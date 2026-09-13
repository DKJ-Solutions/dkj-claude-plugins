<#
.SYNOPSIS
    Regression tests for scripts/task/park-branch.ps1 (commit all outstanding work + push -u to
    origin, no PR, refuse on main).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Integration style -- runs the REAL script
    (copied into a throwaway temp git repo with a bare 'origin', so the commit/push mutations never
    touch the own working copy or a real remote) and asserts on exit code + output + git state.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/park-branch.tests.ps1

    park-branch.ps1 itself calls 'exit', so it is run here as a CHILD PROCESS (powershell -File).
    Its git commands already run under ErrorActionPreference=Continue themselves (the #107 pitfall,
    via the shared Invoke-NativeCapture) -- this test script mirrors the same caution around ITS OWN
    git fixture calls.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot         = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
# AND ITS RUNTIME SIBLING -- issue #1934. fixture-git-lib judges the calls that BUILD the fixture; this
# one judges the child that RUNS in it. A child that dies during load never reaches its first statement,
# so what the asserts below report is the absence of a document nothing wrote -- naming the missing lib
# not at all, while the child's own output named it all along.
. (Join-Path $PSScriptRoot '..\lib\fixture-script-lib.ps1')
$ParkBranchSrc    = Join-Path $RepoRoot 'scripts\task\park-branch.ps1'
# park-branch dot-sources this sibling shared lib for every git call (the #107 stderr guard), so the
# fixture must carry it too.
$NativeCaptureSrc = Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1'
# And the shared park implementation itself since #507 -- park-branch is now the thin entry point and
# Invoke-GitPark does the work, so a fixture without this file has no script at all.
$ParkLibSrc       = Join-Path $RepoRoot 'scripts\lib\park-lib.ps1'
# park-lib dot-sources this one (#1682), guarded -- so a fixture that omits it loses Get-GitParkBacking
# silently rather than crashing. park-cycle.tests.ps1 is where that cost ten asserts.
$PorcelainSrc     = Join-Path $RepoRoot 'scripts\lib\git-porcelain-lib.ps1'

$script:pass = 0
$script:fail = 0

function Get-FlatOutput {
    <#
        Captured child output with the line breaks REMOVED, so a phrase assert cannot fail on a wrap
        point that park-branch.ps1 does not decide. A native child's stderr captured with 2>&1 arrives
        as a NativeCommandError, which PowerShell renders with a 'powershell.exe : ' prefix and WRAPS at
        the host width -- so the wrap point moves with the console width and with the length of the
        fixture's temp path, neither of which park-branch.ps1 decides.

        Applied here for the same reason it was applied to new-branch.tests.ps1 on August 3, 2026, where
        a 176-column window split "must not be 'main'" MID-WORD and failed an assert about correct
        behaviour. This suite's own asserts sit in exactly the same records and are one window width
        away from the same failure.

        THE SUMMARY LINE ABOVE SAID "collapsed to single spaces" UNTIL #1736, and the code below removes
        the break outright. The two are opposite repairs, so that was not a wording slip: collapsing to a
        space is the ONE variant in this tree measured to fail, and the docstring named this suite as
        using it.

        MEASURED, September 9, 2026, over 120 wrap positions x 4 phrases (480 checks per variant), by
        padding a Write-Error until its break swept every column of a 120-wide render:

          * `-replace "`r?`n", ' '` (collapse):  68 of 480 fail -- e.g. 'dirty working tre e'
          * `-replace "`r?`n", ''`  (this one):   0 of 480 fail
          * no flattening at all:                68 of 480 fail

        So this field is not currently letting anything through, and the conversion below is NOT a bug
        fix. What it buys is that the immunity stops being incidental: joining with '' survives a
        mid-word break by reconstruction, and survives a break on a space only because PowerShell keeps
        that space at the end of the line it wrapped -- a property of the renderer, not of this helper.
        Assert-Says strips ALL whitespace from both sides and is immune by construction either way. This
        field stays because a FAILING assert still has to print one readable line -- the same division
        park-cycle.tests.ps1 draws.
    #>
    param($Captured)
    return (($Captured | Out-String) -replace "`r?`n", '')
}

