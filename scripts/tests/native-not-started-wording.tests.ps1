<#
.SYNOPSIS
    Regression tests for issue #2250: the six gh sites that composed their own sentence about an
    unmeasured exit code, and so described a gh that is NOT INSTALLED as one that ran.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/native-not-started-wording.tests.ps1

    WHAT #2234 LEFT BEHIND, AND WHY IT NEEDED A SUITE OF ITS OWN. That issue made Invoke-NativeCapture
    return a verdict instead of throwing when the executable cannot be started, and the capture it
    returns sets ExitCodeUnknown = $true DELIBERATELY -- that is exactly what lets the ~63 sites audited
    under #2081 keep working untouched. The cost is that "could not be started" is a SUBSET of "not
    measured", so every site whose unmeasured arm hand-writes its own sentence absorbs the not-started
    case and says two false things about it: that gh ran, which is precisely what did not happen, and
    that a re-run normally settles it, which is false ADVICE rather than merely imprecise -- a command
    that is not installed does not settle, so a reader who follows it re-runs forever while the real
    remedy is never named.

    ORDER IS THE WHOLE MECHANISM, WHICH IS WHY THIS IS STRUCTURAL. The repair at each site is a
    Test-NativeCommandStarted arm placed AHEAD of the Test-NativeExitMeasured one. Reversed, the broader
    test answers first and the new arm is unreachable -- and nothing about that failure is visible: the
    site still compiles, still refuses, still prints a sentence. So the property a suite can hold is not
    "the arm exists" but "the arm exists and sits above the one that would swallow it", which is the same
    property claim-issue.tests.ps1 already pins for #2234's own repair, one site over.

    WHY THE SOURCE TEXT AND NOT A LIVE RUN. Fixturing an absent gh means a PATH with no gh on it, which
    is machine state rather than a shim, and four of these six sites additionally need a live tracker, a
    credential and a consumer repository to reach at all. A suite can either assert nothing here or
    assert the wrong thing; what it CAN hold is that the two properties travel with the code. Same
    reasoning, and the same named test gap, as claim-issue.tests.ps1 records for its own two structural
    cases.

    TWO OF THE SIX ARE WORDED DIFFERENTLY ON PURPOSE, and case 3 is what stops that being read as drift.
    check-repo-settings.ps1 and check-connectors.ps1 both sit behind a `Get-Command gh` guard that has
    ALREADY proved gh is on PATH before their capture is taken, so "gh is not installed" would be a
    cause the run has measured to be false -- the very class of unmeasured diagnosis this whole family
    exists to stop printing. What is reachable at those two is a gh that was found and still could not be
    launched, and their sentences say that instead.

    THE SEVENTH SITE #2250 LISTS IS DELIBERATELY NOT HERE. claim-issue.ps1's parked-fix branch scan is
    the same shape, and it reads `git` rather than `gh` -- which that issue's own scope paragraph
    excludes, because git is a hard prerequisite of every script in this tree, so a run that has reached
    one of those lines has already proved git exists.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

Write-Host ''
Write-Host '== native-not-started-wording (issue #2250) ==' -ForegroundColor Cyan

