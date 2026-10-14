<#
.SYNOPSIS
    Post the closed message on the Asana task a GitHub issue belongs to when that issue closes as
    completed, the on-hold message when it is parked as not planned while waiting for more information,
    and the reopened message when it is reopened. Copied into a BWJ store repo as
    .github/scripts/asana-closed-message.ps1 and driven by .github/workflows/asana-closed-message.yml.

.DESCRIPTION
    THE TWO MESSAGES THAT CAME BACK. The asana-mirror workflow was retired on October 5, 2026, whole
    (#2804): card moves, the daily sweeps, the prio-label sync, and the created, reopened and closed
    comments. Asked which part to bring back, Dave chose the closed message, in the go-live block's
    current shape (#2818); a day later he brought back the reopened message beside it (#2854), because
    without it a requester can go on testing a result that is being reworked. The prio-label sync came
    back separately, as its own workflow, asana-prio-label (#2945). Everything else stays retired, and
    nothing in this file can move a card, complete a task or write a label: the one write it knows how
    to build is a comment (New-AsanaCommentRequest).

    THE FILE KEEPS ITS 'closed-message' NAME ON PURPOSE. A store holds it at a fixed path, and adopt
    copies by path: a renamed template would land beside the old one rather than replace it, and both
    would post on every close.

    WHAT IT POSTS, AND WHEN:

      - A close as COMPLETED with a linked task: one comment, as html_text. The automation's header,
        the closed line, and under it the sections of the go-live block the shipping session left on
        the issue (build-golive-block.ps1). That block is the "new form": TE BEKIJKEN OP, WAT ER NU
        ANDERS IS, WANNEER HET LIVE KOMT, WAT ER BEWUST NIET IN ZIT, WAT WE VAN JE VRAGEN.
      - A close as completed whose newest block is a RESEARCH block (build-golive-block.ps1 -Research,
        #3004): Maikel's general form (#3017) -- the header, the research closed line ('is now closed:
        the Asana task is ready for review. Read the outcome below.'), the block's OUTCOME section as a
        bulleted list, and the closing ask: 'Is anything still unclear? Leave a comment on this task. No
        more questions? Move the task to '<done section>' and mark it as complete.' A research, test or
        decision ticket changed nothing on the store, so the reopen line ('when something is still not
        working as expected') would describe a result that does not exist. The block carries a second
        marker (Get-AsanaResearchBlockMarker) beside its own, and that is how it is recognised.
        THE DONE SECTION IS THE BOARD'S OWN NAME, NEVER A FIXED '4. Done' (#3017): the code the repo's
        Get-AsanaStageMap gives the Completed stage, matched against the sections of the task's own
        board (Resolve-DoneSectionName). Where any step of that does not answer, the ask says 'Mark the
        task as complete.' and names no section, rather than one this run could not confirm.
      - A close as completed that CARRIES NO BLOCK, for any reason: the header, the closed line, and one
        sentence under them -- 'The result message for this round follows.' NEVER THE CLOSED LINE ALONE
        (Maikel, October 14, 2026, #3004): 'with this automation there must always be an explanation of
        how to view the result', and a bare 'is now closed' told the requester of
        smartwatchbanden#943 that the work was done and nothing about where its result was. The
        sentence tells them a result message is still coming; the task's assignee writes it. No link
        to the GitHub issue stands in for it: not every requester can open the repo. The cases:
          * the newest block was posted BEFORE the issue's last reopen (#2968). That block describes an
            earlier round; xoxowildhearts#414 sent round 1's block into the task as round 2's result.
            A block newer than the reopen, and an issue never reopened, are carried as before;
          * the last reopen could not be read, so a block that might be stale is not carried;
          * there is NO block on the issue. A close by hand is refused by the close guard before it gets
            here (hooks/guard-stale-paste-block.ps1, #3004), so this is the GitHub close button, a merge,
            or a session the hook does not run in;
          * the comments COULD NOT BE READ; the log says the read failed, with gh's exit code and stderr
            -- never 'none was on the issue', which it cannot know (#2875).
        The requester is delayed, never misinformed. This is the BACKSTOP for a merge or a close the
        hook never saw -- the GitHub merge button, a merge queue, the close button.
      - A close as NOT PLANNED that keeps the awaiting-info-client label on, with a linked task: one
        comment, the header and the on-hold line in the requester's fixed form -- 'is closed: there is not
        enough information to start development yet. Once the questions above are answered, the issue will
        be reopened and the work picks up again.' (#2902, #2909). That pair is the BWJ procedure's
        sanctioned way to park a ticket waiting on its requester (#2732), and without this line the
        requester heard nothing, or -- where a session closed it as completed to get a message out --
        read 'is now closed' as finished. No block is read: nothing was built.
      - A close as NOT PLANNED without that label, or as a DUPLICATE: nothing. Nothing was built, so
        there is nothing to test, and a rejection is said by a person rather than by this line (#2765).
      - A REOPEN with a linked task, whatever the earlier close reason: one comment, the header and the
        reopened line in the requester's fixed form (#2656) -- 'is reopened: this Asana task is now back in
        development.' No block is read; a reopen carries nothing to test.
      - An issue with no linked task, or one linking several different tasks: nothing, and the log
        says which.

    NO DE-DUPLICATION, as before: a close or a reopen is a real state change, so a second close after a
    reopen is news again and is said again.

    HOW THE TASK IS FOUND -- Resolve-AsanaTaskRef, the same three matchers, in this order: the
    '<!-- asana-task: <gid> -->' marker report-issue writes; the '| **Asana** | ... |' header row of an
    imported ticket; exactly one Asana task URL anywhere else. Several different tasks is 'ambiguous'
    and skipped: this script never guesses which ticket an issue belongs to.

    SELF-CONTAINED, AND THAT IS WHY THE HELPERS ARE COPIES. This file ships into a consumer's
    .github/scripts/, where no plugin lib exists, so the matchers and the block's marker are copied
    from bwj-development's scripts/lib/asana-task-lib.ps1 rather than loaded from it.
    scripts/tests/bwj-development.tests.ps1 holds each copy equal to its source, and holds this file to
    dot-sourcing nothing.

    WHOSE TEXT IT FORWARDS (security review, #2818). The block is taken only from a comment whose author
    is the repo's OWNER, a MEMBER or a COLLABORATOR (Test-TrustedCommentAuthor): anyone else who can
    comment could otherwise put a link of their choosing on the task, under the token owner's name and
    the automation's header. AND FROM ONE WHOSE AUTHOR CAN WRITE TO THE REPO (#2907): author_association
    is computed for the viewer, and the workflow's token cannot see a PRIVATE org membership, so an org
    member who ships the work reads as CONTRIBUTOR to it and their block was dropped -- every run in
    smartwatchbanden logged 'none was on the issue'. So the author of an untrusted comment that carries
    the block's marker is asked about once, by repo permission ('gh api .../collaborators/<login>/
    permission'), and the block is carried when that answers admin or write (Test-TrustedRepoPermission).
    A comment without the marker is never asked about, and a drop is logged with the association and
    the permission, never as 'none was on the issue'.

    THE TASK IT WRITES TO is the one the issue body's marker names, and whoever can edit the body can
    point that marker at any task the token reaches. That is the retired
    asana-mirror's trust model unchanged, and it is accepted rather than closed here: the write is one
    comment, and checking the task's project against a configured one is a check this workflow
    deliberately does without. The board read for the done section (#3017) is no such check: it reads
    the sections of whichever board the task is on, to NAME one in the ask, and gates nothing. A reopen
    (#2854) is one more trigger on that same model, not a new one: an issue's author can reopen it, but
    what a reopen posts is fixed text, with nothing from the issue in it.

    THE REPO'S STAGE MAP IS READ AS TEXT, NEVER RUN (#3017). scripts/repo-config.ps1 is the repo's own
    seam file, and dot-sourcing it in a job that holds ASANA_PAT would run whatever it, and everything
    it dot-sources in turn, does. The one value needed is the Completed code inside Get-AsanaStageMap,
    and Get-RepoStageCode reads that with a pattern.

    IT PRINTS NOTHING ANOTHER PERSON WROTE. The only foreign text this run could meet is a task name, a
    comment body, a board's section name or an Asana API error message, and none of them is printed: a
    failed post reports its HTTP status and nothing else. The one error text it does print is gh's own stderr on a failed
    comment read (#2875) -- GitHub's API or auth message, never a comment -- because a read that failed
    silently was once logged as an issue with no block on it, and the cause could not be recovered.

    Auth: ASANA_PAT (the repo secret). GH_TOKEN is the workflow's own token, used to read the issue's
    comments for the block through REST ('gh api .../issues/<n>/comments', Get-IssueCommentsApiArgs),
    which 'issues: read' covers; the GraphQL read it replaced answered nothing on the runner (#2875).
    The issue's last reopen is read the same way ('gh api .../issues/<n>/events', Get-IssueReopenApiArgs),
    and only when a block is there to judge (#2968).
    There is no project, workspace or Projects token: a comment addresses its task by GID alone. The
    ASANA_PAT also makes the two reads a research close needs for its done section (#3017): the task's
    board memberships, then that board's sections. Nothing else is read from Asana.

    The script runs its main flow only when invoked directly; dot-sourcing it loads the pure helpers and
    does nothing else, which is how the suite exercises them.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    # Read from the environment by default rather than passed as an argument: a body can approach the
    # per-argument limit on Linux once it carries multi-byte text.
    [string]$IssueBody = $env:ISSUE_BODY,
    # 'owner/repo#<n>'.
    [string]$IssueRef = '',
    # github.event.issue.state_reason: 'completed', 'not_planned', 'duplicate', or empty on an event
    # older than GitHub's close reasons, which GitHub treated as completed. Not read on a reopen.
    [string]$StateReason = '',
    # github.event.action: a close or a reopen.
    [ValidateSet('closed', 'reopened')]
    [string]$Event = 'closed',
    # The issue's label names as a JSON array (#2902): read only on a close as not planned, where
    # awaiting-info-client makes it the on-hold message. Empty from a workflow copied before #2902, which
    # leaves a not-planned close silent as it was.
    [string]$IssueLabels = $env:ISSUE_LABELS,
    [string]$AsanaPat = $env:ASANA_PAT,
    # The repo's seam file, read as TEXT for the Completed stage code a research close names its done
    # section by (#3017). Empty means the checkout's own, two levels above this script, resolved in
    # Invoke-Main: $PSScriptRoot is empty in a param default when the file is dot-sourced from a prompt.
    [string]$RepoConfigPath = ''
)

$ErrorActionPreference = 'Stop'

$script:AsanaApiBase = 'https://app.asana.com/api/1.0'

function Get-AsanaGidsFromText {
    <#
        Pure: the distinct task GIDs of every Asana task URL in a piece of text, in first-seen order.
        Both URL shapes Asana hands out are read; a URL that names no task contributes nothing.
        A copy of asana-task-lib.ps1's function of this name.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $gids = @()
    foreach ($m in [regex]::Matches($Text, 'https://app\.asana\.com/[^\s)>\]]*')) {
        $url = $m.Value
        $t = [regex]::Match($url, '/task/([0-9]+)')
        if (-not $t.Success) { $t = [regex]::Match($url, '^https://app\.asana\.com/0/[0-9]+/([0-9]+)') }
        if ($t.Success) { $gids += $t.Groups[1].Value }
    }
    return @($gids | Select-Object -Unique)
}

function Get-AsanaHeaderRowText {
    <#
        Pure: the contents of an imported ticket's '| **Asana** | ... |' header row, or ''. A copy of
        asana-task-lib.ps1's function of this name.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$IssueBody)

    $m = [regex]::Match($IssueBody, '(?m)^\|\s*\*{0,2}Asana\*{0,2}\s*\|(.*)$')
    if (-not $m.Success) { return '' }
    return $m.Groups[1].Value
}

function Resolve-AsanaTaskRef {
    <#
        Pure: which Asana task an issue body belongs to -- Gid (or $null), Source ('marker' |
        'header-row' | 'sole-url' | 'ambiguous' | 'none') and Candidates. Non-numeric content never
        matches, so it can never reach a request URL. A copy of asana-task-lib.ps1's function of this name.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$IssueBody)

    $marker = [regex]::Match($IssueBody, '<!--\s*asana-task:\s*([0-9]+)\s*-->')
    if ($marker.Success) {
        return [pscustomobject]@{ Gid = $marker.Groups[1].Value; Source = 'marker'; Candidates = @($marker.Groups[1].Value) }
    }

    $row = Get-AsanaHeaderRowText -IssueBody $IssueBody
    if ($row) {
        $rowGids = @(Get-AsanaGidsFromText -Text $row)
        if ($rowGids.Count -ge 1) {
            return [pscustomobject]@{ Gid = $rowGids[0]; Source = 'header-row'; Candidates = $rowGids }
        }
    }

    $all = @(Get-AsanaGidsFromText -Text $IssueBody)
    if ($all.Count -eq 1) { return [pscustomobject]@{ Gid = $all[0]; Source = 'sole-url'; Candidates = $all } }
    if ($all.Count -gt 1) { return [pscustomobject]@{ Gid = $null; Source = 'ambiguous'; Candidates = $all } }
    return [pscustomobject]@{ Gid = $null; Source = 'none'; Candidates = @() }
}

function Get-ClosedMessageHeader {
    <#
        Pure: the first line of the comment. Asana shows a comment as written by the account whose token
        posted it, and ASANA_PAT belongs to a person, so without this line a colleague reads the message
        as that person's own words (#2476). The requester's wording, word for word (#2656): an em dash,
        'GitHub automation', and the robot emoji U+1F916, composed from code points.
    #>
    return "$([char]0x2014) GitHub automation $([char]::ConvertFromUtf32(0x1F916))"
}

function Get-ClosedMessageTail {
    <#
        Pure: what follows 'is now closed' in the closed sentence, its own punctuation first. The result
        form invites a reopen (#2700); the research form says the task is ready for review and points at
        the outcome below it (#3017, Maikel, October 14, 2026, replacing #3004's 'Nothing has changed.
        This issue was for research purposes only.'), because a research, test or decision ticket has no
        result that can be 'not working as expected'. Both are fixed and fit every ticket.
    #>
    param([switch]$Research)
    if ($Research) { return ': the Asana task is ready for review. Read the outcome below.' }
    return '. It can be reopened anytime when something is still not working as expected.'
}

function Get-ClosedMessageAsk {
    <#
        Pure: the closing ask under a research close's outcome (#3017), fixed and English on every
        board. -DoneSection is the board's own name for its done column (Resolve-DoneSectionName), so
        the line stays true where that column is not called '4. Done'; without one the ask names no
        section, because a name this run could not confirm would send the requester to a column that
        is not there.
    #>
    param([AllowEmptyString()][string]$DoneSection = '')
    $unclear = 'Is anything still unclear? Leave a comment on this task.'
    if ($DoneSection) { return "$unclear No more questions? Move the task to '$DoneSection' and mark it as complete." }
    return "$unclear No more questions? Mark the task as complete."
}

function New-ClosedMessage {
    <#
        Pure: the closed comment as plain text -- the header, a blank line, and the closed sentence
        (#2700). It is the go-live block's own opening, so the two read the same. -Research is the
        research form (#3004).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [switch]$Research
    )
    return (@((Get-ClosedMessageHeader), '', "GitHub issue $IssueRef is now closed$(Get-ClosedMessageTail -Research:$Research)") -join "`n")
}

function Get-PasteBlockSections {
    <#
        Pure: the sections of a go-live block -- the text between its two '---' rules, minus the two
        lines this message composes itself (the header and the closed line). '' when there is no block.
        The header is dropped by SHAPE (the first non-blank line, opening with an em dash), so a block
        posted under an older header is carried without it too.
    #>
    param([AllowEmptyString()][string]$Body)

    $lines = @(([string]$Body) -split "`r?`n")
    $rules = @(for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $i } })
    if ($rules.Count -lt 2 -or ($rules[1] - $rules[0]) -lt 2) { return '' }
    $inner = @($lines[($rules[0] + 1)..($rules[1] - 1)])

    $dash = [string][char]0x2014
    $at = 0
    while ($at -lt $inner.Count -and -not $inner[$at].Trim()) { $at++ }
    if ($at -lt $inner.Count -and $inner[$at].TrimStart().StartsWith($dash)) {
        $at++
        while ($at -lt $inner.Count -and -not $inner[$at].Trim()) { $at++ }
        if ($at -lt $inner.Count -and $inner[$at].StartsWith('GitHub issue ')) { $at++ }
    }
    $rest = @(if ($at -lt $inner.Count) { $inner[$at..($inner.Count - 1)] })
    return (($rest -join "`n").Trim())
}

function ConvertTo-AsanaXmlText {
    <#
        Pure: text made safe for Asana html_text. The characters XML forbids outright (C0 controls other
        than tab, newline and carriage return) are dropped first, because one of them makes Asana answer
        400 and the requester is told nothing (security review, #2818). Then &, <, > and " are escaped.
        An apostrophe stays as typed: it is valid in XML text, and whether Asana accepts '&apos;' was never
        measured, while Dutch block prose is full of apostrophes.
    #>
    param([AllowEmptyString()][string]$Text)
    $clean = [regex]::Replace([string]$Text, '[\x00-\x08\x0B\x0C\x0E-\x1F]', '')
    return $clean.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

function ConvertTo-AsanaStoryHtml {
    <#
        Pure: a block's Markdown sections as the INSIDE of an Asana html_text body (#2703). A heading
        line (capitals and spaces) becomes <strong>, '[text](url)' and a bare http(s) URL become <a>,
        and '**x**' becomes <strong>. Everything else is XML-escaped, so the body is always well-formed:
        a malformed one is answered 400 and the requester is told nothing. Newlines survive as written.

        -Lists (#3017): a run of consecutive '- ' lines becomes ONE line, '<ul><li>..</li>..</ul>', the
        shape Maikel's reference story on smartwatchbanden#944's task carries, so Asana shows a list
        rather than hyphens. Only the research form asks for it; a result block's text is posted as it
        always was.
    #>
    param(
        [AllowEmptyString()][string]$Markdown,
        [switch]$Lists
    )

    $esc   = { param($s) ConvertTo-AsanaXmlText -Text $s }
    $out   = New-Object System.Collections.Generic.List[string]
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($line in (([string]$Markdown) -split "`r?`n")) {
        if ($Lists -and $line -match '^\s*-\s+(.*)$') { $items.Add("<li>$(ConvertTo-AsanaInlineHtml -Line $Matches[1].Trim())</li>"); continue }
        if ($items.Count -gt 0) { $out.Add("<ul>$($items -join '')</ul>"); $items.Clear() }
        if ($line -cmatch '^[A-Z][A-Z /]*[A-Z]$') { $out.Add("<strong>$(& $esc $line)</strong>"); continue }
        $out.Add((ConvertTo-AsanaInlineHtml -Line $line))
    }
    if ($items.Count -gt 0) { $out.Add("<ul>$($items -join '')</ul>") }
    return (@($out) -join "`n")
}

function ConvertTo-AsanaInlineHtml {
    <#
        Pure: one line of a block's Markdown as html_text -- '[text](url)' and a bare http(s) URL as <a>,
        '**x**' as <strong>, everything else XML-escaped. The inline half of ConvertTo-AsanaStoryHtml,
        apart so a list item is converted exactly as a line is (#3017).
    #>
    param([AllowEmptyString()][string]$Line)

    $esc  = { param($s) ConvertTo-AsanaXmlText -Text $s }
    $line = [string]$Line
    $sb   = New-Object System.Text.StringBuilder
    $pos  = 0
    foreach ($m in [regex]::Matches($line, '\[([^\]]+)\]\((https?://[^)\s]+)\)|(https?://[^\s<>()]+)|\*\*([^*]+)\*\*')) {
        [void]$sb.Append((& $esc $line.Substring($pos, $m.Index - $pos)))
        if ($m.Groups[1].Success) {
            [void]$sb.Append("<a href=`"$(& $esc $m.Groups[2].Value)`">$(& $esc $m.Groups[1].Value)</a>")
        } elseif ($m.Groups[3].Success) {
            # A bare URL at the end of a sentence would swallow its full stop and link to a page that
            # does not exist (code review, #2818), so trailing punctuation goes back into the text.
            $bare  = $m.Groups[3].Value
            $trail = ([regex]::Match($bare, '[.,;:!?]+$')).Value
            if ($trail) { $bare = $bare.Substring(0, $bare.Length - $trail.Length) }
            [void]$sb.Append("<a href=`"$(& $esc $bare)`">$(& $esc $bare)</a>$(& $esc $trail)")
        } else {
            [void]$sb.Append("<strong>$(& $esc $m.Groups[4].Value)</strong>")
        }
        $pos = $m.Index + $m.Length
    }
    [void]$sb.Append((& $esc $line.Substring($pos)))
    return $sb.ToString()
}

function New-ClosedMessageHtml {
    <#
        Pure: the closed message as Asana html_text -- the header, the closed sentence with the issue
        name as a link and 'closed' in bold (the requester's form, #2656), and the block's sections
        under it where -BlockSections carries any. Only <body>, <a>, <strong> and, in the research form,
        <ul> and <li>, all on Asana's allow-list for a story.

        WITHOUT SECTIONS, ONE SENTENCE SAYS THE RESULT MESSAGE FOLLOWS (#3004), in the closed line's own
        style -- never the closed line alone, which tells the requester the work is done and nothing about
        how to see it. It began as the close whose only block describes an EARLIER round (#2968); it is
        now every close that carries no block. Never beside a block, which it would contradict.

        -Research (#3004, its form #3017's): the block is a research block, so the closed sentence says
        the task is ready for review instead of inviting a reopen, the outcome's bullets become a list,
        and the closing ask follows them, naming -DoneSection where one was found (Get-ClosedMessageAsk).
        It is meaningful only beside sections: a research close that carries no block gets the result
        form, because nothing it could say about a finding is known.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [AllowEmptyString()][string]$BlockSections = '',
        [switch]$Research,
        [AllowEmptyString()][string]$DoneSection = ''
    )

    $esc      = { param($s) ConvertTo-AsanaXmlText -Text $s }
    $parts    = $IssueRef -split '#'
    $url      = "https://github.com/$($parts[0])/issues/$($parts[1])"
    $research = $Research -and [bool]$BlockSections
    $tail     = Get-ClosedMessageTail -Research:$research
    $html     = "<body>$(& $esc (Get-ClosedMessageHeader))`n`nGitHub issue <a href=`"$(& $esc $url)`">$(& $esc $IssueRef)</a> is now <strong>closed</strong>$(& $esc $tail)"
    if ($research) {
        $html += "`n`n" + (ConvertTo-AsanaStoryHtml -Markdown $BlockSections -Lists) + "`n" + (& $esc (Get-ClosedMessageAsk -DoneSection $DoneSection))
    } elseif ($BlockSections) { $html += "`n`n" + (ConvertTo-AsanaStoryHtml -Markdown $BlockSections) }
    else { $html += "`n`n" + (& $esc 'The result message for this round follows.') }
    return $html + '</body>'
}

function New-ReopenedMessage {
    <#
        Pure: the reopened comment as plain text -- the header, a blank line, and the reopened sentence
        in the requester's fixed form (#2656), brought back by #2854.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)
    return (@((Get-ClosedMessageHeader), '', "GitHub issue $IssueRef is reopened: this Asana task is now back in development.") -join "`n")
}

function New-ReopenedMessageHtml {
    <#
        Pure: the reopened message as Asana html_text -- the header, then the reopened sentence with the
        issue name as a link and only the state word, 'reopened:', in bold (#2909) -- the same form the
        closed line takes.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)

    $esc   = { param($s) ConvertTo-AsanaXmlText -Text $s }
    $parts = $IssueRef -split '#'
    $url   = "https://github.com/$($parts[0])/issues/$($parts[1])"
    return "<body>$(& $esc (Get-ClosedMessageHeader))`n`nGitHub issue <a href=`"$(& $esc $url)`">$(& $esc $IssueRef)</a> is <strong>reopened:</strong> this Asana task is now back in development.</body>"
}

function New-OnHoldMessage {
    <#
        Pure: the on-hold comment as plain text (#2902) -- the header, a blank line, and the on-hold
        sentence in the requester's fixed form (#2909). Posted on a close as not planned with
        awaiting-info-client kept on, so the requester reads a parked ticket as waiting for them, never as
        finished: the completed line says 'is now closed. It can be reopened anytime', which a colleague
        with an open question in front of them reads as done.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)
    return (@((Get-ClosedMessageHeader), '', "GitHub issue $IssueRef is closed: there is not enough information to start development yet. Once the questions above are answered, the issue will be reopened and the work picks up again.") -join "`n")
}

function New-OnHoldMessageHtml {
    <#
        Pure: the on-hold message as Asana html_text -- the header, then the on-hold sentence with the
        issue name as a link and only the state word, 'closed:', in bold (#2909) -- the same form the
        reopened line takes. No block is read: nothing was built, so there is nothing to test.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)

    $esc   = { param($s) ConvertTo-AsanaXmlText -Text $s }
    $parts = $IssueRef -split '#'
    $url   = "https://github.com/$($parts[0])/issues/$($parts[1])"
    return "<body>$(& $esc (Get-ClosedMessageHeader))`n`nGitHub issue <a href=`"$(& $esc $url)`">$(& $esc $IssueRef)</a> is <strong>closed:</strong> there is not enough information to start development yet. Once the questions above are answered, the issue will be reopened and the work picks up again.</body>"
}

function Get-AsanaPasteBlockMarker {
    <#
        Pure: the machine marker build-golive-block.ps1 puts on the comment carrying the block. A copy
        of asana-task-lib.ps1's function of this name.
    #>
    return '<!-- asana-paste-block -->'
}

function Get-AsanaResearchBlockMarker {
    <#
        Pure: the second marker build-golive-block.ps1 -Research puts on a research block (#3004). A copy
        of asana-task-lib.ps1's function of this name.
    #>
    return '<!-- asana-paste-block-kind: research -->'
}

function ConvertTo-AsanaInstant {
    <#
        Pure: a GitHub timestamp as a UTC [datetime], or $null when it is empty or does not parse. Takes
        the ISO string ('2026-10-13T08:15:00Z') or a [datetime] -- Windows PowerShell 5.1's
        ConvertFrom-Json already turns such a string into a LOCAL-kind datetime, so both shapes are
        normalised to UTC before anything is compared (#2968). A copy of
        asana-task-lib.ps1's function of this name.
    #>
    param($Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
    $text = ([string]$Value).Trim()
    if (-not $text) { return $null }
    $parsed = [datetime]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
    if ([datetime]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) { return $parsed }
    return $null
}

function Test-AsanaPasteBlockBody {
    <#
        Pure: is this comment body a go-live block the closed message would CARRY? The marker, and
        sections Get-PasteBlockSections finds that are not empty and hold no '[ADD LINK]' placeholder --
        exactly the predicate Select-SessionPasteBlockSections picks a block by (#2968). It is ONE
        predicate on purpose: a freshness check that accepted a comment the selection then skipped (a
        marker with two adjacent rules, a header-only block) would call the issue fresh while the
        message carried the older round's block, which is the failure #2968 measured.
        A copy of asana-task-lib.ps1's function of this name.
    #>
    param([AllowEmptyString()][string]$Body)

    if (-not ([string]$Body).Contains((Get-AsanaPasteBlockMarker))) { return $false }
    $sections = Get-PasteBlockSections -Body $Body
    return [bool]($sections -and -not $sections.Contains('[ADD LINK]'))
}

function Get-AsanaPasteBlockVerdict {
    <#
        Pure: is the block the closed message would carry still the right one, judged against the
        issue's most recent reopen (#2968)? -Comments are objects with Body and CreatedAt in the order
        GitHub returns them (oldest first); -LastReopenedAt is the timestamp of the latest 'reopened'
        event, or $null where the issue was never reopened. THE COMMENT JUDGED IS THE ONE THE SELECTION
        PICKS: the last comment, in that order, that Test-AsanaPasteBlockBody accepts.

          'none'         no comment carries a block -- nothing to be stale.
          'not-reopened' a block exists and the issue was never reopened.
          'fresh'        that block was posted AFTER the last reopen: it belongs to this round.
          'stale'        it is at or before the last reopen: it describes an earlier round, which is what
                         #2968 measured carried into the Asana task as this round's result.
          'unknown'      a time that cannot be parsed, so no judgement is made; the caller decides.

        STRICTLY NEWER IS FRESH, AND AN EQUAL SECOND IS STALE: GitHub stamps to the second, and the wrong
        answer to a tie must be the one the caller can repair (a refusal with its fix on one line, a
        delayed message), never the one that sends old information on as new.
        A copy of asana-task-lib.ps1's function of this name.
    #>
    param(
        [AllowEmptyCollection()][object[]]$Comments = @(),
        $LastReopenedAt = $null
    )

    $chosen = $null
    foreach ($c in @($Comments)) {
        if (Test-AsanaPasteBlockBody -Body ([string]$c.Body)) { $chosen = $c }
    }
    if ($null -eq $chosen) { return 'none' }
    if ($null -eq $LastReopenedAt) { return 'not-reopened' }
    $reopen = ConvertTo-AsanaInstant -Value $LastReopenedAt
    $at     = ConvertTo-AsanaInstant -Value $chosen.CreatedAt
    if ($null -eq $reopen -or $null -eq $at) { return 'unknown' }
    if ($at -gt $reopen) { return 'fresh' }
    return 'stale'
}

function Select-SessionPasteBlockBody {
    <#
        Pure: out of an issue's comment bodies, the NEWEST one that is a block the message would carry
        -- the marker, and sections that are not a placeholder copy ('[ADD LINK]'). '' when there is
        none. The whole body, because whether it is a research block (#3004) is read from its marker,
        which sits outside the sections.
    #>
    param([string[]]$Bodies = @())

    # THE PREDICATE IS Test-AsanaPasteBlockBody, THE ONE THE FRESHNESS CHECK JUDGES BY (#2968): a block it
    # skipped here and accepted there would let a newer degenerate comment make an old block look fresh.
    $list = @($Bodies)
    for ($i = $list.Count - 1; $i -ge 0; $i--) {
        $body = [string]$list[$i]
        if (Test-AsanaPasteBlockBody -Body $body) { return $body }
    }
    return ''
}

function Select-SessionPasteBlockSections {
    <#
        Pure: the sections of the block Select-SessionPasteBlockBody picks. '' when there is none.
    #>
    param([string[]]$Bodies = @())
    $body = Select-SessionPasteBlockBody -Bodies $Bodies
    if (-not $body) { return '' }
    return (Get-PasteBlockSections -Body $body)
}

function Get-OnHoldLabelNames {
    <#
        Pure: the labels that turn a close as not planned into a close while WAITING (#2732, #2902). It is
        the pair the BWJ procedure sanctions for parking a ticket blocked on its requester: not planned,
        with this label kept on through the close. The current name first, then the former one
        (awaiting-more-info until #2917): a tracker keeps the old name until somebody renames it there,
        and a not-planned close under it must still post the on-hold message.
    #>
    return @('awaiting-info-client', 'awaiting-more-info')
}

function Get-ClosedMessageDecision {
    <#
        Pure: whether this close or reopen gets a message, which one (Kind: 'closed' | 'on-hold' |
        'reopened'), and why not where it does not. Post is $true for a reopen; for a close as completed
        (or one with no reason, which GitHub treated as completed); and for a close as NOT PLANNED that
        still carries the awaiting-info-client label (#2902) -- the parked-while-waiting pair, which gets the
        on-hold message. All three need an issue whose body resolves to exactly one task. A reopen ignores
        the close reason: whatever the issue was closed as, it is in development now (#2854). A close as
        not planned WITHOUT the label is a rejection, and a duplicate is somebody else's ticket: both stay
        silent, because nothing was built (#2765).
    #>
    param(
        [AllowEmptyString()][string]$StateReason = '',
        [AllowEmptyString()][string]$IssueBody = '',
        [ValidateSet('closed', 'reopened')][string]$Event = 'closed',
        [AllowEmptyCollection()][string[]]$Labels = @()
    )

    $reason = ([string]$StateReason).Trim().ToLowerInvariant()
    $kind   = if ($Event -eq 'reopened') { 'reopened' } else { 'closed' }
    if ($Event -eq 'closed' -and $reason -and $reason -ne 'completed') {
        $onHold = $reason -eq 'not_planned' -and (@($Labels | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() } | Where-Object { (Get-OnHoldLabelNames) -contains $_ }).Count -gt 0)
        if (-not $onHold) {
            return [pscustomobject]@{ Post = $false; Gid = $null; Kind = $null; Why = "closed as '$reason' -- nothing was built, so the task is told nothing (#2765)." }
        }
        $kind = 'on-hold'
    }
    $ref = Resolve-AsanaTaskRef -IssueBody $IssueBody
    if ($ref.Source -eq 'ambiguous') {
        return [pscustomobject]@{ Post = $false; Gid = $null; Kind = $null; Why = "the body links several different Asana tasks ($($ref.Candidates -join ', ')) -- refusing to guess. Add an explicit <!-- asana-task: GID --> marker to settle it." }
    }
    if (-not $ref.Gid) {
        return [pscustomobject]@{ Post = $false; Gid = $null; Kind = $null; Why = 'no Asana task is linked from the issue -- nothing to tell.' }
    }
    return [pscustomobject]@{ Post = $true; Gid = $ref.Gid; Kind = $kind; Why = "matched by $($ref.Source)" }
}

function ConvertFrom-IssueLabelList {
    <#
        Pure: the ISSUE_LABELS the workflow passes -- the label names as a JSON array, by GitHub's own
        toJSON() -- as a list. JSON rather than a joined string because a label name may hold a comma.
        Empty (a workflow copied before #2902) or unparseable is no labels, which leaves a not-planned
        close silent, as it was.
    #>
    param([AllowEmptyString()][string]$Text = '')
    if (-not ([string]$Text).Trim()) { return @() }
    # -InputObject and foreach, not a pipe: Windows PowerShell 5.1 sends a parsed array down the pipeline
    # as ONE object, which would read every label as a single joined name.
    try { $parsed = ConvertFrom-Json -InputObject ([string]$Text) } catch { return @() }
    $names = @(foreach ($n in $parsed) { ([string]$n).Trim() })
    return @($names | Where-Object { $_ })
}

function New-AsanaCommentRequest {
    <#
        Pure: the POST that adds an html_text comment to a task. The only write this script can build.
        A non-numeric GID is refused before it can reach a URL.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [Parameter(Mandatory = $true)][string]$Html
    )
    if ($Gid -notmatch '\A[0-9]+\z') { throw "Refusing to build a request for a non-numeric task GID: '$Gid'." }
    [pscustomobject]@{
        Method = 'POST'
        Uri    = "$script:AsanaApiBase/tasks/$Gid/stories"
        Body   = (ConvertTo-Json @{ data = @{ html_text = $Html } } -Compress -Depth 5)
    }
}

function Test-TrustedCommentAuthor {
    <#
        Pure: may a comment by an author with this GitHub association supply the block? OWNER, MEMBER and
        COLLABORATOR only -- the people who can ship the work. See the header's trust paragraph.
    #>
    param([AllowEmptyString()][string]$Association)
    return (@('OWNER', 'MEMBER', 'COLLABORATOR') -contains ([string]$Association).Trim().ToUpperInvariant())
}

function Test-TrustedRepoPermission {
    <#
        Pure: may an author with this repo permission supply the block (#2907)? admin or write only --
        GitHub's legacy base role, where maintain reads as write and triage as read. The people who can
        ship the work, whatever their org membership's visibility.
    #>
    param([AllowEmptyString()][string]$Permission)
    return (@('admin', 'write') -contains ([string]$Permission).Trim().ToLowerInvariant())
}

function Test-GitHubUserLogin {
    <#
        Pure: is this a GitHub user login -- letters, digits and single hyphens, 39 at most? Only such a
        login is asked about or printed: a bot's 'name[bot]' is no user and holds no repo permission.
    #>
    param([AllowEmptyString()][string]$Login)
    return ([string]$Login -cmatch '\A[A-Za-z0-9](?:-?[A-Za-z0-9]){0,38}\z')
}

function Get-PermissionCheckLogins {
    <#
        Pure: the distinct logins whose repo permission must be asked (#2907) -- the authors of comments
        that carry the block's marker but whose association is not trusted. Nothing else is asked about,
        so an issue whose block came from a visible member costs no extra call.
    #>
    param([AllowEmptyCollection()][object[]]$Comments = @())

    $marker = Get-AsanaPasteBlockMarker
    $logins = foreach ($c in @($Comments)) {
        if (Test-TrustedCommentAuthor -Association ([string]$c.Association)) { continue }
        if (-not ([string]$c.Body).Contains($marker)) { continue }
        if (Test-GitHubUserLogin -Login ([string]$c.Login)) { [string]$c.Login }
    }
    return @($logins | Select-Object -Unique)
}

function Get-CollaboratorPermissionApiArgs {
    <#
        Pure: the gh arguments that read one user's permission on the repo (#2907). A login that is not
        a user login is refused before it can reach the request path.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][string]$Login
    )
    if ($IssueRef -notmatch '\A([^\s#/]+)/([^\s#/]+)#([0-9]+)\z') { throw "IssueRef '$IssueRef' is not 'owner/repo#<n>'." }
    if (-not (Test-GitHubUserLogin -Login $Login)) { throw 'Refusing to ask the permission of a login that is not a GitHub user login.' }
    return @('api', "repos/$($Matches[1])/$($Matches[2])/collaborators/$Login/permission", '--jq', '.permission')
}

function Invoke-GhCapture {
    <#
        Run gh with these arguments and keep both streams apart: Out (the stdout lines), ExitCode, and
        Error (gh's own stderr, or a placeholder when it wrote none). Shared by both reads, so a failed
        read is reported the same way in each (#2875).
    #>
    param([Parameter(Mandatory = $true)][string[]]$GhArgs)

    $prev = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $all  = @(& gh @ghArgs 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    $out = @($all | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
    $err = (@($all | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }) -join ' ').Trim()
    return [pscustomobject]@{ Out = $out; ExitCode = $code; Error = $(if ($err) { $err } else { '(gh wrote nothing to stderr)' }) }
}

function Read-CollaboratorPermission {
    <#
        One user's repo permission, read through gh: Ok, Permission, ExitCode, Error. A failed read is
        reported, never taken as a permission (#2875's lesson): Error is gh's own stderr.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][string]$Login
    )

    $run = Invoke-GhCapture -GhArgs (Get-CollaboratorPermissionApiArgs -IssueRef $IssueRef -Login $Login)
    if ($run.ExitCode -ne 0) {
        return [pscustomobject]@{ Ok = $false; Permission = ''; ExitCode = $run.ExitCode; Error = $run.Error }
    }
    return [pscustomobject]@{ Ok = $true; Permission = (@($run.Out) -join '').Trim(); ExitCode = 0; Error = '' }
}

function Select-TrustedCommentBodies {
    <#
        Pure: the bodies that may supply the block, in the order GitHub returned them, and a note for every
        marker comment that was NOT carried (#2907). A comment is carried when its association is trusted,
        or -- for a marker comment -- when -Permissions answers admin or write for its author. -Permissions
        maps a login to its permission string, or to $null where the read failed. A note names the
        association and the permission, and the login only when it is a user login; never the body.
        Comments is the same set as the objects themselves, so the block's TIME stays with its body
        (#2968).
    #>
    param(
        [AllowEmptyCollection()][object[]]$Comments = @(),
        [hashtable]$Permissions = @{}
    )

    $marker = Get-AsanaPasteBlockMarker
    $bodies = @()
    $kept   = @()
    $notes  = @()
    $dropped = 0
    foreach ($c in @($Comments)) {
        $assoc = ([string]$c.Association).Trim().ToUpperInvariant()
        $body  = [string]$c.Body
        if (Test-TrustedCommentAuthor -Association $assoc) { $bodies += $body; $kept += $c; continue }
        if (-not $body.Contains($marker)) { continue }
        $login = [string]$c.Login
        $shown = if ($assoc) { $assoc } else { 'unknown' }
        if (-not (Test-GitHubUserLogin -Login $login)) {
            $dropped++
            $notes += "a go-live block comment was not carried: its author (association $shown) is not a GitHub user login."
            continue
        }
        if (-not $Permissions.ContainsKey($login) -or $null -eq $Permissions[$login]) {
            $dropped++
            $notes += "a go-live block comment by '$login' was not carried: association $shown, and their repo permission could not be read."
            continue
        }
        $perm = ([string]$Permissions[$login]).Trim().ToLowerInvariant()
        if (Test-TrustedRepoPermission -Permission $perm) {
            $bodies += $body
            $kept   += $c
            $notes  += "a go-live block comment by '$login' was carried on repo permission '$perm' (association $shown)."
            continue
        }
        $dropped++
        $notes += "a go-live block comment by '$login' was not carried: association $shown, repo permission '$(if ($perm -cmatch '\A[a-z_]{1,20}\z') { $perm } else { 'unrecognized' })'."
    }
    return [pscustomobject]@{ Bodies = $bodies; Comments = $kept; Notes = $notes; Dropped = $dropped }
}

function Get-IssueCommentsApiArgs {
    <#
        Pure: the gh arguments that read an issue's comments through REST (#2875) --
        'gh api repos/<owner>/<repo>/issues/<n>/comments', which the workflow's 'issues: read' covers by
        GitHub's own documentation. The GraphQL read this replaced ('gh issue view --json comments')
        answered nothing on the runner for an issue carrying a trusted block. --paginate walks every
        page, and --jq runs on each page and prints one compact JSON object per comment per line, so
        the pages never arrive as several concatenated arrays and no newer-gh flag (--slurp) is needed.
        The author's login comes along for the permission check (#2907), and created_at for the
        freshness check against the last reopen (#2968).
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)

    if ($IssueRef -notmatch '\A([^\s#/]+)/([^\s#/]+)#([0-9]+)\z') { throw "IssueRef '$IssueRef' is not 'owner/repo#<n>'." }
    return @('api', "repos/$($Matches[1])/$($Matches[2])/issues/$($Matches[3])/comments", '--paginate',
             '--jq', '.[] | {author_association, login: .user.login, body, created_at}')
}

function ConvertFrom-IssueCommentLines {
    <#
        Pure: every comment -- Association, Login, Body, CreatedAt -- out of the lines the REST read prints, one JSON
        object per comment, over every page, in the order GitHub returns them (oldest first). Which of
        them may supply the block is Select-TrustedCommentBodies' question, not this one's (#2907).
        Blank lines are skipped; a line that does not parse throws, so a garbled read is reported as a
        failed read rather than as an issue with no block.
    #>
    param([AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines = @())

    $comments = @()
    foreach ($line in @($Lines)) {
        $text = ([string]$line).Trim()
        if (-not $text) { continue }
        $comment = $text | ConvertFrom-Json
        $comments += [pscustomobject]@{
            Association = [string]$comment.author_association
            Login       = [string]$comment.login
            Body        = [string]$comment.body
            CreatedAt   = [string]$comment.created_at
        }
    }
    return $comments
}

function Read-IssueComments {
    <#
        Every comment of the issue, read through gh (Get-IssueCommentsApiArgs), and whether the read
        worked at all: Ok, Comments, ExitCode, Error. A FAILED READ IS NOT AN ISSUE WITHOUT A
        BLOCK (#2875): the read this replaced discarded gh's stderr and answered an empty list, and the
        log then said 'none was on the issue' about an issue that carried one. Error is gh's own stderr
        -- an API or auth message, never a comment body -- so the caller can log it.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)

    $run = Invoke-GhCapture -GhArgs (Get-IssueCommentsApiArgs -IssueRef $IssueRef)
    if ($run.ExitCode -ne 0) {
        return [pscustomobject]@{ Ok = $false; Comments = @(); ExitCode = $run.ExitCode; Error = $run.Error }
    }
    try { $comments = @(ConvertFrom-IssueCommentLines -Lines $run.Out) } catch {
        return [pscustomobject]@{ Ok = $false; Comments = @(); ExitCode = 0; Error = 'gh exited 0, but its output did not parse as one comment per line.' }
    }
    return [pscustomobject]@{ Ok = $true; Comments = $comments; ExitCode = 0; Error = '' }
}

function Get-IssueReopenApiArgs {
    <#
        Pure: the gh arguments that read when an issue was reopened (#2968) -- REST again, like the
        comment read (#2875): 'gh api repos/<owner>/<repo>/issues/<n>/events', which 'issues: read' covers,
        paginated, with --jq keeping only the reopened events' created_at, one timestamp per line.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)

    if ($IssueRef -notmatch '\A([^\s#/]+)/([^\s#/]+)#([0-9]+)\z') { throw "IssueRef '$IssueRef' is not 'owner/repo#<n>'." }
    return @('api', "repos/$($Matches[1])/$($Matches[2])/issues/$($Matches[3])/events", '--paginate',
             '--jq', '.[] | select(.event == "reopened") | .created_at')
}

function ConvertFrom-ReopenEventLines {
    <#
        Pure: the LATEST reopen out of the lines the events read prints, as the timestamp text, or $null
        where there were none -- the issue was never reopened. A line that is not a timestamp throws, so
        a garbled read is reported as a failed read and never as an issue that was not reopened (#2968).
    #>
    param([AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines = @())

    $latest = $null
    $latestText = $null
    foreach ($line in @($Lines)) {
        $text = ([string]$line).Trim()
        if (-not $text) { continue }
        $at = ConvertTo-AsanaInstant -Value $text
        if ($null -eq $at) { throw 'a reopen event line is not a timestamp.' }
        if ($null -eq $latest -or $at -gt $latest) { $latest = $at; $latestText = $text }
    }
    return $latestText
}

function Read-LastReopen {
    <#
        When the issue was last reopened, read through gh (Get-IssueReopenApiArgs): Ok, LastReopenedAt
        ($null where it never was), ExitCode, Error -- the shape of the comment read, and a failed read
        is reported the same way (#2875). A FAILED READ IS NOT AN ISSUE THAT WAS NEVER REOPENED: the
        caller must not take it for one (Invoke-Main holds the block back, and says why).
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)

    $run = Invoke-GhCapture -GhArgs (Get-IssueReopenApiArgs -IssueRef $IssueRef)
    if ($run.ExitCode -ne 0) {
        return [pscustomobject]@{ Ok = $false; LastReopenedAt = $null; ExitCode = $run.ExitCode; Error = $run.Error }
    }
    try { $last = ConvertFrom-ReopenEventLines -Lines $run.Out } catch {
        return [pscustomobject]@{ Ok = $false; LastReopenedAt = $null; ExitCode = 0; Error = 'gh exited 0, but its output did not parse as one timestamp per line.' }
    }
    return [pscustomobject]@{ Ok = $true; LastReopenedAt = $last; ExitCode = 0; Error = '' }
}

function Get-ClosedMessageBlockPhrase {
    <#
        Pure: the half of the final log line that says what happened to the block. The cases are kept
        apart on purpose (#2875): a block was carried; the comments were read and none carried one; the
        comments could not be read, so nobody looked. Wherever no block went out, the message said the
        result message follows (#3004), and the phrase says so, so the log tells whoever reads the run
        that the assignee still owes the requester that message.
    #>
    param(
        [AllowEmptyString()][string]$Sections = '',
        [bool]$ReadOk = $true,
        # The carried block is a research block (#3004).
        [bool]$Research = $false,
        # How many go-live block comments the trust check did not carry (#2907): a dropped block and an
        # absent one are different facts, and they used to share 'none was on the issue'.
        [int]$Dropped = 0,
        # Why a block that WAS on the issue is not being carried (#2968): 'stale' (it predates the last
        # reopen) or 'unread' (the reopen could not be read, so whether it does is unknown).
        [string]$Held = ''
    )
    if ($Sections) { if ($Research) { return "with the session's research block" } return "with the session's go-live block" }
    $owed = "; the message says the result message follows, which the task's assignee still owes the requester"
    if ($Held -eq 'stale') { return "without a go-live block -- the only one on the issue predates its last reopen, so it describes an earlier round$owed" }
    if ($Held -eq 'unread') { return "without a go-live block -- one was on the issue, but when the issue was last reopened could not be read (the gh error is above), so whether it is stale is unknown$owed" }
    if (-not $ReadOk) { return "without a go-live block -- the comments could not be read (the gh error is above), so whether one was on the issue is unknown$owed" }
    if ($Dropped -gt 0) { return "without a go-live block -- one was on the issue but its author was not trusted (the reason is above)$owed" }
    return "without a go-live block -- none was on the issue$owed"
}

function Get-RepoStageCode {
    <#
        Pure: the section code the repo's Get-AsanaStageMap gives a stage -- 'Completed' by default, the
        stage whose column a reviewed task is moved to -- read from the TEXT of scripts/repo-config.ps1
        (#3017). '' when the file states no map or the map no such stage: the plugin's built-in map was
        retired with the CI mirror, so there is no default to fall back on, and the ask then names no
        section. A code is a number with at most one letter after it ('4', '3A'), quoted or bare.

        READ, NEVER RUN: the job holds ASANA_PAT, and dot-sourcing the repo's seam file would run whatever
        it does. Only the body of Get-AsanaStageMap is searched, up to the next function, and a line that
        is a comment does not count.
    #>
    param(
        [AllowEmptyString()][string]$ConfigText = '',
        [string]$Stage = 'Completed'
    )
    $start = [regex]::Match([string]$ConfigText, '(?im)^\s*function\s+Get-AsanaStageMap\b')
    if (-not $start.Success) { return '' }
    $body = $ConfigText.Substring($start.Index + $start.Length)
    $next = [regex]::Match($body, '(?im)^\s*function\s+')
    if ($next.Success) { $body = $body.Substring(0, $next.Index) }
    # The key opens a line or follows '{' or ';' (a one-line hashtable), and the value ends the entry.
    $m = [regex]::Match($body, "(?im)(?:^|[{;])\s*$([regex]::Escape($Stage))\s*=\s*['`"]?([0-9]+[A-Za-z]?)['`"]?(?=\s*(?:[;}#]|$))")
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

function Select-DoneSectionName {
    <#
        Pure: the one section among -Names whose code -- the text before its first '.', as
        Get-AsanaStageMap reads a board -- is -Code, compared without regard to case. '' when none is, or
        when more than one distinct name is (a task on two boards that disagree), because the ask must not
        guess which column the requester is looking at.
    #>
    param(
        [AllowEmptyCollection()][string[]]$Names = @(),
        [AllowEmptyString()][string]$Code = ''
    )
    if (-not $Code) { return '' }
    $hits = @(@($Names) | Where-Object {
        $m = [regex]::Match([string]$_, '^\s*([0-9]+[A-Za-z]?)\.')
        $m.Success -and $m.Groups[1].Value -ieq $Code
    } | ForEach-Object { ([string]$_).Trim() } | Select-Object -Unique)
    if ($hits.Count -eq 1) { return $hits[0] }
    return ''
}

function Resolve-DoneSectionName {
    <#
        The board's own name for the column a reviewed task moves to (#3017): the task's board
        memberships, then the sections of each of those boards, and the one whose code is -Code.
        Returns Name ('' when not found) and Why, a log phrase that never carries a section's or task's
        text. Every read failure is an answer, never a throw: the message goes out either way, and the ask
        then names no section. -Get is the read, injectable so the suite can drive it without a network.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [AllowEmptyString()][string]$Code = '',
        [string]$Pat = '',
        [scriptblock]$Get = $null
    )
    if (-not $Code) { return [pscustomobject]@{ Name = ''; Why = 'the repo states no Completed stage in Get-AsanaStageMap' } }
    if ($Gid -notmatch '\A[0-9]+\z') { return [pscustomobject]@{ Name = ''; Why = 'the task GID is not numeric' } }
    # No closure: invoked from here, the block sees $Pat through this function's scope, and it calls
    # whatever Invoke-RestMethod this script's scope resolves, which is how the suite stubs it.
    if (-not $Get) { $Get = { param($Uri) Invoke-RestMethod -Method GET -Uri $Uri -Headers @{ Authorization = "Bearer $Pat" } } }
    try {
        $task = & $Get "$script:AsanaApiBase/tasks/$($Gid)?opt_fields=memberships.project.gid"
    } catch { return [pscustomobject]@{ Name = ''; Why = 'the task could not be read' } }
    $projects = @(@($task.data.memberships) | ForEach-Object { [string]$_.project.gid } | Where-Object { $_ -match '\A[0-9]+\z' } | Select-Object -Unique)
    if ($projects.Count -eq 0) { return [pscustomobject]@{ Name = ''; Why = 'the task is on no board' } }
    $names = @()
    foreach ($p in $projects) {
        try {
            $sections = & $Get "$script:AsanaApiBase/projects/$p/sections?opt_fields=name"
        } catch { return [pscustomobject]@{ Name = ''; Why = "the sections of board $p could not be read" } }
        $names += @(@($sections.data) | ForEach-Object { [string]$_.name })
    }
    $name = Select-DoneSectionName -Names $names -Code $Code
    if ($name) { return [pscustomobject]@{ Name = $name; Why = "found by code $Code" } }
    return [pscustomobject]@{ Name = ''; Why = "no single section with code $Code on the task's board" }
}

function Invoke-Main {
    if ($IssueRef -notmatch '\A[^\s#/]+/[^\s#/]+#[0-9]+\z') { throw "IssueRef '$IssueRef' is not 'owner/repo#<n>'." }
    $decision = Get-ClosedMessageDecision -StateReason $StateReason -IssueBody $IssueBody -Event $Event `
        -Labels (ConvertFrom-IssueLabelList -Text $IssueLabels)
    if (-not $decision.Post) {
        Write-Host "$IssueRef -- $($decision.Why)"
        return
    }
    if (-not $AsanaPat) { throw 'ASANA_PAT is not set.' }

    if ($decision.Kind -eq 'reopened') {
        $html = New-ReopenedMessageHtml -IssueRef $IssueRef
    } elseif ($decision.Kind -eq 'on-hold') {
        $html = New-OnHoldMessageHtml -IssueRef $IssueRef
    } else {
        $read = Read-IssueComments -IssueRef $IssueRef
        if (-not $read.Ok) {
            # gh's own exit code and error text, never a comment body (#2875): a failed read used to be
            # silent, and then logged as an issue with no block on it.
            Write-Host "The comments of $IssueRef could not be read: gh exited $($read.ExitCode): $($read.Error)"
        }
        # The author of a block comment whose association is not trusted is asked about by repo permission
        # (#2907): a private org member reads as CONTRIBUTOR to this token.
        $permissions = @{}
        foreach ($login in (Get-PermissionCheckLogins -Comments $read.Comments)) {
            $perm = Read-CollaboratorPermission -IssueRef $IssueRef -Login $login
            if ($perm.Ok) { $permissions[$login] = $perm.Permission } else {
                $permissions[$login] = $null
                Write-Host "The repo permission of '$login' could not be read: gh exited $($perm.ExitCode): $($perm.Error)"
            }
        }
        $trusted = Select-TrustedCommentBodies -Comments $read.Comments -Permissions $permissions
        foreach ($note in $trusted.Notes) { Write-Host "Trust check: $note" }
        $dropped  = $trusted.Dropped
        $chosen   = Select-SessionPasteBlockBody -Bodies $trusted.Bodies
        $sections = if ($chosen) { Get-PasteBlockSections -Body $chosen } else { '' }
        $research = [bool]$chosen -and $chosen.Contains((Get-AsanaResearchBlockMarker))

        # A BLOCK FROM BEFORE THE LAST REOPEN IS NOT CARRIED (#2968). xoxowildhearts#414 closed after
        # round 1 with its block, was reopened, and closed again by the PR of round 2 -- whose block the
        # session posted only afterwards -- so the second closed message carried round 1's block as the
        # result of round 2. THE MISTAKE THAT COSTS LESS IS CHOSEN: a requester told a result is still
        # coming waits, and a requester sent round 1's link as round 2's result acts on the wrong thing.
        # The same holds where the reopen could not be read: that costs the block, and the message says the
        # result follows (#3004), the same as an unreadable comment read -- never a block that might be stale. The read is made only when
        # a block is there to judge, so an issue without one costs no extra call.
        $held = ''
        if ($sections) {
            $state = Get-AsanaPasteBlockVerdict -Comments $trusted.Comments -LastReopenedAt $null
            if ($state -ne 'none') {
                $reopen = Read-LastReopen -IssueRef $IssueRef
                if (-not $reopen.Ok) {
                    Write-Host "When $IssueRef was last reopened could not be read: gh exited $($reopen.ExitCode): $($reopen.Error)"
                    $held = 'unread'
                } else {
                    $verdict = Get-AsanaPasteBlockVerdict -Comments $trusted.Comments -LastReopenedAt $reopen.LastReopenedAt
                    if ($verdict -eq 'stale') { $held = 'stale' }
                    elseif ($verdict -eq 'unknown') { $held = 'unread' }
                }
                if ($held) { $sections = ''; $research = $false }
            }
        }
        # NO SECTIONS IS NEVER THE CLOSED LINE ALONE (#3004): New-ClosedMessageHtml adds that the result
        # message follows, whichever of the reasons above left the block out.
        # A RESEARCH CLOSE NAMES THE BOARD'S OWN DONE SECTION IN ITS CLOSING ASK (#3017), never a fixed
        # '4. Done'. The reads are made only here, so every other message costs nothing extra.
        $done = ''
        if ($research -and $sections) {
            $configText = ''
            $configPath = if ($RepoConfigPath) { $RepoConfigPath } else { Join-Path $PSScriptRoot '../../scripts/repo-config.ps1' }
            if (Test-Path -LiteralPath $configPath -PathType Leaf) {
                $configText = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $configPath).ProviderPath)
            }
            $resolved = Resolve-DoneSectionName -Gid $decision.Gid -Code (Get-RepoStageCode -ConfigText $configText) -Pat $AsanaPat
            $done = $resolved.Name
            Write-Host "Done section for the closing ask: $(if ($done) { 'named' } else { 'not named' }) -- $($resolved.Why)."
        }
        $html = New-ClosedMessageHtml -IssueRef $IssueRef -BlockSections $sections -Research:$research -DoneSection $done
    }
    $request = New-AsanaCommentRequest -Gid $decision.Gid -Html $html
    # UTF-8 BYTES, not the string: Windows PowerShell 5.1 encodes a string body as ISO-8859-1, which
    # would turn the header's em dash into '?'. pwsh sends UTF-8 either way.
    $headers = @{ Authorization = "Bearer $AsanaPat"; 'Content-Type' = 'application/json; charset=utf-8' }
    try {
        Invoke-RestMethod -Method $request.Method -Uri $request.Uri -Headers $headers `
            -Body ([System.Text.Encoding]::UTF8.GetBytes([string]$request.Body)) | Out-Null
    } catch {
        $status = $null
        if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        throw "Asana refused the $Event message for task $($decision.Gid) (HTTP $(if ($status) { $status } else { 'status unknown' }))."
    }
    if ($decision.Kind -eq 'reopened') {
        Write-Host "Asana task $($decision.Gid) told: $IssueRef is reopened and back in development ($($decision.Why)). The card was NOT moved."
        return
    }
    if ($decision.Kind -eq 'on-hold') {
        Write-Host "Asana task $($decision.Gid) told: $IssueRef is on hold, closed as not planned while waiting for more information ($($decision.Why)). The card was NOT moved."
        return
    }
    $with = Get-ClosedMessageBlockPhrase -Sections $sections -ReadOk $read.Ok -Dropped $dropped -Held $held -Research $research
    Write-Host "Asana task $($decision.Gid) told: $IssueRef is closed, $with ($($decision.Why)). The task was NOT completed -- that is the requester's call."
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
