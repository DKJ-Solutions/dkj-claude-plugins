<#
.SYNOPSIS
    Tests for plugins/dkj-policy/hooks/connector-sessioncheck.ps1's #1591 fallback: what a SESSION
    SEES on a machine with no sibling source checkout (the ordinary state of a consumer), now that
    the hook runs plugin-versions.ps1 -Brief instead of printing "check skipped" unconditionally.

.DESCRIPTION
    WHY A NEW FILE RATHER THAN EXTENDING connectors.tests.ps1's SECTION 9. That section already
    covers this hook, but through a completely different seam: New-StubWorkshop builds a FAKE
    check-connectors.ps1 behind a valid marketplace marker, and every stub scenario there answers
    "does a workshop resolve, and what does it say". The fallback tested here fires precisely when
    NO workshop resolves, and what it prints depends on a different subsystem entirely -- the
    install administration (~/.claude/plugins/installed_plugins.json) and the marketplace clone
    that plugin-versions.ps1 reads. Bolting that fixture shape (repo + home + git clone + admin
    JSON, exactly plugin-versions.tests.ps1's own idiom) onto an 800+-line file already organised
    around stub workshops would blur two unrelated subjects under one section number. Two of
    connectors.tests.ps1's existing scenarios (9a, 9e) still cover this hook's PRE-fallback rejection
    path (no workshop marker found at all) and were repaired in place there, isolated the same way
    this file isolates everything -- CLAUDE_PROJECT_DIR + USERPROFILE redirected to a scratch
    fixture, per Get-InstallRecord's own docstring, which is the seam that already existed and
    the one this file uses throughout.

    THE FOUR BRANCHES THIS FILE PINS, one scenario group each:
      1  the engine reports at least one [ERROR]   -> a "behind the marketplace clone" verdict
         line, then the [ERROR] lines, then any [INFO] lines, then the [SUMMARY] line, then the
         restart-the-session line -- in that exact order (Assert-Equal on the whole run, line by
         line, not just Assert-Match on fragments)
      2  no [ERROR], but the engine has something to  -> ONE line carrying the summary text, with
         say ([INFO] present or the run is fully quiet)  the [INFO] line(s) NOT forwarded (they would
                                                          be permanent session-start noise from a
                                                          plugin nobody can act on -- the hook's own
                                                          docstring names this explicitly)
      3  the engine's output carries none of the three -> its own branch: neither a finding nor an
         markers this hook recognises (a broken           all-clear, and the engine's own exit code
         install, or a shape change)                      is carried into the message
      4  no plugin-versions.ps1 engine reachable at all  -> the pre-#1591 "check skipped" line,
         (a plugin install predating the mirror)          UNCHANGED

    EVERY ONE OF THE FOUR IS ASSERTED TO SAY THE REGISTER CHECKS DID NOT RUN -- the [UNREGISTERED]
    lesson of 2026-07-28, applied to this new code path. That is true of all four, and branch 4 is why the assertion is
    worth making rather than assuming: it inherited the pre-#1591 wording ("... check skipped."),
    which never mentioned register checks at all, so for a while the hook's own docstring
    overclaimed by exactly one branch. Found by pinning the four independently instead of trusting
    the docstring (#1606), and repaired in the hook rather than by weakening the assert -- which
    would have made this suite lie about what ships.

    BRANCH 2'S ZERO-PLUGINS CORNER WAS THE SECOND ONE FOUND THE SAME WAY (#1607): the engine's whole
    answer there is a single [INFO] line and no [SUMMARY], and the hook read $vsummary
    unconditionally -- so the line trailed off after "Version check: " and dropped the one thing the
    engine had to say. Also repaired in the hook. Both are pinned below on the FIXED behaviour, and
    both scenarios keep the reasoning, because a pin whose history is gone is a pin nobody dares
    touch.

    HOW EACH BRANCH IS REACHED, since none of them is the hook's normal candidate-search path:
      - Branches 1 and 2 drive the REAL hook against a REAL plugin-versions.ps1, isolated via
        CLAUDE_PROJECT_DIR + USERPROFILE exactly as plugin-versions.tests.ps1 isolates that script
        directly. WHICH real copy is not a free choice, and naming it precisely is the point: the
        hook has exactly ONE engine candidate -- ($PSScriptRoot/../scripts/task/plugin-versions.ps1)
        relative to the HOOK FILE'S OWN location -- and $Hook below is the plugin mirror's copy
        (plugins/dkj-policy/hooks/), so the engine these two branches measure is
        plugins/dkj-policy/scripts/task/plugin-versions.ps1. THE MIRROR, never this repo's root
        scripts/task/ copy. The drift lint holds the two byte-identical, so the assertions below
        read the same either way; the ORDER of two commands does not.
        AFTER EDITING scripts/task/plugin-versions.ps1, RUN scripts/sync/build-shared-scripts.ps1
        BEFORE RUNNING THIS SUITE STANDALONE. Until the mirror is rebuilt this suite reports on the
        PREVIOUS engine and says nothing about having done so. Measured September 10, 2026 on the
        #1772 branch: 47 pass / 0 fail against the unrebuilt mirror, then 41 pass / 6 fail from the
        same unchanged suite once it was rebuilt, with a fixture that genuinely needed repointing
        (#1786). The test gate is not exposed to this -- it runs the shared-script drift check,
        which ERRORS on a stale mirror, before it runs the suites -- so the window is the standalone
        run only, which is exactly the run a session makes while editing the engine.
      - Branch 3 substitutes a FAKE engine the only way that single candidate allows: an isolated
        COPY of the hook with the fake planted at its own ..\scripts\task\plugin-versions.ps1 (one
        that prints neither [ERROR] nor [INFO] nor [SUMMARY]). It used to plant the fake under
        (Get-Location) instead, back when $cwd was the hook's FIRST candidate; that candidate was
        removed on review as arbitrary execution out of whatever directory a session happened to be
        opened in, and Invoke-HookWithFakeEngine's own docstring records what its removal cost.
      - Branch 4 needs that one candidate to miss, so it copies the hook itself into an isolated
        fixture tree with no such sibling -- the same "stub" technique connectors.tests.ps1 already
        uses for check-connectors.ps1.

    THE FIFTH GROUP IS NOT A FIFTH BRANCH -- IT IS HOW OFTEN THE FOUR ARE REACHED (#1605). The
    matcher is 'startup|resume|clear|compact', so every scenario above used to be paid again at every
    compaction, and the engine spawn is 1.1-1.8s of it. Group 5 counts the spawns on disk (the fake
    engine appends a line to a counter file before printing its verdict) and asserts the property
    that makes a cache safe rather than merely cheap: a replayed firing prints EXACTLY what the
    measured one printed. Its four cases are the whole contract -- same id replays, a new id
    re-measures, a payload with no id never caches, and a payload predating the lib degrades to the
    pre-#1605 behaviour rather than to an error.

    Every scenario asserts exit code 0 explicitly: a SessionStart hook must never fail a session.
    -WorkshopPathOverride always points at a path that does not exist, so every scenario enters the
    "no verified workshop checkout" branch deliberately, never by accident of the real machine.

    Dependency-free (no Pester), same style as plugin-versions.tests.ps1 / connectors.tests.ps1.
    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

# JUDGING THIS SUITE'S OWN FIXTURE CHILD -- issues #1934 and #1954. Three of the helpers below copy the
# hook into a fixture tree and run it there, so a lib the copy list has gone stale on kills the child
# during LOAD. The hook's own sibling loads are GUARDED, which is why this is dormant today rather than
# redundant: it catches the first unguarded one, which is exactly how #1917 produced the class.
. (Join-Path $PSScriptRoot '..\lib\fixture-script-lib.ps1')
$Hook     = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\connector-sessioncheck.ps1'
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "connector-sessioncheck-test-$PID-$([guid]::NewGuid().ToString('n'))"
$Utf8     = New-Object System.Text.UTF8Encoding $false

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
function Assert-Has {
    param([string]$Text, [string]$Needle, [string]$Label)
    Assert-True ($Text.Contains($Needle)) $Label
}
function Assert-Lacks {
    param([string]$Text, [string]$Needle, [string]$Label)
    Assert-True (-not $Text.Contains($Needle)) $Label
}

# --- fixture builders (same idiom as plugin-versions.tests.ps1) ---------------------------------

function Git-X {
    # git under EAP=Continue -- the #107 pitfall guard, same reasoning as plugin-versions.tests.ps1.
    param([string]$Dir, [string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $Dir @GitArgs 2>&1
        # THE EXIT CODE IS JUDGED (issue #1635). This helper returned the output and dropped the verdict,
        # so a failed fixture command was indistinguishable from a working one. Every call in this file
        # is expected to succeed -- there is no negative probe among them -- so judging the reads along
        # with the mutations costs nothing and covers both.
        Assert-FixtureGitOk -Code $LASTEXITCODE -GitArgs (@('-C', $Dir) + @($GitArgs)) -Output $out
        return (($out | ForEach-Object { "$_" }) -join "`n").Trim()
    } finally {
        $ErrorActionPreference = $prev
    }
}

function New-Case {
    # A checkout dir (for CLAUDE_PROJECT_DIR) and a scratch home (for USERPROFILE) that carries the
    # install administration and the marketplace clone -- the hook's fallback reads BOTH via the
    # ambient environment (it passes no -RootOverride/-UserHomeOverride of its own to the engine).
    param([Parameter(Mandatory = $true)][string]$Label)
    $repo    = Join-Path $Fixture "$Label\repo"
    $homeDir = Join-Path $Fixture "$Label\home"
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $homeDir '.claude\plugins') -Force | Out-Null
    [pscustomobject]@{
        Repo  = $repo
        Home  = $homeDir
        Clone = (Join-Path $homeDir '.claude\plugins\marketplaces\ccs-fixture')
        Admin = (Join-Path $homeDir '.claude\plugins\installed_plugins.json')
    }
}

function Set-Enabled {
    param([string]$RepoDir, [string[]]$Ids = @())
    New-Item -ItemType Directory -Path (Join-Path $RepoDir '.claude') -Force | Out-Null
    if ($Ids.Count -eq 0) {
        [System.IO.File]::WriteAllText((Join-Path $RepoDir '.claude\settings.json'), '{ "enabledPlugins": { } }', $Utf8)
        return
    }
    $ep = @{}
    foreach ($i in $Ids) { $ep[$i] = $true }
    [System.IO.File]::WriteAllText((Join-Path $RepoDir '.claude\settings.json'),
        (@{ enabledPlugins = $ep } | ConvertTo-Json -Depth 5), $Utf8)
}

function New-Clone {
    # A git-based marketplace clone at $Dir: .claude-plugin/marketplace.json + one plugin.json per
    # name, all at the same version. Returns the HEAD sha after the first commit.
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [string]$Version = '4.32.0',
        [string[]]$PluginNames = @('dkj-subagents-alpha')
    )
    New-Item -ItemType Directory -Path (Join-Path $Dir '.claude-plugin') -Force | Out-Null
    $plugins = @()
    foreach ($pn in $PluginNames) {
        $pdir = Join-Path $Dir "plugins\$pn\.claude-plugin"
        New-Item -ItemType Directory -Path $pdir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $pdir 'plugin.json'),
            (@{ name = $pn; version = $Version } | ConvertTo-Json -Depth 5), $Utf8)
        $plugins += @{ name = $pn; source = "./plugins/$pn" }
    }
    [System.IO.File]::WriteAllText((Join-Path $Dir '.claude-plugin\marketplace.json'),
        (@{ name = 'ccs-fixture'; plugins = @($plugins) } | ConvertTo-Json -Depth 6), $Utf8)
    Git-X $Dir @('init', '--quiet') | Out-Null
    Git-X $Dir @('config', 'user.email', 'tycho@test.local') | Out-Null
    Git-X $Dir @('config', 'user.name', 'Tycho Test') | Out-Null
    Git-X $Dir @('config', 'commit.gpgsign', 'false') | Out-Null
    Git-X $Dir @('add', '-A') | Out-Null
    Git-X $Dir @('commit', '--quiet', '-m', 'clone c1') | Out-Null
    return (Git-X $Dir @('rev-parse', 'HEAD'))
}

function New-Rec {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [string]$Version = '4.32.0',
        [string]$Sha = ''
    )
    $h = @{ scope = 'project'; projectPath = $ProjectPath; version = $Version }
    if ($Sha) { $h['gitCommitSha'] = $Sha }
    return $h
}