# THE SIX SITES, EACH WITH THE TWO SENTENCES WHOSE ORDER IS THE REPAIR. The anchors are the sentences
# themselves rather than the predicate calls, because a file can hold several of each -- ship-pr.ps1
# alone takes 40-odd captures -- and an index of "the first Test-NativeCommandStarted in the file" would
# pass while the site under test had none at all.
$sites = @(
    @{ File        = 'scripts\lint\check-branch-entry.ps1'
       What        = 'the DEPLOY-lock read'
       NotStarted  = 'gh is not installed here, or is not on PATH (issue #2234), so the read never ran'
       Unmeasured  = 'gh ran and its exit code came back unmeasurable (issue #1931), so nothing is known about the read --' }
    @{ File        = 'scripts\lint\check-repo-settings.ps1'
       What        = 'the repo-settings read (behind a Get-Command guard)'
       NotStarted  = 'gh is on PATH but could not be started (issue #2234)'
       Unmeasured  = 'gh ran and its exit code came back unmeasurable (issue #1931), so nothing is known about this read' }
    @{ File        = 'scripts\release\ship-pr.ps1'
       What        = 'the DEPLOY-lock read'
       NotStarted  = 'gh is not installed here, or is not on PATH (issue #2234), so the read never ran'
       Unmeasured  = 'gh ran and its exit code came back unmeasurable (issue #1931), so nothing is known about the read' }
    @{ File        = 'scripts\sync\check-connectors.ps1'
       What        = "a consumer's repo read (behind a Get-Command and an auth gate)"
       NotStarted  = 'gh was found and authenticated at the start of this run but could not be started for this read (issue #2234)'
       Unmeasured  = 'gh ran and its exit code came back unmeasurable (issue #1931), so nothing arrived that this could judge' }
    @{ File        = 'scripts\sync\check-consumer-siblings.ps1'
       What        = 'the default-branch read'
       NotStarted  = 'gh is not installed here, or is not on PATH (issue #2234), so the default branch was never read'
       Unmeasured  = 'gh ran and its exit code came back unmeasurable (issue #1931) reading the default branch' }
    @{ File        = 'scripts\sync\check-consumer-siblings.ps1'
       What        = 'the tree read'
       NotStarted  = 'gh is not installed here, or is not on PATH (issue #2234), so the tree was never read'
       Unmeasured  = 'gh ran and its exit code came back unmeasurable (issue #1931) reading the tree' }
)

