<#
.SYNOPSIS
    Regression tests for the split-identity check (issue #1315): the check script
    scripts/lint/check-git-identity.ps1 and the SessionStart hook git-identity-sessioncheck.ps1.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/git-identity-gate.tests.ps1

    NOTHING HERE READS THE MACHINE'S OWN IDENTITY, and that is the whole design of this suite. The
    check's subject IS the machine -- the account gh holds, the name git commits as, and since inbound
    #1867 whether git will accept a commit at all -- so a suite that let any of those values through
    would assert a different thing on Dave's checkout than on a CI runner, and would go green or red
    for reasons that have nothing to do with the code. Every case below therefore passes all three in
    explicitly (-GhAccountOverride / -GitUserNameOverride / -CanCommitOverride), and the hook is
    exercised against STUB check scripts written into the fixture rather than against the real one.
    The third one defaults to "yes, it can commit" in Invoke-Check, so the cases written before it
    existed go on asserting exactly what they were written to assert. The one thing not asserted is
    the reading of `gh auth status` itself, which is a test gap named in the branch document rather
    than papered over: it needs a keyring, and a suite that installed one would be testing gh.

    THE LOGIN-SHAPE BOUNDARY IS WHERE THE VALUE IS. The check only reports a mismatch when
    git config user.name is a VALID GitHub username, because that guard is the only thing standing
    between this check and firing forever in every repo whose user.name is a person's name. So the
    cases walk GitHub's rule at both edges -- 39 characters passes, 40 does not, and a leading,
    trailing or doubled hyphen does not.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary and two sharing one fixed temp path tear down each other's tree.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\lint\check-git-identity.ps1'
$Hook     = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\git-identity-sessioncheck.ps1'
$Mirror   = Join-Path $RepoRoot 'plugins\dkj-policy\scripts\lint\check-git-identity.ps1'

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function New-Tree {
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("gitidentity-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:trees += $dir
    return $dir
}

function New-StubCheck {
    <#
        A stand-in check script, so the hook's three output branches can be driven without a machine
        that actually has a split identity. It accepts -RootOverride because that is the only argument
        the hook passes.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body,
        [Parameter(Mandatory = $true)][int]$ExitCode
    )
    $path = Join-Path $Dir "$Name.ps1"
    $lines = @("param([string]`$RootOverride = '')")
    foreach ($b in ($Body -split "`n")) {
        if ($b) { $lines += ("Write-Host '" + ($b -replace "'", "''") + "'") }
    }
    $lines += "exit $ExitCode"
    [System.IO.File]::WriteAllText($path, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    return $path
}

function Invoke-Check {
    <#
        Both identities always passed in explicitly -- see the file synopsis. 'NONE' is the check's own
        spelling for "absent", so a case can say "gh is logged out" without logging anything out.

        AND SO IS THE COMMIT-ABILITY PROBE, for exactly the same reason (inbound #1867). Since that
        probe runs `git var GIT_AUTHOR_IDENT` against the real machine, leaving it unset would put a
        THIRD machine-dependent value into every case here -- and a green suite on Dave's checkout
        would go red on a runner with no git identity, in cases that have nothing to do with it. So
        -CanCommit defaults to 'YES' and every existing case keeps asserting what it was written to
        assert; the cases that are ABOUT the probe pass 'NO'.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gh,
        [Parameter(Mandatory = $true)][string]$Git,
        [string]$CanCommit = 'YES',
        [string]$ScriptPath = $Script
    )
    $scriptArgs = @('-GhAccountOverride', $Gh, '-GitUserNameOverride', $Git, '-CanCommitOverride', $CanCommit)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @scriptArgs 2>&1
    } finally { $ErrorActionPreference = $prevEap }
    return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
}

function Invoke-Hook {
    param([Parameter(Mandatory = $true)][string]$CheckScriptOverride, [string]$Dir = '')
    $hookArgs = @('-CheckScriptOverride', $CheckScriptOverride)
    if ($Dir) { $hookArgs += @('-ConsumerPathOverride', $Dir) }
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Hook @hookArgs 2>&1
    } finally { $ErrorActionPreference = $prevEap }
    return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
}