function Test-Says {
    <# Does captured child output contain this phrase, whatever the console did to it?

       WHICH ASSERTS NEED IT is decided by the stream the phrase comes out of, not by its wording --
       that is #1736's classification, and it is the half of this that is worth keeping whatever the
       flattener does. Invoke-Script below captures the child with 2>&1, so its ERROR stream is in .Out,
       and a throw, a Write-Error or a Write-Warning reaches a capture through PowerShell's error
       formatter, which hard-wraps INSIDE a word. Write-Host does not go through it at all, which is why
       'parked on origin' and 'nothing new to commit' below keep -match: they are park-lib's Write-Host
       lines and cannot wrap, so routing them through here would assert less than -match does, not more.

       Only three asserts in this file read the formatter, and all three are on refusals: the main-branch
       pointer, and the two on the push-failure message park-lib composes.

       Strips ALL whitespace from both sides -- see the measurement in Get-FlatOutput above. Literal
       (IndexOf), so a phrase carrying '(', ')' or '[' needs no escaping; OrdinalIgnoreCase keeps the
       case-insensitivity that -match had at these call sites. #>
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
    <# The NEGATIVE direction, and the one that fails silently rather than loudly: a bare -notmatch
       reports absence and has measured a line break, so it goes GREEN for the wrong reason and no run
       ever shows it. That is why it gets a helper of its own instead of a `-not (Test-Says ...)` at the
       call site -- the shape has to be as easy to reach for as the positive one. #>
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

function New-Fixture {
    <#
        A fresh throwaway git repo with park-branch.ps1 + native-capture-lib.ps1 copied in, an
        initial commit on a base branch 'main', and a bare repo wired up as 'origin' so the push has
        somewhere to land (no auth/network needed). Returns the working repo path; the bare origin
        path is $dir + '.git' and is tracked for cleanup.
    #>
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("park-branch-test-$PID-$Label-$([guid]::NewGuid().ToString('n'))")
    if (Test-Path -LiteralPath $dir) { Remove-Item -Recurse -Force -LiteralPath $dir }
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\task') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\lib')  -Force | Out-Null
    Copy-Item -LiteralPath $ParkBranchSrc    -Destination (Join-Path $dir 'scripts\task\park-branch.ps1')        -Force
    Copy-Item -LiteralPath $NativeCaptureSrc -Destination (Join-Path $dir 'scripts\lib\native-capture-lib.ps1')  -Force
    # command-probe-lib.ps1 is a sibling of a sibling (#1729): the three libs above dot-source it for
    # Test-FunctionDefined, so the fixture owes it exactly as it owes ref-print-lib.
    # check-report-lib.ps1 likewise (#1917): the script under test resolves its repo root through
    # Resolve-RepoRootOrFail, which lives there -- so the fixture owes it too. UNGUARDED in the script,
    # deliberately: it is the first statement that runs, and a guarded load would have to fall back to
    # the very unjudged .Trim() this repair removes.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\check-report-lib.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\command-probe-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\command-probe-lib.ps1') -Force
    Copy-Item -LiteralPath $ParkLibSrc       -Destination (Join-Path $dir 'scripts\lib\park-lib.ps1')            -Force
    Copy-Item -LiteralPath $PorcelainSrc     -Destination (Join-Path $dir 'scripts\lib\git-porcelain-lib.ps1')   -Force

    $bareRemote = "$dir.git"
    if (Test-Path -LiteralPath $bareRemote) { Remove-Item -Recurse -Force -LiteralPath $bareRemote }

    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $dir init -q
        Invoke-FixtureGitIn $dir config user.email 'tycho-tests@local.invalid'
        Invoke-FixtureGitIn $dir config user.name 'Tycho Tests'
        # gpgsign off: a locked signing agent must not fail a fixture commit for a reason unrelated to the test (#1287).
        Invoke-FixtureGitIn $dir config commit.gpgsign false
        # symbolic-ref instead of checkout -b: works on a still-unborn HEAD regardless of git's own
        # init.defaultBranch setting, and gives no error if HEAD happens to already be named 'main'.
        Invoke-FixtureGitIn $dir symbolic-ref HEAD refs/heads/main
        [System.IO.File]::WriteAllText((Join-Path $dir 'README.md'), "# fixture`n", (New-Object System.Text.UTF8Encoding $false))
        Invoke-FixtureGitIn $dir add -A
        Invoke-FixtureGitIn $dir commit -q -m 'init'
        Invoke-FixtureGitJudged @('init', '--bare', '-q', $bareRemote)
        Invoke-FixtureGitIn $dir remote add origin $bareRemote
    } finally {
        $ErrorActionPreference = $prevEap
    }
    $script:fixtures += $dir
    $script:fixtures += $bareRemote
    return $dir
}

