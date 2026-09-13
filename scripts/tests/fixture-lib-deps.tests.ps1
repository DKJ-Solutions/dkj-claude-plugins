<#
.SYNOPSIS
    Regression tests for scripts/lib/fixture-dep-lib.ps1, and the gate itself: no hand-listed fixture
    lib copies under scripts/tests may go stale against what those libs dot-source (issue #1693), in a
    suite or in a fixture builder the suites share (issue #1865), nor against what the copied SCRIPT
    dot-sources at load time (issue #1924).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/fixture-lib-deps.tests.ps1

    WHY THIS SUITE IS ALSO THE GATE. The tree-wide pass at the bottom is the check #1693 asked for; it
    lives here rather than as a numbered check in check-plugin-integrity.ps1 for one reason, and it is
    worth stating plainly: while this was written, another branch was repairing that script's .SYNOPSIS
    check list (#1680), and appending a check would have meant both of us rewriting the same block. The
    merits were even -- that file already carries a fixture-shaped check ([fixture-git]) and this one
    already carries three tree-walking meta-suites (shared-scripts, subagent-shared,
    template-selfcontained) -- so collision decided it. Moving it later is a one-call change: the
    reading is all in the lib, and Get-FixtureDepReport is the whole answer.

    WHAT WAS MEASURED BEFORE ANY OF IT WAS BUILT, because a gate here arrives measured:

      1. THE SCOPE IN #1693 IS SHORT. It names five suites; twelve copy a lib into a fixture. Its five
         counts are all exactly right (8/8/8/6/2) -- the list was incomplete, not wrong.
         AND SO WAS THIS SUITE'S OWN SCOPE, one layer down and for the same reason (#1865, September 11,
         2026): "twelve suites copy a lib" is a count of SUITES, and the reader was filtered to
         '*.tests.ps1' to match it. check-plugin-integrity-fixture.ps1 copies fourteen libs, is shared by
         four lint suites, and is not a suite by name -- so the one builder here that four suites depend
         on was invisible to the gate, measured on #1860's branch where this suite reported seven correct
         findings and the four lint suites then died on lib load anyway. Thirteen subjects now, and the
         scan set is every .ps1 in this directory.
      1b. AND SO WAS THE SUBJECT ITSELF, one axis over (#1924, September 13, 2026). Both widenings above
         are about WHICH FILES are read; this one is about WHAT IS READ IN THEM. The check asked, for each
         copied LIB, whether that lib's siblings came too -- and never asked it of the SCRIPT the fixture
         exists to run. Measured on the #1917 branch, which gave ~25 acting scripts an unguarded
         dot-source of check-report-lib.ps1: six fixture-based suites broke on exactly that (fold-changelog
         155 asserts red, prune-merged 73, park-branch 18, new-branch and two more dead on load) and this
         suite reported all 26 of its asserts passed throughout.
         THE WIDENING IS NOT BORN GREEN ON EVERY DOT-SOURCE, WHICH IS WHY IT IS NARROWED TO LOAD TIME.
         Seeding from all of a script's dot-sources reports 10 subjects on the clean tree; all ten are
         CONDITIONAL ones a fixture legitimately declines to carry -- source-repo-guard-lib.ps1 in eight,
         whose refusal cannot fire in a fixture at all, since a fixture has no marketplace.json. Seeding
         from the load-time ones alone reports none, and still reports the whole of the measured class.
         Measured again as the reconstruction in the section below, which is this file's standing way of
         proving a widening catches what it was built for rather than merely staying quiet.
      2. THE REAL INSTANCE DOT-SOURCES THROUGH A VARIABLE. On origin/fix/1682-porcelain-line-parse,
         park-lib.ps1 reads
             $parkPorcelainLib = Join-Path $PSScriptRoot 'git-porcelain-lib.ps1'
             if (Test-Path -LiteralPath $parkPorcelainLib -PathType Leaf) { . $parkPorcelainLib }
         so the dot-source command's own text is `. $parkPorcelainLib` and names no file at all. The
         first version of this reader matched on that text and missed the ONLY real instance of the
         class it was built for. EVERY lib in scripts/lib that dot-sources a sibling does it that way --
         no exceptions at the time of writing -- so this is the normal shape here, not an edge case.
      3. THE NAIVE CHECK IS NOT BORN GREEN, IT IS BORN 100% FALSE. Reading any literal in the Copy-Item
         (rather than its -Destination) produced two findings on a clean tree and both were wrong:
         consumer-check-lib.tests.ps1, whose fixture deliberately has no measure-context-lib sibling
         because it exists to prove the guarded load degrades, and internal-note.tests.ps1, which is
         right not to copy branch-info.ps1 because that seam is repo-owned and supplied by the caller.
         Those two findings are what shaped the reader: bind to the destination, and exempt the
         repo-owned seams. This repo declines a findings-list check on its false-positive rate (the
         stale-path check, 124 findings, all false), so shipping this without those two would have been
         proposing exactly what it turns down.
      4. AFTER BOTH: 85 suites read (this file and #1682's included), 12 subjects, 0 findings -- and the
         reconstructed pre-repair state of that real branch yields exactly 1, naming
         park-lib.ps1 -> git-porcelain-lib.ps1. The asserts below deliberately do NOT pin those two
         counts (they test `-gt 50` and `-ge 10`), because a number in an assert goes stale on the day
         somebody adds a suite -- which this file did to itself.

    AND THE READING IS NOT DONE IN THIS BRANCH'S OWN LIB. The dot-source half delegates to
    script-contract-lib.ps1's Get-ScriptDotSourceTargets: the first version was a second AST walker,
    which is the "second literal" defect this branch's sibling issue (#1682) is about. The code review
    caught it. What that also bought was the walker's own memo, and what it cost was fixing that memo's
    key -- it was path-only, so this suite's deliberate rewrites of one fixture lib were served a stale
    answer and two asserts went red.

    WALL-CLOCK, THREE RUNS EACH, BECAUSE THE COST REVIEW ASKED FOR IT: 11.0-13.2s for the first
    working version, 8.2-8.7s after memoising and splitting the AST walk, and 2.51-2.54s as it stands
    -- the last cut coming from delegating (one shared memo instead of two engines), skipping the parse
    of any suite whose text has no 'Copy-Item' in it at all (18 of them do, of the whole pool), and
    reading each subject's copy list once rather than twice. For scale, the gate's own slowest suites
    run 155-237s, so none of this was ever visible there; it is taken because it is correct and free,
    not because it was urgent.

    THE SYNTHETIC FIXTURES BELOW ARE NOT DECORATION. They were written while the gate had nothing at
    all to check -- no lib in scripts/lib dot-sourced a sibling -- so nothing but a shape assert could
    notice if the reader stopped reading. That changed when #1682 merged: park-lib.ps1 now dot-sources
    git-porcelain-lib.ps1, git-porcelain-lib.ps1 dot-sources native-capture-lib.ps1, and fanout-lib.ps1
    dot-sources three, so the tree-wide pass at the bottom is measuring a real closure and CONFIRMING
    that branch's repair of the five copy lists rather than waiting for a first subject. The shape
    asserts stay, because a green tree still cannot tell a working reader from a broken one -- and each
    one is a shape measured in the tree rather than invented.

    Pure ASCII (repo convention for .ps1).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')
. (Join-Path $RepoRoot 'scripts\lib\fixture-dep-lib.ps1')

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
        $script:fail++
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        Write-Host "         expected: $Expected" -ForegroundColor Red
        Write-Host "         actual:   $Actual" -ForegroundColor Red
    }
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

# Temp paths come from the shared composer (#1659) rather than being built here from a label: the
# fixture trees this suite writes are exactly the shape that issue is about, and #1664 is converting
# the rest of scripts/tests/ the same way.
$SandRoot = New-ScratchPath -Label 'fixdep' -Directory
$LibDir   = Join-Path $SandRoot 'lib'
$TestDir  = Join-Path $SandRoot 'tests'
New-Item -ItemType Directory -Path $LibDir  -Force | Out-Null
New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

# A SECOND SANDBOX WITH A REAL REPO SHAPE, for the script half (#1924). The flat one above is enough for
# every lib question, because a lib is only ever looked up by leaf in -LibDirectory. A copied SCRIPT is
# looked up by its repo-relative PATH under -RepoRoot, and it resolves its own libs through
# '$PSScriptRoot\..\lib' -- so nothing about that half can be exercised without the two directories
# actually standing in that relation.
$ScriptRepo = Join-Path $SandRoot 'repo'
$ScriptRepoLib  = Join-Path $ScriptRepo 'scripts\lib'
$ScriptRepoTask = Join-Path $ScriptRepo 'scripts\task'
New-Item -ItemType Directory -Path $ScriptRepoLib  -Force | Out-Null
New-Item -ItemType Directory -Path $ScriptRepoTask -Force | Out-Null

function Set-Lib {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Body)
    [System.IO.File]::WriteAllText((Join-Path $LibDir $Name), $Body, $Utf8NoBom)
}

function Set-Suite {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Body)
    $path = Join-Path $TestDir $Name
    [System.IO.File]::WriteAllText($path, $Body, $Utf8NoBom)
    return $path
}

function Set-RepoLib {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Body)
    [System.IO.File]::WriteAllText((Join-Path $ScriptRepoLib $Name), $Body, $Utf8NoBom)
}

function Set-RepoScript {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Body)
    [System.IO.File]::WriteAllText((Join-Path $ScriptRepoTask $Name), $Body, $Utf8NoBom)
}

