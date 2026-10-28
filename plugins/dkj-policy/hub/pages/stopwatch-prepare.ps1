<#
.SYNOPSIS
    Prepare a Stopwatch card for a label with no clock running, or withdraw it. The documented entry point is this
    plugin's stopwatch-prepare skill (skills/stopwatch-prepare/SKILL.md).

.DESCRIPTION
    Adds the label to the `prepared` list of THIS machine's stopwatch.json, so the hub's /stopwatch overview shows a
    "ready, not started" card for it. No run is created: the run still starts only when the owner sends a prompt whose
    first line is `stopwatch: <label>`, and the run then lands on that card (the hook removes the prepared entry).
    The label is normalised exactly as a prompt's label is (ConvertTo-StopwatchLabel: control characters as spaces,
    trimmed, cut to the label maximum), so the card and the later prompt agree. A label that already has a card is
    not a problem: it is recorded, and its normal card shows until it has no run left.

      -Label <label>   the label to prepare (required)
      -Remove          withdraw a prepared label instead
      -StorePath       for the tests

    -RepoRoot is the repo: CLAUDE_PROJECT_DIR, else the working directory, when not given. Writes only this machine's
    store, under the same lock the hooks take, and refuses a store that does not read (nothing is written over it).
    Not synced: a prepared label is this machine's own and is never shared. Exits 0 on success, 1 on a refusal.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [string]$Label = '',
    [switch]$Remove,
    [string]$StorePath = '',
    [string]$RepoRoot = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\stopwatch-lib.ps1')
$root = if ($RepoRoot) { $RepoRoot } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$root = [System.IO.Path]::GetFullPath($root).TrimEnd('\', '/')
if (-not $StorePath) { [void](Move-HubTimingLegacyStore -RepoRoot $root); $StorePath = Get-StopwatchStorePath -RepoRoot $root }

$norm = ConvertTo-StopwatchLabel -Text $Label
if (-not $norm) {
    Write-Host '[REFUSED] -Label is empty -- nothing was written.'
    exit 1
}
$lock = Get-HubTimingLock -StorePath $StorePath
try {
    $store = Read-StopwatchStore -Path $StorePath
    if ($store.Error) {
        Write-Host "[REFUSED] $StorePath does not read ($($store.Error)) -- nothing was written. Repair or remove it by hand first."
        exit 1
    }
    $others = @($store.Prepared | Where-Object { $_.Label -ine $norm })
    $had = @($store.Prepared).Count -ne $others.Count
    if ($Remove) {
        if (-not $had) { Write-Host "[OK] `"$norm`" was not prepared -- nothing to withdraw."; exit 0 }
        $prepared = $others
    } else {
        $prepared = @($others + @(@{ Label = $norm; PreparedAt = [datetime]::UtcNow }))
    }
    if ($store.Skipped) { Copy-Item -LiteralPath $StorePath -Destination "$StorePath.bak" -Force -ErrorAction SilentlyContinue }
    Save-StopwatchStore -Path $StorePath -Runs $store.Runs -Prepared $prepared
} finally {
    if ($lock) { try { $lock.ReleaseMutex() } catch { }; $lock.Dispose() }
}
if ($Remove) {
    Write-Host "[OK] withdrew the prepared card `"$norm`"."
} else {
    Write-Host "[OK] prepared the card `"$norm`" on /stopwatch: ready, no clock running."
    Write-Host "     The owner starts it with a prompt whose first line is: stopwatch: $norm"
}
exit 0
