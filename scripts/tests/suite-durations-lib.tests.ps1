<#
.SYNOPSIS
    Tests for scripts/lib/suite-durations-lib.ps1 -- the CI-log parser shared by
    record-suite-durations.ps1 and measure-suites.ps1 (issue #2775).

.DESCRIPTION
    THE PROPERTY THAT WOULD BREAK SILENTLY IS THE ROW VALIDATION. test-suite-gate.tests.ps1 prints a
    duration table over its own fixtures into the same log, in the same shape as the real one, so a
    parser that kept every matching row would mix fixture seconds into the pool total and look exactly
    like data. Case 2 pins that a row naming a suite outside the known set is dropped AND counted.

    CASE 4 IS THE SHARD READ: only jobs named 'suites (<n>)' are shards, and a shard that never started
    has no wall-clock -- reading it as 0 would make it the fastest shard rather than no shard.

    CASE 5 PINS THE FAMILY TOTALS, including that a malformed spec throws rather than totalling nothing:
    a family that silently matches no suite reads as a family that costs nothing.

    Dependency-free (no Pester), same style as the rest of the suite. Only the pure functions are
    exercised; the two gh readers need a network and are measured by running the script.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\suite-durations-lib.ps1'

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

Write-Host "== suite-durations-lib ==" -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $LibPath) 'suite-durations-lib.ps1 exists'
. $LibPath

# 1 -- the run-id list, in the -File form that arrives as one string
Assert-Equal '111|222|333' ((Split-RunIdList -RunId @('111,222 333')) -join '|') 'a comma- and space-separated string splits into its ids'
Assert-Equal 0 (@(Split-RunIdList -RunId @()).Count) 'and no ids is an empty list, not one empty id'

# 2 -- the rows: kept against the known set, everything else dropped and counted
$known = @{ 'alpha.tests.ps1' = $true; 'beta.tests.ps1' = $true }
$lines = @(
    "suites (1)`tRun suites`t2026-10-03T12:40:00Z    249.2s  alpha.tests.ps1  started +40.9s",
    "suites (2)`tRun suites`t2026-10-03T12:40:00Z     12.0s  beta.tests.ps1  started +0.0s",
    "suites (2)`tRun suites`t2026-10-03T12:40:00Z      1.4s  fixture-a.tests.ps1  started +0.1s",
    "suites (2)`tRun suites`t2026-10-03T12:40:00Z  alpha.tests.ps1 took 249.2s",
    'nothing here'
)
$parsed = Get-SuiteDurationRows -Lines $lines -KnownNames $known
Assert-Equal 2 @($parsed.Rows).Count 'both real suite rows are kept'
Assert-Equal 1 $parsed.Dropped 'the fixture row is dropped and counted'
Assert-Equal 249.2 ($parsed.Rows | Where-Object Name -eq 'alpha.tests.ps1').Seconds 'a row''s seconds are read as written'
Assert-Equal 0 @((Get-SuiteDurationRows -Lines @() -KnownNames $known).Rows).Count 'an empty log yields no rows'

# 3 -- the means
$samples = @{ 'beta.tests.ps1' = @(10.0, 13.0); 'alpha.tests.ps1' = @(100.04) }
$means = Get-SuiteMeans -Samples $samples
Assert-Equal 'alpha.tests.ps1|beta.tests.ps1' (@($means.Keys) -join '|') 'the means are ordered by suite name'
Assert-Equal 11.5 $means['beta.tests.ps1'] 'a suite''s mean is over its samples'
Assert-Equal 100 $means['alpha.tests.ps1'] 'and rounded to a tenth'

# 4 -- the shards
$jobs = @(
    [pscustomobject]@{ name = 'lint';       startedAt = '2026-10-03T12:38:22Z'; completedAt = '2026-10-03T12:39:20Z' },
    [pscustomobject]@{ name = 'suites (2)'; startedAt = '2026-10-03T12:38:22Z'; completedAt = '2026-10-03T12:42:17Z' },
    [pscustomobject]@{ name = 'suites (1)'; startedAt = '2026-10-03T12:38:23Z'; completedAt = '2026-10-03T12:45:04Z' },
    [pscustomobject]@{ name = 'suites (3)'; startedAt = $null;                  completedAt = $null }
)
$shards = @(Get-ShardSeconds -Jobs $jobs)
Assert-Equal 'suites (1)|suites (2)' (($shards | ForEach-Object Name) -join '|') 'only started suites jobs are shards, in shard order'
Assert-Equal 401 $shards[0].Seconds 'a shard''s wall-clock is its completedAt minus its startedAt'
Assert-Equal 235 $shards[1].Seconds 'for every shard'

# 5 -- the families
$fm = [ordered]@{ 'check-plugin-integrity-a.tests.ps1' = 10.0; 'check-plugin-integrity-b.tests.ps1' = 5.5; 'bwj-x.tests.ps1' = 2.0; 'bwj-development.tests.ps1' = 3.0 }
$fam = Get-FamilyTotals -Means $fm -Family @('integrity=check-plugin-integrity-*', 'bwj=bwj-*;bwj-development.tests.ps1', 'none=zzz-*')
Assert-Equal 15.5 $fam['integrity'].Seconds 'a family totals the suites its glob matches'
Assert-Equal 2 $fam['integrity'].Suites 'and counts them'
Assert-Equal 5 $fam['bwj'].Seconds 'several globs joined by ; all count, each suite once'
Assert-Equal 0 $fam['none'].Suites 'a family matching nothing is reported as zero suites, not left out'
$threw = $false
try { Get-FamilyTotals -Means $fm -Family @('integrity') | Out-Null } catch { $threw = $true }
Assert-True $threw 'a family without =glob throws rather than totalling nothing'

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:pass) passed, $($script:fail) failed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: $($script:pass) passed." -ForegroundColor Green
exit 0
