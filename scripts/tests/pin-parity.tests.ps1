<#
.SYNOPSIS
    Tests that the actions/checkout pin the scaffolder hands a consumer is the same one this repo runs
    on itself, and that it is a SHA rather than a tag (issue #1904).

.DESCRIPTION
    WHY THIS SUITE EXISTS. adopt-merge-queue.ps1 composes two WRITE-CAPABLE runners into a consumer's
    .github/ -- fold-on-merge.yml, which spends a fine-grained PAT belonging to somebody who bypasses
    the trunk ruleset, and verify-resolved.yml, which holds issues: write. Both were composed with a
    mutable `actions/checkout@v5` until #1904, while this repo's own committed copies of the same two
    jobs were SHA-pinned and the comment on the first of them said exactly why: a mutable tag on that
    line could retag its way into exfiltrating a 366-day standing write token instead of an hour-lived
    one. The repo that wrote the warning was protected; the repos that took its advice were not.

    A PIN IS ONLY HALF AN ANSWER, AND THIS SUITE IS THE OTHER HALF. Pinning the generator fixes today
    and creates a slower problem: this repo's workflows are hand-maintained and a scaffolder's are not,
    so the moment somebody bumps .github/workflows/fold-on-merge.yml and does not think about the
    generator, every consumer's floor silently stays behind the floor the source runs on -- and nothing
    reports it, because both files are individually valid. That divergence is what these asserts fail
    on. The refresh point is ONE variable ($checkoutPin); this is the gate that says when to move it.

    THE THREE PROPERTIES, and each fails silently without an assert:

      1. the generator's pin is a 40-character SHA, not a tag. This is the property #1904 was filed on,
         and the one a later edit reaching for readability would quietly undo;
      2. it EQUALS the pin in this repo's own fold-on-merge.yml -- the parity above;
      3. verify-resolved.yml here carries that same SHA, so "this repo's own pin" is one answer rather
         than two that happen to agree today.

    WHAT IS DELIBERATELY NOT ASSERTED: that every actions/checkout in .github/ is pinned. Several are
    not, correctly -- a read-only runner holding contents: read and no secret has nothing to exfiltrate,
    and repo-settings.yml is unpinned here for that reason. Pinning is a property of the JOB, not of the
    line, so a blanket assert would be wrong in exactly the cases the reasoning already covers.

    Dependency-free: no Pester, only PowerShell. Exit 0 if everything passes, 1 on a failure.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Get-CheckoutSha {
    <#
        Pulls the 40-character SHA out of an `actions/checkout@<ref>` reference, wherever it sits. Returns
        $null when the ref is not a SHA -- which is the finding, not an error, so the caller asserts on it
        rather than being thrown at.
    #>
    param([string]$Text)
    $m = [regex]::Match($Text, 'actions/checkout@([0-9a-f]{40})')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

Write-Host 'pin-parity.tests -- the scaffolded checkout pin against this repo''s own' -ForegroundColor Cyan
Write-Host ''

# --- 1. The generator pins by SHA -----------------------------------------------------------------
# Read from the ROOT copy. The plugin mirror is held byte-identical by the shared-scripts drift lint,
# so asserting both would be asserting that lint twice; if the mirror ever diverges, that gate is the
# one that must say so.
Write-Host '-- 1. the generator pins by SHA rather than by tag --' -ForegroundColor Cyan
$genPath = Join-Path $RepoRoot 'scripts\task\adopt-merge-queue.ps1'
Assert-True (Test-Path -LiteralPath $genPath) 'adopt-merge-queue.ps1 is where this suite expects it'
$gen = Get-Content -LiteralPath $genPath -Raw

$genSha = Get-CheckoutSha $gen
Assert-True ($null -ne $genSha) 'the generator names actions/checkout by a 40-character SHA'
Assert-True ($gen -notmatch 'actions/checkout@v\d') 'and no mutable actions/checkout@vN tag survives in it'

# ONE refresh point, not four literals. Four copies of a SHA is four places to forget.
$pinAssignments = ([regex]::Matches($gen, '(?m)^\$checkoutPin\s*=')).Count
Assert-Equal 1 $pinAssignments 'the pin is assigned exactly once, so it has a single refresh point'

# --- 2. Parity with this repo's own fold runner ----------------------------------------------------
Write-Host '-- 2. it equals the pin this repo runs on itself --' -ForegroundColor Cyan
$foldPath = Join-Path $RepoRoot '.github\workflows\fold-on-merge.yml'
Assert-True (Test-Path -LiteralPath $foldPath) 'this repo''s own fold-on-merge.yml is present'
$foldSha = Get-CheckoutSha (Get-Content -LiteralPath $foldPath -Raw)
Assert-True ($null -ne $foldSha) 'and it too names actions/checkout by SHA'
Assert-Equal $foldSha $genSha 'the scaffolded pin is the SAME SHA this repo''s fold runner uses'

# --- 3. This repo's own two write-capable runners agree with each other -----------------------------
# Without this, "this repo's own pin" is two answers that happen to match today, and a bump to one of
# them would move the parity target while leaving the other behind.
Write-Host '-- 3. both of this repo''s write-capable runners carry that same SHA --' -ForegroundColor Cyan
$verifyPath = Join-Path $RepoRoot '.github\workflows\verify-resolved.yml'
Assert-True (Test-Path -LiteralPath $verifyPath) 'this repo''s own verify-resolved.yml is present'
$verifySha = Get-CheckoutSha (Get-Content -LiteralPath $verifyPath -Raw)
Assert-Equal $foldSha $verifySha 'verify-resolved.yml pins the same SHA as fold-on-merge.yml'

Write-Host ''
Write-Host "pin-parity.tests: $script:pass passed, $script:fail failed." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
