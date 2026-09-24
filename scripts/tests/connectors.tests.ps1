<#
.SYNOPSIS
    Regression tests for the connectors check (scripts/sync/check-connectors.ps1) and the
    SessionStart hook (connector-sessioncheck.ps1).

.DESCRIPTION
    Dependency-free: no Pester, only PowerShell. Integration style -- runs the real scripts
    in a CHILD PROCESS against throwaway fixtures in the temp folder and asserts on exit code + output.
    Register checks run with -SkipDrift and -SkipVersions unless a test specifically covers that
    code path (the drift check has its own suite; no plugin administration exists on CI).

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/connectors.tests.ps1

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\sync\check-connectors.ps1'
$Hook     = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\connector-sessioncheck.ps1'
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "connectors-test-fixture-$PID-$([guid]::NewGuid().ToString('n'))"
# A scratch '~/.claude' for the isolated hook calls (9a/9e) -- no marketplace clone, no install
# administration, so plugin-versions.ps1's fallback lands deterministically on "indeterminate"
# regardless of what this machine's real install/clone actually look like.
$HookHome = Join-Path ([System.IO.Path]::GetTempPath()) "connectors-hook-home-$PID-$([guid]::NewGuid().ToString('n'))"
# The fake 'gh' scenario 13 drives -RemoteRunners against (#1808), plus the log of every call it
# makes -- the log is what lets 13a assert the COST claim (nothing is called when the switch is off)
# rather than merely stating it. Declared here so the closing finally can clear both and put PATH back.
$FakeBin  = Join-Path ([System.IO.Path]::GetTempPath()) "connectors-fakegh-$PID-$([guid]::NewGuid().ToString('n'))"
$GhCalls  = Join-Path ([System.IO.Path]::GetTempPath()) "connectors-ghcalls-$PID-$([guid]::NewGuid().ToString('n')).log"
# A wrapper directory git-init'd in its OWN right, for check 1b's arm-4 nested-checkout scenarios
# (#1821): the consumer fixture is built one or more levels INSIDE it via New-FixtureConsumer/
# New-FixtureManifest's -Root, so the folder resolves inside a git work tree without BEING that work
# tree's root. Never $Fixture's own parent -- that parent is the shared system temp folder.
$NestedFixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "connectors-nested-fixture-$PID-$([guid]::NewGuid().ToString('n'))"
# Scenario 14's consumers, and the ONE fixture root that cannot live in the system temp folder (#2298):
# a localCheckout is relative to the repo root and the scope guardrail refuses anything outside
# '$RepoRoot/../..', which temp is. -ConsumerPathOverride is the usual way past that and it points EVERY
# manifest at one directory, so it cannot express a register whose connectors are in different lens-naming
# states -- which is the whole subject of 14. So it sits BESIDE the repo, two levels up: inside the allowed
# scope, outside the work tree (so 'git status' is untouched), and removed in the closing finally.
$LensFixtureRoot = Join-Path (Resolve-Path -LiteralPath (Join-Path $RepoRoot '..\..')).Path "connectors-lens-fixture-$PID-$([guid]::NewGuid().ToString('n'))"
$PrevPath = $env:PATH

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Assert-Match {
    param([string]$Pattern, [string]$Text, [string]$Name)
    if ($Text -match $Pattern) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         pattern not found: '$Pattern'" -ForegroundColor Red
    }
}

function Assert-NotMatch {
    param([string]$Pattern, [string]$Text, [string]$Name)
    if ($Text -notmatch $Pattern) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         pattern found that should not be there: '$Pattern'" -ForegroundColor Red
    }
}

function Invoke-Ps {
    param([string]$Path, [string[]]$ScriptArgs)
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @ScriptArgs
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

# Runs the hook with CLAUDE_PROJECT_DIR and USERPROFILE pinned to a scratch repo/home for the
# child process (Get-InstallRecord's own docstring endorses redirecting USERPROFILE this way).
# NEEDED SINCE #1591: when no workshop is found, the hook now falls back to running
# plugin-versions.ps1 -Brief using the AMBIENT environment (it takes no -RootOverride/
# -UserHomeOverride of its own) -- so a call to Invoke-Ps alone reads THIS machine's real install
# administration and marketplace clone, which is why 9a/9e stopped being deterministic the moment
# that fallback was added.
function Invoke-HookIsolated {
    param([string]$RepoDir, [string]$HomeDir, [string[]]$ScriptArgs)
    $prevP = $env:CLAUDE_PROJECT_DIR
    $prevU = $env:USERPROFILE
    $env:CLAUDE_PROJECT_DIR = $RepoDir
    $env:USERPROFILE = $HomeDir
    try {
        return Invoke-Ps $Hook $ScriptArgs
    } finally {
        $env:CLAUDE_PROJECT_DIR = $prevP
        $env:USERPROFILE = $prevU
    }
}

# Builds a fixture consumer with settings.json + given extensions. -Layout chooses where the
# lenses live: 'legacy' (.claude/extensions/) or 'plugins'
# (.claude/plugins/claude-specialists/dkj-subagents-alpha/, since life-hub parity).
# -Root defaults to $Fixture (every pre-#1821 call site) and exists so the arm-4 nested-checkout
# scenarios (#1821) can build a consumer at a path that itself sits INSIDE another, separately
# git-init'd directory -- $Fixture's own parent is the shared system temp folder, which is not a
# place this suite may git-init.
function New-FixtureConsumer {
    param([string[]]$ExtensionIds, [bool]$PluginEnabled = $true, [string]$Layout = 'legacy', [string]$Root = $Fixture)
    if (Test-Path -LiteralPath $Root) { Remove-Item -Recurse -Force -LiteralPath $Root }
    $extDir = if ($Layout -eq 'plugins') {
        Join-Path $Root '.claude\plugins\claude-specialists\dkj-subagents-alpha'
    } else {
        Join-Path $Root '.claude\extensions'
    }
    New-Item -ItemType Directory -Path $extDir -Force | Out-Null
    $enabled = if ($PluginEnabled) { '{ "dkj-subagents-alpha@dkj-claude-plugins": true }' } else { '{ }' }
    $settings = '{ "enabledPlugins": ' + $enabled + ' }'
    [System.IO.File]::WriteAllText((Join-Path $Root '.claude\settings.json'), $settings)
    foreach ($id in $ExtensionIds) {
        $p = Join-Path $extDir "$id-extension.md"
        [System.IO.File]::WriteAllText($p, "---`nid: $($id.Split('-')[1])`ngroup: $($id.Split('-')[0])`n---`nfixture")
    }
}

# Writes a fixture manifest (per-repo schema) and returns its path.
function New-FixtureManifest {
    param(
        [string[]]$Extensions,
        # Deliberately untyped: localCheckout is one relative path OR a list of candidates (#1524), and
        # a [string[]] here would silently turn every single-path case into a one-element array, so the
        # string form -- what every manifest but the two BWJ ones still carries -- would stop being
        # exercised at all.
        $LocalCheckout = 'nonexistent-fixture-path',
        [string]$Plugin = 'dkj-subagents-alpha@dkj-claude-plugins',
        # The register's own name for the consumer. A parameter since #1808: it is what the network
        # read turns into an API owner and name, so a scenario has to be able to hand it a slug the
        # guard must refuse.
        [string]$Repo = 'fixture/consumer',
        # Mirrors New-FixtureConsumer's -Root (#1821): the nested-checkout scenarios write their
        # manifest beside a consumer that does not live at $Fixture.
        [string]$Root = $Fixture
    )
    $mfPath = Join-Path $Root 'manifest.json'
    $obj = [ordered]@{
        repo          = $Repo
        visibility    = 'private'
        localCheckout = $LocalCheckout
        plugins       = @(
            [ordered]@{
                id         = $Plugin
                extensions = $Extensions
            }
        )
        notes         = ''
    }
    [System.IO.File]::WriteAllText($mfPath, ($obj | ConvertTo-Json -Depth 5))
    return $mfPath
}

# Builds a stub workshop (for the hook tests): marker + a fake check script with fixed output.
function New-StubWorkshop {
    param([string]$Name, [string[]]$OutputLines, [int]$ExitCode, [bool]$ValidMarker = $true)
    $root = Join-Path $Fixture $Name
    New-Item -ItemType Directory -Path (Join-Path $root 'scripts\sync') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root '.claude-plugin') -Force | Out-Null
    $markerName = if ($ValidMarker) { 'dkj-claude-plugins' } else { 'fake-marketplace' }
    [System.IO.File]::WriteAllText((Join-Path $root '.claude-plugin\marketplace.json'), ('{ "name": "' + $markerName + '" }'))
    $body = (($OutputLines | ForEach-Object { 'Write-Host "' + $_ + '"' }) -join "`r`n") + "`r`nexit $ExitCode`r`n"
    [System.IO.File]::WriteAllText((Join-Path $root 'scripts\sync\check-connectors.ps1'), $body)
    return $root
}

# Overwrites the fixture's settings.json to enable exactly these ids (helper for check 5 / the
# [UNLISTED] scenarios, #1775). New-FixtureConsumer only ever enables the one hardcoded plugin id
# ('dkj-subagents-alpha@dkj-claude-plugins'), and check 5's whole subject is a SECOND id sitting
# beside it that the manifest does not list -- so those scenarios need a settings.json this helper can
# shape freely, written AFTER New-FixtureConsumer (which rebuilds $Fixture from scratch and would wipe
# this file if called afterwards).
function Set-FixtureEnabledPlugins {
    param([string[]]$Ids)
    $obj = [ordered]@{}
    foreach ($id in $Ids) { $obj[$id] = $true }
    $enabled = if ($Ids.Count -eq 0) { '{ }' } else { ($obj | ConvertTo-Json -Compress) }
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude\settings.json'), ('{ "enabledPlugins": ' + $enabled + ' }'))
}

# Turns $At (default $Fixture) into a real git work tree (for check 1b, #1821), optionally with an
# 'origin' remote. NO NETWORK: 'git init' and 'git remote add' only ever write local .git config, and
# the URL passed in is never fetched from or pushed to -- check 1b itself only ever reads .git/config
# via 'remote get-url'. Called AFTER New-FixtureConsumer, which rebuilds $Fixture from scratch and
# would wipe a '.git' folder written before it. Same '2>$null' + $LASTEXITCODE idiom
# check-connectors.ps1's own check 1b uses for the identical local git calls (see its comment on why
# this is not routed through native-capture-lib.ps1: that lib exists to bound a call that LEAVES the
# machine).
# -At exists for the arm-4 nested-checkout scenarios (#1821): there the git work tree is init'd one
# level ABOVE the actual consumer folder, on a dedicated wrapper directory that is not $Fixture at
# all -- $Fixture's own parent is the shared system temp folder, which is not a place this suite may
# git-init.
function Set-FixtureGitCheckout {
    param([string]$OriginUrl = '', [string]$At = $Fixture)
    & git -C $At init -q 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git init failed in fixture ($At)" }
    if ($OriginUrl) {
        & git -C $At remote add origin $OriginUrl 2>$null
        if ($LASTEXITCODE -ne 0) { throw "git remote add origin failed in fixture ($At)" }
    }
}

