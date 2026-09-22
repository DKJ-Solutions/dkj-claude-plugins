<#
.SYNOPSIS
    Tests for scripts/lib/ci-merge-skip-lib.ps1 -- issue #2303's pure combiner and PR-number
    parse, used by scripts/ci/get-merge-suite-skip.ps1 to decide whether a 'merge:' push to main
    may skip the test suites.

.DESCRIPTION
    PURE FUNCTIONS ONLY -- no git, no gh, no network. Every branch of Get-MergeCommitSuiteSkipVerdict
    is exercised directly against already-fetched facts, the same split every sibling in pr-issues-lib
    (Get-StaleCertificateVerdict, Get-CertifyingRunCreatedAt) is tested under.

    FAIL-CLOSED IS THE PROPERTY UNDER TEST, not merely the happy path: the negative cases outnumber the
    positive one on purpose, because the cost of getting this wrong in the SKIP direction is a red trunk
    with a green required check -- the exact hazard #1292 exists to prevent -- while the cost of getting
    it wrong in the RUN direction is a suite that was not strictly necessary. That asymmetry is why every
    ambiguous or unreadable input below is asserted to answer Skip=$false.

    Dependency-free (no Pester), same style as the rest of the suite. Pure ASCII.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\ci-merge-skip-lib.ps1'
$ScriptPath = Join-Path $RepoRoot 'scripts\ci\get-merge-suite-skip.ps1'

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

Assert-True (Test-Path -LiteralPath $LibPath) 'ci-merge-skip-lib.ps1 exists at its registered source path'
. $LibPath

Write-Host ''
Write-Host 'Get-MergeCommitPrNumber' -ForegroundColor Cyan

Assert-Equal '2303' (Get-MergeCommitPrNumber -Message 'merge: feat/2303-conditional-merge-commit-suite-skip (#2303)') `
    'reads the number out of ship-pr''s own subject shape'
Assert-Equal '7' (Get-MergeCommitPrNumber -Message 'merge: fix/x (#7)') 'and a short branch name/number alike'
Assert-Equal $null (Get-MergeCommitPrNumber -Message 'fold: feat/x changelog (#12)') 'a fold subject is not a merge subject, even with the same tail shape'
Assert-Equal $null (Get-MergeCommitPrNumber -Message 'Merge pull request #504 from Owner/feat/x') 'GitHub''s own default merge subject (no type prefix) does not match'
Assert-Equal $null (Get-MergeCommitPrNumber -Message 'merge: feat/x') 'a subject missing the (#NN) tail does not match'
Assert-Equal $null (Get-MergeCommitPrNumber -Message '') 'an empty subject does not match'
Assert-Equal $null (Get-MergeCommitPrNumber -Message $null) 'and neither does $null'
# ANCHORED AT THE END, per the lib's own docstring: a number embedded earlier in the branch name must
# not be picked up in place of the trailing, authoritative one.
Assert-Equal '99' (Get-MergeCommitPrNumber -Message 'merge: fix/12-something (#99)') `
    'a number embedded in the branch name is not read in place of the trailing (#NN)'

Write-Host ''
Write-Host 'Get-MergeCommitSuiteSkipVerdict -- the one path that answers Skip=$true' -ForegroundColor Cyan

$freshStale = [pscustomobject]@{ Stale = $false; Count = 0; Commits = @(); ExemptCount = 0; ExemptCommits = @() }
$verdict = Get-MergeCommitSuiteSkipVerdict -RequiredCheckOutcome 'pass' -CertifyingRunFound $true -StaleVerdict $freshStale
Assert-True $verdict.Skip 'pass + a dateable run + a non-stale verdict skips the suites'
Assert-True ([bool]$verdict.Reason) 'and always carries a reason'

Write-Host ''
Write-Host 'Get-MergeCommitSuiteSkipVerdict -- every other path answers Skip=$false' -ForegroundColor Cyan