function Clear-Sandbox {
    Get-ChildItem -Path $LibDir  -File | Remove-Item -Force
    Get-ChildItem -Path $TestDir -File | Remove-Item -Force
}

try {
    # ---------------------------------------------------------------------------------------------
    Write-Host 'Get-DotSourcedLibName -- the two shapes a dependency arrives in' -ForegroundColor Cyan

    # THE VARIABLE SHAPE IS THE ONE THAT MATTERS, and it is copied verbatim from park-lib.ps1 on
    # origin/fix/1682-porcelain-line-parse -- the guard included, because the guard is why the miss is
    # silent rather than a crash.
    Set-Lib -Name 'a-lib.ps1' -Body @'
$aDep = Join-Path $PSScriptRoot 'b-lib.ps1'
if (Test-Path -LiteralPath $aDep -PathType Leaf) { . $aDep }
function Get-A { 'a' }
'@
    Set-Lib -Name 'b-lib.ps1' -Body "function Get-B { 'b' }`n"

    Assert-Equal 'b-lib.ps1' ((Get-DotSourcedLibName -Path (Join-Path $LibDir 'a-lib.ps1') -RepoRoot $SandRoot) -join ',') `
        'a dependency dot-sourced through a variable is read -- the #1682 shape, which the first reader missed'

    # The literal shape, which is what a synthetic-only suite would have tested and passed on.
    Set-Lib -Name 'c-lib.ps1' -Body ". (Join-Path `$PSScriptRoot 'b-lib.ps1')`nfunction Get-C { 'c' }`n"
    Assert-Equal 'b-lib.ps1' ((Get-DotSourcedLibName -Path (Join-Path $LibDir 'c-lib.ps1') -RepoRoot $SandRoot) -join ',') `
        'and so is one written out inside the dot-source itself'

    # A COMMENT CANNOT REACH IT. park-lib.ps1's own header carries a dot-source of itself as an
    # .EXAMPLE; the AST does not see comments, which is why this reader can be trusted near docstrings.
    Set-Lib -Name 'd-lib.ps1' -Body @'
<#
    .EXAMPLE
        . (Join-Path $PSScriptRoot 'b-lib.ps1')
#>
function Get-D { 'd' }
'@
    Assert-Equal '' ((Get-DotSourcedLibName -Path (Join-Path $LibDir 'd-lib.ps1') -RepoRoot $SandRoot) -join ',') `
        'a dot-source inside a docstring is not a dependency -- the AST cannot see comments'

    # NAMING A .ps1 IS NOT DEPENDING ON IT. shared-scripts-lib.ps1's registry names every mirrored
    # script in the tree; a reader that took every literal would report all of them.
    Set-Lib -Name 'e-lib.ps1' -Body "`$script:Registry = @('b-lib.ps1', 'x-lib.ps1')`nfunction Get-E { 'e' }`n"
    Assert-Equal '' ((Get-DotSourcedLibName -Path (Join-Path $LibDir 'e-lib.ps1') -RepoRoot $SandRoot) -join ',') `
        'a .ps1 named in a string but never dot-sourced is not a dependency'

    # ---------------------------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'Get-FixtureCopiedLibName -- the DESTINATION is the subject, not the source' -ForegroundColor Cyan

    # Every one of these copies READS FROM scripts\lib\<x>.ps1 in the real repo, so a reader that takes
    # any literal takes the source as well -- which is what produced two false findings on a clean
    # tree. The flat destination here is consumer-check-lib.tests.ps1's real shape.
    $flat = Set-Suite -Name 'flat.tests.ps1' -Body @'
Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\a-lib.ps1') -Destination (Join-Path $loneDir 'a-lib.ps1')
'@
    Assert-Equal '' ((Get-FixtureCopiedLibName -Path $flat) -join ',') `
        'a copy whose destination is NOT a fixture scripts/lib is not a subject, however its source reads'

    $named = Set-Suite -Name 'named.tests.ps1' -Body @'
Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\a-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\a-lib.ps1') -Force
'@
    Assert-Equal 'a-lib.ps1' ((Get-FixtureCopiedLibName -Path $named) -join ',') `
        'the named -Destination form is read'

    # THE POSITIONAL FORM IS IN THIS TREE TOO -- source-repo-guard.tests.ps1 writes it this way, and a
    # reader that handled only the named form stopped treating that suite as a subject at all.
    $positional = Set-Suite -Name 'positional.tests.ps1' -Body @'
Copy-Item $GuardLib (Join-Path $awayDir 'scripts\lib\a-lib.ps1')
'@
    Assert-Equal 'a-lib.ps1' ((Get-FixtureCopiedLibName -Path $positional) -join ',') `
        'and so is the positional form, where the destination is the second positional argument'

    # A switch between the two positionals must not shift which one is the destination.
    $switched = Set-Suite -Name 'switched.tests.ps1' -Body @'