try {
    Write-Host "== connectors.tests ==" -ForegroundColor Cyan
    # -UserHomeOverride pins the USER layer of the settings chain to a dir that does not exist (inbound
    # #294). The enable state is now read from the whole chain, so without this every case would inherit
    # whatever the machine running the suite has enabled globally -- and case 3 below, which asserts that
    # a NOT-enabled plugin is an error, would silently invert on such a machine.
    $base = @('-SkipDrift', '-SkipVersions', '-UserHomeOverride', (Join-Path $Fixture 'no-user-home'))

    # --- 1. Happy path: everything present and enabled -> exit 0 -------------------------------------
    New-FixtureConsumer -ExtensionIds @('06-16', '06-17')
    $mf = New-FixtureManifest -Extensions @('06-16', '06-17')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'happy path: exit code 0'
    Assert-Match '\[OK\]\s+plugin is enabled' $r.Out 'happy path: enabled check OK'
    Assert-Match 'all 2 registered extensions present' $r.Out 'happy path: extensions OK'
    Assert-NotMatch 'manifest synced at' $r.Out 'happy path: no more manifest-version INFO (register slimming)'

    # --- 1b. New layout: lenses on the plugin path -> same happy path -----------------------
    New-FixtureConsumer -ExtensionIds @('06-16', '06-17') -Layout 'plugins'
    $mf = New-FixtureManifest -Extensions @('06-16', '06-17')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'plugin path: exit code 0'
    Assert-Match 'all 2 registered extensions present' $r.Out 'plugin path: extensions OK'

    # --- 1c. Check 1b (#1821), arm 1: origin agrees with the manifest, HTTPS shape -> silent, ordinary
    #      verdicts still print. Covers the first of the two URL shapes the parse regex handles.
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureGitCheckout -OriginUrl 'https://github.com/acme-org/widgets.git'
    $mf = New-FixtureManifest -Extensions @('06-16') -Repo 'acme-org/widgets'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'origin agrees (https): exit code 0'
    Assert-Match '\[OK\]\s+plugin is enabled' $r.Out 'origin agrees (https): ordinary verdicts still print'
    Assert-Match 'all 1 registered extensions present' $r.Out 'origin agrees (https): extensions OK still prints'
    Assert-NotMatch "could not read this checkout's own git identity" $r.Out 'origin agrees (https): no arm-4 SKIP'
    Assert-NotMatch 'differs from the manifest' $r.Out 'origin agrees (https): no arm-2 SKIP'
    Assert-NotMatch "this checkout's 'origin' is" $r.Out 'origin agrees (https): no arm-3 ERROR'

    # --- 1d. Check 1b, arm 1 again: SSH shape, no '.git' suffix -> same silent agreement -------------
    #      Nothing else pins that the parse handles this shape too.
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureGitCheckout -OriginUrl 'git@github.com:acme-org/widgets'
    $mf = New-FixtureManifest -Extensions @('06-16') -Repo 'acme-org/widgets'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'origin agrees (ssh): exit code 0'
    Assert-Match '\[OK\]\s+plugin is enabled' $r.Out 'origin agrees (ssh): ordinary verdicts still print'
    Assert-NotMatch "this checkout's 'origin' is" $r.Out 'origin agrees (ssh): no arm-3 ERROR'

    # --- 1d2. Check 1b, arm 1 again: the THIRD URL shape, 'ssh://git@github.com/...' -- a valid,
    #      not-rare remote shape the parse used to fall through on unasked (Victor's finding, #1821).
    #      1c/1d already pin the other two; this pins the parse on all three rather than two of three.
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureGitCheckout -OriginUrl 'ssh://git@github.com/acme-org/widgets.git'
    $mf = New-FixtureManifest -Extensions @('06-16') -Repo 'acme-org/widgets'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'origin agrees (ssh://): exit code 0'
    Assert-Match '\[OK\]\s+plugin is enabled' $r.Out 'origin agrees (ssh://): ordinary verdicts still print'
    Assert-NotMatch "this checkout's 'origin' is" $r.Out 'origin agrees (ssh://): no arm-3 ERROR (the shape used to fall through unrecognised)'

    # --- 1e. Check 1b, arm 3: a GENUINE mismatch -- this is the whole point of #1821. The fixture is
    #      set up so that, WITHOUT check 1b's 'continue', two of the ordinary verdicts below would
    #      ALSO have fired here: the plugin is disabled (-> '[ERROR] ... is NOT (or no longer)
    #      enabled') and the one registered extension is actually present on disk (-> '[OK] all 1
    #      registered extensions present'). Neither may print: the whole defect #1821 was filed over
    #      is a register printing confident, true-about-the-folder, false-about-the-repo verdicts, and
    #      this is the regression guard that a future edit cannot quietly drop the 'continue' and
    #      still pass -- if it did, the two Assert-NotMatch below would fail.
    New-FixtureConsumer -ExtensionIds @('06-16') -PluginEnabled $false
    Set-FixtureGitCheckout -OriginUrl 'https://github.com/other-org/gadgets.git'
    $mf = New-FixtureManifest -Extensions @('06-16') -Repo 'acme-org/widgets'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'origin mismatch: exit code 1'
    Assert-Match '\[ERROR\]' $r.Out 'origin mismatch: an ERROR is printed'
    Assert-Match 'other-org/gadgets' $r.Out 'origin mismatch: the ERROR names the origin slug'
    Assert-Match 'acme-org/widgets' $r.Out 'origin mismatch: the ERROR names the manifest slug'
    Assert-NotMatch 'is NOT \(or no longer\) enabled' $r.Out 'origin mismatch: the withheld plugin-enabled ERROR never prints'
    Assert-NotMatch 'registered extensions present' $r.Out 'origin mismatch: the withheld extensions OK never prints'

    # --- 1f. Check 1b, arm 2: this repo's OWN rename history landing on a transfer redirect ---------
    #      Depends on the real, current values scripts\repo-config.ps1 states for THIS repo (the same
    #      dependency test 12h below already carries for check 6): Get-RepoName() is
    #      'DKJ-Solutions/dkj-claude-plugins' and Get-RetiredRepoNames() lists 'claude-code-specialists'
    #      (the pre-#1769 name). So a manifest naming this repo's CURRENT slug, checked out from an
    #      origin that still names the RETIRED slug, is exactly the transfer-redirect case arm 2 exists
    #      for -- and is reproduced here rather than contorted through New-StubWorkshop, because it is
    #      the one case that genuinely needs $ThisRepoSlug to equal the manifest's 'repo', which only
    #      this tree's own repo-config.ps1 can supply.
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureGitCheckout -OriginUrl 'https://github.com/DKJ-Solutions/claude-code-specialists.git'
    $mf = New-FixtureManifest -Extensions @('06-16') -Repo 'DKJ-Solutions/dkj-claude-plugins'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'own rename history: exit code 0 (no false alarm)'
    Assert-Match '\[SKIP\]' $r.Out 'own rename history: a SKIP is printed'
    Assert-Match 'differs from the manifest' $r.Out 'own rename history: names it as a transfer redirect'
    Assert-Match 'git -C <this checkout> remote set-url origin https://github\.com/DKJ-Solutions/dkj-claude-plugins\.git' $r.Out 'own rename history: names the one command that ends it'
    Assert-Match '\[OK\]\s+plugin is enabled' $r.Out 'own rename history: proceeds exactly as on agreement'
    Assert-NotMatch "this checkout's 'origin' is" $r.Out 'own rename history: no arm-3 ERROR'
    # THE WORDING IS SOFTENED ON PURPOSE (#1821, Edith's finding): this run makes no network call, so
    # it cannot CONFIRM a transfer redirect -- only that the mismatch is CONSISTENT with one. Pinned
    # here so a future edit cannot drift the claim back to something the run never measured.
    Assert-Match 'consistent with a transfer redirect rather than confirmed as one' $r.Out 'own rename history: the softened claim is pinned'
    Assert-Match 'since this run makes no network call' $r.Out 'own rename history: and names why it cannot go further'
    Assert-NotMatch 'a transfer redirect, not a different repository' $r.Out 'own rename history: the old, over-confident wording is gone'

    # --- 1g. Check 1b, arm 4: not a git work tree at all -> the question could not be asked ---------
    #      New-FixtureConsumer's plain folder is never a git work tree, so every scenario ABOVE this
    #      one that never calls Set-FixtureGitCheckout already exercises this arm implicitly -- this
    #      scenario is what pins it explicitly, so it stays true on purpose rather than by accident.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mf = New-FixtureManifest -Extensions @('06-16') -Repo 'acme-org/widgets'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'not a git work tree: exit code unchanged'
    Assert-Match "could not read this checkout's own git identity" $r.Out 'not a git work tree: names why the question could not be asked'
    Assert-Match '\[OK\]\s+plugin is enabled' $r.Out 'not a git work tree: checks below still run'
    Assert-Match 'all 1 registered extensions present' $r.Out 'not a git work tree: extensions check still runs too'

    # --- 1h. Check 1b, arm 4 again: IS a work tree, but has no 'origin' remote ----------------------
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureGitCheckout
    $mf = New-FixtureManifest -Extensions @('06-16') -Repo 'acme-org/widgets'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'work tree, no origin: exit code unchanged'
    Assert-Match "could not read this checkout's own git identity" $r.Out 'work tree, no origin: same SKIP as no-git-at-all'
    Assert-Match '\[OK\]\s+plugin is enabled' $r.Out 'work tree, no origin: checks below still run'

    # --- 1i. Check 1b, arm 4's nested-checkout sub-case (#1821, Victor's finding, medium severity): the
    #      folder resolves INSIDE a git work tree but is NOT that work tree's own root. Before the fix
    #      this read via '--is-inside-work-tree', which answers 'true' for any folder nested inside
    #      somebody else's checkout, and 'remote get-url origin' then walked UP and answered with the
    #      ENCLOSING repo's origin as if it were this checkout's own identity. THE BITING CASE: the
    #      wrapper's origin does NOT match the manifest, so the pre-fix code would have printed a false
    #      arm-3 [ERROR] blaming a repository that has nothing to do with the folder actually named by
    #      localCheckout. The fixed code must instead recognise this is arm 4 (the question does not
    #      apply to a non-root folder at all) and print no mismatch.
    if (Test-Path -LiteralPath $NestedFixtureRoot) { Remove-Item -Recurse -Force -LiteralPath $NestedFixtureRoot }
    New-Item -ItemType Directory -Path $NestedFixtureRoot -Force | Out-Null
    Set-FixtureGitCheckout -At $NestedFixtureRoot -OriginUrl 'https://github.com/other-org/gadgets.git'
    $nestedCheckout = Join-Path $NestedFixtureRoot 'sub\consumer'
    New-FixtureConsumer -ExtensionIds @('06-16') -Root $nestedCheckout
    $mf = New-FixtureManifest -Extensions @('06-16') -Repo 'acme-org/widgets' -Root $nestedCheckout
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $nestedCheckout))
    Assert-Equal 0 $r.Code 'nested, non-root, enclosing origin mismatches manifest: exit code 0 (no false alarm)'
    Assert-NotMatch "this checkout's 'origin' is" $r.Out 'nested, non-root, enclosing origin mismatches manifest: no arm-3 ERROR blaming the enclosing repo'
    Assert-NotMatch '\[ERROR\]' $r.Out 'nested, non-root, enclosing origin mismatches manifest: no ERROR at all'
    Assert-Match 'is not the root of the git work tree it sits inside' $r.Out 'nested, non-root, enclosing origin mismatches manifest: named as arm 4, precisely'
    Assert-Match 'acme-org/widgets' $r.Out 'nested, non-root, enclosing origin mismatches manifest: still names the manifest slug it could not check'
    Assert-Match '\[OK\]\s+plugin is enabled' $r.Out 'nested, non-root, enclosing origin mismatches manifest: checks below still run'

    # --- 1j. Same nested-checkout sub-case, but the enclosing repo's origin HAPPENS to match the
    #      manifest -- the silent-agreement half, invisible by construction. Before the fix this would
    #      have read the enclosing origin, found it equal to the manifest, and fired NO signal at all --
    #      a false arm-1 agreement for a folder that was never a clone of anything in its own right. The
    #      only way to prove the fix still catches this is to assert the arm-4 SKIP is present: if it
    #      were ever missing, the run would have silently agreed instead.
    if (Test-Path -LiteralPath $NestedFixtureRoot) { Remove-Item -Recurse -Force -LiteralPath $NestedFixtureRoot }
    New-Item -ItemType Directory -Path $NestedFixtureRoot -Force | Out-Null
    Set-FixtureGitCheckout -At $NestedFixtureRoot -OriginUrl 'https://github.com/acme-org/widgets.git'
    $nestedCheckout = Join-Path $NestedFixtureRoot 'sub\consumer'
    New-FixtureConsumer -ExtensionIds @('06-16') -Root $nestedCheckout
    $mf = New-FixtureManifest -Extensions @('06-16') -Repo 'acme-org/widgets' -Root $nestedCheckout
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $nestedCheckout))
    Assert-Equal 0 $r.Code 'nested, non-root, enclosing origin happens to match manifest: exit code 0'
    Assert-NotMatch "this checkout's 'origin' is" $r.Out 'nested, non-root, enclosing origin happens to match manifest: no arm-3 ERROR'
    Assert-Match 'is not the root of the git work tree it sits inside' $r.Out 'nested, non-root, enclosing origin happens to match manifest: arm 4 still fires -- NOT a silent arm-1 agreement'
    Assert-Match '\[OK\]\s+plugin is enabled' $r.Out 'nested, non-root, enclosing origin happens to match manifest: checks below still run'

    # --- 1k. Check 1b, arm 3's remedy line, guarded (#1821, Sebastian's finding): a manifest 'repo' that
    #      is not a well-formed GitHub slug must not be composed into the printed 'git remote set-url'
    #      command -- the [ERROR] itself still fires (nothing about the malformed value was checked
    #      either way), but the remedy names the field as not a well-formed slug instead of building a
    #      URL from it. Made precise enough that reintroducing the raw string interpolation would fail
    #      it: the malformed value itself must never appear inside a 'remote set-url' line.
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureGitCheckout -OriginUrl 'https://github.com/acme-org/widgets.git'
    $mf = New-FixtureManifest -Extensions @('06-16') -Repo 'fixture/consumer/../../etc'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'malformed manifest repo slug (arm 3): exit code 1'
    Assert-Match '\[ERROR\]' $r.Out 'malformed manifest repo slug (arm 3): the finding still fires'
    Assert-Match "this checkout's 'origin' is" $r.Out 'malformed manifest repo slug (arm 3): still the arm-3 mismatch line'
    Assert-Match 'not a valid GitHub owner/name slug -- rejected before it became an API call' $r.Out 'malformed manifest repo slug (arm 3): named as not well-formed'
    Assert-Match 'No ready-to-run repoint command is printed here' $r.Out 'malformed manifest repo slug (arm 3): says so plainly'
    Assert-NotMatch 'remote set-url origin https://github\.com/fixture' $r.Out 'malformed manifest repo slug (arm 3): the raw value is never composed into a remote set-url command'

    # --- 2. Registered extension is missing -> exit 1 ----------------------------------------
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mf = New-FixtureManifest -Extensions @('06-16', '06-19')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'missing extension: exit code 1'
    Assert-Match '\[ERROR\].*06-19' $r.Out 'missing extension: ERROR names the id'
    # inbound #203: the finding carries the connector it is about. The session hook filters this output
    # down to the signal lines and drops the '== connector: <repo>' headers, so two consumers on the
    # same outdated plugin version used to produce two identical, unattributable [ERROR] lines. This is
    # the end-to-end proof that Set-CheckScope reaches a real Write-Failure line.
    # The label narrows to '<repo> / <plugin-id>' inside a plugin block: a consumer can register several
    # plugins, and one shared cause (a single outdated install) then yields one finding per plugin --
    # identical to the character once the '-- plugin:' header is filtered out. Found live in this repo's
    # own register while verifying the connector-name fix, so the plugin id is part of the fix, not a
    # nice-to-have.
    Assert-Match '\[ERROR\]\s+fixture/consumer / dkj-subagents-alpha@dkj-claude-plugins:' $r.Out 'missing extension: the ERROR line names the connector AND the plugin block it belongs to'

    # --- 3. Plugin not enabled -> exit 1 --------------------------------------------------------
    New-FixtureConsumer -ExtensionIds @('06-16') -PluginEnabled $false
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'plugin disabled: exit code 1'
    Assert-Match '\[ERROR\].*is NOT' $r.Out 'plugin disabled: ERROR message'
    # Only settings.json exists in this fixture, so that is what the verdict names -- the message states
    # what was actually consulted, not a chain it merely looked for. Case 3c covers the two-layer wording.
    Assert-Match 'is NOT \(or no longer\) enabled in \.claude/settings\.json' $r.Out 'plugin disabled: the ERROR names the layer it consulted'

    # --- 3b. inbound #294, symptom 3: the enable lives ONLY in settings.local.json ----------------
    #     Measured against 3.0.5: this check reported "plugin is NOT (or no longer) enabled" for
    #     DaveKJohn/life-hub in the very session that had loaded four of its skills and all three of its
    #     hooks -- literally true about settings.json, false about the session. The mirror image of the
    #     roster check's false green, from the identical blindness: same cause, opposite direction, so a
    #     reader who cross-referenced the two gates learned to trust neither.
    New-FixtureConsumer -ExtensionIds @('06-16') -PluginEnabled $false
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude\settings.local.json'),
        '{ "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true } }')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'local-only enable: exit code 0 (no false alarm)'
    Assert-Match '\[OK\]\s+plugin is enabled in .*settings\.local\.json' $r.Out 'local-only enable: enabled, and the layer that says so is named'
    Assert-NotMatch 'is NOT \(or no longer\) enabled' $r.Out 'local-only enable: the false ERROR is gone'

    # --- 3c. Both layers present, neither enables -> the verdict names BOTH -----------------------
    #     The point of the wording: a reader who disagrees with a "not enabled" finding needs to know
    #     which files were read before going to look for the enable somewhere else.
    New-FixtureConsumer -ExtensionIds @('06-16') -PluginEnabled $false
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude\settings.local.json'), '{ "enabledPlugins": { } }')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'both layers, neither enables: exit code 1'
    Assert-Match 'is NOT \(or no longer\) enabled in \.claude/settings\.json and \.claude/settings\.local\.json' $r.Out 'both layers: the ERROR names the whole chain it consulted'

    # --- 4. Checkout not present -> SKIP, exit 0 -----------------------------------------------
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mf = New-FixtureManifest -Extensions @('06-16') -LocalCheckout 'nonexistent-fixture-path'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf))
    Assert-Equal 0 $r.Code 'missing checkout: exit code 0'
    Assert-Match '\[SKIP\]' $r.Out 'missing checkout: SKIP message'

    # --- 4b. A LIST of candidate paths, none present -> SKIP naming ALL of them, exit 0 -------------
    #     The field is one per-manifest value while the layout it describes is per-machine (#1524), so
    #     it may hold several relative paths. When none resolves, the [SKIP] has to name every one of
    #     them: that line is the only thing a reader gets, and a skip naming one candidate out of two
    #     reads as "the checkout is absent" when what actually happened is "this machine's layout is
    #     not in the register".
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mf = New-FixtureManifest -Extensions @('06-16') -LocalCheckout @('nonexistent-fixture-path', 'also-nonexistent-fixture-path')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf))
    Assert-Equal 0 $r.Code 'candidate list, none present: exit code 0'
    Assert-Match '\[SKIP\]' $r.Out 'candidate list, none present: SKIP message'
    Assert-Match 'nonexistent-fixture-path' $r.Out 'candidate list, none present: the SKIP names the first candidate'
    Assert-Match 'also-nonexistent-fixture-path' $r.Out 'candidate list, none present: the SKIP names the second candidate too'

    # --- 4c. A LIST whose LATER candidate resolves -> checked, not skipped --------------------------
    #     The regression #1524 is made of: the first candidate missing must not end the connector. '.'
    #     is used as the resolving one for the same reason case 6 below uses it -- it is the only path
    #     relative to the repo root that is guaranteed to exist wherever this suite runs.
    $mf = New-FixtureManifest -Extensions @('06-16') -LocalCheckout @('nonexistent-fixture-path', '.')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf))
    Assert-NotMatch '\[SKIP\]' $r.Out 'candidate list, later one present: NOT skipped -- the first miss does not end the connector'
    Assert-Match '== connector: fixture/consumer' $r.Out 'candidate list, later one present: the connector is actually checked'

    # --- 5. Unregistered extension of this plugin -> INFO, exit 0 ------------------------
    New-FixtureConsumer -ExtensionIds @('06-16', '06-23')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'unregistered: exit code 0 (INFO, not an error)'
    Assert-Match "\[INFO\].*'06-23'" $r.Out 'unregistered: INFO names the id (first layer)'

    # --- 5b. Same INFO signal from the plugin path --------------------------------------------
    New-FixtureConsumer -ExtensionIds @('06-16', '06-23') -Layout 'plugins'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'unregistered on plugin path: exit code 0'
    Assert-Match "\[INFO\].*'06-23'" $r.Out 'unregistered on plugin path: INFO names the id'

    # --- 5d. Inventory drift in the session's OWN register -> non-counting [INVENTORY] --------------
    #     Found 2026-07-29: a deliberate run turned up eleven of these at once, six in the workshop's
    #     own entry (the lenses landed with PR #212, the inventory was never updated alongside). The
    #     finding is an [INFO], the hook shows only [ERROR], so nothing had surfaced it. -OnlyConsumer
    #     marks the fixture as the repo this run is "in", which is the case a reader can act on.
    New-FixtureConsumer -ExtensionIds @('06-16', '06-23')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture, '-OnlyConsumer', $Fixture))
    Assert-Match '\[INVENTORY\]' $r.Out 'own inventory drift: a non-counting [INVENTORY] marker is emitted for the hook'
    Assert-Match "\[INVENTORY\].*06-23" $r.Out 'own inventory drift: the marker names the missing id'
    Assert-Match "\[INFO\].*'06-23'" $r.Out 'own inventory drift: the [INFO] stays for the count and the deliberate run'
    Assert-Match '1 info signal' $r.Out 'own inventory drift: [INVENTORY] is non-counting (still exactly 1 info signal)'
    Assert-Equal 0 $r.Code 'own inventory drift: exit 0 -- a behind-reality register is not a failure of the plugin install'
    # Same audience rule as [UNREGISTERED]: say plainly that nothing is broken, so the line reads as
    # bookkeeping rather than as a fault in the reader's repo.
    Assert-Match 'Nothing is broken' $r.Out 'own inventory drift: the message states the repo is not broken'

    # --- 5e. The same drift in ANOTHER repo's register stays silent --------------------------------
    #     The scoping that keeps this from reintroducing the other-machine noise the [INFO]-silence
    #     rule removed (Dave, July 20, 2026). Identical fixture to 5d, minus -OnlyConsumer: the
    #     checkout is then no longer the repo the run is in, so the [INFO] must still appear while the
    #     [INVENTORY] marker must not. Without this test the feature would look correct in 5d and
    #     quietly surface every consumer's bookkeeping at every session start.
    New-FixtureConsumer -ExtensionIds @('06-16', '06-23')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Match "\[INFO\].*'06-23'" $r.Out "another repo's inventory drift: the [INFO] is still reported on a deliberate run"
    Assert-NotMatch '\[INVENTORY\]' $r.Out "another repo's inventory drift: NO [INVENTORY] marker -- it would be another machine's bookkeeping"

    # --- 5c. -OnlyConsumer without a manifest in the register -> INFO, exit 0 -----------------------
    #     A fresh/unregistered consumer (as the SessionStart hook passes via -OnlyConsumer) should
    #     see an informational "not registered" signal -- NOT the reassuring "in sync" branch. The
    #     manifest checkout does not exist, so no manifest matches this consumer -> matched=0
    #     (regression: this used to be a bare Write-Host that did not count as an info signal,
    #     causing the hook to show "all connectors in sync").
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mf = New-FixtureManifest -Extensions @('06-16') -LocalCheckout 'nonexistent-fixture-path'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-OnlyConsumer', $Fixture))
    Assert-Equal 0 $r.Code 'unregistered consumer: exit code 0 (INFO, no block)'
    Assert-Match '\[INFO\].*not registered' $r.Out 'unregistered consumer: not-registered signal'
    Assert-Match '1 info signal' $r.Out 'unregistered consumer: counts as an info signal'
    # This notice is about the RUN, not about any single connector, so it must not inherit the label of
    # whichever manifest the loop walked last (inbound #203 -- the reason the label is cleared after the
    # loop rather than set once). 'fixture/consumer' is exactly the label that would leak in here.
    Assert-NotMatch '\[INFO\]\s+fixture/consumer:.*not registered' $r.Out 'unregistered consumer: the run-level notice is NOT attributed to the last connector walked'
    # Gap found 2026-07-28: the [INFO] above is suppressed by the session hook, so a brand-new consumer
    # was told "no errors" -- a positive all-clear for a repo the workshop cannot see at all. The
    # non-counting [UNREGISTERED] marker is what reaches the session; the [INFO] stays for the count and
    # the deliberate run. Both must be present, and the marker must not inflate the tally.
    Assert-Match '\[UNREGISTERED\]' $r.Out 'unregistered consumer: a non-counting [UNREGISTERED] marker is emitted for the hook'
    # The message has to serve a reader who knows nothing about the plugin's source repo (Dave, July 28,
    # 2026). Two halves: say nothing here is broken, and address the fix to the maintainer rather than
    # handing homework to whoever merely installed the plugin.
    Assert-Match 'Nothing here is affected' $r.Out 'unregistered consumer: the message states the consumer is not broken'
    Assert-Match 'no action is needed on your side' $r.Out 'unregistered consumer: a plain user is told explicitly to do nothing'
    Assert-NotMatch 'in the workshop' $r.Out 'unregistered consumer: no instruction to go work in a repo the reader may not have'
    Assert-Match '1 info signal' $r.Out 'unregistered consumer: [UNREGISTERED] is non-counting (still exactly 1 info signal)'
    Assert-Equal 0 $r.Code 'unregistered consumer: still exit 0 -- not being registered is not a failure of the plugin install'

    # --- 6. Real manifests of this repo: the self-manifest always checks ----------------------
    $selfManifest = Join-Path $RepoRoot 'connectors\dkj-claude-plugins.json'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $selfManifest))
    Assert-Equal 0 $r.Code 'self-manifest (workshop consumes itself): exit code 0'

    # --- 6b. Real manifests of one siblingGroup: the same layouts, candidate for candidate (#2141) ---
    # Members of a group share a machine layout, so there is no state in which one needs a candidate
    # the other does not. Three closed issues (#1524, #1807, #1831) each repaired ONE manifest and the
    # pair went out of step; #2141 is the fourth, and its cost was a false '[SKIP] not present on this
    # machine' for a checkout that WAS present. A candidate is compared with the repo folder taken off
    # its end -- '../../bwj-development/<repo>' names a layout, and the repo differs per member by design.
    # A test rather than a runtime check on purpose: at run time a member lacking a layout is correct
    # on a machine that has none of it, and only the SOURCE tree can say the two lists were meant to match.
    $groupLayouts = @{}
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'connectors') -Filter '*.json') {
        $m = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
        if (-not $m.PSObject.Properties['siblingGroup']) { continue }
        $folder = ([string]$m.repo).Split('/')[-1]
        $layouts = @($m.localCheckout | ForEach-Object { ([string]$_) -replace ('/' + [regex]::Escape($folder) + '$'), '' })
        if (-not $groupLayouts.ContainsKey([string]$m.siblingGroup)) { $groupLayouts[[string]$m.siblingGroup] = @{} }
        $groupLayouts[[string]$m.siblingGroup][$f.Name] = $layouts
    }
    Assert-Equal $true (@($groupLayouts.Keys | Where-Object { $groupLayouts[$_].Count -ge 2 }).Count -ge 1) 'sibling groups: the register still holds a group of two or more, so the check below has a subject'
    foreach ($g in $groupLayouts.Keys) {
        $union = @($groupLayouts[$g].Values | ForEach-Object { $_ } | Select-Object -Unique)
        foreach ($member in $groupLayouts[$g].Keys) {
            $missing = @($union | Where-Object { $groupLayouts[$g][$member] -notcontains $_ })
            Assert-Equal '' ($missing -join ', ') "sibling group '$g': $member declares every layout its siblings do"
        }
    }

    # --- 7. Guardrails (Sean's advice): manifest fields are not blindly trusted -----------------
    # 7a. Absolute localCheckout path -> rejected, exit 1.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mf = New-FixtureManifest -Extensions @('06-16') -LocalCheckout 'C:\Windows'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf))
    Assert-Equal 1 $r.Code 'absolute path: exit code 1'
    Assert-Match '\[ERROR\].*rejected' $r.Out 'absolute path: rejected message'

    # 7a2. An absolute path ANYWHERE in a candidate list -> rejected, exit 1. The guardrail is on the
    #      field, not on its first element: a list whose second entry is absolute must not slip through
    #      because the first one happened to be relative and missing.
    $mf = New-FixtureManifest -Extensions @('06-16') -LocalCheckout @('nonexistent-fixture-path', 'C:\Windows')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf))
    Assert-Equal 1 $r.Code 'absolute path in a candidate list: exit code 1'
    Assert-Match '\[ERROR\].*rejected' $r.Out 'absolute path in a candidate list: rejected message'

    # 7a3. An EMPTY candidate list -> rejected, exit 1. A manifest naming no checkout at all is a
    #      malformed register entry, not a checkout that is absent here -- reporting it as [SKIP] would
    #      be the same false-absence sentence #1524 was filed about.
    $mf = New-FixtureManifest -Extensions @('06-16') -LocalCheckout @()
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf))
    Assert-Equal 1 $r.Code 'empty candidate list: exit code 1'
    Assert-Match '\[ERROR\].*no localCheckout path' $r.Out 'empty candidate list: rejected message names the missing field'

    # 7b. Path traversal outside the scope root -> rejected, exit 1. '..\..\..' resolved from
    #     the repo root always ends up above the scope root (= two levels above the repo root).
    $mf = New-FixtureManifest -Extensions @('06-16') -LocalCheckout '..\..\..'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf))
    Assert-Equal 1 $r.Code 'path traversal: exit code 1'
    Assert-Match '\[ERROR\].*outside the allowed scope' $r.Out 'path traversal: scope message'

    # 7c. Plugin field with path characters -> rejected, exit 1.
    $mf = New-FixtureManifest -Extensions @('06-16') -Plugin '..\..\evil@dkj-claude-plugins'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'invalid plugin field: exit code 1'
    Assert-Match '\[ERROR\].*plugin field' $r.Out 'invalid plugin field: ERROR message'

    # --- 8. Machine-record check (without -SkipVersions; Victor's finding) ---------------------------
    # The administration is read via $env:USERPROFILE; the child process inherits the env var, so
    # we point it at the fixture temporarily. -SkipDrift stays on (own suite).
    function Set-FixtureAdmin([string]$RecordsJson) {
        $dir = Join-Path $Fixture '.claude\plugins'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir 'installed_plugins.json'), $RecordsJson)
    }
    $oldProfile = $env:USERPROFILE
    try {
        # 8a. Stale record (projectPath does not exist) -> no crash, INFO, exit 0.
        New-FixtureConsumer -ExtensionIds @('06-16')
        $mf = New-FixtureManifest -Extensions @('06-16')
        Set-FixtureAdmin '{ "version": 2, "plugins": { "dkj-subagents-alpha@dkj-claude-plugins": [ { "scope": "project", "projectPath": "C:\\does-not-exist-connectors-fixture", "installPath": "x", "version": "0.0.1" } ] } }'
        $env:USERPROFILE = $Fixture
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mf, '-ConsumerPathOverride', $Fixture)
        Assert-Equal 0 $r.Code 'stale record: exit code 0 (no crash)'
        Assert-Match '\[INFO\].*no machine record' $r.Out 'stale record: INFO message'

        # 8b. Record points to the fixture but with an older version than the source -> ERROR, exit 1.
        $fixtureEscaped = ($Fixture -replace '\\', '\\')
        Set-FixtureAdmin ('{ "version": 2, "plugins": { "dkj-subagents-alpha@dkj-claude-plugins": [ { "scope": "project", "projectPath": "' + $fixtureEscaped + '", "installPath": "x", "version": "0.0.1" } ] } }')
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mf, '-ConsumerPathOverride', $Fixture)
        Assert-Equal 1 $r.Code 'outdated record: exit code 1'
        Assert-Match '\[ERROR\].*machine record is on v0\.0\.1' $r.Out 'outdated record: ERROR message'

        # 8c. SEVERAL records for one checkout, at DIFFERENT versions -> say so, do not pick one (#240).
        #     The old loop took the first match and stopped, so the [OK]/[ERROR] the session hook shows
        #     every start depended on JSON ordering. Measured on Dave's machine: three registered
        #     versions for one repo. An honest "cannot determine" is the only defensible output, and it
        #     must NOT be an INFO -- while the records disagree, every version claim about this consumer
        #     is unreliable.
        Set-FixtureAdmin ('{ "version": 2, "plugins": { "dkj-subagents-alpha@dkj-claude-plugins": [ ' +
            '{ "scope": "project", "projectPath": "' + $fixtureEscaped + '", "installPath": "x", "version": "0.0.1" }, ' +
            '{ "scope": "project", "projectPath": "' + $fixtureEscaped + '", "installPath": "x", "version": "0.0.2" }, ' +
            '{ "scope": "project", "projectPath": "' + $fixtureEscaped + '", "installPath": "x", "version": "0.0.3" } ] } }')
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mf, '-ConsumerPathOverride', $Fixture)
        Assert-Equal 1 $r.Code 'disagreeing records: exit code 1'
        Assert-Match '\[ERROR\].*3 machine records for this consumer disagree' $r.Out 'disagreeing records: reports the count instead of a version'
        Assert-Match 'v0\.0\.1, v0\.0\.2, v0\.0\.3' $r.Out 'disagreeing records: names every version it found'
        Assert-Match 'cannot determine' $r.Out 'disagreeing records: says outright that it cannot tell'

        # 8d. Several records, SAME version, different path spellings -> agreement, not a disagreement.
        #     Two spellings of one directory are not two answers: on Windows the trailing separator and
        #     the casing are noise, and reporting them as a conflict would trade a confident wrong
        #     number for a confident false alarm.
        $fixtureLowerEscaped = ($Fixture.ToLowerInvariant() -replace '\\', '\\')
        Set-FixtureAdmin ('{ "version": 2, "plugins": { "dkj-subagents-alpha@dkj-claude-plugins": [ ' +
            '{ "scope": "project", "projectPath": "' + $fixtureEscaped + '\\", "installPath": "x", "version": "0.0.1" }, ' +
            '{ "scope": "project", "projectPath": "' + $fixtureLowerEscaped + '", "installPath": "x", "version": "0.0.1" } ] } }')
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mf, '-ConsumerPathOverride', $Fixture)
        Assert-Match '\[ERROR\].*machine record is on v0\.0\.1' $r.Out 'same version, two spellings: still the plain version verdict'
        Assert-NotMatch 'disagree' $r.Out 'same version, two spellings: NOT reported as a disagreement'

        # 8e. inbound #302: "no machine record" while the plugin IS enabled there means something much
        #     louder than a version check that could not run -- a session in that checkout loads none of
        #     the plugin. And that repo cannot report it itself: the hook that would is inside the plugin
        #     that is not loading, so this check, from the workshop, is the only vantage point left.
        #     Stays [INFO], deliberately: a consumer legitimately used from another machine has no record
        #     here either, so the state is not conclusive -- the message names both readings.
        Set-FixtureAdmin '{ "version": 2, "plugins": { } }'
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mf, '-ConsumerPathOverride', $Fixture)
        Assert-Equal 0 $r.Code 'enabled but no record: exit 0 -- INFO, never a gate breach'
        Assert-Match '\[INFO\].*no machine record for this consumer, while the plugin IS enabled' $r.Out 'enabled but no record: the consequence is stated, not just the skipped version check'
        Assert-Match 'loads none of this plugin' $r.Out 'enabled but no record: says what a session there actually gets'
        Assert-Match 'claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project' $r.Out 'enabled but no record: names the one command that settles it'
        # ...and NOT the marker, because this run is walking a consumer that is not the session's repo.
        # This is the half that keeps the [INFO]-silence rule intact: promoting the line for every
        # connector would put another machine's business back into every session start.
        Assert-NotMatch '\[NOT-INSTALLED-HERE\]' $r.Out 'enabled but no record, ANOTHER repo: no marker -- the session hook must stay quiet about other machines'

        # 8e2 (#533). The same state, in the repo the session is actually in: -OnlyConsumer is how a
        #      consumer's hook scopes the run to itself, and it makes Test-IsSessionRepo true. Here the
        #      "the install may belong to another machine" reading that keeps 8e an [INFO] does not exist
        #      -- the session is running in this checkout -- so the marker is added on top of the [INFO].
        #      Measured need: on 2026-08-09 a mid-session pull left both enabled plugins recordless here
        #      and nothing said so, because the [INFO] is suppressed by the hook and roster-sync's marker
        #      of the same name is unreachable at session start by design.
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mf, '-ConsumerPathOverride', $Fixture, '-OnlyConsumer', $Fixture)
        Assert-Equal 0 $r.Code 'enabled but no record, SESSION repo: still exit 0 -- non-counting, nothing is broken about the source'
        Assert-Match '\[NOT-INSTALLED-HERE\]' $r.Out 'enabled but no record, SESSION repo: the marker fires'
        Assert-Match 'loads none of it' $r.Out 'enabled but no record, SESSION repo: says what a session here actually gets'
        Assert-Match 'claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project' $r.Out 'enabled but no record, SESSION repo: the marker carries the fix, not just the diagnosis'
        Assert-Match '\[INFO\].*no machine record for this consumer, while the plugin IS enabled' $r.Out 'enabled but no record, SESSION repo: the [INFO] is kept -- a deliberate run should still list everything'

        # 8e3 (#533). Every 'source on vX' in a run is read from THIS checkout, now -- a point-in-time fact
        #      the session hook then forwards into a context that keeps it for hours. The run therefore
        #      names the commit it measured, once at run level: the same answer for every finding below, so
        #      repeating it per line would cost the reader on every line to say nothing new. The value is
        #      not asserted (it is whatever HEAD is), only that it is a real short sha and that the run
        #      says so at all.
        Assert-Match '== check-connectors .*source read at [0-9a-f]{7}' $r.Out 'source stamp: the run names the commit its version verdicts were read at'

        # 8f. The same fact when the plugin is NOT enabled there keeps the old, milder wording: nothing is
        #     silently loading or failing to load, so the loud reading would be a false alarm.
        #     Order matters: New-FixtureConsumer wipes $Fixture, and both the manifest and the
        #     administration live inside it, so they are rebuilt after it -- not before.
        New-FixtureConsumer -ExtensionIds @('06-16') -PluginEnabled $false
        $mf = New-FixtureManifest -Extensions @('06-16')
        Set-FixtureAdmin '{ "version": 2, "plugins": { } }'
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mf, '-ConsumerPathOverride', $Fixture)
        Assert-Match '\[INFO\].*no machine record for this consumer \(the install may run via a different machine\)' $r.Out 'not enabled, no record: the milder wording is kept'
        Assert-NotMatch 'loads none of this plugin' $r.Out 'not enabled, no record: no loud claim about a session that was never going to load it'

        # 8g. An administration that EXISTS but does not parse must not be read as "no record". Found while
        #     reviewing this change: an unreadable file yields an empty record set, and the branches above
        #     would then have reported "no machine record for this consumer" -- a statement about absence,
        #     drawn from a file nothing could read. That is the exact species of claim #302 is about, one
        #     level down. The verdict is withheld and the file is named instead.
        New-FixtureConsumer -ExtensionIds @('06-16')
        $mf = New-FixtureManifest -Extensions @('06-16')
        Set-FixtureAdmin '{ "version": 2, "plugins": { oops'
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mf, '-ConsumerPathOverride', $Fixture)
        Assert-Equal 1 $r.Code 'unreadable administration: exit 1 -- the authority for this check could not be read'
        Assert-Match '\[ERROR\].*does not parse as JSON' $r.Out 'unreadable administration: the file is named'
        Assert-Match 'version verdict below is withheld' $r.Out 'unreadable administration: says the verdicts are withheld'
        Assert-NotMatch 'no machine record for this consumer' $r.Out 'unreadable administration: NOT reported as an absent record'
        Assert-NotMatch 'no plugin administration found' $r.Out 'unreadable administration: nor as an absent file'

        # 8h. And with -SkipVersions the administration is not read at all, so an unreadable one is silent:
        #     a run explicitly asked not to look at versions must not fail on the version authority.
        $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
        Assert-NotMatch 'does not parse as JSON' $r.Out '-SkipVersions: the administration is not read, so not reported'
    } finally {
        $env:USERPROFILE = $oldProfile
    }

    # --- 9. SessionStart hook (connector-sessioncheck.ps1) ---------------------------------------
    # 9a. No workshop checkout findable -> soft message, exit 0 (never block a session).
    #     SINCE #1591 this is no longer the literal 'check skipped' string: the hook now finds its
    #     own plugin-versions.ps1 mirror (this repo IS the workshop, so it always has one) and runs
    #     it -Brief instead of giving up. That branch reads the AMBIENT environment (no
    #     -RootOverride/-UserHomeOverride of its own), so Invoke-HookIsolated pins CLAUDE_PROJECT_DIR
    #     and USERPROFILE to scratch fixtures -- otherwise this assertion would depend on whatever
    #     this machine's own install record and marketplace clone happen to say (measured: it does,
    #     and un-pinned it read this dev checkout's real "behind" state).
    New-Item -ItemType Directory -Force -Path (Join-Path $HookHome '.claude\plugins') | Out-Null
    New-FixtureConsumer -ExtensionIds @('06-16')
    $r = Invoke-HookIsolated -RepoDir $Fixture -HomeDir $HookHome -ScriptArgs @('-WorkshopPathOverride', (Join-Path $Fixture 'does-not-exist'))
    Assert-Equal 0 $r.Code 'hook without a workshop: exit code 0'
    Assert-Match 'register checks \(consumer registration, lens inventory, agent-def drift\) did not run' $r.Out 'hook without a workshop: the [UNREGISTERED] lesson of 2026-07-28 -- says the register checks did not run'
    Assert-Match 'Version check: 1 plugin\(s\) enabled here: 0 behind, 1 undetermined, 0 up to date\.' $r.Out 'hook without a workshop: falls back to the plugin-versions -Brief summary (no clone at all here -> undetermined, not an error)'

    # 9b. With the real workshop: integration smoke. Which branch (in-sync or signals) fires depends
    #     on the repo's current register state (e.g. manifests not yet updated after a release
    #     bump) -- that is deliberately not asserted here; the branches themselves are
    #     deterministically covered by the stub tests 9c and 9d (a lesson from CI run PR #54).
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $RepoRoot, '-SkipDrift', '-SkipVersions')
    Assert-Equal 0 $r.Code 'hook with a workshop: exit code 0'
    Assert-Match 'connector-sessioncheck:' $r.Out 'hook with a workshop: session-check output'

    # 9c. Stub workshop with clean output including boilerplate drifted lines (Victor's finding):
    #     the bare summary lines must NOT count as a signal.
    $stub = New-StubWorkshop -Name 'stub-clean' -ExitCode 0 -OutputLines @(
        '  [OK]    all good',
        'Agent-def summary: 19 missing, 0 identical (dead copies), 0 drifted.',
        'Persona drift is INFORMATIONAL (does not affect the exit code): 0 drifted.'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Equal 0 $r.Code 'clean stub: exit code 0'
    Assert-Match 'no errors' $r.Out 'clean stub: boilerplate does not count as a signal'

    # 9c2. Stub workshop with only INFO lines -> OK branch, no session alert (Dave's wish,
    #      July 20, 2026): INFO is register administration about consumer sync (often another
    #      machine/user) and should not be reported at every session start.
    $stub = New-StubWorkshop -Name 'stub-info' -ExitCode 0 -OutputLines @(
        '  [INFO]  fixture register-administration signal',
        '  [INFO]  extension 06-24 exists in the consumer but is not in the register.'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Equal 0 $r.Code 'info stub: exit code 0'
    Assert-Match 'no errors' $r.Out 'info stub: OK branch (INFO gives no session alert)'
    Assert-NotMatch 'fixture register-administration signal' $r.Out 'info stub: INFO line NOT passed through'

    # 9d. Stub workshop with a real error -> signals branch, line comes through. BILINGUAL: the hook
    #     must recognize both the new [ERROR] and the legacy [FOUT] as a blocking signal, because
    #     the plugin cache (this hook) and the workshop checkout (check-connectors) can be on
    #     different versions.
    $stub = New-StubWorkshop -Name 'stub-error' -ExitCode 1 -OutputLines @(
        '  [ERROR] fixture-error-new',
        '  [FOUT]  fixture-error-legacy'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Equal 0 $r.Code 'error stub: exit code 0 (the hook never blocks)'
    Assert-Match 'signals found' $r.Out 'error stub: signals branch'
    Assert-Match 'fixture-error-new' $r.Out 'error stub: new [ERROR] line passed through (bilingual)'
    Assert-Match 'fixture-error-legacy' $r.Out 'error stub: legacy [FOUT] line passed through (bilingual)'

    # 9d1b. Grouping: lines that differ ONLY in the plugin name fold into one line per consumer, and
    #       every plugin name survives the fold. The saving is real -- measured 2026-08-15, six such
    #       lines were 1,511 characters, 81% of everything the five session hooks printed, paid again
    #       on every compaction. What must NOT be lost is attribution: inbound #203 was filed because
    #       identical unattributable lines could not be traced to a consumer, so these asserts pin the
    #       NAMES, not merely the line count.
    $stub = New-StubWorkshop -Name 'stub-group' -ExitCode 1 -OutputLines @(
        '  [ERROR] owner/consumer-one / plugin-a: machine record is on v1.0.0, source on v2.0.0.',
        '  [ERROR] owner/consumer-one / plugin-b: machine record is on v1.0.0, source on v2.0.0.',
        '  [ERROR] owner/consumer-one / plugin-c: machine record is on v1.0.0, source on v2.0.0.',
        '  [ERROR] owner/consumer-two / plugin-a: machine record is on v1.0.0, source on v2.0.0.',
        '  [ERROR] owner/consumer-one / plugin-d: a completely different problem.'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'consumer-one -- 3 plugins' $r.Out 'grouping: the three same-message lines fold into one'
    Assert-Match 'plugin-a, plugin-b, plugin-c' $r.Out 'grouping: every folded plugin name survives (#203 attribution)'
    Assert-Match 'consumer-two / plugin-a' $r.Out 'grouping: a lone line for another consumer keeps its original shape'
    Assert-Match 'plugin-d: a completely different problem' $r.Out 'grouping: a DIFFERENT message is never folded in, however similar the consumer'
    Assert-NotMatch 'consumer-one -- 4 plugins' $r.Out 'grouping: the different message did not inflate the group'

    # 9d1c. Anything that is not the '[MARKER] consumer / plugin: message' shape passes through
    #       untouched -- the drift check's own summary lines are the reason this matters.
    $stub = New-StubWorkshop -Name 'stub-group-passthrough' -ExitCode 1 -OutputLines @(
        '  [ERROR] a line with no consumer or plugin at all',
        '  [DRIFTED] owner/consumer-one / plugin-a: drifted from the source.'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'a line with no consumer or plugin at all' $r.Out 'grouping: an unparseable line is passed through verbatim'
    Assert-Match 'consumer-one / plugin-a: drifted' $r.Out 'grouping: a single [DRIFTED] line keeps its shape'

    # 9d2. Stub with a blocking signal (new [ERROR]) AND [INFO] in the same run -> the signal
    #      comes through, the INFO stays out (the most sensitive regression scenario for the
    #      separation, Victor's finding).
    $stub = New-StubWorkshop -Name 'stub-mix' -ExitCode 1 -OutputLines @(
        '  [ERROR] fixture-mix-error',
        '  [INFO]  fixture-mix-info'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'fixture-mix-error' $r.Out 'mix stub: [ERROR] line passed through'
    Assert-NotMatch 'fixture-mix-info' $r.Out 'mix stub: INFO line NOT passed through'

    # 9d3. Complete report (Summary line present) -> findings surface WITHOUT a partial-report warning,
    #      and the summary states what the run covered. The hook is invoked from the repo root against a
    #      stub workshop elsewhere, so this is the -OnlyConsumer scoping path (inbound #203): saying so
    #      distinguishes "this repo is behind" from "some registered consumer is behind" -- the exact
    #      confusion the 2026-07-27 investigation ran into.
    $stub = New-StubWorkshop -Name 'stub-complete' -ExitCode 1 -OutputLines @(
        '  [ERROR] life-hub: machine record is on v2.1.0, source on v2.8.0',
        'Summary: 1 error(s), 0 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Equal 0 $r.Code 'complete stub: exit code 0'
    Assert-Match 'signals found' $r.Out 'complete stub: signals branch'
    Assert-Match 'life-hub' $r.Out 'complete stub: the connector name travels with the finding'
    Assert-NotMatch 'may be partial' $r.Out 'complete stub: a complete report is not flagged as partial'
    Assert-Match 'scoped to this repo' $r.Out 'complete stub: the summary states the run was scoped to this repo (-OnlyConsumer)'

    # 9d4. Same findings, but the check stopped before its Summary line -> flagged as possibly partial.
    #      The exit code cannot carry this on its own: a complete report WITH findings and a crash
    #      halfway both leave the child on a non-zero exit (inbound #203 item 2).
    $stub = New-StubWorkshop -Name 'stub-partial' -ExitCode 1 -OutputLines @(
        '  [ERROR] life-hub: machine record is on v2.1.0, source on v2.8.0'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'signals found' $r.Out 'partial stub: findings still surface'
    Assert-Match 'may be partial' $r.Out 'partial stub: missing Summary marker flags the list as possibly incomplete'

    # 9d5. Non-zero exit with NO signal line at all: the check broke before it could report anything.
    #      This used to fall into the else-branch and print the "signals found -- summary" header with an
    #      EMPTY list under it, which reads as a finding that is not there. It now has its own branch.
    $stub = New-StubWorkshop -Name 'stub-broke' -ExitCode 1 -OutputLines @(
        'some unexpected failure before any check ran'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Equal 0 $r.Code 'broken stub: exit code 0 (the hook never blocks)'
    Assert-Match 'could not complete' $r.Out 'broken stub: reported as could-not-complete'
    Assert-NotMatch 'signals found' $r.Out 'broken stub: NOT a signals summary with an empty list under it'
    Assert-NotMatch 'no errors' $r.Out 'broken stub: NOT misreported as no errors'

    # 9f. An unregistered consumer must NOT be told "no errors." full stop (gap found 2026-07-28). The
    #     check reports it as [INFO], which this hook suppresses, so the reassurance used to be the only
    #     thing a brand-new consumer ever saw. The non-counting [UNREGISTERED] line now survives next to
    #     the no-errors verdict -- next to, not under: nothing is wrong with the plugin install here,
    #     only with the workshop's view of it, so the exit code and the "no errors" reading both stand.
    # The stub carries the REAL message text (kept in step with check-connectors.ps1), because the
    # jargon assertion below only means something if the fixture is faithful -- an old-wording stub would
    # make the hook look guilty of text it never produced.
    $stub = New-StubWorkshop -Name 'stub-unregistered' -ExitCode 0 -OutputLines @(
        '  [INFO]  not registered: no manifest for this consumer in the register.',
        "  [UNREGISTERED] this repo is not in the plugin maintainer's connector register. Nothing here is affected -- the plugin works normally. If you maintain the plugin source, add a connectors/<repo>.json manifest there; if you just use the plugin, no action is needed on your side.",
        'Summary: 0 error(s), 1 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Equal 0 $r.Code 'unregistered stub: exit code 0'
    Assert-Match '\[UNREGISTERED\]' $r.Out 'unregistered stub: the marker reaches the session context'
    Assert-Match "not in the plugin maintainer's register" $r.Out 'unregistered stub: the verdict line says so instead of a bare "no errors"'
    # Consumer-first wording (Dave, July 28, 2026): a reader who only installed the plugin has never
    # heard of "the workshop", so that nickname must not appear in anything surfaced to a session.
    Assert-NotMatch 'workshop' $r.Out 'unregistered stub: no internal "workshop" jargon reaches the consumer'
    Assert-NotMatch 'signals found' $r.Out 'unregistered stub: NOT escalated to a signals summary (nothing is wrong with the install)'
    Assert-NotMatch '\[INFO\]\s+not registered' $r.Out 'unregistered stub: the per-signal [INFO] line still stays out'

    # 9g. A REGISTERED consumer gains nothing: no marker, so the plain no-errors line is unchanged. The
    #     guard against this fix becoming a line every session start carries.
    $stub = New-StubWorkshop -Name 'stub-registered' -ExitCode 0 -OutputLines @(
        '  [OK]    all 3 registered extensions present',
        'Summary: 0 error(s), 0 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'no errors\.' $r.Out 'registered stub: the plain no-errors line is unchanged'
    Assert-NotMatch 'UNREGISTERED' $r.Out 'registered stub: no unregistered notice'
    Assert-NotMatch 'not in the workshop register' $r.Out 'registered stub: no register wording at all'

    # 9i. An [INVENTORY] notice reaches the session on its own verdict line (found 2026-07-29). Same
    #     shape as 9f one step further in: the repo IS registered, so "not in the register" would be the
    #     wrong story -- its entry simply lists fewer lenses than the repo holds. The check emits the
    #     line only about the repo the session is in, so the hook can surface it unconditionally.
    $stub = New-StubWorkshop -Name 'stub-inventory' -ExitCode 0 -OutputLines @(
        "  [INFO]  DKJ-Solutions/claude-code-specialists / dkj-subagents-alpha@dkj-claude-plugins: extension '04-11' exists in the consumer but is not in the register -- update the register or review the change.",
        "  [INVENTORY] this repo has 1 lens(es) that its own entry in the connector register does not list (04-11) -- add them to the 'extensions' array in dkj-claude-plugins.json, in the same change that landed the lens. Nothing is broken: the register's view of this repo is simply behind reality.",
        'Summary: 0 error(s), 1 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Equal 0 $r.Code 'inventory stub: exit code 0'
    Assert-Match '\[INVENTORY\]' $r.Out 'inventory stub: the marker reaches the session context'
    Assert-Match 'lens inventory for this repo is behind' $r.Out 'inventory stub: its own verdict line, not the not-registered one'
    Assert-NotMatch "not in the plugin maintainer's register" $r.Out 'inventory stub: NOT reported as unregistered -- the entry exists, it is just behind'
    Assert-NotMatch 'signals found' $r.Out 'inventory stub: NOT escalated to a signals summary (nothing is wrong with the install)'
    Assert-NotMatch '\[INFO\]' $r.Out 'inventory stub: the per-signal [INFO] line still stays out'

    # 9j. A clean run gains nothing: the guard against this becoming a line every session start carries.
    $stub = New-StubWorkshop -Name 'stub-no-inventory' -ExitCode 0 -OutputLines @(
        '  [OK]    all 19 registered extensions present',
        'Summary: 0 error(s), 0 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'no errors\.' $r.Out 'no-inventory stub: the plain no-errors line is unchanged'
    Assert-NotMatch 'INVENTORY' $r.Out 'no-inventory stub: no inventory notice'
    Assert-NotMatch 'inventory' $r.Out 'no-inventory stub: no inventory wording at all'

    # 9k. Real signals AND an inventory notice in one run: both surface (the $notices list, not just
    #     $unregistered -- a regression here would silently drop the marker whenever anything else is
    #     also wrong, which is exactly when a session is busiest).
    $stub = New-StubWorkshop -Name 'stub-inv-mixed' -ExitCode 1 -OutputLines @(
        '  [ERROR] life-hub / dkj-subagents-alpha@dkj-claude-plugins: machine record is on v2.9.0, source on v2.11.0',
        "  [INVENTORY] this repo has 1 lens(es) that its own entry in the connector register does not list (04-11) -- add them to the 'extensions' array in dkj-claude-plugins.json, in the same change that landed the lens. Nothing is broken: the register's view of this repo is simply behind reality.",
        'Summary: 1 error(s), 1 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'signals found' $r.Out 'inventory mixed: the signals branch fires'
    Assert-Match 'v2\.9\.0' $r.Out 'inventory mixed: the real [ERROR] surfaces'
    Assert-Match '\[INVENTORY\]' $r.Out 'inventory mixed: the inventory marker surfaces alongside it'

    # 9h. Real signals AND an unregistered notice in one run: both surface, neither crowds out the other.
    $stub = New-StubWorkshop -Name 'stub-unreg-mixed' -ExitCode 1 -OutputLines @(
        '  [ERROR] life-hub / dkj-subagents-alpha@dkj-claude-plugins: machine record is on v2.1.0, source on v2.9.0',
        '  [UNREGISTERED] this repo has no manifest in the workshop register.',
        'Summary: 1 error(s), 1 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'signals found' $r.Out 'unregistered mixed: the signals branch fires'
    Assert-Match 'v2\.1\.0' $r.Out 'unregistered mixed: the real [ERROR] surfaces'
    Assert-Match '\[UNREGISTERED\]' $r.Out 'unregistered mixed: the unregistered marker surfaces alongside it'

    # 9l (#533). The marker on its own: its own verdict, and NOT an errors summary. The distinction it has
    #     to keep is that nothing is wrong with the source -- this machine simply does not have the plugin
    #     -- which is why it rides in $notices rather than $signals.
    $notInstalledLine = "  [NOT-INSTALLED-HERE] 'dkj-subagents-alpha@dkj-claude-plugins' is enabled in .claude/settings.json but has no install record for this checkout -- a session here loads none of it (no skills, no subagents, no hooks). Fix: 'claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project' from this root. Nothing is wrong with the source; this machine simply does not have the plugin."
    $stub = New-StubWorkshop -Name 'stub-notinstalled' -ExitCode 0 -OutputLines @(
        $notInstalledLine,
        'Summary: 0 error(s), 1 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Equal 0 $r.Code 'not-installed stub: exit code 0'
    Assert-Match '\[NOT-INSTALLED-HERE\]' $r.Out 'not-installed stub: the marker reaches the session context'
    Assert-Match 'enabled for this repo is not installed here' $r.Out 'not-installed stub: its own verdict line'
    Assert-NotMatch "not in the plugin maintainer's register" $r.Out 'not-installed stub: NOT the unregistered verdict -- different state, different fix'
    Assert-NotMatch 'lens inventory for this repo is behind' $r.Out 'not-installed stub: NOT the inventory verdict either'
    Assert-NotMatch 'signals found' $r.Out 'not-installed stub: NOT escalated to a signals summary (the source is fine)'

    # 9m. A clean run gains nothing -- the guard against this becoming a line every session start carries.
    $stub = New-StubWorkshop -Name 'stub-no-notinstalled' -ExitCode 0 -OutputLines @(
        '  [OK]    machine record is on the source version (v3.9.0)',
        'Summary: 0 error(s), 0 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'no errors\.' $r.Out 'no-notinstalled stub: the plain no-errors line is unchanged'
    Assert-NotMatch 'NOT-INSTALLED' $r.Out 'no-notinstalled stub: no marker'
    Assert-NotMatch 'not installed here' $r.Out 'no-notinstalled stub: no wording about it at all'

    # 9n. Real signals AND the marker in one run: both surface. Same regression guard as 9k -- the marker
    #     must not be dropped precisely when something else is also wrong, which is when a session is
    #     busiest and least able to notice its absence.
    $stub = New-StubWorkshop -Name 'stub-notinstalled-mixed' -ExitCode 1 -OutputLines @(
        '  [ERROR] life-hub / dkj-subagents-alpha@dkj-claude-plugins: machine record is on v2.9.0, source on v2.11.0',
        $notInstalledLine,
        'Summary: 1 error(s), 1 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'signals found' $r.Out 'not-installed mixed: the signals branch fires'
    Assert-Match 'v2\.9\.0' $r.Out 'not-installed mixed: the real [ERROR] surfaces'
    Assert-Match '\[NOT-INSTALLED-HERE\]' $r.Out 'not-installed mixed: the marker surfaces alongside it'

    # 9o. The marker AND a register notice together: the marker takes the headline (a session running
    #     without its specialist surface outranks the maintainer's view of a repo that works), and the
    #     register notice is still printed rather than swallowed by the branch that won.
    $stub = New-StubWorkshop -Name 'stub-notinstalled-unreg' -ExitCode 0 -OutputLines @(
        $notInstalledLine,
        '  [UNREGISTERED] this repo has no manifest in the workshop register.',
        'Summary: 0 error(s), 2 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'enabled for this repo is not installed here' $r.Out 'not-installed + unregistered: the not-installed verdict takes the headline'
    Assert-Match '\[UNREGISTERED\]' $r.Out 'not-installed + unregistered: the register notice is still printed, not swallowed'
    Assert-NotMatch 'signals found' $r.Out 'not-installed + unregistered: still not an errors summary'

    # 9p (#533). The summary says WHEN its version claims were true. The stamp is LIFTED from the check's
    #     own header rather than measured in the hook -- the commit that matters is the one the versions
    #     were read at, and a second git call could put a wrong timestamp on a right number.
    $stub = New-StubWorkshop -Name 'stub-stamp' -ExitCode 1 -OutputLines @(
        '== check-connectors -- 4 manifest(s) -- source read at 855fd40 ==',
        '  [ERROR] life-hub / dkj-subagents-alpha@dkj-claude-plugins: machine record is on v3.4.0, source on v3.9.0',
        'Summary: 1 error(s), 0 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'signals found' $r.Out 'stamp stub: the signals branch fires'
    Assert-Match 'source read at 855fd40' $r.Out 'stamp stub: the measured commit reaches the session context'
    Assert-Match 'git rev-parse --short HEAD' $r.Out 'stamp stub: and says how to check it, which is the whole point of dating it'
    Assert-NotMatch '== check-connectors' $r.Out 'stamp stub: the header itself is NOT forwarded -- only the fact lifted out of it'

    # 9q. No header, no stamp. A source tree without git (a consumer holding a downloaded copy) makes the
    #     check omit it, and an omitted stamp is honest where an invented one would invite exactly the
    #     trust this whole change is trying to make earnable.
    $stub = New-StubWorkshop -Name 'stub-nostamp' -ExitCode 1 -OutputLines @(
        '== check-connectors -- 4 manifest(s) ==',
        '  [ERROR] life-hub / dkj-subagents-alpha@dkj-claude-plugins: machine record is on v3.4.0, source on v3.9.0',
        'Summary: 1 error(s), 0 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'signals found' $r.Out 'no-stamp stub: the signals branch still fires'
    Assert-Match 'v3\.9\.0' $r.Out 'no-stamp stub: the finding itself is unaffected'
    Assert-NotMatch 'source read at' $r.Out 'no-stamp stub: nothing is invented'
    Assert-NotMatch 'rev-parse' $r.Out 'no-stamp stub: and no advice to check a stamp that is not there'

    # 9e. Marker check (Sean guardrail): a candidate path without a valid marker is NOT executed.
    #     Same #1591 fallback as 9a applies here too (a bad marker also leaves $workshop unset), so
    #     this is isolated the same way; what this scenario actually pins is that the fake script's
    #     own output never reaches the session, not the exact wording of the fallback.
    $stub = New-StubWorkshop -Name 'stub-fake' -ExitCode 0 -ValidMarker $false -OutputLines @(
        'FAKE-EXECUTED'
    )
    $r = Invoke-HookIsolated -RepoDir $Fixture -HomeDir $HookHome -ScriptArgs @('-WorkshopPathOverride', $stub)
    Assert-Equal 0 $r.Code 'fake workshop: exit code 0'
    Assert-Match 'register checks \(consumer registration, lens inventory, agent-def drift\) did not run' $r.Out 'fake workshop: rejected as a workshop -- register checks did not run'
    Assert-NotMatch 'FAKE-EXECUTED' $r.Out 'fake workshop: script was NOT executed'

    # 9r (#1775). [UNLISTED] on its own: its own verdict line, not folded into [UNREGISTERED]'s or
    #     [INVENTORY]'s -- same reasoning as 9f/9i for the two neighbouring markers' own-verdict
    #     scenarios: a whole plugin block the register never named is a different situation, with a
    #     different fix, from "not registered at all" or "an extension list is behind".
    $stub = New-StubWorkshop -Name 'stub-unlisted' -ExitCode 0 -OutputLines @(
        "  [INFO]  DKJ-Solutions/claude-code-specialists / dkj-policy@dkj-claude-plugins: plugin 'dkj-subagents-ecomm@dkj-claude-plugins' is enabled in .claude/settings.json but this manifest's 'plugins' list does not name it -- it was never looped over above, so nothing about it was checked here (no extension check, no version check). Add a plugins[] block for it to dkj-claude-plugins.json, in the same change that enabled it, or remove the enable if that was not intended.",
        "  [UNLISTED] this repo has 1 plugin(s) enabled that its own entry in the connector register does not list (dkj-subagents-ecomm@dkj-claude-plugins) -- add a plugins[] block for each to dkj-claude-plugins.json, in the same change that enabled it. Nothing is broken: the register's view of this repo is simply behind reality.",
        'Summary: 0 error(s), 1 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Equal 0 $r.Code 'unlisted stub: exit code 0'
    Assert-Match '\[UNLISTED\]' $r.Out 'unlisted stub: the marker reaches the session context'
    Assert-Match "this repo's register entry does not list every plugin it has enabled" $r.Out 'unlisted stub: its own verdict line, not the unregistered or inventory one'
    Assert-NotMatch "not in the plugin maintainer's register" $r.Out 'unlisted stub: NOT reported as unregistered -- the entry exists, it is just missing a plugin block'
    Assert-NotMatch 'lens inventory for this repo is behind' $r.Out 'unlisted stub: NOT reported as an inventory drift -- a different subject entirely'
    Assert-NotMatch 'signals found' $r.Out 'unlisted stub: NOT escalated to a signals summary (nothing is wrong with the install)'
    Assert-NotMatch '\[INFO\]' $r.Out 'unlisted stub: the per-signal [INFO] line still stays out'

    # 9s. A clean run gains nothing -- the guard against this becoming a line every session start carries.
    $stub = New-StubWorkshop -Name 'stub-no-unlisted' -ExitCode 0 -OutputLines @(
        '  [OK]    plugin is enabled in .claude/settings.json',
        'Summary: 0 error(s), 0 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'no errors\.' $r.Out 'no-unlisted stub: the plain no-errors line is unchanged'
    Assert-NotMatch 'UNLISTED' $r.Out 'no-unlisted stub: no marker'
    Assert-NotMatch 'does not list every plugin' $r.Out 'no-unlisted stub: no wording about it at all'

    # 9t. Real signals AND [UNLISTED] in one run: both surface -- same regression guard as 9k/9n, the
    #     marker must not be dropped precisely when something else is also wrong.
    $stub = New-StubWorkshop -Name 'stub-unlisted-mixed' -ExitCode 1 -OutputLines @(
        '  [ERROR] life-hub / dkj-subagents-alpha@dkj-claude-plugins: machine record is on v2.9.0, source on v2.11.0',
        '  [UNLISTED] this repo has 1 plugin(s) enabled that its own entry in the connector register does not list (dkj-subagents-ecomm@dkj-claude-plugins) -- add a plugins[] block for each to dkj-claude-plugins.json, in the same change that enabled it. Nothing is broken: the register''s view of this repo is simply behind reality.',
        'Summary: 1 error(s), 1 info signal(s).'
    )
    $r = Invoke-Ps $Hook @('-WorkshopPathOverride', $stub)
    Assert-Match 'signals found' $r.Out 'unlisted mixed: the signals branch fires'
    Assert-Match 'v2\.9\.0' $r.Out 'unlisted mixed: the real [ERROR] surfaces'
    Assert-Match '\[UNLISTED\]' $r.Out 'unlisted mixed: the marker surfaces alongside it'

    # --- 10. A plugin id the marketplace no longer declares --------------------------------------------
    #      THE THREE WAYS Get-PluginDir CAN MISS ARE NOT ONE FINDING, and telling them apart is this
    #      scenario's whole subject. While the lookup was a directory probe there was only one way to
    #      miss -- a name nobody publishes -- so one [ERROR] covered it. Asking the marketplace added a
    #      second, and it is not a fault at all: a plugin renamed upstream leaves every consumer holding
    #      the old id until they migrate.
    #
    #      Measured the day the teams/workflows rename shipped: this check raised four [ERROR] lines
    #      against two real consumers for ids that were correct, deliberately recorded, and which
    #      connectors/README.md had just been updated to say are kept until each consumer migrates. The
    #      check and the doctrine contradicted each other and the doctrine was right, because this
    #      register records what a consumer HAS.
    Write-Host "a retired plugin id is an unmigrated consumer, not an invalid register" -ForegroundColor Cyan
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mfOld = New-FixtureManifest -Extensions @('06-16') -Plugin 'specialists@dkj-claude-plugins'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mfOld, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'retired id: exit code 0 -- an unmigrated consumer does not fail the check'
    Assert-NotMatch '\[ERROR\]' $r.Out 'retired id: and raises no error at all'
    Assert-Match '\[INFO\]' $r.Out 'retired id: it is reported, as an INFO'
    Assert-Match 'has not migrated' $r.Out 'retired id: the line says what the state IS, not just that a lookup failed'
    Assert-Match 'records what they HAVE' $r.Out 'retired id: and why the register is right to still name the old id'

    #      The other two ways must still be errors -- separating them is only worth anything if the
    #      genuine faults keep their verdict.
    $mfBad = New-FixtureManifest -Extensions @('06-16') -Plugin '../../etc/passwd@dkj-claude-plugins'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mfBad, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'malformed id: still exits 1'
    Assert-Match '\[ERROR\]' $r.Out 'malformed id: still an error -- a register file defect is not a migration'
    Assert-Match 'invalid or unknown plugin field' $r.Out 'malformed id: and keeps its own wording'

    # --- 10b. A RETIRED id that IS enabled and has NO install record (#1802) -----------------------
    #      Until #1802 a retired id's 'continue' skipped the whole plugin block, check 4 among it -- so
    #      the two consumers #1802 measured as worst, both enabling nothing but retired ids, were the
    #      two this check could say least about. This is the one question that survives the
    #      retirement: it needs no source folder, only the install administration.
    Write-Host "retired id, ALSO enabled, ALSO recordless: the #1802 finding" -ForegroundColor Cyan
    $oldProfileRetired = $env:USERPROFILE
    try {
        # 10b1. retired + enabled + NO install record -> the new [INFO] fires, states the consequence,
        #       and does NOT hand over a bare install command as the fix -- that command cannot work
        #       for an id the catalogue no longer declares.
        New-FixtureConsumer -ExtensionIds @('06-16')
        Set-FixtureEnabledPlugins -Ids @('specialists@claude-code-specialists')
        $mfRetiredRec = New-FixtureManifest -Extensions @('06-16') -Plugin 'specialists@claude-code-specialists'
        Set-FixtureAdmin '{ "version": 2, "plugins": { } }'
        $env:USERPROFILE = $Fixture
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mfRetiredRec, '-ConsumerPathOverride', $Fixture)
        Assert-Equal 0 $r.Code 'retired+enabled+no record: exit code 0 (still non-error)'
        Assert-NotMatch '\[ERROR\]' $r.Out 'retired+enabled+no record: still no error at all'
        Assert-Match 'no machine record for it either' $r.Out 'retired+enabled+no record: the new #1802 finding fires'
        Assert-Match 'loads none of this plugin' $r.Out 'retired+enabled+no record: states the consequence, same as the current-id sibling'
        Assert-Match 'will NOT fix it' $r.Out 'retired+enabled+no record: says the install command will NOT fix it'
        Assert-Match 'The way out is the migration' $r.Out 'retired+enabled+no record: hands over the migration instead of a bare install command'
        Assert-NotMatch 'settles it' $r.Out 'retired+enabled+no record: not the current-id sibling wording (which ends on ''settles it'')'

        # 10b2. retired + enabled + a record IS PRESENT -> the new line does NOT fire. This is the real
        #       BWJ state (smartwatchbanden / xoxowildhearts hold records for their retired dkj-team-*
        #       ids) -- a false positive here would be the worst possible outcome of this change.
        $fixtureEscapedRetired = ($Fixture -replace '\\', '\\')
        Set-FixtureAdmin ('{ "version": 2, "plugins": { "specialists@claude-code-specialists": [ { "scope": "project", "projectPath": "' + $fixtureEscapedRetired + '", "installPath": "x", "version": "1.0.0" } ] } }')
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mfRetiredRec, '-ConsumerPathOverride', $Fixture)
        Assert-Equal 0 $r.Code 'retired+enabled+record present: exit code 0'
        Assert-Match 'is not a plugin this marketplace declares any more' $r.Out 'retired+enabled+record present: the base retired INFO still fires'
        Assert-NotMatch 'no machine record for it either' $r.Out 'retired+enabled+record present: the new finding does NOT fire -- a record exists (the BWJ state)'

        # 10b3. retired + NOT enabled in the consumer -> the new line does not fire either: the finding
        #       is conditioned on the id being enabled, not merely on being retired and recordless.
        Set-FixtureEnabledPlugins -Ids @('dkj-subagents-alpha@claude-code-specialists')
        Set-FixtureAdmin '{ "version": 2, "plugins": { } }'
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mfRetiredRec, '-ConsumerPathOverride', $Fixture)
        Assert-Equal 0 $r.Code 'retired+not enabled: exit code 0'
        Assert-Match 'is not a plugin this marketplace declares any more' $r.Out 'retired+not enabled: the base retired INFO still fires'
        Assert-NotMatch 'no machine record for it either' $r.Out 'retired+not enabled: the new finding does NOT fire -- not enabled here'
    } finally {
        $env:USERPROFILE = $oldProfileRetired
    }

    # 10b4. -SkipVersions -> the install administration is not read at all in that mode, so the new
    #       finding cannot fire regardless of what the (unread) administration would have said.
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureEnabledPlugins -Ids @('specialists@claude-code-specialists')
    $mfRetiredSkip = New-FixtureManifest -Extensions @('06-16') -Plugin 'specialists@claude-code-specialists'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mfRetiredSkip, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code '-SkipVersions, retired+enabled: exit code 0'
    Assert-Match 'is not a plugin this marketplace declares any more' $r.Out '-SkipVersions, retired+enabled: the base retired INFO still fires'
    Assert-NotMatch 'no machine record for it either' $r.Out '-SkipVersions, retired+enabled: the new finding does NOT fire -- administration not read'

    # 10b5. The retired INFO's trailing clause names what is skipped, and WHY, replacing the old
    #       blanket "their plugin block is skipped, so nothing below is checked for it" wording.
    Assert-Match "extension inventory and the version comparison need this plugin's source folder" $r.Out 'retired INFO: the trailing clause names what needs the source folder'
    Assert-Match 'both are skipped for it' $r.Out 'retired INFO: and says both are skipped, replacing the old blanket wording'
    Assert-NotMatch 'nothing below is checked for it' $r.Out 'retired INFO: the old blanket wording is gone'

    # 10b6. [NOT-INSTALLED-HERE] promotion -- fires only when the connector being walked IS the
    #       session's own repo (Test-IsSessionRepo), the same scoping check 4's own promotion uses.
    $oldProfileNih = $env:USERPROFILE
    try {
        New-FixtureConsumer -ExtensionIds @('06-16')
        Set-FixtureEnabledPlugins -Ids @('specialists@claude-code-specialists')
        $mfRetiredNih = New-FixtureManifest -Extensions @('06-16') -Plugin 'specialists@claude-code-specialists'
        Set-FixtureAdmin '{ "version": 2, "plugins": { } }'
        $env:USERPROFILE = $Fixture

        # Not the session repo (no -OnlyConsumer) -> the [INFO] fires, the marker must not: another
        # machine could still hold the install, so the state is not conclusive from here.
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mfRetiredNih, '-ConsumerPathOverride', $Fixture)
        Assert-Match 'no machine record for it either' $r.Out 'retired+enabled+no record, NOT session repo: the [INFO] fires'
        Assert-NotMatch '\[NOT-INSTALLED-HERE\]' $r.Out 'retired+enabled+no record, NOT session repo: no marker -- another machine could still hold the install'

        # The session repo (-OnlyConsumer) -> the marker rides alongside the [INFO], non-counting.
        $r = Invoke-Ps $Script @('-SkipDrift', '-Manifest', $mfRetiredNih, '-ConsumerPathOverride', $Fixture, '-OnlyConsumer', $Fixture)
        Assert-Equal 0 $r.Code 'retired+enabled+no record, SESSION repo: exit 0 -- non-counting, nothing broken about the source'
        Assert-Match '\[NOT-INSTALLED-HERE\]' $r.Out 'retired+enabled+no record, SESSION repo: the marker fires'
        Assert-Match 'BOTH a retired plugin name and without an install record' $r.Out 'retired+enabled+no record, SESSION repo: the marker names both conditions'
        Assert-Match 'no machine record for it either' $r.Out 'retired+enabled+no record, SESSION repo: the [INFO] is kept too -- a deliberate run should still list everything'
    } finally {
        $env:USERPROFILE = $oldProfileNih
    }

    # --- 11. Check 5 / [UNLISTED]: a plugin enabled in the consumer's settings chain that this
    #      manifest's own 'plugins' list never names at all (#1775). $RepoRoot inside the SCRIPT UNDER
    #      TEST is always this real checkout (it is derived from $PSScriptRoot, not from the fixture), so
    #      $ThisMarketplaceName there is always 'dkj-claude-plugins' -- every id below is chosen with
    #      that in mind.
    Write-Host "check 5 / [UNLISTED]: a plugin enabled here that the manifest's own list does not name" -ForegroundColor Cyan

    # 11a. Enabled, not listed -> a counting [INFO] naming it, exit 0 (informational, not a gate breach).
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureEnabledPlugins -Ids @('dkj-subagents-alpha@dkj-claude-plugins', 'dkj-subagents-ecomm@dkj-claude-plugins')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'unlisted plugin: exit code 0 (INFO, not an error)'
    Assert-Match "\[INFO\].*'dkj-subagents-ecomm@dkj-claude-plugins'.*does not name it" $r.Out 'unlisted plugin: INFO names the id the manifest never lists'
    # 11a / item 3: NOT the session repo (no -OnlyConsumer) -> the [INFO] stands, the [UNLISTED] must not.
    Assert-NotMatch '\[UNLISTED\]' $r.Out 'unlisted plugin, NOT the session repo: no [UNLISTED] marker'

    # 11b. Same fixture, but the consumer IS the session repo (-OnlyConsumer) -> the non-counting
    #      [UNLISTED] line rides alongside the [INFO], and the run still exits 0.
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture, '-OnlyConsumer', $Fixture))
    Assert-Equal 0 $r.Code 'unlisted plugin, SESSION repo: exit 0 -- non-counting, nothing is broken about the source'
    Assert-Match '\[UNLISTED\]' $r.Out 'unlisted plugin, SESSION repo: the marker fires'
    Assert-Match 'dkj-subagents-ecomm@dkj-claude-plugins' $r.Out 'unlisted plugin, SESSION repo: the marker names the id'
    Assert-Match "\[INFO\].*'dkj-subagents-ecomm@dkj-claude-plugins'" $r.Out 'unlisted plugin, SESSION repo: the [INFO] is kept too -- a deliberate run should still list everything'

    # 11c. An id naming a DIFFERENT marketplace is silently out of scope -- not this register's business
    #      to judge a catalogue it does not own. Checked with -OnlyConsumer too, the stronger claim: even
    #      when this IS the session repo, an out-of-scope id raises neither line.
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureEnabledPlugins -Ids @('dkj-subagents-alpha@dkj-claude-plugins', 'some-plugin@other-marketplace')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture, '-OnlyConsumer', $Fixture))
    Assert-Equal 0 $r.Code 'different marketplace id: exit code 0'
    Assert-NotMatch 'some-plugin@other-marketplace' $r.Out 'different marketplace id: not mentioned anywhere -- not this register''s catalogue to judge'
    Assert-NotMatch '\[UNLISTED\]' $r.Out 'different marketplace id: no [UNLISTED] marker, even in the session repo'

    # 11d. An id with NO '@' at all cannot be attributed to any marketplace -- also silently excluded.
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureEnabledPlugins -Ids @('dkj-subagents-alpha@dkj-claude-plugins', 'no-at-sign-id')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture, '-OnlyConsumer', $Fixture))
    Assert-Equal 0 $r.Code 'id without @: exit code 0'
    Assert-NotMatch 'no-at-sign-id' $r.Out 'id without @: not mentioned anywhere -- there is nothing to compare it against'
    Assert-NotMatch '\[UNLISTED\]' $r.Out 'id without @: no [UNLISTED] marker'

    # 11e. Every enabled id is also named in the manifest's own list -> neither line, even in the
    #      session repo. The regression guard against this becoming a line every session start carries.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture, '-OnlyConsumer', $Fixture))
    Assert-NotMatch '\[UNLISTED\]' $r.Out 'fully listed: no [UNLISTED] marker'
    Assert-NotMatch 'does not name it' $r.Out 'fully listed: no unlisted-plugin INFO either'

    # 11f. A RETIRED id (this marketplace's own segment, a name the marketplace no longer declares) that
    #      is enabled and absent from the manifest IS still reported -- the predicate agrees with the
    #      existing 'retired' branch in the per-plugin loop rather than re-excluding by segment what that
    #      branch already treats as worth recording. 'specialists@dkj-claude-plugins' is the id case
    #      10 above already establishes as retired for this marketplace.
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureEnabledPlugins -Ids @('dkj-subagents-alpha@dkj-claude-plugins', 'specialists@dkj-claude-plugins')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture, '-OnlyConsumer', $Fixture))
    Assert-Equal 0 $r.Code 'retired id, unlisted: exit code 0 (non-error)'
    Assert-Match "\[INFO\].*'specialists@dkj-claude-plugins'.*does not name it" $r.Out 'retired id, unlisted: the INFO reports it too'
    Assert-Match '\[UNLISTED\]' $r.Out 'retired id, unlisted: the [UNLISTED] marker fires'
    Assert-Match 'specialists@dkj-claude-plugins' $r.Out 'retired id, unlisted: the marker names the retired id'

    # 11g. No settings file at all -> AnyFileExists is false, and check 5 stays silent entirely: an
    #      absence claim drawn from a file that does not exist is exactly what this repo refuses. The run
    #      still fails overall (the pre-existing 'no settings file found' guardrail), but that is a
    #      different, pre-existing finding -- not this check speaking where it has nothing to read.
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture, '-OnlyConsumer', $Fixture))
    Assert-Equal 1 $r.Code 'no settings file: still exit 1 (the pre-existing guardrail, not check 5)'
    Assert-Match '\[ERROR\].*no settings file found' $r.Out 'no settings file: the pre-existing guardrail still fires'
    Assert-NotMatch '\[UNLISTED\]' $r.Out 'no settings file: check 5 stays silent -- nothing to read'
    Assert-NotMatch 'does not name it' $r.Out 'no settings file: no unlisted-plugin INFO either'

    # 11h (Victor's finding 4). An id where '@' is the FIRST character carries an attributable
    #      marketplace segment (everything after it) but an EMPTY plugin-name segment before it -- not a
    #      real plugin id, the same shape Test-PluginNameSlug rejects elsewhere in this file as malformed.
    #      Deliberately excluded, same as an id with no '@' at all (11d): there is no plugin name to write
    #      an 'add a plugins[] block for it' finding about. Checked with -OnlyConsumer, the stronger claim.
    New-FixtureConsumer -ExtensionIds @('06-16')
    Set-FixtureEnabledPlugins -Ids @('dkj-subagents-alpha@dkj-claude-plugins', '@dkj-claude-plugins')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture, '-OnlyConsumer', $Fixture))
    Assert-Equal 0 $r.Code 'id with empty plugin name: exit code 0'
    Assert-NotMatch '\[UNLISTED\]' $r.Out 'id with empty plugin name: no [UNLISTED] marker'
    Assert-NotMatch 'does not name it' $r.Out 'id with empty plugin name: no unlisted-plugin INFO either'

    # --- 12. Check 6: a consumer's CI runner names a path this tree no longer has (#1805) ----------
    # THE FIXTURES NAME REAL PATHS OF THIS REPO, not invented ones, and one of them deliberately names
    # a path that USED to exist here (plugins/workflows/contributing-davekjohn/...). That is the exact
    # string two consumers were still running after the September 5 move, and a fixture that invented a
    # path would prove the regex works without proving the check answers the case it was built for.
    Write-Host "`n-- 12. check 6: a runner reaching into a path this tree no longer has --" -ForegroundColor Cyan

    function New-FixtureWorkflowText {
        # THE YAML SHAPE, WITHOUT A DISK. Split out from New-FixtureWorkflow when scenario 13 arrived
        # (#1808): the remote read is handed workflow TEXT rather than a path, and the whole point of
        # it going through the same judgement is lost if it is fed a different fixture shape than the
        # local half. One builder, two transports -- the same split the script itself makes between
        # Write-RunnerPathFinding and its two callers.
        #
        # -PathFirst and -Commented are the two shapes the first cut of the parser silently missed.
        # They are switches on the shared helper rather than bespoke fixtures so that every OTHER
        # assertion in this scenario keeps holding over them unchanged.
        param(
            [Parameter(Mandatory)][string]$Repository,
            [Parameter(Mandatory)][string]$ScriptPath,
            [switch]$PathFirst,
            [switch]$Commented,
            # -Ref and -Credential are check 6d's (#2337): the ref the checkout fetches at ('' writes no
            # ref: line at all), and whether the job holds a write credential beside it.
            [AllowEmptyString()][string]$Ref = 'main',
            [switch]$Credential
        )
        $refKey = if ($Ref) { @("          ref: $Ref") } else { @() }
        $withKeys = if ($PathFirst) {
            @('          path: .workflow-scripts', ("          repository: $Repository")) + $refKey
        } elseif ($Commented) {
            @(("          repository: $Repository  # the shared workflow scripts")) + $refKey + @('          path: .workflow-scripts   # where they land')
        } else {
            @(("          repository: $Repository")) + $refKey + @('          path: .workflow-scripts')
        }
        $credentialKeys = if ($Credential) { @('        env:', '          GH_TOKEN: ${{ secrets.FOLD_PUSH_TOKEN }}') } else { @() }
        return (@(
            'name: Fixture'
            'on:'
            '  pull_request:'
            '    branches: [main]'
            'jobs:'
            '  fixture:'
            '    runs-on: windows-latest'
            '    steps:'
            '      - uses: actions/checkout@v5'
            ''
            '      - uses: actions/checkout@v5'
            '        with:'
        ) + $withKeys + @(
            ''
            '      - shell: powershell'
        ) + $credentialKeys + @(
            '        run: |'
            ("          powershell -NoProfile -ExecutionPolicy Bypass -File .workflow-scripts/$ScriptPath -Branch " + '"x"')
        ) -join "`n")
    }

    function New-FixtureWorkflow {
        <# The same text, written where check 6's LOCAL half reads it. #>
        param(
            [Parameter(Mandatory)][string]$Name,
            [Parameter(Mandatory)][string]$Repository,
            [Parameter(Mandatory)][string]$ScriptPath,
            [switch]$PathFirst,
            [switch]$Commented,
            [AllowEmptyString()][string]$Ref = 'main',
            [switch]$Credential
        )
        $dir = Join-Path $Fixture '.github\workflows'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir $Name), (New-FixtureWorkflowText -Repository $Repository -ScriptPath $ScriptPath -PathFirst:$PathFirst -Commented:$Commented -Ref $Ref -Credential:$Credential))
    }

    # 12a. The current path -- silence, and nothing about it in the output. This is the case every
    #      healthy consumer is in, so a check that cannot stay quiet here is one nobody will keep.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'branch-entry.yml' -Repository 'DKJ-Solutions/dkj-claude-plugins' -ScriptPath 'plugins/dkj-policy/scripts/lint/check-branch-entry.ps1'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'current runner path: exit code 0'
    Assert-NotMatch 'does not exist here' $r.Out 'current runner path: no finding'

    # 12b. The retired path -- an ERROR that names the file, the line, and where the script is NOW.
    #      The suggestion is asserted because it is the whole difference between a report and a repair:
    #      the reader is in a repo that does not contain this tree and cannot go looking.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'branch-entry.yml' -Repository 'DKJ-Solutions/dkj-claude-plugins' -ScriptPath 'plugins/workflows/contributing-davekjohn/scripts/lint/check-branch-entry.ps1'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'retired runner path: exit code 1 -- it counts as an error'
    Assert-Match 'branch-entry\.yml line \d+' $r.Out 'retired runner path: names the workflow file and the line'
    Assert-Match 'plugins/workflows/contributing-davekjohn/scripts/lint/check-branch-entry\.ps1' $r.Out 'retired runner path: quotes the path it found'
    Assert-Match 'it is at plugins/dkj-policy/scripts/lint/check-branch-entry\.ps1' $r.Out 'retired runner path: offers the PUBLISHED copy first, not this repo own scripts/ path'

    # 12c. The OLD OWNER still counts. This repo moved from DaveKJohn to DKJ-Solutions on September 2,
    #      2026 and a consumer scaffolded before that names the old owner, which still resolves through
    #      the transfer redirect. Matching owner/name would skip the file and report nothing -- the same
    #      silence this check exists to end, arriving through the guard itself.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'branch-entry.yml' -Repository 'DaveKJohn/claude-code-specialists' -ScriptPath 'plugins/workflows/contributing-davekjohn/scripts/lint/check-branch-entry.ps1'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'old owner, retired path: still exit code 1'
    Assert-Match 'does not exist here' $r.Out 'old owner, retired path: still reported'

    # 12d. A checkout of somebody ELSE's repository is not this check's business, whatever path it runs.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'other.yml' -Repository 'someone/unrelated-repo' -ScriptPath 'plugins/workflows/contributing-davekjohn/scripts/lint/check-branch-entry.ps1'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'another repository checked out: exit code 0'
    Assert-NotMatch 'does not exist here' $r.Out 'another repository checked out: no finding'

    # 12e. A script name that exists NOWHERE here reads as removed, not moved -- a different
    #      conversation, and the message has to be able to say so rather than trailing off.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'branch-entry.yml' -Repository 'DKJ-Solutions/claude-code-specialists' -ScriptPath 'plugins/dkj-policy/scripts/lint/check-nothing-of-this-name.ps1'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'unknown script name: exit code 1'
    Assert-Match 'removed rather than moved' $r.Out 'unknown script name: says removed rather than moved'

    # 12f. A TRAVERSING REFERENCE IS NOT LOOKED UP (Sebastian's finding 1). The capture charset admits
    #      '.' and '/' because a path needs them, so '../../..' matches exactly as a real reference
    #      does -- and Test-Path resolves it against the real filesystem. Handing it one unchecked
    #      turns this check into an existence oracle for the maintainer's own disk, answered by whether
    #      an [ERROR] line appears, unattended, at every session start. It is reported as its own state
    #      rather than as a missing path, because nothing was looked up.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'branch-entry.yml' -Repository 'DKJ-Solutions/claude-code-specialists' -ScriptPath '../../../../check-branch-entry.ps1'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'traversing path: exit code 1 -- reported, never dropped'
    Assert-Match 'does not stay inside the checkout' $r.Out 'traversing path: named as escaping the checkout'
    Assert-Match 'was NOT looked up here' $r.Out 'traversing path: says outright that no lookup happened'
    Assert-NotMatch 'does not exist here' $r.Out 'traversing path: NOT phrased as a missing path -- that would be an answer it refused to compute'
    Assert-NotMatch 'removed rather than moved' $r.Out 'traversing path: and no recursive search was run for it either'

    # 12g. THE WORKFLOW FILENAME IS A CONSUMER-OWNED VALUE TOO (Sebastian's finding 2). It was the one
    #      value in this message printed raw while its two neighbours were wrapped. Square brackets are
    #      legal in an NTFS filename and the SessionStart hooks decide how loudly to surface a run by
    #      matching '[ERROR]' over its whole output -- so a file named like this would not merely look
    #      odd, it would be COUNTED. The finding itself must still fire.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'x[ERROR] forged.yml' -Repository 'DKJ-Solutions/claude-code-specialists' -ScriptPath 'plugins/workflows/contributing-davekjohn/scripts/lint/check-branch-entry.ps1'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'bracketed filename: the real finding still fires'
    Assert-Match 'does not exist here' $r.Out 'bracketed filename: and it is the stale-path finding, not something else'
    Assert-Match 'xERROR forged\.yml' $r.Out 'bracketed filename: the name is printed with its brackets stripped'
    Assert-NotMatch 'x\[ERROR\] forged' $r.Out 'bracketed filename: the forged marker never reaches the output verbatim'

    # 12h/12i. THE TWO SHAPES THE PARSER FIRST MISSED (Victor's findings 1 and 2). Both are ordinary
    #      hand edits of a scaffolded runner -- swapping two keys, and adding an end-of-line comment --
    #      and both made the whole file read as carrying no reference at all. A false negative here is
    #      #1805 recurring one layer down, inside the detector built to close it, so each gets a
    #      scenario proving the finding still fires rather than a note saying it should.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'branch-entry.yml' -Repository 'DKJ-Solutions/claude-code-specialists' -ScriptPath 'plugins/workflows/contributing-davekjohn/scripts/lint/check-branch-entry.ps1' -PathFirst
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'path: written above repository:: still exit code 1'
    Assert-Match 'does not exist here' $r.Out 'path: written above repository:: the stale path is still found'

    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'branch-entry.yml' -Repository 'DKJ-Solutions/claude-code-specialists' -ScriptPath 'plugins/workflows/contributing-davekjohn/scripts/lint/check-branch-entry.ps1' -Commented
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'trailing YAML comments: still exit code 1'
    Assert-Match 'does not exist here' $r.Out 'trailing YAML comments: the stale path is still found'
    # 12h. THE RETIRED REPO NAME STILL COUNTS, for the same reason 12c gives about the old OWNER and
    #      on a different axis: this repo was renamed from 'claude-code-specialists' to
    #      'dkj-claude-plugins' on September 10, 2026 (#1769), and a consumer scaffolded before that
    #      day still writes the old name into its runner. The runner keeps WORKING -- GitHub answers
    #      the transfer redirect -- so the only thing a rename breaks is this check, which matches on
    #      the name half. Matching the current name alone would report nothing about that consumer, and
    #      a consumer nothing is reported about reads as clean.
    #
    #      THE TWO AXES EXPIRE ON DIFFERENT DAYS, which is why this is its own scenario rather than a
    #      second assert on 12c: an owner transfer and a name change are separate acts, and a consumer
    #      can be behind on either, both, or neither. This one is behind on the name and current on the
    #      owner, which 12c cannot exercise.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'branch-entry.yml' -Repository 'DKJ-Solutions/claude-code-specialists' -ScriptPath 'plugins/workflows/contributing-davekjohn/scripts/lint/check-branch-entry.ps1'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 1 $r.Code 'retired repo name: still exit code 1'
    Assert-Match 'does not exist here' $r.Out 'retired repo name: the stale path is still found'
    Assert-Match 'branch-entry\.yml line \d+' $r.Out 'retired repo name: names the workflow file and the line'

    # --- 12j-12m. Check 6c: a consumer that reaches into this tree NOWHERE AT ALL (#1850) ----------
    # Check 6 judges paths that ARE named, so every scenario above needs a reference to exist before it
    # can say anything. A consumer running none of the three runners names none, produces no finding,
    # and reads exactly like a fully adopted one -- measured on DaveKJohn/djcylow-react, which
    # registers the full core-team adoption and whose entire .github/workflows/ is one ci.yml.
    #
    # THE FIXTURE MANIFEST HAS TO NAME THE WORKFLOW PLUGIN, because that is the gate: the runners come
    # from adopt-dkj-policy, so a consumer registered for the subagent teams alone is not asked. 12m is
    # that gate's own scenario, and it is the one that keeps every scenario ABOVE this block silent --
    # each of them writes the default manifest, which names dkj-subagents-alpha only.
    $wfPlugin = 'dkj-policy@dkj-claude-plugins'

    # 12j. ADOPTED -- silence. The case every healthy consumer is in, asserted first for the same
    #      reason 12a is: a check that cannot stay quiet here is one nobody keeps.
    New-FixtureConsumer -ExtensionIds @()
    Set-FixtureEnabledPlugins -Ids @($wfPlugin)
    New-FixtureWorkflow -Name 'branch-entry.yml' -Repository 'DKJ-Solutions/dkj-claude-plugins' -ScriptPath 'plugins/dkj-policy/scripts/lint/check-branch-entry.ps1'
    $mf = New-FixtureManifest -Extensions @() -Plugin $wfPlugin
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'adopted consumer: exit code 0'
    Assert-NotMatch 'none of the runners' $r.Out 'adopted consumer: no adoption finding'

    # 12k. WORKFLOWS, BUT NOT ONE OF THEM CHECKS THIS REPOSITORY OUT. This is djcylow-react's shape,
    #      and before #1850 it was indistinguishable from 12j. [INFO] and exit 0, not [ERROR]: both
    #      halves of adopt-dkj-policy are optional, so this is a state that may be a decision -- the
    #      register's own doctrine for an unmigrated plugin id, one check over.
    New-FixtureConsumer -ExtensionIds @()
    Set-FixtureEnabledPlugins -Ids @($wfPlugin)
    New-FixtureWorkflow -Name 'ci.yml' -Repository 'someone/unrelated-repo' -ScriptPath 'plugins/dkj-policy/scripts/lint/check-branch-entry.ps1'
    $mf = New-FixtureManifest -Extensions @() -Plugin $wfPlugin
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'unadopted consumer: exit code 0 -- a state, not a defect'
    Assert-Match '\[INFO\]' $r.Out 'unadopted consumer: reported as an INFO'
    Assert-Match 'none of the runners' $r.Out 'unadopted consumer: says no runner of this workflow is running there'
    Assert-Match 'not one of them checks this repository out' $r.Out 'unadopted consumer: says which of the two no-runner states it is in'
    Assert-Match "notes" $r.Out 'unadopted consumer: hands over where to record a deliberate answer'
    Assert-Match 'nothing recognisable reaches into this tree' $r.Out 'unadopted consumer: states its own bound rather than claiming nothing is there'

    # 12l. NO .github/workflows AT ALL -- the same finding, and it has to READ differently, because
    #      "you have workflows and none of them does this" and "you have none" are different repairs.
    New-FixtureConsumer -ExtensionIds @()
    Set-FixtureEnabledPlugins -Ids @($wfPlugin)
    $mf = New-FixtureManifest -Extensions @() -Plugin $wfPlugin
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'no workflows at all: exit code 0'
    Assert-Match 'has no \.github/workflows at all' $r.Out 'no workflows at all: named as its own state'
    Assert-NotMatch 'not one of them checks this repository out' $r.Out 'no workflows at all: not the other sentence'

    # 12m. THE GATE. A consumer registered for the subagent teams only has no reason to hold these
    #      runners, and an [INFO] against it would be this register inventing an expectation that
    #      consumer never took on.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'workflow plugin not registered: exit code 0'
    Assert-NotMatch 'none of the runners' $r.Out 'workflow plugin not registered: not asked at all'

    # 12n. THE SOURCE REPO IS NEVER ASKED, and this is a regression test rather than a nicety: THIS
    #      repo names the workflow plugin in its own record and runs all three of those scripts by
    #      LOCAL path, because it is the tree every consumer checks out. So it is the one registered
    #      repo that can never produce a reference, and without the exclusion it would be the loudest
    #      finding in every run. The exit code is deliberately not asserted -- this points the check at
    #      the real repository, whose other verdicts are not this scenario's subject.
    $mf = New-FixtureManifest -Extensions @() -Plugin $wfPlugin -Repo 'DKJ-Solutions/dkj-claude-plugins'
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $RepoRoot))
    Assert-NotMatch 'none of the runners' $r.Out 'source repo: not asked whether it checks itself out'

    # --- 12o-12t. Check 6d: a WRITE runner fetching this tree at a moving or stale ref (#2337) ------
    # #2333 pinned the shared-scripts checkout of the three runners that hold a credential, and made a
    # re-run of adopt-ci-floor report a stale one. A consumer nobody re-runs it in stays on ref: main
    # beside FOLD_PUSH_TOKEN; this is the register saying so. The version it judges against is this
    # tree's own dkj-policy plugin.json, read here the same way so the suite survives every release.
    $pinVersion = [string]((Get-Content -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy\.claude-plugin\plugin.json') -Raw | ConvertFrom-Json).version)
    $pinSha = '0123456789abcdef0123456789abcdef01234567'
    $pinScript = 'plugins/dkj-policy/scripts/release/fold-changelog-entry.ps1'

    # 12o. The pre-#2333 shape: a credential beside ref: main. [INFO], exit 0 -- it works, and is exposed.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'fold-on-merge.yml' -Repository 'DKJ-Solutions/dkj-claude-plugins' -ScriptPath $pinScript -Credential
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'write runner on main: exit code 0 -- a state, not a red gate'
    Assert-Match "\[INFO\].*fold-on-merge\.yml line \d+ holds a write credential and fetches this repo's scripts at 'main' -- a moving ref" $r.Out 'write runner on main: an INFO naming the file, the line and the ref'
    Assert-Match "v$([regex]::Escape($pinVersion)) is the current one" $r.Out 'write runner on main: names the release to pin to'

    # 12p. NO ref: AT ALL is the default branch -- moving, and said as such rather than read as unknown.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'fold-on-merge.yml' -Repository 'DKJ-Solutions/dkj-claude-plugins' -ScriptPath $pinScript -Credential -Ref ''
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Match 'no ref: at all \(the default branch\) -- a moving ref' $r.Out 'write runner with no ref: reported as moving'

    # 12q. Pinned, but at an older release -- behind, with both versions named.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'verify-resolved.yml' -Repository 'DKJ-Solutions/dkj-claude-plugins' -ScriptPath $pinScript -Credential -Ref "$pinSha # v0.0.1"
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-Equal 0 $r.Code 'write runner behind: exit code 0'
    Assert-Match "verify-resolved\.yml line \d+ .*pinned at v0\.0\.1, behind v$([regex]::Escape($pinVersion))" $r.Out 'write runner behind: names the pin and the current release'
    Assert-NotMatch 'a moving ref' $r.Out 'write runner behind: not called a moving ref'

    # 12r. Pinned at this release -- silence. The state adopt-ci-floor writes, so it must stay quiet.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'merge-on-green.yml' -Repository 'DKJ-Solutions/dkj-claude-plugins' -ScriptPath $pinScript -Credential -Ref "$pinSha # v$pinVersion"
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-NotMatch 'holds a write credential' $r.Out 'write runner pinned at this release: no pin finding'

    # 12s. A READ-ONLY runner on main -- silence. branch-entry.yml tracks main on purpose (#1805), and
    #      every scenario in 12a-12n is this shape, so a check that fired here would have fired there.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'branch-entry.yml' -Repository 'DKJ-Solutions/dkj-claude-plugins' -ScriptPath 'plugins/dkj-policy/scripts/lint/check-branch-entry.ps1'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-NotMatch 'holds a write credential' $r.Out 'read-only runner on main: not judged'

    # 12t. A SHA with no version beside it is pinned but undatable -- not called moving, not called behind.
    New-FixtureConsumer -ExtensionIds @('06-16')
    New-FixtureWorkflow -Name 'fold-on-merge.yml' -Repository 'DKJ-Solutions/dkj-claude-plugins' -ScriptPath $pinScript -Credential -Ref $pinSha
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-NotMatch 'holds a write credential' $r.Out 'bare SHA pin: no finding either way'

    # --- 13. Check 6b: -RemoteRunners reads an ABSENT consumer's runners over the API (#1808) ------
    # Check 6 reads the consumer's local checkout, so it inherited check 1: an absent consumer was
    # [SKIP] and its runners were not read at all -- and the consumers most likely to carry a stale
    # path are the ones nobody visits, which are the ones least likely to be checked out where you
    # happen to be running. Measured on the branch that built check 6: of six registered connectors,
    # three were [SKIP], including both of the two #1805 reported as red.
    #
    # DRIVEN AGAINST A FAKE gh ON PATH, not the real one. The subject is what this script does with
    # each of the API's answers, and there is exactly one way to exercise the answer that matters most
    # -- a repository the credential cannot see -- without owning such a repository.
    Write-Host "`n-- 13. check 6b: the opt-in network read (-RemoteRunners) --" -ForegroundColor Cyan

    New-Item -ItemType Directory -Path $FakeBin -Force | Out-Null
    $Utf8NoBom = New-Object System.Text.UTF8Encoding $false
    # 'auth status' answers the run-level probe; 'graphql' answers the per-connector read out of
    # GH_GRAPHQL_BODY with GH_GRAPHQL_EXIT as its exit code -- gh really does exit 1 on a response
    # carrying an errors[] block, which is why the script parses the body before it looks at the code.
    # EVERY call is logged, including auth status, because 13a's claim is that NONE is made.
    $ghImpl = @'
if ($env:GH_CALL_LOG) { Add-Content -Path $env:GH_CALL_LOG -Value ($args -join ' ') }
if ($args -contains 'auth' -and $args -contains 'status') {
    if ($env:GH_AUTH_FAIL) { [Console]::Error.WriteLine('fake gh: you are not logged in'); exit 1 }
    exit 0
}
if ($args -contains 'graphql') {
    if ($env:GH_GRAPHQL_BODY) { Write-Output $env:GH_GRAPHQL_BODY }
    if ($env:GH_GRAPHQL_EXIT) { exit ([int]$env:GH_GRAPHQL_EXIT) }
    exit 0
}
exit 1
'@
    [System.IO.File]::WriteAllText((Join-Path $FakeBin 'gh-impl.ps1'), $ghImpl, $Utf8NoBom)
    $ghCmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0gh-impl.ps1`" %*`r`nexit /b %ERRORLEVEL%`r`n"
    [System.IO.File]::WriteAllText((Join-Path $FakeBin 'gh.cmd'), $ghCmd, $Utf8NoBom)
    $env:PATH = "$FakeBin;$env:PATH"
    $env:GH_CALL_LOG = $GhCalls

    function New-GraphQlAnswer {
        <# The shape 'gh api graphql' returns for this query. -Files is a list of @{ Name; Text }; a
           $null Text is the API declining to render a blob as text, which is its own outcome. Built
           through ConvertTo-Json rather than hand-written so the workflow YAML inside it is escaped
           by the same encoder that will have to decode it. #>
        param([object[]]$Files = @(), [string]$Branch = 'main', [switch]$NoRepository, [switch]$NoWorkflowDir, [string]$ErrorMessage = '')
        if ($NoRepository) {
            $obj = [ordered]@{
                data   = [ordered]@{ repository = $null }
                errors = @(@{ type = 'NOT_FOUND'; message = $ErrorMessage })
            }
            return ($obj | ConvertTo-Json -Depth 10 -Compress)
        }
        $repo = [ordered]@{ defaultBranchRef = [ordered]@{ name = $Branch } }
        if ($NoWorkflowDir) {
            $repo['object'] = $null
        } else {
            $repo['object'] = [ordered]@{ entries = @($Files | ForEach-Object {
                [ordered]@{ name = $_.Name; type = 'blob'; object = [ordered]@{ text = $_.Text } }
            }) }
        }
        return (([ordered]@{ data = [ordered]@{ repository = $repo } }) | ConvertTo-Json -Depth 10 -Compress)
    }

    function Invoke-Absent {
        <# The script against a manifest whose checkout does NOT resolve -- the [SKIP] branch, which is
           where the network read lives. Deliberately no -ConsumerPathOverride: that parameter's whole
           job is to make a checkout resolve. #>
        param([string]$ManifestPath, [switch]$Remote)
        Remove-Item -Path $GhCalls -Force -ErrorAction SilentlyContinue
        $callArgs = $base + @('-Manifest', $ManifestPath)
        if ($Remote) { $callArgs += '-RemoteRunners' }
        $run = Invoke-Ps $Script $callArgs
        $log = if (Test-Path -LiteralPath $GhCalls) { (Get-Content -LiteralPath $GhCalls -Raw) } else { '' }
        return [pscustomobject]@{ Code = $run.Code; Out = $run.Out; Calls = $log }
    }

    $staleYml   = New-FixtureWorkflowText -Repository 'DKJ-Solutions/claude-code-specialists' -ScriptPath 'plugins/workflows/contributing-davekjohn/scripts/lint/check-branch-entry.ps1'
    $currentYml = New-FixtureWorkflowText -Repository 'DKJ-Solutions/claude-code-specialists' -ScriptPath 'plugins/dkj-policy/scripts/lint/check-branch-entry.ps1'

    # 13a. THE DEFAULT IS OFF, AND NOT ONE CALL IS MADE. This is the reason the feature is a switch at
    #      all -- the script runs from connector-sessioncheck.ps1 at every session start -- so it is
    #      asserted against the call log rather than trusted to the reading of an if. The [SKIP] also
    #      has to keep its original wording, because that sentence is true again when nothing is read.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $env:GH_GRAPHQL_BODY = New-GraphQlAnswer -Files @(@{ Name = 'branch-entry.yml'; Text = $staleYml })
    Remove-Item Env:\GH_GRAPHQL_EXIT -ErrorAction SilentlyContinue
    Remove-Item Env:\GH_AUTH_FAIL -ErrorAction SilentlyContinue
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Absent -ManifestPath $mf
    Assert-Equal 0 $r.Code 'switch off: exit code 0'
    Assert-Match 'not present on this machine -- not checked' $r.Out 'switch off: the plain [SKIP] wording, unchanged'
    Assert-Equal '' $r.Calls 'switch off: gh is not called AT ALL -- the cost claim, asserted'
    Assert-NotMatch 'does not exist here' $r.Out 'switch off: and the stale path the fake would have served is not reported'

    # 13b. THE CASE THE SWITCH EXISTS FOR: an absent consumer whose runner names a path this tree no
    #      longer holds is now an [ERROR], with the same wording and the same repair suggestion the
    #      local half gives -- plus the branch it was read from, because the reader cannot open the
    #      file to check which revision this is about.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Absent -ManifestPath $mf -Remote
    Assert-Equal 1 $r.Code 'remote read, stale path: exit code 1 -- it counts as an error'
    Assert-Match 'branch-entry\.yml line \d+' $r.Out 'remote read, stale path: names the workflow file and the line'
    Assert-Match 'it is at plugins/dkj-policy/scripts/lint/check-branch-entry\.ps1' $r.Out 'remote read, stale path: same repair suggestion as the local half'
    Assert-Match 'read from main over the API' $r.Out 'remote read, stale path: says which branch it judged'
    Assert-Match 'no checkout of this consumer is on this machine' $r.Out 'remote read, stale path: and why it read the API rather than the disk'
    Assert-Match 'graphql' $r.Calls 'remote read, stale path: the call was actually made'
    Assert-NotMatch 'not present on this machine -- not checked\.' $r.Out 'remote read: the [SKIP] no longer claims nothing was checked'

    # 13c. A CURRENT PATH IS SILENT OVER THE NETWORK TOO. The healthy consumer is the common one, and a
    #      check that cannot stay quiet on a deliberate sweep of the whole register is one nobody runs
    #      twice.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $env:GH_GRAPHQL_BODY = New-GraphQlAnswer -Files @(@{ Name = 'branch-entry.yml'; Text = $currentYml })
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Absent -ManifestPath $mf -Remote
    Assert-Equal 0 $r.Code 'remote read, current path: exit code 0'
    Assert-NotMatch 'does not exist here' $r.Out 'remote read, current path: no finding'
    Assert-Match 'graphql' $r.Calls 'remote read, current path: and it did look -- silence here is a verdict, not a skip'

    # 13c2. CHECK 6d RIDES THE SAME ROUTE (#2337). The consumers most likely to carry a pre-#2333
    #       ref: main are the ones nobody visits, so the pin finding has to reach them over the network
    #       too -- with the branch it was read from, like every remote finding.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $foldYml = New-FixtureWorkflowText -Repository 'DKJ-Solutions/dkj-claude-plugins' -ScriptPath 'plugins/dkj-policy/scripts/release/fold-changelog-entry.ps1' -Credential
    $env:GH_GRAPHQL_BODY = New-GraphQlAnswer -Files @(@{ Name = 'fold-on-merge.yml'; Text = $foldYml })
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Absent -ManifestPath $mf -Remote
    Assert-Equal 0 $r.Code 'remote read, write runner on main: exit code 0'
    Assert-Match "fold-on-merge\.yml line \d+ holds a write credential .*a moving ref.*read from main over the API" $r.Out 'remote read, write runner on main: the pin finding, naming the branch it read'

    # 13d. THE THIRD STATE, AND THE WHOLE REASON THIS IS WORTH A SWITCH. A repository the credential
    #      cannot see comes back as HTTP 200 with a null repository, an errors[] block, and exit 1 from
    #      gh. It must be a STATED not-checked: silence would be indistinguishable from 13c above, on a
    #      check whose entire subject is a breach nobody has noticed. The API's own sentence is quoted
    #      because 'gh exited 1' does not tell the reader whether to log in or to fix the register.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $env:GH_GRAPHQL_BODY = New-GraphQlAnswer -NoRepository -ErrorMessage "Could not resolve to a Repository with the name 'fixture/consumer'."
    $env:GH_GRAPHQL_EXIT = '1'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Absent -ManifestPath $mf -Remote
    Assert-Equal 0 $r.Code 'unreadable repo: exit code 0 -- our reach, not the consumer breaching anything'
    Assert-Match '\[INFO\].*could not be read' $r.Out 'unreadable repo: stated, not silent'
    Assert-Match 'Could not resolve to a Repository' $r.Out "unreadable repo: quotes the API's own message rather than the exit code"
    Assert-Match 'Nothing about them was checked' $r.Out 'unreadable repo: says outright that no verdict was reached'
    Assert-Match 'gh api repos/fixture/consumer' $r.Out 'unreadable repo: hands over the command that shows what gh says'
    Remove-Item Env:\GH_GRAPHQL_EXIT -ErrorAction SilentlyContinue

    # 13e. NO .github/workflows AT ALL is silence, and deliberately not the third state: it is the same
    #      verdict the local half reaches when the directory is not there. The distinction is only
    #      available because the query asks in GraphQL -- over REST both this and 13d are an HTTP 404.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $env:GH_GRAPHQL_BODY = New-GraphQlAnswer -NoWorkflowDir
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Absent -ManifestPath $mf -Remote
    Assert-Equal 0 $r.Code 'no workflows directory: exit code 0'
    Assert-NotMatch 'could not be read' $r.Out 'no workflows directory: NOT reported as unreadable -- the repo answered'
    Assert-NotMatch 'does not exist here' $r.Out 'no workflows directory: and nothing to find in it'

    # 13f. A BLOB WITH NO TEXT IS ITS OWN NOTHING. The API declines to render a binary or over-sized
    #      blob, and treating that null as an empty workflow would read as 'this file names no
    #      reference' -- the exact false negative the lib's header warns about, arriving through the
    #      transport instead of the parser. The OTHER file in the same repo must still be judged.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $env:GH_GRAPHQL_BODY = New-GraphQlAnswer -Files @(
        @{ Name = 'unreadable.yml'; Text = $null },
        @{ Name = 'branch-entry.yml'; Text = $staleYml }
    )
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Absent -ManifestPath $mf -Remote
    Assert-Equal 1 $r.Code 'text-less blob: exit code 1 -- the second file is still judged'
    Assert-Match 'unreadable\.yml came back without text' $r.Out 'text-less blob: named as not judged'
    Assert-Match 'was NOT judged' $r.Out 'text-less blob: and said so in as many words'
    Assert-Match 'branch-entry\.yml line \d+' $r.Out 'text-less blob: the sibling workflow is still reported'

    # 13g. A REFUSED REQUEST IS SAID OUT LOUD. -RemoteRunners was typed on purpose, so falling back to
    #      the ordinary [SKIP] would answer a deliberate question with the silence it was typed to end.
    #      Asked ONCE per run rather than per connector, because gh holding no credential is a property
    #      of the machine.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $env:GH_AUTH_FAIL = '1'
    $env:GH_GRAPHQL_BODY = New-GraphQlAnswer -Files @(@{ Name = 'branch-entry.yml'; Text = $staleYml })
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Absent -ManifestPath $mf -Remote
    Assert-Equal 0 $r.Code 'gh not authenticated: exit code 0'
    Assert-Match "gh auth status' exited 1" $r.Out 'gh not authenticated: named, with what gh answered'
    Assert-Match 'no consumer.s runners were read over the network' $r.Out 'gh not authenticated: says what the switch did not do'
    Assert-NotMatch 'graphql' $r.Calls 'gh not authenticated: and no repository read was attempted'
    Assert-NotMatch 'does not exist here' $r.Out 'gh not authenticated: the stale path the fake would have served is NOT reported'
    Remove-Item Env:\GH_AUTH_FAIL -ErrorAction SilentlyContinue

    # 13h. NO gh AT ALL is the same refusal through a different door, and it is a different branch of
    #      the code. PATH is cut down to an empty directory plus the two Windows directories a child
    #      powershell needs to start at all -- gh lives in neither, and git goes with it, which the
    #      script already degrades over (the source stamp is in a try/catch and simply does not print).
    #      $PSHOME IS IN THERE BECAUSE Invoke-Ps CALLS 'powershell' BY BARE NAME: cutting PATH to the
    #      empty directory alone made this scenario fail on 'The term powershell is not recognized',
    #      which is the harness losing its own interpreter rather than the script meeting no gh.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $noGhBin = Join-Path $Fixture 'no-gh-bin'
    New-Item -ItemType Directory -Path $noGhBin -Force | Out-Null
    $mf = New-FixtureManifest -Extensions @('06-16')
    $savedPath = $env:PATH
    $env:PATH = "$noGhBin;$PSHOME;$env:SystemRoot\System32"
    try { $r = Invoke-Absent -ManifestPath $mf -Remote } finally { $env:PATH = $savedPath }
    Assert-Equal 0 $r.Code 'no gh on PATH: exit code 0'
    Assert-Match "'gh' is not on PATH" $r.Out 'no gh on PATH: named as the reason'
    Assert-Match 'still judged off the disk by check 6' $r.Out 'no gh on PATH: and says what DOES still work'

    # 13i. THE SLUG IS GUARDED BEFORE IT REACHES A URL. 'repo' is manifest content from a public
    #      repository -- the same data the localCheckout guardrails already refuse to trust -- and here
    #      it would become the owner and name of an API call. Held to GitHub's own shape, and refused
    #      without a single call being made.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $env:GH_GRAPHQL_BODY = New-GraphQlAnswer -Files @(@{ Name = 'branch-entry.yml'; Text = $staleYml })
    $mf = New-FixtureManifest -Extensions @('06-16') -Repo 'fixture/consumer/../../etc'
    $r = Invoke-Absent -ManifestPath $mf -Remote
    Assert-Equal 0 $r.Code 'malformed repo slug: exit code 0'
    Assert-Match 'not a valid GitHub owner/name slug' $r.Out 'malformed repo slug: named as rejected'
    Assert-Match 'rejected before it became an API call' $r.Out 'malformed repo slug: and says the call was never made'
    Assert-NotMatch 'graphql' $r.Calls 'malformed repo slug: which the call log confirms'

    # 13j. WITH -OnlyConsumer THE NETWORK IS NOT REACHED FOR SOMEBODY ELSE. That switch means a session
    #      is asking about its own repo, whose checkout is present by definition -- so an absent one
    #      reached here is another consumer, and reading it would put a third party's findings into a
    #      session that asked about neither. The same reasoning the [SKIP] itself is suppressed under.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mf = New-FixtureManifest -Extensions @('06-16')
    Remove-Item -Path $GhCalls -Force -ErrorAction SilentlyContinue
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-RemoteRunners', '-OnlyConsumer', $Fixture))
    $onlyCalls = if (Test-Path -LiteralPath $GhCalls) { (Get-Content -LiteralPath $GhCalls -Raw) } else { '' }
    Assert-Equal 0 $r.Code '-OnlyConsumer over an absent third party: exit code 0'
    Assert-NotMatch 'graphql' $onlyCalls '-OnlyConsumer: no repository read for a consumer this session did not ask about'
    Assert-NotMatch 'does not exist here' $r.Out '-OnlyConsumer: and no finding about one either'
    # (Victor's finding 2.) NOT ONE gh PROCESS, not merely no graphql call. The capability probe used to
    # run before -OnlyConsumer was consulted, so a session-start run with both switches spawned
    # `gh auth status` for an answer nothing downstream could reach. The assertion is on the WHOLE log
    # for that reason: checking only for 'graphql' is what let the spawn through.
    Assert-Equal '' $onlyCalls '-OnlyConsumer: and the capability probe is not spawned either -- the answer is unreachable there'

    # 13k. A SHORT READ IS A FACT ABOUT THIS RUN, NOT ABOUT THE REPOSITORY (Victor's finding 1). Passing
    #      -TimeoutSeconds routes the call through the Start-Process arm, which can answer exit 0 with a
    #      capture still being written -- and truncated JSON does not parse. Folded into the generic
    #      parse-failure line it would print 13d's sentence, sending the reader after the register or
    #      their credential for something a re-run settles. The fake serves half a document at exit 0;
    #      ShortRead itself cannot be provoked from here, so what this pins is the SEPARATION -- the two
    #      causes must not share one sentence.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $env:GH_GRAPHQL_BODY = '{"data":{"repository":{"defaultBranchRef":{"nam'
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Absent -ManifestPath $mf -Remote
    Assert-Equal 0 $r.Code 'unparseable answer: exit code 0'
    Assert-Match 'nothing this could parse as JSON' $r.Out 'unparseable answer: named as a parse failure'
    Assert-NotMatch 'Could not resolve to a Repository' $r.Out 'unparseable answer: and NOT as a repository nobody can see'
    Assert-NotMatch 'still being written' $r.Out 'unparseable answer: nor as a short read -- gh exited 0 with a whole (if broken) capture'

    # --- 14. The lens-naming roll-up: the retirement condition, end to end (#2289 / #2298) ---------
    # #2289 built the roll-up and #2294 landed it; its own verdict logic arrived UNTESTED, and not by
    # oversight: it fires only on a FULL-REGISTER sweep, which is exactly what -Manifest -- this
    # suite's isolation everywhere else -- switches off. So none of the three endings, the grouping,
    # the per-connector line or the silence on a narrowed run was exercised by anything.
    # -ConnectorsRootOverride is the seam that closes it, and it exists for this and nothing else.
    Write-Host "`n-- 14. the lens-naming roll-up (#2289 / #2298) --" -ForegroundColor Cyan

    # A consumer holding lens files in a chosen spelling, and a register naming consumers.
    #
    # THE SPELLINGS ARE LITERALS HERE, DELIBERATELY, against this tree's own rule that a caller asks
    # Get-SpecialistFileShapes rather than composing a name. A fixture that asks the code under test
    # what a spelling is asserts nothing -- it would agree with a wrong table as readily as a right
    # one. The cost is stated rather than hidden: on the day the Lens row's AlsoRead empties (#2292),
    # 14b and 14e stop having a subject and fail. That is the correct signal at exactly that moment,
    # and the retirement's own checklist is where it is answered.
    function New-LensConsumer {
        param(
            [Parameter(Mandatory = $true)][string]$Path,
            [ValidateSet('written', 'retired', 'mixed', 'none')][string]$Spelling = 'written',
            [string[]]$Id = @('06-16', '06-17')
        )
        $extDir = Join-Path $Path '.claude\specialists\lenses'
        New-Item -ItemType Directory -Path $extDir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $Path '.claude\settings.json'),
            '{ "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true } }')
        if ($Spelling -eq 'none') { return }
        $i = 0
        foreach ($id in $Id) {
            $i++
            $useWritten = switch ($Spelling) {
                'written' { $true }
                'retired' { $false }
                default   { $i -eq 1 }   # 'mixed': one of each, which is the state no single file shows
            }
            $name = if ($useWritten) { "specialist-$id-lens.md" } else { "$id-extension.md" }
            [System.IO.File]::WriteAllText((Join-Path $extDir $name), "---`nid: $($id.Split('-')[1])`ngroup: $($id.Split('-')[0])`n---`nfixture")
        }
    }
    function New-LensRegister {
        <# A register directory of one manifest per connector, returned as its path. #>
        param([Parameter(Mandatory = $true)][hashtable[]]$Connector)
        $dir = Join-Path $LensFixtureRoot "register-$([guid]::NewGuid().ToString('n'))"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $n = 0
        foreach ($c in $Connector) {
            $n++
            $obj = [ordered]@{
                repo          = $c.Repo
                visibility    = 'private'
                localCheckout = $c.Checkout
                plugins       = @([ordered]@{ id = 'dkj-subagents-alpha@dkj-claude-plugins'; extensions = @() })
            }
            [System.IO.File]::WriteAllText((Join-Path $dir "c$n.json"), ($obj | ConvertTo-Json -Depth 8))
        }
        return $dir
    }
    # The fixture as the manifests must spell it: relative to the repo root, so '..\..\<leaf>' -- the
    # same shape the two BWJ manifests already carry.
    $lensRel = '..\..\' + (Split-Path $LensFixtureRoot -Leaf)
    New-LensConsumer -Path (Join-Path $LensFixtureRoot 'over-a')    -Spelling 'written'
    New-LensConsumer -Path (Join-Path $LensFixtureRoot 'over-b')    -Spelling 'written'
    New-LensConsumer -Path (Join-Path $LensFixtureRoot 'retired-a') -Spelling 'retired'
    New-LensConsumer -Path (Join-Path $LensFixtureRoot 'mixed-a')   -Spelling 'mixed'
    New-LensConsumer -Path (Join-Path $LensFixtureRoot 'empty-a')   -Spelling 'none'

    # --- 14a. Every connector over -> the window opens, and says what it is NOT -------------------
    $reg = New-LensRegister -Connector @(
        @{ Repo = 'fixture/over-a'; Checkout = "$lensRel\over-a" },
        @{ Repo = 'fixture/over-b'; Checkout = "$lensRel\over-b" })
    $r = Invoke-Ps $Script ($base + @('-ConnectorsRootOverride', $reg))
    Assert-Equal 0 $r.Code 'all over: exit code 0 -- the roll-up counts nothing'
    Assert-Match '\[LENS-RETIREMENT\] ALL 2 CONNECTORS ARE OVER' $r.Out 'all over: the verdict fires and names the register size'
    Assert-Match 'deliberate act with its own issue' $r.Out 'all over: it says plainly that this is not an instruction to perform the retirement'
    Assert-Match 'keyed on plugin CACHES' $r.Out 'all over: and carries the bound -- one of the four kinds'
    Assert-NotMatch 'NOT YET' $r.Out 'all over: and not the negative verdict as well'

    # --- 14b. One connector still on the also-read spelling -> NOT YET ----------------------------
    $reg = New-LensRegister -Connector @(
        @{ Repo = 'fixture/over-a';    Checkout = "$lensRel\over-a" },
        @{ Repo = 'fixture/retired-a'; Checkout = "$lensRel\retired-a" })
    $r = Invoke-Ps $Script ($base + @('-ConnectorsRootOverride', $reg))
    Assert-Equal 0 $r.Code 'not yet: exit code 0 -- a consumer that has not migrated is in breach of nothing'
    Assert-Match '\[LENS-RETIREMENT\] NOT YET: 1 of 2 connectors' $r.Out 'not yet: the verdict counts the ones still behind'
    Assert-Match 'the condition is FALSE' $r.Out 'not yet: and states the condition plainly'
    Assert-Match 'not over:  fixture/retired-a' $r.Out 'not yet: the grouping names which connector it is'
    Assert-NotMatch 'ALL 2 CONNECTORS ARE OVER' $r.Out 'not yet: the green verdict does not also fire'
    Assert-NotMatch 'NOT the full list' $r.Out 'not yet: with full coverage it does NOT claim the list is partial'

    # --- 14c. A checkout this machine does not hold -> NOT ANSWERABLE, never a green light --------
    $reg = New-LensRegister -Connector @(
        @{ Repo = 'fixture/over-a'; Checkout = "$lensRel\over-a" },
        @{ Repo = 'fixture/gone';   Checkout = 'nonexistent-fixture-path' })
    $r = Invoke-Ps $Script ($base + @('-ConnectorsRootOverride', $reg))
    Assert-Equal 0 $r.Code 'absent: exit code 0'
    Assert-Match '\[LENS-RETIREMENT\] NOT ANSWERABLE FROM THIS MACHINE' $r.Out 'absent: the middle ending fires'
    Assert-Match '1 of 2 connectors measured' $r.Out 'absent: it says how much of the register it managed'
    Assert-Match 'none of them is behind' $r.Out 'absent: and why this arm rather than NOT YET'
    Assert-NotMatch 'ALL 2 CONNECTORS ARE OVER' $r.Out 'absent: the green verdict is NOT reached on a partial read'

    # --- 14d. A checkout that IS here but holds no lens -> unmeasured, never "over" ---------------
    #      The false-green shape this state exists to catch: zero files on the also-read spelling is
    #      arithmetically true of a consumer that never bootstrapped, and counting it as over would
    #      hand the retirement a majority built out of silence.
    $reg = New-LensRegister -Connector @(
        @{ Repo = 'fixture/over-a'; Checkout = "$lensRel\over-a" },
        @{ Repo = 'fixture/empty';  Checkout = "$lensRel\empty-a" })
    $r = Invoke-Ps $Script ($base + @('-ConnectorsRootOverride', $reg))
    Assert-Equal 0 $r.Code 'no lenses: exit code 0'
    Assert-Match 'no lenses: fixture/empty' $r.Out 'no lenses: the grouping says which of the two absences it is'
    Assert-Match '\[LENS-RETIREMENT\] NOT ANSWERABLE FROM THIS MACHINE' $r.Out 'no lenses: and it counts as unmeasured, not as over'
    Assert-NotMatch 'ALL 2 CONNECTORS ARE OVER' $r.Out 'no lenses: so the window does NOT open on it'

    # --- 14e. A PART-migrated consumer counts as behind, not as over ------------------------------
    #      The Mixed state, which is the one no single file can show you: a tree half-renamed is not
    #      over the rename, and reading its written half as a pass is the same false green one level in.
    $reg = New-LensRegister -Connector @(
        @{ Repo = 'fixture/over-a'; Checkout = "$lensRel\over-a" },
        @{ Repo = 'fixture/mixed';  Checkout = "$lensRel\mixed-a" })
    $r = Invoke-Ps $Script ($base + @('-ConnectorsRootOverride', $reg))
    Assert-Equal 0 $r.Code 'part-migrated: exit code 0'
    Assert-Match 'part-migrated' $r.Out 'part-migrated: the per-connector line names the state'
    Assert-Match '\[LENS-RETIREMENT\] NOT YET: 1 of 2 connectors' $r.Out 'part-migrated: and it counts as behind'
    Assert-NotMatch 'ALL 2 CONNECTORS ARE OVER' $r.Out 'part-migrated: never as over'

    # --- 14f. Precedence: a measured NOT YET outranks an unreached connector (#2298) ---------------
    #      The correction this branch carries. A connector measurably behind settles the condition as
    #      FALSE whatever the unreached ones hold, so answering 'not answerable' there states less
    #      than the run established -- while the coverage claim moves into that same line, so the
    #      list is never read as complete.
    $reg = New-LensRegister -Connector @(
        @{ Repo = 'fixture/over-a';    Checkout = "$lensRel\over-a" },
        @{ Repo = 'fixture/retired-a'; Checkout = "$lensRel\retired-a" },
        @{ Repo = 'fixture/gone';      Checkout = 'nonexistent-fixture-path' })
    $r = Invoke-Ps $Script ($base + @('-ConnectorsRootOverride', $reg))
    Assert-Equal 0 $r.Code 'precedence: exit code 0'
    Assert-Match '\[LENS-RETIREMENT\] NOT YET: 1 of 3 connectors' $r.Out 'precedence: the decisive negative is the verdict'
    Assert-Match '1 of the 3 could not be measured here' $r.Out 'precedence: and it still names the unmeasured count'
    Assert-Match 'NOT the full list of what still has to migrate' $r.Out 'precedence: so the list is not read as complete'
    Assert-NotMatch 'NOT ANSWERABLE FROM THIS MACHINE' $r.Out 'precedence: the weaker verdict does not also fire'

    # --- 14g. The marker is this check''s own, and not check-roster-sync''s (#2298) ----------------
    $reg = New-LensRegister -Connector @(@{ Repo = 'fixture/over-a'; Checkout = "$lensRel\over-a" })
    $r = Invoke-Ps $Script ($base + @('-ConnectorsRootOverride', $reg))
    Assert-Match '\[LENS-RETIREMENT\]' $r.Out 'marker: the roll-up prints its own token'
    Assert-NotMatch '\[LENS-NAMING\]' $r.Out 'marker: and never the one check-roster-sync uses for an unrelated fact (#2219)'

    # --- 14h. A narrowed run keeps the per-connector line and drops the register-wide VERDICT ------
    #      -OnlyConsumer is the path connector-sessioncheck takes in a consumer repo, where a
    #      register-wide verdict would be unfounded and none of that session's business; -Manifest is
    #      the same situation asked for by hand. 'Checked 1 of 6' would be a partial sweep wearing a
    #      verdict's clothes.
    #
    #      THE TWO HALVES ARE SEPARATE AND ONLY ONE IS SUPPRESSED, which is what these assertions had
    #      to be corrected to say: the per-connector reading is about the ONE consumer in front of
    #      you and is exactly as true on a narrowed run, so it still prints. Asserting on the marker
    #      alone conflated them and failed here -- correctly. What must not appear is a sentence about
    #      the REGISTER, so the three verdict wordings are named one by one.
    New-FixtureConsumer -ExtensionIds @('06-16')
    $mf = New-FixtureManifest -Extensions @('06-16')
    $r = Invoke-Ps $Script ($base + @('-Manifest', $mf, '-ConsumerPathOverride', $Fixture))
    Assert-NotMatch 'lens naming across the register' $r.Out '-Manifest: the roll-up heading is absent'
    Assert-NotMatch 'CONNECTORS ARE OVER' $r.Out '-Manifest: and the green verdict with it'
    Assert-NotMatch 'NOT YET:' $r.Out '-Manifest: and the negative one'
    Assert-NotMatch 'NOT ANSWERABLE FROM THIS MACHINE' $r.Out '-Manifest: and the coverage one'

    $reg = New-LensRegister -Connector @(@{ Repo = 'fixture/over-a'; Checkout = "$lensRel\over-a" })
    $r = Invoke-Ps $Script ($base + @('-ConnectorsRootOverride', $reg, '-OnlyConsumer', (Join-Path $LensFixtureRoot 'over-a')))
    Assert-NotMatch 'lens naming across the register' $r.Out '-OnlyConsumer: the roll-up heading is absent'
    Assert-NotMatch 'CONNECTORS ARE OVER' $r.Out '-OnlyConsumer: and the green verdict with it'
    Assert-NotMatch 'NOT YET:' $r.Out '-OnlyConsumer: and the negative one'
    Assert-NotMatch 'NOT ANSWERABLE FROM THIS MACHINE' $r.Out '-OnlyConsumer: and the coverage one'
    Assert-Match '\[LENS-RETIREMENT\].*written spelling' $r.Out '-OnlyConsumer: the PER-CONNECTOR reading still prints -- it is about the one consumer asked about, so it is as true here as anywhere'
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    if (Test-Path -LiteralPath $HookHome) { Remove-Item -Recurse -Force -LiteralPath $HookHome -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $FakeBin) { Remove-Item -Recurse -Force -LiteralPath $FakeBin -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $NestedFixtureRoot) { Remove-Item -Recurse -Force -LiteralPath $NestedFixtureRoot -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $LensFixtureRoot) { Remove-Item -Recurse -Force -LiteralPath $LensFixtureRoot -ErrorAction SilentlyContinue }
    Remove-Item -Path $GhCalls -Force -ErrorAction SilentlyContinue
    $env:PATH = $PrevPath
    foreach ($v in @('GH_CALL_LOG', 'GH_GRAPHQL_BODY', 'GH_GRAPHQL_EXIT', 'GH_AUTH_FAIL')) {
        Remove-Item -Path "Env:\$v" -ErrorAction SilentlyContinue
    }
}

Write-Host "`nResult: $($script:pass) pass, $($script:fail) fail." -ForegroundColor $(if ($script:fail -gt 0) { 'Red' } else { 'Green' })
if ($script:fail -gt 0) { exit 1 }
exit 0