Assert-True (-not (Get-MergeCommitSuiteSkipVerdict -RequiredCheckOutcome 'fail' -CertifyingRunFound $true -StaleVerdict $freshStale).Skip) `
    'a failing required check refuses, even with a fresh certificate'
Assert-True (-not (Get-MergeCommitSuiteSkipVerdict -RequiredCheckOutcome 'pending' -CertifyingRunFound $true -StaleVerdict $freshStale).Skip) `
    'a pending check refuses'
Assert-True (-not (Get-MergeCommitSuiteSkipVerdict -RequiredCheckOutcome 'unknown' -CertifyingRunFound $true -StaleVerdict $freshStale).Skip) `
    'an unreadable check (Get-CheckOutcome''s own "unknown") refuses'
Assert-True (-not (Get-MergeCommitSuiteSkipVerdict -RequiredCheckOutcome 'pass' -CertifyingRunFound $false -StaleVerdict $freshStale).Skip) `
    'pass with no dateable run behind it refuses -- a run that cannot be dated proves nothing datable'
Assert-True (-not (Get-MergeCommitSuiteSkipVerdict -RequiredCheckOutcome 'pass' -CertifyingRunFound $true -StaleVerdict $null).Skip) `
    'pass with a run found but no staleness verdict at all refuses'

$staleVerdict = [pscustomobject]@{ Stale = $true; Count = 2; Commits = @('a', 'b'); ExemptCount = 0; ExemptCommits = @() }
Assert-True (-not (Get-MergeCommitSuiteSkipVerdict -RequiredCheckOutcome 'pass' -CertifyingRunFound $true -StaleVerdict $staleVerdict).Skip) `
    'pass, a dateable run, but main gained real commits since it -- refuses'
Assert-True ((Get-MergeCommitSuiteSkipVerdict -RequiredCheckOutcome 'pass' -CertifyingRunFound $true -StaleVerdict $staleVerdict).Reason -match '2') `
    'and the refusal names how many commits'

# A fold-exempt-only gain (Stale=$false via Get-StaleCertificateVerdict's own exemption) still skips --
# this function trusts the Stale FLAG, not the raw commit list, which is exactly what lets #1592's fold
# exemption reach this predicate for free.
$foldOnlyStale = [pscustomobject]@{ Stale = $false; Count = 0; Commits = @(); ExemptCount = 3; ExemptCommits = @('x', 'y', 'z') }
Assert-True (Get-MergeCommitSuiteSkipVerdict -RequiredCheckOutcome 'pass' -CertifyingRunFound $true -StaleVerdict $foldOnlyStale).Skip `
    'commits gained that are ALL fold-exempt still skip -- the exemption reaches this predicate through the Stale flag'

Write-Host ''
Write-Host 'The lib and the script are ASCII' -ForegroundColor Cyan

$rawLib = Get-Content -LiteralPath $LibPath -Raw
Assert-True (-not ($rawLib -cmatch '[^\x00-\x7F]')) 'ci-merge-skip-lib.ps1 is pure ASCII'
Assert-True (Test-Path -LiteralPath $ScriptPath) 'scripts/ci/get-merge-suite-skip.ps1 exists'
$rawScript = Get-Content -LiteralPath $ScriptPath -Raw
Assert-True (-not ($rawScript -cmatch '[^\x00-\x7F]')) 'get-merge-suite-skip.ps1 is pure ASCII'

# NOT A MIRRORED/SHARED SCRIPT, DELIBERATELY -- unlike ci-fold-lib.ps1, nothing in ship-pr.ps1 or
# open-pr.ps1 calls into this file. It is a dependency of ci.yml alone, this repo's own internal CI
# workflow, which #1300's own precedent (the fold shortcut) never mirrored either.
Assert-True ((Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1') -Raw) -notmatch 'ci-merge-skip-lib') `
    'ci-merge-skip-lib is correctly NOT registered as a shared script -- it serves ci.yml alone'

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
