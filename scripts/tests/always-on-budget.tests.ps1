<#
.SYNOPSIS
    Tests for scripts/lib/always-on-budget-lib.ps1 and scripts/lint/check-always-on-budget.ps1
    (issue #2037).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit 0 if everything passes, 1 on a failure --
    so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/always-on-budget.tests.ps1

    WHAT THIS SUITE IS FOR, and it is not "does the gate refuse". The subject is a RATCHET, and a
    ratchet fails in two opposite directions, only one of which anybody notices:

      1. TOO TIGHT -- it refuses a branch that changed nothing. Nobody debugs that twice; they pass
         -Force once and the gate is decoration from then on. Every assert about the CARRIED term is
         here for this: a CI runner has no marketplace clone, so the orchestrator persona (30,267 B,
         27.7% of this repo's path) does not resolve there, and a naive total would read as a 30k
         shrink locally and a 30k growth in CI, on a commit that touched neither.
      2. TOO LOOSE -- it lets the path grow while reporting green. That is the state #2037 was filed
         about, so an unmeasured document must never be counted as zero, and the limit must be
         max(budget, baseline) rather than min(): min() freezes every repo at its own low-water mark and
         refuses a branch for adding 200 B to a 60,000 B path, which is a rule nobody agreed to arriving
         as a side effect of one they did.

    ONE ASSERT EXISTS BECAUSE THE FIRST DRAFT DIED ON IT, which is the honest reason to pin it: on
    Windows PowerShell 5.1 the array-subexpression operator '@()' raises ArgumentException on a
    List[object] -- empty or not -- while the same operator on a List[string] is fine. Every other
    caller in this tree gets away with '@()' because a List RETURNED from a function is unrolled to
    object[] first; a List still held in a variable is not. The measurement therefore uses .ToArray(),
    and the assert below is what would catch a "tidy-up" putting '@()' back.

    THIS FILE IS PURE ASCII, like the sources it tests.
#>
$ErrorActionPreference = 'Stop'

# THE REPO ROOT, judged and ANCHORED (#1917), exactly as measure-always-on.tests.ps1 anchors it: this
# suite writes fixture trees and must not resolve its subject through the inherited working directory.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$RepoRoot = Resolve-RepoRootOrFail -From $PSScriptRoot -ScriptName 'always-on-budget.tests.ps1'
$Lib = Join-Path $RepoRoot 'scripts\lib\always-on-budget-lib.ps1'
$Script = Join-Path $RepoRoot 'scripts\lint\check-always-on-budget.ps1'

. $Lib

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    # SCALARS ONLY -- '-eq' against an array FILTERS it rather than comparing it. Same note, same
    # reason, as measure-always-on.tests.ps1's copy.
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

# $PID plus a guid in the fixture path, per the suite convention in scripts/README.md: the test gate is
# a throttled PARALLEL scheduler, so two runs at one fixed path tear down each other's tree mid-assert.
$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("always-on-budget-$PID-$([guid]::NewGuid().ToString('n'))")
if (Test-Path $Fixture) { Remove-Item -Recurse -Force $Fixture }
New-Item -ItemType Directory -Path $Fixture -Force | Out-Null
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function New-Fixture {
    <# Writes a fixture document of an EXACT byte size, LF-terminated, so every assert below is about
       arithmetic rather than about how long a sentence happens to be. #>
    param([string]$RelPath, [int]$Bytes, [string[]]$Leading = @())
    $full = Join-Path $Fixture $RelPath
    $dir = Split-Path -Parent $full
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $head = ''
    if ($Leading.Count -gt 0) { $head = (($Leading -join "`n") + "`n") }
    $padLen = $Bytes - $head.Length
    if ($padLen -lt 1) { throw "fixture $RelPath : the leading lines already exceed $Bytes bytes" }
    $body = ('x' * ($padLen - 1)) + "`n"
    [System.IO.File]::WriteAllText($full, ($head + $body), $Utf8NoBom)
    return $full
}

function New-Baseline {
    <# A baseline object of the shape Read-AlwaysOnBaseline returns, without going through the file --
       so the verdict asserts test the verdict rather than the JSON round trip, which has its own block. #>
    param([int64]$Bytes, [hashtable]$Documents = @{})
    return [pscustomobject]@{ Path = ''; Unreadable = ''; Bytes = $Bytes; Recorded = ''; Reason = ''; Documents = $Documents }
}

try {
    Write-Host ''
    Write-Host 'The limit -- max(budget, baseline), which is the whole ratchet' -ForegroundColor Cyan

    Assert-Equal 100000 (Get-AlwaysOnLimit -Budget 100000 -Baseline $null) 'with no baseline the limit is the budget'
    Assert-Equal 100000 (Get-AlwaysOnLimit -Budget 100000 -Baseline (New-Baseline -Bytes 60000)) 'under the budget the limit is the BUDGET -- the headroom stays usable'
    Assert-Equal 150000 (Get-AlwaysOnLimit -Budget 100000 -Baseline (New-Baseline -Bytes 150000)) 'over the budget the limit is the BASELINE -- the path may not grow'
    # THE min() TRAP, pinned by name. min() would answer 60000 on the second case above and refuse a
    # branch for spending room the repo is entitled to.
    Assert-True ((Get-AlwaysOnLimit -Budget 100000 -Baseline (New-Baseline -Bytes 60000)) -ne 60000) 'the limit is never min(budget, baseline)'

    Write-Host ''
    Write-Host 'The verdict -- six states, and which of them refuse' -ForegroundColor Cyan

    function Get-Verdict {
        param([int64]$Total, [int64]$Budget = 100000, $Baseline = $null)
        $m = [pscustomobject]@{ Total = $Total; Unmeasured = @(); Carried = @(); Dead = @(); Sizes = @{} }
        return (Get-AlwaysOnBudgetVerdict -Measurement $m -Budget $Budget -Baseline $Baseline)
    }

    $v = Get-Verdict -Total 150000
    Assert-Equal 'first-run' $v.State 'no baseline is a first run'
    Assert-True $v.Ok 'a first run never refuses, however far over it is -- that is the day-one cliff the ratchet exists to avoid'
    Assert-True $v.ShouldRecord 'a first run records where the repo is'

    $v = Get-Verdict -Total 60000 -Baseline (New-Baseline -Bytes 60000)
    Assert-Equal 'inside' $v.State 'under the budget and not crossing it'
    Assert-True $v.Ok 'inside the budget passes'

    $v = Get-Verdict -Total 80000 -Baseline (New-Baseline -Bytes 60000)
    Assert-Equal 'inside' $v.State 'growth UNDER the ceiling is allowed'
    Assert-True (-not $v.ShouldRecord) 'and it does NOT raise the low-water mark -- the baseline only ever falls on its own'

    $v = Get-Verdict -Total 100001 -Baseline (New-Baseline -Bytes 60000)
    Assert-Equal 'crossing' $v.State 'one byte past the ceiling from under it is a crossing'
    Assert-True (-not $v.Ok) 'a crossing refuses'

    $v = Get-Verdict -Total 150000 -Baseline (New-Baseline -Bytes 150000)
    Assert-Equal 'over-holding' $v.State 'over the budget and unchanged is holding'
    Assert-True $v.Ok 'holding passes -- an over-budget repo is not refused for standing still'

    $v = Get-Verdict -Total 140000 -Baseline (New-Baseline -Bytes 150000)
    Assert-Equal 'over-shrink' $v.State 'over the budget and smaller is a shrink'
    Assert-True $v.Ok 'a shrink passes'
    Assert-True $v.ShouldRecord 'a shrink lowers the low-water mark'
    Assert-Equal -10000 $v.Delta 'the delta is signed against the baseline'

    $v = Get-Verdict -Total 150001 -Baseline (New-Baseline -Bytes 150000)
    Assert-Equal 'over-growing' $v.State 'one byte of growth on an over-budget path is refused'
    Assert-True (-not $v.Ok) 'growth on an over-budget path refuses'
    Assert-True (-not $v.ShouldRecord) 'a refused run records nothing'

    Write-Host ''
    Write-Host 'The budget seam -- absent, stated, and malformed' -ForegroundColor Cyan

    Assert-Equal 100000 (Get-AlwaysOnBudgetDefault) 'the built-in ceiling is 100,000 bytes'
    Assert-Equal 100000 (Resolve-AlwaysOnBudget) 'with no seam defined the default answers'
    function Get-AlwaysOnBudget { return 42000 }
    Assert-Equal 42000 (Resolve-AlwaysOnBudget) 'a stated seam wins'
    function Get-AlwaysOnBudget { return 0 }
    Assert-Equal 100000 (Resolve-AlwaysOnBudget) 'a zero falls back -- opting out is not something this seam offers'
    function Get-AlwaysOnBudget { return 'plenty' }
    Assert-Equal 100000 (Resolve-AlwaysOnBudget) 'a non-numeric answer falls back rather than refusing every PR'
    Remove-Item Function:\Get-AlwaysOnBudget

    Write-Host ''
    Write-Host 'The measurement -- the walk, the carried term, and the unmeasured one' -ForegroundColor Cyan

    # A three-document path: the root, a tree import, and an absolute '~' import standing in for the
    # orchestrator persona that lives in the marketplace clone.
    $persona = '~/plugins/persona.md'
    New-Fixture -RelPath 'CLAUDE.md'  -Bytes 4000 -Leading @('# Root', '@lens.md', "@$persona") | Out-Null
    New-Fixture -RelPath 'lens.md'    -Bytes 2000 -Leading @('# Lens') | Out-Null
    $homeDir = Join-Path $Fixture '_home'
    New-Item -ItemType Directory -Path (Join-Path $homeDir 'plugins') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $homeDir 'plugins\persona.md'), ('y' * 999 + "`n"), $Utf8NoBom)

    $env:MEASURE_CONTEXT_HOME = $homeDir
    try {
        $m = Get-AlwaysOnMeasurement -RepoRoot $Fixture
        Assert-Equal 7000 $m.Total 'the total is every document on the path, not just the root file'
        Assert-Equal 3 @($m.Measured).Count 'all three documents were measured'
        Assert-Equal 0 @($m.Unmeasured).Count 'nothing is unmeasured when every import resolves'
        # THE @() / List[object] REGRESSION GUARD. If .ToArray() is ever "tidied" back to @(), the call
        # above throws ArgumentException on Windows PowerShell 5.1 and this suite fails at the line
        # above rather than here -- which is the point: the assert is the call itself.
        Assert-True ($m.Measured -is [array]) 'the row sets come back as arrays, built with .ToArray() rather than @()'
        Assert-True ($m.Sizes.ContainsKey($persona)) 'an external document is keyed by its IMPORT TARGET, not by its machine-specific resolved path'

        $baselinePath = Write-AlwaysOnBaseline -RepoRoot $Fixture -Measurement $m -Reason ''
        Assert-True (Test-Path -LiteralPath $baselinePath) 'the baseline is written'
        $raw = [System.IO.File]::ReadAllText($baselinePath, $Utf8NoBom)
        Assert-True ($raw -notmatch "`r") 'the baseline is written LF, so it does not diff whole-file per machine'
        $b = Read-AlwaysOnBaseline -RepoRoot $Fixture
        Assert-Equal 7000 $b.Bytes 'the baseline round-trips its total'
        Assert-Equal 1000 $b.Documents[$persona] 'and the per-document sizes a carrier with no clone needs'
    } finally {
        Remove-Item Env:\MEASURE_CONTEXT_HOME -ErrorAction SilentlyContinue
    }

    # NOW SIMULATE THE CI RUNNER: no marketplace clone, so the '~' import does not resolve. This is the
    # premise #2037 never weighed, and the assert that the two carriers judge the same subject.
    $env:MEASURE_CONTEXT_HOME = (Join-Path $Fixture '_no_such_home')
    try {
        $bRecorded = Read-AlwaysOnBaseline -RepoRoot $Fixture
        $mCi = Get-AlwaysOnMeasurement -RepoRoot $Fixture -Baseline $bRecorded
        Assert-Equal 7000 $mCi.Total 'with the persona unresolvable, the recorded figure is CARRIED and the total is unchanged'
        Assert-Equal 1 @($mCi.Carried).Count 'the carried document is named rather than silently folded in'
        Assert-Equal 6000 $mCi.MeasuredBytes 'the measured half is reported separately from the carried half'
        $vCi = Get-AlwaysOnBudgetVerdict -Measurement $mCi -Budget 100000 -Baseline $bRecorded
        Assert-Equal 'inside' $vCi.State 'so a CI run on an unchanged commit reads as no change at all'

        # AND WITH NO RECORD EITHER: unmeasured, never zero.
        $mBlind = Get-AlwaysOnMeasurement -RepoRoot $Fixture
        Assert-Equal 6000 $mBlind.Total 'an unresolvable document with no recorded figure contributes nothing'
        Assert-Equal 1 @($mBlind.Unmeasured).Count 'and is REPORTED, so the total is known to be a floor'
    } finally {
        Remove-Item Env:\MEASURE_CONTEXT_HOME -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host 'A DEAD import against an UNSEEN one -- one unresolved line, two different facts' -ForegroundColor Cyan

    # THE SHAPE #2138 WAS MEASURED ON: a registered consumer importing the ORCHESTRATOR's body from a
    # marketplace path retired eight days earlier. Every assert in this block is about the diagnosis
    # rather than the arithmetic -- the old report called it "not measured and not recorded" and told
    # the reader to re-run on a machine where the import resolves, which is where they already were.
    $RepoDead = Join-Path $Fixture 'repo-dead'
    New-Item -ItemType Directory -Path $RepoDead -Force | Out-Null
    $homeLive = Join-Path $Fixture '_home_live'
    $mktRoot  = Join-Path $homeLive '.claude\plugins\marketplaces'
    New-Item -ItemType Directory -Path (Join-Path $mktRoot 'present-market') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $mktRoot 'present-market\persona.md'), (('y' * 999) + "`n"), $Utf8NoBom)
    # A sibling whose name STARTS with the root's, which is what the separator in the prefix test is for.
    New-Item -ItemType Directory -Path (Join-Path $homeLive '.claude\plugins\marketplaces-extra') -Force | Out-Null

    $liveTarget = '~/.claude/plugins/marketplaces/present-market/persona.md'
    $deadTarget = '~/.claude/plugins/marketplaces/retired-market/persona.md'

    $env:MEASURE_CONTEXT_HOME = $homeLive
    try {
        # THE TWO PROOFS, and the two non-proofs beside them.
        Assert-Equal 'dead' (Get-ImportAbsenceKind -Path (Join-Path $RepoDead 'gone.md') -RepoRoot $RepoDead) `
            'a missing IN-TREE import is dead: the repo is present by definition -- this run is reading it'
        Assert-Equal 'dead' (Get-ImportAbsenceKind -Path (Join-Path $mktRoot 'retired-market\persona.md') -RepoRoot $RepoDead) `
            'a missing import under an EXISTING marketplace root is dead, not unmeasurable'
        Assert-Equal 'unprovable' (Get-ImportAbsenceKind -Path (Join-Path $Fixture 'elsewhere\x.md') -RepoRoot $RepoDead) `
            'a missing import that is neither in the repo nor under the marketplace root proves nothing'
        Assert-Equal 'unprovable' (Get-ImportAbsenceKind -Path (Join-Path $homeLive '.claude\plugins\marketplaces-extra\x.md') -RepoRoot $RepoDead) `
            'a SIBLING directory whose name merely starts with the MARKETPLACE root is not inside it'
        # THE SAME ASSERT ON THE OTHER BRANCH, and its absence is why the first draft shipped with the
        # guard on one test and not the other: 'repo-deadXYZ' is not in 'repo-dead', and the bare prefix
        # comparison said it was. Both branches go through Test-PathIsUnder now, and both are pinned --
        # a containment test written twice is one that can be right once (code review of #2138).
        Assert-Equal 'unprovable' (Get-ImportAbsenceKind -Path ($RepoDead + 'XYZ\gone.md') -RepoRoot $RepoDead) `
            'a SIBLING directory whose name merely starts with the REPO root is not inside it either'
        Assert-True (Test-PathIsUnder -Path (Join-Path $RepoDead 'a\b.md') -Parent $RepoDead) `
            'Test-PathIsUnder: a nested path is inside'
        Assert-True (Test-PathIsUnder -Path $RepoDead -Parent $RepoDead) `
            'Test-PathIsUnder: the parent itself counts as inside -- a target resolving to the directory is still this tree''s'
        Assert-True (-not (Test-PathIsUnder -Path ($RepoDead + 'XYZ') -Parent $RepoDead)) `
            'Test-PathIsUnder: a name-prefix sibling is not'

        [System.IO.File]::WriteAllText((Join-Path $RepoDead 'CLAUDE.md'),
            ("# Root`n@$liveTarget`n@$deadTarget`n" + ('x' * 2000) + "`n"), $Utf8NoBom)

        $mDead = Get-AlwaysOnMeasurement -RepoRoot $RepoDead
        Assert-Equal 1 @($mDead.Dead).Count 'the retired marketplace is reported DEAD'
        Assert-Equal $deadTarget @($mDead.Dead)[0].Target 'and it is the retired target that is named, not the one that resolves'
        Assert-Equal 0 @($mDead.Carried).Count 'with no baseline there is nothing to carry'
        Assert-Equal 1 @($mDead.Unmeasured).Count 'it is unmeasured TOO -- the sets cut across each other rather than replacing one another'

        # THE REGRESSION THIS BLOCK EXISTS FOR. A figure in the baseline says what a document USED to
        # cost; it is no evidence that anything still loads it. Asked after the carried branch instead
        # of before it, this lib's own memory would hide the one failure it is here to surface -- and
        # the total would go on reporting bytes for a document no session has.
        $bDead = New-Baseline -Bytes 9999 -Documents @{ $deadTarget = 1000 }
        $mDeadc = Get-AlwaysOnMeasurement -RepoRoot $RepoDead -Baseline $bDead
        Assert-Equal 1 @($mDeadc.Dead).Count 'a dead import with a RECORDED figure is still reported dead'
        Assert-Equal 1 @($mDeadc.Carried).Count 'and its recorded bytes are still carried'
        Assert-Equal ($mDead.Total + 1000) $mDeadc.Total 'the total is unchanged by the diagnosis -- dropping a carried term is what makes the next branch read as growth'
        $vDead = Get-AlwaysOnBudgetVerdict -Measurement $mDeadc -Budget 100000 -Baseline $bDead
        Assert-Equal 1 @($vDead.Dead).Count 'the verdict passes the dead set through to the reporting layer'

        # AND THE CI SHAPE, which is the reason the exclusion existed at all (issue #874): a runner has
        # no marketplace clone, so nothing about that import can be concluded there and erroring would
        # fail every PR for a correct file.
        $outDead = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $RepoDead 2>&1
        $textDead = ($outDead | Out-String)
        Assert-Equal 0 $LASTEXITCODE 'a dead import WARNS and does not refuse -- the exit code belongs to the budget'
        Assert-True ($textDead -match "DEAD '@'-import") 'the check names it as dead'
        Assert-True ($textDead -match 'Repair the import line') 'and gives the remedy that can actually help'
        Assert-True ($textDead -notmatch 'not measured and not recorded') 'and does NOT also print the re-run-elsewhere instruction for the same line'
        # always-on-sessioncheck.ps1 forwards the [WARN]-MARKED lines to every session start and drops
        # the indented continuations, so a remedy on a continuation line never leaves this gate.
        Assert-True (@($outDead | Where-Object { "$_" -cmatch '\[WARN\]' -and "$_" -match 'Repair the import line' }).Count -gt 0) `
            'the remedy sits on a [WARN] line, which is the only part the session-start hook forwards'
    } finally {
        Remove-Item Env:\MEASURE_CONTEXT_HOME -ErrorAction SilentlyContinue
    }

    $env:MEASURE_CONTEXT_HOME = (Join-Path $Fixture '_home_absent')
    try {
        Assert-Equal 'unprovable' (Get-ImportAbsenceKind -Path (Join-Path $mktRoot 'retired-market\persona.md') -RepoRoot $RepoDead) `
            'with no marketplace root on the machine at all, the same target is UNPROVABLE -- a CI runner concludes nothing'
        $mCiDead = Get-AlwaysOnMeasurement -RepoRoot $RepoDead
        Assert-Equal 0 @($mCiDead.Dead).Count 'so CI reports no dead import'
        Assert-Equal 2 @($mCiDead.Unmeasured).Count 'and both external documents fall back to unmeasured, exactly as before'
    } finally {
        Remove-Item Env:\MEASURE_CONTEXT_HOME -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host 'The check script -- exit codes and the refusals' -ForegroundColor Cyan

    # A second fixture tree, all in-tree, so the script can be driven without a home override.
    $Repo2 = Join-Path $Fixture 'repo2'
    New-Item -ItemType Directory -Path $Repo2 -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $Repo2 'CLAUDE.md'), ('# Root' + "`n" + ('x' * 4992) + "`n"), $Utf8NoBom)

    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $Repo2 2>&1
    $text = ($out | Out-String)
    Assert-Equal 0 $LASTEXITCODE 'a first run exits 0'
    Assert-True ($text -match 'no baseline yet') 'and says so'
    Assert-True ($text -match 'Nothing was written') 'and writes nothing without -Record'

    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $Repo2 -Record 2>&1
    Assert-Equal 0 $LASTEXITCODE '-Record exits 0'
    Assert-True (Test-Path -LiteralPath (Get-AlwaysOnBaselinePath -RepoRoot $Repo2)) '-Record writes the baseline into the workflow folder'

    # Growth under the ceiling: allowed, because 5,000 B is nowhere near 100,000.
    Add-Content -LiteralPath (Join-Path $Repo2 'CLAUDE.md') -Value ('z' * 100)
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $Repo2 2>&1
    Assert-Equal 0 $LASTEXITCODE 'growth under the ceiling is not refused'

    # Now put the repo over its own ceiling by stating a tiny budget through the seam, which is also the
    # only way to exercise the crossing arm without writing a 100 KB fixture.
    $cfgDir = Join-Path $Repo2 'scripts'
    New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $cfgDir 'repo-config.ps1'), "function Get-AlwaysOnBudget { return 4000 }`n", $Utf8NoBom)
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $Repo2 2>&1
    $text = ($out | Out-String)
    Assert-Equal 1 $LASTEXITCODE 'a path over a stated budget, having grown past the baseline, is refused'
    Assert-True ($text -match 'GROWS an already-over-budget') 'and is named as growth rather than as a crossing'
    Assert-True ($text -match 'Four places this weight goes') 'the refusal names the destination -- a ceiling with no destination is a red check nobody can clear'

    # -Raise: refused without a reason, honoured with one.
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $Repo2 -Raise 2>&1
    Assert-Equal 1 $LASTEXITCODE '-Raise without -Reason is refused'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $Repo2 -Raise -Reason 'the routing table is on the path by design' 2>&1
    Assert-Equal 0 $LASTEXITCODE '-Raise with a reason is honoured'
    $bRaised = Read-AlwaysOnBaseline -RepoRoot $Repo2
    Assert-True ($bRaised.Reason -match 'by design') 'and the reason is written into the file, where a reviewer can argue with it'

    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $Repo2 2>&1
    Assert-Equal 0 $LASTEXITCODE 'after the raise the same tree passes'

    # A repo with no root document is skipped, not refused: a consumer without a CLAUDE.md has no
    # always-on path to bound, and every consumer that has one arrived at it through specialists-init.
    $Repo3 = Join-Path $Fixture 'repo3'
    New-Item -ItemType Directory -Path $Repo3 -Force | Out-Null
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $Repo3 2>&1
    Assert-Equal 0 $LASTEXITCODE 'a repo with no CLAUDE.md is skipped'
    Assert-True ((($out | Out-String)) -match '\[SKIP\]') 'and says SKIP rather than reporting a zero-byte path'
} finally {
    Remove-Item -Recurse -Force $Fixture -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host ("  {0} passed, {1} failed" -f $script:pass, $script:fail) -ForegroundColor $(if ($script:fail -gt 0) { 'Red' } else { 'Green' })
if ($script:fail -gt 0) { exit 1 }
exit 0