function Invoke-ParkBranch {
    <#
        Runs the fixture copy of park-branch.ps1 as a child process, with the fixture folder as cwd
        (so the dual-context fallback `git rev-parse --show-toplevel` lands there) and without
        CLAUDE_PROJECT_DIR from an earlier test run. EAP=Continue around the call -- the same caution
        as new-branch.tests.ps1 (native stderr under EAP=Stop would otherwise become terminating here).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [string]$Intent
    )
    $scriptPath = Join-Path $Dir 'scripts\task\park-branch.ps1'
    $callArgs = @()
    if ($PSBoundParameters.ContainsKey('Intent')) { $callArgs += @('-Intent', $Intent) }

    $prevPd  = $env:CLAUDE_PROJECT_DIR
    $prevEap = $ErrorActionPreference
    $prevLoc = (Get-Location).Path
    try {
        Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
        Set-Location -LiteralPath $Dir
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @callArgs 2>&1
        $code = $LASTEXITCODE
        # #1934: a load failure here is not a refusal -- say so before the asserts read a document nothing wrote.
        Assert-FixtureScriptLoaded -Code $code -Script $scriptPath -Output $out
        return [pscustomobject]@{ Code = $code; Out = (Get-FlatOutput $out) }
    } finally {
        $ErrorActionPreference = $prevEap
        Set-Location -LiteralPath $prevLoc
        if ($null -eq $prevPd) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prevPd }
    }
}

function Get-CommitCount {
    param([Parameter(Mandatory = $true)][string]$Dir)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        return @(& git -C $Dir log --oneline).Count
    } finally { $ErrorActionPreference = $prevEap }
}

function Checkout-NewBranch {
    param([Parameter(Mandatory = $true)][string]$Dir, [Parameter(Mandatory = $true)][string]$Name)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $Dir checkout -q -b $Name
    } finally { $ErrorActionPreference = $prevEap }
}

