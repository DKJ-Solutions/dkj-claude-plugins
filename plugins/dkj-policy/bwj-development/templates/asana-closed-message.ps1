<#
.SYNOPSIS
    Post the closed message on the Asana task a GitHub issue belongs to when that issue closes as
    completed, and the reopened message when it is reopened. Copied into a BWJ store repo as
    .github/scripts/asana-closed-message.ps1 and driven by .github/workflows/asana-closed-message.yml.

.DESCRIPTION
    THE TWO MESSAGES THAT CAME BACK. The asana-mirror workflow was retired on October 5, 2026, whole
    (#2804): card moves, the daily sweeps, the prio-label sync, and the created, reopened and closed
    comments. Asked which part to bring back, Dave chose the closed message, in the go-live block's
    current shape (#2818); a day later he brought back the reopened message beside it (#2854), because
    without it a requester can go on testing a result that is being reworked. Everything else stays
    retired, and nothing in this file can move a card, complete a task or write a label: the one write it
    knows how to build is a comment (New-AsanaCommentRequest).

    THE FILE KEEPS ITS 'closed-message' NAME ON PURPOSE. A store holds it at a fixed path, and adopt
    copies by path: a renamed template would land beside the old one rather than replace it, and both
    would post on every close.

    WHAT IT POSTS, AND WHEN:

      - A close as COMPLETED with a linked task: one comment, as html_text. The automation's header,
        the closed line, and under it the sections of the go-live block the shipping session left on
        the issue (build-golive-block.ps1). That block is the "new form": TE BEKIJKEN OP, WAT ER NU
        ANDERS IS, WANNEER HET LIVE KOMT, WAT ER BEWUST NIET IN ZIT, WAT WE VAN JE VRAGEN.
      - A close as completed with NO block on the issue: the header and the closed line alone, so the
        requester still hears that the work is done. A proposal in #2818 rather than a decision.
      - A close as NOT PLANNED, or as a DUPLICATE: nothing. Nothing was built, so there is nothing to
        test (#2765).
      - A REOPEN with a linked task, whatever the earlier close reason: one comment, the header and the
        reopened line in the requester's fixed form (#2656) -- 'reopened: this Asana task is back in
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
    the automation's header. THE TASK IT WRITES TO is the one the issue body's marker names, and whoever
    can edit the body can point that marker at any task the token reaches. That is the retired
    asana-mirror's trust model unchanged, and it is accepted rather than closed here: the write is one
    comment, and checking the task's project would need a project read this workflow deliberately does
    without. A reopen (#2854) is one more trigger on that same model, not a new one: an issue's author
    can reopen it, but what a reopen posts is fixed text, with nothing from the issue in it.

    IT PRINTS NOTHING ANOTHER PERSON WROTE. The only foreign text this run could meet is a task name or
    an API error message, and neither is printed: a failed post reports its HTTP status and nothing else.

    Auth: ASANA_PAT (the repo secret). GH_TOKEN is the workflow's own token, used to read the issue's
    comments for the block. There is no project, workspace or Projects token: a comment addresses its
    task by GID alone.

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
    # github.event.action: which of the two messages this run is for.
    [ValidateSet('closed', 'reopened')]
    [string]$Event = 'closed',
    [string]$AsanaPat = $env:ASANA_PAT
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

function New-ClosedMessage {
    <#
        Pure: the closed comment as plain text -- the header, a blank line, and the closed sentence
        (#2700). It is the go-live block's own opening, so the two read the same.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)
    return (@((Get-ClosedMessageHeader), '', "GitHub issue $IssueRef is now closed. It can be reopened anytime when something is still not working as expected.") -join "`n")
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
    #>
    param([AllowEmptyString()][string]$Markdown)

    $esc = { param($s) ConvertTo-AsanaXmlText -Text $s }
    $out = foreach ($line in (([string]$Markdown) -split "`r?`n")) {
        if ($line -cmatch '^[A-Z][A-Z /]*[A-Z]$') { "<strong>$(& $esc $line)</strong>"; continue }
        $sb  = New-Object System.Text.StringBuilder
        $pos = 0
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
        $sb.ToString()
    }
    return (@($out) -join "`n")
}

function New-ClosedMessageHtml {
    <#
        Pure: the closed message as Asana html_text -- the header, the closed sentence with the issue
        name as a link and 'closed' in bold (the requester's form, #2656), and the block's sections
        under it where -BlockSections carries any. Only <body>, <a> and <strong>, all on Asana's
        allow-list for a story.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [AllowEmptyString()][string]$BlockSections = ''
    )

    $esc   = { param($s) ConvertTo-AsanaXmlText -Text $s }
    $parts = $IssueRef -split '#'
    $url   = "https://github.com/$($parts[0])/issues/$($parts[1])"
    $html  = "<body>$(& $esc (Get-ClosedMessageHeader))`n`nGitHub issue <a href=`"$(& $esc $url)`">$(& $esc $IssueRef)</a> is now <strong>closed</strong>. It can be reopened anytime when something is still not working as expected."
    if ($BlockSections) { $html += "`n`n" + (ConvertTo-AsanaStoryHtml -Markdown $BlockSections) }
    return $html + '</body>'
}

function New-ReopenedMessage {
    <#
        Pure: the reopened comment as plain text -- the header, a blank line, and the reopened sentence
        in the requester's fixed form (#2656), brought back by #2854.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)
    return (@((Get-ClosedMessageHeader), '', "GitHub issue $IssueRef reopened: this Asana task is back in development.") -join "`n")
}

function New-ReopenedMessageHtml {
    <#
        Pure: the reopened message as Asana html_text -- the header, then the reopened sentence with the
        issue name as a link and 'reopened:' in bold, the same form the closed line takes.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)

    $esc   = { param($s) ConvertTo-AsanaXmlText -Text $s }
    $parts = $IssueRef -split '#'
    $url   = "https://github.com/$($parts[0])/issues/$($parts[1])"
    return "<body>$(& $esc (Get-ClosedMessageHeader))`n`nGitHub issue <a href=`"$(& $esc $url)`">$(& $esc $IssueRef)</a> <strong>reopened:</strong> this Asana task is back in development.</body>"
}

function Get-AsanaPasteBlockMarker {
    <#
        Pure: the machine marker build-golive-block.ps1 puts on the comment carrying the block. A copy
        of asana-task-lib.ps1's function of this name.
    #>
    return '<!-- asana-paste-block -->'
}

function Select-SessionPasteBlockSections {
    <#
        Pure: out of an issue's comment bodies, the sections of the NEWEST block carrying the marker
        that is not a placeholder copy ('[ADD LINK]'). '' when there is none.
    #>
    param([string[]]$Bodies = @())

    $marker = Get-AsanaPasteBlockMarker
    $list = @($Bodies)
    for ($i = $list.Count - 1; $i -ge 0; $i--) {
        $body = [string]$list[$i]
        if (-not $body.Contains($marker)) { continue }
        $sections = Get-PasteBlockSections -Body $body
        if ($sections -and -not $sections.Contains('[ADD LINK]')) { return $sections }
    }
    return ''
}

function Get-ClosedMessageDecision {
    <#
        Pure: whether this close or reopen gets a message, and why not where it does not. Post is $true
        for a reopen, or a close as completed (or one with no reason, which GitHub treated as completed),
        on an issue whose body resolves to exactly one task. A reopen ignores the close reason: whatever
        the issue was closed as, it is in development now (#2854).
    #>
    param(
        [AllowEmptyString()][string]$StateReason = '',
        [AllowEmptyString()][string]$IssueBody = '',
        [ValidateSet('closed', 'reopened')][string]$Event = 'closed'
    )

    $reason = ([string]$StateReason).Trim().ToLowerInvariant()
    if ($Event -eq 'closed' -and $reason -and $reason -ne 'completed') {
        return [pscustomobject]@{ Post = $false; Gid = $null; Why = "closed as '$reason' -- nothing was built, so the task is told nothing (#2765)." }
    }
    $ref = Resolve-AsanaTaskRef -IssueBody $IssueBody
    if ($ref.Source -eq 'ambiguous') {
        return [pscustomobject]@{ Post = $false; Gid = $null; Why = "the body links several different Asana tasks ($($ref.Candidates -join ', ')) -- refusing to guess. Add an explicit <!-- asana-task: GID --> marker to settle it." }
    }
    if (-not $ref.Gid) {
        return [pscustomobject]@{ Post = $false; Gid = $null; Why = 'no Asana task is linked from the issue -- nothing to tell.' }
    }
    return [pscustomobject]@{ Post = $true; Gid = $ref.Gid; Why = "matched by $($ref.Source)" }
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

function Get-IssueCommentBodies {
    <#
        The bodies of the issue's comments by a trusted author (Test-TrustedCommentAuthor), read through
        gh. An unreadable issue answers none -- the closed message then goes out without a block, which
        still tells the requester the work is done.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)

    $parts = $IssueRef -split '#'
    $prev = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $raw = & gh issue view $parts[1] --repo $parts[0] --json comments 2>$null
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    if ($code -ne 0 -or -not $raw) { return @() }
    try { $comments = (($raw | Out-String) | ConvertFrom-Json).comments } catch { return @() }
    return @(@($comments) | Where-Object { Test-TrustedCommentAuthor -Association ([string]$_.authorAssociation) } | ForEach-Object { [string]$_.body })
}

function Invoke-Main {
    if ($IssueRef -notmatch '\A[^\s#/]+/[^\s#/]+#[0-9]+\z') { throw "IssueRef '$IssueRef' is not 'owner/repo#<n>'." }
    $decision = Get-ClosedMessageDecision -StateReason $StateReason -IssueBody $IssueBody -Event $Event
    if (-not $decision.Post) {
        Write-Host "$IssueRef -- $($decision.Why)"
        return
    }
    if (-not $AsanaPat) { throw 'ASANA_PAT is not set.' }

    if ($Event -eq 'reopened') {
        $html = New-ReopenedMessageHtml -IssueRef $IssueRef
    } else {
        $sections = Select-SessionPasteBlockSections -Bodies (Get-IssueCommentBodies -IssueRef $IssueRef)
        $html     = New-ClosedMessageHtml -IssueRef $IssueRef -BlockSections $sections
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
    if ($Event -eq 'reopened') {
        Write-Host "Asana task $($decision.Gid) told: $IssueRef is reopened and back in development ($($decision.Why)). The card was NOT moved."
        return
    }
    $with = if ($sections) { "with the session's go-live block" } else { 'without a go-live block -- none was on the issue' }
    Write-Host "Asana task $($decision.Gid) told: $IssueRef is closed, $with ($($decision.Why)). The task was NOT completed -- that is the requester's call."
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