Copy-Item -Force $GuardLib (Join-Path $awayDir 'scripts\lib\a-lib.ps1')
'@
    Assert-Equal 'a-lib.ps1' ((Get-FixtureCopiedLibName -Path $switched) -join ',') `
        'a switch parameter consumes no positional, so -Force before the paths changes nothing'

    Clear-Sandbox

    # ---------------------------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'Get-FixtureDepFinding -- the gap, the closure, and what is deliberately not a finding' -ForegroundColor Cyan

    Set-Lib -Name 'a-lib.ps1' -Body @'
$aDep = Join-Path $PSScriptRoot 'b-lib.ps1'
if (Test-Path -LiteralPath $aDep -PathType Leaf) { . $aDep }
'@
    Set-Lib -Name 'b-lib.ps1' -Body @'
$bDep = Join-Path $PSScriptRoot 'c-lib.ps1'
if (Test-Path -LiteralPath $bDep -PathType Leaf) { . $bDep }
'@
    Set-Lib -Name 'c-lib.ps1' -Body "function Get-C { 'c' }`n"

    $onlyA = Set-Suite -Name 'onlya.tests.ps1' -Body @'
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\lib\a-lib.ps1') -Force
'@
    $f = @(Get-FixtureDepFinding -Path $onlyA -LibDirectory $LibDir -RepoRoot $SandRoot)
    Assert-Equal 2 $f.Count 'the CLOSURE is walked in one pass: copying only a-lib reports b AND c, not b alone'
    # @() around each filter, not for tidiness: under Set-StrictMode a Where-Object that matches ONE
    # object hands back that object rather than a list, and reading .Count off it throws.
    Assert-Equal 1 @($f | Where-Object { $_.Lib -eq 'a-lib.ps1' -and $_.Missing -eq 'b-lib.ps1' }).Count `
        'the direct dependency is named with the lib that wants it'
    Assert-Equal 1 @($f | Where-Object { $_.Lib -eq 'b-lib.ps1' -and $_.Missing -eq 'c-lib.ps1' }).Count `
        'and so is the one a level further down, attributed to b rather than to a'

    $allThree = Set-Suite -Name 'allthree.tests.ps1' -Body @'
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\lib\a-lib.ps1') -Force
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\lib\b-lib.ps1') -Force
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\lib\c-lib.ps1') -Force
'@
    Assert-Equal 0 @(Get-FixtureDepFinding -Path $allThree -LibDirectory $LibDir -RepoRoot $SandRoot).Count `
        'a complete list is silent -- the assert that keeps this from being a check that always fires'

    # A DEPENDENCY THE TREE DOES NOT CARRY IS NOT A FINDING. The guarded dot-source exists precisely
    # because a lib may legitimately not be present, and this reader has no opinion about a name that
    # is not there.
    Set-Lib -Name 'g-lib.ps1' -Body @'
$gDep = Join-Path $PSScriptRoot 'not-in-this-tree-lib.ps1'
if (Test-Path -LiteralPath $gDep -PathType Leaf) { . $gDep }
'@
    $ghost = Set-Suite -Name 'ghost.tests.ps1' -Body @'
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\lib\g-lib.ps1') -Force
'@
    Assert-Equal 0 @(Get-FixtureDepFinding -Path $ghost -LibDirectory $LibDir -RepoRoot $SandRoot).Count `
        'a dot-source of a lib the tree does not have is not a finding'

    # A CYCLE MUST NOT SPIN. Two libs dot-sourcing each other is not a shape in this tree, and the
    # visited set is what makes that a safe thing to be true rather than a lucky one.
    Set-Lib -Name 'p-lib.ps1' -Body @'
