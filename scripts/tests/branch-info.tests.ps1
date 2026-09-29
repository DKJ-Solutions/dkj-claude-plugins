<#
.SYNOPSIS
    Regression tests for scripts/lib/branch-info.ps1 (the shared branch conventions + type SSOT).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Dot-sources the lib and runs a series of
    asserts. Exit code 0 if everything passes, 1 on a failure -- so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/branch-info.tests.ps1

    Guards in particular the SSOT contract that closed the DRY leak (issue #81): the branch types
    have a single source (Get-BranchTypes) that release-lib.ps1 reads instead of its own copy.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\branch-info.ps1')

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

Write-Host "Get-BranchPrefix" -ForegroundColor Cyan
Assert-Equal 'feat'  (Get-BranchPrefix -Branch 'feat/new-plugin') "slash prefix 'feat/...' -> feat"
Assert-Equal 'fix'   (Get-BranchPrefix -Branch 'fix/broken-frontmatter') "slash prefix 'fix/...' -> fix"
Assert-Equal 'wip'   (Get-BranchPrefix -Branch 'wip-loose-name') "hyphen prefix without slash -> wip"

Write-Host "Get-BranchInfo" -ForegroundColor Cyan
$feat = Get-BranchInfo -Branch 'feat/new-plugin'
Assert-Equal $true        $feat.IsKnown  'known prefix -> IsKnown'
Assert-Equal 'enhancement' $feat.Label   'feat -> label enhancement'
Assert-Equal 'Feat'        $feat.Type    'feat -> type Feat'
Assert-Equal 'feat-new-plugin' $feat.SafeName 'SafeName replaces / with -'

$docs = Get-BranchInfo -Branch 'docs/update-readme'
Assert-Equal 'documentation' $docs.Label 'docs -> label documentation'
Assert-Equal 'Docs'          $docs.Type  'docs -> type Docs'

$unknown = Get-BranchInfo -Branch 'wip/experiment'
Assert-Equal $false $unknown.IsKnown 'unknown prefix -> not IsKnown'
Assert-Equal $null  $unknown.Label   'unknown prefix -> no label'
Assert-Equal $null  $unknown.Type    'unknown prefix -> no type'

Write-Host "Get-BranchTypes (type SSOT, issue #81)" -ForegroundColor Cyan
$types = @(Get-BranchTypes)
Assert-Equal 'Feat Fix Docs Chore' ($types -join ' ') 'canonical types in fixed order'

# SSOT contract: every Type value in the prefix table is a member of Get-BranchTypes, and
# conversely every canonical type has at least one prefix. This keeps the table from drifting
# relative to the canonical list (and release-lib.ps1, which reuses the list, stays in sync).
$tableTypes = @($script:BranchPrefixTable.Values | ForEach-Object { $_.Type } | Sort-Object -Unique)
foreach ($t in $tableTypes) {
    Assert-True ($types -contains $t) "table type '$t' is in Get-BranchTypes"
}
# 'Chore' IS THE ONE CANONICAL TYPE WITH NO PREFIX, SINCE AUGUST 7, 2026, and that is asserted rather than
# excused. Chore work goes directly on the trunk, so no branch produces it -- but every entry already
# written under it must still validate, so it stays in Get-BranchTypes. Pinning the exception by name is
# what makes it a decision: a table that quietly re-adds a chore row fails here, and so does dropping
# 'Chore' from the canonical list and breaking the entries that carry it.
Assert-True (-not ($tableTypes -contains 'Chore')) "'Chore' has NO prefix -- chore work goes directly on the trunk"
Assert-True ($types -contains 'Chore') "...but it is still a canonical type, because existing entries declare it"
foreach ($t in ($types | Where-Object { $_ -ne 'Chore' })) {
    Assert-True ($tableTypes -contains $t) "canonical type '$t' has a prefix in the table"
}

Write-Host "Test-BranchName (SSOT validation helper, new-branch.ps1)" -ForegroundColor Cyan
$validCheck = Test-BranchName -Branch 'feat/new-plugin'
Assert-Equal $true $validCheck.IsValid 'valid name -> IsValid'
Assert-Equal $null  $validCheck.Reason 'valid name -> no Reason'
Assert-Equal $true  $validCheck.IsKnown 'valid name (known prefix) -> IsKnown'

$mainCheck = Test-BranchName -Branch 'main'
Assert-Equal $false $mainCheck.IsValid "'main' -> IsValid false"
Assert-Equal "Branch name must not be 'main'." $mainCheck.Reason "'main' -> expected Reason"

$finalCheck = Test-BranchName -Branch 'feat/final-version'
Assert-Equal $false $finalCheck.IsValid "name with token 'final' -> IsValid false"
# THE REASON NAMES THE REMEDY, so it is asserted in two halves rather than as one literal: what was
# refused, and what to do instead. A whole-string compare would go red on every rewording of the
# explanation, which is the half most likely to be improved -- and it would say nothing about the part
# that actually has to be there.
# 'chore/' IS REFUSED (Dave, August 7, 2026): chore work goes directly on the trunk, so a chore BRANCH is
# a contradiction. Anchored to the PREFIX, unlike 'final' -- a branch may legitimately be about chores, and
# refusing that would be the over-broad match this repo already accepts for one token and no more.
$choreCheck = Test-BranchName -Branch 'chore/tidy-the-scripts'
Assert-Equal $false $choreCheck.IsValid "prefix 'chore/' -> IsValid false"
Assert-True ($choreCheck.Reason -match 'not a branch prefix') "chore -> the Reason says what was refused"
Assert-True ($choreCheck.Reason -match 'feat/, fix/ or docs/') "chore -> and names the three that are left"
Assert-Equal $true (Test-BranchName -Branch 'docs/explain-the-chore-commits').IsValid "a branch ABOUT chores is fine -- only the prefix position makes the claim"
# ...and 'Chore' survives as a TYPE, because every entry already written under it still has to validate.
Assert-True ((Get-BranchTypes) -contains 'Chore') "'Chore' is still a recognised changelog type -- existing entries carry it"

Assert-True ($finalCheck.Reason -match "must not contain the token 'final'") "token 'final' -> the Reason says what was refused"
Assert-True ($finalCheck.Reason -match '-v2') "token 'final' -> and names the remedy, so the next guess is not 'finished'"

$emptyCheck = Test-BranchName -Branch ''
Assert-Equal $false $emptyCheck.IsValid 'empty name -> IsValid false'
Assert-Equal "Branch name must not be empty." $emptyCheck.Reason 'empty name -> expected Reason'

$wsCheck = Test-BranchName -Branch '   '
Assert-Equal $false $wsCheck.IsValid 'whitespace-only name -> IsValid false'
Assert-Equal "Branch name must not be empty." $wsCheck.Reason 'whitespace-only name -> expected Reason'

$unknownCheck = Test-BranchName -Branch 'wip/experiment'
Assert-Equal $true  $unknownCheck.IsValid 'unknown prefix -> IsValid true (soft-warn path, no hard reject)'
Assert-Equal $false $unknownCheck.IsKnown 'unknown prefix -> IsKnown false'

# U+212A KELVIN SIGN folds to `k` under a plain -notmatch, so the ASCII allowlist admitted it -- and git
# accepts it in a branch name (#2520). Written as a code point: the script layer is ASCII.
$kelvinCheck = Test-BranchName -Branch ('fix/' + [char]0x212A)
Assert-Equal $false $kelvinCheck.IsValid 'a name carrying the Kelvin sign -> IsValid false (case-sensitive allowlist, #2520)'
Assert-Equal $true (Test-BranchName -Branch 'fix/Upper-K').IsValid '...while upper-case ASCII is still admitted'

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
