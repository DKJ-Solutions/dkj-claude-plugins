<#
.SYNOPSIS
    Regression tests for scripts/task/adopt-statusline.ps1 -- issue #2103, Part 5 of
    'adopt-dkj-policy'.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/adopt-statusline.tests.ps1

    EVERY CASE RUNS AGAINST ITS OWN FIXTURE REPO, passed with -RootOverride. This command writes into
    .claude/, which is the one directory a suite must never be allowed to reach for real: the repo
    running the suite has a statusLine of its own, and a case that found it would be asserting against
    the machine rather than against the script.

    WHAT IS ACTUALLY WORTH ASSERTING HERE IS THE REFUSAL, not the happy path. The happy path writes two
    files and is hard to get wrong; the value is in the three ways this command must decline to damage
    something -- an existing statusLine (singular per settings file, so placing ours REPLACES it), a
    settings file that does not parse, and the source repo of the workflow itself. Each of those is a
    silent, total loss if it goes the other way, and none of them is visible in a dry run's output
    unless it is checked.

    AND IN THE SHIM'S CONTRACT, which is the half that outlives every release. It resolves the payload
    at render time precisely so that no path in settings.json can go stale, so the cases below walk it
    against a fixture install administration: this repo's record preferred, a pathless record as the
    fallback, somebody else's project record never, and every failure path silent and exit 0.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary and two sharing one fixed temp path tear down each other's tree.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\task\adopt-statusline.ps1'

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function New-FixtureRepo {
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("adoptstatus-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:trees += $dir
    return (Resolve-Path -LiteralPath $dir).Path
}

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-Adopt {
    param([string]$Root, [switch]$Apply)
    $adoptArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script, '-RootOverride', $Root)
    if ($Apply) { $adoptArgs += '-Apply' }
    $out = @(& powershell @adoptArgs 2>&1 | ForEach-Object { "$_" })
    return [pscustomobject]@{ Output = ($out -join "`n"); ExitCode = $LASTEXITCODE }
}

Write-Host ''
Write-Host '== adopt-statusline: the dry run ==' -ForegroundColor Cyan

# --- 1. the default writes nothing ---------------------------------------------------------------
# The first run of a command that edits your settings shows you the edit. Asserted on the FILES rather
# than on the word 'DRY RUN' in the output, because the claim is about the disk.
$root = New-FixtureRepo 'dryrun'
$res = Invoke-Adopt -Root $root
Assert-True ($res.ExitCode -eq 0) 'dry run: exits 0'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $root '.claude\statusline\dkj-progress.ps1'))) `
    'dry run: no shim is written'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $root '.claude\settings.json'))) `
    'dry run: no settings file is written'
Assert-True ($res.Output -match 'would write') 'dry run: it says what it would place'
Assert-True ($res.Output -match 'statusLine') 'dry run: and prints the block itself, so it can be placed by hand'

# --- 2. -Apply places both halves ----------------------------------------------------------------
$root = New-FixtureRepo 'apply'
$res = Invoke-Adopt -Root $root -Apply
$shimPath = Join-Path $root '.claude\statusline\dkj-progress.ps1'
$settingsPath = Join-Path $root '.claude\settings.json'
Assert-True ($res.ExitCode -eq 0) 'apply: exits 0'
Assert-True (Test-Path -LiteralPath $shimPath -PathType Leaf) 'apply: the shim is placed'
Assert-True (Test-Path -LiteralPath $settingsPath -PathType Leaf) 'apply: settings.json is created'

$settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-True ("$($settings.statusLine.type)" -eq 'command') 'apply: the statusLine is a command'
Assert-True ("$($settings.statusLine.refreshInterval)" -eq '2000') 'apply: it carries a refreshInterval'

# FORWARD SLASHES, AND THIS IS NOT A STYLE ASSERT. The statusline documentation names the trap: Git
# Bash treats unquoted backslashes as escape characters, so a Windows-style path reaches the script
# runner with its separators removed and the command fails with nothing visible to say so.
Assert-True ("$($settings.statusLine.command)" -notmatch '\\\\') `
    'apply: the command carries no backslash, which Git Bash would eat silently'
Assert-True ("$($settings.statusLine.command)" -match '\.claude/statusline/dkj-progress\.ps1') `
    'apply: the command names the SHIM, never a versioned plugin-cache path'

