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
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

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
Assert-True ($res.Output -match '"refreshInterval": 2\r?\n') `
    'dry run: the printed block carries the interval in seconds, since a person places it by hand from that text'

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
# SECONDS, NOT MILLISECONDS (#2163). This asserted '2000' until September 19, 2026 -- the suite held the
# defect in place: Claude Code reads the value in seconds, so 2000 is a 33-minute timer and the bar only
# redrew on conversation events. Held to a small number rather than to '2' alone, so a future change of
# cadence is free and a return to milliseconds is not.
Assert-True ("$($settings.statusLine.refreshInterval)" -eq '2') 'apply: it carries a refreshInterval of 2 seconds'
Assert-True ([int]"$($settings.statusLine.refreshInterval)" -le 60) `
    'apply: and the interval is seconds -- a value in the hundreds would be a millisecond figure Claude Code reads as minutes'

# The repo that prescribes this cadence runs it too, and its own settings are where the wrong unit sat.
$repoSettings = Get-Content -LiteralPath (Join-Path $RepoRoot '.claude\settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-True ("$($repoSettings.statusLine.refreshInterval)" -eq "$($settings.statusLine.refreshInterval)") `
    'the source repo''s own statusLine runs at the interval adopt-statusline places'

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
$mergedRaw = Get-Content -LiteralPath (Join-Path $root '.claude\settings.json') -Raw -Encoding UTF8
$settings = $mergedRaw | ConvertFrom-Json
Assert-True (@($settings.permissions.allow) -contains 'Bash(git status:*)') 'merge: an existing permission survives'
Assert-True ("$($settings.enabledPlugins.'x@y')" -eq 'True') 'merge: an existing enabledPlugins entry survives'
Assert-True ($null -ne $settings.statusLine) 'merge: and the statusLine was added beside them'

# A SINGLE-ELEMENT ARRAY IS STILL AN ARRAY, ASSERTED ON THE RAW TEXT. The three asserts above cannot
# see this: '@($x) -contains' is true whether $x came back as a one-element array or as a bare string,
# so a round trip that collapsed 'allow' to a scalar would pass all three. It does not collapse -- that
# trap is a top-level PIPELINE artefact and this value is a nested property -- but the claim being made
# here is about somebody else's settings file surviving a parse-and-rewrite, and an assert that cannot
# fail is not evidence for it.
Assert-True ($mergedRaw -match '"allow":\s*\[') `
    'merge: a one-element array is written back as an array, not flattened to a string'

# --- 6. re-running finds nothing to do ------------------------------------------------------------
# Additive, like every file this family places. It is what makes running this again after a plugin
# update harmless -- and correct, since the shim is the half that never needs updating.
$shimBefore = Get-Content -LiteralPath (Join-Path $root '.claude\statusline\dkj-progress.ps1') -Raw
$res = Invoke-Adopt -Root $root -Apply
$shimAfter = Get-Content -LiteralPath (Join-Path $root '.claude\statusline\dkj-progress.ps1') -Raw
Assert-True ($shimBefore -ceq $shimAfter) 're-run: the shim is not rewritten'
Assert-True ($res.Output -match '\[keep\]') 're-run: and the run says it kept what was there'

# --- 6b. additive means the BYTES, not only the keys (#2505) --------------------------------------
# Case 5 asserts that every key survives, and it passed all along while the file around those keys was
# re-serialised: Windows PowerShell 5.1's ConvertTo-Json column-pads every member and drops blank lines,
# so a consumer's one-key addition to a 163-line file came back as a 164-line diff. So these compare the
# written TEXT against the exact text an insert must produce -- the original, untouched, up to its
# closing brace, with the member in the file's own indent and line ending.
function Get-ExpectedInsert {
    param([string]$Original, [string]$Unit, [string]$Eol)
    $close = $Original.LastIndexOf('}')
    $head  = $Original.Substring(0, $close).TrimEnd()
    $member = @(
        "$Unit`"statusLine`": {"
        "$Unit$Unit`"type`": `"command`","
        "$Unit$Unit`"command`": `"powershell -NoProfile -ExecutionPolicy Bypass -File \`".claude/statusline/dkj-progress.ps1\`"`","
        "$Unit$Unit`"refreshInterval`": 2"
        "$Unit}"
    ) -join $Eol
    return ($head + ',' + $Eol + $member + $Eol + $Original.Substring($close))
}

$root = New-FixtureRepo 'bytes'
$original = "{`n  `"env`": {`n    `"KEEP`": `"1`"`n  },`n  `"permissions`": {`n    `"allow`": [`n      `"Bash(git status:*)`",`n`n      `"Bash(git log:*)`"`n    ]`n  }`n}`n"
Write-Utf8 (Join-Path $root '.claude\settings.json') $original
$res = Invoke-Adopt -Root $root -Apply
$written = [System.IO.File]::ReadAllText((Join-Path $root '.claude\settings.json'))
Assert-True ($res.ExitCode -eq 0) 'bytes: exits 0'
Assert-True ($written -ceq (Get-ExpectedInsert -Original $original -Unit '  ' -Eol "`n")) `
    'bytes: the file is the original text plus the inserted member, and nothing else changed'
