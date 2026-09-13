<#
.SYNOPSIS
    Tests for the machine-local path gate -- Get-BranchMachineLocalFindings in scripts/lib/park-lib.ps1,
    the Get-MachineLocalPaths seam in scripts/repo-config.ps1, and the advisory note open-pr.ps1 builds
    on them (issue #1559).

.DESCRIPTION
    WHAT THIS EXISTS FOR. A tracked file a person edited for their own clone -- .claude/settings.json
    with four extra plugins enabled locally plus "autoUpdate": false -- rode into a branch commit on a
    `git add -A` and reached the merge queue on PR #1557, past every gate. The development-document
    gates (scaffold, step-list, impact, link) never read the diff's file set; the backing gate reads
    the diff but asks the opposite question -- work MISSING from the commit, not surplus in it.

    THE PROPERTY UNDER TEST IS THE MERGE-BASE SCOPE and the advisory shape, not a refusal. The gate
    WARNS and never blocks: the issue asked for exactly that, so a branch that legitimately changes the
    shared settings file needs no escape valve. Sections 4-5 use REAL git repos, because the risk of a
    wrong answer lives in the git plumbing (which ref `$Trunk...HEAD` is measured against) -- the same
    #1399 lesson the backing gate carries.

    Dependency-free (no Pester), same style as backing-gate.tests.ps1.
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

# --- 1. spec parsing, no git needed -----------------------------------------------------------------
Write-Host "`n== 1. an empty or absent list means 'nothing to check' ==" -ForegroundColor Cyan
$e1 = Get-BranchMachineLocalFindings -RepoRoot $RepoRoot -Trunk 'main' -MachineLocalPaths @()
Assert-True $e1.Known 'empty list: Known is true -- there is nothing to check, which is an answer'
Assert-Equal 0 @($e1.Paths).Count 'empty list: no paths'
$e2 = Get-BranchMachineLocalFindings -RepoRoot $RepoRoot -Trunk 'main' -MachineLocalPaths @('', '   ', $null)
Assert-True $e2.Known 'a list of only blanks collapses to nothing to check'
Assert-Equal 0 @($e2.Paths).Count 'blanks contribute no specs'

# --- 2. an unreadable diff is Known = false, never an empty all-clear -----------------------------
Write-Host "`n== 2. a trunk ref that does not resolve degrades to cannot-answer ==" -ForegroundColor Cyan
$u = Get-BranchMachineLocalFindings -RepoRoot $RepoRoot -Trunk 'no-such-trunk-anywhere' -MachineLocalPaths @('.claude/settings.json')
Assert-True (-not $u.Known) 'unknown trunk: Known is false'
Assert-Equal 0 @($u.Paths).Count 'unknown trunk: no paths, and the caller must not read this as all-clear'

# --- 3. the lib is a named function and travels to the consumer ----------------------------------
Write-Host "`n== 3. one function, mirrored into the plugin ==" -ForegroundColor Cyan
$libText = [System.IO.File]::ReadAllText($LibPath)
Assert-True ($libText -match 'function Get-BranchMachineLocalFindings') 'the check is a named function'
Assert-True ($libText -match "core\.quotePath=true") 'it forces core.quotePath for the compare (language rule)'
Assert-True ($libText -match "refs/remotes/origin/\`$Trunk") 'it prefers the remote-tracking ref (#1399)'
Assert-True ($libText -match '\$trunkRef\.\.\.HEAD') 'three-dot: the branch against its merge base with the trunk'
. (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1')
$pairs = @(Get-SharedScriptPairs -RepoRoot $RepoRoot)
foreach ($name in @('park-lib', 'open-pr')) {
    $pair = @($pairs | Where-Object { $_.Name -eq $name })
    Assert-Equal 1 $pair.Count "$name is registered exactly once"
    if ($pair.Count -eq 1) {
        Assert-True (Test-Path -LiteralPath $pair[0].MirrorPath) "$name's mirror exists in the plugin tree"
        $mir = [System.IO.File]::ReadAllText($pair[0].MirrorPath)
        Assert-True ($mir -match 'Get-BranchMachineLocalFindings') "$name's mirror carries the new check"
    }
}

# --- 4 & 5. REAL GIT REPOS: the merge-base scope is where a wrong answer would live ---------------
$script:gitFixtures = @()

function New-GitFixture {
    <# A throwaway repo with a bare 'origin' -- same conventions as backing-gate.tests.ps1. #>
    param([Parameter(Mandatory = $true)][string]$Label, [switch]$NoOrigin)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("machine-local-test-$PID-$Label-$([guid]::NewGuid().ToString('n'))")
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
        New-Item -ItemType Directory -Path (Join-Path $dir '.claude') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir 'README.md'), "# fixture`n", (New-Object System.Text.UTF8Encoding $false))
        [System.IO.File]::WriteAllText((Join-Path $dir '.claude/settings.json'), "{`n}`n", (New-Object System.Text.UTF8Encoding $false))
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
    # -- 4. the file the incident was about, swept into a branch commit ----------------------------
    Write-Host "`n== 4. a branch commit that touches .claude/settings.json is named ==" -ForegroundColor Cyan
    $fx4 = New-GitFixture -Label '4'
    Invoke-GitQuiet -Arguments @('-C', $fx4, 'checkout', '-q', '-b', 'fix/some-unrelated-thing')
    # the deliberate work
    [System.IO.File]::WriteAllText((Join-Path $fx4 'src.txt'), "real change`n", (New-Object System.Text.UTF8Encoding $false))
    # the swept machine-local edit
    [System.IO.File]::WriteAllText((Join-Path $fx4 '.claude/settings.json'), "{`n  `"enabledPlugins`": {}`n}`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-GitQuiet -Arguments @('-C', $fx4, 'add', '-A')
    Invoke-GitQuiet -Arguments @('-C', $fx4, 'commit', '-q', '-m', 'unrelated thing (git add -A swept settings.json)')

    $f4 = Get-BranchMachineLocalFindings -RepoRoot $fx4 -Trunk 'main' -MachineLocalPaths @('.claude/settings.json')
    Assert-True $f4.Known 'swept file: the diff was read'
    Assert-Equal '.claude/settings.json' ($f4.Paths -join ',') 'swept file: it is named, and src.txt is not'

    # a path NOT on the list is not flagged
    $f4b = Get-BranchMachineLocalFindings -RepoRoot $fx4 -Trunk 'main' -MachineLocalPaths @('.claude/other.json')
    Assert-Equal 0 @($f4b.Paths).Count 'a path not on the list is not flagged'

    # a directory spec ('.claude/') catches it too
    $f4c = Get-BranchMachineLocalFindings -RepoRoot $fx4 -Trunk 'main' -MachineLocalPaths @('.claude/')
    Assert-Equal '.claude/settings.json' ($f4c.Paths -join ',') "a trailing-slash entry matches the whole directory"

    # -- 5. a trunk-side change to the same file is NOT the branch's (three-dot merge base) --------
    Write-Host "`n== 5. a change to the watched file on the TRUNK side is not attributed to the branch ==" -ForegroundColor Cyan
    $fx5 = New-GitFixture -Label '5'
    # branch cut from the current tip
    $branchBase = Get-GitOutput -Arguments @('-C', $fx5, 'rev-parse', 'HEAD')
    Invoke-GitQuiet -Arguments @('-C', $fx5, 'checkout', '-q', '-b', 'feat/clean-branch')
    [System.IO.File]::WriteAllText((Join-Path $fx5 'feature.txt'), "branch work only`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-GitQuiet -Arguments @('-C', $fx5, 'add', '-A')
    Invoke-GitQuiet -Arguments @('-C', $fx5, 'commit', '-q', '-m', 'branch work, no settings.json')
    # trunk moves on AFTER the branch was cut, and its move touches the watched file
    Invoke-GitQuiet -Arguments @('-C', $fx5, 'checkout', '-q', 'main')
    [System.IO.File]::WriteAllText((Join-Path $fx5 '.claude/settings.json'), "{`n  `"changed`": `"on trunk`"`n}`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-GitQuiet -Arguments @('-C', $fx5, 'add', '-A')
    Invoke-GitQuiet -Arguments @('-C', $fx5, 'commit', '-q', '-m', 'trunk-side settings.json change')
    Invoke-GitQuiet -Arguments @('-C', $fx5, 'push', '-q', 'origin', 'main')
    Invoke-GitQuiet -Arguments @('-C', $fx5, 'checkout', '-q', 'feat/clean-branch')

    $f5 = Get-BranchMachineLocalFindings -RepoRoot $fx5 -Trunk 'main' -MachineLocalPaths @('.claude/settings.json')
    Assert-True $f5.Known 'trunk-side change: the diff was read'
    Assert-Equal 0 @($f5.Paths).Count 'trunk-side change: the branch touched nothing on the list -- merge-base scope, not tip diff'

    # -- 5b. #1399: a stale local trunk caught up via merge does not fake a hit -------------------
    Write-Host "`n== 5b. the remote-tracking ref is preferred, so an upstream settings.json change is not the branch's ==" -ForegroundColor Cyan
    $fx6 = New-GitFixture -Label '6'
    Invoke-GitQuiet -Arguments @('-C', $fx6, 'checkout', '-q', '-b', 'feat/caught-up')
    $shaOld = Get-GitOutput -Arguments @('-C', $fx6, 'rev-parse', 'main')
    Invoke-GitQuiet -Arguments @('-C', $fx6, 'checkout', '-q', 'main')
    [System.IO.File]::WriteAllText((Join-Path $fx6 '.claude/settings.json'), "{`n  `"upstream`": true`n}`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-GitQuiet -Arguments @('-C', $fx6, 'add', '-A')
    Invoke-GitQuiet -Arguments @('-C', $fx6, 'commit', '-q', '-m', 'upstream settings.json change')
    Invoke-GitQuiet -Arguments @('-C', $fx6, 'push', '-q', 'origin', 'main')
    Invoke-GitQuiet -Arguments @('-C', $fx6, 'checkout', '-q', 'feat/caught-up')
    # local main dragged back one commit; branch catches up the documented way
    Invoke-GitQuiet -Arguments @('-C', $fx6, 'update-ref', 'refs/heads/main', $shaOld)
    Invoke-GitQuiet -Arguments @('-C', $fx6, 'merge', '-q', 'origin/main')

    $f6 = Get-BranchMachineLocalFindings -RepoRoot $fx6 -Trunk 'main' -MachineLocalPaths @('.claude/settings.json')
    Assert-True $f6.Known 'stale local trunk: the diff was read'
    Assert-Equal 0 @($f6.Paths).Count "stale local trunk: the upstream file change is not counted as the branch's work"
} finally {
    foreach ($f in $script:gitFixtures) {
        if (Test-Path -LiteralPath $f) { Remove-Item -Recurse -Force -LiteralPath $f -ErrorAction SilentlyContinue }
    }
}

# --- 6. the seam is defined in this repo ---------------------------------------------------------
Write-Host "`n== 6. Get-MachineLocalPaths is defined and names the settings file ==" -ForegroundColor Cyan
$cfgText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\repo-config.ps1'))
Assert-True ($cfgText -match 'function Get-MachineLocalPaths') 'repo-config.ps1 defines the seam'
. (Join-Path $RepoRoot 'scripts\repo-config.ps1')
$seam = @(Get-MachineLocalPaths)
Assert-True ($seam -contains '.claude/settings.json') "this repo watches .claude/settings.json"
# WATCHED IS NOT THE SAME AS MACHINE-LOCAL (#1574). The file is a shared, tracked declaration, and a
# branch whose subject IS that declaration is the happy path this gate fires on -- so the seam has to
# keep saying which of the two cases the settings.local.json move belongs to. It said the opposite
# until #1574: "machine-local plugin enablement belongs in .claude/settings.local.json", read as a
# blanket rule about the file, on a run whose branch was deliberately changing the enabled set.
Assert-True ($cfgText -match 'NOT MACHINE-LOCAL') 'the seam comment says the watched file is not itself machine-local'
Assert-True ($cfgText -match 'for that case and no other') 'and scopes the settings.local.json move to the clone-own case'

# --- 7. open-pr.ps1 wires it in, as an advisory note ----------------------------------------------
Write-Host "`n== 7. open-pr.ps1 reaches the gate and only warns ==" -ForegroundColor Cyan
$openPr = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\release\open-pr.ps1'))
# The probe's idiom changed with #1729 (inline Get-Command -> Test-FunctionDefined); the subject of
# this assert is that the optional seam is PROBED before it is called, not which call does the probing.
Assert-True ($openPr -match 'Test-FunctionDefined ''Get-MachineLocalPaths''') 'open-pr probes the optional seam'
Assert-True ($openPr -match 'Get-BranchMachineLocalFindings -RepoRoot \$repoRoot -Trunk \(Get-BranchTrunkName\)') 'it asks the shared check with the resolved trunk'
Assert-Equal 1 ([regex]::Matches($openPr, '\$mlFinding = Get-BranchMachineLocalFindings').Count) 'called exactly once'
Assert-True ($openPr -match 'machine-local path gate: this branch''s commits touch') 'it names the finding'
# advisory: Write-Warning, and no exit in the block
$mlBlock = [regex]::Match($openPr, "(?s)if \(Test-FunctionDefined 'Get-MachineLocalPaths'.*?\n\}\n\n# Scaffold gate").Value
Assert-True ([bool]$mlBlock) 'the gate block is findable'
Assert-True ($mlBlock -match 'Write-Warning \$machineLocalNote') 'the block warns'
Assert-Equal 0 ([regex]::Matches($mlBlock, 'exit 1').Count) 'the block never refuses -- no exit'
# TWO CASES, NOT ONE REMEDY (#1574). The note fires on the intended happy path -- a branch whose
# subject is a deliberate change to the shared file -- so it must say so there rather than telling
# the author to move the change somewhere gitignored. A warning that prescribes the wrong remedy on
# the path it fires on is one that gets scrolled past, and then it is scrolled past on the day it is
# right. This text ships to every consumer through the plugin mirror, so it is asserted here.
Assert-True ($mlBlock -match 'Two cases') 'the note states both cases rather than one remedy'
Assert-True ($mlBlock -match "only THIS clone's own") 'the move is prescribed only for the clone-own edit'
Assert-Equal 0 ([regex]::Matches($mlBlock, 'machine-local plugin enablement belongs in').Count) 'the retired blanket remedy is gone'
# said twice (issue #1559) at each of open-pr's run ends -- and since inbound #1916 there are THREE
# of those, not two: a `gh pr create` that reports a 5xx/transport failure and then re-checks itself
# into finding the PR already there is exactly as real an ending as the other two, and just as far
# off-screen from the gate by the time it closes out.
Assert-Equal 4 ([regex]::Matches($openPr, 'Write-Warning \$machineLocalNote').Count) 'the note is emitted once at the gate and once from each of the three run ends'
# placement: before the scaffold gate and before the push
Assert-True ($openPr.IndexOf('machine-local path gate:') -lt $openPr.IndexOf('scaffold gate:')) 'the machine-local gate runs before the scaffold gate'
Assert-True ($openPr.IndexOf('machine-local path gate:') -lt $openPr.IndexOf("'push', '-u', 'origin'")) 'and before the push'

Write-Host ''
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
# assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
$fixtureBroken = Write-FixtureGitSummary -Subject 'park-lib.ps1 (the machine-local gate)'
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
