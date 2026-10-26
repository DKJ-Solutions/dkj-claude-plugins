<#
.SYNOPSIS
    The Logbook page of every repo's hub (#3364; in dkj-policy since #3470): every assignment given in a clean session, timed from its
    first prompt until Claude is back on the trunk, without anybody marking it.

.DESCRIPTION
    THE STOPWATCH'S MACHINERY WITH ANOTHER TRIGGER. The store format, the model, the transcript phases and both pages
    are stopwatch-lib.ps1's, beside this file, which this file loads; what is the Logbook's own is when a run starts and
    stops, its store, and the words on its pages. The Stopwatch times what a prompt marks with `stopwatch:`; the
    Logbook times every session, so the two never compete for a run.

    THE RULES (Invoke-LogbookHookEvent, called by the hooks of this plugin's hooks/logbook-hook.ps1), as the owner chose
    them on October 24, 2026:

      - The FIRST prompt of a new Claude Code session (a new session id, so also after /clear) starts a run, but only
        when the checkout is on the trunk and clean at that moment: a session that begins in the middle of work is not
        an assignment from a clean start, and is not logged. The store keeps the session ids it has seen
        (the last $script:LogbookSessionsKept), so a later prompt of the same session never starts one, whatever
        the checkout reads by then. The run's label is the prompt's first line.
      - The Stop hook ends that session's run when a turn ends with the checkout on the trunk and clean, ALSO WHEN
        HEAD NEVER MOVED: a session that only asks a question is logged as a short run (unlike the Stopwatch, which
        waits for HEAD to move). A branch parked for the owner's eye is not the trunk, so its run keeps going.
      - EXCEPT WHILE A SHIP IS IN FLIGHT. ship-pr returns the checkout to the trunk as soon as the PR exists (#1073)
        and then waits on CI, often backgrounded, so at the end of that turn the checkout reads as a clean trunk
        while the merge and the fold are still owed. Its CI wait publishes a run-progress record
        (dkj-policy's scripts/lib/run-progress-lib.ps1), and a live one holds the run open; the turn the finished ship wakes
        ends it.
      - Runs are keyed by session id, so two sessions side by side each keep their own run, and every open run shows
        as going (ConvertTo-StopwatchModel -KeepOpenRuns), up to a day old (ConvertTo-LogbookModel).

    A SWEEP IS SHOWN PER ISSUE (#3405). A /sweep-issues session works several issues in one turn, so its run is the
    whole sweep, and that length only says how many issues the backlog held (the owner, October 24, 2026). The pages
    cut it at every ship-pr fold of this checkout inside it (Get-LogbookRuns), since a fold is the moment the trunk
    is clean again: each issue is a run of its own, from the previous clean trunk to its fold, named after the issue
    its fold commit names. The time after the last fold belongs to no issue and is not shown. The store and the
    hooks do not change; the cut is made where the pages are built.

    THE STORE IS THIS MACHINE'S AND STAYS HERE: logbook.json beside the repo's Stopwatch store
    (%LOCALAPPDATA%\dkj-claude-plugins\repos\<repo>\, one per repo since #3470), outside the tree for the
    Stopwatch's reason (a run must not dirty the checkout it is timing). Unlike the Stopwatch's runs it is NEVER
    shared to origin, not even where a repo opts in (#3349): a label is the first line of a prompt, and every
    prompt of a clean session is logged, not only the ones marked for it.

    Pure. Every value that reaches the page is escaped by the Stopwatch's page functions. Pure ASCII (repo
    convention for .ps1). Tested by scripts/tests/logbook.tests.ps1 in the source repo.
#>

. (Join-Path $PSScriptRoot 'stopwatch-lib.ps1')

$script:LogbookSessionsKept = 500
# An open run older than this is not shown (Victor, #3364): a session abandoned on a branch, or one that crashed,
# never reaches its Stop on the trunk, and would otherwise draw a clock that grows for ever. It stays in the store,
# so a resumed session that does close it shows it again.
$script:LogbookOpenRunMaxHours = 24
# A finished run's speed on the overview (Get-LogbookSpeedTones): green under the first, orange under the second, red
# from there on, read off its work time (the owner, October 26, 2026).
$script:LogbookFastSeconds = 15 * 60
$script:LogbookSlowSeconds = 45 * 60

function Get-LogbookStorePath {
    <# The Logbook's store on this machine for the repo at -RepoRoot, beside its Stopwatch's. #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    return (Join-Path (Split-Path -Parent (Get-StopwatchStorePath -RepoRoot $RepoRoot)) 'logbook.json')
}

function Get-LogbookPromptLabel {
    <#
        A run's label: the first line of -Prompt, read past Claude Code's `<pasted_content id="hhhh">` wrapper as the
        Stopwatch's marker is (#3336), control characters as spaces, trimmed and cut to the Stopwatch's label maximum;
        "Assignment" when nothing is left.
    #>
    param([AllowEmptyString()][string]$Prompt = '')
    $text = [regex]::Replace($Prompt.TrimStart(), '^<pasted_content id="[0-9a-f]{4}">[ \t]*\r?\n', '').TrimStart()
    $line = ($text -split '\r?\n', 2)[0]
    $label = ($line -replace ('[' + [char]0 + '-' + [char]31 + [char]127 + ']'), ' ').Trim()
    if ($label.Length -gt $script:StopwatchLabelMax) { $label = $label.Substring(0, $script:StopwatchLabelMax).Trim() }
    if (-not $label) { $label = 'Assignment' }
    return $label
}

function Invoke-LogbookHookEvent {
    <#
        What a Claude Code hook does to the Logbook's store (#3364), decided without git or a clock so every rule is
        tested. -Hook Prompt: a -SessionId not in -Sessions is added to them, and when -Branch is -Trunk and -Clean it
        also starts a run at -Now for that session, labelled from -Prompt; a session already seen, or no session id,
        does nothing. -Hook Stop: the open run of -SessionId ends at -Now when -Branch is -Trunk, -Clean and not
        -ShipInFlight; otherwise nothing. Returns Runs, Sessions and Changed (write only when set).
    #>
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Prompt', 'Stop')][string]$Hook,
        [AllowEmptyCollection()][object[]]$Runs = @(),
        [AllowEmptyCollection()][string[]]$Sessions = @(),
        [AllowEmptyString()][string]$SessionId = '',
        [Parameter(Mandatory = $true)][datetime]$Now,
        [string]$Branch = '',
        [bool]$Clean = $false,
        [string]$Head = '',
        [string]$Trunk = 'main',
        [AllowEmptyString()][string]$Prompt = '',
        [bool]$ShipInFlight = $false
    )
    $runs = @($Runs | Where-Object { $_ })
    $seen = @($Sessions | Where-Object { $_ })
    $same = @{ Runs = $runs; Sessions = $seen; Changed = $false }
    if (-not $SessionId) { return $same }
    $onTrunk = ($Branch -ceq $Trunk) -and $Clean
    if ($Hook -eq 'Prompt') {
        if ($seen -ccontains $SessionId) { return $same }
        $seen = @($seen + $SessionId)
        if ($seen.Count -gt $script:LogbookSessionsKept) { $seen = @($seen[($seen.Count - $script:LogbookSessionsKept)..($seen.Count - 1)]) }
        if ($onTrunk) {
            $run = New-StopwatchRun -Label (Get-LogbookPromptLabel -Prompt $Prompt) -Now $Now -StartHead $Head
            $run.Session = $SessionId
            $runs = @($runs + $run)
        }
        return @{ Runs = $runs; Sessions = $seen; Changed = $true }
    }
    $open = @($runs | Where-Object { -not $_.End -and $_.Session -ceq $SessionId }) | Select-Object -Last 1
    if (-not $open -or -not $onTrunk -or $ShipInFlight) { return $same }
    $copy = $open.Clone(); $copy.End = $Now.ToUniversalTime()
    return @{ Runs = @($runs | ForEach-Object { if ($_.Id -eq $copy.Id) { $copy } else { $_ } }); Sessions = $seen; Changed = $true }
}

# A run whose label is this is a sweep, cut per issue on the pages (#3405).
$script:LogbookSweepLabel = '^/(dkj-policy:)?sweep-issues(\s|$)'
# A fold commit is made seconds after its fold mark; one this far after it, or before it, belongs to another fold.
$script:LogbookFoldCommitSeconds = 300

function Split-LogbookSweepRuns {
    <#
        -Runs with every sweep run ($script:LogbookSweepLabel) cut at the -Folds inside it (@{ At; Issue }), oldest
        first: one run per fold, from the run's start or the fold before to this fold, labelled with the fold's issue
        (`/sweep-issues #3397`, or `issue <n>` when the fold named none), and its id the sweep's with `-<n>` behind it.
        A finished sweep's time after its last fold is dropped; a going sweep's is the issue in progress, going. A
        sweep with no fold inside it, and every other run, is returned as it is. Pure.
    #>
    param([AllowEmptyCollection()][object[]]$Runs = @(), [AllowEmptyCollection()][object[]]$Folds = @())
    $out = @()
    foreach ($r in @($Runs | Where-Object { $_ })) {
        $cuts = @()
        if ($r.Label -imatch $script:LogbookSweepLabel) {
            $cuts = @($Folds | Where-Object { $_ -and $_.At -gt $r.Start -and (-not $r.End -or $_.At -le $r.End) } | Sort-Object { $_.At })
        }
        if (-not $cuts.Count) { $out += $r; continue }
        $from = $r.Start; $n = 0
        foreach ($c in $cuts) {
            $n++
            $lap = $r.Clone(); $lap.Id = "$($r.Id)-$n"; $lap.Start = $from; $lap.End = $c.At
            $lap.Label = $r.Label + ' ' + $(if ($c.Issue) { '#' + $c.Issue } else { "issue $n" })
            $out += $lap; $from = $c.At
        }
        if (-not $r.End) {
            $lap = $r.Clone(); $lap.Id = "$($r.Id)-$($n + 1)"; $lap.Start = $from; $lap.Label = $r.Label + ' issue ' + ($n + 1)
            $out += $lap
        }
    }
    return @($out | Sort-Object { $_.Start })
}

function Get-LogbookFolds {
    <#
        The folds in -Marks (Read-RunStepMarks' marks, already this checkout's) as @{ At; Issue }: every ship-pr 'fold'
        mark, with the issue number from the branch of the first unused fold commit in -Commits (@{ At; Subject }, a
        subject reading `fold: <prefix>/<n>-...`) made from 5 seconds before it to $script:LogbookFoldCommitSeconds
        after it; empty when none matches. Pure.
    #>
    param([AllowEmptyCollection()][object[]]$Marks = @(), [AllowEmptyCollection()][object[]]$Commits = @())
    $used = @{}; $out = @()
    foreach ($m in @($Marks | Where-Object { $_ -and $_.Run -eq 'ship-pr' -and $_.Step -eq 'fold' } | Sort-Object { $_.At })) {
        $issue = ''
        $i = 0
        foreach ($c in @($Commits | Sort-Object { $_.At })) {
            $i++
            if ($used[$i] -or $c.At -lt $m.At.AddSeconds(-5) -or $c.At -gt $m.At.AddSeconds($script:LogbookFoldCommitSeconds)) { continue }
            if ($c.Subject -cmatch '^fold: [a-z]+/(\d+)-') { $issue = $Matches[1]; $used[$i] = $true; break }
        }
        $out += @{ At = $m.At; Issue = $issue }
    }
    return $out
}

function Get-LogbookRuns {
    <#
        The runs the Logbook pages show: -Runs with every sweep cut per issue (Split-LogbookSweepRuns), at the folds
        the step log at -StepLogPath holds for the checkout at -RepoRoot, named from the fold commits in that
        checkout's git history. Without a sweep among -Runs nothing is read; without the step log's reader, or a
        log, the sweeps stay whole. Never throws.
    #>
    param([AllowEmptyCollection()][object[]]$Runs = @(), [string]$StepLogPath = '', [string]$RepoRoot = '')
    $sweeps = @($Runs | Where-Object { $_ -and $_.Label -imatch $script:LogbookSweepLabel })
    if (-not $sweeps.Count -or -not $StepLogPath -or -not $script:StopwatchStepLogAvailable) { return @($Runs) }
    try {
        $from = ($sweeps | ForEach-Object { $_.Start } | Measure-Object -Minimum).Minimum
        $to = [datetime]::UtcNow
        $marks = @(Read-RunStepMarks -Path $StepLogPath -From $from -To $to | Where-Object {
                $_.Run -eq 'ship-pr' -and $_.Step -eq 'fold' -and (-not $RepoRoot -or (Test-RunProgressInWorkspace -RecordWorkspace $_.Workspace -SessionWorkspace $RepoRoot)) })
        if (-not $marks.Count) { return @($Runs) }
        $commits = @()
        if ($RepoRoot) {
            $ErrorActionPreference = 'Continue'
            $since = $from.ToUniversalTime().AddMinutes(-1).ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
            $lines = @(git -C $RepoRoot log --all --format='%ct%x09%s' --since=$since --grep='^fold: ' 2>$null)
            if ($LASTEXITCODE -eq 0) {
                $commits = @(foreach ($l in $lines) {
                        $p = ([string]$l) -split "`t", 2
                        if ($p.Count -eq 2 -and $p[0] -match '^\d+$') { @{ At = [DateTimeOffset]::FromUnixTimeSeconds([long]$p[0]).UtcDateTime; Subject = $p[1] } } })
            }
        }
        return (Split-LogbookSweepRuns -Runs $Runs -Folds (Get-LogbookFolds -Marks $marks -Commits $commits))
    } catch {
        return @($Runs)
    }
}

function ConvertTo-LogbookModel {
    <# What both Logbook pages show: ConvertTo-StopwatchModel -KeepOpenRuns over -Runs, without the open runs older than $script:LogbookOpenRunMaxHours at -Now. #>
    param([AllowEmptyCollection()][object[]]$Runs = @(), [datetime]$Now = [datetime]::UtcNow)
    $cut = $Now.ToUniversalTime().AddHours(-$script:LogbookOpenRunMaxHours)
    return (ConvertTo-StopwatchModel -Runs @($Runs | Where-Object { $_ -and ($_.End -or $_.Start -ge $cut) }) -KeepOpenRuns)
}

function Get-LogbookWorkTimes {
    <#
        Each finished run's work time, by run id: its time less the phase in which no session was busy
        ($script:StopwatchIdlePhase, "Waiting on you"), from -Transcript (Get-StopwatchTranscriptCache's entries). A
        run the transcripts did not cover, or covered with no session, has none, so a page never shows a work time
        nothing measured. Returns @{ Work; Waiting } per id, in seconds. Pure.
    #>
    param([AllowEmptyCollection()][object[]]$Runs = @(), [hashtable]$Transcript = @{})
    $out = @{}
    foreach ($r in @($Runs | Where-Object { $_ -and $_.End })) {
        $t = $Transcript[$r.Id]
        if (-not $t -or -not $t.Sessions -or -not @($t.Phases | Where-Object { $_ }).Count) { continue }
        $waiting = [double](@($t.Phases | Where-Object { $_.Name -eq $script:StopwatchIdlePhase } | ForEach-Object { [double]$_.Seconds }) | Measure-Object -Sum).Sum
        $total = ($r.End - $r.Start).TotalSeconds
        $out[$r.Id] = @{ Work = [Math]::Max(0, $total - $waiting); Waiting = [Math]::Min($total, $waiting) }
    }
    return $out
}

function Get-LogbookSpeedTones {
    <#
        Each finished run's speed, by run id: 'fast' under $script:LogbookFastSeconds, 'medium' under
        $script:LogbookSlowSeconds, else 'slow'. Read off its work time in -WorkTimes (Get-LogbookWorkTimes), so time
        spent waiting on the owner does not make a run slow; a run with no work time is read off its whole time. Pure.
    #>
    param([AllowEmptyCollection()][object[]]$Runs = @(), [hashtable]$WorkTimes = @{})
    $out = @{}
    foreach ($r in @($Runs | Where-Object { $_ -and $_.End })) {
        $s = if ($WorkTimes[$r.Id]) { [double]$WorkTimes[$r.Id].Work } else { ($r.End - $r.Start).TotalSeconds }
        $out[$r.Id] = if ($s -lt $script:LogbookFastSeconds) { 'fast' } elseif ($s -lt $script:LogbookSlowSeconds) { 'medium' } else { 'slow' }
    }
    return $out
}

function Format-LogbookPageHtml {
    <#
        The overview on '/logbook': the Stopwatch's overview with the Logbook's words, every recent open run going
        (ConvertTo-LogbookModel), no change against a run before, and each finished run's work time beside its time
        (Get-LogbookWorkTimes over -Transcript), so the time Claude waited on the owner does not hide the work.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Runs,
        [AllowEmptyString()][string]$ReadError = '',
        [int]$Skipped = 0,
        [AllowEmptyString()][string]$StorePath = '',
        [hashtable]$Transcript = @{},
        [datetime]$Now = [datetime]::UtcNow,
        [AllowEmptyString()][string]$RepoName = '',
        [string]$HubHref = '/hub'
    )
    $notes = @{}
    $work = Get-LogbookWorkTimes -Runs $Runs -Transcript $Transcript
    foreach ($id in $work.Keys) { $notes[$id] = 'work ' + (Format-DevSeconds $work[$id].Work) }
    $tones = Get-LogbookSpeedTones -Runs $Runs -WorkTimes $work
    $note = 'A finished run''s card is green under ' + ($script:LogbookFastSeconds / 60) + ' minutes of work, orange under ' + ($script:LogbookSlowSeconds / 60) + ' and red from there on; a run with no work time is read off its whole time. ' +
        'Kept on this machine in <code>' + (ConvertTo-GeneralPageText $StorePath) + '</code>, outside the checkout, and not shared: a label is the first line of a prompt. ' +
        'The first prompt of a new Claude Code session starts a run when the checkout is on the trunk and clean; a Stop hook ends it once a turn ends with the checkout back on the trunk and clean, ' +
        'also when nothing was merged, and not while a ship-pr is still waiting on CI. Both are the dkj-policy plugin''s <code>hooks/logbook-hook.ps1</code>. ' +
        'A <code>/sweep-issues</code> run is shown per issue: cut at each ship-pr fold of this checkout, the moment the trunk is clean again, and named after the issue its fold commit names; the time after the last fold belongs to no issue. ' +
        'Built by its <code>hub/lib/logbook-lib.ps1</code> on the Stopwatch''s pages.'
    return Format-StopwatchPageHtml -Model (ConvertTo-LogbookModel -Runs $Runs -Now $Now) -ReadError $ReadError -Skipped $Skipped -StorePath $StorePath -Now $Now `
        -Route '/logbook' -PageTitle 'Logbook' `
        -FooterNote $note -NoDelta -CardNotes $notes -CardTones $tones -Flat -RepoName $RepoName -HubHref $HubHref
}

function Format-LogbookRunPageHtml {
    <# One run's page on '/logbook/<slug>': the Stopwatch's run page under the Logbook's crumb, without the change against a run before, with its work time and its waiting under its time. #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Group,
        [AllowEmptyString()][string]$StorePath = '',
        [hashtable]$Transcript = @{},
        [datetime]$Now = [datetime]::UtcNow,
        [AllowEmptyString()][string]$RepoName = '',
        [string]$HubHref = '/hub'
    )
    $note = 'Kept on this machine in <code>' + (ConvertTo-GeneralPageText $StorePath) + '</code>, outside the checkout, and not shared. ' +
        'The phases are read from this repo''s Claude Code session transcripts once a run has stopped, as the Stopwatch reads them: each second goes to the first phase going at that moment, ' +
        'and a second in which no session was busy is time spent waiting on you. Built by the dkj-policy plugin''s <code>hub/lib/logbook-lib.ps1</code>.'
    $timeNote = ''
    if (@($Group.Rows).Count) {
        $w = (Get-LogbookWorkTimes -Runs @($Group.Rows[0].Run) -Transcript $Transcript)[$Group.Rows[0].Run.Id]
        if ($w) { $timeNote = 'Work ' + (Format-DevSeconds $w.Work) + ', waiting on you ' + (Format-DevSeconds $w.Waiting) + '.' }
    }
    return Format-StopwatchRunPageHtml -Group $Group -StorePath $StorePath -Transcript $Transcript -Now $Now -Route '/logbook' -ParentLabel 'Logbook' -FooterNote $note -NoDelta -TimeNote $timeNote -RepoName $RepoName -HubHref $HubHref
}
