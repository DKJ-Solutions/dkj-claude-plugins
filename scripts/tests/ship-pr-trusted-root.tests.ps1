<#
.SYNOPSIS
    Behavioural (not merely textual) tests for ship-pr.ps1's -TrustedRoot / open-pr.ps1's -SeamRoot
    (issue #2437) -- the coverage trusted-tree-seam.tests.ps1 deliberately does not carry, since that
    suite is a STATIC/textual guard (see its own header) and this one runs real code.

.DESCRIPTION
    THREE THINGS ARE PROVEN HERE, EACH THE SMALLEST UNIT THAT GENUINELY CARRIES THE BEHAVIOUR:

    1. SEAM LOADING PREFERS -TrustedRoot/-SeamRoot OVER $repoRoot, even when $repoRoot carries its OWN
       valid copy of the seam file. Proven by running the REAL ship-pr.ps1 and open-pr.ps1 (in place,
       never copied) against two throwaway fixture roots, each carrying a scripts\repo-config.ps1 whose
       Get-RepoName THROWS a distinctive marker naming which root it came from. $repo = Get-RepoName is
       the very next statement after the seam dot-source in both scripts, so the run dies there -- before
       any gh call, any git mutation, any gate -- and the marker in the refusal says which copy was read.
       A FULL END-TO-END RUN OF EITHER SCRIPT NEEDS gh AND A REAL PULL REQUEST, which this suite does not
       have; this is the smallest real execution that still exercises the actual seam-selection line
       ($seamRoot = if ($TrustedRoot/$SeamRoot) { ... } else { $repoRoot }) rather than re-describing it.

    2. Remove-ShipFoldWorktree -NotOwned NEVER REMOVES A TREE IT DID NOT CREATE. Proven by extracting the
       real function body out of ship-pr.ps1 (brace-balanced, verbatim -- never retyped) into an isolated
       unit alongside the real native-capture-lib.ps1, and running it against an actual git worktree in a
       throwaway fixture repo: with -NotOwned the worktree survives; without it (the ordinary,
       already-existing behaviour) it is removed, which is the regression guard proving the extraction
       still exercises the real function rather than a stub.

    3. THE -TrustedRoot FOLD ARM SETS $foldTree TO THE CALLER'S OWN TREE, NEVER A NEW WORKTREE. Proven by
       extracting that exact `if ($TrustedRoot) { ... }` block (again brace-balanced, verbatim) and running
       it in isolation, with nothing else defined in scope: if it called git, Invoke-NativeCapture or
       anything else this suite does not provide, the run would fail outright rather than quietly succeed.
       It runs clean and returns exactly the resolved fixture path, which is the behavioural half of what
       trusted-tree-seam.tests.ps1 already pins textually (no `worktree add` reachable past the
       -TrustedRoot short-circuit).

    THE HONEST GAP THIS SUITE DOES NOT CLOSE (named in the branch document's own TEST section): the
    ephemeral GIT_CONFIG_KEY_n credential mechanism, and whether a merge-on-green sweep genuinely reaches
    the fold arm above through a real two-directory git push over HTTPS, needs a live run of
    .github/workflows/merge-on-green.yml against a real pull request -- workflow_run always executes the
    DEFAULT branch's copy of that file, so it cannot be proven from this branch's own pull request, and no
    fixture built here can stand in for GitHub's own receive-pack authorisation. merge-on-green-lib.tests.ps1
    (Tycho #18, item 1) proves the LOCAL half of that mechanism -- that git itself honours the extracted
    triplet -- which is as close as a suite in this tree can get without a network call.

    Dependency-free (no Pester), same style as the rest of the suite. Pure ASCII.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot         = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$ShipPath         = Join-Path $RepoRoot 'scripts\release\ship-pr.ps1'
$OpenPath         = Join-Path $RepoRoot 'scripts\release\open-pr.ps1'
$NativeCaptureSrc = Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1'

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635's own convention, carried here too.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}

function Test-Says {
    <# Whitespace-insensitive, ordinal-ignorecase containment -- the same helper (and the same reason)
       as worktree-lane.tests.ps1's own copy: the trap in ship-pr.ps1/open-pr.ps1 prints the thrown
       ErrorRecord through $host.UI.WriteErrorLine(($_ | Out-String).TrimEnd()), which can still be
       wrapped by the host's own console width -- see the lens's "Which suites need Test-Says" section.
       Literal (IndexOf), so a phrase carrying '(' or '.' needs no escaping. #>
    param([string]$Text, [string]$Phrase)
    $haystack = ($Text -replace '\s', '')
    $needle = ($Phrase -replace '\s', '')
    return ($haystack.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}
function Assert-Says {
    param([string]$Text, [string]$Phrase, [string]$Name)
    if (Test-Says -Text $Text -Phrase $Phrase) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         wanted: '$Phrase'`n         in:    '$Text'" -ForegroundColor Red }
}

# THE FLATTENER: join captured records with '' (not a space, not a newline) -- measured 0/480 failures
# against a formatter break landing on every column of a 120-wide render (the lens's "three flatteners"
# section). A join with a space cannot repair a break that landed INSIDE a word.
function Get-FlatOutput {
    param($Captured)
    return (($Captured | Out-String) -replace "`r?`n", '')
}

$script:fixtures = @()

# =================================================================================================
# PART 1 -- SEAM LOADING PREFERS -TrustedRoot/-SeamRoot OVER $repoRoot
# =================================================================================================
Write-Host 'Part 1: -TrustedRoot / -SeamRoot are read INSTEAD OF $repoRoot, not merely when $repoRoot lacks the file' -ForegroundColor Cyan

function New-SeamFixtureRoot {
    <# A throwaway root carrying only the two repo-owned seam files: scripts\repo-config.ps1, whose
       Get-RepoName THROWS a marker distinctive to this root, and scripts\lib\branch-info.ps1 (needed by
       open-pr.ps1's own two-file pre-flight; ship-pr.ps1 never reads it at all). No git repo -- CLAUDE
       PROJECT_DIR only needs to name an EXISTING directory (Resolve-CheckRoot's own contract), and no
       marketplace.json, so Assert-OwnCopy's condition 2 declines and the guard never fires. #>
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][string]$Marker)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ship-pr-seam-$Label-$PID-$([guid]::NewGuid().ToString('n'))")
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\lib') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir 'scripts\repo-config.ps1'),
        "function Get-RepoName { throw '$Marker' }`r`n", (New-Object System.Text.UTF8Encoding $false))
    [System.IO.File]::WriteAllText((Join-Path $dir 'scripts\lib\branch-info.ps1'),
        "# fixture stub`r`n", (New-Object System.Text.UTF8Encoding $false))
    $script:fixtures += $dir
    return $dir
}

function Invoke-SeamProbe {
    <# Runs the REAL script (never a copy) as a child process, with CLAUDE_PROJECT_DIR pointed at the
       fixture "branch" root and the process cwd pointed at a THIRD, throwaway, non-repo directory -- so
       nothing this run could reach by an unqualified relative git call is the real checkout. Both scripts
       die at (or immediately after) the seam dot-source, before any gh call or git mutation, so this never
       touches real state regardless. #>
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$BranchDir,
        [string[]]$ExtraArgs = @()
    )
    $cwdDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ship-pr-seam-cwd-$PID-$([guid]::NewGuid().ToString('n'))")
    New-Item -ItemType Directory -Path $cwdDir -Force | Out-Null
    $script:fixtures += $cwdDir
    $prevPd  = $env:CLAUDE_PROJECT_DIR
    $prevLoc = (Get-Location).Path
    $prevEap = $ErrorActionPreference
    try {
        $env:CLAUDE_PROJECT_DIR = $BranchDir
        $ErrorActionPreference = 'Continue'
        Set-Location -LiteralPath $cwdDir
        $out  = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ExtraArgs 2>&1
        $code = $LASTEXITCODE
        return [pscustomobject]@{ Code = $code; Out = (Get-FlatOutput $out) }
    } finally {
        $ErrorActionPreference = $prevEap
        Set-Location -LiteralPath $prevLoc
        if ($null -eq $prevPd) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prevPd }
    }
}

try {
    # --- 1a. open-pr.ps1, no -SeamRoot: reads $repoRoot's own copy ---------------------------------
    $branch1a = New-SeamFixtureRoot -Label '1a-branch' -Marker 'MARKER-BRANCH-1A'
    $r1a = Invoke-SeamProbe -ScriptPath $OpenPath -BranchDir $branch1a
    Assert-Equal 1 $r1a.Code 'open-pr.ps1, no -SeamRoot: refuses (the thrown marker becomes a terminating error)'
    Assert-Says $r1a.Out 'MARKER-BRANCH-1A' 'open-pr.ps1, no -SeamRoot: the BRANCH copy of Get-RepoName ran'

    # --- 1b. open-pr.ps1, -SeamRoot given: reads the TRUSTED copy, not the branch's OWN valid one ---
    # THE BRANCH ROOT ALSO CARRIES A VALID SEAM FILE HERE -- the point being proven is precedence, not
    # merely "a missing file falls back somewhere else".
    $branch1b  = New-SeamFixtureRoot -Label '1b-branch'  -Marker 'MARKER-BRANCH-1B-MUST-NOT-RUN'
    $trusted1b = New-SeamFixtureRoot -Label '1b-trusted' -Marker 'MARKER-TRUSTED-1B'
    $r1b = Invoke-SeamProbe -ScriptPath $OpenPath -BranchDir $branch1b -ExtraArgs @('-SeamRoot', $trusted1b)
    Assert-Equal 1 $r1b.Code 'open-pr.ps1, -SeamRoot: refuses (the TRUSTED marker becomes a terminating error)'
    Assert-Says $r1b.Out 'MARKER-TRUSTED-1B' 'open-pr.ps1, -SeamRoot: the TRUSTED copy of Get-RepoName ran'
    Assert-True (-not (Test-Says -Text $r1b.Out -Phrase 'MARKER-BRANCH-1B')) `
        'open-pr.ps1, -SeamRoot: the BRANCH''s own (valid) copy did NOT run -- -SeamRoot wins, not just "file present somewhere"'

    # --- 1c. ship-pr.ps1, no -TrustedRoot: reads $repoRoot's own copy ------------------------------
    $branch1c = New-SeamFixtureRoot -Label '1c-branch' -Marker 'MARKER-BRANCH-1C'
    $r1c = Invoke-SeamProbe -ScriptPath $ShipPath -BranchDir $branch1c
    Assert-Equal 1 $r1c.Code 'ship-pr.ps1, no -TrustedRoot: refuses'
    Assert-Says $r1c.Out 'MARKER-BRANCH-1C' 'ship-pr.ps1, no -TrustedRoot: the BRANCH copy of Get-RepoName ran'

    # --- 1d. ship-pr.ps1, -TrustedRoot given: reads the TRUSTED copy -------------------------------
    $branch1d  = New-SeamFixtureRoot -Label '1d-branch'  -Marker 'MARKER-BRANCH-1D-MUST-NOT-RUN'
    $trusted1d = New-SeamFixtureRoot -Label '1d-trusted' -Marker 'MARKER-TRUSTED-1D'
    $r1d = Invoke-SeamProbe -ScriptPath $ShipPath -BranchDir $branch1d -ExtraArgs @('-TrustedRoot', $trusted1d)
    Assert-Equal 1 $r1d.Code 'ship-pr.ps1, -TrustedRoot: refuses'
    Assert-Says $r1d.Out 'MARKER-TRUSTED-1D' 'ship-pr.ps1, -TrustedRoot: the TRUSTED copy of Get-RepoName ran'
    Assert-True (-not (Test-Says -Text $r1d.Out -Phrase 'MARKER-BRANCH-1D')) `
        'ship-pr.ps1, -TrustedRoot: the BRANCH''s own (valid) copy did NOT run'
} finally {
    foreach ($f in ($script:fixtures | Select-Object -Unique)) {
        if ($f -and (Test-Path -LiteralPath $f)) { Remove-Item -Recurse -Force -LiteralPath $f -ErrorAction SilentlyContinue }
    }
    $script:fixtures = @()
}

# =================================================================================================
# PART 2 -- Remove-ShipFoldWorktree -NotOwned NEVER REMOVES A TREE IT DID NOT CREATE
# =================================================================================================
Write-Host ''
Write-Host 'Part 2: Remove-ShipFoldWorktree -NotOwned, extracted verbatim, against a real git worktree' -ForegroundColor Cyan

function Get-BalancedBlock {
    <# The text from the first match of $StartPattern to that block's own balanced closing brace --
       brace counting, not a bounded regex, so nesting inside the block (an if/else, a foreach) cannot
       truncate it early. Naive about strings/comments containing '{'/'}', which is safe for the two
       call sites below: neither extracted block contains a brace inside a string or a comment (checked
       by hand against the source this suite pins with the [x] found asserts further down). #>
    param([string]$Text, [string]$StartPattern)
    $m = [regex]::Match($Text, $StartPattern)
    if (-not $m.Success) { return $null }
    $openIdx = $Text.IndexOf('{', $m.Index)
    if ($openIdx -lt 0) { return $null }
    $depth = 0
    for ($i = $openIdx; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') {
            $depth--
            if ($depth -eq 0) { return $Text.Substring($m.Index, $i - $m.Index + 1) }
        }
    }
    return $null
}

$ShipRaw = Get-Content -LiteralPath $ShipPath -Raw

$removeFnText = Get-BalancedBlock -Text $ShipRaw -StartPattern 'function Remove-ShipFoldWorktree\s*\{'
Assert-True ([bool]$removeFnText) 'Remove-ShipFoldWorktree is extracted verbatim from ship-pr.ps1 (brace-balanced)'
Assert-True ($removeFnText -match '\[switch\]\$NotOwned') 'the extracted text carries the -NotOwned parameter'

if ($removeFnText) {
    $unitDir  = Join-Path ([System.IO.Path]::GetTempPath()) ("ship-pr-removefn-unit-$PID-$([guid]::NewGuid().ToString('n'))")
    New-Item -ItemType Directory -Path $unitDir -Force | Out-Null
    $script:fixtures += $unitDir
    $unitFile = Join-Path $unitDir 'unit.ps1'
    # NATIVE-CAPTURE-LIB.PS1 IS DOT-SOURCED BY ITS REAL, ABSOLUTE PATH, never copied: its OWN guarded
    # dot-source of run-progress-lib.ps1 resolves via $PSScriptRoot, so loading it from its real location
    # picks up that sibling exactly as ship-pr.ps1 itself does, with no fixture copy needed.
    [System.IO.File]::WriteAllText($unitFile, @"
. '$NativeCaptureSrc'
$removeFnText
"@, (New-Object System.Text.UTF8Encoding $false))

    $fixtureRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("ship-pr-removefn-repo-$PID-$([guid]::NewGuid().ToString('n'))")
    New-Item -ItemType Directory -Path $fixtureRepo -Force | Out-Null
    $script:fixtures += $fixtureRepo
    $wtOwnedDir    = "$fixtureRepo-wt-owned"
    $wtNotOwnedDir = "$fixtureRepo-wt-notowned"
    $script:fixtures += $wtOwnedDir
    $script:fixtures += $wtNotOwnedDir

    function Invoke-Git2 {
        param([string[]]$Arguments)
        $prevEap = $ErrorActionPreference
        try { $ErrorActionPreference = 'Continue'; $out = & git @Arguments 2>&1; return [pscustomobject]@{ Code = $LASTEXITCODE; Out = (($out | Out-String).Trim()) } }
        finally { $ErrorActionPreference = $prevEap }
    }
    function Invoke-FixtureGit2 {
        param([string[]]$Arguments)
        $r = Invoke-Git2 -Arguments $Arguments
        Assert-FixtureGitOk -Code $r.Code -GitArgs $Arguments -Output $r.Out
    }

    Invoke-FixtureGit2 @('init', '-q', $fixtureRepo)
    Invoke-FixtureGit2 @('-C', $fixtureRepo, 'config', 'user.email', 'tycho-tests@local.invalid')
    Invoke-FixtureGit2 @('-C', $fixtureRepo, 'config', 'user.name', 'Tycho Tests')
    Invoke-FixtureGit2 @('-C', $fixtureRepo, 'config', 'commit.gpgsign', 'false')
    Invoke-FixtureGit2 @('-C', $fixtureRepo, 'symbolic-ref', 'HEAD', 'refs/heads/main')
    [System.IO.File]::WriteAllText((Join-Path $fixtureRepo 'README.md'), "# fixture`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-FixtureGit2 @('-C', $fixtureRepo, 'add', '-A')
    Invoke-FixtureGit2 @('-C', $fixtureRepo, 'commit', '-q', '-m', 'init')

    # TWO WORKTREES, BOTH HOLDING A BRANCH OF THEIR OWN (git refuses two worktrees on the same ref) --
    # this suite never needs 'main' checked out anywhere but the primary, so a throwaway branch per
    # worktree is enough to exercise the removal itself.
    Invoke-FixtureGit2 @('-C', $fixtureRepo, 'branch', 'wt-owned')
    Invoke-FixtureGit2 @('-C', $fixtureRepo, 'branch', 'wt-notowned')
    Invoke-FixtureGit2 @('-C', $fixtureRepo, 'worktree', 'add', $wtOwnedDir, 'wt-owned')
    Invoke-FixtureGit2 @('-C', $fixtureRepo, 'worktree', 'add', $wtNotOwnedDir, 'wt-notowned')

    function Get-WorktreeCount2 {
        param([string]$Dir)
        $r = Invoke-Git2 -Arguments @('-C', $Dir, 'worktree', 'list', '--porcelain')
        return @($r.Out -split "`r?`n" | Where-Object { $_ -match '^worktree\s+' }).Count
    }
    Assert-Equal 3 (Get-WorktreeCount2 -Dir $fixtureRepo) 'sanity: the fixture repo now registers three worktrees (primary + two)'

    # --- 2a. -NotOwned: the worktree this run did NOT create SURVIVES ------------------------------
    . $unitFile
    # THE REAL SCRIPT'S OWN INVARIANT, REPRODUCED HERE ON PURPOSE: Remove-ShipFoldWorktree's git call
    # carries no -C -- it relies on ship-pr.ps1 having already Set-Location'd to $repoRoot long before
    # step 5 runs (line 489). Without reproducing that here, 'git worktree remove' would run against
    # whatever repo this SUITE's own process happens to be standing in, not the fixture -- which is
    # dangerous-by-omission even where the path coincidentally matches nothing there. Push/Pop around
    # every call, exactly as ship-pr.ps1's own Set-Location $repoRoot holds for its whole remaining run.
    $prevLocPart2 = (Get-Location).Path
    try {
        Set-Location -LiteralPath $fixtureRepo
        Remove-ShipFoldWorktree -Path $wtNotOwnedDir -NotOwned
        Assert-Equal 3 (Get-WorktreeCount2 -Dir $fixtureRepo) '-NotOwned: still three worktrees registered -- nothing was removed'
        Assert-True (Test-Path -LiteralPath $wtNotOwnedDir -PathType Container) '-NotOwned: the directory itself still exists'

        # --- 2b. no -NotOwned (the ordinary, pre-existing arm): the worktree this run DID own IS removed
        # THE REGRESSION GUARD: without this half, 2a would pass for the trivial reason that the extracted
        # function does nothing at all (a no-op stub would also leave the worktree alone).
        Remove-ShipFoldWorktree -Path $wtOwnedDir
        Assert-Equal 2 (Get-WorktreeCount2 -Dir $fixtureRepo) 'no -NotOwned: back to two worktrees -- the owned one WAS removed'
        Assert-True (-not (Test-Path -LiteralPath $wtOwnedDir -PathType Container)) 'no -NotOwned: the directory itself is gone'
    } finally {
        Set-Location -LiteralPath $prevLocPart2
    }
}

# =================================================================================================
# PART 3 -- THE -TrustedRoot FOLD ARM SETS $foldTree TO THE CALLER'S TREE, NEVER A NEW WORKTREE
# =================================================================================================
Write-Host ''
Write-Host 'Part 3: the -TrustedRoot fold arm, extracted verbatim, never calls git at all' -ForegroundColor Cyan

# ANCHORED ON THE SAME TEXT trusted-tree-seam.tests.ps1 already pins textually ('if ($TrustedRoot) {'
# immediately followed by '$trustedResolved'), which is what disambiguates this occurrence from the
# other three literal 'if ($TrustedRoot) {' sites in this file (the skip-forcing block, the one-line
# $seamRoot assignment, and the open-pr.ps1 forwarding call).
$foldArmText = Get-BalancedBlock -Text $ShipRaw -StartPattern '(?s)if\s*\(\$TrustedRoot\)\s*\{\s*\$trustedResolved'
Assert-True ([bool]$foldArmText) 'the -TrustedRoot fold arm is extracted verbatim (brace-balanced, disambiguated on $trustedResolved)'
# NOT 'worktree' as a bare substring: the arm's own Write-Host line legitimately SAYS "not a new
# worktree" in its human-readable message. What must be absent is an actual git invocation --
# Invoke-NativeCapture, or the literal 'worktree', 'add' argument pair ship-pr.ps1's throwaway-worktree
# arm uses a few lines below this one in the real file.
Assert-True ($foldArmText -notmatch 'Invoke-NativeCapture') 'the extracted arm calls no native-capture git wrapper'
Assert-True ($foldArmText -notmatch "'worktree',\s*'add'") 'the extracted arm never spells the worktree-add argument pair'

if ($foldArmText) {
    $foldFixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ship-pr-foldarm-$PID-$([guid]::NewGuid().ToString('n'))")
    New-Item -ItemType Directory -Path $foldFixtureDir -Force | Out-Null
    $script:fixtures += $foldFixtureDir
    try {
        # RUN IN ISOLATION, WITH NOTHING ELSE DEFINED: if this block called git, Invoke-NativeCapture or
        # anything this scriptblock's own scope does not provide, the run would fail outright (an unknown
        # command) rather than quietly succeed -- so a clean return is itself behavioural evidence that
        # the arm's only actions are Resolve-Path and Write-Host, exactly as the structural assert above
        # and trusted-tree-seam.tests.ps1's own textual pin both already say.
        $foldArmSb = [scriptblock]::Create("param(`$TrustedRoot)`r`n$foldArmText`r`nreturn `$foldTree")
        $result = & $foldArmSb $foldFixtureDir
        $resolvedFixture = (Resolve-Path -LiteralPath $foldFixtureDir).Path
        Assert-Equal $resolvedFixture $result `
            'running the extracted arm in isolation sets $foldTree to the resolved -TrustedRoot path -- no worktree, no git call, nothing else defined was needed'
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $foldFixtureDir -ErrorAction SilentlyContinue
    }
}

# HONEST GAP, NAMED RATHER THAN LEFT SILENT: this proves $foldTree is set correctly and that nothing
# past this arm needs a worktree. It does NOT prove the fetch + ff-only merge + fold-changelog-entry.ps1
# invocation that follows it in ship-pr.ps1 actually succeeds against $TrustedRoot end to end -- that
# needs a real 'origin' remote a genuinely merged PR could fast-forward against, which is exactly the
# live-run gap this file's own header names.

foreach ($f in ($script:fixtures | Select-Object -Unique)) {
    if ($f -and (Test-Path -LiteralPath $f)) { Remove-Item -Recurse -Force -LiteralPath $f -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "ship-pr-trusted-root.tests.ps1: $script:pass passed, $script:fail failed" -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
$fixtureBroken = Write-FixtureGitSummary -Subject 'ship-pr-trusted-root.tests.ps1'
if ($script:fail -gt 0) { exit 1 }
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
exit 0