function Write-Admin {
    param([string]$Path, [hashtable]$Plugins)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, (@{ version = 2; plugins = $Plugins } | ConvertTo-Json -Depth 12), $Utf8)
}

function Invoke-Hook {
    <#
        Runs the REAL hook (the plugin mirror's copy -- see $Hook) with CLAUDE_PROJECT_DIR and
        USERPROFILE pinned to a fixture, and the process location pushed to $RepoRoot.

        THE ENGINE IT REACHES IS THE MIRROR BESIDE THAT HOOK FILE, and the pushed location has
        nothing to do with it: the hook's one engine candidate is $PSScriptRoot-relative, so what
        these callers measure is plugins/dkj-policy/scripts/task/plugin-versions.ps1 whatever the
        working directory is. This helper pushed to $RepoRoot back when $cwd WAS the hook's first
        engine candidate and that push was what found the root copy. THE PUSH IS NOW INERT for
        these scenarios and is kept only as belt-and-braces isolation: the hook's remaining reads of
        (Get-Location) are its workshop search -- which every scenario here bypasses with
        -WorkshopPathOverride -- and its consumer scoping, which sits past the version branch's own
        return. Pinning it still costs nothing and keeps the caller's directory out of any path a
        later change might reopen; do not read it as a mechanism these branches depend on.
        The header's ordering note applies to every caller of this helper: rebuild the mirror before
        running this suite standalone against a freshly edited scripts/task/plugin-versions.ps1
        (#1786).

        No native-capture-lib redirect-file capture here (unlike plugin-versions.tests.ps1):
        Invoke-Ps in connectors.tests.ps1 already established this hook is safe to call with a plain
        '&' (it never writes to stderr on its own success paths, and every path here catches its own
        errors before Write-Host), so the extra machinery buys nothing this hook's own tests need.
    #>
    param([string]$RepoDir, [string]$HomeDir, [string[]]$HookArgs = @())
    $prevP = $env:CLAUDE_PROJECT_DIR
    $prevU = $env:USERPROFILE
    $env:CLAUDE_PROJECT_DIR = $RepoDir
    $env:USERPROFILE = $HomeDir
    Push-Location $RepoRoot
    try {
        # THE VERSION BOUND IS RAISED HERE, ONCE, FOR EVERY CALLER OF THIS HELPER (#1701). This is the
        # helper that runs the hook against the REAL engine, so every one of its callers races the same
        # cold PowerShell 5.1 startup -- and this suite runs inside the test gate's own parallel lanes,
        # which is the one condition under which the production 30s is reachable. When it was hit, the
        # hook took its graceful-degradation branch (correctly, still exit 0) and six assertions written
        # against the branch that did not run all failed, on a branch that reads nothing this hook
        # touches. Raised rather than tolerated: the un-degraded five-line output is exactly what these
        # blocks exist to pin, and asserting "either shape" would retire the assertion to keep the
        # suite green. The degraded shape has its own scenario below, forced deterministically.
        #
        # A caller that names the parameter itself wins, which is what lets that scenario exist.
        $bound = if ($HookArgs -contains '-VersionTimeoutSeconds') { @() } else { @('-VersionTimeoutSeconds', '300') }
        $args = @('-WorkshopPathOverride', (Join-Path $Fixture 'nowhere')) + $bound + $HookArgs
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Hook @args
        return [pscustomobject]@{ Code = $LASTEXITCODE; Lines = @($out); Text = ($out -join "`n") }
    } finally {
        Pop-Location
        $env:CLAUDE_PROJECT_DIR = $prevP
        $env:USERPROFILE = $prevU
    }
}

function Invoke-HookWithFakeEngine {
    <#
        Branch 3: substitutes a FAKE plugin-versions.ps1 the only way the hook can now be made to
        reach one -- an isolated COPY of the hook with the fake planted at its own
        ..\scripts\task\plugin-versions.ps1. This is branch 4's Invoke-IsolatedHookNoEngine technique
        with the engine ADDED rather than withheld.

        IT USED TO PLANT THE FAKE UNDER (Get-Location) INSTEAD, and that is worth recording because
        the change was not cosmetic: the hook's candidate search tried $cwd FIRST, which is what made
        that injection work -- and that candidate was REMOVED on review, being arbitrary execution
        out of whatever directory a session happened to be opened in. When it went, this helper
        silently stopped substituting anything: the hook ran the REAL mirror against the fixture and
        branch 3 asserted against a genuine "no plugins are enabled" line. The suite caught it, which
        is the argument for pinning whole lines here rather than fragments.
    #>
    param(
        [string]$EngineDir,
        [string]$FakeBody,
        [string]$RepoDir,
        [string]$HomeDir,
        [string[]]$HookArgs = @(),
        # Copy native-capture-lib.ps1 to the hook copy's own ..\scripts\lib\ sibling, which is where the
        # hook resolves it from. Without it the copy takes its pre-#1591 fallback -- a bare '& powershell'
        # with no bound at all -- so a scenario about the BOUND has to ask for the lib that enforces it.
        # Same seam Invoke-CountedHook uses for session-cache-lib, and off by default for the same reason:
        # the blocks that predate it assert the fallback and must keep getting it.
        [switch]$WithCaptureLib
    )
    $hookCopy = Join-Path $EngineDir 'hooks\connector-sessioncheck.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $hookCopy) -Force | Out-Null
    Copy-Item -LiteralPath $Hook -Destination $hookCopy -Force
    New-Item -ItemType Directory -Path (Join-Path $EngineDir 'scripts\task') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $EngineDir 'scripts\task\plugin-versions.ps1'), $FakeBody, $Utf8)
    if ($WithCaptureLib) {
        New-Item -ItemType Directory -Path (Join-Path $EngineDir 'scripts\lib') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1') `
                  -Destination (Join-Path $EngineDir 'scripts\lib\native-capture-lib.ps1') -Force
        # run-progress-lib.ps1 is native-capture-lib's own sibling dot-source (#2101). Guarded there, so
        # its absence would not break this fixture -- copied anyway, because a fixture that differs from
        # the tree in a way nobody wrote down is the shape #1693 exists to stop.
        Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\run-progress-lib.ps1') `
                  -Destination (Join-Path $EngineDir 'scripts\lib\run-progress-lib.ps1') -Force
        # command-probe-lib.ps1 is a sibling of a sibling (#1729): the three libs above dot-source it for
        # Test-FunctionDefined, so the fixture owes it exactly as it owes ref-print-lib.
        Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\command-probe-lib.ps1') -Destination (Join-Path $EngineDir 'scripts\lib\command-probe-lib.ps1') -Force
    }
    $prevP = $env:CLAUDE_PROJECT_DIR
    $prevU = $env:USERPROFILE
    $env:CLAUDE_PROJECT_DIR = $RepoDir
    $env:USERPROFILE = $HomeDir
    Push-Location $EngineDir
    try {
        # EAP LOWERED AND STDERR MERGED FOR THE CALL -- see Invoke-CountedHook for why (#1954).
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $hookCopy `
            -WorkshopPathOverride (Join-Path $Fixture 'nowhere') @HookArgs 2>&1
        $code = $LASTEXITCODE
        Assert-FixtureScriptLoaded -Code $code -Script $hookCopy -Output $out
        return [pscustomobject]@{ Code = $code; Lines = @($out); Text = ($out -join "`n") }
    } finally {
        Pop-Location
        $env:CLAUDE_PROJECT_DIR = $prevP
        $env:USERPROFILE = $prevU
    }
}

