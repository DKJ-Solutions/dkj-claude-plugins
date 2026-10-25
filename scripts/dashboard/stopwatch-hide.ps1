<#
.SYNOPSIS
    Hide a Stopwatch run, or every run of a label, on every machine -- or show it again (#3446). The documented
    entry point is the stopwatch-hide skill (.claude/skills/stopwatch-hide/SKILL.md).

.DESCRIPTION
    A run lives in the store of the machine that recorded it, and that machine publishes it to its own ref on origin
    at every sync, so deleting it anywhere else does not stick. This script writes a hide entry into THIS machine's
    stopwatch-hidden.json instead, then runs the sync, which publishes the entry in this machine's own payload. Every
    machine's pages leave out what any machine hid; the newest entry for a run id or label wins, so -Show undoes a
    hide from whichever machine wrote it. The machine that recorded a hidden run erases it from its own store at its
    next sync (#3453), and from then on -Show cannot bring it back. The rules are in
    scripts/lib/stopwatch-sync-lib.ps1.

      -RunId <id>      hide one run (its id, e.g. 20261023-112047-da87)
      -Label <label>   hide every finished run of that label (exact text, as the page's card names it in full)
      -Show            with -RunId or -Label: show it again
      -List            print the hide entries this machine knows of (its own and, as last fetched, every other's)
      -NoSync          write the entry but do not sync; the next sync (at most five minutes) publishes it

    -StorePath, -RepoRoot and -Remote are for the tests. Exits 0 when the entry was written (the sync's outcome is
    printed, and a failed sync is retried by every later one), 1 on a refusal.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [string]$RunId = '',
    [string]$Label = '',
    [switch]$Show,
    [switch]$List,
    [switch]$NoSync,
    [string]$StorePath = '',
    [string]$RepoRoot = '',
    [string]$Remote = 'origin'
)
$ErrorActionPreference = 'Stop'
$here = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $here 'scripts\lib\dev-pages-lib.ps1')
. (Join-Path $here 'scripts\lib\stopwatch-lib.ps1')
. (Join-Path $here 'scripts\lib\stopwatch-sync-lib.ps1')
$root = if ($RepoRoot) { $RepoRoot } else { $here }
if (-not $StorePath) { $StorePath = Get-StopwatchStorePath }
$hidePath = Get-StopwatchHiddenPath -StorePath $StorePath
$machine = Get-StopwatchMachineId -StoreDir (Split-Path -Parent $StorePath)
$own = Read-StopwatchHidden -Path $hidePath
if ($own.Error) {
    Write-Host "[REFUSED] $hidePath does not read ($($own.Error)) -- nothing was written. Repair or remove it by hand first."
    exit 1
}
$shared = Read-StopwatchShared -RepoRoot $root -MachineId $machine

if ($List) {
    # A label from another machine's payload is printed with every non-ASCII character as \uXXXX, so no control or bidi character reaches the console.
    $safe = { param([string]$s) [regex]::Replace($s, '[^\x20-\x7E]', { param($m) '\u' + ([int][char]$m.Value).ToString('x4') }) }
    $state = Get-StopwatchHiddenState -Entries (@($own.Entries) + @($shared.Hidden))
    Write-Host "Hide entries this machine ($machine) wrote:"
    if (-not @($own.Entries).Count) { Write-Host '  (none)' }
    foreach ($e in @($own.Entries | Sort-Object { $_.At })) { Write-Host ('  ' + $(if ($e.Hidden) { 'hide' } else { 'show' }) + ' ' + $e.Kind + ' "' + (& $safe $e.Value) + '" at ' + (Format-StopwatchStamp $e.At)) }
    Write-Host "Hidden on every machine now (newest entry wins, other machines as last fetched):"
    if (-not ($state.Runs.Count + $state.Labels.Count)) { Write-Host '  (nothing)' }
    foreach ($k in @($state.Runs.Keys | Sort-Object)) { Write-Host "  run   $k" }
    foreach ($k in @($state.Labels.Keys | Sort-Object)) { Write-Host ('  label "' + (& $safe $k) + '"') }
    exit 0
}

if ([bool]$RunId -eq [bool]$Label) {
    Write-Host '[REFUSED] name exactly one of -RunId or -Label (or pass -List) -- nothing was written.'
    exit 1
}
$kind = if ($RunId) { 'run' } else { 'label' }
$value = if ($RunId) { $RunId } else { $Label }
# Wrapped: a function's one-element array arrives unrolled, and $entries[-1] on a bare hashtable is a key lookup.
$entries = @(Set-StopwatchHiddenEntry -Entries $own.Entries -Kind $kind -Value $value -Hidden (-not $Show) | Where-Object { $_ })
if (-not $entries.Count) {
    Write-Host "[REFUSED] '$value' is not a $(if ($RunId) { 'run id' } else { 'label' }) -- nothing was written."
    exit 1
}
$written = $entries[-1]

# A name that matches no run this machine can see is written anyway (the run may be on a machine not fetched yet), but said.
$known = @(@((Read-StopwatchStore -Path $StorePath).Runs) + @($shared.Runs) | Where-Object { if ($kind -eq 'run') { $_.Id -ceq $written.Value } else { $_.Label -ceq $written.Value } })
Save-StopwatchHidden -Path $hidePath -Entries $entries
Write-Host ('[OK] ' + $(if ($Show) { 'shown again' } else { 'hidden' }) + ": $kind `"$($written.Value)`" ($(@($known).Count) run(s) this machine can see).")
if (-not @($known).Count) { Write-Host "     No run this machine can see matches it: check the spelling (a label is matched exactly, in full)$(if ($Show) { ', or it has already been erased' })." }
if (-not $Show) { Write-Host '     The machine that recorded it erases it at its next sync; -Show brings it back only until then.' }

if ($NoSync) { Write-Host '     Not synced (-NoSync): the next sync publishes it.'; exit 0 }
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'scripts\dashboard\stopwatch-sync.ps1') -StorePath $StorePath -RepoRoot $root -Remote $Remote *> $null
$log = Join-Path (Split-Path -Parent $StorePath) 'stopwatch-sync.log'
$line = if (Test-Path -LiteralPath $log -PathType Leaf) { [System.IO.File]::ReadAllText($log).Trim() } else { '(no sync log)' }
Write-Host "     sync: $line"
exit 0
