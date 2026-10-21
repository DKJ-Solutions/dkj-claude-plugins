<#
.SYNOPSIS
    The Asana task helpers this plugin's task scripts still share now that the asana-mirror CI
    workflow is retired: which Asana task an issue body links (Resolve-AsanaTaskRef), reading that
    task (Get-AsanaTaskState), and the marker and lead of the go-live block an issue comment carries
    (Get-AsanaPasteBlockMarker, Get-AsanaPasteBlockLead, Test-AsanaPasteBlockPosted), and whether the
    newest block predates the issue's last reopen (Get-AsanaPasteBlockVerdict, Read-AsanaIssueBlockState,
    #2968) -- the judgement guard-stale-paste-block.ps1 refuses a ship on, and build-golive-block.ps1's
    duplicate check counts only blocks posted since that reopen with.

.DESCRIPTION
    MOVED OUT OF templates/asana-mirror.ps1 WHEN THAT TEMPLATE WAS RETIRED (Dave, October 5, 2026).
    build-backlog-page.ps1 and build-golive-block.ps1 used to dot-source the whole CI template for these
    few pure helpers; with the template gone they live here, beside the other libs those two scripts
    already load. Nothing in this file writes to Asana: Get-AsanaTaskState only reads. The go-live block
    reaches the Asana task through the asana-closed-message CI workflow (#2818), whose template carries
    its own copies of the matchers and the marker below, because it ships standalone.

    Console text goes through ConvertTo-ConsoleStrippedText from ref-print-lib.ps1, dot-sourced below,
    rather than a private copy: the template carried its own copy only because it shipped standalone
    into a consumer's .github/scripts/, and this lib does not.

    STILL SELF-CONTAINED: this file lives inside bwj-development's own scripts\lib\, so a script that
    dot-sources it is not reaching into a second plugin's libs.

    Pure ASCII (repo convention for .ps1).
#>

. (Join-Path $PSScriptRoot 'ref-print-lib.ps1')

$script:AsanaApiBase = 'https://app.asana.com/api/1.0'

function Get-AsanaGidsFromText {
    <#
        Return the distinct task GIDs of every Asana task URL in a piece of text, in the order they
        first appear. Both URL shapes Asana hands out are read:

            https://app.asana.com/1/<workspace>/project/<project>/task/<task>
            https://app.asana.com/0/<project>/<task>

        A URL that names no task (a project or portfolio link) contributes nothing.
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
        Return the contents of an imported ticket's '| **Asana** | ... |' header row, or '' when the
        body has no such row. Anchored on the row label, so a link to a sibling ticket elsewhere in
        the body cannot be mistaken for this ticket's own task.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$IssueBody)

    $m = [regex]::Match($IssueBody, '(?m)^\|\s*\*{0,2}Asana\*{0,2}\s*\|(.*)$')
    if (-not $m.Success) { return '' }
    return $m.Groups[1].Value
}

function Resolve-AsanaTaskRef {
    <#
        Resolve which Asana task an issue body belongs to. Returns an object with:

            Gid         the numeric task GID as a string, or $null
            Source      'marker' | 'header-row' | 'sole-url' | 'ambiguous' | 'none'
            Candidates  the distinct GIDs seen, for the 'ambiguous' report

        Pure -- no network. Non-numeric content never matches, so it can never reach a request URL.
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

function Get-AsanaTaskState {
    <#
        Read a task's 'completed' flag. Returns $null when the task cannot be read -- it was deleted,
        or it lives in a workspace this PAT has no access to. That is reported and skipped rather
        than thrown, so one unreachable ticket cannot end a run over all of them.

        Read-only: nothing in this lib writes to Asana.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [Parameter(Mandatory = $true)][string]$Pat,

        # The fields to ask Asana for. The default keeps every existing caller unchanged; the label
        # sweep asks for the custom fields on top of it.
        [string]$OptFields = 'completed,name'
    )
    if ($Gid -notmatch '^[0-9]+$') { throw "Refusing to read a non-numeric task GID: '$Gid'." }
    $uri = "$script:AsanaApiBase/tasks/$Gid" + "?opt_fields=$OptFields"
    try {
        $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers @{ Authorization = "Bearer $Pat" }
        return $resp.data
    } catch {
        Write-Host "  Asana task $Gid is not readable with this token ($(ConvertTo-ConsoleStrippedText -Text $_.Exception.Message)) -- skipped."
        return $null
    }
}

function Get-AsanaPasteBlockMarker {
    <#
        The machine marker build-golive-block.ps1 puts on the paste-ready block's GitHub comment. Pure.

        An HTML comment, for the same reason the asana-task link uses one: it is the only form that
        cannot be misread, and it renders as nothing. It sits in the FRAMING text and never inside
        the block itself, because the block is pasted into Asana and a marker that travelled with it
        would arrive there as visible junk.
    #>
    return '<!-- asana-paste-block -->'
}

function Get-AsanaResearchBlockMarker {
    <#
        The second marker build-golive-block.ps1 -Research puts on a block that reports an OUTCOME rather
        than a result to look at (#3004): a research, test or decision ticket, where nothing changed on
        the store. Pure. The closed message reads it to write the research form (#3017, its second line
        #3069's: 'Nothing has changed. Read the outcome below.', the outcome as a list, and the closing
        ask) instead of the reopen line, which promises a result that can be 'not working as
        expected'. It sits beside the block's own marker, outside the
        rules, for the same reason that one does. A copy of it lives in templates/asana-closed-message.ps1.
    #>
    return '<!-- asana-paste-block-kind: research -->'
}

function Get-AsanaMeasureBlockMarker {
    <#
        The second marker build-golive-block.ps1 -Measure puts on a block whose result is a number the
        requester measures again (#3179). Pure. The closed message reads it to write the measurement form
        instead of the reopen line or the research form, and to close with the measurement ask. A copy
        of it lives in templates/asana-closed-message.ps1.
    #>
    return '<!-- asana-paste-block-kind: measure -->'
}

function Get-AsanaAlreadyFixedBlockMarker {
    <#
        The second marker build-golive-block.ps1 -AlreadyFixed puts on a block for a ticket an earlier
        release had already fixed (#3242): verified, and nothing changed in this round. Pure. The closed
        message reads it to say so under the intro instead of the reopen line or 'Nothing has changed', and
        to close with the already-fixed ask. A copy of it lives in templates/asana-closed-message.ps1.
    #>
    return '<!-- asana-paste-block-kind: already-fixed -->'
}

function Get-AsanaHandBlockMarker {
    <#
        The second marker build-golive-block.ps1 -ByHand puts on a block that records a closed message
        POSTED BY HAND on the Asana task (#3183): the requester approved a message in a form the
        automation does not have, and the workflow must not post its own beside it. Pure. The closed
        message reads it and posts nothing; the close guard accepts the block like any other, so the
        guard's intent -- the requester always gets a message -- holds, and the hand route is visible on
        the issue. A copy of it lives in templates/asana-closed-message.ps1.
    #>
    return '<!-- asana-paste-block-kind: by-hand -->'
}

function Get-AsanaReleaseBlockMarker {
    <#
        The second marker build-golive-block.ps1 puts on a result block that names a PLANNED release day
        rather than -LiveSince (#3069): built, but visible only once that release is out. Pure. The
        closed message reads it to say so under its intro instead of implying the requester can look
        now; a block without it -- a -LiveSince block, or one posted before #3069 -- keeps the plain
        reopen line. It sits beside the block's own marker, outside the rules, for the same reason that
        one does. A copy of it lives in templates/asana-closed-message.ps1.
    #>
    return '<!-- asana-paste-block-kind: after-release -->'
}

function Get-AsanaPasteBlockLead {
    <#
        The block's own opening sentence -- the prose half of the de-duplication below, and the
        second matcher for a block a person typed rather than pasted. Pure.
    #>
    return 'Fill in the link below and paste the block into the Asana task'
}

function ConvertTo-AsanaInstant {
    <#
        Pure: a GitHub timestamp as a UTC [datetime], or $null when it is empty or does not parse. Takes
        the ISO string ('2026-10-13T08:15:00Z') or a [datetime] -- Windows PowerShell 5.1's
        ConvertFrom-Json already turns such a string into a LOCAL-kind datetime, so both shapes are
        normalised to UTC before anything is compared (#2968). A copy of it lives in
        templates/asana-closed-message.ps1.
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

function Get-PasteBlockSections {
    <#
        Pure: the sections of a go-live block -- the text between its two '---' rules, minus the
        lines this message composes itself (the header and the closed line). '' when there is no block.
        A copy of templates/asana-closed-message.ps1's function of this name (#2968): the hook and
        build-golive-block.ps1 judge a block by the same sections the closed message carries.
        The header is dropped by SHAPE (the first non-blank line, opening with an em dash), so a block
        posted under an older header is carried without it too.
        THE CLOSED LINE CAN RUN ON TO A SECOND LINE (#3069): the intro, then the line that tells the
        forms apart, with no blank line between them. That line is the message's own as well, so it is
        dropped with the intro -- unless it is a section heading, which a block written before #3069
        never had directly under its one-line closed line, but a hand-typed one might.
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
        if ($at -lt $inner.Count -and $inner[$at].StartsWith('GitHub issue ')) {
            $at++
            if ($at -lt $inner.Count -and $inner[$at].Trim() -and $inner[$at] -cnotmatch '^[A-Z][A-Z /]*[A-Z]$') { $at++ }
        }
    }
    $rest = @(if ($at -lt $inner.Count) { $inner[$at..($inner.Count - 1)] })
    return (($rest -join "`n").Trim())
}

function Test-AsanaPasteBlockBody {
    <#
        Pure: is this comment body a go-live block the closed message would CARRY? The marker, and
        sections Get-PasteBlockSections finds that are not empty and hold no '[ADD LINK]' placeholder --
        exactly the predicate Select-SessionPasteBlockSections picks a block by (#2968). It is ONE
        predicate on purpose: a freshness check that accepted a comment the selection then skipped (a
        marker with two adjacent rules, a header-only block) would call the issue fresh while the
        message carried the older round's block, which is the failure #2968 measured.
        A copy of it lives in templates/asana-closed-message.ps1.
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
        A copy of it lives in templates/asana-closed-message.ps1.
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

function Test-AsanaPasteBlockSinceReopen {
    <#
        Pure: is a paste-ready block already on the issue FOR THIS ROUND -- a comment carrying the marker
        or the lead sentence, posted after the issue's last reopen (every comment counts where it was
        never reopened)? The duplicate check of build-golive-block.ps1 -Post (#2968): a block that
        predates the reopen belongs to the round before, and refusing a second one made the right route,
        the corrected block, the awkward one while the stale one went on to the requester. A comment
        whose time cannot be read counts as a block, the cautious answer for a duplicate check.
    #>
    param(
        [AllowEmptyCollection()][object[]]$Comments = @(),
        $LastReopenedAt = $null
    )

    $marker = Get-AsanaPasteBlockMarker
    $lead   = Get-AsanaPasteBlockLead
    $reopen = if ($null -ne $LastReopenedAt) { ConvertTo-AsanaInstant -Value $LastReopenedAt } else { $null }
    foreach ($c in @($Comments)) {
        $body = [string]$c.Body
        if (-not $body) { continue }
        if (-not ($body.Contains($marker) -or $body.Contains($lead))) { continue }
        if ($null -eq $LastReopenedAt) { return $true }
        $at = ConvertTo-AsanaInstant -Value $c.CreatedAt
        if ($null -eq $reopen -or $null -eq $at -or $at -gt $reopen) { return $true }
    }
    return $false
}

function ConvertFrom-AsanaIssueBlockStateJson {
    <#
        Pure: the reply of the one GraphQL read below as Ok, Body (the issue's own body, '' where the reply
        carries none), Comments (Body, CreatedAt), LastReopenedAt (the latest reopened event's createdAt,
        or $null) and Truncated ($true where the issue has more comments than the read returned). A reply
        that is not JSON, or names no issue, is Ok = $false. Body serves the close guard (#3004), which
        asks Resolve-AsanaTaskRef whether the issue links a task before it judges the block.
    #>
    param([AllowEmptyString()][string]$Json)

    $bad = [pscustomobject]@{ Ok = $false; Body = ''; Comments = @(); LastReopenedAt = $null; Truncated = $false }
    if (-not ([string]$Json).Trim()) { return $bad }
    try { $issue = (ConvertFrom-Json -InputObject $Json).data.repository.issue } catch { return $bad }
    if ($null -eq $issue -or $null -eq $issue.comments -or $null -eq $issue.reopened) { return $bad }

    $comments = @(foreach ($n in @($issue.comments.nodes)) { [pscustomobject]@{ Body = [string]$n.body; CreatedAt = $n.createdAt } })
    $reopen   = $null
    foreach ($n in @($issue.reopened.nodes)) { if ($n -and $n.createdAt) { $reopen = $n.createdAt } }
    $body = if ($issue.PSObject.Properties['body']) { [string]$issue.body } else { '' }
    return [pscustomobject]@{
        Ok             = $true
        Body           = $body
        Comments       = $comments
        LastReopenedAt = $reopen
        Truncated      = ([int]$issue.comments.totalCount -gt $comments.Count)
    }
}

function Invoke-AsanaGhBounded {
    <#
        gh with these arguments, bounded (#2968): Started, TimedOut, ExitCode, Out, Err. ONE runner for
        the hook's reads and Read-AsanaIssueBlockState, so a fix to the bound lands in both. -Arguments
        is the command-line string handed to gh as is, so a caller puts only validated text in it. The
        process is killed past -TimeoutMs, which is how a hung gh cannot outlast a hook's ceiling.
        Read-only in itself; what gh does is the caller's arguments.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Arguments,
        [int]$TimeoutMs = 20000,
        [string]$WorkingDirectory = ''
    )

    $r = [pscustomobject]@{ Started = $false; TimedOut = $false; ExitCode = -1; Out = ''; Err = '' }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'gh'
        $psi.Arguments = $Arguments
        if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $p = [System.Diagnostics.Process]::Start($psi)
        $r.Started = $true
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutMs)) {
            try { $p.Kill() } catch { }
            $r.TimedOut = $true
            return $r
        }
        $r.ExitCode = $p.ExitCode
        $r.Out = [string]$outTask.Result
        $r.Err = [string]$errTask.Result
    } catch { }
    return $r
}
function Read-AsanaIssueBlockState {
    <#
        An issue's comments and its last reopen, in ONE bounded GraphQL call (#2968): Ok, Comments,
        LastReopenedAt, Truncated, Error. GraphQL, because REST would take two paginated reads (the
        comments and the events) where this takes one, and the caller is a session at its desk -- the
        hook before a merge, the post of a block -- not the Actions runner whose GraphQL read answered
        nothing (#2875), which is why the closed-message template keeps REST. The last 100 comments are
        read; Truncated says an older one was not, and a caller that found no block must then not
        conclude there is none. Bounded by -TimeoutMs through Invoke-AsanaGhBounded. Read-only.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Owner,
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][int]$Number,
        [int]$TimeoutMs = 20000,
        [string]$WorkingDirectory = ''
    )

    $fail = { param($why) [pscustomobject]@{ Ok = $false; Body = ''; Comments = @(); LastReopenedAt = $null; Truncated = $false; Error = $why } }
    # The owner and name go onto a command line, so only GitHub's own character classes pass.
    if ($Owner -notmatch '\A[A-Za-z0-9][A-Za-z0-9-]*\z' -or $Repo -notmatch '\A[A-Za-z0-9._-]+\z') { return (& $fail 'the repo is not an owner/name pair') }

    $query = 'query($owner:String!,$name:String!,$num:Int!){repository(owner:$owner,name:$name){issue(number:$num){body ' +
        'reopened:timelineItems(itemTypes:[REOPENED_EVENT],last:1){nodes{... on ReopenedEvent{createdAt}}} ' +
        'comments(last:100){totalCount nodes{body createdAt}}}}}'
    $run = Invoke-AsanaGhBounded -Arguments "api graphql -f query=`"$query`" -f owner=$Owner -f name=$Repo -F num=$Number" -TimeoutMs $TimeoutMs -WorkingDirectory $WorkingDirectory
    if ($run.TimedOut) { return (& $fail 'gh did not answer in time') }
    if (-not $run.Started) { return (& $fail 'gh could not be run') }
    if ($run.ExitCode -ne 0) { return (& $fail "gh exited $($run.ExitCode)") }
    $state = ConvertFrom-AsanaIssueBlockStateJson -Json $run.Out
    $state | Add-Member -NotePropertyName Error -NotePropertyValue $(if ($state.Ok) { '' } else { 'the reply did not parse or named no issue' })
    return $state
}

function Test-AsanaPasteBlockPosted {
    <#
        Has a paste-ready block already been written on this issue FOR THE CURRENT ROUND? Reads the
        issue's comments and its last reopen (Read-AsanaIssueBlockState) and looks, among the comments
        posted after that reopen, for the marker or -- for a block somebody typed by hand -- the lead
        sentence Get-AsanaPasteBlockLead returns, which WORKFLOW-portable.md publishes for exactly that
        case (build-golive-block.ps1 writes a different framing sentence and is found by the marker).
        The same two-matcher shape, and the same ordering, as the task link itself: the machine marker
        first and unconditionally, prose second.

        ONLY A BLOCK AFTER THE LAST REOPEN COUNTS (#2968). A block from before it describes the round
        before; xoxowildhearts#414 carried one into the Asana task as the second round's result because
        replacing it needed -Force. Test-AsanaPasteBlockSinceReopen holds the rule.

        AN UNREADABLE ISSUE ANSWERS $true, so a run that cannot check does not comment blindly. The
        cost of each mistake is what settles it: a skipped post can be repeated with -Force once the
        comments are readable again, while a blind post puts a second copy underneath a block that
        was already there. So does an issue with more comments than one read returns and no block among
        them: the older ones were not looked at.

        A LOOSE SUBSTRING MATCH, AND ANYBODY WHO CAN COMMENT CAN SUPPRESS THIS. Either matcher
        anywhere in any comment answers $true -- including a comment that QUOTES WORKFLOW-portable.md,
        which publishes both strings verbatim so a session can write the block by hand. That is
        accepted rather than tightened: build-golive-block.ps1 -Force posts regardless. Tightening
        it (an exact whole-comment compare, or an author check) would buy nothing against a person who can equally well delete
        the real block, and would cost the hand-written case the marker exists to serve.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)

    $parts = $IssueRef -split '#'
    $repoParts = $parts[0] -split '/', 2
    $number = 0
    $state = $null
    if ($repoParts.Count -eq 2 -and [int]::TryParse($parts[1], [ref]$number)) {
        $state = Read-AsanaIssueBlockState -Owner $repoParts[0] -Repo $repoParts[1] -Number $number
    }
    if ($null -eq $state -or -not $state.Ok) {
        Write-Host "  Comments of $IssueRef are not readable -- no paste-ready block posted, rather than posting one blindly."
        return $true
    }
    if (Test-AsanaPasteBlockSinceReopen -Comments $state.Comments -LastReopenedAt $state.LastReopenedAt) { return $true }
    if ($state.Truncated) {
        Write-Host "  $IssueRef has more comments than were read -- no paste-ready block posted, rather than posting one blindly."
        return $true
    }
    return $false
}