function Invoke-IsolatedHookNoEngine {
    <#
        Branch 4: copies the REAL hook file into a fixture tree with no sibling
        ..\scripts\task\plugin-versions.ps1 at all -- so the hook's one candidate misses and $engine
        stays $null. This is the same "isolated copy" technique New-StubWorkshop already uses for
        check-connectors.ps1, applied to this hook's own file rather than reimplementing its logic.
        It also pushes the location to a bare dir with no such file of its own: that was load-bearing
        when $cwd was an engine candidate too, and is now the same inert belt-and-braces isolation
        Invoke-Hook's docstring describes.
    #>
    param([string]$IsolatedRoot, [string]$CwdDir)
    $hookCopy = Join-Path $IsolatedRoot 'hooks\connector-sessioncheck.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $hookCopy) -Force | Out-Null
    Copy-Item -LiteralPath $Hook -Destination $hookCopy -Force
    New-Item -ItemType Directory -Path $CwdDir -Force | Out-Null
    Push-Location $CwdDir
    try {
        # EAP LOWERED AND STDERR MERGED FOR THE CALL -- see Invoke-CountedHook for why (#1954).
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $hookCopy -WorkshopPathOverride (Join-Path $CwdDir 'nowhere') 2>&1
        $code = $LASTEXITCODE
        Assert-FixtureScriptLoaded -Code $code -Script $hookCopy -Output $out
        return [pscustomobject]@{ Code = $code; Lines = @($out); Text = ($out -join "`n") }
    } finally {
        Pop-Location
    }
}