$pDep = Join-Path $PSScriptRoot 'q-lib.ps1'
if (Test-Path -LiteralPath $pDep -PathType Leaf) { . $pDep }
'@
    Set-Lib -Name 'q-lib.ps1' -Body @'
$qDep = Join-Path $PSScriptRoot 'p-lib.ps1'
if (Test-Path -LiteralPath $qDep -PathType Leaf) { . $qDep }
'@
    $cycle = Set-Suite -Name 'cycle.tests.ps1' -Body @'
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\lib\p-lib.ps1') -Force
'@
    $cf = @(Get-FixtureDepFinding -Path $cycle -LibDirectory $LibDir -RepoRoot $SandRoot)
    Assert-Equal 1 $cf.Count 'a cycle terminates and reports once rather than spinning'

    # ---------------------------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'The repo-owned seam exemption (the second false finding on a clean tree)' -ForegroundColor Cyan

    Assert-Equal 'branch-info.ps1' ((Get-FixtureDepRepoOwnedSeam) -join ',') `
        'exactly one seam is exempt, and the list is read from the lib rather than restated here'

    Set-Lib -Name 'r-lib.ps1' -Body @'
$rSeam = Join-Path $PSScriptRoot 'branch-info.ps1'
if (Test-Path -LiteralPath $rSeam -PathType Leaf) { . $rSeam }
'@
    Set-Lib -Name 'branch-info.ps1' -Body "function Get-BranchInfo { }`n"
    $seamSuite = Set-Suite -Name 'seam.tests.ps1' -Body @'
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\lib\r-lib.ps1') -Force
'@
    Assert-Equal 0 @(Get-FixtureDepFinding -Path $seamSuite -LibDirectory $LibDir -RepoRoot $SandRoot).Count `
        'a repo-owned seam the caller supplies is not a debt the fixture owes -- internal-note.tests.ps1 is why'

    # And the exemption is narrow: the same shape with a non-seam lib IS reported, so the list is doing
    # the work rather than the reader having quietly stopped looking.
    Set-Lib -Name 's-lib.ps1' -Body @'
$sDep = Join-Path $PSScriptRoot 'c-lib.ps1'
if (Test-Path -LiteralPath $sDep -PathType Leaf) { . $sDep }
'@
    $nonSeam = Set-Suite -Name 'nonseam.tests.ps1' -Body @'
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\lib\s-lib.ps1') -Force
'@
    Assert-Equal 1 @(Get-FixtureDepFinding -Path $nonSeam -LibDirectory $LibDir -RepoRoot $SandRoot).Count `
        'while an ordinary sibling in the same position is still reported'

    # ---------------------------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'The per-path memo is keyed on the FILE, not the path' -ForegroundColor Cyan

    # THIS IS A REGRESSION ASSERT WITH A RED IT ACTUALLY HAD. Get-DotSourcedLibName memoises, because
    # Get-FixtureDepFinding asks it once per (suite, lib) pair; keyed on the path alone it answered
    # from the cache after a rewrite, and two asserts above went red on the stale answer. A cache that
    # is only correct while every caller remembers not to rewrite a file is enforced by memory, so the
    # key carries the timestamp and the length. Asserted directly rather than left to the sections
    # above to notice, because there it looked like a closure bug.
    Set-Lib -Name 'cache-lib.ps1' -Body @'
