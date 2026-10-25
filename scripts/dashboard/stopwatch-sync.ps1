<#
.SYNOPSIS
    Share the Stopwatch's runs across machines (#3349): fetch every machine's runs from origin and publish this
    machine's own, through refs/stopwatch/<machine id>. The rules are in scripts/lib/stopwatch-sync-lib.ps1.

.DESCRIPTION
    Started in the background, never waited on: by the Stop hook (scripts/dashboard/stopwatch-hook.ps1) once a run
    has ended, and by the hub (serve-connector-dashboard.ps1) when a Stopwatch page is loaded and the last sync is
    more than a few minutes old. Either way the run is the same: fetch, then erase from this machine's store every
    finished run a hide entry of any machine names (#3453), then compute the phases of this machine's
    finished runs from its own transcripts (Get-StopwatchTranscriptCache, which also fills the local cache), then
    publish them when they differ from what origin holds.

    ONE AT A TIME. A sync holds stopwatch-sync.lock beside the store open for as long as it runs, and a second one
    waits for it (up to two minutes) instead of racing it: both would build on the same copy of the ref, and the
    second push would be refused as not a fast-forward, often the Stop hook's, which carries the newest run (Victor,
    #3349). The operating system releases the lock when the process ends, however it ends. A push that is refused
    anyway is tried once more, from a fresh fetch.

    It stamps stopwatch-sync.stamp beside the store when it starts, so a hub that loads a page every few seconds
    starts one sync, not one per load. It writes the outcome of its last run to stopwatch-sync.log beside the store
    (one line, overwritten), so a sync that keeps failing can be read without a console. It always exits 0.

    -StorePath, -TranscriptDir, -RepoRoot and -Remote are for the tests.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [string]$StorePath = '',
    [string]$TranscriptDir = '',
    [string]$RepoRoot = '',
    [string]$Remote = 'origin'
)
$ErrorActionPreference = 'Stop'
$log = ''
$lock = $null
try {
    $here = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    . (Join-Path $here 'scripts\lib\dev-pages-lib.ps1')
    . (Join-Path $here 'scripts\lib\stopwatch-lib.ps1')
    . (Join-Path $here 'scripts\lib\stopwatch-sync-lib.ps1')
    $root = if ($RepoRoot) { $RepoRoot } else { $here }
    if (-not $StorePath) { $StorePath = Get-StopwatchStorePath }
    if (-not $TranscriptDir) { $TranscriptDir = Get-StopwatchTranscriptDir -RepoRoot $root }
    $dir = Split-Path -Parent $StorePath
    $log = Join-Path $dir 'stopwatch-sync.log'
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }

    $lockPath = Join-Path $dir 'stopwatch-sync.lock'
    $deadline = [datetime]::UtcNow.AddMinutes(2)
    while (-not $lock) {
        try { $lock = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
        catch { if ([datetime]::UtcNow -gt $deadline) { throw 'another sync held the lock for two minutes' }; Start-Sleep -Milliseconds 500 }
    }
    [System.IO.File]::WriteAllText((Join-Path $dir 'stopwatch-sync.stamp'), (Format-StopwatchStamp ([datetime]::UtcNow)))

    $store = Read-StopwatchStore -Path $StorePath
    $machine = Get-StopwatchMachineId -StoreDir $dir
    $outcome = ''
    for ($try = 1; $try -le 2; $try++) {
        $fetched = Receive-StopwatchShared -RepoRoot $root -Remote $Remote
        if ($store.Error) { $outcome = 'not published: the store does not read'; break }
        if (-not $machine) { $outcome = 'not published: no machine id'; break }
        if (-not $fetched) { $outcome = 'not published: the fetch did not answer, so the copy to build on is unknown'; break }
        # This machine's hide entries (#3446) travel in its own payload. A hide file that does not read stops the
        # publish, as a store that does not read does: publishing none would show everything it hides again.
        $hidden = Read-StopwatchHidden -Path (Get-StopwatchHiddenPath -StorePath $StorePath)
        if ($hidden.Error) { $outcome = 'not published: the hide file does not read'; break }
        # A run any machine hides is erased from this machine's own store before the publish (#3453).
        $erase = Remove-StopwatchHiddenFromStore -StorePath $StorePath -Entries (@($hidden.Entries) + @((Read-StopwatchShared -RepoRoot $root -MachineId $machine).Hidden))
        if ($erase.Error) { $outcome = 'not published: ' + $erase.Error; break }
        if ($erase.Erased.Count) { $store = Read-StopwatchStore -Path $StorePath }
        $done = @($store.Runs | Where-Object { $_.End })
        $stepLog = if ($script:StopwatchStepLogAvailable) { Get-RunStepLogPath } else { '' }
        $phases = Get-StopwatchTranscriptCache -Runs $done -CachePath (Join-Path $dir 'stopwatch-phases.json') -TranscriptDir $TranscriptDir -StepLogPath $stepLog -RepoRoot $root
        $json = ConvertTo-StopwatchSharedJson -MachineId $machine -Runs $done -Phases $phases -Hidden $hidden.Entries
        $p = Publish-StopwatchShared -RepoRoot $root -MachineId $machine -Json $json -TempDir $dir -Remote $Remote
        $outcome = $p.Status + $(if ($p.Message) { ': ' + $p.Message } else { '' }) + $(if ($try -gt 1) { ' (second try)' } else { '' })
        if ($p.Status -ne 'failed') { break }
    }
    [System.IO.File]::WriteAllText($log, ((Format-StopwatchStamp ([datetime]::UtcNow)) + ' ' + $outcome))
} catch {
    try { if ($log) { [System.IO.File]::WriteAllText($log, ((Format-StopwatchStamp ([datetime]::UtcNow)) + ' failed: ' + $_.Exception.Message)) } } catch { }
} finally {
    if ($lock) { $lock.Dispose() }
}
exit 0
