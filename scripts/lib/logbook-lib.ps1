<#
.SYNOPSIS
    The Logbook page of this repo's dev server (#3364): every assignment given in a clean session, timed from its
    first prompt until Claude is back on the trunk, without anybody marking it.

.DESCRIPTION
    THE STOPWATCH'S MACHINERY WITH ANOTHER TRIGGER. The store format, the model, the transcript phases and both pages
    are scripts/lib/stopwatch-lib.ps1's, which this file loads; what is the Logbook's own is when a run starts and
    stops, its store, and the words on its pages. The Stopwatch times what a prompt marks with `stopwatch:`; the
    Logbook times every session, so the two never compete for a run.

    THE RULES (Invoke-LogbookHookEvent, called by the hooks of scripts/dashboard/logbook-hook.ps1), as the owner chose
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
        (scripts/lib/run-progress-lib.ps1), and a live one holds the run open; the turn the finished ship wakes
        ends it.
      - Runs are keyed by session id, so two sessions side by side each keep their own run, and every open run shows
        as going (ConvertTo-StopwatchModel -KeepOpenRuns).

    THE STORE IS THIS MACHINE'S AND STAYS HERE: %LOCALAPPDATA%\dkj-claude-plugins\logbook.json, outside the tree
    for the Stopwatch's reason (a run must not dirty the checkout it is timing). Unlike the Stopwatch's runs it is
    NOT shared to origin (#3349): a label is the first line of a prompt, and this repo is public.

    Pure. Every value that reaches the page is escaped by the Stopwatch's page functions. Pure ASCII (repo
    convention for .ps1). Tested by scripts/tests/logbook.tests.ps1.
#>

. (Join-Path $PSScriptRoot 'stopwatch-lib.ps1')

$script:LogbookSessionsKept = 500

function Get-LogbookStorePath {
    <# The Logbook's store on this machine, beside the Stopwatch's. #>
    return (Join-Path (Split-Path -Parent (Get-StopwatchStorePath)) 'logbook.json')
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

function Format-LogbookPageHtml {
    <# The overview on '/logbook': the Stopwatch's overview with the Logbook's words, every open run going, and no change against a run before. #>
    param(
        [Parameter(Mandatory = $true)][object[]]$Runs,
        [AllowEmptyString()][string]$ReadError = '',
        [int]$Skipped = 0,
        [AllowEmptyString()][string]$StorePath = '',
        [datetime]$Now = [datetime]::UtcNow
    )
    $note = 'Kept on this machine in <code>' + (ConvertTo-DashboardText $StorePath) + '</code>, outside the checkout, and not shared: a label is the first line of a prompt. ' +
        'The first prompt of a new Claude Code session starts a run when the checkout is on the trunk and clean; a Stop hook ends it once a turn ends with the checkout back on the trunk and clean, ' +
        'also when nothing was merged, and not while a ship-pr is still waiting on CI. Both are <code>scripts/dashboard/logbook-hook.ps1</code>. ' +
        'Built by <code>scripts/lib/logbook-lib.ps1</code> on the Stopwatch''s pages.'
    return Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs $Runs -KeepOpenRuns) -ReadError $ReadError -Skipped $Skipped -StorePath $StorePath -Now $Now `
        -Route '/logbook' -PageTitle 'Logbook' -Sub 'One card per session that began on a clean trunk, newest first, timed from its first prompt until Claude was back on the trunk.' `
        -FooterNote $note -NoDelta
}

function Format-LogbookRunPageHtml {
    <# One run's page on '/logbook/<slug>': the Stopwatch's run page under the Logbook's crumb, without the change against a run before. #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Group,
        [AllowEmptyString()][string]$StorePath = '',
        [hashtable]$Transcript = @{},
        [datetime]$Now = [datetime]::UtcNow
    )
    $note = 'Kept on this machine in <code>' + (ConvertTo-DashboardText $StorePath) + '</code>, outside the checkout, and not shared. ' +
        'The phases are read from this repo''s Claude Code session transcripts once a run has stopped, as the Stopwatch reads them: each second goes to the first phase going at that moment, ' +
        'and a second in which no session was busy is time spent waiting on you. Built by <code>scripts/lib/logbook-lib.ps1</code>.'
    return Format-StopwatchRunPageHtml -Group $Group -StorePath $StorePath -Transcript $Transcript -Now $Now -Route '/logbook' -ParentLabel 'Logbook' -FooterNote $note -NoDelta
}