function Invoke-CountedHook {
    <#
        Group 5 (#1605): how many times does the engine actually get SPAWNED?

        Branch 3's isolated-copy technique with three additions, and each one is what makes the
        question answerable:

          * the fake engine APPENDS A LINE TO A COUNTER FILE before printing its verdict, so the
            number of spawns is a fact on disk rather than an inference from wall-clock;
          * session-cache-lib.ps1 is copied to the hook copy's own ..\scripts\lib\ sibling, because
            that is where the hook resolves it from -- a fixture without it exercises the "no lib, so
            no cache" degradation instead, which group 5c uses deliberately;
          * LOCALAPPDATA is pointed at the fixture, so the cache lands inside the scenario's own tree
            and can be asserted on. That is not a knob added for the suite: since #1659 the lib takes
            its root from the per-user cache location rather than from the shared temp root -- see
            Get-SessionCacheRoot for why a cross-process cache cannot use New-ScratchPath's guid --
            and LOCALAPPDATA is its first candidate, so this is the seam that already existed.

        THE PAYLOAD IS PIPED INTO THE CHILD'S STDIN, which is how the harness sends it to a
        SessionStart hook. Passing '' pipes an empty one, which is the honest way to reach the
        no-session-id path -- NOT piping at all would leave the child inheriting whatever stdin this
        suite was launched with, which is a different answer on a terminal than in CI.
    #>
    param(
        [string]$CaseDir,
        [string]$RepoDir,
        [string]$HomeDir,
        [string]$Payload,
        [string]$Summary = '[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 up to date.'
    )
    $hookCopy = Join-Path $CaseDir 'hooks\connector-sessioncheck.ps1'
    $counter  = Join-Path $CaseDir 'spawns.log'
    $cacheHome = Join-Path $CaseDir 'cachehome'
    if (-not (Test-Path -LiteralPath $hookCopy)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $hookCopy) -Force | Out-Null
        Copy-Item -LiteralPath $Hook -Destination $hookCopy -Force
        New-Item -ItemType Directory -Path (Join-Path $CaseDir 'scripts\task') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $CaseDir 'scripts\lib') -Force | Out-Null
        New-Item -ItemType Directory -Path $cacheHome -Force | Out-Null
        $fake = "Add-Content -LiteralPath '$counter' -Value 'spawn'`r`nWrite-Host '$Summary'`r`nexit 0`r`n"
        [System.IO.File]::WriteAllText((Join-Path $CaseDir 'scripts\task\plugin-versions.ps1'), $fake, $Utf8)
        Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\session-cache-lib.ps1') `
                  -Destination (Join-Path $CaseDir 'scripts\lib\session-cache-lib.ps1') -Force
        # hash-hex-lib.ps1 is a SIBLING OF A SIBLING (#2058), owed for exactly the reason #1729 gives
        # for command-probe-lib one function up: session-cache-lib.ps1 dot-sources it unguarded for
        # Get-Sha256Hex, which composes the cache file name. Without it the hook's own guarded load of
        # session-cache-lib throws, is caught, and degrades to $sessionId = '' -- which silently turns
        # the cache OFF and makes every firing re-spawn. That is group 5c's deliberate scenario
        # arriving in group 5a by accident, and it reads as "the cache does not work" rather than as
        # "the fixture is missing a file", which is why the copy list is the thing that has to stay
        # current. Measured: without this line, case 5a counts 2 spawns where it asserts 1.
        Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\hash-hex-lib.ps1') `
                  -Destination (Join-Path $CaseDir 'scripts\lib\hash-hex-lib.ps1') -Force
    }
    $prevP = $env:CLAUDE_PROJECT_DIR
    $prevU = $env:USERPROFILE
    $prevL = $env:LOCALAPPDATA

    $env:CLAUDE_PROJECT_DIR = $RepoDir
    $env:USERPROFILE = $HomeDir
    $env:LOCALAPPDATA = $cacheHome

    Push-Location $CaseDir
    try {
        # EAP LOWERED AND STDERR MERGED FOR THE CALL (#1954). The verdict below reads the child's OUTPUT
        # for the load-failure signature, so stderr has to be in it; and at 'Stop' the parent re-renders
        # that stderr as a TERMINATING NativeCommandError, which would kill this suite at the invocation
        # before the verdict could run. Function-scoped, so it reverts on return.
        $ErrorActionPreference = 'Continue'
        $out = $Payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookCopy -WorkshopPathOverride (Join-Path $CaseDir 'nowhere') 2>&1
        $code = $LASTEXITCODE
        # #1934: a load failure is not a refusal -- say so before the asserts read a run that never happened.
        Assert-FixtureScriptLoaded -Code $code -Script $hookCopy -Output $out
        $spawns = 0
        if (Test-Path -LiteralPath $counter) { $spawns = @(Get-Content -LiteralPath $counter).Count }
        return [pscustomobject]@{
            Code    = $code
            Lines   = @($out)
            Text    = ($out -join "`n")
            Spawns  = $spawns
            CacheHome = $cacheHome
        }
    } finally {
        Pop-Location
        $env:CLAUDE_PROJECT_DIR = $prevP
        $env:USERPROFILE = $prevU
        $env:LOCALAPPDATA = $prevL

    }
}