Assert-True ($written -match "\*\)`",`n`n      `"Bash") 'bytes: a blank line inside an array survives'
Assert-True ($written -notmatch '"env":  \{') 'bytes: no ConvertTo-Json column padding appears'

# CRLF and a tab indent: the member follows the file, not a house style.
$root = New-FixtureRepo 'crlf-tab'
$original = "{`r`n`t`"env`": {`r`n`t`t`"KEEP`": `"1`"`r`n`t}`r`n}`r`n"
Write-Utf8 (Join-Path $root '.claude\settings.json') $original
$null = Invoke-Adopt -Root $root -Apply
$written = [System.IO.File]::ReadAllText((Join-Path $root '.claude\settings.json'))
Assert-True ($written -ceq (Get-ExpectedInsert -Original $original -Unit "`t" -Eol "`r`n")) `
    'bytes: a CRLF, tab-indented file gets the member in CRLF and tabs'

# A BOM is part of what was there.
$root = New-FixtureRepo 'bom'
$bomPath = Join-Path $root '.claude\settings.json'
New-Item -ItemType Directory -Path (Split-Path -Parent $bomPath) -Force | Out-Null
[System.IO.File]::WriteAllText($bomPath, "{`n  `"env`": {}`n}`n", (New-Object System.Text.UTF8Encoding($true)))
$null = Invoke-Adopt -Root $root -Apply
$bytes = [System.IO.File]::ReadAllBytes($bomPath)
Assert-True ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) 'bytes: a BOM that was there is still there'
Assert-True ($null -ne ((Get-Content -LiteralPath $bomPath -Raw -Encoding UTF8 | ConvertFrom-Json).statusLine)) `
    'bytes: and the file behind it still parses with the statusLine in it'

# The first member on the '{' line: the unit is read off the next indented member, not defaulted.
$root = New-FixtureRepo 'inline-first'
$original = "{ `"a`": 1,`n    `"b`": 2`n}`n"
Write-Utf8 (Join-Path $root '.claude\settings.json') $original
$null = Invoke-Adopt -Root $root -Apply
$written = [System.IO.File]::ReadAllText((Join-Path $root '.claude\settings.json'))
Assert-True ($written -ceq (Get-ExpectedInsert -Original $original -Unit '    ' -Eol "`n")) `
    'bytes: a first member on the brace line still gets the file''s own 4-space unit'

# An empty object takes the member with no comma in front of it.
$root = New-FixtureRepo 'empty-object'
Write-Utf8 (Join-Path $root '.claude\settings.json') "{}`n"
$res = Invoke-Adopt -Root $root -Apply
$emptyRaw = [System.IO.File]::ReadAllText((Join-Path $root '.claude\settings.json'))
Assert-True ($res.ExitCode -eq 0) 'empty object: exits 0'
Assert-True ($emptyRaw -notmatch '\{\s*,') 'empty object: no leading comma'
Assert-True ("$(($emptyRaw | ConvertFrom-Json).statusLine.type)" -eq 'command') 'empty object: the statusLine is placed'

# --- 6c. a shim git cannot see is said out loud (#2505) --------------------------------------------
# The consumer's shape: '.claude/*' ignored, with exceptions that do not cover statusline/. The shim is
# written, git status never lists it, and the committed settings.json names a file no other checkout gets.
function New-GitFixture {
    param([string]$Label, [string]$Gitignore)
    $dir = New-FixtureRepo $Label
    Invoke-FixtureGitIn $dir init -q
    Write-Utf8 (Join-Path $dir '.gitignore') $Gitignore
    return $dir
}

$root = New-GitFixture -Label 'ignored' -Gitignore ".claude/*`n!.claude/settings.json`n"
$res = Invoke-Adopt -Root $root
Assert-True ($res.Output -match 'WARNING\] git IGNORES') 'ignored shim: a dry run already warns'
Assert-True ($res.Output -match [regex]::Escape('.gitignore:1:.claude/*')) 'ignored shim: and names the rule that matched'
Assert-True ($res.Output -match [regex]::Escape('!.claude/statusline/')) 'ignored shim: and the exception that fixes it'
$res = Invoke-Adopt -Root $root -Apply
Assert-True ($res.ExitCode -eq 0) 'ignored shim: a warning, not a refusal'
Assert-True ($res.Output -match 'WARNING\] git IGNORES') 'ignored shim: -Apply warns too'
Assert-True ((Get-Content -LiteralPath (Join-Path $root '.gitignore') -Raw) -ceq ".claude/*`n!.claude/settings.json`n") `
    'ignored shim: the .gitignore is left exactly as it was'

$root = New-GitFixture -Label 'visible' -Gitignore ".claude/*`n!.claude/settings.json`n!.claude/statusline/`n"
$res = Invoke-Adopt -Root $root
Assert-True ($res.Output -notmatch 'IGNORES') 'visible shim: an exception that covers it prints no warning'
Assert-True ($res.Output -notmatch 'could not ask git') 'visible shim: and no unknown either -- git answered'

# Outside a work tree git answers 128, which is unknown -- said as such, never read as "not ignored".
$root = New-FixtureRepo 'no-git'
$res = Invoke-Adopt -Root $root
Assert-True ($res.Output -match 'could not ask git') 'no git repo: the check says it could not ask, rather than passing silently'
Assert-True ($res.Output -notmatch 'IGNORES') 'no git repo: and claims no ignore rule either'

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

# --- 10. two records for this repo: the NEWEST wins, not the first enumerated ---------------------
# THE CASE THIS REPO'S OWN HISTORY PRODUCES. An id is '<plugin>@<marketplace>', and the marketplace
# half was renamed on September 10, 2026 -- which leaves a stale 'dkj-policy@<old>' record sitting
# beside the current one, both naming this repo. check-report-lib's Get-InstallRecord documents that
# pair as real and hands back ALL matches so a caller can see the disagreement; the shim cannot do
# that, because its contract is to print nothing and never report. So it has to RESOLVE the tie, and
# resolving it by enumeration order is how a machine renders a stale payload permanently with nothing
# saying so -- the exact failure this whole design was chosen to avoid, one layer in.
$stale = New-FixturePayload -Label 'stale' -Marker 'STALE-PAYLOAD'
$escapedStale = $stale -replace '\\', '\\'
$fixtureHome = New-FixtureHome -Label 'twokeys' -AdminJson @"
{"version":2,"plugins":{
  "dkj-policy@claude-code-specialists":[
    {"scope":"project","projectPath":"$escapedRoot","installPath":"$escapedStale","version":"4.0.0",
     "installedAt":"2026-08-01T10:00:00.000Z","lastUpdated":"2026-08-01T10:00:00.000Z"}
  ],
  "dkj-policy@dkj-claude-plugins":[
    {"scope":"project","projectPath":"$escapedRoot","installPath":"$escapedPayload","version":"5.5.0",
     "installedAt":"2026-09-11T08:56:14.373Z","lastUpdated":"2026-09-18T08:30:50.300Z"}
  ]
}}
"@
$res = Invoke-Shim -UserHome $fixtureHome
Assert-True ($res.Output -match 'PAYLOAD-REACHED') 'shim: with two records for this repo, the most recently updated one is used'
Assert-True ($res.Output -notmatch 'STALE-PAYLOAD') 'shim: and the stale one from the retired marketplace name is not'

# THE STALE KEY FIRST IN THE FILE, which is the ordering that would have passed before the tiebreak
# existed. Without this the case above proves nothing: PSObject.Properties enumerates in insertion
# order, so a single fixture can only ever exercise one side of the bug it is written for.
$fixtureHome = New-FixtureHome -Label 'twokeys-reversed' -AdminJson @"
{"version":2,"plugins":{
  "dkj-policy@dkj-claude-plugins":[
    {"scope":"project","projectPath":"$escapedRoot","installPath":"$escapedPayload","version":"5.5.0",
     "installedAt":"2026-09-11T08:56:14.373Z","lastUpdated":"2026-09-18T08:30:50.300Z"}
  ],
  "dkj-policy@claude-code-specialists":[
    {"scope":"project","projectPath":"$escapedRoot","installPath":"$escapedStale","version":"4.0.0",
     "installedAt":"2026-08-01T10:00:00.000Z","lastUpdated":"2026-08-01T10:00:00.000Z"}
  ]
}}
"@
$res = Invoke-Shim -UserHome $fixtureHome
Assert-True ($res.Output -match 'PAYLOAD-REACHED') 'shim: and the answer does not depend on which key the file lists first'
Assert-True ($res.Output -notmatch 'STALE-PAYLOAD') 'shim: the stale payload loses from either position'

# A RECORD WITH NO STAMPS AT ALL still loses to one that has them, rather than winning by accident.
# An unparseable or absent stamp sorts oldest, which is the safe direction: it loses a tie instead of
# taking one.
$fixtureHome = New-FixtureHome -Label 'nostamp' -AdminJson @"
{"version":2,"plugins":{
  "dkj-policy@claude-code-specialists":[
    {"scope":"project","projectPath":"$escapedRoot","installPath":"$escapedStale","version":"4.0.0"}
  ],
  "dkj-policy@dkj-claude-plugins":[
    {"scope":"project","projectPath":"$escapedRoot","installPath":"$escapedPayload","version":"5.5.0",
     "installedAt":"2026-09-11T08:56:14.373Z","lastUpdated":"2026-09-18T08:30:50.300Z"}
  ]
}}
"@
$res = Invoke-Shim -UserHome $fixtureHome
Assert-True ($res.Output -match 'PAYLOAD-REACHED') 'shim: a record carrying no timestamp sorts oldest rather than winning'

# --- 11. every missing thing is silence, never an error -------------------------------------------
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

# --- 12. the shim names no version ----------------------------------------------------------------
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
# A BROKEN FIXTURE FAILS THE RUN (issue #1635): the ignore cases read a repo git init had to build.
$fixtureBroken = Write-FixtureGitSummary -Subject 'adopt-statusline.ps1'
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:fail) of $($script:pass + $script:fail) asserts failed." -ForegroundColor Red
    exit 1
}
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
