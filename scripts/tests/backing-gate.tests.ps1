<#
.SYNOPSIS
    Tests for the backing gate -- Get-BranchBackingFinding in scripts/lib/park-lib.ps1, and the
    refusal open-pr.ps1 builds on it (issue #1026).

.DESCRIPTION
    WHAT THIS EXISTS FOR. PR #1025 merged a changelog entry describing two new rules in a manual whose
    edit was never committed. The branch's whole diff was its development document; the fold then removed
    that file, so the merge delivered an entry and no content. Every gate was green -- the four that read
    the development document are all satisfied by an entry with nothing behind it, because none of them
    reads the diff.

    THE MEASUREMENT ALREADY EXISTED AND WENT TO THE WRONG READER. park-cycle's backing note (#960/#976)
    named the count and the state and gave the instruction that would have prevented the merge -- in a
    COMMIT BODY. That is right for the reader on a second device and invisible to the session holding the
    uncommitted file. This gate is the same measurement, delivered where it can still be acted on.

    SO THE PROPERTY UNDER TEST IS THE NARROWNESS, not the refusal. A gate that fires whenever a resolved
    step has no commit behind it would fire on nearly every early branch -- a planning step ticked before
    a line of code exists is the ordinary case -- and a gate firing on almost every run is one nobody
    reads by the time it matters. Most cases below assert SILENCE.

    AND THE CONDITION HAS TWO CALLERS, which is why it is a function rather than two inline tests. The
    park note describes both shapes; the gate refuses one and warns on the other. Case 5 pins that they
    still agree, because a park that alarms over a gate that stays silent is the drift this repo pays for.

    SECTIONS 8-9 EXERCISE Get-GitParkBacking ITSELF, WITH REAL GIT REPOS (issue #1399, September 4,
    2026), rather than the duck-typed shapes the rest of this file tests against. The bug lived in the
    git plumbing: a bare local trunk name in '$Trunk...HEAD' silently over-counts a branch's committed
    work once local main has fallen behind origin/main and the branch has caught up via
    'git merge origin/main' (the documented way -- a rebase would need a force-push, which the safety
    rules block). Section 8 reproduces that exact false-negative; section 9 pins the fallback (no
    origin ref -> the bare local name, exactly as before the fix) and that the returned Trunk field
    still names the bare trunk regardless of which ref actually answered the count.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
$LibPath  = Join-Path $RepoRoot 'scripts\lib\park-lib.ps1'

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

Assert-True (Test-Path -LiteralPath $LibPath) 'park-lib.ps1 exists at its registered source path'
. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')
. $LibPath

# The two inputs are duck-typed, so the fixtures are the shapes the real callers hand over and nothing
# more: Get-BranchProgressTally's counts, and Get-GitParkBacking's object.
function New-Steps {
    param([int]$Total, [int]$Open, [int]$Resolved)
    return [pscustomobject]@{ Total = $Total; Open = $Open; Resolved = $Resolved }
}
function New-Backing {
    param(
        [int]$Committed = 0, [bool]$CommittedKnown = $true,
        [int]$Uncommitted = 0, [bool]$UncommittedKnown = $true
    )
    return [pscustomobject]@{
        Committed = $Committed; CommittedKnown = $CommittedKnown
        Uncommitted = $Uncommitted; UncommittedKnown = $UncommittedKnown
        Trunk = 'main'
    }
}

# --- 1. THE CASE THIS FILE EXISTS FOR: PR #1025's exact shape ----------------------------------
Write-Host "`n== 1. a finished plan with the work still uncommitted here ==" -ForegroundColor Cyan
$f1 = Get-BranchBackingFinding -Steps (New-Steps -Total 3 -Open 0 -Resolved 3) -Backing (New-Backing -Committed 0 -Uncommitted 1)
Assert-True ([bool]$f1) 'the finding is raised'
Assert-Equal 'UncommittedHere' $f1.Kind 'and it names the repairable shape'
Assert-Equal 1 $f1.Uncommitted 'carrying the count the author needs'
Assert-Equal 3 $f1.Resolved 'and the plan state that makes it legible'
Assert-Equal 3 $f1.Total 'both halves of it'

# --- 2. the other shape: the work is not on this machine at all --------------------------------
# Different fault, different answer at the caller -- open-pr warns rather than refusing, because from
# here it is indistinguishable from a branch that legitimately ships its entry alone.
Write-Host "`n== 2. a finished plan with nothing uncommitted either ==" -ForegroundColor Cyan
$f2 = Get-BranchBackingFinding -Steps (New-Steps -Total 3 -Open 0 -Resolved 3) -Backing (New-Backing -Committed 0 -Uncommitted 0)
Assert-True ([bool]$f2) 'still a finding'
Assert-Equal 'NotInThisCheckout' $f2.Kind 'but a different kind'
Assert-Equal 0 $f2.Uncommitted 'with nothing to point the author at'

# --- 3. THE NARROWNESS, which is the property that would break silently ------------------------
# Each of these is the ordinary state of a branch mid-flight. A gate firing on any of them is one
# nobody reads by the time it matters.
Write-Host "`n== 3. everything ordinary stays silent ==" -ForegroundColor Cyan
Assert-True ($null -eq (Get-BranchBackingFinding -Steps (New-Steps -Total 3 -Open 1 -Resolved 2) -Backing (New-Backing -Uncommitted 4))) 'a half-done plan is silent, however much is uncommitted'
Assert-True ($null -eq (Get-BranchBackingFinding -Steps (New-Steps -Total 0 -Open 0 -Resolved 0) -Backing (New-Backing -Uncommitted 4))) 'a document with no steps yet is silent'
Assert-True ($null -eq (Get-BranchBackingFinding -Steps (New-Steps -Total 3 -Open 0 -Resolved 3) -Backing (New-Backing -Committed 2 -Uncommitted 1))) 'a finished plan WITH work committed is silent -- the entry has content behind it'
Assert-True ($null -eq (Get-BranchBackingFinding -Steps (New-Steps -Total 3 -Open 0 -Resolved 3) -Backing (New-Backing -Committed 1))) 'one committed file is enough to be content'

# A plan whose steps were all DROPPED rather than done still counts as resolved -- that is the marks
# rule, and it is a legitimate finished plan, so the gate must judge it on its backing like any other.
Assert-True ([bool](Get-BranchBackingFinding -Steps (New-Steps -Total 2 -Open 0 -Resolved 2) -Backing (New-Backing -Uncommitted 1))) 'resolved-by-dropping is still a finished plan'

# --- 4. an unmeasured figure is not a measured zero --------------------------------------------
# CommittedKnown is $false on a checkout with no trunk ref -- configured differently, not defective.
# Reading that as "nothing is committed" would raise the alarm on every such repo.
Write-Host "`n== 4. not measured is never treated as zero ==" -ForegroundColor Cyan
Assert-True ($null -eq (Get-BranchBackingFinding -Steps (New-Steps -Total 3 -Open 0 -Resolved 3) -Backing (New-Backing -Committed 0 -CommittedKnown $false -Uncommitted 1))) 'an unmeasurable committed count raises nothing'
$f4 = Get-BranchBackingFinding -Steps (New-Steps -Total 3 -Open 0 -Resolved 3) -Backing (New-Backing -Committed 0 -Uncommitted 9 -UncommittedKnown $false)
Assert-True ([bool]$f4) 'an unmeasurable UNCOMMITTED count still leaves a finding -- nothing is committed, which is established'
Assert-Equal 'NotInThisCheckout' $f4.Kind 'and it degrades to the warning shape rather than refusing on a number it does not have'

# --- 5. the park note and the gate read the SAME condition -------------------------------------
# The whole reason this is a function. Two spellings over one tree is how a park that alarms and a
# gate that stays silent end up disagreeing, with nothing to say which is right.
Write-Host "`n== 5. one condition, both callers ==" -ForegroundColor Cyan
$libText = [System.IO.File]::ReadAllText($LibPath)
Assert-True ($libText -match 'function Get-BranchBackingFinding') 'the condition is a named function'
# THE VERDICT, not the prose. Both functions read $Backing.CommittedKnown -- Format- to choose its
# wording, Get-BranchBackingFinding to decide -- and that is two readers of one field, not two
# conditions. What must exist exactly once is the FINISHED test itself: total/open/resolved together.
Assert-Equal 1 ([regex]::Matches($libText, '\$open -eq 0').Count) 'the finished test is spelled exactly once in the lib'
Assert-True ($libText -match '\$finding = Get-BranchBackingFinding') 'and Format-GitParkBacking asks for it rather than repeating it'

$alarmed = Format-GitParkBacking -Steps (New-Steps -Total 3 -Open 0 -Resolved 3) -Backing (New-Backing -Committed 0 -Uncommitted 1)
Assert-True ($alarmed -match 'reads as FINISHED') 'the park note alarms on the shape the gate refuses'
Assert-True ($alarmed -match 'do not open a PR') 'and still tells that reader what not to do'
$quiet = Format-GitParkBacking -Steps (New-Steps -Total 3 -Open 1 -Resolved 2) -Backing (New-Backing -Committed 0 -Uncommitted 1)
Assert-True (-not ($quiet -match 'reads as FINISHED')) 'and stays quiet on the shape the gate lets through'

# --- 6. open-pr wires it in ---------------------------------------------------------------------
# The lib being right proves nothing about it being REACHED -- the lesson pr-issues-lib cost this repo.
Write-Host "`n== 6. open-pr.ps1 reaches the gate ==" -ForegroundColor Cyan
$openPr = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\release\open-pr.ps1'))
Assert-True ($openPr -match "lib\\park-lib\.ps1") 'open-pr dot-sources park-lib'
Assert-True ($openPr -match 'Get-BranchBackingFinding -Steps \$tally -Backing \$backing') 'it asks the shared condition'
# The CALL exactly once -- the name also appears in the comment above it, which is the point of the
# comment, so counting bare mentions would pin the prose instead of the wiring.
Assert-Equal 1 ([regex]::Matches($openPr, '\$backingFinding = Get-BranchBackingFinding').Count) 'called exactly once'
Assert-Equal 0 ([regex]::Matches($openPr, '\$tally\.Open -eq 0').Count) 'and open-pr does not re-spell the condition it just asked for'
Assert-True ($openPr -match 'backing gate: the plan reads as FINISHED') 'and refuses in words naming the state'
Assert-True ($openPr -match "NotInThisCheckout") 'the other kind is handled separately'

# THE VALVE, and that it is a valve rather than a bypass: -Force must WARN, not fall silent. A gate
# whose escape valve says nothing is a gate that quietly stopped existing.
$gateBlock = [regex]::Match($openPr, '(?s)if \(\$backingFinding\).*?\n        \}').Value
Assert-True ([bool]$gateBlock) 'the gate block is findable'
Assert-True ($gateBlock -match '\$Force') 'the refusal has a -Force valve'
Assert-True ($gateBlock -match 'but -Force was given') 'and the valve still says so out loud'
Assert-True ($gateBlock -match 'exit 1') 'the un-forced path stops the run'

# It must sit AFTER the step gate: a plan with open steps is refused there first, and reporting
# "your finished plan has nothing behind it" about an unfinished plan would be nonsense.
Assert-True ($openPr.IndexOf('step-list gate:') -lt $openPr.IndexOf('backing gate:')) 'the backing gate runs after the step-list gate'
# And BEFORE the push, which is the only placement that makes it a gate at all.
Assert-True ($openPr.IndexOf('backing gate:') -lt $openPr.IndexOf("'push', '-u', 'origin'")) 'and before the push'

# --- 7. the lib travels to the consumer ---------------------------------------------------------
Write-Host "`n== 7. mirrored into the plugin ==" -ForegroundColor Cyan
. (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1')
$pairs = @(Get-SharedScriptPairs -RepoRoot $RepoRoot)
foreach ($name in @('park-lib', 'open-pr')) {
    $pair = @($pairs | Where-Object { $_.Name -eq $name })
    Assert-Equal 1 $pair.Count "$name is registered exactly once"
    if ($pair.Count -eq 1) {
        Assert-True (Test-Path -LiteralPath $pair[0].MirrorPath) "$name's mirror exists in the plugin tree"
        $mir = [System.IO.File]::ReadAllText($pair[0].MirrorPath)
        Assert-True ($mir -match 'Get-BranchBackingFinding') "$name's mirror carries the new condition"
    }
}

# --- 8 & 9. Get-GitParkBacking and a stale local trunk ref (#1399) -----------------------------
# REAL GIT REPOS FROM HERE ON, unlike the duck-typed fixtures above -- the bug lived in the git
# plumbing itself (which ref '$Trunk...HEAD' is measured against), not in the object shape the rest
# of this file tests.
$script:gitFixtures = @()

function New-GitFixture {
    <# A minimal throwaway repo with a bare 'origin', for exercising the real git calls behind
       Get-GitParkBacking. Same conventions as park-cycle.tests.ps1's New-Fixture: symbolic-ref onto
       an unborn HEAD (works whatever init.defaultBranch says locally), gpgsign off (#1287). #>
    param([Parameter(Mandatory = $true)][string]$Label, [switch]$NoOrigin)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("backing-gate-test-$PID-$Label-$([guid]::NewGuid().ToString('n'))")
    if (Test-Path -LiteralPath $dir) { Remove-Item -Recurse -Force -LiteralPath $dir }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $bareRemote = "$dir.git"
    if (Test-Path -LiteralPath $bareRemote) { Remove-Item -Recurse -Force -LiteralPath $bareRemote }
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $dir init -q
        Invoke-FixtureGitIn $dir config user.email 'tycho-tests@local.invalid'
        Invoke-FixtureGitIn $dir config user.name 'Tycho Tests'
        Invoke-FixtureGitIn $dir config commit.gpgsign false
        Invoke-FixtureGitIn $dir symbolic-ref HEAD refs/heads/main
        [System.IO.File]::WriteAllText((Join-Path $dir 'README.md'), "# fixture`n", (New-Object System.Text.UTF8Encoding $false))
        Invoke-FixtureGitIn $dir add -A
        Invoke-FixtureGitIn $dir commit -q -m 'init'
        if (-not $NoOrigin) {
            Invoke-FixtureGitJudged @('init', '--bare', '-q', $bareRemote)
            Invoke-FixtureGitIn $dir remote add origin $bareRemote
            Invoke-FixtureGitIn $dir push -q -u origin main
        }
    } finally { $ErrorActionPreference = $prevEap }
    $script:gitFixtures += $dir
    if (-not $NoOrigin) { $script:gitFixtures += $bareRemote }
    return $dir
}

function Invoke-GitQuiet {
    <# One EAP-safe git call, output discarded -- the fixture-building idiom park-cycle.tests.ps1 uses
       throughout, repeated here (rather than dot-sourced from there) so this file stays free-standing. #>
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # THE EXIT CODE IS READ, NOT DISCARDED (issue #1635). It went to Out-Null with the output, so a
        # failed fixture command was indistinguishable from a working one -- and a repo that half-built
        # is plausible rather than correct, which makes every assert below it measure the wrong thing.
        $out = & git @Arguments 2>&1
        Assert-FixtureGitOk -Code $LASTEXITCODE -GitArgs @($Arguments) -Output $out
    } finally { $ErrorActionPreference = $prevEap }
}

function Get-GitOutput {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $prevEap = $ErrorActionPreference
    try { $ErrorActionPreference = 'Continue'; return ((& git @Arguments) | Out-String).Trim() }
    finally { $ErrorActionPreference = $prevEap }
}

try {
    # -- 8. THE FALSE-NEGATIVE ITSELF: a caught-up branch with zero real commits of its own ---------
    # Local main is left one commit behind origin/main -- exactly what the normal flow allows (new-
    # branch's own base warning only warns) -- and the branch catches up the documented way,
    # 'git merge origin/main', which is a fast-forward here since the branch was never ahead. That
    # merge makes the branch's tip equal to origin/main's, so a diff against the STALE bare 'main'
    # (still at the old commit) would count the upstream commit's own file as this branch's committed
    # work. The fix prefers refs/remotes/origin/main, which 'git push' already advanced locally when
    # the upstream commit was pushed -- no fetch needed -- so the diff lands on zero real commits.
    Write-Host "`n== 8. Get-GitParkBacking prefers the remote-tracking ref over a stale local trunk ==" -ForegroundColor Cyan
    $fix8a = New-GitFixture -Label '8a'
    Invoke-GitQuiet -Arguments @('-C', $fix8a, 'checkout', '-q', '-b', 'feat/caught-up-v1')
    $shaA = Get-GitOutput -Arguments @('-C', $fix8a, 'rev-parse', 'main')
    Invoke-GitQuiet -Arguments @('-C', $fix8a, 'checkout', '-q', 'main')
    [System.IO.File]::WriteAllText((Join-Path $fix8a 'shared.txt'), "upstream change`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-GitQuiet -Arguments @('-C', $fix8a, 'add', '-A')
    Invoke-GitQuiet -Arguments @('-C', $fix8a, 'commit', '-q', '-m', 'upstream work')
    Invoke-GitQuiet -Arguments @('-C', $fix8a, 'push', '-q', 'origin', 'main')
    # 'git push' updates refs/remotes/origin/main locally on success -- modelling a fetch that already
    # happened, with no second clone or working copy required.
    Invoke-GitQuiet -Arguments @('-C', $fix8a, 'checkout', '-q', 'feat/caught-up-v1')
    # Reset LOCAL main back one commit. main is not checked out here, so this is a clean ref move, not
    # a working-copy edit -- and it is exactly the state the issue names: local main behind origin/main.
    Invoke-GitQuiet -Arguments @('-C', $fix8a, 'update-ref', 'refs/heads/main', $shaA)
    Invoke-GitQuiet -Arguments @('-C', $fix8a, 'merge', '-q', 'origin/main')

    $backing8a = Get-GitParkBacking -RepoRoot $fix8a -Trunk 'main'
    Assert-Equal 0 $backing8a.Committed 'stale local trunk: the remote-tracking ref is used, so a caught-up branch with no real commits reports zero'
    Assert-True $backing8a.CommittedKnown 'stale local trunk: the figure is measured, not unknown'
    Assert-Equal 'main' $backing8a.Trunk "stale local trunk: the Trunk field still names the bare trunk ('main'), not the ref it resolved to"

    # -- 9. THE FALLBACK, unchanged from before the fix ----------------------------------------------
    Write-Host "`n== 9. Get-GitParkBacking falls back to the bare trunk name when no origin ref exists ==" -ForegroundColor Cyan
    $fix9a = New-GitFixture -Label '9a' -NoOrigin
    Invoke-GitQuiet -Arguments @('-C', $fix9a, 'checkout', '-q', '-b', 'feat/no-origin-v1')
    [System.IO.File]::WriteAllText((Join-Path $fix9a 'own-work.txt'), "real commit`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-GitQuiet -Arguments @('-C', $fix9a, 'add', '-A')
    Invoke-GitQuiet -Arguments @('-C', $fix9a, 'commit', '-q', '-m', 'own work')

    # 9a. No origin at all -> no refs/remotes/origin/main to prefer, so the bare local 'main' answers,
    # exactly as before #1399 -- and here it is the RIGHT answer, because nothing pulled main out of
    # sync with anything: one real commit on the branch, correctly counted.
    $backing9a = Get-GitParkBacking -RepoRoot $fix9a -Trunk 'main'
    Assert-Equal 1 $backing9a.Committed "no origin: falls back to the bare local trunk name and counts the branch's own commit"
    Assert-True $backing9a.CommittedKnown 'no origin: the figure is measured via the local ref'

    # 9b. Neither the remote-tracking ref nor a same-named local ref exists (an unrecognised trunk
    # name) -> CommittedKnown stays $false, same as before the fix. 'not measured' and '0' are
    # different claims -- Get-BranchBackingFinding above already covers why conflating them is wrong.
    $backing9b = Get-GitParkBacking -RepoRoot $fix9a -Trunk 'nonexistent-trunk'
    Assert-True (-not $backing9b.CommittedKnown) 'no ref anywhere: CommittedKnown stays false, same as before the fix'
    Assert-Equal 0 $backing9b.Committed 'no ref anywhere: the default zero, not a measured zero'
    Assert-Equal 'nonexistent-trunk' $backing9b.Trunk 'no ref anywhere: Trunk still echoes back whatever name was asked for'

    # -- 10. Resolve-TrunkRef ITSELF (#2322): the one definition both park-lib readers now call --------
    Write-Host "`n== 10. Resolve-TrunkRef: remote-tracking first, bare name second, `$null when neither ==" -ForegroundColor Cyan
    Assert-Equal 'refs/remotes/origin/main' (Resolve-TrunkRef -RepoRoot $fix8a -Trunk 'main') 'origin present: the remote-tracking ref wins, even with a local main of the same name'
    Assert-Equal 'main' (Resolve-TrunkRef -RepoRoot $fix9a -Trunk 'main') 'no origin: falls back to the bare local name'
    Assert-True ($null -eq (Resolve-TrunkRef -RepoRoot $fix9a -Trunk 'nonexistent-trunk')) 'no ref anywhere: $null, never a name that does not resolve'
} finally {
    foreach ($f in $script:gitFixtures) {
        if (Test-Path -LiteralPath $f) { Remove-Item -Recurse -Force -LiteralPath $f -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
# assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
$fixtureBroken = Write-FixtureGitSummary -Subject 'park-lib.ps1 (the backing gate)'
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
