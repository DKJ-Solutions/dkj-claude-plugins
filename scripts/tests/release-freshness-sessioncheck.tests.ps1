<#
.SYNOPSIS
    Regression tests for the SessionStart hook plugins/dkj-policy/hooks/release-freshness-sessioncheck.ps1
    (issue #2673): a visible warning when the marketplace's origin carries a newer release than the
    plugin version this session runs.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell and git.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/release-freshness-sessioncheck.tests.ps1

    "GitHub" is a local bare repository carrying the tags a scenario needs, and the "marketplace clone"
    is a plain repository whose origin points at it -- so `git ls-remote` runs for real, with no network.
    The running version comes from a fixture plugin.json passed through -PluginJsonOverride.

    Fixture paths carry $PID (repo convention). Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot  = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Hook      = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\release-freshness-sessioncheck.ps1'
$HooksJson = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\hooks.json'

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function Invoke-Git {
    param([string[]]$GitArgs)
    $null = & git @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed ($LASTEXITCODE)" }
}

function New-Fixture {
    <#
        A bare "origin" carrying -Tags, a clone of it, and a plugin.json at -Running.
        -NoClone leaves the clone directory without .git; -BrokenOrigin points origin at a path that
        does not exist.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [string[]]$Tags = @(),
        [string]$Running = '5.10.0',
        [switch]$NoClone,
        [switch]$BrokenOrigin
    )
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("relfresh-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:trees += $dir

    $work = Join-Path $dir 'work'
    $bare = Join-Path $dir 'origin.git'
    $clone = Join-Path $dir 'clone'
    New-Item -ItemType Directory -Path $work, $clone -Force | Out-Null

    Invoke-Git @('init', '-q', $work)
    Invoke-Git @('-C', $work, '-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'commit', '-q', '--allow-empty', '-m', 'root')
    foreach ($t in $Tags) { Invoke-Git @('-C', $work, 'tag', $t) }
    Invoke-Git @('clone', '-q', '--bare', $work, $bare)

    if (-not $NoClone) {
        Invoke-Git @('init', '-q', $clone)
        $originUrl = $(if ($BrokenOrigin) { Join-Path $dir 'does-not-exist.git' } else { $bare })
        Invoke-Git @('-C', $clone, 'remote', 'add', 'origin', $originUrl)
    }

    $pj = Join-Path $dir 'plugin.json'
    [System.IO.File]::WriteAllText($pj, "{`"name`":`"dkj-policy`",`"version`":`"$Running`"}", (New-Object System.Text.UTF8Encoding($false)))

    return [pscustomobject]@{ Dir = $dir; Clone = $clone; PluginJson = $pj; Cache = (Join-Path $dir 'cache') }
}

function Invoke-Hook {
    <# Runs the hook in a child powershell. -Payload is written to its stdin (a session id). #>
    param([Parameter(Mandatory = $true)]$Fixture, [string]$Payload = '')
    $hookArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Hook,
                  '-PluginJsonOverride', $Fixture.PluginJson, '-CloneOverride', $Fixture.Clone,
                  '-CacheRootOverride', $Fixture.Cache)
    if ($Payload) {
        $out = $Payload | & powershell @hookArgs 2>&1
    } else {
        $out = '' | & powershell @hookArgs 2>&1
    }
    return [pscustomobject]@{ Out = (@($out) -join "`n").Trim(); Code = $LASTEXITCODE }
}

Write-Host '== release-freshness-sessioncheck.ps1 ==' -ForegroundColor Cyan
Assert-True (Test-Path -LiteralPath $Hook -PathType Leaf) 'the hook exists at its plugin path'

$hooks = Get-Content -LiteralPath $HooksJson -Raw | ConvertFrom-Json
$entries = @($hooks.hooks.SessionStart | ForEach-Object { $_ } | Where-Object {
    @($_.hooks | Where-Object { $_.command -match 'release-freshness-sessioncheck\.ps1' }).Count -gt 0 })
Assert-True ($entries.Count -eq 1) 'exactly one SessionStart group registers the hook'
if ($entries.Count -eq 1) {
    Assert-True ($entries[0].matcher -match 'startup') 'its matcher fires on startup'
}

# --- behind: the one case that speaks --------------------------------------------------------------
$f = New-Fixture -Label behind -Tags @('v5.9.0', 'v5.10.0', 'v5.11.0') -Running '5.10.0'
$r = Invoke-Hook -Fixture $f
Assert-True ($r.Code -eq 0) 'behind -- exit 0'
$json = $null
try { $json = $r.Out | ConvertFrom-Json } catch { $json = $null }
Assert-True ($null -ne $json) 'behind -- stdout is one JSON object (so the harness reads systemMessage)'
if ($json) {
    Assert-True ([string]$json.systemMessage -match 'v5\.10\.0' -and [string]$json.systemMessage -match 'v5\.11\.0') 'behind -- systemMessage names both versions'
    Assert-True ([string]$json.systemMessage -match 'update-plugins') 'behind -- systemMessage names the command that closes the gap'
    Assert-True ($json.hookSpecificOutput.hookEventName -eq 'SessionStart') 'behind -- hookSpecificOutput names the SessionStart event'
    Assert-True ([string]$json.hookSpecificOutput.additionalContext -match '\[BEHIND\]') 'behind -- the model is told too, under a marker'
}

# --- numeric, not string, comparison: v5.9.0 is OLDER than 5.10.0 -----------------------------------
$f = New-Fixture -Label numeric -Tags @('v5.9.0') -Running '5.10.0'
$r = Invoke-Hook -Fixture $f
Assert-True ($r.Code -eq 0 -and $r.Out -eq '') 'v5.9.0 on origin against 5.10.0 running -- silent (compared as versions, not strings)'

# --- current and ahead are silent -----------------------------------------------------------------
$f = New-Fixture -Label current -Tags @('v5.10.0', 'v5.11.0') -Running '5.11.0'
$r = Invoke-Hook -Fixture $f
Assert-True ($r.Code -eq 0 -and $r.Out -eq '') 'running the newest release -- silent'

$f = New-Fixture -Label ahead -Tags @('v5.11.0') -Running '5.12.0'
$r = Invoke-Hook -Fixture $f
Assert-True ($r.Code -eq 0 -and $r.Out -eq '') 'running ahead of origin (the source repo between cuts) -- silent'

# --- only an exact vX.Y.Z tag counts --------------------------------------------------------------
$f = New-Fixture -Label shapes -Tags @('v5.10.0', 'v9.0.0-rc1', 'v9.0', 'release-9.0.0', '9.0.0') -Running '5.10.0'
$r = Invoke-Hook -Fixture $f
Assert-True ($r.Code -eq 0 -and $r.Out -eq '') 'tags that are not exactly vX.Y.Z are ignored -- silent'

# --- every failure is silent ----------------------------------------------------------------------
$f = New-Fixture -Label noclone -Tags @('v6.0.0') -NoClone
$r = Invoke-Hook -Fixture $f
Assert-True ($r.Code -eq 0 -and $r.Out -eq '') 'no marketplace clone -- silent, exit 0'

$f = New-Fixture -Label broken -Tags @('v6.0.0') -BrokenOrigin
$r = Invoke-Hook -Fixture $f
Assert-True ($r.Code -eq 0 -and $r.Out -eq '') 'origin unreachable -- silent, exit 0'

$f = New-Fixture -Label badversion -Tags @('v6.0.0') -Running 'not-a-version'
$r = Invoke-Hook -Fixture $f
Assert-True ($r.Code -eq 0 -and $r.Out -eq '') 'an unparseable running version -- silent, exit 0'

# --- once per session: a replay needs no network --------------------------------------------------
$f = New-Fixture -Label cache -Tags @('v5.11.0') -Running '5.10.0'
$payload = '{"session_id":"11111111-2222-3333-4444-555555555555"}'
$r1 = Invoke-Hook -Fixture $f -Payload $payload
Invoke-Git @('-C', $f.Clone, 'remote', 'set-url', 'origin', (Join-Path $f.Dir 'gone.git'))
$r2 = Invoke-Hook -Fixture $f -Payload $payload
Assert-True ($r1.Out -match 'v5\.11\.0' -and $r2.Out -match 'v5\.11\.0') 'same session id -- the second firing replays the cached answer with origin gone'
$r3 = Invoke-Hook -Fixture $f -Payload '{"session_id":"99999999-2222-3333-4444-555555555555"}'
Assert-True ($r3.Out -eq '') 'a new session id measures afresh -- and an unreachable origin stays silent'

# --- conventions ----------------------------------------------------------------------------------
$raw = Get-Content -LiteralPath $Hook -Raw
Assert-True (-not ($raw -cmatch '[^\x00-\x7F]')) 'the hook is pure ASCII'

foreach ($t in $script:trees) {
    if ($t -and (Test-Path -LiteralPath $t)) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAIL: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