# THE CENTRAL CLAIM OF THE WHOLE DESIGN, asserted as its own case because it is the one that would be
# lost first. A path into the plugin cache keeps working after an update and renders the payload
# installed the day it was written -- silently, forever.
Assert-True ("$($settings.statusLine.command)" -notmatch 'plugins[\\/]cache') `
    'apply: and it names no cache path at all, so a plugin update cannot strand it'

# --- 3. an existing statusLine is never replaced --------------------------------------------------
# statusLine is singular per settings file. This is the case the issue left open ("refuse-and-print vs.
# compose") and the one where going the other way costs somebody their own status line without asking.
$root = New-FixtureRepo 'existing'
Write-Utf8 (Join-Path $root '.claude\settings.json') '{"statusLine":{"type":"command","command":"mine.ps1"},"env":{"KEEP":"1"}}'
$res = Invoke-Adopt -Root $root -Apply
$settings = Get-Content -LiteralPath (Join-Path $root '.claude\settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-True ($res.ExitCode -eq 0) 'existing statusLine: this is a normal outcome, not a failure'
Assert-True ("$($settings.statusLine.command)" -eq 'mine.ps1') `
    'existing statusLine: theirs is left exactly as it was'
Assert-True ($res.Output -match 'REPLACE') 'existing statusLine: and the run says why it declined'
Assert-True ($res.Output -match 'dkj-progress\.ps1') 'existing statusLine: the block is printed for a by-hand placement'

# THE SHIM IS STILL PLACED, and that is deliberate rather than incidental: declining the settings edit
# must not also withhold the file that edit would have pointed at, or wiring it up later means running
# this command again and reading past the same refusal.
Assert-True (Test-Path -LiteralPath (Join-Path $root '.claude\statusline\dkj-progress.ps1') -PathType Leaf) `
    'existing statusLine: the shim is placed anyway, so wiring up later is a settings edit and nothing else'

# --- 4. an unreadable settings file is refused, not rewritten -------------------------------------
# A command that repaired this by overwriting would destroy whatever the reader was in the middle of.
$root = New-FixtureRepo 'broken'
Write-Utf8 (Join-Path $root '.claude\settings.json') '{ this is not json'
$res = Invoke-Adopt -Root $root -Apply
Assert-True ($res.ExitCode -eq 1) 'unparseable settings: refuses with a non-zero exit'
Assert-True ((Get-Content -LiteralPath (Join-Path $root '.claude\settings.json') -Raw) -match 'this is not json') `
    'unparseable settings: the file is left byte-for-byte as it was'
Assert-True ($res.Output -match 'does not parse') 'unparseable settings: and it says so rather than dying on a cast'

