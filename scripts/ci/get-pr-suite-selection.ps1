<#
.SYNOPSIS
    Issue #3309: decides how THIS CI job runs the test suites. Prints
    'pr-suite-selection: mode=<mode> -- <reason>' and, inside GitHub Actions, writes 'mode' and 'suites'
    to $env:GITHUB_OUTPUT for the suites step (and the Linux leg) to read.

.DESCRIPTION
    THE FOUR MODES:
      full     -- run as before: the shard's slice of the whole pool. Every PR that changes anything but
                  static assets, every push, and every read that failed.
      skip     -- run nothing in this job. Only for an asset-only PR, and only in a job that is not the
                  one running the selection (shards 2..N, and the Linux leg).
      selected -- run exactly 'suites' (comma-separated file names), unsharded. Shard 1 of an asset-only
                  PR, once the selection is proven. 'suites' may be empty, which means none.
      whole    -- run the whole pool unsharded in this one job. Shard 1 of an asset-only PR whose
                  selection could NOT be proven: the other shards have already skipped on the cheap path
                  verdict, so this job has to carry the pool alone. Slow, and correct.

    WHY THE PATH VERDICT AND THE SELECTION ARE SPLIT. The verdict is a string test over the changed
    paths, so every job can afford it. The selection parses ~480 scripts (about a minute on a cold CI
    runner), so only shard 1 pays for it. That split is what makes 'whole' necessary.

    THE CHANGED PATHS COME FROM THE MERGE COMMIT ITSELF. A pull_request run checks out
    refs/pull/N/merge at depth 1. Its first parent is the base and its tree is what CI judges, so
    'git diff HEAD^1 HEAD' is exactly what this PR changes against the base it would land on. The
    parents are fetched here (depth 2) rather than by deepening every checkout in ci.yml.

    FAIL-CLOSED: any read that fails, or any event that is not pull_request, answers 'full'. The rules
    themselves are in scripts/lib/ci-suite-selection-lib.ps1.
#>
[CmdletBinding()]
param(
    # 1-based shard of the suites matrix; 0 for a job outside it (the Linux leg).
    [int]$Shard = 0
)
$ErrorActionPreference = 'Stop'

function Write-SelectionVerdict {
    param([string]$Mode, [string]$Reason, [string[]]$Suites = @())
    Write-Host "pr-suite-selection: mode=$Mode -- $Reason"
    if ($Mode -eq 'selected') {
        foreach ($s in $Suites) { Write-Host "  selected: $s" }
    }
    if ($env:GITHUB_OUTPUT) {
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "mode=$Mode"
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value ("suites=" + ($Suites -join ','))
    }
}

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
. (Join-Path $PSScriptRoot '../lib/native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '../lib/ci-suite-selection-lib.ps1')

if ($env:GITHUB_EVENT_NAME -ne 'pull_request') {
    Write-SelectionVerdict -Mode 'full' -Reason "event is '$($env:GITHUB_EVENT_NAME)', not 'pull_request'"
    exit 0
}

$paths = $null
try {
    if ($env:GITHUB_SHA) {
        # A failed fetch is not judged here: the diff below then fails on the missing parent, and that answers 'full'.
        $null = Invoke-NativeCapture -FilePath 'git' -DiscardStderr -Arguments @('fetch', '--no-tags', '--quiet', '--depth=2', 'origin', $env:GITHUB_SHA)
    }
    $read = Invoke-NativeCapture -FilePath 'git' -DiscardStderr -Arguments @('-c', 'core.quotePath=true', 'diff', '--name-only', '--no-renames', 'HEAD^1', 'HEAD')
    if ($read.ExitCode -eq 0) { $paths = @($read.Output | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) }
} catch { $paths = $null }
if ($null -eq $paths) {
    # EVERY JOB READS FOR ITSELF, so a failed read here says nothing about the others: shards 2..N may
    # have read an asset-only change and skipped. Shard 1 is the one job that can cover for them, so its
    # fail-closed answer is the whole pool, not its own slice (#3309, Victor's review).
    $failMode = if ($Shard -eq 1) { 'whole' } else { 'full' }
    Write-SelectionVerdict -Mode $failMode -Reason 'the changed paths could not be read (git diff HEAD^1 HEAD failed)'
    exit 0
}

# THE BRANCH'S OWN DOCUMENT IS NOT PART OF THE JUDGED CHANGE (#3370) -- see Remove-BranchDocumentPath.
# Resolved through the same resolver every gate uses, for the PR's head branch. A resolver that fails
# leaves the path set untouched, so the document stays in and the verdict stays 'full'.
try {
    if ($env:GITHUB_HEAD_REF) {
        . (Join-Path $RepoRoot 'scripts/lib/branch-info.ps1')
        . (Join-Path $PSScriptRoot '../lib/entry-scaffold-lib.ps1')
        $branchDoc = Resolve-BranchFilePath -Kind File -RepoRoot $RepoRoot -Branch $env:GITHUB_HEAD_REF
        $without = @(Remove-BranchDocumentPath -ChangedPaths $paths -BranchDocument $branchDoc)
        if ($without.Count -lt $paths.Count) {
            Write-Host "pr-suite-selection: not judging $branchDoc -- the branch's own development document (#3370)"
            $paths = $without
        }
    }
} catch {
    # The exception's TYPE, not its message: a message can carry foreign text, and stripping it would load
    # check-report-lib.ps1 into every shard for one line (#2271's guard).
    Write-Host "pr-suite-selection: the branch document could not be resolved ($($_.Exception.GetType().Name)); it stays in the judged change"
}

$assets = Get-StaticAssetVerdict -ChangedPaths $paths
if (-not $assets.AssetOnly) {
    Write-SelectionVerdict -Mode 'full' -Reason $assets.Reason
    exit 0
}

if ($Shard -ne 1) {
    Write-SelectionVerdict -Mode 'skip' -Reason ("every changed path is a static asset ({0}); shard 1 runs the suites that read them" -f ($assets.Extensions -join ', '))
    exit 0
}

. (Join-Path $PSScriptRoot '../lib/gate-lib.ps1')
$configPath = Join-Path $RepoRoot 'scripts/repo-config.ps1'
if (Test-Path -LiteralPath $configPath) { . $configPath }
$selection = $null
try {
    $selection = Get-StaticAssetSuiteSelection -RepoRoot $RepoRoot -ChangedPaths $paths
} catch {
    $selection = [pscustomobject]@{ Proven = $false; Reason = "the selection failed: $($_.Exception.Message)" }
}
if (-not $selection.Proven) {
    Write-SelectionVerdict -Mode 'whole' -Reason "asset-only, but the selection is not proven -- $($selection.Reason). Running the whole pool in this shard."
    exit 0
}
$names = @($selection.Suites | ForEach-Object { ($_ -split '/')[-1] })
Write-SelectionVerdict -Mode 'selected' -Suites $names -Reason ("asset-only ({0}): {1} of {2} suites -- {3} reached by a changed path, {4} tree walk(s) that name the extension" -f ($assets.Extensions -join ', '), $names.Count, $selection.PoolCount, @($selection.Matched).Count, @($selection.KeptAlways).Count)
exit 0