$cacheDep = Join-Path $PSScriptRoot 'c-lib.ps1'
if (Test-Path -LiteralPath $cacheDep -PathType Leaf) { . $cacheDep }
'@
    Assert-Equal 'c-lib.ps1' ((Get-DotSourcedLibName -Path (Join-Path $LibDir 'cache-lib.ps1') -RepoRoot $SandRoot) -join ',') `
        'the first read of a lib answers from the file'

    Start-Sleep -Milliseconds 20   # so the rewrite lands on a different last-write tick
    Set-Lib -Name 'cache-lib.ps1' -Body "function Get-Cache { 'nothing dot-sourced now' }`n"
    Assert-Equal '' ((Get-DotSourcedLibName -Path (Join-Path $LibDir 'cache-lib.ps1') -RepoRoot $SandRoot) -join ',') `
        'and a rewrite at the SAME path is read again rather than served from the memo'

    # ---------------------------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'An unparseable file throws rather than reading as "no dependencies"' -ForegroundColor Cyan

    # An empty answer here means "nothing to copy", which is the silence this lib exists to remove. So
    # a file that cannot be parsed must fail loudly instead of passing quietly.
    Set-Lib -Name 'broken-lib.ps1' -Body "function Get-Broken { `n"
    $threw = $false
    try { $null = Get-DotSourcedLibName -Path (Join-Path $LibDir 'broken-lib.ps1') -RepoRoot $SandRoot } catch { $threw = $true }
    Assert-True $threw 'an unparseable lib throws, so a parse failure can never read as a clean dependency set'

    # ---------------------------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'The COPIED SCRIPT is a subject too, and it is read at LOAD TIME only (#1924)' -ForegroundColor Cyan

    # THE RECONSTRUCTION OF #1917, which is the instance this whole half exists for: an acting script
    # gains an unguarded dot-source at the top of the file, and every fixture that copies it dies during
    # load -- reporting a missing fixture DOCUMENT, because the script never got as far as writing one.
    # The guarded dot-source beside it is the control: identical shape, one `if` around it, and the two
    # must not answer the same way.
    Set-RepoLib -Name 'report-lib.ps1' -Body "function Resolve-RepoRootOrFail { }`n"
    Set-RepoLib -Name 'optional-lib.ps1' -Body "function Get-Optional { }`n"
    Set-RepoLib -Name 'inner-lib.ps1' -Body "function Get-Inner { }`n"
    Set-RepoScript -Name 'acting.ps1' -Body @'