try {
    # --- the mismatch, which is the whole point --------------------------------------------------
    Write-Host 'check-git-identity.ps1 -- a provable mismatch'

    $r = Invoke-Check -Gh 'DaveKJohn' -Git 'davekokbwj'
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[ERROR\]') `
        'the measured pairing (gh DaveKJohn / git davekokbwj) -- [ERROR], exit 1'
    Assert-True ($r.Out -match 'DaveKJohn' -and $r.Out -match 'davekokbwj') `
        'the report names BOTH accounts, so the reader knows which is which without re-running anything'
    Assert-True ($r.Out -match 'add-assignee davekokbwj') `
        'it names the by-NAME claim as the interim idiom, with the committing account filled in'
    Assert-True ($r.Out -match 'git config user\.name' -and $r.Out -match 'gh auth login') `
        'both ways out are printed -- the check does not pick one of the two accounts for the reader'
    Assert-True ($r.Out -match 'construction') `
        'it says the cross-device tell is not diagnostic here, which is the second consequence of #1315'

    # A 39-character login is valid by GitHub's rule, so the mismatch must still be reported. This is
    # the upper edge of the guard, and the case that fails if the quantifier is ever written {0,37}.
    $long = 'a' + ('b' * 38)
    Assert-True ($long.Length -eq 39) 'fixture sanity: the long name is exactly 39 characters'
    $r = Invoke-Check -Gh 'DaveKJohn' -Git $long
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[ERROR\]') `
        'a 39-character user.name is a valid login -- the mismatch is still reported'

    $r = Invoke-Check -Gh 'DaveKJohn' -Git 'a-b-c'
    Assert-True ($r.Code -eq 1) 'single hyphens are legal in a login -- reported'

    # --- the identities agreeing -------------------------------------------------------------------
    Write-Host ''
    Write-Host 'check-git-identity.ps1 -- agreement'

    $r = Invoke-Check -Gh 'maikel-bwj' -Git 'maikel-bwj'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[OK\]') `
        'the same account on both sides -- [OK], exit 0'

    $r = Invoke-Check -Gh 'DaveKJohn' -Git 'davekjohn'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[OK\]') `
        'GitHub logins are case-insensitive, so a case-only difference is ONE account, not two'

    # --- the noise guard, which is why this check is shippable ------------------------------------
    Write-Host ''
    Write-Host 'check-git-identity.ps1 -- the login-shape guard (no false positives)'

    $r = Invoke-Check -Gh 'maikel-bwj' -Git 'Maikel Hoogendoorn'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]') `
        'a display name with a space is NOT an account -- [SKIP], the case that would otherwise fire forever'

    $r = Invoke-Check -Gh 'DaveKJohn' -Git 'bad-'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]') 'a trailing hyphen is not a valid login -- [SKIP]'

    $r = Invoke-Check -Gh 'DaveKJohn' -Git '-bad'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]') 'a leading hyphen is not a valid login -- [SKIP]'

    $r = Invoke-Check -Gh 'DaveKJohn' -Git 'a--b'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]') 'a doubled hyphen is not a valid login -- [SKIP]'

    $r = Invoke-Check -Gh 'DaveKJohn' -Git ('a' * 40)
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]') `
        'a 40-character name is past GitHub''s 39-character limit -- [SKIP], the upper edge of the guard'

    $r = Invoke-Check -Gh 'DaveKJohn' -Git 'dave.kok'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]') 'a dot is not legal in a login -- [SKIP]'

    # --- nothing to compare ------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'check-git-identity.ps1 -- nothing to compare'

    $r = Invoke-Check -Gh 'NONE' -Git 'davekokbwj'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]' -and $r.Out -match 'no active account') `
        'gh absent or logged out -- [SKIP], the ordinary state of a consumer that never uses the tracker'

    $r = Invoke-Check -Gh 'DaveKJohn' -Git 'NONE'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]' -and $r.Out -match 'unset') `
        'user.name unset but the checkout CAN commit -- [SKIP]; nothing to compare, now that the state which made this matter is reported above it (inbound #1867)'

    $r = Invoke-Check -Gh 'NONE' -Git 'NONE'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]') 'neither side present -- [SKIP], no throw'

    # --- the checkout that cannot commit at all (inbound #1867) ------------------------------------
    # THE STATE THE THIRD [SKIP] ABOVE USED TO SWALLOW. Its old justification -- "git itself refuses to
    # commit in that state, so it needs no second reporter" -- is true about WHETHER and wrong about
    # WHEN: the first commit of the cycle is inside new-branch.ps1, after HEAD has moved. These cases
    # pin the split, and they are the ones that pass -CanCommit 'NO'.
    Write-Host ''
    Write-Host 'check-git-identity.ps1 -- no usable git author identity'

    $r = Invoke-Check -Gh 'davekokbwj' -Git 'davekokbwj' -CanCommit 'NO'
    Assert-True ($r.Out -match '\[WARNING\]' -and $r.Out -match 'cannot commit') `
        'no author identity -- a [WARNING] of its own, not one of the three silent [SKIP]s'
    Assert-True ($r.Code -eq 0) `
        'and it stays ADVISORY (exit 0) -- the SessionStart hook behind it must never block a session'
    Assert-True ($r.Out -match 'GIT_AUTHOR_IDENT') `
        'it names the probe, so a reader can reproduce the verdict without reading the script'
    Assert-True ($r.Out -match 'user\.name' -and $r.Out -match 'user\.email') `
        'BOTH config keys are printed -- setting only user.name leaves git refusing just as hard'

    # THE PRECEDENCE, which is the half a reader cannot infer from the two cases above. A machine can
    # hold a split identity AND no usable one at once; the blunter finding has to win, because a
    # checkout that cannot commit cannot act on the comparison either.
    $r = Invoke-Check -Gh 'DaveKJohn' -Git 'davekokbwj' -CanCommit 'NO'
    Assert-True ($r.Out -match '\[WARNING\]' -and $r.Out -notmatch '\[ERROR\]') `
        'it outranks the split-identity report -- the mismatch is not what a no-identity machine needs told'
    Assert-True ($r.Code -eq 0) `
        'and the exit code follows the verdict actually printed, so exit 1 cannot arrive with no [ERROR]'

    # THE OTHER DIRECTION, and it is what keeps this check shippable: a checkout that CAN commit must
    # reach the comparison untouched. Without this, a probe that answered 'NO' too readily would
    # silence every finding the check exists for.
    $r = Invoke-Check -Gh 'DaveKJohn' -Git 'davekokbwj' -CanCommit 'YES'
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[ERROR\]' -and $r.Out -notmatch '\[WARNING\]') `
        'a checkout that CAN commit falls straight through to the comparison, unchanged'

    # --- Test-GitCanCommit ITSELF: what the probe's exit code is allowed to mean (issue #1920) -----
    #
    # WHY THE LIB IS DRIVEN DIRECTLY HERE, where every case above drives the script. The cases above
    # pass -CanCommitOverride, so they assert what the CHECK does with a verdict it is handed -- they
    # cannot reach how that verdict is REACHED, and that is the half #1920 is about. The seam is the
    # probe's exit code, so the probe is what has to be stubbed.
    #
    # THE DEFECT THIS PINS. Test-GitCanCommit's docstring has said since #1867 that an unknown answer
    # is treated as can-commit -- "a refusal built on a failure to measure would wedge a run for the
    # wrong reason" -- while its body read `$res.ExitCode -eq 0`, which refuses on every non-zero exit
    # there is. new-branch.ps1 runs this probe before the checkout on every run and exits 1 on a
    # refusal with nothing created, and new-branch.tests.ps1 invokes that script some forty times per
    # gate run across sixteen lanes. One transient git failure -- the class #1915 measured in that same
    # suite on that same day -- therefore produced a red gate that had measured nothing.
    #
    # SHADOWED AFTER THE DOT-SOURCE, the idiom remote-ahead-lib.tests.ps1 already uses and that
    # native-capture-lib.ps1 documents for itself: a plain function can be redefined in the scope that
    # dot-sourced it, and Test-GitCanCommit resolves the name at call time. No git runs in these cases
    # at all, which is what keeps them machine-independent like the rest of this suite.
    Write-Host ''
    Write-Host 'Test-GitCanCommit -- only git''s own 128 is a refusal'

    . (Join-Path $RepoRoot 'scripts\lib\git-identity-lib.ps1')
    $script:stubProbeExit     = 0
    $script:stubProbeTimedOut = $false
    $script:stubProbeNull     = $false
    function Invoke-NativeCapture {
        param(
            [Parameter(Mandatory = $true)][string]$FilePath,
            [string[]]$Arguments = @(),
            [switch]$DiscardStderr,
            [switch]$Utf8,
            [int]$TimeoutSeconds = 0
        )
        if ($script:stubProbeNull) { return $null }
        return [pscustomobject]@{ Output = @(); ExitCode = $script:stubProbeExit; TimedOut = $script:stubProbeTimedOut }
    }

    # 0 -- git named an author. The healthy machine, and the case every other run in the workflow is.
    $script:stubProbeExit = 0
    Assert-True (Test-GitCanCommit -RepoRoot $RepoRoot) 'exit 0: git named an author -- the checkout can commit'

    # 128 -- git's die(), which is how it reports an unknown author identity. THE ONE REFUSAL, and the
    # number is pinned against git itself by new-branch.tests.ps1's (y) fixture sanity assert rather
    # than only here, so the two ends of the discriminator cannot drift apart silently.
    $script:stubProbeExit = 128
    Assert-True (-not (Test-GitCanCommit -RepoRoot $RepoRoot)) 'exit 128: git refuses to name an author -- the one state that refuses'

    # THE REGRESSION ITSELF. Each of these refused before #1920 and measured nothing: 1 is what a
    # killed process leaves behind, and the negative code is a Windows crash status (the sign bit the
    # gate's own crash probe reads). A run that could not take the measurement must not be told the
    # answer is "no".
    foreach ($code in @(1, 2, 129, -1073741819)) {
        $script:stubProbeExit = $code
        Assert-True (Test-GitCanCommit -RepoRoot $RepoRoot) "exit $code : the probe did not answer -- unknown is can-commit, not a refusal"
    }

    # A BOUNDED CALL THAT EXPIRED IS READ BEFORE ITS NUMBER IS. Invoke-NativeCapture substitutes its
    # own exit code on a timeout, so the number is not git's at all -- and the substituted one must
    # never be able to read as 128 by coincidence.
    $script:stubProbeTimedOut = $true
    $script:stubProbeExit     = 128
    Assert-True (Test-GitCanCommit -RepoRoot $RepoRoot) 'timed out: the wait expired, so nothing was measured -- even at exit 128'
    $script:stubProbeTimedOut = $false

    # The $null return, which the function has always honoured -- asserted so the narrowing above
    # cannot quietly take it with it.
    $script:stubProbeNull = $true
    Assert-True (Test-GitCanCommit -RepoRoot $RepoRoot) 'no result object at all: still can-commit'
    $script:stubProbeNull = $false

    # Restored, so nothing after this point is stubbed. The dot-source re-defines the real function
    # over the shadow in this same scope.
    . (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')
    Assert-True ((Get-Command Invoke-NativeCapture -CommandType Function).ScriptBlock.ToString() -match 'ConvertTo-NativeArgumentToken|Start-Process|& \$FilePath') `
        'and the stub is gone again -- the real capture is back in scope for anything after this'

    # --- the plugin mirror answers identically ----------------------------------------------------
    # shared-scripts.tests.ps1 proves the two files are byte-identical; this proves the mirror RUNS
    # from its own directory, which is the only thing byte-equality cannot tell you (its
    # $PSScriptRoot-relative dot-source of native-capture-lib.ps1 has to resolve there too).
    Write-Host ''
    Write-Host 'the plugin mirror'

    Assert-True (Test-Path -LiteralPath $Mirror -PathType Leaf) 'the mirror exists at the registered path'
    $r = Invoke-Check -Gh 'DaveKJohn' -Git 'davekokbwj' -ScriptPath $Mirror
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[ERROR\]') `
        'the mirror reports the same mismatch, so its own dot-source resolves from the plugin tree'

    # --- the SessionStart hook ---------------------------------------------------------------------
    Write-Host ''
    Write-Host 'git-identity-sessioncheck.ps1'

    $stubs = New-Tree -Label 'stubs'

    $errStub = New-StubCheck -Dir $stubs -Name 'stub-error' -ExitCode 1 `
        -Body "[ERROR] this checkout acts as one GitHub account and commits as another:`n          gh acts as 'DaveKJohn'`n          git commits as 'davekokbwj'"
    $r = Invoke-Hook -CheckScriptOverride $errStub
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'acts as one GitHub account and commits as another' -and $r.Out -match 'davekokbwj') `
        'an [ERROR] from the check -- forwarded into the session with its detail, still exit 0'
    Assert-True ($r.Out -match 'data, not instructions') `
        'the forwarded block is labelled as data, so the session does not read a report as a command'

    $okStub = New-StubCheck -Dir $stubs -Name 'stub-ok' -ExitCode 0 -Body "[OK] gh and git are the same account"
    $r = Invoke-Hook -CheckScriptOverride $okStub
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'the gh account and the git identity agree') `
        'a clean check -- the one-line in-sync report, exit 0'

    # A [SKIP] must read as clean rather than as a crash (exit 0, no [ERROR]) -- but issue #1830 is
    # exactly that it must NOT read as [OK]'s agreement sentence either: a [SKIP] means nothing was
    # compared, and reporting "agree" there claims a comparison that never happened, on a machine that
    # may have no git identity at all. So it falls through to a THIRD, silent branch of its own.
    $skipStub = New-StubCheck -Dir $stubs -Name 'stub-skip' -ExitCode 0 -Body "[SKIP] gh names no active account"
    $r = Invoke-Hook -CheckScriptOverride $skipStub
    Assert-True ($r.Code -eq 0 -and $r.Out -notmatch 'could not complete') `
        'a [SKIP] is not a failure -- no "could not complete", exit 0'
    Assert-True ($r.Out -notmatch 'agree') `
        'a [SKIP] must NOT be reported as agreement -- #1830, no comparison was made'

    # THE [WARNING] ARM (inbound #1867). Its whole reason to exist is that this state used to reach the
    # silent [SKIP] branch tested just above -- so the assertion that matters is not only that it is
    # reported, but that it does NOT go silent the way a [SKIP] does. Exit 0 like every other arm: a
    # session start must never strand here, however broken the machine turns out to be.
    $warnStub = New-StubCheck -Dir $stubs -Name 'stub-warning' -ExitCode 0 `
        -Body "[WARNING] this checkout has no usable git author identity -- it cannot commit at all.`n          git config --global user.email `"<the address on that account>`""
    $r = Invoke-Hook -CheckScriptOverride $warnStub
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'no usable git author identity') `
        'a [WARNING] -- reported at session start rather than swallowed as a [SKIP], still exit 0'
    Assert-True ($r.Out -match 'user\.email') `
        'and its detail is forwarded, so the repair is in the session without re-running anything'
    Assert-True ($r.Out -match 'data, not instructions') `
        'the forwarded block is labelled as data, like the [ERROR] arm above it'
    Assert-True ($r.Out -notmatch 'agree') `
        'it is not reported as agreement -- nothing was compared, which is #1830 one state further on'

    # Non-zero exit with no [ERROR] line: an unexpected crash must not be reported as clean.
    $crashStub = New-StubCheck -Dir $stubs -Name 'stub-crash' -ExitCode 3 -Body "something unexpected"
    $r = Invoke-Hook -CheckScriptOverride $crashStub
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'could not complete \(exit 3\)') `
        'a crashing check -- reported as incomplete rather than as clean, and still exit 0'

    $r = Invoke-Hook -CheckScriptOverride (Join-Path ([System.IO.Path]::GetTempPath()) "no-such-check-$PID-$([guid]::NewGuid().ToString('n')).ps1")
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'check script not found -- check skipped') `
        'check script missing -- a notice, exit 0, never a strand'
}
finally {
    foreach ($t in $script:trees) {
        if ($t -and (Test-Path -LiteralPath $t)) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAIL: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