try {
    # --- (a) Guardrail: refuses on main (exit 1), no commit, no push --------------------------------
    Write-Host "park-branch.ps1 -- refuses on main (exit 1)" -ForegroundColor Cyan
    $fixtureA = New-Fixture -Label 'a'
    $rMain = Invoke-ParkBranch -Dir $fixtureA
    Assert-Equal 1 $rMain.Code "on main: exit 1 (guardrail)"
    Assert-Says $rMain.Out 'on main' "on main: pointer names the main rule"
    Assert-Equal 1 (Get-CommitCount -Dir $fixtureA) "on main: no commit added"
    & git -C "$fixtureA.git" rev-parse --verify --quiet 'refs/heads/main' | Out-Null
    Assert-True ($LASTEXITCODE -ne 0) "on main: nothing pushed to origin"

    # --- (b) Commit ALL outstanding work + push -u, no PR ------------------------------------------
    Write-Host "park-branch.ps1 -- commits all outstanding work and pushes to origin" -ForegroundColor Cyan
    $fixtureB = New-Fixture -Label 'b'
    Checkout-NewBranch -Dir $fixtureB -Name 'feat/wip'
    # A mix of outstanding work: a modified tracked file, a staged new file, and an untracked file.
    [System.IO.File]::WriteAllText((Join-Path $fixtureB 'README.md'), "# fixture edited`n", (New-Object System.Text.UTF8Encoding $false))
    [System.IO.File]::WriteAllText((Join-Path $fixtureB 'staged.txt'), "staged`n", (New-Object System.Text.UTF8Encoding $false))
    $prevEap = $ErrorActionPreference
    try { $ErrorActionPreference = 'Continue'; Invoke-FixtureGitIn $fixtureB add -- 'staged.txt' } finally { $ErrorActionPreference = $prevEap }
    [System.IO.File]::WriteAllText((Join-Path $fixtureB 'untracked.txt'), "untracked`n", (New-Object System.Text.UTF8Encoding $false))

    $rB = Invoke-ParkBranch -Dir $fixtureB
    Assert-Equal 0 $rB.Code 'park: exit 0'
    Assert-True ($rB.Out -match 'parked on origin') 'park: reports the branch was parked on origin'
    # working tree fully clean -- nothing left behind
    $statusB = ((& git -C $fixtureB status --porcelain) -join "`n")
    Assert-True ([string]::IsNullOrWhiteSpace($statusB)) 'park: working tree clean after park (all work committed)'
    Assert-Equal 2 (Get-CommitCount -Dir $fixtureB) 'park: exactly one park commit on top of the initial commit'
    # the park commit contains every outstanding file
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $parkFiles = @(& git -C $fixtureB diff-tree --no-commit-id --name-only -r HEAD 2>$null)
    } finally { $ErrorActionPreference = $prevEap }
    Assert-True ($parkFiles -contains 'README.md')    'park: modified tracked file in the park commit'
    Assert-True ($parkFiles -contains 'staged.txt')   'park: staged new file in the park commit'
    Assert-True ($parkFiles -contains 'untracked.txt') 'park: untracked file swept into the park commit (add -A)'
    # pushed + upstream tracking set
    & git -C "$fixtureB.git" rev-parse --verify --quiet 'refs/heads/feat/wip' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) 'park: branch ref present on origin (pushed)'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $upstream = ((& git -C $fixtureB rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null) | Out-String).Trim()
    } finally { $ErrorActionPreference = $prevEap }
    Assert-Equal 'origin/feat/wip' $upstream 'park: upstream tracking set to origin/<branch>'

    # --- (c) Already committed locally but not pushed: no new commit, still pushes ------------------
    Write-Host "park-branch.ps1 -- already committed locally, not pushed: pushes as-is" -ForegroundColor Cyan
    $fixtureC = New-Fixture -Label 'c'
    Checkout-NewBranch -Dir $fixtureC -Name 'feat/committed'
    [System.IO.File]::WriteAllText((Join-Path $fixtureC 'work.txt'), "done`n", (New-Object System.Text.UTF8Encoding $false))
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Invoke-FixtureGitIn $fixtureC add -A
        Invoke-FixtureGitIn $fixtureC commit -q -m 'local work'
    } finally { $ErrorActionPreference = $prevEap }
    $countBeforeC = Get-CommitCount -Dir $fixtureC

    $rC = Invoke-ParkBranch -Dir $fixtureC
    Assert-Equal 0 $rC.Code 'park (already committed): exit 0'
    Assert-True ($rC.Out -match 'nothing new to commit') 'park (already committed): reports nothing new to commit'
    Assert-Equal $countBeforeC (Get-CommitCount -Dir $fixtureC) 'park (already committed): no extra commit created'
    & git -C "$fixtureC.git" rev-parse --verify --quiet 'refs/heads/feat/committed' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) 'park (already committed): branch still pushed to origin'

    # --- (d) -Intent recorded in the park commit message ------------------------------------------
    Write-Host "park-branch.ps1 -- -Intent recorded in the park commit message" -ForegroundColor Cyan
    $fixtureD = New-Fixture -Label 'd'
    Checkout-NewBranch -Dir $fixtureD -Name 'feat/intent'
    [System.IO.File]::WriteAllText((Join-Path $fixtureD 'wip.txt'), "wip`n", (New-Object System.Text.UTF8Encoding $false))
    $intentText = 'Skeleton done; next: wire the API client.'
    $rD = Invoke-ParkBranch -Dir $fixtureD -Intent $intentText
    Assert-Equal 0 $rD.Code '-Intent: exit 0'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lastMsg = ((& git -C $fixtureD log -1 --pretty=%B 2>$null) | Out-String)
    } finally { $ErrorActionPreference = $prevEap }
    Assert-True ($lastMsg -match [regex]::Escape('park: feat/intent')) '-Intent: park commit still carries the park subject'
    Assert-True ($lastMsg -match [regex]::Escape($intentText)) '-Intent: the intent text is recorded in the commit body'

    # --- (d2) The subject NAMES THE SCOPE (#507) ----------------------------------------------------
    # THE DEFECT THIS SUITE COULD NOT SEE. Both parking entry points wrote the identical subject --
    # `park: <branch> (work parked for later)` -- while committing different things, so a reader could not
    # tell afterwards whether only the two branch files or everything outstanding had reached origin.
    # Nothing here asserted the subject beyond the branch name, which is why the drift survived a suite
    # that otherwise checks this script closely. The phrase is read from the lib rather than retyped, so
    # rewording a scope stays a one-place change and this assert cannot quietly stop matching.
    . (Join-Path $RepoRoot 'scripts\lib\park-lib.ps1')
    $scopes = Get-GitParkScopes
    Assert-True ($lastMsg -match [regex]::Escape($scopes['Everything'])) '-Intent: the subject names the scope that was committed (everything outstanding)'
    Assert-True (-not ($lastMsg -match [regex]::Escape($scopes['BranchFiles']))) 'and does not claim the narrower scope it did not use'
    Assert-True ($scopes['Everything'] -ne $scopes['BranchFiles']) 'the two scopes are told apart by their words -- the whole point of #507'

    # --- (d3) A REJECTED PUSH IS REPORTED AS A REJECTED PUSH (#1143) --------------------------------
    # THE DEFECT: Invoke-GitPark wrote one fixed sentence over every failed push -- "is 'origin'
    # configured and reachable?" -- which was the right question while park-branch.ps1 was the only
    # caller. Since #900 the push is what new-branch does on every creation and cycle-autopark on every
    # Stop, so the common failure is a non-fast-forward against a branch already on origin, and the
    # summary sent the reader to check `git remote -v` for nothing. Nothing here could see it: the suite
    # only ever staged pushes that SUCCEED.
    #
    # The fixture diverges with `git commit --amend` rather than a reset: it rewrites the local tip so it
    # is no longer a descendant of what origin holds, which is the same rejection with none of the
    # destructive shape.
    Write-Host "park-branch.ps1 -- a rejected push says so, and does not blame the remote" -ForegroundColor Cyan
    $fixtureE = New-Fixture -Label 'e'
    Checkout-NewBranch -Dir $fixtureE -Name 'fix/diverged'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        [System.IO.File]::WriteAllText((Join-Path $fixtureE 'first.txt'), "one`n", (New-Object System.Text.UTF8Encoding $false))
        Invoke-FixtureGitIn $fixtureE add -A
        Invoke-FixtureGitIn $fixtureE commit -q -m 'first'
        Invoke-FixtureGitIn $fixtureE push -q -u origin 'fix/diverged'
        # Rewrite the tip that origin already has: local and origin now share no descendant line.
        Invoke-FixtureGitIn $fixtureE commit -q --amend -m 'first (rewritten)'
    } finally { $ErrorActionPreference = $prevEap }
    # Something outstanding, so park reaches the push through its normal commit path rather than the
    # nothing-to-commit shortcut.
    [System.IO.File]::WriteAllText((Join-Path $fixtureE 'second.txt'), "two`n", (New-Object System.Text.UTF8Encoding $false))
    $rNff = Invoke-ParkBranch -Dir $fixtureE
    Assert-Equal 1 $rNff.Code 'rejected push: exit 1 (the caller still stops)'
    # Both read the Write-Error that park-lib's Get-GitPushFailureMessage composes, so both go through
    # the formatter. The second one is the direction that fails silently: as a -notmatch it reported
    # absence and would have measured a line break.
    Assert-Says $rNff.Out 'origin already has commits this branch does not' 'rejected push: the summary names the real cause'
    Assert-DoesNotSay $rNff.Out 'configured and reachable' 'rejected push: and does not send the reader to check the remote'

    # And the three arms from their own text, so a reworded message is a one-place change here too --
    # asserted on the function rather than by staging three different remote failures.
    . (Join-Path $RepoRoot 'scripts\lib\park-lib.ps1')
    $mReject = Get-GitPushFailureMessage -Output " ! [rejected]        fix/x -> fix/x (non-fast-forward)"
    $mUnreach = Get-GitPushFailureMessage -Output "fatal: 'origin' does not appear to be a git repository"
    $mUnknown = Get-GitPushFailureMessage -Output "error: something nobody has classified yet"
    Assert-True ($mReject -match 'rejected')                  'message arms: a non-fast-forward reads as a rejection'
    Assert-True ($mUnreach -match 'could not be reached')     'message arms: an unusable remote still reads as a remote problem'
    Assert-True ($mUnknown -match "git's own output is above") 'message arms: an unrecognised failure names no cause at all'
    Assert-True (($mReject -ne $mUnreach) -and ($mUnreach -ne $mUnknown)) 'message arms: the three are told apart -- the whole point of #1143'

    # --- (e) No PR interaction: park never invokes gh / opens a PR ---------------------------------
    Write-Host "park-branch.ps1 -- no PR is opened" -ForegroundColor Cyan
    # (b) already proved a full push; here we assert the source itself carries no PR/gh path, so a
    # future edit cannot silently turn park into a PR opener.
    $srcText = [System.IO.File]::ReadAllText($ParkBranchSrc, [System.Text.Encoding]::UTF8)
    Assert-True (-not ($srcText -match '(?m)^\s*[^#]*\bgh\b')) 'park: source contains no active gh/PR call'
} finally {
    foreach ($f in $script:fixtures) {
        if (Test-Path -LiteralPath $f) { Remove-Item -Recurse -Force -LiteralPath $f -ErrorAction SilentlyContinue }
    }
}

Write-Host ""
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
# assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
$fixtureBroken = Write-FixtureGitSummary -Subject 'park-branch.ps1'
# AND THE SAME VERDICT FOR A CHILD THAT DIED ON LOAD (#1934). Separate counter, separate line: a
# fixture git call that failed and a child that never started are different breakages with different
# repairs, and folding them into one number would name neither.
$loadBroken = Write-FixtureScriptSummary -Subject 'park-branch.ps1'
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
if ($loadBroken) {
    Write-Host "FAILED: $(Get-FixtureScriptLoadFailureCount) child script(s) died on load -- this run measured a fixture, not the script." -ForegroundColor Red
    exit 1
}
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