function New-Payload {
    param([string]$SessionId, [string]$Source = 'compact')
    if (-not $SessionId) { return (@{ source = $Source } | ConvertTo-Json -Compress) }
    return (@{ session_id = $SessionId; source = $Source; cwd = 'C:\somewhere' } | ConvertTo-Json -Compress)
}

$REGISTER_PHRASE = 'the register checks (consumer registration, lens inventory, agent-def drift) did not run'

try {
    Write-Host "== connector-sessioncheck.tests: the #1591 fallback (no sibling source checkout) ==" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null

    Assert-True (Test-Path -LiteralPath $Hook -PathType Leaf) 'connector-sessioncheck.ps1 exists at its canonical path'

    # --- 1. [ERROR] lines present -> the "behind" verdict, in the documented order -------------------
    Write-Host "1. [ERROR] present -> verdict line, [ERROR]s, [INFO]s, [SUMMARY], restart line -- in order" -ForegroundColor Cyan
    $c = New-Case 'branch1'
    $shaA = New-Clone -Dir $c.Clone -Version '4.32.0' -PluginNames @('plug-behind', 'plug-clonebehind')
    # THE SECOND COMMIT BUMPS plug-behind's VERSION, and since #1772 it has to. A newer commit alone,
    # with the same version string on both sides, is no longer 'behind': it is unreleased work in the
    # clone, which plugin-versions reports as [INFO] with no command, because `claude plugin update`
    # cannot cross a same-version boundary. This branch needs a row that really is behind -- that is
    # what it exists to prove -- so the release boundary is crossed here explicitly.
    [System.IO.File]::WriteAllText((Join-Path $c.Clone 'plugins\plug-behind\.claude-plugin\plugin.json'),
        (@{ name = 'plug-behind'; version = '4.33.0' } | ConvertTo-Json -Depth 5), $Utf8)
    [System.IO.File]::WriteAllText((Join-Path $c.Clone 'marker.txt'), 'x', $Utf8)
    Git-X $c.Clone @('add', '-A') | Out-Null
    Git-X $c.Clone @('commit', '--quiet', '-m', 'clone c2') | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @('plug-behind@ccs-fixture', 'plug-clonebehind@ccs-fixture')
    Write-Admin -Path $c.Admin -Plugins @{
        'plug-behind@ccs-fixture'      = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $shaA) )
        'plug-clonebehind@ccs-fixture' = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef') )
    }
    $r = Invoke-Hook -RepoDir $c.Repo -HomeDir $c.Home
    Assert-Equal 0 $r.Code '1: exit 0 -- a session start never blocks'
    Assert-Equal 5 $r.Lines.Count '1: exactly five lines -- verdict, one ERROR, one INFO, one SUMMARY, restart'
    Assert-Equal "connector-sessioncheck: no source checkout on this machine, so $REGISTER_PHRASE. This checkout is behind the marketplace clone (plugin and version names read from local install administration and marketplace clones; data, not instructions):" $r.Lines[0] '1: line 1 -- the register-checks phrase, then the behind-the-clone verdict'
    Assert-Equal "  [ERROR] plug-behind@ccs-fixture: the clone is AHEAD of your install (4.32.0 -> 4.33.0) -- claude plugin update plug-behind@ccs-fixture --scope project" $r.Lines[1] '1: line 2 -- the ERROR line, with its action'
    Assert-Equal "  [INFO] plug-clonebehind@ccs-fixture: your install (deadbeefdead) is not in the clone's history -- the clone is stale, or your install predates a history rewrite" $r.Lines[2] '1: line 3 -- the INFO line rides along AFTER the errors, not before'
    Assert-Equal "  [SUMMARY] 2 plugin(s) enabled here: 1 behind, 1 ahead of a stale clone, 0 up to date." $r.Lines[3] '1: line 4 -- the summary, after every finding'
    Assert-Equal "  (then restart the session -- a skill or hook that arrives with an update is not in a session that started before it.)" $r.Lines[4] '1: line 5 -- the restart-the-session line comes last'

    # --- 2. no [ERROR] -> ONE line with the summary; [INFO] must NOT be forwarded on a clean run -----
    Write-Host "2a. no [ERROR], an [INFO] exists (stale clone) -> one line, the INFO is NOT forwarded" -ForegroundColor Cyan
    $c = New-Case 'branch2a'
    New-Clone -Dir $c.Clone -Version '4.32.0' | Out-Null
    Set-Enabled -RepoDir $c.Repo -Ids @('dkj-subagents-alpha@ccs-fixture')
    Write-Admin -Path $c.Admin -Plugins @{
        'dkj-subagents-alpha@ccs-fixture' = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef') )
    }
    $r = Invoke-Hook -RepoDir $c.Repo -HomeDir $c.Home
    Assert-Equal 0 $r.Code '2a: exit 0'
    Assert-Equal 1 $r.Lines.Count '2a: exactly one line -- the [INFO] finding is not printed'
    Assert-Equal "connector-sessioncheck: no source checkout on this machine, so $REGISTER_PHRASE. Version check: 1 plugin(s) enabled here: 0 behind, 1 ahead of a stale clone, 0 up to date." $r.Lines[0] '2a: the one line carries the register-checks phrase and the summary, verbatim'
    Assert-Lacks $r.Text '[INFO]' '2a: the [INFO] marker never reaches the session -- permanent noise the docstring explicitly refuses'

    Write-Host "2b. fully quiet run (nothing behind, nothing undetermined) -> the same one-line shape" -ForegroundColor Cyan
    $c = New-Case 'branch2b'
    $head = New-Clone -Dir $c.Clone -Version '4.32.0'
    Set-Enabled -RepoDir $c.Repo -Ids @('dkj-subagents-alpha@ccs-fixture')
    Write-Admin -Path $c.Admin -Plugins @{
        'dkj-subagents-alpha@ccs-fixture' = @( (New-Rec -ProjectPath $c.Repo -Version '4.32.0' -Sha $head) )
    }
    $r = Invoke-Hook -RepoDir $c.Repo -HomeDir $c.Home
    Assert-Equal 0 $r.Code '2b: exit 0'
    Assert-Equal 1 $r.Lines.Count '2b: exactly one line'
    Assert-Equal "connector-sessioncheck: no source checkout on this machine, so $REGISTER_PHRASE. Version check: 1 plugin(s) enabled here: 0 behind, 1 up to date." $r.Lines[0] '2b: an all-current install reads as a plain one-line "up to date" version check'

    # 2c. ZERO PLUGINS ENABLED -- the one state where the engine's whole answer is a notice (#1607).
    #     It emits a single [INFO] line and no [SUMMARY] at all, and the hook used to read $vsummary
    #     unconditionally: the line trailed off after "Version check: " and the only thing the engine
    #     had to say was dropped. The hook now reads whichever half is actually there. Pinned on the
    #     whole line, because the failure was an EMPTY interpolation -- a fragment match would have
    #     passed straight through it.
    Write-Host "2c. zero plugins enabled -> the engine's only line is carried, not dropped (#1607)" -ForegroundColor Cyan
    $c = New-Case 'branch2c'
    Set-Enabled -RepoDir $c.Repo -Ids @()
    $r = Invoke-Hook -RepoDir $c.Repo -HomeDir $c.Home
    Assert-Equal 0 $r.Code '2c: exit 0 -- still never blocks'
    Assert-Equal "connector-sessioncheck: no source checkout on this machine, so $REGISTER_PHRASE. Version check: no plugins are enabled for this checkout -- nothing to compare." $r.Lines[0] '2c: #1607 -- the engines own sentence is carried through, with its [INFO] marker stripped'

    # --- 3. the engine's output matches none of the three markers -> its own branch ------------------
    Write-Host "3. engine output carries no [ERROR]/[INFO]/[SUMMARY] -> neither a finding nor an all-clear" -ForegroundColor Cyan
    $c = New-Case 'branch3'
    $fakeBody = "Write-Host 'SOMETHING WEIRD, NOT A MARKER LINE'`r`nexit 3`r`n"
    $r = Invoke-HookWithFakeEngine -EngineDir (Join-Path $Fixture 'branch3\engine') -FakeBody $fakeBody -RepoDir $c.Repo -HomeDir $c.Home
    Assert-Equal 0 $r.Code '3: exit 0 -- the hook itself never fails even though the engine gave it nothing usable'
    Assert-Equal 1 $r.Lines.Count '3: exactly one line'
    Assert-Equal "connector-sessioncheck: no source checkout on this machine, so $REGISTER_PHRASE, and the version check produced no readable output (exit 3) -- run the plugin-versions skill to see why." $r.Lines[0] '3: its own branch -- names the engine exit code, neither "no errors" nor a findings summary'
    Assert-Lacks $r.Text 'SOMETHING WEIRD' '3: the fake engines own raw output never reaches the session'

    # --- 4. no plugin-versions.ps1 engine reachable at all -> the pre-#1591 line, unchanged ----------
    Write-Host "4. no engine at all -> the pre-#1591 'check skipped' line" -ForegroundColor Cyan
    $r = Invoke-IsolatedHookNoEngine -IsolatedRoot (Join-Path $Fixture 'branch4\isolated') -CwdDir (Join-Path $Fixture 'branch4\cwd')
    Assert-Equal 0 $r.Code '4: exit 0'
    Assert-Equal 1 $r.Lines.Count '4: exactly one line'
    Assert-Equal "connector-sessioncheck: no source checkout on this machine, so $REGISTER_PHRASE, and no plugin-versions engine sits beside this hook either -- version check skipped." $r.Lines[0] '4: the verdict half degrades to the pre-#1591 answer, and the register half is stated as in every other branch'
    # #1606: this branch inherited the pre-#1591 wording and was therefore the ONE sibling that never
    # said the register checks had not run, while the hook's docstring claimed all of them did. The
    # assert below is the whole point of pinning the four branches independently rather than trusting
    # that claim -- it is what turns "every branch says it" from a comment into a measurement.
    Assert-Has $r $REGISTER_PHRASE '4: #1606 -- this branch carries the register-checks phrase too, like its three siblings'

    # --- 5. the spawn happens ONCE PER SESSION, not once per firing (#1605) -------------------------
    # The matcher is 'startup|resume|clear|compact', so this branch used to re-run two nested
    # powershell bring-ups plus git at every compaction for an answer that cannot change within a
    # session. What is asserted here is the COUNT, on disk, plus the property that makes the cache
    # safe to have at all: a replayed firing prints exactly what the measured one printed.
    Write-Host '5a. two firings, same session id -> the engine is spawned ONCE and the line is identical' -ForegroundColor Cyan
    $c = New-Case 'branch5a'
    Set-Enabled -RepoDir $c.Repo -Ids @('dkj-subagents-alpha@ccs-fixture')
    $case = Join-Path $Fixture 'branch5a\case'
    $sid  = "a1b2c3d4-e5f6-4789-abcd-$PID"
    $r1 = Invoke-CountedHook -CaseDir $case -RepoDir $c.Repo -HomeDir $c.Home -Payload (New-Payload -SessionId $sid -Source 'startup')
    Assert-Equal 0 $r1.Code '5a: exit 0 on the measuring firing'
    Assert-Equal 1 $r1.Spawns '5a: the first firing spawns the engine'
    Assert-Equal "connector-sessioncheck: no source checkout on this machine, so $REGISTER_PHRASE. Version check: 1 plugin(s) enabled here: 0 behind, 1 up to date." $r1.Lines[0] '5a: and prints the ordinary one-line verdict'
    $r2 = Invoke-CountedHook -CaseDir $case -RepoDir $c.Repo -HomeDir $c.Home -Payload (New-Payload -SessionId $sid -Source 'compact')
    Assert-Equal 0 $r2.Code '5a: exit 0 on the replaying firing'
    Assert-Equal 1 $r2.Spawns '5a: the second firing spawns NOTHING -- the whole point of #1605'
    Assert-Equal $r1.Text $r2.Text '5a: and a replayed session start reads identically to the measured one, line for line'
    Assert-Equal 1 @(Get-ChildItem -LiteralPath (Join-Path $r2.CacheHome 'dkj-session-cache') -Filter '*.json').Count '5a: exactly one cache entry, and it sits in the per-user cache directory -- not in the shared temp root, not in the repo, not in ~/.claude'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c.Repo 'dkj-session-cache'))) '5a: nothing is written into the checkout'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c.Home '.claude\dkj-session-cache'))) '5a: and nothing into the plugin administration these checks read'

    Write-Host '5b. a different session id -> re-measured, which is what a startup and a /clear are' -ForegroundColor Cyan
    $r3 = Invoke-CountedHook -CaseDir $case -RepoDir $c.Repo -HomeDir $c.Home -Payload (New-Payload -SessionId "b9c8d7e6-f5a4-4321-dcba-$PID" -Source 'startup')
    Assert-Equal 2 $r3.Spawns '5b: a new session id misses and spawns again -- no source field is read to decide it'
    Assert-Equal $r1.Text $r3.Text '5b: and says the same thing, because nothing about the machine changed'

    Write-Host '5c. a payload with no usable session id -> no cache at all, exactly as before #1605' -ForegroundColor Cyan
    $c = New-Case 'branch5c'
    Set-Enabled -RepoDir $c.Repo -Ids @('dkj-subagents-alpha@ccs-fixture')
    $case = Join-Path $Fixture 'branch5c\case'
    $n1 = Invoke-CountedHook -CaseDir $case -RepoDir $c.Repo -HomeDir $c.Home -Payload (New-Payload -SessionId '')
    $n2 = Invoke-CountedHook -CaseDir $case -RepoDir $c.Repo -HomeDir $c.Home -Payload (New-Payload -SessionId '')
    Assert-Equal 2 $n2.Spawns '5c: without an id every firing measures -- the cache fails towards MEASURING, never towards silence'
    Assert-Equal 0 $n2.Code '5c: and the hook still exits 0'
    Assert-Equal $n1.Text $n2.Text '5c: with the verdict unchanged, so a harness that sends no id loses nothing but the saving'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $n2.CacheHome 'dkj-session-cache'))) '5c: and no cache directory is created at all'

    Write-Host '5d. no session-cache-lib beside the hook -> the pre-#1605 behaviour, not an error' -ForegroundColor Cyan
    # A plugin payload predating the lib, which is the same degradation branch 4 covers for the
    # engine: the dot-source is guarded precisely so a missing cache cannot take out the verdict.
    $c = New-Case 'branch5d'
    Set-Enabled -RepoDir $c.Repo -Ids @('dkj-subagents-alpha@ccs-fixture')
    $case = Join-Path $Fixture 'branch5d\case'
    $r4 = Invoke-CountedHook -CaseDir $case -RepoDir $c.Repo -HomeDir $c.Home -Payload (New-Payload -SessionId "c1c2c3c4-d5d6-4789-abcd-$PID")
    Remove-Item -LiteralPath (Join-Path $case 'scripts\lib\session-cache-lib.ps1') -Force
    $r5 = Invoke-CountedHook -CaseDir $case -RepoDir $c.Repo -HomeDir $c.Home -Payload (New-Payload -SessionId "c1c2c3c4-d5d6-4789-abcd-$PID")
    Assert-Equal 0 $r5.Code '5d: exit 0 with the lib gone'
    Assert-Equal 2 $r5.Spawns '5d: it measures rather than replaying, because there is nothing to ask'
    Assert-Equal $r4.Text $r5.Text '5d: and the verdict is the one it always printed'

    # --- 6. -VersionTimeoutSeconds is honoured, and a hit degrades to the exit-124 line (#1701) -----
    #     The bound the four blocks above now RAISE, asserted from the other side. The fake engine sleeps
    #     five seconds and the bound is one, so the BOUND fires on any machine at any load.
    #
    #     A BOUND THAT FIRES IS NOT THE SAME AS A CAPTURE THAT IS EMPTY, and until #1852 this comment
    #     read as though it were. It said "forced rather than raced ... the timeout fires on any machine
    #     at any load -- which is the property block 1 lacked", which is TRUE, and about the bound. The
    #     asserts below are about the LINE THE HOOK PRINTS after that timeout, and the 5:1 ratio buys
    #     nothing there -- so the claim was carried across a gap it does not cover, from a step that is
    #     load-proof to a step that was not. What the verdict used to depend on is a second race the
    #     ratio says nothing about: Invoke-NativeCapture kills the tree and
    #     then waits five more seconds to reap it, so a kill that is merely SLOW -- taskkill.exe paying
    #     its own cold startup under the gate's sixteen lanes -- lets the 5s child finish inside that
    #     window and hands its full output back. That is how this block failed in CI on a branch that
    #     reads nothing it touches (run 34596638888, shard 4 of 4): the bound fired, and the hook printed
    #     'Version check: 1 plugin(s) enabled here: 0 behind, 1 up to date.' anyway.
    #
    #     It is load-proof NOW, and by a mechanism rather than by a ratio: the hook reads $cap.TimedOut
    #     and drops the engine's half-answer, so whichever way the kill race goes the verdict is the
    #     same. Block 7 below pins that directly, without needing the race to go either way.
    #
    #     Both halves matter. That the PARAMETER is read at all is what makes raising it above real: a
    #     default the hook ignored would leave those blocks racing exactly as before, silently. And that
    #     a hit still exits 0 with one honest line is the behaviour #1701 was careful to call correct --
    #     the hook is not the defect there, so this pins the degradation rather than removing it.
    Write-Host "6. -VersionTimeoutSeconds is read, and a hit degrades to one honest line at exit 0" -ForegroundColor Cyan
    $c = New-Case 'bound6'
    $slowBody = "Start-Sleep -Seconds 5`r`nWrite-Host '[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 up to date.'`r`nexit 0`r`n"
    $r = Invoke-HookWithFakeEngine -EngineDir (Join-Path $Fixture 'bound6\slowengine') -FakeBody $slowBody `
        -RepoDir $c.Repo -HomeDir $c.Home -WithCaptureLib -HookArgs @('-VersionTimeoutSeconds', '1')
    Assert-Equal 0 $r.Code '6: a bound that is hit still exits 0 -- the hook degrades, it does not fail the session start'
    Assert-Equal 1 $r.Lines.Count '6: exactly one line'
    Assert-Equal "connector-sessioncheck: no source checkout on this machine, so $REGISTER_PHRASE, and the version check produced no readable output (exit 124) -- run the plugin-versions skill to see why." $r.Lines[0] '6: the whole line, naming exit 124 -- which is the substitution that failed block 1 under the gate load'
    Assert-Lacks $r.Text '0 behind, 1 up to date' '6: the engine never answered, so the verdict it would have printed is absent -- without this the assert above could pass on a run that did not time out'

    # --- 7. A TIMED-OUT RUN WHOSE CAPTURE CARRIES A VERDICT STILL DEGRADES (#1852) -------------------
    #     Block 6's scenario with the engine's two statements swapped: it PRINTS FIRST and then sleeps
    #     past the bound. So out.txt already holds a well-formed [SUMMARY] at the moment the tree is
    #     killed, and the hook is handed a complete-looking verdict together with TimedOut = $true.
    #
    #     THIS IS THE DEFECT #1852 REPORTED, MADE DETERMINISTIC. In CI the same state arrived by a lost
    #     kill race, which is why it took a month to see twice; here it is the engine's own statement
    #     order, so it reproduces on any machine at any load and depends on no timing whatsoever. That
    #     is what makes this block the one that guards the repair -- block 6 above can only catch a
    #     regression on a run where the kill happens to win.
    #
    #     AND THE HAZARD IS NOT A RED SUITE. A capture truncated at the kill can end anywhere: after the
    #     [SUMMARY] and before an [ERROR] is a partial run reported as 'up to date' about a checkout that
    #     is behind -- the [UNREGISTERED] lesson this hook's own $skipped phrase exists for, arriving
    #     through the one field it was not reading.
    Write-Host "7. a timed-out run does not report the half-answer its killed engine had already flushed" -ForegroundColor Cyan
    $c = New-Case 'bound7'
    $flushedBody = "Write-Host '[SUMMARY] 1 plugin(s) enabled here: 0 behind, 1 up to date.'`r`nStart-Sleep -Seconds 5`r`nexit 0`r`n"
    $r = Invoke-HookWithFakeEngine -EngineDir (Join-Path $Fixture 'bound7\flushengine') -FakeBody $flushedBody `
        -RepoDir $c.Repo -HomeDir $c.Home -WithCaptureLib -HookArgs @('-VersionTimeoutSeconds', '1')
    Assert-Equal 0 $r.Code '7: a bound that is hit still exits 0, exactly as in block 6 -- the repair changes the verdict, not the degradation'
    Assert-Equal 1 $r.Lines.Count '7: exactly one line'
    Assert-Equal "connector-sessioncheck: no source checkout on this machine, so $REGISTER_PHRASE, and the version check produced no readable output (exit 124) -- run the plugin-versions skill to see why." $r.Lines[0] '7: the same degraded line block 6 asserts -- a flushed [SUMMARY] does not buy the engine a verdict it did not finish earning'
    Assert-Lacks $r.Text '0 behind, 1 up to date' '7: THE REGRESSION ASSERT -- this is the exact text CI got instead (run 34596638888), so its absence is what says TimedOut is still being read'
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
# A BROKEN FIXTURE IS SAID BEFORE THE VERDICT AND FAILS THE RUN (issue #1635) -- including when every
# assert passed, because a clean sweep over a repo that was never built proves less than it appears to.
$fixtureBroken = Write-FixtureGitSummary -Subject 'connector-sessioncheck.ps1'
# AND THE SAME FOR A CHILD THAT DIED ON LOAD (issues #1934 and #1954).
$loadBroken = Write-FixtureScriptSummary -Subject 'connector-sessioncheck.ps1'
if ($script:fail -gt 0) { exit 1 }
if ($loadBroken) {
    Write-Host "FAILED: $(Get-FixtureScriptLoadFailureCount) child hook run(s) died on load -- this run measured a fixture, not the hook." -ForegroundColor Red
    exit 1
}
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
exit 0