. (Join-Path $PSScriptRoot '..\lib\report-lib.ps1')
$optional = Join-Path $PSScriptRoot '..\lib\optional-lib.ps1'
if (Test-Path -LiteralPath $optional -PathType Leaf) { . $optional }
function Invoke-Late {
    . (Join-Path $PSScriptRoot '..\lib\inner-lib.ps1')
}
'@

    Assert-Equal 'inner-lib.ps1,optional-lib.ps1,report-lib.ps1' `
        ((Get-DotSourcedLibName -Path (Join-Path $ScriptRepoTask 'acting.ps1') -RepoRoot $ScriptRepo) -join ',') `
        'without -LoadTimeOnly all three are dot-sources -- the contract check''s question, unchanged'

    Assert-Equal 'report-lib.ps1' `
        ((Get-DotSourcedLibName -Path (Join-Path $ScriptRepoTask 'acting.ps1') -RepoRoot $ScriptRepo -LoadTimeOnly) -join ',') `
        'with it, only the top-level unguarded one -- a Test-Path guard and a function body both drop out'

    $scriptSuite = Set-Suite -Name 'script.tests.ps1' -Body @'
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\task\acting.ps1') -Force
'@
    Assert-Equal 'scripts/task/acting.ps1' ((Get-FixtureCopiedScriptPath -Path $scriptSuite) -join ',') `
        'a copied acting script is read as a repo-relative PATH, not a leaf -- the file has to be found again'

    # AND THE TWO READERS PARTITION THE DESTINATIONS. A scripts/lib copy belongs to the lib reader and
    # must not also arrive here, or every lib would be walked twice and attributed under two names.
    $bothSuite = Set-Suite -Name 'both.tests.ps1' -Body @'
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\task\acting.ps1') -Force
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\lib\report-lib.ps1') -Force
'@
    Assert-Equal 'scripts/task/acting.ps1' ((Get-FixtureCopiedScriptPath -Path $bothSuite) -join ',') `
        'and a scripts/lib destination is NOT also a script -- the two readers split the destinations'
    Assert-Equal 'report-lib.ps1' ((Get-FixtureCopiedLibName -Path $bothSuite) -join ',') `
        'while the lib reader still sees only the lib, unchanged by the second reader beside it'

    $sf = @(Get-FixtureDepFinding -Path $scriptSuite -LibDirectory $ScriptRepoLib -RepoRoot $ScriptRepo)
    Assert-Equal 1 $sf.Count 'the fixture that copies the script and not its load-time lib is reported'
    Assert-Equal 'report-lib.ps1' ($sf[0].Missing) 'and the lib named is the unguarded one'
    Assert-Equal 'scripts/task/acting.ps1' ($sf[0].Lib) `
        'attributed to the SCRIPT that wants it, by the path the suite copies -- so the finding names the file to edit'

    Assert-Equal 0 @(Get-FixtureDepFinding -Path $bothSuite -LibDirectory $ScriptRepoLib -RepoRoot $ScriptRepo).Count `
        'and copying that lib silences it, without the guarded and in-function ones ever being demanded'

    # THE CLOSURE RUNS FROM A SCRIPT'S DEPENDENCY TOO, in the same pass. Without this the author repairs
    # the first lib, re-runs, and is told about its sibling on the second round -- the round-trip
    # Get-FixtureDepFinding's own docstring refuses for the lib half.
    Set-RepoLib -Name 'report-lib.ps1' -Body @'
$chained = Join-Path $PSScriptRoot 'chained-lib.ps1'
if (Test-Path -LiteralPath $chained -PathType Leaf) { . $chained }
'@
    Set-RepoLib -Name 'chained-lib.ps1' -Body "function Get-Chained { }`n"
    $chainFindings = @(Get-FixtureDepFinding -Path $scriptSuite -LibDirectory $ScriptRepoLib -RepoRoot $ScriptRepo)
    Assert-Equal 2 $chainFindings.Count `
        'a lib the script loads, and what THAT lib dot-sources, are both reported in one pass'
    Assert-Equal 1 @($chainFindings | Where-Object { $_.Lib -eq 'report-lib.ps1' -and $_.Missing -eq 'chained-lib.ps1' }).Count `
        'and the second is attributed to the lib rather than to the script -- the guarded rule applies again below the seed'

    # A DESTINATION NAMING NO FILE IN THE REPO IS NOT A FINDING, the same judgement the lib half makes
    # about a dependency the tree does not carry.
    $ghostScript = Set-Suite -Name 'ghostscript.tests.ps1' -Body @'
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\task\not-in-this-tree.ps1') -Force
'@
    Assert-Equal 0 @(Get-FixtureDepFinding -Path $ghostScript -LibDirectory $ScriptRepoLib -RepoRoot $ScriptRepo).Count `
        'a copied script this repo does not have is not a finding -- there is nothing to read'

    # ---------------------------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'The declared opt-out -- and the reason is part of the syntax' -ForegroundColor Cyan

    # THIS MECHANISM WAS SPECIFIED BEFORE IT WAS NEEDED, in Get-FixtureCopiedLibName's own docstring under
    # #1693, and #1924 produced the first instance: source-repo-guard.tests.ps1 copies check-branch-entry
    # into an away directory to watch the guard REFUSE it, so the run exits 1 before any other lib loads.
    $optSuite = Set-Suite -Name 'optout.tests.ps1' -Body @'
# fixture-dep: script-not-loaded scripts/task/acting.ps1 -- the guard refuses it before any lib loads
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\task\acting.ps1') -Force
'@
    Assert-Equal 'scripts/task/acting.ps1' ((Get-FixtureDepScriptOptOut -Path $optSuite) -join ',') `
        'the declaration is read off the comment -- the one reader here that is text rather than AST'
    Assert-Equal 0 @(Get-FixtureDepFinding -Path $optSuite -LibDirectory $ScriptRepoLib -RepoRoot $ScriptRepo).Count `
        'and a declared script is not walked at all'

    # THE MALFORMED ONE MUST NOT DISARM THE GATE. A directive with no ' -- <why>' is the shape somebody
    # writes in a hurry, and silently honouring it would turn a typo into a switched-off check.
    $noReason = Set-Suite -Name 'noreason.tests.ps1' -Body @'
# fixture-dep: script-not-loaded scripts/task/acting.ps1
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\task\acting.ps1') -Force
'@
    Assert-Equal 0 @(Get-FixtureDepScriptOptOut -Path $noReason).Count `
        'a declaration with no reason is not a declaration'
    Assert-True (@(Get-FixtureDepFinding -Path $noReason -LibDirectory $ScriptRepoLib -RepoRoot $ScriptRepo).Count -gt 0) `
        'so the finding still stands -- a malformed opt-out fails loud rather than switching the gate off'

    # A DIRECTIVE INSIDE A STRING IS DATA, NOT A DECLARATION -- the mirror image of the docstring assert
    # near the top of this file, and a red this reader actually had. The first version matched the raw
    # file text, and THIS suite writes synthetic opt-out fixtures into here-strings: the tree-wide count
    # below read 3 where the tree held 1. Reading the parser's comment tokens separates the two, so the
    # fixture written here is deliberately the shape that caught it.
    $inString = Set-Suite -Name 'instring.tests.ps1' -Body @'
$body = @"
# fixture-dep: script-not-loaded scripts/task/acting.ps1 -- written into a fixture, not declared here
"@
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\task\acting.ps1') -Force
'@
    Assert-Equal 0 @(Get-FixtureDepScriptOptOut -Path $inString).Count `
        'a directive inside a string is not a declaration -- only a real comment token is'
    Assert-True (@(Get-FixtureDepFinding -Path $inString -LibDirectory $ScriptRepoLib -RepoRoot $ScriptRepo).Count -gt 0) `
        'so a suite that merely writes the directive into a fixture does not exempt itself'

    # And it is scoped to the script it names, not to the file it sits in.
    $otherScript = Set-Suite -Name 'otherscript.tests.ps1' -Body @'
# fixture-dep: script-not-loaded scripts/task/something-else.ps1 -- unrelated
Copy-Item -LiteralPath $x -Destination (Join-Path $dir 'scripts\task\acting.ps1') -Force
'@
    Assert-True (@(Get-FixtureDepFinding -Path $otherScript -LibDirectory $ScriptRepoLib -RepoRoot $ScriptRepo).Count -gt 0) `
        'a declaration naming a different script exempts nothing'

    Clear-Sandbox

    # ---------------------------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'THE GATE: this repo own fixtures, held against what their copied libs dot-source' -ForegroundColor Cyan

    $report = Get-FixtureDepReport -TestsDirectory (Join-Path $RepoRoot 'scripts\tests') `
                                   -LibDirectory   (Join-Path $RepoRoot 'scripts\lib') `
                                   -RepoRoot       $RepoRoot

    # BOTH FIGURES, BECAUSE A SILENT PASS NEEDS BOTH. Zero findings over zero subjects is a reader that
    # found nothing to read; zero over thirteen is the tree being clean. The two must never print the
    # same line -- the same reason check-plugin-integrity.ps1's span checks print both.
    Assert-True ($report.Files -gt 50) "the whole tests directory was read (found $($report.Files) files)"
    Assert-True ($report.Subjects -ge 10) `
        "and $($report.Subjects) of them copy a lib into a fixture -- so this gate has subjects rather than being vacuous"

    # THE SCAN SET IS EVERY '.ps1', NOT ONLY THE SUITES (issue #1865). Both figures above are
    # thresholds, deliberately -- a pinned count goes stale the day somebody adds a suite. But the whole
    # repair here is that the non-suite files entered the scan set, and a threshold cannot notice them
    # leaving again: check-plugin-integrity-fixture.ps1 is the fixture builder four lint suites share,
    # is not named '*.tests.ps1', and a filter narrowed back to that pattern still passes both asserts.
    # So this compares what was READ against what is THERE, which no later suite can blur.
    $testDir = Join-Path $RepoRoot 'scripts\tests'
    $allPs1 = @(Get-ChildItem -Path $testDir -Filter '*.ps1' -File).Count
    $suiteNamed = @(Get-ChildItem -Path $testDir -Filter '*.tests.ps1' -File).Count
    Assert-Equal $allPs1 $report.Files `
        "every .ps1 in scripts/tests was read, not only the $suiteNamed named '*.tests.ps1' (#1865)"
    Assert-True ($allPs1 -gt $suiteNamed) `
        "and the tree still holds a non-suite .ps1 for that to be about ($($allPs1 - $suiteNamed) of them)"

    # The builder itself is the reason, so it is named rather than left to the count. It copies its libs
    # by -Destination like every suite does, so being in the scan set is the whole of what it needed.
    $builderCopies = @(Get-FixtureCopiedLibName -Path (Join-Path $testDir 'check-plugin-integrity-fixture.ps1'))
    Assert-True ($builderCopies.Count -ge 10) `
        "the shared integrity fixture builder is a subject ($($builderCopies.Count) libs copied), though its name is not a suite's"

    # THE SCRIPT HALF NEEDS ITS OWN NON-VACUITY ASSERT (#1924), for the same reason Subjects is returned
    # at all: the whole widening is silent when it reads nothing, and 'zero findings' looks identical
    # either way. A threshold rather than a count, on this file's own standing rule that a pinned number
    # goes stale the day somebody adds a suite.
    $copiedScripts = @(Get-ChildItem -Path $testDir -Filter '*.ps1' -File |
                        ForEach-Object { Get-FixtureCopiedScriptPath -Path $_.FullName })
    Assert-True ($copiedScripts.Count -ge 8) `
        "and $($copiedScripts.Count) acting scripts are copied into fixtures, so the script half has subjects too"

    # THE DECLARED OPT-OUTS ARE COUNTED, not because the number matters but because the mechanism is one
    # a later reader could quietly start leaning on. One today: source-repo-guard.tests.ps1. A tree that
    # grows a dozen is one where the asymmetry in Get-FixtureDepFinding stopped fitting, and that is worth
    # noticing as a number rather than discovering as a habit.
    $optOuts = @(Get-ChildItem -Path $testDir -Filter '*.ps1' -File |
                    ForEach-Object { Get-FixtureDepScriptOptOut -Path $_.FullName })
    Assert-True ($optOuts.Count -le 3) `
        "the declared opt-out stays rare ($($optOuts.Count) in the tree) -- it is an exception, not a way of passing the gate"

    if ($report.Findings.Count -gt 0) {
        foreach ($f in $report.Findings) {
            Write-Host "         $($f.File): $($f.Lib) dot-sources $($f.Missing), which the fixture does not copy" -ForegroundColor Red
        }
    }
    Assert-Equal 0 $report.Findings.Count `
        'every fixture copies the libs its copied libs dot-source (#1693)'

} finally {
    if (Test-Path -LiteralPath $SandRoot) {
        Remove-Item -Recurse -Force -LiteralPath $SandRoot -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