# --- 1. every site has a not-started arm, and it sits ABOVE the one that would swallow it -----------
Write-Host ''
Write-Host '-- 1. the arm exists, and its order is the mechanism --' -ForegroundColor Cyan
$sourceCache = @{}
foreach ($site in $sites) {
    $path = Join-Path $RepoRoot $site.File
    if (-not $sourceCache.ContainsKey($site.File)) {
        $sourceCache[$site.File] = [System.IO.File]::ReadAllText($path)
    }
    $src   = $sourceCache[$site.File]
    $leaf  = Split-Path -Leaf $site.File
    $label = "$leaf -- $($site.What)"

    $notStartedAt = $src.IndexOf($site.NotStarted)
    $unmeasuredAt = $src.IndexOf($site.Unmeasured)

    Assert-True ($notStartedAt -ge 0) "$label : names a gh that could not be started"
    Assert-True ($unmeasuredAt -ge 0) "$label : still names the unmeasurable exit code (#1931) separately"
    # THE ORDER ASSERT IS THE ONE THAT MATTERS, and it is written to FAIL rather than to pass vacuously
    # when either anchor has gone: -1 is less than any real index, so an absent not-started sentence
    # would otherwise satisfy "sits above" for free.
    Assert-True ($notStartedAt -ge 0 -and $unmeasuredAt -ge 0 -and $notStartedAt -lt $unmeasuredAt) `
        "$label : ...and that arm sits ABOVE the unmeasurable one, or it would never be reached"
}

# --- 2. no not-started sentence claims the command ran, or offers a re-run as the remedy ------------
#
# NON-CIRCULAR ON PURPOSE. Case 1 compares the source against sentences this file also holds, so it
# pins today's wording and would happily accept tomorrow's if somebody updated both. This case asserts
# a property of the source alone: any LIVE line (comments excluded -- they quote the wrong sentences in
# order to explain them) that cites #2234 as its own diagnosis must not tell the reader the child ran,
# nor send them to a re-run that a missing dependency cannot settle.
Write-Host ''
Write-Host '-- 2. the two false halves are gone from every #2234 sentence --' -ForegroundColor Cyan
foreach ($file in @($sites | ForEach-Object { $_.File } | Sort-Object -Unique)) {
    $leaf  = Split-Path -Leaf $file
    $lines = $sourceCache[$file] -split "`r?`n"
    $bad   = @()
    foreach ($line in $lines) {
        if ($line.TrimStart().StartsWith('#')) { continue }
        if ($line -notmatch '\(issue #2234\)') { continue }
        if ($line -match 'gh ran' -or $line -match 'settles on a re-run' -or $line -match 'normally settles it') {
            $bad = @($bad) + @($line.Trim())
        }
    }
    Assert-True (@($bad).Count -eq 0) "$leaf : no #2234 sentence says the child ran, or advises a re-run that cannot settle it"
}

# --- 3. the two guarded sites do NOT claim gh is absent ---------------------------------------------
#
# WHY THIS IS A TEST AND NOT A COMMENT. #2250 prescribes one shape for all six, and the obvious
# follow-up edit is to make these two "consistent" with the other four. That edit would be a
# regression of exactly the kind this family keeps paying for: a sentence naming a cause the same run
# has already measured to be false, twelve lines further up.
Write-Host ''
Write-Host '-- 3. a site behind a PATH guard names a launch failure, not an absent CLI --' -ForegroundColor Cyan
foreach ($guarded in @(
    @{ File = 'scripts\lint\check-repo-settings.ps1'; Guard = 'Get-Command gh' }
    @{ File = 'scripts\sync\check-connectors.ps1';    Guard = 'Get-Command gh' }
)) {
    $src  = $sourceCache[$guarded.File]
    $leaf = Split-Path -Leaf $guarded.File
    Assert-True ($src -match [regex]::Escape($guarded.Guard)) "$leaf : still carries the PATH guard this wording depends on"
    $liveNotInstalled = @($src -split "`r?`n" | Where-Object {
        -not $_.TrimStart().StartsWith('#') -and $_ -match '\(issue #2234\)' -and $_ -match 'is not installed here, or is not on PATH'
    })
    Assert-True (@($liveNotInstalled).Count -eq 0) "$leaf : its #2234 sentence does not claim gh is absent, which the guard above has disproved"
}

# --- 4. ship-pr's ENCLOSING sentence is conditional too ----------------------------------------------
#
# THE HALF #2250 DID NOT NAME. That report lists $lockUnread's arm, which is the parenthetical; the
# advice "so a re-run normally settles it" lived one layer out, in the Write-Warning that prints it.
# Repairing only the parenthetical would satisfy the report and still print false advice in the same
# printed sentence -- and a reader does not experience the two as separate strings.
Write-Host ''
Write-Host '-- 4. ship-pr: the advice around the parenthetical is conditional on the same fact --' -ForegroundColor Cyan
$shipSrc = $sourceCache['scripts\release\ship-pr.ps1']
Assert-True ($shipSrc -match '\$lockNotStarted\s*=\s*\$true') 'the not-started state is carried as a flag, not sniffed back out of the string'
Assert-True ($shipSrc -match '\$lockRetry\s*=\s*if \(\$lockNotStarted\)') 'the closing advice branches on that flag'
Assert-True ($shipSrc -match 'a re-run will NOT settle it') '...and says so where the command never started'
Assert-True ($shipSrc -match 'could not be read \(\$lockUnread\) -- the section was NOT compared against what the PR published, and the merge is proceeding without that check\. \$lockRetry') `
    'the warning interpolates that branch instead of hard-coding the re-run sentence'

# --- 5. every touched file still parses --------------------------------------------------------------
Write-Host ''
Write-Host '-- 5. the touched scripts parse --' -ForegroundColor Cyan
foreach ($file in @($sites | ForEach-Object { $_.File } | Sort-Object -Unique)) {
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $RepoRoot $file), [ref]$null, [ref]$errors)
    Assert-True (@($errors).Count -eq 0) "$(Split-Path -Leaf $file) parses without error"
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "native-not-started-wording.tests: $($script:pass) passed, $($script:fail) FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "native-not-started-wording.tests: $($script:pass) passed, 0 failed" -ForegroundColor Green
exit 0