# --- 5. the rest of a settings file survives ------------------------------------------------------
# The key is ADDED. A rewrite that dropped a neighbouring key would be the same class of loss as
# replacing the statusLine, arriving through the back door.
$root = New-FixtureRepo 'merge'
Write-Utf8 (Join-Path $root '.claude\settings.json') '{"permissions":{"allow":["Bash(git status:*)"]},"enabledPlugins":{"x@y":true}}'
$null = Invoke-Adopt -Root $root -Apply
$settings = Get-Content -LiteralPath (Join-Path $root '.claude\settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-True (@($settings.permissions.allow) -contains 'Bash(git status:*)') 'merge: an existing permission survives'
Assert-True ("$($settings.enabledPlugins.'x@y')" -eq 'True') 'merge: an existing enabledPlugins entry survives'
Assert-True ($null -ne $settings.statusLine) 'merge: and the statusLine was added beside them'

# --- 6. re-running finds nothing to do ------------------------------------------------------------
# Additive, like every file this family places. It is what makes running this again after a plugin
# update harmless -- and correct, since the shim is the half that never needs updating.
$shimBefore = Get-Content -LiteralPath (Join-Path $root '.claude\statusline\dkj-progress.ps1') -Raw
$res = Invoke-Adopt -Root $root -Apply
$shimAfter = Get-Content -LiteralPath (Join-Path $root '.claude\statusline\dkj-progress.ps1') -Raw
Assert-True ($shimBefore -ceq $shimAfter) 're-run: the shim is not rewritten'
Assert-True ($res.Output -match '\[keep\]') 're-run: and the run says it kept what was there'

Write-Host ''
Write-Host '== the shim contract ==' -ForegroundColor Cyan

# The shim resolves the payload at RENDER time, which is the whole reason it exists. Walked against a
# fixture install administration: nothing here touches the real one.
$root = New-FixtureRepo 'shim'
$null = Invoke-Adopt -Root $root -Apply
$shimPath = Join-Path $root '.claude\statusline\dkj-progress.ps1'

function New-FixtureHome {
    param([string]$Label, [string]$AdminJson)
    $home_ = New-FixtureRepo "home-$Label"
    Write-Utf8 (Join-Path $home_ '.claude\plugins\installed_plugins.json') $AdminJson
    return $home_
}

function New-FixturePayload {
    param([string]$Label, [string]$Marker)
    $payloadRoot = New-FixtureRepo "payload-$Label"
    Write-Utf8 (Join-Path $payloadRoot 'scripts\task\show-progress.ps1') @"
param([string]`$Root = '', [string]`$Payload = '', [int]`$MaxBars = 2)
Write-Output '$Marker'
exit 0
"@
    return $payloadRoot
}

function Invoke-Shim {
    param([string]$UserHome)
    # The shim reads its home from the environment, exactly as it does in a real session -- so the
    # fixture redirects that rather than passing a parameter the shipped file does not have.
    $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -Command "
        `$env:USERPROFILE = '$UserHome'
        `$env:HOME = '$UserHome'
        & '$shimPath'
    " 2>&1 | ForEach-Object { "$_" })
    return [pscustomobject]@{ Output = ($out -join "`n"); ExitCode = $LASTEXITCODE }
}

$payload = New-FixturePayload -Label 'ok' -Marker 'PAYLOAD-REACHED'
$escapedRoot = $root -replace '\\', '\\'
$escapedPayload = $payload -replace '\\', '\\'

# --- 7. this repo's own record is the one used ----------------------------------------------------
$fixtureHome = New-FixtureHome -Label 'match' -AdminJson @"
{"version":2,"plugins":{"dkj-policy@dkj-claude-plugins":[
  {"scope":"project","projectPath":"$escapedRoot","installPath":"$escapedPayload","version":"9.9.9"}
]}}
"@
$res = Invoke-Shim -UserHome $fixtureHome
Assert-True ($res.ExitCode -eq 0) 'shim: exits 0'
Assert-True ($res.Output -match 'PAYLOAD-REACHED') 'shim: it resolves this repo''s record and hands over to the payload'

# --- 8. somebody else's project record is never used ----------------------------------------------
# The failure this prevents is a statusline rendering from a payload installed for a different repo --
# which on a machine running several consumers is the ordinary state, not an exotic one.
$otherRoot = (New-FixtureRepo 'other') -replace '\\', '\\'
$fixtureHome = New-FixtureHome -Label 'foreign' -AdminJson @"
{"version":2,"plugins":{"dkj-policy@dkj-claude-plugins":[
  {"scope":"project","projectPath":"$otherRoot","installPath":"$escapedPayload","version":"9.9.9"}
]}}
"@
$res = Invoke-Shim -UserHome $fixtureHome
Assert-True ($res.ExitCode -eq 0) 'shim: a foreign record still exits 0'
Assert-True ($res.Output -notmatch 'PAYLOAD-REACHED') `
    'shim: and it is NOT used -- a record naming another repo is not this repo''s payload'

# --- 9. a pathless (user-scope) record is the fallback ---------------------------------------------
$fixtureHome = New-FixtureHome -Label 'userscope' -AdminJson @"
{"version":2,"plugins":{"dkj-policy@dkj-claude-plugins":[
  {"scope":"user","installPath":"$escapedPayload","version":"9.9.9"}
]}}
"@
$res = Invoke-Shim -UserHome $fixtureHome
Assert-True ($res.Output -match 'PAYLOAD-REACHED') `
    'shim: a user-scope install carries no projectPath and still serves this repo'

# --- 10. every missing thing is silence, never an error -------------------------------------------
# A status line runs every couple of seconds for as long as a session is open. A failure here is not an
# error report; it is a broken status line, repeated forever.
$fixtureHome = New-FixtureHome -Label 'nopayload' -AdminJson @"
{"version":2,"plugins":{"dkj-policy@dkj-claude-plugins":[
  {"scope":"project","projectPath":"$escapedRoot","installPath":"C:\\nope\\gone","version":"9.9.9"}
]}}
"@
$res = Invoke-Shim -UserHome $fixtureHome
Assert-True ($res.ExitCode -eq 0) 'shim: a payload that is gone exits 0'
Assert-True (-not ($res.Output -match 'PAYLOAD-REACHED')) 'shim: and prints nothing'

$fixtureHome = New-FixtureHome -Label 'broken' -AdminJson '{ not json at all'
$res = Invoke-Shim -UserHome $fixtureHome
Assert-True ($res.ExitCode -eq 0) 'shim: an administration it cannot parse exits 0'

$fixtureHome = New-FixtureRepo 'noadmin'
$res = Invoke-Shim -UserHome $fixtureHome
Assert-True ($res.ExitCode -eq 0) 'shim: no administration at all exits 0'

# --- 11. the shim names no version ----------------------------------------------------------------
# The property the whole design turns on, asserted against the file rather than against the argument
# for it: nothing in here pins a release, so nothing in here can go stale at one.
$shimText = Get-Content -LiteralPath $shimPath -Raw
Assert-True ($shimText -notmatch 'plugins[\\/]cache') 'shim: it hard-codes no cache path'
Assert-True ($shimText -match 'installed_plugins\.json') 'shim: it resolves the payload through the install administration'
Assert-True ($shimText -match 'DO NOT EDIT') 'shim: it says it is generated, so a reader knows what put it there'

# --- teardown ------------------------------------------------------------------------------------
foreach ($tree in $script:trees) {
    try { Remove-Item -LiteralPath $tree -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:fail) of $($script:pass + $script:fail) asserts failed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
