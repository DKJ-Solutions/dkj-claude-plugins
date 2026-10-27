<#
.SYNOPSIS
    Fast-forward this checkout's trunk to origin -- or, with -AllCheckouts, every checkout on this
    machine -- wherever that cannot touch anybody's work (issue #3605).

.DESCRIPTION
    The command half of #3605; the other half is the SessionStart prep hook
    (plugins/dkj-policy/hooks/trunk-sync-sessionprep.ps1), which does the same for the checkout a
    session opens in. Both call Invoke-TrunkFastForward (trunk-sync-lib.ps1), so the safety conditions
    have one definition: on the trunk, no uncommitted change to a tracked file, not diverged, and the
    move is 'git merge --ff-only'. A checkout that fails one is skipped and says why; nothing is
    stashed, rebased or merged.

    Exits 1 when any checkout FAILED (a fetch or the fast-forward itself), or when -AllCheckouts cannot
    read the install administration; a skip is not a failure.

    Dual-context: run the root copy in this repo, the plugin mirror in a consumer. Pure ASCII, per
    this repo's script-layer convention.

.PARAMETER AllCheckouts
    Sync every checkout on this machine that holds a plugin install record, instead of only the one
    you are standing in. The checkouts are read off ~/.claude/plugins/installed_plugins.json (every
    record's projectPath) -- the same set update-plugins -AllCheckouts sweeps. git runs there with the
    checkout's own hooks and core.fsmonitor switched off, because nobody opened those repos this time. Records naming a folder
    that is gone are counted into one summary line (tidy-machine owns those records).

.PARAMETER DryRun
    Fetch and measure, move nothing: each checkout reports what it would do.

.PARAMETER RootOverride
    Repo root for the single-checkout run, for the test suite. A consumer never types this.

.PARAMETER UserHomeOverride
    The home directory '~/.claude' hangs off, for the test suite. A consumer never types this.

.EXAMPLE
    ./scripts/task/sync-trunk.ps1
.EXAMPLE
    ./scripts/task/sync-trunk.ps1 -AllCheckouts
#>
[CmdletBinding()]
param(
    [switch]$AllCheckouts,
    [switch]$DryRun,
    [string]$RootOverride = '',
    [string]$UserHomeOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The source-repo guard, wired the way every shared entry point wires it.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\trunk-sync-lib.ps1')

function Write-SyncLine {
    param($Result)
    $color = switch ($Result.Outcome) { 'failed' { 'Red' } 'skipped' { 'Yellow' } default { 'Green' } }
    $what = switch ($Result.Outcome) {
        'synced'  { "fast-forwarded '$($Result.Trunk)' by $($Result.Behind) commit(s)" }
        'would'   { "would fast-forward '$($Result.Trunk)' by $($Result.Behind) commit(s)" }
        'current' { "'$($Result.Trunk)' is current with origin" }
        default   {
            $behind = if ($Result.Behind -gt 0) { " ($($Result.Behind) behind)" } else { '' }
            "$($Result.Detail)$behind"
        }
    }
    Write-Host ("  {0,-8} {1} -- {2}" -f $Result.Outcome, $Result.Path, $what) -ForegroundColor $color
}

if (-not $AllCheckouts) {
    $repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'sync-trunk.ps1' -OverrideName '-RootOverride'
    $r = Invoke-TrunkFastForward -RepoRoot $repoRoot -DryRun:$DryRun
    Write-SyncLine $r
    exit $(if ($r.Outcome -eq 'failed') { 1 } else { 0 })
}

if ($RootOverride) {
    Write-Host 'sync-trunk: -AllCheckouts and -RootOverride cannot be combined -- the sweep reads its checkouts off the install administration.' -ForegroundColor Red
    exit 1
}
$admin = Get-InstallRecord -RepoRoot (Get-Location).Path -UserHomeOverride $UserHomeOverride
if (-not $admin.Exists -or -not $admin.Readable) {
    $why = if (-not $admin.Exists) { 'it does not exist' } else { "it does not parse: $($admin.Error)" }
    Write-Host "sync-trunk -AllCheckouts: cannot read the install administration ($($admin.Path)) -- $why." -ForegroundColor Red
    exit 1
}

# Distinct project paths, case-insensitively and without a trailing separator, ordinally sorted so the
# run order is the same on every machine -- as update-plugins -AllCheckouts reads them.
$seen = @{}
foreach ($rec in @($admin.AllRecords)) {
    $p = [string]$rec.ProjectPath
    if (-not $p) { continue }
    $key = $p.TrimEnd('\', '/').ToLowerInvariant()
    if (-not $seen.ContainsKey($key)) { $seen[$key] = $p.TrimEnd('\', '/') }
}
$paths = [string[]]@($seen.Values)
if ($paths.Count -gt 1) { [array]::Sort($paths, [System.StringComparer]::OrdinalIgnoreCase) }

Write-Host "sync-trunk -AllCheckouts -- $($paths.Count) checkout(s) in the install administration$(if ($DryRun) { ', -DryRun' })" -ForegroundColor Cyan
$gone = 0
$results = New-Object System.Collections.Generic.List[object]
foreach ($p in $paths) {
    if (-not (Test-Path -LiteralPath $p -PathType Container)) { $gone++; continue }
    # -NoRepoHooks: a checkout the person did not open this time runs none of its own hooks or fsmonitor
    # (security review) -- see Get-TrunkSyncGitPrefix.
    $r = Invoke-TrunkFastForward -RepoRoot $p -DryRun:$DryRun -NoRepoHooks
    $results.Add($r)
    Write-SyncLine $r
}
if ($gone -gt 0) {
    Write-Host "  $gone install record path(s) name a folder that is gone -- tidy-machine reports and clears them." -ForegroundColor Yellow
}
$count = { param($o) @($results | Where-Object { $_.Outcome -eq $o }).Count }
$failed = & $count 'failed'
$moved = (& $count 'synced') + (& $count 'would')
Write-Host ("sync-trunk -AllCheckouts: {0} {1}, {2} current, {3} skipped, {4} failed." -f $moved, $(if ($DryRun) { 'would move' } else { 'synced' }), (& $count 'current'), (& $count 'skipped'), $failed) -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
exit $(if ($failed -gt 0) { 1 } else { 0 })
