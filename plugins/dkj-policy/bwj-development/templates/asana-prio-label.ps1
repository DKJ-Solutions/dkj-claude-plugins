<#
.SYNOPSIS
    Carry the Asana task's Prio-Score onto the GitHub issue as ONE prio-N label (prio-1 lowest, prio-4
    highest). Copied into a BWJ store repo as .github/scripts/asana-prio-label.ps1 and driven by
    .github/workflows/asana-prio-label.yml, on an issue being opened or edited and on a daily sweep.

.DESCRIPTION
    THE PART OF THE RETIRED MIRROR THAT CAME BACK (#2945). The asana-mirror workflow was retired on
    October 5, 2026, whole (#2804), and two comments came back as asana-closed-message (#2818, #2854).
    Asked about the third part, Dave brought the Prio-Score -> prio-N label sync back on October 12,
    2026, with two triggers: an issue opened or edited, plus a daily sweep. This is that sync and nothing
    else. It lives in its OWN file, not in asana-closed-message, because that workflow holds 'issues:
    read' and says it never writes a label; this one holds 'issues: write' and writes nothing but labels.

    THE ONE GITHUB WRITE is 'gh issue edit' adding or removing a label from the four-name set
    prio-1..prio-4 (Set-IssuePrioLabel). It never writes to Asana, moves a card, completes a task or
    posts a comment, and no other label is ever touched.

    THE MAPPING (Dave, September 2, 2026; renamed onto the family's vocabulary in #1842, bands untouched):

        1.00-1.99  prio-1       3.00-3.99  prio-3
        2.00-2.99  prio-2       4.00-5.00  prio-4

    Each band is closed at the bottom and open at the top. A score outside 1.00-5.00, and a task with no
    score, name NO label.

    WHAT IT LEAVES ALONE, ON PURPOSE. A label is only ever changed when a task is found AND it carries a
    valid score. An issue with no linked task (or several different ones), an unreadable task, an
    unscored task and an out-of-range score all leave the issue's labels exactly as they are: an absent
    score is never read as 'remove the label', so a label a person set by hand survives. Nothing here
    sweeps the pre-#1842 label names (prio-low and its kin): the retired mirror dropped them when the
    migration window closed, and a store still carrying one is a one-time rename, not this script's job.

    EXACTLY ONE prio label comes out of a scored issue: the matching one is added if missing, and every
    OTHER prio-N the issue carries is removed, so a task rescored from 2.5 to 4.2 does not leave an issue
    claiming two priorities. Nothing is done when the issue already reads right, so a re-run is quiet.

    TWO MODES (-Mode):

      event  ONE issue, from the workflow's issue event: -IssueRef 'owner/repo#<n>' and the body in
             ISSUE_BODY (so the body, and the task it links, are the payload's). The issue's
             CURRENT labels are read live through gh, not taken from the payload. That narrows, but does
             not close, a race: a run still working from an older body can briefly write the label that
             body names until the newer run corrects it. A failed read stops the run rather than guessing.
      sweep  EVERY open issue of the repo (GITHUB_REPOSITORY), 'gh issue list --state open --limit 1000'.
             It catches what the event cannot: a score changed in Asana after the issue was last edited,
             and an issue opened before this workflow was adopted. It walks GitHub, not the Asana
             project, so an imported ticket with no back-link on its task is reached, and no project GID
             is needed. The 1000-issue cap is reported (and raised as a ::warning:: annotation) when it is reached.

    A LABEL CHANGE STARTS NO FURTHER RUN: the workflow listens to opened and edited, and adding a label
    is a 'labeled' event.

    HOW THE TASK IS FOUND -- Resolve-AsanaTaskRef, the same three matchers as asana-closed-message, in
    this order: the '<!-- asana-task: <gid> -->' marker report-issue writes; the '| **Asana** | ... |'
    header row of an imported ticket; exactly one Asana task URL anywhere else. Several different tasks
    is 'ambiguous' and skipped: this script never guesses which ticket an issue belongs to. The score
    field is found by NAME (-PrioFieldName, default 'Prio-Score'), because a custom field's GID differs
    per workspace. A task living in a project that does not carry the field has no such field, and reads
    as unscored.

    SELF-CONTAINED, AND THAT IS WHY THE HELPERS ARE COPIES. This file ships into a consumer's
    .github/scripts/, where no plugin lib exists, so the three matchers and Invoke-GhCapture are copied
    from asana-closed-message.ps1 (the matchers originate in bwj-development's
    scripts/lib/asana-task-lib.ps1) rather than loaded. The score and label functions are copied back
    from the retired asana-mirror.ps1.

    THE TASK IT READS is the one the issue body's marker names, and whoever can edit the body can point
    that marker at any task the token reaches. That is the retired asana-mirror's trust model unchanged
    and accepted: the read is one task's score, and the only thing it can change is one of four labels.

    IT PRINTS NOTHING ANOTHER PERSON WROTE. A task name, a body or an Asana error message is never
    printed: an unreadable task reports its HTTP status and nothing else. The one error text it does
    print is gh's own stderr on a failed gh call -- GitHub's API or auth message, never issue content.

    Auth: ASANA_PAT (the repo secret) reads tasks. GH_TOKEN is the workflow's own token, with 'issues:
    write' for the label edit. A missing ASANA_PAT is said and ends the run WITHOUT failing it: the
    session check (closed-message-sessioncheck) is what reports a store with no secret.

    The script runs its main flow only when invoked directly; dot-sourcing it loads the pure helpers and
    does nothing else, which is how the suite exercises them.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [ValidateSet('event', 'sweep')]
    [string]$Mode = 'event',
    # Read from the environment by default rather than passed as an argument: a body can approach the
    # per-argument limit on Linux once it carries multi-byte text. Event mode only.
    [string]$IssueBody = $env:ISSUE_BODY,
    # 'owner/repo#<n>'. Event mode only.
    [string]$IssueRef = '',
    # 'owner/repo'. Sweep mode only.
    [string]$Repo = $env:GITHUB_REPOSITORY,
    # The Asana number field the score is read from, by NAME: its GID differs per workspace.
    [string]$PrioFieldName = 'Prio-Score',
    [string]$AsanaPat = $env:ASANA_PAT
)

$ErrorActionPreference = 'Stop'

$script:AsanaApiBase = 'https://app.asana.com/api/1.0'

# The four prio labels, low to high. EXACTLY ONE of these belongs on a scored issue, which is what
# Set-IssuePrioLabel enforces by removing the other three. Named once so the mapping and the enforcer
# cannot drift apart.
$script:PrioLabels = @('prio-1', 'prio-2', 'prio-3', 'prio-4')

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

function Invoke-GhCapture {
    <#
        Run gh with these arguments and keep both streams apart: Out (the stdout lines), ExitCode, and
        Error (gh's own stderr, or a placeholder when it wrote none). A copy of asana-closed-message.ps1's
        function of this name.
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

function Get-PrioLabelForScore {
    <#
        Pure: the GitHub label for one Asana Prio-Score, or $null when the score names none. Each band is
        closed at the bottom and open at the top, so a precision-2 field can never land between two of
        them. $null for a task with no score AND for a score outside 1.00-5.00: neither is guessed at
        and neither is an error. A copy of the retired asana-mirror.ps1's function of this name.
    #>
    param([AllowNull()]$Score)

    if ($null -eq $Score) { return $null }
    $s = [double]$Score
    if ($s -ge 1 -and $s -lt 2) { return 'prio-1' }
    if ($s -ge 2 -and $s -lt 3) { return 'prio-2' }
    if ($s -ge 3 -and $s -lt 4) { return 'prio-3' }
    if ($s -ge 4 -and $s -le 5) { return 'prio-4' }
    return $null
}

function Get-PrioScoreFromTask {
    <#
        Pure: the named number field's value from a task object, or $null when the task carries no such
        field or the field is empty. The lookup is a match on NAME, not a position or a GID: a field is
        defined in one workspace and does not cross into another. A task in a project that does not carry
        the field has no field by this name at all, and reads as unscored. A copy of the retired
        asana-mirror.ps1's function of this name.
    #>
    param(
        [AllowNull()]$Task,
        [Parameter(Mandatory = $true)][string]$FieldName
    )

    if (-not $Task -or -not $Task.custom_fields) { return $null }
    foreach ($f in $Task.custom_fields) {
        if ($f.name -eq $FieldName) { return $f.number_value }
    }
    return $null
}

function Get-PrioLabelChange {
    <#
        Pure: what one issue needs to read right -- Add (the label to add, or $null when it already
        carries it) and Remove (the OTHER prio-N names it carries). Nothing at all when -Label is $null:
        an absent score never removes a label. Only names from the four-name set are ever returned, so no
        other label of the issue can be passed to gh.
    #>
    param(
        [AllowNull()][string]$Label,
        [AllowEmptyCollection()][string[]]$Current = @()
    )

    if (-not $Label -or $script:PrioLabels -cnotcontains $Label) {
        return [pscustomobject]@{ Add = $null; Remove = @() }
    }
    $have = @(@($Current) | ForEach-Object { ([string]$_).Trim() })
    $add = if ($have -ccontains $Label) { $null } else { $Label }
    $remove = @($script:PrioLabels | Where-Object { $_ -cne $Label -and $have -ccontains $_ })
    return [pscustomobject]@{ Add = $add; Remove = $remove }
}

function Get-AsanaTaskScoreUri {
    <#
        Pure: the GET that reads one task's custom fields. A non-numeric GID is refused before it can reach
        a URL.
    #>
    param([Parameter(Mandatory = $true)][string]$Gid)
    if ($Gid -notmatch '\A[0-9]+\z') { throw "Refusing to read a non-numeric task GID: '$Gid'." }
    return "$script:AsanaApiBase/tasks/$Gid" + '?opt_fields=custom_fields.name,custom_fields.number_value'
}

function Get-AsanaReadOutcome {
    <#
        Pure: how a failed Asana task read is treated, by its HTTP status ($null or 0 when there was no
        response at all). 'skip' for a 404 only -- the task is gone, which is the ticket's state and not
        the sync's. 'failed' for everything else: 401/403 (a revoked or short-scoped PAT), 429 (rate
        limited), 5xx, and a read that got no response. Those make the run fail, because a green run
        that synced nothing is worse than a red one.
    #>
    param([AllowNull()]$Status)

    if ($Status -and [int]$Status -eq 404) { return 'skip' }
    return 'failed'
}

function Get-AsanaTaskState {
    <#
        Read a task's custom fields. Returns Task (the task, or $null), Failed and Status. A failed read
        is reported with its HTTP status only, never Asana's message, and never thrown, so one bad ticket
        cannot end a sweep over all of them: the CALLER fails the run for a Failed read (Get-AsanaReadOutcome
        decides which are) and treats a 404 as a quiet skip. Read-only.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [Parameter(Mandatory = $true)][string]$Pat
    )

    $uri = Get-AsanaTaskScoreUri -Gid $Gid
    try {
        $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers @{ Authorization = "Bearer $Pat" }
        return [pscustomobject]@{ Task = $resp.data; Failed = $false; Status = 200 }
    } catch {
        $status = $null
        if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        $failed = (Get-AsanaReadOutcome -Status $status) -eq 'failed'
        Write-Host "  Asana task $Gid is not readable with this token (HTTP $(if ($status) { $status } else { 'status unknown' })) -- $(if ($failed) { 'FAILED read' } else { 'skipped' })."
        return [pscustomobject]@{ Task = $null; Failed = $failed; Status = $status }
    }
}

function ConvertFrom-IssueListJson {
    <#
        Pure: the issues out of 'gh issue list --json' text, as a list. Empty text and '[]' are an EMPTY
        list (Count 0) on Windows PowerShell 5.1 as well as 7: 5.1 hands a parsed '[]' down a pipeline as
        one object, so the array is read with -InputObject and unrolled with foreach.
    #>
    param([AllowEmptyString()][string]$Text = '')

    if (-not ([string]$Text).Trim()) { return @() }
    $parsed = ConvertFrom-Json -InputObject ([string]$Text)
    return @(foreach ($x in $parsed) { $x })
}

function ConvertFrom-LabelNameLines {
    <#
        Pure: the label names out of the lines 'gh ... --jq' prints, one name per line. Blank lines are
        skipped.
    #>
    param([AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines = @())
    return @(@($Lines) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
}

function Read-IssueLabelNames {
    <#
        One issue's CURRENT label names, read live through gh: Ok, Labels, ExitCode, Error. A failed read
        is reported, never taken as 'no labels' -- that would add a label to an issue that has it, and
        could not remove a stale one.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][int]$Number
    )

    $run = Invoke-GhCapture -GhArgs @('issue', 'view', "$Number", '--repo', $Repo, '--json', 'labels', '--jq', '.labels[].name')
    if ($run.ExitCode -ne 0) {
        return [pscustomobject]@{ Ok = $false; Labels = @(); ExitCode = $run.ExitCode; Error = $run.Error }
    }
    return [pscustomobject]@{ Ok = $true; Labels = @(ConvertFrom-LabelNameLines -Lines $run.Out); ExitCode = 0; Error = '' }
}

function Set-IssuePrioLabel {
    <#
        Put EXACTLY ONE prio label on an issue: add -Label if it is missing, and remove whichever of the
        other three the issue carries (Get-PrioLabelChange). Returns Changed ($true when it edited the
        issue), Failed ($true when the edit was refused) and Error (gh's own stderr on a refusal). Nothing
        is done when there is nothing to do, so a re-run is quiet. 'gh issue edit' fails outright on a
        label the repo does not have; adopt-bwj-development creates all four.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][int]$Number,
        [AllowNull()][string]$Label,
        [string[]]$Current = @()
    )

    $change = Get-PrioLabelChange -Label $Label -Current $Current
    if (-not $change.Add -and @($change.Remove).Count -eq 0) {
        return [pscustomobject]@{ Changed = $false; Failed = $false; Error = '' }
    }

    $ghArgs = @('issue', 'edit', "$Number", '--repo', $Repo)
    if ($change.Add) { $ghArgs += @('--add-label', $change.Add) }
    foreach ($s in @($change.Remove)) { $ghArgs += @('--remove-label', $s) }

    $run = Invoke-GhCapture -GhArgs $ghArgs
    if ($run.ExitCode -ne 0) {
        return [pscustomobject]@{ Changed = $false; Failed = $true; Error = $run.Error }
    }
    $removed = if (@($change.Remove).Count) { " (removed $(@($change.Remove) -join ', '))" } else { '' }
    Write-Host "  $Repo#$Number -> $Label$removed"
    return [pscustomobject]@{ Changed = $true; Failed = $false; Error = '' }
}

function Resolve-IssueScoreLabel {
    <#
        What one issue's body says its label should be: Label (or $null), ReadFailed and Why. $null for a
        body with no linked task, one linking several, a task that cannot be read, and a task with no valid
        score -- every one of which leaves the labels alone. ReadFailed is $true only for a read that
        failed for a reason worth a red run (Get-AsanaReadOutcome); a 404 is a quiet skip.
    #>
    param(
        [AllowEmptyString()][string]$Body,
        [Parameter(Mandatory = $true)][string]$Pat,
        [Parameter(Mandatory = $true)][string]$FieldName
    )

    $ref = Resolve-AsanaTaskRef -IssueBody $Body
    if ($ref.Source -eq 'ambiguous') {
        return [pscustomobject]@{ Label = $null; ReadFailed = $false; Why = "the body links several different Asana tasks ($($ref.Candidates -join ', ')) -- refusing to guess, labels left alone." }
    }
    if (-not $ref.Gid) {
        return [pscustomobject]@{ Label = $null; ReadFailed = $false; Why = 'no Asana task is linked from the issue -- labels left alone.' }
    }
    $read = Get-AsanaTaskState -Gid $ref.Gid -Pat $Pat
    if ($read.Failed) {
        return [pscustomobject]@{ Label = $null; ReadFailed = $true; Why = "task $($ref.Gid) could not be read (HTTP $(if ($read.Status) { $read.Status } else { 'status unknown' })) -- labels left alone, run failed." }
    }
    if (-not $read.Task) {
        return [pscustomobject]@{ Label = $null; ReadFailed = $false; Why = "task $($ref.Gid) was not found (HTTP 404) -- labels left alone." }
    }
    $label = Get-PrioLabelForScore -Score (Get-PrioScoreFromTask -Task $read.Task -FieldName $FieldName)
    if (-not $label) {
        return [pscustomobject]@{ Label = $null; ReadFailed = $false; Why = "task $($ref.Gid) carries no valid '$FieldName' (1.00-5.00) -- labels left alone." }
    }
    return [pscustomobject]@{ Label = $label; ReadFailed = $false; Why = "task $($ref.Gid), matched by $($ref.Source)" }
}

function Invoke-EventMode {
    if ($IssueRef -notmatch '\A([^\s#/]+/[^\s#/]+)#([0-9]+)\z') { throw "IssueRef '$IssueRef' is not 'owner/repo#<n>'." }
    $slug   = $Matches[1]
    $number = [int]$Matches[2]

    $want = Resolve-IssueScoreLabel -Body $IssueBody -Pat $AsanaPat -FieldName $PrioFieldName
    if ($want.ReadFailed) { throw "$IssueRef -- $($want.Why)" }
    if (-not $want.Label) {
        Write-Host "$IssueRef -- $($want.Why)"
        return
    }
    $read = Read-IssueLabelNames -Repo $slug -Number $number
    if (-not $read.Ok) {
        throw "The labels of $IssueRef could not be read: gh exited $($read.ExitCode): $($read.Error)"
    }
    $set = Set-IssuePrioLabel -Repo $slug -Number $number -Label $want.Label -Current $read.Labels
    if ($set.Failed) {
        throw "Could not set '$($want.Label)' on $IssueRef -- does the repo have all four prio labels? gh: $($set.Error)"
    }
    if (-not $set.Changed) { Write-Host "$IssueRef already reads $($want.Label) ($($want.Why))." }
}

function Invoke-LabelSweep {
    <#
        Every OPEN issue of the repo, each given the one prio label its task's score names. One issue
        failing (an unreadable task, a refused edit) never ends the walk; the run fails at the END when an
        edit was refused or an Asana read failed (anything but a 404), so a store missing a prio label is a red run rather than a quiet one.
    #>
    if ($Repo -notmatch '\A[^\s#/]+/[^\s#/]+\z') { throw "Repo '$Repo' is not 'owner/repo'." }
    $limit = 1000
    $run = Invoke-GhCapture -GhArgs @('issue', 'list', '--repo', $Repo, '--state', 'open', '--limit', "$limit", '--json', 'number,body,labels')
    if ($run.ExitCode -ne 0) { throw "The open issues of $Repo could not be listed: gh exited $($run.ExitCode): $($run.Error)" }
    $issues = @(ConvertFrom-IssueListJson -Text ([string]($run.Out -join "`n")))
    if ($issues.Count -ge $limit) {
        $capNote = "The listing holds $limit issues, the cap -- older open issues are not swept."
        Write-Host $capNote
        Write-Host "::warning::$capNote"
    }

    $scored = 0
    $done   = 0
    $failed = 0
    $unread = 0
    foreach ($i in $issues) {
        $want = Resolve-IssueScoreLabel -Body ([string]$i.body) -Pat $AsanaPat -FieldName $PrioFieldName
        if ($want.ReadFailed) { $unread++ }
        if (-not $want.Label) { continue }
        $scored++
        $current = @($i.labels | ForEach-Object { $_.name })
        $set = Set-IssuePrioLabel -Repo $Repo -Number ([int]$i.number) -Label $want.Label -Current $current
        if ($set.Changed) { $done++ }
        if ($set.Failed) {
            $failed++
            Write-Host "  Could not set '$($want.Label)' on $Repo#$($i.number) -- does the repo have all four prio labels? gh: $($set.Error)"
        }
    }
    Write-Host "Label sweep: $($issues.Count) open issue(s) examined, $scored with a valid '$PrioFieldName', $done relabelled, $failed refused, $unread Asana read(s) failed."
    if ($failed -gt 0 -or $unread -gt 0) {
        throw "$failed label edit(s) were refused and $unread Asana task read(s) failed (not a 404); see above."
    }
}

function Invoke-Main {
    if (-not $AsanaPat) {
        # Said, and not a failure: the session check reports a store with no secret, and a red run per
        # issue edit would only add noise to the same finding.
        Write-Host 'ASANA_PAT is not set -- the prio label sync did nothing. The repo maintainer sets the secret (see step 3 of the adopt-bwj-development skill).'
        return
    }
    if ($Mode -eq 'sweep') { Invoke-LabelSweep } else { Invoke-EventMode }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
