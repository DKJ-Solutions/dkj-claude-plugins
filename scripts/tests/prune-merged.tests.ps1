<#
.SYNOPSIS
    Regression tests for scripts/task/prune-merged.ps1 (fast-forward the trunk, prune stale
    remote-tracking refs, delete only the local branches whose merge can be proven).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Integration style -- runs the REAL script
    (copied into a throwaway temp git repo with a bare 'origin', so every mutation lands in TEMP and
    never touches the own working copy or a real remote) and asserts on exit code + output + git state.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/prune-merged.tests.ps1

    THE ASSERTS DEPEND ON NO REAL gh, AND ON NO NETWORK. A fixture's remote is a local bare repo, so
    `gh pr list` cannot resolve a GitHub repo there and the merged-PR proof is simply unavailable --
    which is a path the script has to answer gracefully anyway, and one of the cases below is exactly
    that. Most of what is asserted here is therefore the ANCESTRY proof and the keep-with-a-reason
    behaviour, both pure git and identical on a developer machine and in CI.

    THE THREE CASES THAT DO NEED THE MERGED-PR PROOF BRING THEIR OWN gh (inbound #1191), a batch file
    on PATH that prints a canned answer -- see New-GhStub. It reaches nothing: no network, no GitHub,
    no credential, and it is as reproducible in CI as everything above it. It exists because "the
    asserts do not depend on gh" had a cost nobody had priced: proof (b) was never established in any
    fixture, so the arm that force-deletes a branch on a merged PR was the one arm this suite could not
    see -- and the name-versus-tip defect of #1191 lived there for the whole life of the script.

    prune-merged.ps1 itself calls 'exit', so it is run here as a CHILD PROCESS (powershell -File).
    Its git commands already run under ErrorActionPreference=Continue themselves (the #107 pitfall,
    via the shared Invoke-NativeCapture) -- this test script mirrors the same caution around ITS OWN
    git fixture calls.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot          = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
$PruneMergedSrc    = Join-Path $RepoRoot 'scripts\task\prune-merged.ps1'
# Dot-sourced by the script for every git call (the #107 stderr guard).
$NativeCaptureSrc  = Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1'
# And for Get-BranchTrunkName: the trunk comes from the seam rather than a literal, so a fixture
# without this lib has no script at all.
$EntryScaffoldSrc  = Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1'
# And for naming the worktree that holds the trunk when the checkout is refused (issue #1069). The
# fixture repo has exactly one worktree, so this lib answers "nobody else holds it" on every case in
# this suite -- it is copied because a MISSING dot-source is not a degraded answer but no script at
# all, which is how its absence showed up: every single case failed at exit 1 before the first assert.
$WorktreeLibSrc    = Join-Path $RepoRoot 'scripts\lib\worktree-lib.ps1'
# worktree-lib.ps1 dot-sources this for Get-DisplayRef (issue #1623), so a fixture that copies the one
# without the other builds a repo whose scripts die on a missing function.
$RefPrintLibSrc    = Join-Path $RepoRoot 'scripts\lib\ref-print-lib.ps1'
# And for the merged-PR proof itself (issue #1194): the map and the two-part test every proof-(b) case
# below is decided by, shared with dkj-subagents-shopify's sync-main.ps1 since the same mechanism turned out to
# have been repaired twice in one day. Same reason as worktree-lib above -- and it was rediscovered the
# same way the moment the dot-source was added and this line was not.
$MergedPrLibSrc    = Join-Path $RepoRoot 'scripts\lib\merged-pr-lib.ps1'

$script:pass = 0
$script:fail = 0

function Get-FlatOutput {
    <#
        Captured child output as ONE line: every record read as text, then joined with nothing between.
        A native child's stderr captured with 2>&1 arrives as a NativeCommandError per stderr LINE, and
        the child has already WRAPPED its message at its own host width -- a point that moves with the
        console width and with the length of the fixture's temp path, neither of which this script
        decides. So a phrase assert must survive a break anywhere.

        Read as text rather than rendered with Out-String, which is the part that used to break it:
        Out-String FORMATS each of those records for display, and the decoration it adds ('At <file>:<line>
        char:<n>', the '+ CategoryInfo' block, '+ FullyQualifiedErrorId : NativeCommandError') lands
        BETWEEN the two halves of a wrapped sentence. Removing newlines cannot bridge that -- there is now
        a paragraph of PowerShell in the gap, not a line break. Measured on prune-merged's no-trunk
        refusal, which is long enough to wrap mid-phrase on a developer machine while staying whole in
        CI: green there, red here, for a script that was correct in both places.

        Joined with '' rather than a space because the wrap is a HARD break at a column, so the halves
        reconstruct exactly ('dirt' + 'y working tree'); a space between them would match nothing.
        seam-lib.tests.ps1 and internal-note.tests.ps1 carry this same copy since #982/#959, where the
        wrap reached both of them for real: red on a developer console, green in CI.

        WHO ELSE ANSWERS THIS QUESTION, AND HOW -- measured August 27, 2026, because the list that stood
        here was wrong in both directions and a stale at-risk record is worse than none. Three older
        variants are in the tree, and they are NOT equally exposed:

          * park-branch, park-cycle and worktree-lane: Out-String, then newlines removed. Safe against
            the mid-word break, exposed to the decoration Out-String inserts between the halves. The
            last two were absent from the list that stood here.
          * new-branch: Out-String, then ALL whitespace stripped -- robust against a break anywhere, at
            the price of asserts that must themselves be whitespace-free.
          * find-specialist-mentions: joins with a SPACE, which is the one variant measured to fail
            outright ('the da' + ' ' + 'te by hand' matches nothing). Exposed on both counts.

        shared-scripts.tests.ps1 was named here and carries no copy at all: it captures the child's
        stderr to a redirect FILE and strips all whitespace in Test-OutputContains, which is stronger
        than this helper rather than older than it. (session-status.tests.ps1 did carry one, until #957
        removed it with the script it covered.)

        THAT INVENTORY WAS RIGHT ABOUT THE MECHANISM AND WRONG ABOUT WHO IS EXPOSED (#1736,
        September 9, 2026). Exposure is not a property of a suite's flattener. It needs TWO things: the
        capture has to carry the child's error stream, AND the phrase an assert reads has to be emitted
        into it -- through throw, Write-Error or Write-Warning. Write-Host never reaches the formatter,
        and most asserts in these suites read Write-Host.

        Re-measuring the three variants settled both halves. Over 120 wrap positions x 4 phrases (480
        checks each), padding a Write-Error until its break swept every column of a 120-wide render:

          * collapse to a space:      68 of 480 fail -- e.g. 'dirty working tre e'
          * no flattening at all:     68 of 480 fail
          * join with '' (this one):   0 of 480 fail

        So the ranking above is confirmed and the exposure list is not. find-specialist-mentions is the
        only suite on the failing variant, and it asserts NO formatter-emitted phrase -- so it is exposed
        on neither count, not "on both". park-branch and worktree-lane join with '' like this file, and
        their summary lines described the other variant; both were corrected alongside this one. No
        suite in the tree was found to be letting a wrapped phrase through.

        AND SINCE #1742 NO SUITE IS ON THE FAILING VARIANT EITHER (September 9, 2026). The two
        paragraphs above are left as written -- they are dated measurements -- but the sentence they
        end on has moved: find-specialist-mentions.tests.ps1 now joins with '' like this file. It was
        changed while nothing was failing there, precisely because the safety was an accident of what
        that suite happens to assert, and the first refusal assert added to it would have inherited the
        68-in-480 variant.

        WHICH MAKES THE ASSERT-SAYS CONVERSION BELOW A HARDENING, NOT A FIX, and it is worth saying so
        plainly. Joining with '' reconstructs a mid-word split exactly, and survives a split on a space
        only because PowerShell keeps that space at the end of the line it wrapped -- a property of the
        renderer that nothing here controls or tests. Assert-Says strips ALL whitespace from both sides
        and needs neither property, so the eleven asserts that read one of this script's three
        Write-Error/Write-Warning messages go through it. The rest keep -match, deliberately: they read
        Write-Host lines, and routing those through a whitespace-blind reader would assert LESS than
        -match does.
    #>
    param($Captured)
    return (($Captured | ForEach-Object { [string]$_ }) -join '')
}

function Test-Says {
    <# Does captured child output contain this phrase, whatever the console did to it? Strips ALL
       whitespace from both sides, which is the only form immune to a break at either kind of position
       -- see the reasoning in Get-FlatOutput above.

       Literal (IndexOf), so a phrase carrying '(', ')', '-' or a path separator needs no escaping,
       which is why the call sites below lost their [regex]::Escape(). OrdinalIgnoreCase keeps the
       case-insensitivity -match had at those sites. #>
    param([string]$Text, [string]$Phrase)
    $haystack = ($Text -replace '\s', '')
    $needle = ($Phrase -replace '\s', '')
    return ($haystack.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Assert-Says {
    param([string]$Text, [string]$Phrase, [string]$Name)
    if (Test-Says -Text $Text -Phrase $Phrase) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         wanted to find: '$Phrase'`n         in:             '$Text'" -ForegroundColor Red
    }
}

function Assert-DoesNotSay {
    <# The negative direction, which is the one that fails SILENTLY: a bare -notmatch reports absence
       and has measured a line break, so it goes green for the wrong reason and no run ever shows it.
       Both call sites below assert that the dirty-tree refusal did NOT fire, which is exactly the
       claim a wrap would counterfeit. #>
    param([string]$Text, [string]$Phrase, [string]$Name)
    if (-not (Test-Says -Text $Text -Phrase $Phrase)) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         did NOT want to find: '$Phrase'" -ForegroundColor Red
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

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

$script:fixtures = @()

function Invoke-FixtureGit {
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

function New-Fixture {
    <#
        A fresh throwaway git repo with the script and its three libs copied in, an initial commit on
        'main', and a bare repo wired up as 'origin' -- pushed, so the fast-forward and the
        fetch --prune have a real remote to succeed against with no auth or network.
    #>
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("prune-merged-test-$PID-$Label-$([guid]::NewGuid().ToString('n'))")
    if (Test-Path -LiteralPath $dir) { Remove-Item -Recurse -Force -LiteralPath $dir }
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\task') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\lib')  -Force | Out-Null
    Copy-Item -LiteralPath $PruneMergedSrc   -Destination (Join-Path $dir 'scripts\task\prune-merged.ps1')       -Force
    Copy-Item -LiteralPath $NativeCaptureSrc -Destination (Join-Path $dir 'scripts\lib\native-capture-lib.ps1')  -Force
    Copy-Item -LiteralPath $EntryScaffoldSrc -Destination (Join-Path $dir 'scripts\lib\entry-scaffold-lib.ps1')  -Force
    # command-probe-lib.ps1 is a sibling of a sibling (#1729): the three libs above dot-source it for
    # Test-FunctionDefined, so the fixture owes it exactly as it owes ref-print-lib.
    # check-report-lib.ps1 likewise (#1917): the script under test resolves its repo root through
    # Resolve-RepoRootOrFail, which lives there -- so the fixture owes it too. UNGUARDED in the script,
    # deliberately: it is the first statement that runs, and a guarded load would have to fall back to
    # the very unjudged .Trim() this repair removes.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\check-report-lib.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\command-probe-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\command-probe-lib.ps1') -Force
    # document-newline-lib.ps1 likewise (#1832): entry-scaffold-lib.ps1 and pr-body-lib.ps1 dot-source it
    # for Get-DocumentNewline, unconditionally and for the same reason -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\document-newline-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\document-newline-lib.ps1') -Force
    # fetch-attempt-lib.ps1 likewise (#1860): entry-scaffold-lib.ps1 dot-sources it for
    # Invoke-RecordedRemoteFetch, which Get-TrunkGap's fetch runs through -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\fetch-attempt-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\fetch-attempt-lib.ps1') -Force
    Copy-Item -LiteralPath $WorktreeLibSrc   -Destination (Join-Path $dir 'scripts\lib\worktree-lib.ps1')        -Force
    Copy-Item -LiteralPath $RefPrintLibSrc   -Destination (Join-Path $dir 'scripts\lib\ref-print-lib.ps1')       -Force
    Copy-Item -LiteralPath $MergedPrLibSrc   -Destination (Join-Path $dir 'scripts\lib\merged-pr-lib.ps1')       -Force

    $bareRemote = "$dir.git"
    if (Test-Path -LiteralPath $bareRemote) { Remove-Item -Recurse -Force -LiteralPath $bareRemote }

    Invoke-FixtureGit -Arguments @('-C', $dir, 'init', '-q')
    Invoke-FixtureGit -Arguments @('-C', $dir, 'config', 'user.email', 'tycho-tests@local.invalid')
    Invoke-FixtureGit -Arguments @('-C', $dir, 'config', 'user.name', 'Tycho Tests')
    # gpgsign off: a locked signing agent must not fail a fixture commit for a reason unrelated to the test (#1287).
    Invoke-FixtureGit -Arguments @('-C', $dir, 'config', 'commit.gpgsign', 'false')
    # symbolic-ref instead of checkout -b: works on a still-unborn HEAD regardless of git's own
    # init.defaultBranch setting, and errors on nothing if HEAD is already named 'main'.
    Invoke-FixtureGit -Arguments @('-C', $dir, 'symbolic-ref', 'HEAD', 'refs/heads/main')
    [System.IO.File]::WriteAllText((Join-Path $dir 'README.md'), "# fixture`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-FixtureGit -Arguments @('-C', $dir, 'add', '-A')
    Invoke-FixtureGit -Arguments @('-C', $dir, 'commit', '-q', '-m', 'init')
    Invoke-FixtureGit -Arguments @('init', '--bare', '-q', $bareRemote)
    Invoke-FixtureGit -Arguments @('-C', $dir, 'remote', 'add', 'origin', $bareRemote)
    Invoke-FixtureGit -Arguments @('-C', $dir, 'push', '-q', '-u', 'origin', 'main')

    $script:fixtures += $dir
    $script:fixtures += $bareRemote
    return $dir
}

function Invoke-PruneMerged {
    <#
        Runs the fixture copy as a child process, with the fixture folder as cwd (so the dual-context
        fallback `git rev-parse --show-toplevel` lands there) and without CLAUDE_PROJECT_DIR left over
        from an earlier test run. EAP=Continue around the call, the same caution as the suites next to
        this one.

        -GhStubDir PUTS A FAKE gh IN FRONT OF THE REAL ONE, for the three cases that need proof (b).
        PATH is read by the child at process start, so prepending here is what decides which `gh` the
        script's own `Get-Command 'gh'` resolves. Restored in the finally, like every other piece of
        environment this function borrows -- a leaked PATH would silently stub every case below it.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [switch]$DryRun,
        [switch]$IncludeRemote,
        [string]$GhStubDir
    )
    $scriptPath = Join-Path $Dir 'scripts\task\prune-merged.ps1'
    $callArgs = @()
    if ($DryRun) { $callArgs += '-DryRun' }
    if ($IncludeRemote) { $callArgs += '-IncludeRemote' }

    $prevPd   = $env:CLAUDE_PROJECT_DIR
    $prevPath = $env:PATH
    $prevEap  = $ErrorActionPreference
    $prevLoc  = (Get-Location).Path
    try {
        Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
        if ($GhStubDir) { $env:PATH = "$GhStubDir;$prevPath" }
        Set-Location -LiteralPath $Dir
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @callArgs 2>&1
        $code = $LASTEXITCODE
        return [pscustomobject]@{ Code = $code; Out = (Get-FlatOutput $out) }
    } finally {
        $ErrorActionPreference = $prevEap
        Set-Location -LiteralPath $prevLoc
        $env:PATH = $prevPath
        if ($null -eq $prevPd) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prevPd }
    }
}

function New-GhStub {
    <#
        A `gh` that answers exactly one question -- `pr list --json headRefName,headRefOid` -- with a
        canned array, and returns the folder to put in front of PATH.

        WHY A STUB AT ALL, when this suite's whole stance is that the asserts do not depend on gh. That
        stance is still right for everything it covers: a fixture's remote is a local bare repo, so a
        REAL gh has no GitHub repo to resolve and proof (b) is simply unavailable -- which left the
        merged-PR arm, and the name-versus-tip bug living in it, outside every assert here. The stub
        does not reach a network or a real repo; it is a batch file that prints a string, and what it
        exercises is this script's own matching, which is the part inbound #1191 was about.

        A .cmd RATHER THAN A .ps1, because `Get-Command 'gh'` and `& 'gh'` both have to find it the way
        they would find the real executable -- PATHEXT resolves .cmd, and a bare .ps1 on PATH is not a
        command at all. `type` rather than an echo per row: the JSON carries quotes and braces, and
        batch escaping of those is a trap this suite has no reason to walk into.

        AND IT SITS BESIDE THE FIXTURE, NOT INSIDE IT. Two untracked files in the repo are a dirty
        working tree, which is step 1 of the script under test -- so an in-tree stub buys a refusal
        instead of a classification, on every case that uses it. Registered for cleanup like the
        fixture and its bare remote.

        IT HONOURS `--jq`, AND THAT IS WHAT MAKES THESE CASES REGRESSION TESTS. An arg-blind stub that
        always printed JSON was tried first and looked fine: green on the fixed script, and green on
        the BROKEN one too, because the pre-#1191 script asked for `--json headRefName --jq
        .[].headRefName` and read a JSON array as one unusable line -- so it matched nothing and kept
        the branch for entirely the wrong reason. A test that passes on the defect it was written for is
        worse than no test. So the stub answers the shape it was ASKED for: names only where `--jq` is
        present, the JSON array otherwise. Verified in both directions -- case (o) fails against the
        pre-#1191 source and passes against this one.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][array]$Rows
    )
    $stubDir = "$Dir.ghstub"
    if (Test-Path -LiteralPath $stubDir) { Remove-Item -Recurse -Force -LiteralPath $stubDir }
    New-Item -ItemType Directory -Path $stubDir -Force | Out-Null
    $script:fixtures += $stubDir

    # Built by hand rather than with ConvertTo-Json: a one-element array serialises as an OBJECT in
    # Windows PowerShell 5.1 unless it is wrapped, which is exactly the shape two of the three cases
    # below use, and a silently-object body would make them pass as "gh answered nothing".
    $items = @($Rows | ForEach-Object { '{"headRefName":"' + $_.Name + '","headRefOid":"' + $_.Oid + '"}' })
    $json  = '[' + ($items -join ',') + ']'
    $names = (@($Rows | ForEach-Object { $_.Name }) -join "`r`n") + "`r`n"
    $utf8  = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $stubDir 'gh-merged.json'),  $json,  $utf8)
    [System.IO.File]::WriteAllText((Join-Path $stubDir 'gh-merged-names.txt'), $names, $utf8)
    [System.IO.File]::WriteAllText((Join-Path $stubDir 'gh.cmd'), (@(
        '@echo off',
        'echo %*|findstr /C:"--jq" >nul',
        'if errorlevel 1 goto json',
        'type "%~dp0gh-merged-names.txt"',
        'goto :eof',
        ':json',
        'type "%~dp0gh-merged.json"'
    ) -join "`r`n") + "`r`n", $utf8)
    return $stubDir
}

function Get-BranchTip {
    <# The full sha a local branch points at -- what a merged PR's headRefOid is compared against. #>
    param([Parameter(Mandatory = $true)][string]$Dir, [Parameter(Mandatory = $true)][string]$Name)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        return ((& git -C $Dir rev-parse $Name | Select-Object -First 1) | Out-String).Trim()
    } finally { $ErrorActionPreference = $prevEap }
}

function Get-LocalBranches {
    param([Parameter(Mandatory = $true)][string]$Dir)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        return @(& git -C $Dir for-each-ref --format='%(refname:short)' refs/heads |
            ForEach-Object { $_.Trim() } | Where-Object { $_ })
    } finally { $ErrorActionPreference = $prevEap }
}

function Get-HeadName {
    <# 'main', a branch name, or the literal 'HEAD' when the fixture is detached. #>
    param([Parameter(Mandatory = $true)][string]$Dir)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        return ((& git -C $Dir rev-parse --abbrev-ref HEAD | Select-Object -First 1) | Out-String).Trim()
    } finally { $ErrorActionPreference = $prevEap }
}

function New-MergedBranch {
    <# A branch whose commit is then merged into main, so it IS an ancestor of the trunk. #>
    param([Parameter(Mandatory = $true)][string]$Dir, [Parameter(Mandatory = $true)][string]$Name)
    Invoke-FixtureGit -Arguments @('-C', $Dir, 'checkout', '-q', '-b', $Name)
    [System.IO.File]::WriteAllText((Join-Path $Dir "$($Name -replace '[\\/]', '-').txt"), "work`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-FixtureGit -Arguments @('-C', $Dir, 'add', '-A')
    Invoke-FixtureGit -Arguments @('-C', $Dir, 'commit', '-q', '-m', "work on $Name")
    Invoke-FixtureGit -Arguments @('-C', $Dir, 'checkout', '-q', 'main')
    Invoke-FixtureGit -Arguments @('-C', $Dir, 'merge', '-q', '--no-ff', '-m', "merge: $Name", $Name)
    Invoke-FixtureGit -Arguments @('-C', $Dir, 'push', '-q', 'origin', 'main')
}

function New-UnmergedBranch {
    <# A branch with its own commit and NO merge -- the shape of unfinished or parked work. #>
    param([Parameter(Mandatory = $true)][string]$Dir, [Parameter(Mandatory = $true)][string]$Name)
    Invoke-FixtureGit -Arguments @('-C', $Dir, 'checkout', '-q', '-b', $Name)
    [System.IO.File]::WriteAllText((Join-Path $Dir "$($Name -replace '[\\/]', '-').txt"), "wip`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-FixtureGit -Arguments @('-C', $Dir, 'add', '-A')
    Invoke-FixtureGit -Arguments @('-C', $Dir, 'commit', '-q', '-m', "wip on $Name")
    Invoke-FixtureGit -Arguments @('-C', $Dir, 'checkout', '-q', 'main')
}

try {
    # --- (a) Only the trunk: nothing to reap, exit 0 -------------------------------------------------
    Write-Host "prune-merged.ps1 -- only the trunk" -ForegroundColor Cyan
    $dirA = New-Fixture -Label 'a'
    $rA = Invoke-PruneMerged -Dir $dirA
    Assert-Equal 0 $rA.Code 'only the trunk: exit 0 -- nothing to reap is not an error'
    Assert-True ($rA.Out -match 'Nothing to reap') 'only the trunk: and it says so rather than printing an empty report'
    Assert-Equal 1 (Get-LocalBranches -Dir $dirA).Count 'only the trunk: main is still there'

    # --- (b) A merged branch goes, an unmerged branch stays -----------------------------------------
    #     THE CENTRAL PAIR. Both proofs are absent for the unmerged branch (no ancestry, and gh cannot
    #     resolve a GitHub repo from a local bare remote), which is precisely the state a parked branch
    #     or unfinished work is in -- so this asserts the safety property, not just the happy path.
    Write-Host "prune-merged.ps1 -- merged goes, unmerged stays" -ForegroundColor Cyan
    $dirB = New-Fixture -Label 'b'
    New-MergedBranch   -Dir $dirB -Name 'feat/landed'
    New-UnmergedBranch -Dir $dirB -Name 'feat/still-going'
    $rB = Invoke-PruneMerged -Dir $dirB
    Assert-Equal 0 $rB.Code 'mixed: exit 0'
    $branchesB = Get-LocalBranches -Dir $dirB
    Assert-True (-not ($branchesB -contains 'feat/landed')) 'mixed: the merged branch is deleted'
    Assert-True ($branchesB -contains 'feat/still-going') 'mixed: the UNMERGED branch survives -- the whole safety property of this script'
    Assert-True ($branchesB -contains 'main') 'mixed: and the trunk is never a candidate'
    Assert-True ($rB.Out -match 'Deleted feat/landed') 'mixed: the run names what it deleted'
    Assert-True ($rB.Out -match 'ancestor of main') 'mixed: with the proof it deleted on, so a reader can check the reasoning'
    Assert-True ($rB.Out -match 'Kept feat/still-going') 'mixed: and names what it kept'
    Assert-True ($rB.Out -match 'not an ancestor of the trunk') 'mixed: with the reason, rather than leaving it inferred from an absent line'
    # The remote half is somebody else's, and saying so is what stops a clean local list being read as
    # evidence about the remote.
    Assert-True ($rB.Out -match 'ls-remote --heads origin') 'mixed: it names the command that actually answers the remote question'

    # --- (c) -DryRun reports and deletes nothing -----------------------------------------------------
    Write-Host "prune-merged.ps1 -- -DryRun" -ForegroundColor Cyan
    $dirC = New-Fixture -Label 'c'
    New-MergedBranch -Dir $dirC -Name 'fix/landed-too'
    $rC = Invoke-PruneMerged -Dir $dirC -DryRun
    Assert-Equal 0 $rC.Code '-DryRun: exit 0'
    Assert-True ((Get-LocalBranches -Dir $dirC) -contains 'fix/landed-too') '-DryRun: the reapable branch is STILL THERE'
    Assert-True ($rC.Out -match 'Would delete fix/landed-too') '-DryRun: and it says what it would have done'
    Assert-True ($rC.Out -match 'Nothing was deleted') '-DryRun: with the line that makes the run unmistakable for the real one'

    # --- (d) A dirty tree IS refused where the step-off is reachable -------------------------------
    #     Refused UP FRONT rather than discovered by a failing checkout halfway through: at that point
    #     the fetch may already have run, and the reader has to work out what did and did not happen.
    #
    #     AND IT IS STANDING ON A BRANCH, WHICH IS THE WHOLE POINT OF THE CASE (issue #1575). This case
    #     ran from the trunk until September 8, 2026 -- New-MergedBranch ends with `checkout main`, so
    #     it did so silently -- which meant the one assert in the suite for this guard was pinning the
    #     state the guard should never have refused. The branch here is UNMERGED and never reaped; what
    #     is asserted is that the refusal arrives before anything is touched, and the reason it must is
    #     that this checkout's own branch COULD turn out to be reapable, which is unknowable at step 1.
    Write-Host "prune-merged.ps1 -- refuses on a dirty tree, standing on a branch" -ForegroundColor Cyan
    $dirD = New-Fixture -Label 'd'
    New-MergedBranch   -Dir $dirD -Name 'feat/would-have-gone'
    New-UnmergedBranch -Dir $dirD -Name 'feat/standing-here'
    Invoke-FixtureGit -Arguments @('-C', $dirD, 'checkout', '-q', 'feat/standing-here')
    [System.IO.File]::WriteAllText((Join-Path $dirD 'uncommitted.txt'), "in progress`n", (New-Object System.Text.UTF8Encoding $false))
    $rD = Invoke-PruneMerged -Dir $dirD
    Assert-Equal 1 $rD.Code 'dirty on a branch: exit 1'
    # All four read the ONE Write-Error that carries the dirty-tree refusal, so all four sit in the
    # formatter's output and go through Assert-Says (#1736). It is a long message interpolating the
    # fixture's branch name, which is precisely the sort that wraps somewhere different on every run.
    Assert-Says $rD.Out 'dirty working tree' 'dirty on a branch: the refusal names what is wrong'
    Assert-Says $rD.Out 'feat/standing-here' 'dirty on a branch: and names the branch that makes the step-off reachable, which is the whole ground of the refusal'
    Assert-Says $rD.Out 'park-branch' 'dirty on a branch: and points at the ways out rather than only refusing'
    Assert-Says $rD.Out '-DryRun' 'dirty on a branch: including the read-only way out, which costs the caller nothing'
    Assert-True ((Get-LocalBranches -Dir $dirD) -contains 'feat/would-have-gone') 'dirty on a branch: NOTHING was deleted -- a branch that was reapable a line earlier is untouched'
    Assert-Equal 'feat/standing-here' (Get-HeadName -Dir $dirD) 'dirty on a branch: and the caller is left exactly where the refusal found them'

    # --- (d2) A dirty tree on the TRUNK does not refuse -- it reports (issue #1575) -----------------
    #     THE CASE THE GUARD USED TO GET WRONG. The refusal's stated ground is stepping off the branch
    #     you are standing on; the candidate list is `refs/heads` minus the trunk, so standing on the
    #     trunk there is nothing to step off and step 4c is unreachable for the whole run. Measured on
    #     September 8, 2026 with one unrelated uncommitted file in a clean trunk checkout: refused.
    #
    #     IT MATTERS BECAUSE THIS IS THE PRESCRIBED MID-ASSIGNMENT COMMAND. The orchestrator's lens
    #     sends a session here instead of classifying `git ls-remote` output by hand, and mid-assignment
    #     is exactly when a checkout is dirty -- so the guard blocked the report in the state the advice
    #     was written for. The asserts are in three parts, because "did not refuse" is the weakest of
    #     them: the run must reach its work (the merged branch is actually reaped), and it must SAY the
    #     tree was dirty, so an absent refusal is never read as an absent guard.
    Write-Host "prune-merged.ps1 -- dirty tree on the trunk reports and proceeds" -ForegroundColor Cyan
    $dirD2 = New-Fixture -Label 'd2'
    New-MergedBranch -Dir $dirD2 -Name 'feat/landed-anyway'
    [System.IO.File]::WriteAllText((Join-Path $dirD2 'uncommitted.txt'), "in progress`n", (New-Object System.Text.UTF8Encoding $false))
    $rD2 = Invoke-PruneMerged -Dir $dirD2
    Assert-Equal 0 $rD2.Code 'dirty on the trunk: exit 0 -- the step-off it would refuse for is unreachable from here'
    # The refusal is a Write-Error, so its ABSENCE is what a wrap would counterfeit -- hence
    # Assert-DoesNotSay. The two lines under it read Write-Host and keep -match.
    Assert-DoesNotSay $rD2.Out 'refuses on a dirty working tree' 'dirty on the trunk: no refusal'
    Assert-True ($rD2.Out -match 'uncommitted change') 'dirty on the trunk: the dirty tree is REPORTED, not passed over in silence'
    Assert-True ($rD2.Out -match 'no branch to step off') 'dirty on the trunk: with the reason it was harmless, so the guard does not read as removed'
    Assert-True (-not ((Get-LocalBranches -Dir $dirD2) -contains 'feat/landed-anyway')) 'dirty on the trunk: and the run did its actual work'
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $dirD2 'uncommitted.txt')) -match 'in progress') 'dirty on the trunk: the uncommitted file is untouched -- the run never went near it'

    # --- (d3) A dirty tree under -DryRun does not refuse either (issue #1575) ----------------------
    #     The second unreachable state, and a separate arm because it holds even ON a branch: the
    #     per-branch loop `continue`s above 4c on every candidate, so a look-first run has no step-off
    #     to protect. This is the cheapest way for a session with uncommitted work to get the report.
    Write-Host "prune-merged.ps1 -- dirty tree under -DryRun reports and proceeds" -ForegroundColor Cyan
    $dirD3 = New-Fixture -Label 'd3'
    New-MergedBranch   -Dir $dirD3 -Name 'feat/would-be-reaped'
    New-UnmergedBranch -Dir $dirD3 -Name 'feat/standing-here-too'
    Invoke-FixtureGit -Arguments @('-C', $dirD3, 'checkout', '-q', 'feat/standing-here-too')
    [System.IO.File]::WriteAllText((Join-Path $dirD3 'uncommitted.txt'), "in progress`n", (New-Object System.Text.UTF8Encoding $false))
    $rD3 = Invoke-PruneMerged -Dir $dirD3 -DryRun
    Assert-Equal 0 $rD3.Code 'dirty under -DryRun: exit 0 -- on a branch, where the same run without -DryRun refuses'
    Assert-DoesNotSay $rD3.Out 'refuses on a dirty working tree' 'dirty under -DryRun: no refusal'
    Assert-True ($rD3.Out -match 'DryRun deletes nothing') 'dirty under -DryRun: and it says which of the reasons made the tree its own business'
    Assert-True ($rD3.Out -match 'Would delete feat/would-be-reaped') 'dirty under -DryRun: the report the caller came for is actually produced'
    Assert-True ((Get-LocalBranches -Dir $dirD3) -contains 'feat/would-be-reaped') 'dirty under -DryRun: and nothing was deleted'
    Assert-Equal 'feat/standing-here-too' (Get-HeadName -Dir $dirD3) 'dirty under -DryRun: the checkout never moved'

    # --- (e) A clone without the declared trunk refuses rather than guessing ------------------------
    #     The safe direction, and asserted because it is the one case where a wrong answer would delete
    #     against the wrong ancestry.
    Write-Host "prune-merged.ps1 -- no local trunk" -ForegroundColor Cyan
    $dirE = New-Fixture -Label 'e'
    New-UnmergedBranch -Dir $dirE -Name 'feat/orphan'
    Invoke-FixtureGit -Arguments @('-C', $dirE, 'checkout', '-q', 'feat/orphan')
    Invoke-FixtureGit -Arguments @('-C', $dirE, 'branch', '-q', '-D', 'main')
    $rE = Invoke-PruneMerged -Dir $dirE
    Assert-Equal 1 $rE.Code 'no trunk: exit 1'
    # The no-trunk refusal is the exact message the flattener's own docstring above cites as having
    # measured green in CI and red on a developer machine. Both sites are Write-Error.
    Assert-Says $rE.Out "no local branch 'main'" 'no trunk: the refusal names the branch it looked for'
    Assert-Says $rE.Out 'Get-TrunkBranchName' 'no trunk: and the seam that decides it, so a repo on another trunk knows where to answer'
    Assert-True ((Get-LocalBranches -Dir $dirE) -contains 'feat/orphan') 'no trunk: and it deleted nothing'

    # --- (e2) A second worktree holding the trunk is NAMED -- and no longer STOPS the run -----------
    #     git allows one worktree per branch, and it will not write a ref that is checked out anywhere
    #     in the clone. Under #1069 that made step 2's checkout impossible clone-wide and this script
    #     REFUSED -- so it was unavailable in exactly the situation that produces stray branches. Since
    #     #1147 the fast-forward is a refspec fetch, which is refused in the same state but costs only
    #     the fast-forward: the run continues against the local trunk, which errs towards KEEPING
    #     branches, and the lane is still named with the way out. THE PAIR IS THE POINT -- the naming
    #     without the exit code, and the reaping that used to be collateral damage of the refusal.
    #
    #     THIS CASE EXISTS FOR THE WIRING, NOT THE DECISION. worktree-lib.tests.ps1 asserts the reading;
    #     what only a fixture can prove is that the script REACHES it -- measured the hour this was
    #     written, when the lib was dot-sourced but not copied into the fixture and all 40 asserts in
    #     this file failed at exit 1, before the first one ran.
    Write-Host "prune-merged.ps1 -- another worktree holds the trunk" -ForegroundColor Cyan
    $dirE2 = New-Fixture -Label 'e2'
    New-MergedBranch -Dir $dirE2 -Name 'feat/would-have-gone-too'
    Invoke-FixtureGit -Arguments @('-C', $dirE2, 'checkout', '-q', '-b', 'feat/standing-here')
    $trunkLane = "$dirE2-lane"
    if (Test-Path -LiteralPath $trunkLane) { Remove-Item -Recurse -Force -LiteralPath $trunkLane }
    Invoke-FixtureGit -Arguments @('-C', $dirE2, 'worktree', 'add', '-q', $trunkLane, 'main')
    $rE2 = Invoke-PruneMerged -Dir $dirE2
    Assert-Equal 0 $rE2.Code 'trunk held: exit 0 -- a fast-forward that cannot happen is not worth losing the run over'
    # A Write-Warning, and the longest of the three: it interpolates the holder's absolute path twice,
    # so where it wraps moves with the length of the fixture's temp directory. The middle site loses its
    # [regex]::Escape() because Test-Says compares literally.
    Assert-Says $rE2.Out 'another worktree holds it' 'trunk held: the warning says what is actually wrong'
    Assert-Says $rE2.Out (Split-Path -Leaf $trunkLane) 'trunk held: and names the directory, which git own message does not'
    Assert-Says $rE2.Out 'HandBack' 'trunk held: with the way out, not only the verdict'
    Assert-True (-not ((Get-LocalBranches -Dir $dirE2) -contains 'feat/would-have-gone-too')) 'trunk held: and the run STILL REAPED -- the held trunk costs the fast-forward, not the tidy-up'
    Assert-Equal 'feat/standing-here' (Get-HeadName -Dir $dirE2) 'trunk held: with the caller left exactly where it was -- nothing was ever checked out'
    Invoke-FixtureGit -Arguments @('-C', $dirE2, 'worktree', 'remove', '--force', $trunkLane)

    # --- (e3) A MERGED branch a second worktree is standing on (issue #1760) -------------------------
    #     The mirror image of (e2): there a lane held the TRUNK and cost the fast-forward; here a lane
    #     holds a branch the two proofs have just cleared for deletion. git refuses to delete a branch
    #     that is checked out anywhere in the clone, and that refusal takes precedence over -d's own
    #     unmerged check -- so it lands on exactly the branches this script was about to reap. Step 4c
    #     can only move THIS tree's HEAD; no tree may move another one, so the answer is a sentence.
    #
    #     WHAT THIS ASSERTS THAT (e2) DOES NOT: the vocabulary. Before #1760 the delete was attempted
    #     and its refusal reported as `git branch -d refused: <git's own text>` -- true, and naming a
    #     worktree rather than a proof, with no hand-back in it. The pair below is the point: the
    #     branch survives (it always did), AND the reader is handed the way out instead of git's text.
    Write-Host "prune-merged.ps1 -- a merged branch is held by another worktree" -ForegroundColor Cyan
    $dirE3 = New-Fixture -Label 'e3'
    New-MergedBranch -Dir $dirE3 -Name 'feat/landed-in-a-lane'
    $branchLane = "$dirE3-lane"
    if (Test-Path -LiteralPath $branchLane) { Remove-Item -Recurse -Force -LiteralPath $branchLane }
    Invoke-FixtureGit -Arguments @('-C', $dirE3, 'worktree', 'add', '-q', $branchLane, 'feat/landed-in-a-lane')

    # THE LOOK-FIRST RUN FIRST, because it is the half that used to lie. -DryRun printed "Would delete
    # feat/landed-in-a-lane" for a delete the real run cannot perform -- a promise from the one mode
    # whose whole purpose is to say what will happen. That is why 4d is asked ABOVE the DryRun branch
    # rather than beside the delete.
    $rE3d = Invoke-PruneMerged -Dir $dirE3 -DryRun
    Assert-Equal 0 $rE3d.Code 'branch held, dry run: exit 0'
    Assert-DoesNotSay $rE3d.Out 'Would delete feat/landed-in-a-lane' 'branch held, dry run: it does not promise a delete the real run cannot perform'
    Assert-Says $rE3d.Out 'another worktree is standing on it' 'branch held, dry run: it reports the reason the real run will act on'

    $rE3 = Invoke-PruneMerged -Dir $dirE3
    Assert-Equal 0 $rE3.Code 'branch held: exit 0 -- one unreapable branch is not a failed run'
    Assert-True ((Get-LocalBranches -Dir $dirE3) -contains 'feat/landed-in-a-lane') 'branch held: the branch is still there'
    Assert-Says $rE3.Out 'another worktree is standing on it' 'branch held: reported in this script vocabulary, not git refusal text'
    Assert-Says $rE3.Out (Split-Path -Leaf $branchLane) 'branch held: and it names the directory holding it'
    Assert-Says $rE3.Out 'HandBack' 'branch held: with the way out, not only the verdict'
    Assert-DoesNotSay $rE3.Out 'refused:' 'branch held: git own refusal is never what the reader is handed'
    Assert-Equal 'main' (Get-HeadName -Dir $dirE3) 'branch held: and this checkout was never moved'
    Invoke-FixtureGit -Arguments @('-C', $dirE3, 'worktree', 'remove', '--force', $branchLane)

    # --- (e4) An UNMERGED branch in a lane keeps its OWN reason ---------------------------------------
    #     The bound on (e3). A lane holding unfinished work is the ordinary state this script exists to
    #     leave alone, and it is already kept for a reason of its own -- which is the reason a reader
    #     needs. Reporting the worktree there would name an obstacle when nothing was going to touch
    #     that branch, so 4d is asked AFTER the two proofs rather than at the top of the loop.
    Write-Host "prune-merged.ps1 -- an unmerged branch in a lane keeps its own reason" -ForegroundColor Cyan
    $dirE4 = New-Fixture -Label 'e4'
    New-UnmergedBranch -Dir $dirE4 -Name 'feat/still-working'
    $wipLane = "$dirE4-lane"
    if (Test-Path -LiteralPath $wipLane) { Remove-Item -Recurse -Force -LiteralPath $wipLane }
    Invoke-FixtureGit -Arguments @('-C', $dirE4, 'worktree', 'add', '-q', $wipLane, 'feat/still-working')
    $rE4 = Invoke-PruneMerged -Dir $dirE4
    Assert-Equal 0 $rE4.Code 'lane, unmerged: exit 0'
    Assert-True ((Get-LocalBranches -Dir $dirE4) -contains 'feat/still-working') 'lane, unmerged: the branch is still there'
    Assert-Says $rE4.Out 'not an ancestor of the trunk' 'lane, unmerged: kept for its own reason -- the proofs, not the worktree'
    Assert-DoesNotSay $rE4.Out 'another worktree is standing on it' 'lane, unmerged: and the lane is not reported as an obstacle to something nothing was going to do'
    Invoke-FixtureGit -Arguments @('-C', $dirE4, 'worktree', 'remove', '--force', $wipLane)
    # --- (f) It never deletes a remote branch -------------------------------------------------------
    #     A deliberate decision rather than an omission: with the remote reaping its own merged heads,
    #     a remote delete would only ever reach branches that are NOT merged.
    Write-Host "prune-merged.ps1 -- the remote is untouched" -ForegroundColor Cyan
    $dirF = New-Fixture -Label 'f'
    New-MergedBranch -Dir $dirF -Name 'feat/pushed-and-landed'
    Invoke-FixtureGit -Arguments @('-C', $dirF, 'push', '-q', 'origin', 'feat/pushed-and-landed')
    $rF = Invoke-PruneMerged -Dir $dirF
    Assert-Equal 0 $rF.Code 'remote: exit 0'
    Assert-True (-not ((Get-LocalBranches -Dir $dirF) -contains 'feat/pushed-and-landed')) 'remote: the LOCAL branch is deleted'
    $remoteHeads = @(& git -C $dirF ls-remote --heads origin | ForEach-Object { $_ })
    Assert-True (($remoteHeads -join ' ') -match 'feat/pushed-and-landed') 'remote: and the REMOTE branch is still standing -- this script deletes nothing there'

    # AND STRUCTURALLY, not only on this fixture. Matched on the QUOTED argument form -- the shape a
    # git call actually takes here (Invoke-NativeCapture takes an array of quoted strings) -- rather
    # than on the bare words, which appear in the script's own header explaining why it does not do
    # this. A prose ban and a code ban are two different assertions and only the second is worth one.
    #
    # QUOTES OF EITHER KIND SINCE #1042, and the widening is the point of it. That issue added a pass
    # that PRINTS `git push <remote> --delete <branch>`, so the file now contains those words in a
    # double-quoted string on purpose -- and a real call written as "--delete" instead of '--delete'
    # would have slipped past the single-quote form while looking exactly like the printed line. The
    # printed line survives this because what precedes its `--delete` is a SPACE, not a quote: an
    # argument is a string that starts there, a printed flag is a word inside one.
    $srcText = [System.IO.File]::ReadAllText($PruneMergedSrc)
    Assert-True ($srcText -notmatch '["'']--delete') 'remote: and no git call in the source carries a --delete argument, in quotes of either kind, so the property is structural rather than only untested here'

    # --- (g) -IncludeRemote classifies the heads it used to only name -------------------------------
    #     Issue #1042. `git ls-remote --heads` is the only read that surfaces a parked branch, and the
    #     script named that command while interpreting none of it -- so the same per-head triage was
    #     re-derived by hand, three times in two days. This asserts BOTH halves of the repair: the
    #     paste-ready command for a head with positive proof, and the labelled keep for one without.
    #     The unmerged head is deleted LOCALLY first, so it exists only on the remote -- the shape of a
    #     parked branch or another machine's push, which is the case the pass exists for.
    Write-Host "prune-merged.ps1 -- -IncludeRemote classifies the remote heads" -ForegroundColor Cyan
    $dirG = New-Fixture -Label 'g'
    New-MergedBranch   -Dir $dirG -Name 'feat/landed-and-pushed'
    New-UnmergedBranch -Dir $dirG -Name 'feat/parked-elsewhere'
    Invoke-FixtureGit -Arguments @('-C', $dirG, 'push', '-q', 'origin', 'feat/landed-and-pushed')
    Invoke-FixtureGit -Arguments @('-C', $dirG, 'push', '-q', 'origin', 'feat/parked-elsewhere')
    Invoke-FixtureGit -Arguments @('-C', $dirG, 'branch', '-q', '-D', 'feat/parked-elsewhere')
    $rG = Invoke-PruneMerged -Dir $dirG -IncludeRemote
    Assert-Equal 0 $rG.Code '-IncludeRemote: exit 0'
    Assert-True ($rG.Out -match 'git push origin --delete feat/landed-and-pushed') '-IncludeRemote: a provably merged head is handed over as the paste-ready command'
    Assert-True ($rG.Out -match 'Kept origin/feat/parked-elsewhere') '-IncludeRemote: and a head with neither proof is labelled Kept instead of being left to be re-derived'
    Assert-True ($rG.Out -match 'treat as live') '-IncludeRemote: with the reason, which is what replaces the hand-written do-not-sweep-this-one warning'
    Assert-True ($rG.Out -notmatch 'Kept origin/main') '-IncludeRemote: the trunk is never a candidate on the remote either'
    #     THE SAFETY PROPERTY OF THIS PASS: it hands over a command and runs none. Both heads -- the one
    #     it called deletable and the one it kept -- are still standing afterwards.
    $remoteHeadsG = @(& git -C $dirG ls-remote --heads origin | ForEach-Object { $_ }) -join ' '
    Assert-True ($remoteHeadsG -match 'feat/landed-and-pushed') '-IncludeRemote: the head it printed a delete command for is STILL on the remote -- it reports, it does not run'
    Assert-True ($remoteHeadsG -match 'feat/parked-elsewhere') '-IncludeRemote: and so is the one it kept'

    # --- (h) A clean local list does not skip the remote pass ---------------------------------------
    #     "The trunk is the only local branch" used to end the run on the spot -- and that is exactly
    #     the state in which the remote question is worth asking, since a clone that has just been
    #     tidied proves nothing whatsoever about origin. The second run below is the other half: with
    #     no switch, nothing on the remote is classified and the closing line names the switch that
    #     would. Asserted as a pair, because either one alone would pass on a script that ignored the
    #     flag entirely.
    Write-Host "prune-merged.ps1 -- a clean local list still reports the remote" -ForegroundColor Cyan
    $dirH = New-Fixture -Label 'h'
    New-MergedBranch -Dir $dirH -Name 'fix/gone-locally'
    Invoke-FixtureGit -Arguments @('-C', $dirH, 'push', '-q', 'origin', 'fix/gone-locally')
    Invoke-FixtureGit -Arguments @('-C', $dirH, 'branch', '-q', '-d', 'fix/gone-locally')
    $rH = Invoke-PruneMerged -Dir $dirH -IncludeRemote
    Assert-Equal 0 $rH.Code 'clean local: exit 0'
    Assert-True ($rH.Out -match 'Nothing to reap') 'clean local: it still says the local list is empty'
    Assert-True ($rH.Out -match 'git push origin --delete fix/gone-locally') 'clean local: AND the remote pass still runs -- the early exit does not swallow it'
    $rH2 = Invoke-PruneMerged -Dir $dirH
    Assert-True ($rH2.Out -notmatch 'git push origin --delete') 'clean local: without the switch nothing about the remote is classified'
    Assert-True ($rH2.Out -match '-IncludeRemote') 'clean local: the closing line names the switch that would classify it, rather than only the raw command'

    # --- (i) The checkout is never taken at all (issues #1071, #1147) -------------------------------
    #     Step 2 used to switch to the trunk to fast-forward it. #1071 made it hand the checkout back;
    #     #1147 removed the switch, because a borrow returned within the second is still a tree that
    #     moved under whatever else is running in the same checkout (#1145). THE ASSERT IS ON HEAD, not
    #     on the sentence: the message is what a reader gets, the ref is what the next commit obeys.
    #     The merged sibling is in the fixture on purpose -- not moving must not cost the reaping, and
    #     the reachability of the REF is the whole claim of the refspec fetch.
    #
    #     AND ON THE ABSENCE OF THE OLD LINES, which is the half a passing HEAD assert cannot prove: a
    #     script that switched and switched back would satisfy the first assert and fail these.
    Write-Host "prune-merged.ps1 -- the checkout is never taken" -ForegroundColor Cyan
    $dirI = New-Fixture -Label 'i'
    New-MergedBranch   -Dir $dirI -Name 'feat/landed-while-i-watched'
    New-UnmergedBranch -Dir $dirI -Name 'feat/where-i-was'
    Invoke-FixtureGit -Arguments @('-C', $dirI, 'checkout', '-q', 'feat/where-i-was')
    $headBeforeI = ((& git -C $dirI rev-parse HEAD) | Out-String).Trim()
    $rI = Invoke-PruneMerged -Dir $dirI
    Assert-Equal 0 $rI.Code 'no borrow: exit 0'
    Assert-Equal 'feat/where-i-was' (Get-HeadName -Dir $dirI) 'no borrow: HEAD is on the branch the run started from -- the next commit cannot land on the trunk by accident'
    Assert-True ($rI.Out -notmatch 'Switched to') 'no borrow: and it never switched, so there is no switch line'
    Assert-True ($rI.Out -notmatch 'Back on') 'no borrow: nor a hand-back line, because nothing was handed back'
    Assert-True ($rI.Out -match 'without checking it out') 'no borrow: the fast-forward says how it was done, which is the whole repair'
    Assert-True (-not ((Get-LocalBranches -Dir $dirI) -contains 'feat/landed-while-i-watched')) 'no borrow: the merged sibling is still reaped -- staying put does not cut the run short'
    #     THE TRUNK REALLY DID ADVANCE, and that is what a fetch-without-checkout has to prove: the
    #     fixture's main is already current here, so the assert that carries weight is the working
    #     tree's -- HEAD's commit is untouched, which a checkout-and-back could not leave true if it
    #     had failed halfway.
    Assert-Equal $headBeforeI (((& git -C $dirI rev-parse HEAD) | Out-String).Trim()) 'no borrow: and the commit under the working tree is the same one it started on'
    #     -DryRun moves nothing either, and never did anything else since #1147: steps 2 and 3 run in
    #     full and neither touches a tree.
    $rI2 = Invoke-PruneMerged -Dir $dirI -DryRun
    Assert-Equal 'feat/where-i-was' (Get-HeadName -Dir $dirI) 'no borrow: -DryRun stays put too'

    # --- (j) The one move that survives, and it says why -------------------------------------------
    #     A branch this same run REAPS -- step 4c, and since #1147 the ONLY thing in this script that
    #     moves a working tree. `git branch -d` cannot touch the branch HEAD is on, so a merged start
    #     branch is reapable only if the run steps off it first; it is not a borrow, because there is
    #     nothing to return to once the branch is gone. The asserts are that it happens, that it says
    #     so BEFORE it happens, and that the closing line names the sha -- the whole of what makes that
    #     position recoverable.
    Write-Host "prune-merged.ps1 -- the start branch this run reaped" -ForegroundColor Cyan
    $dirJ = New-Fixture -Label 'j'
    New-MergedBranch -Dir $dirJ -Name 'feat/finished-here'
    $shaJ = ((& git -C $dirJ rev-parse --short 'feat/finished-here') | Out-String).Trim()
    Invoke-FixtureGit -Arguments @('-C', $dirJ, 'checkout', '-q', 'feat/finished-here')
    $rJ = Invoke-PruneMerged -Dir $dirJ
    Assert-Equal 0 $rJ.Code 'reaped start: exit 0'
    Assert-Equal 'main' (Get-HeadName -Dir $dirJ) 'reaped start: the run ends on the trunk, because there is no longer a branch to end on'
    Assert-True (-not ((Get-LocalBranches -Dir $dirJ) -contains 'feat/finished-here')) 'reaped start: and it was still reaped -- standing on a merged branch does not save it'
    Assert-True ($rJ.Out -match 'Stepped off') 'reaped start: the move is announced where it happens, not inferred from the closing line'
    Assert-True ($rJ.Out -match 'was reaped by this run') 'reaped start: the closing line says WHY it did not go back, rather than ending in silence'
    Assert-True ($rJ.Out -match [regex]::Escape($shaJ)) 'reaped start: and names the sha it left, which is the whole of what makes that position recoverable'
    #     AND THE LOOK-FIRST RUN DOES NOT DO IT. Same fixture shape, -DryRun: the branch is reported
    #     reapable and the caller is still standing on it afterwards. Without this, a dry run that
    #     stepped off would be the #1071 defect wearing a safer name.
    $dirJ2 = New-Fixture -Label 'j2'
    New-MergedBranch -Dir $dirJ2 -Name 'feat/finished-here-too'
    Invoke-FixtureGit -Arguments @('-C', $dirJ2, 'checkout', '-q', 'feat/finished-here-too')
    $rJ2 = Invoke-PruneMerged -Dir $dirJ2 -DryRun
    Assert-Equal 'feat/finished-here-too' (Get-HeadName -Dir $dirJ2) 'reaped start: -DryRun never steps off -- it deletes nothing, so it has no reason to move HEAD'
    Assert-True ($rJ2.Out -match 'Would delete feat/finished-here-too') 'reaped start: and it still reports the branch as reapable'
    Assert-True ($rJ2.Out -notmatch 'Stepped off') 'reaped start: with no step-off line, because there was none'

    # --- (k) A run started on the trunk cannot fetch into its own ref --------------------------------
    #     The trunk IS checked out here, so the refspec fetch of step 2 is the one form git refuses;
    #     this run takes `git pull --ff-only` instead, which moves nothing either -- it advances the
    #     branch you are already on to a commit the remote has already published. Worth an assert
    #     because the cheapest wrong implementation is one that fetches into the checked-out ref and
    #     turns the whole run into a warning.
    Write-Host "prune-merged.ps1 -- started on the trunk" -ForegroundColor Cyan
    $dirK = New-Fixture -Label 'k'
    New-UnmergedBranch -Dir $dirK -Name 'feat/somebody-elses'
    $rK = Invoke-PruneMerged -Dir $dirK
    Assert-Equal 'main' (Get-HeadName -Dir $dirK) 'trunk start: still on the trunk'
    Assert-True ($rK.Out -match "Fast-forwarded 'main'") 'trunk start: the fast-forward SUCCEEDED -- the pull path, not a refused fetch into the checked-out ref'
    Assert-True ($rK.Out -notmatch 'could not be fast-forwarded') 'trunk start: so there is no warning about it'
    Assert-True ($rK.Out -notmatch 'without checking it out') 'trunk start: and it does not claim the fetch form it did not use'
    Assert-True ($rK.Out -notmatch 'Back on') 'trunk start: nothing to hand back'
    Assert-True ($rK.Out -notmatch 'Stepped off') 'trunk start: and nothing to step off -- the trunk is never a candidate'

    # --- (l) A detached start is simply left alone --------------------------------------------------
    #     Before #1147 step 2 moved a detached HEAD onto the trunk and could not put it back, so the
    #     run had to name the sha it had left. Nothing moves it now: there is no borrow, and a detached
    #     HEAD is not a branch this run can be asked to reap. The assert is that the position survives
    #     the run untouched, which is stronger than the sentence it replaces.
    Write-Host "prune-merged.ps1 -- started detached" -ForegroundColor Cyan
    $dirL = New-Fixture -Label 'l'
    New-UnmergedBranch -Dir $dirL -Name 'feat/not-where-i-am'
    $shaL = ((& git -C $dirL rev-parse HEAD) | Out-String).Trim()
    Invoke-FixtureGit -Arguments @('-C', $dirL, 'checkout', '-q', '--detach', 'HEAD')
    $rL = Invoke-PruneMerged -Dir $dirL
    Assert-Equal 0 $rL.Code 'detached start: exit 0'
    Assert-Equal 'HEAD' (Get-HeadName -Dir $dirL) 'detached start: STILL detached -- the run does not hand it a branch it never asked for'
    Assert-Equal $shaL (((& git -C $dirL rev-parse HEAD) | Out-String).Trim()) 'detached start: on the same commit, because nothing moved it'
    Assert-True ($rL.Out -notmatch 'Switched to') 'detached start: and it says nothing about a move it did not make'

    # --- (m) The closing line is structural, not a habit --------------------------------------------
    #     Every path out of the script below the step-3 marker goes through Complete-Run, so a path
    #     added later cannot forget it -- the failure mode of the original defect exactly, where the
    #     information to return was present and simply never used. Step 1 keeps its own bare exits on
    #     purpose: nothing has moved yet there, and a refusal must leave the caller where it found
    #     them. Asserted on the source rather than by driving every one of those paths, because what is
    #     being tested is that no FUTURE path can miss it.
    Write-Host "prune-merged.ps1 -- no exit below step 3 skips the closing line" -ForegroundColor Cyan
    $srcLines = [System.IO.File]::ReadAllLines($PruneMergedSrc)
    $step3 = 0
    for ($i = 0; $i -lt $srcLines.Count; $i++) { if ($srcLines[$i] -match '^# --- 3\. ') { $step3 = $i; break } }
    Assert-True ($step3 -gt 0) 'structural: the step-3 marker this assert is anchored on is still in the source'
    $bareExits = @(for ($i = $step3; $i -lt $srcLines.Count; $i++) { if ($srcLines[$i] -match '^\s*exit\b') { "line $($i + 1): $($srcLines[$i].Trim())" } })
    Assert-Equal 0 $bareExits.Count "structural: no bare 'exit' below the step-3 marker -- every path out goes through Complete-Run$(if ($bareExits.Count) { " (found: $($bareExits -join '; '))" })"

    # --- (n) The fast-forward takes no checkout, structurally (issue #1147) -------------------------
    #     Case (i) proves the RUN leaves HEAD alone; this proves the SOURCE cannot take it back. Step 2
    #     is the block between its own marker and step 3's, and a `git checkout` written anywhere in it
    #     is the defect returning -- a borrow handed back within the second still moves the tree under a
    #     concurrent gate (#1145), which is exactly the behaviour a fixture assert on the final HEAD
    #     cannot distinguish from no borrow at all. Matched on the quoted argument form, the shape a
    #     git call actually takes here, so the prose above and below step 2 is not a finding.
    Write-Host "prune-merged.ps1 -- step 2 contains no checkout" -ForegroundColor Cyan
    $step2 = 0
    for ($i = 0; $i -lt $srcLines.Count; $i++) { if ($srcLines[$i] -match '^# --- 2\. ') { $step2 = $i; break } }
    Assert-True ($step2 -gt 0 -and $step2 -lt $step3) 'structural: the step-2 marker is still in the source, above step 3'
    $step2Checkouts = @(for ($i = $step2; $i -lt $step3; $i++) { if ($srcLines[$i] -match "'checkout'") { "line $($i + 1): $($srcLines[$i].Trim())" } })
    Assert-Equal 0 $step2Checkouts.Count "structural: step 2 makes no 'checkout' call -- the trunk is advanced by refspec fetch, never borrowed$(if ($step2Checkouts.Count) { " (found: $($step2Checkouts -join '; '))" })"

    # --- (o) A RECYCLED BRANCH NAME DOES NOT INHERIT THE PREVIOUS BRANCH'S MERGE (inbound #1191) ----
    #     The defect this suite could not see. Everything above runs without gh, so proof (b) was never
    #     established in a fixture at all -- and proof (b) matching on the NAME is the whole bug: a name
    #     freed by deleteBranchOnMerge and used again carried the first branch's merge, and `-D` took
    #     the second branch's unmerged work with the word `merged PR` printed beside it.
    #
    #     THE STUB IS WHAT MAKES THIS TESTABLE, and (p) below is what keeps it honest: a stub that
    #     silently failed would make THIS case pass for the wrong reason -- no gh, no proof, branch
    #     kept. (p) is the same stub proving a REAL merge, so the pair can only both pass if gh is
    #     genuinely answering and the name-and-tip test is genuinely being applied.
    Write-Host "prune-merged.ps1 -- a recycled name does not inherit the old branch's merge" -ForegroundColor Cyan
    $dirO = New-Fixture -Label 'o'
    New-UnmergedBranch -Dir $dirO -Name 'sync/live-2026-09-01'
    #     The sha of the PR that merged under this name BEFORE it was recycled. Any commit that is not
    #     this branch's tip states the case; a literal one states it unmistakably.
    $rO = Invoke-PruneMerged -Dir $dirO -GhStubDir (New-GhStub -Dir $dirO -Rows @(
        @{ Name = 'sync/live-2026-09-01'; Oid = '0123456789abcdef0123456789abcdef01234567' }))
    Assert-Equal 0 $rO.Code 'recycled: exit 0'
    Assert-True ((Get-LocalBranches -Dir $dirO) -contains 'sync/live-2026-09-01') 'recycled: THE BRANCH SURVIVES -- its name was merged once, its commits never were'
    Assert-True ($rO.Out -notmatch 'Deleted sync/live-2026-09-01') 'recycled: and nothing claims to have deleted it'
    Assert-True ($rO.Out -match 'Kept sync/live-2026-09-01') 'recycled: it is reported kept, like any other unproven branch'
    Assert-True ($rO.Out -match 'used this name, but not this commit') 'recycled: the reason names what was measured -- the lookup came up FULL, this commit was not in it'
    Assert-True ($rO.Out -match 'no proof for this tip \(a recycled name, or a commit added') 'recycled: and offers the causes without asserting one (issue #1296)'

    # --- (p) A GENUINE squash merge is still proven -- by the head commit (inbound #1191) -----------
    #     The other direction, and the reason (b) exists at all: a branch whose tip is deliberately not
    #     in the trunk's history, which ancestry can therefore never prove. The name-and-tip test must
    #     still delete it, or the repair for (o) would have cost the script its whole squash case.
    Write-Host "prune-merged.ps1 -- a real squash merge is still proven by its head commit" -ForegroundColor Cyan
    $dirP = New-Fixture -Label 'p'
    New-UnmergedBranch -Dir $dirP -Name 'feat/squashed'
    $tipP = Get-BranchTip -Dir $dirP -Name 'feat/squashed'
    $rP = Invoke-PruneMerged -Dir $dirP -GhStubDir (New-GhStub -Dir $dirP -Rows @(
        @{ Name = 'feat/squashed'; Oid = $tipP }))
    Assert-Equal 0 $rP.Code 'squash: exit 0'
    Assert-True (-not ((Get-LocalBranches -Dir $dirP) -contains 'feat/squashed')) 'squash: the branch IS deleted -- the merged PR is the proof that replaces ancestry'
    Assert-True ($rP.Out -match 'Deleted feat/squashed') 'squash: and the run names what it deleted'
    Assert-True ($rP.Out -match 'merged PR') 'squash: with the proof it deleted on'

    # --- (q) The remote pass applies the same proof -- where it matters most (inbound #1191) --------
    #     This pass hands over `git push origin --delete`, and origin is the copy of last resort: the
    #     local pass at worst discards commits the remote still holds, while a wrong line here reaches
    #     the only copy there is. Both heads exist ONLY on the remote, which is the shape of a parked
    #     branch, and they differ in one thing -- whether the merged PR's head commit is theirs.
    Write-Host "prune-merged.ps1 -- -IncludeRemote applies the name+tip proof too" -ForegroundColor Cyan
    $dirQ = New-Fixture -Label 'q'
    New-UnmergedBranch -Dir $dirQ -Name 'sync/live-recycled'
    New-UnmergedBranch -Dir $dirQ -Name 'sync/live-finished'
    $tipQ = Get-BranchTip -Dir $dirQ -Name 'sync/live-finished'
    Invoke-FixtureGit -Arguments @('-C', $dirQ, 'push', '-q', 'origin', 'sync/live-recycled')
    Invoke-FixtureGit -Arguments @('-C', $dirQ, 'push', '-q', 'origin', 'sync/live-finished')
    Invoke-FixtureGit -Arguments @('-C', $dirQ, 'branch', '-q', '-D', 'sync/live-recycled')
    Invoke-FixtureGit -Arguments @('-C', $dirQ, 'branch', '-q', '-D', 'sync/live-finished')
    $rQ = Invoke-PruneMerged -Dir $dirQ -IncludeRemote -GhStubDir (New-GhStub -Dir $dirQ -Rows @(
        @{ Name = 'sync/live-recycled'; Oid = '0123456789abcdef0123456789abcdef01234567' },
        @{ Name = 'sync/live-finished'; Oid = $tipQ }))
    Assert-Equal 0 $rQ.Code '-IncludeRemote recycled: exit 0'
    Assert-True ($rQ.Out -notmatch 'git push origin --delete sync/live-recycled') '-IncludeRemote recycled: NO delete command for a head whose name was merged but whose commit was not'
    Assert-True ($rQ.Out -match 'Kept origin/sync/live-recycled') '-IncludeRemote recycled: it is labelled kept instead'
    Assert-True ($rQ.Out -match 'used this name, but not this commit') '-IncludeRemote recycled: with the reason, so the reader is not left to re-derive it'
    Assert-True ($rQ.Out -match 'no proof for this tip') '-IncludeRemote recycled: and it names the measurement, not "live work" -- a post-merge commit lands here too (issue #1296)'
    Assert-True ($rQ.Out -match 'git push origin --delete sync/live-finished') '-IncludeRemote recycled: and the head that IS proven still gets its paste-ready command -- the pass is not simply refusing everything'

    # --- (r) The proof is the shared lib's, not a second copy of it (issue #1194) --------------------
    #     ASSERTED STRUCTURALLY, because nothing above can see the difference. Every case (o) to (q)
    #     passed with the private copy too -- the divergence was the ORDINAL comparer, and reproducing
    #     it needs two branch names differing only in case, which a fixture on Windows cannot reliably
    #     create as two loose refs. So the behaviour is unit-tested where it is pure
    #     (merged-pr-lib.tests.ps1) and what is pinned here is that this script routes into it: a bare
    #     '@{}' coming back is exactly how the two copies drifted apart the first time, silently and
    #     with every existing assert still green.
    Write-Host "prune-merged.ps1 -- the merged-PR proof comes from the shared lib" -ForegroundColor Cyan
    $srcR = [System.IO.File]::ReadAllText($PruneMergedSrc)
    Assert-True ($srcR -match [regex]::Escape("'..\lib\merged-pr-lib.ps1'")) `
        'shared: the lib carrying the proof is dot-sourced'
    Assert-True ($srcR -match [regex]::Escape('$mergedTips = Get-MergedPrTips')) `
        'shared: and the map is built by it, not by a hashtable literal this script keys itself'
    Assert-True ($srcR -notmatch [regex]::Escape('$mergedTips = @{}')) `
        'shared: the bare @{} -- whose comparer is case-insensitive, which is how the two copies diverged -- is gone'
    Assert-True ($srcR -match [regex]::Escape('Test-RefMergedByPr -Name $Branch -Tip $Tip -MergedTips $mergedTips')) `
        'shared: the proof itself is the lib''s two-part test'
    Assert-True ($srcR -match [regex]::Escape('Test-MergedPrNameKnown -Name $Branch -MergedTips $mergedTips')) `
        'shared: and so is the middle answer that earns the recycled-name sentence'
} finally {
    foreach ($f in $script:fixtures) {
        if ($f -and (Test-Path -LiteralPath $f)) { Remove-Item -Recurse -Force -LiteralPath $f -ErrorAction SilentlyContinue }
    }
}

Write-Host ""
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
# assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
$fixtureBroken = Write-FixtureGitSummary -Subject 'prune-merged.ps1'
if ($script:fail -gt 0) {
    Write-Host "Result: $($script:pass) pass, $($script:fail) fail." -ForegroundColor Red
    exit 1
}
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
Write-Host "Result: $($script:pass) pass, 0 fail." -ForegroundColor Green
exit 0
