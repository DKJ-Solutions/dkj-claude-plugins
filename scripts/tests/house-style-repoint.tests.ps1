<#
.SYNOPSIS
    Tests for the house-style repoint (#3100): scripts/lib/house-style-repoint-lib.ps1, the pure half of
    scripts/ci/repoint-house-style.ps1.

.DESCRIPTION
    Group 1 holds the tag shape and the branch name. Group 2 the safety reads the skill page prescribes.
    Group 3 the retired-name derivation. Group 4 the rewrites, run against this repo's own skill page,
    rules lib and a scaffolded branch document, so a reshaped page fails here before it fails a run.
    No network: the script's fetches are not exercised here.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$Plugin   = Join-Path $RepoRoot 'plugins/dkj-policy/dkj-solutions'
$Skill    = Join-Path $Plugin 'skills/house-style/SKILL.md'
$Rules    = Join-Path $Plugin 'scripts/lib/house-style-rules.ps1'

. $Rules
. (Join-Path $RepoRoot 'scripts/lib/house-style-repoint-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    Assert-True ("$Expected" -eq "$Actual") ($Name + $(if ("$Expected" -ne "$Actual") { " (expected '$Expected', got '$Actual')" } else { '' }))
}
function Assert-Throws {
    param([scriptblock]$Block, [string]$Name)
    $threw = $false
    try { & $Block | Out-Null } catch { $threw = $true }
    Assert-True $threw $Name
}

Write-Host '-- group 1: the tag and the branch' -ForegroundColor Cyan

Assert-True (Test-HouseStyleReleaseTag 'v0.3.0') 'vX.Y.Z is a release tag'
foreach ($bad in '', 'v0.3', '0.3.0', 'v0.3.0-rc1', 'v0.3.0;rm', 'V0.3.0', "v0.3.0`n") {
    Assert-True (-not (Test-HouseStyleReleaseTag $bad)) "'$($bad -replace "`n", '\n')' is refused"
}
Assert-Equal 'feat/house-style-v0-3-0' (Get-HouseStyleRepointBranch -Tag 'v0.3.0') 'the branch is named after the tag'

Write-Host '-- group 2: the safety reads' -ForegroundColor Cyan

$css = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts/dashboard/house-style/house-style.css'))
$js  = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts/dashboard/house-style/house-theme.js'))
Assert-Equal 0 @(Get-HouseStyleSafetyFindings -CssText $css -JsText $js).Count 'the pinned copy passes'
$cases = [ordered]@{
    'fetch'           = @('', 'fetch("/x");')
    'XMLHttpRequest'  = @('', 'new XMLHttpRequest();')
    'WebSocket'       = @('', 'new WebSocket("wss://x");')
    'sendBeacon'      = @('', 'navigator.sendBeacon("/x");')
    'dynamic import'  = @('', 'import("./x.js");')
    'eval'            = @('', 'eval("1");')
    'new Function'    = @('', 'new Function("return 1");')
    'Function()'      = @('', 'Function("return 1")();')
    'window.fetch'    = @('', 'window.fetch("/x");')
    'globalThis.eval' = @('', 'globalThis.eval("1");')
    'an aliased store' = @('', 'var l = localStorage; l.setItem("a", 1); l.setItem("b", 2);')
    'document.cookie' = @('', 'var c = document.cookie;')
    'sessionStorage'  = @('', 'sessionStorage.setItem("a", "b");')
    'a second key'    = @('', 'localStorage.setItem(key, id); localStorage.setItem("other", 1);')
    '@import'         = @('@import "x.css";', '')
    'a remote url()'  = @('a { background: url(https://x/y.png); }', '')
    'a //host url()'  = @("a { background: url('//x/y.png'); }", '')
}
foreach ($name in $cases.Keys) {
    $f = @(Get-HouseStyleSafetyFindings -CssText $cases[$name][0] -JsText $cases[$name][1])
    Assert-True ($f.Count -gt 0) "$name is a finding"
}
Assert-Equal 0 @(Get-HouseStyleSafetyFindings -CssText 'a { background: url(data:image/png;base64,AA); } /* @import x */' -JsText 'prefetch(); refetch(1); localStorage.setItem(key, id);').Count 'a data url, a commented @import and a name containing fetch are not'

Write-Host '-- group 3: the retired names' -ForegroundColor Cyan

$readme = @(
    '> | Was | Now |', '  |---|---|', '  | `--good`, `--up` | `--positive-3` |', '  | `--loss` | removed |', '',
    '| Token | Use |', '|---|---|', '| `--not-renamed` | x |'
) -join "`n"
Assert-Equal '--good,--loss,--up' ((Get-HouseStyleRenamedNames -ReadmeText $readme) -join ',') 'only the Was column of a rename table counts'
$next = Get-HouseStyleNextRetired -Current @('--a', '--b') -OldTokens @('--x', '--y', '--keep') -NewTokens @('--keep', '--b') -Renamed @('--r')
Assert-Equal '--a,--r,--x,--y' ($next -join ',') 'dropped and renamed names join, a live name leaves'
Assert-Equal '--ink,--ink-2,--inka' ((Get-HouseStyleNextRetired -Current @('--inka', '--ink-2', '--ink') -OldTokens @() -NewTokens @() -Renamed @()) -join ',') 'the order is ordinal, hyphens counted'
$current = @(Get-HouseStyleRetiredTokens)
$same = Get-HouseStyleNextRetired -Current $current -OldTokens (Get-HouseStyleDefinitions -CssText $css).Tokens -NewTokens (Get-HouseStyleDefinitions -CssText $css).Tokens -Renamed @()
Assert-Equal ($current -join ',') ($same -join ',') 'a release with the same stylesheet leaves the list as it is'

Write-Host '-- group 4: the rewrites' -ForegroundColor Cyan

$skillText = [System.IO.File]::ReadAllText($Skill)
$pin = Get-HouseStylePin -SkillText $skillText
$hashes = @{ 'house-style.css' = ('a' * 64); 'house-theme.js' = ('b' * 64) }
$commit = 'c' * 40
$out = Set-HouseStyleSkillPin -Text $skillText -From $pin.Tag -To 'v9.9.9' -Commit $commit -Hashes $hashes
$re = Get-HouseStylePin -SkillText $out
Assert-Equal 'v9.9.9' $re.Tag 'the pin reads the new tag'
Assert-Equal ('a' * 64) $re.Hashes['house-style.css'] 'the css checksum is replaced'
Assert-Equal ('b' * 64) $re.Hashes['house-theme.js'] 'the js checksum is replaced'
Assert-True $out.Contains("points at commit ``$commit``") 'the commit is replaced'
Assert-True (-not [regex]::IsMatch($out, 'dkj-brandbook/(?:(?:tree|blob)/)?' + [regex]::Escape($pin.Tag) + '/')) 'no brand-book link names the old tag'
Assert-True $out.Contains('release tag `v9.9.9`') 'the pinned-tag phrase names the new tag'
Assert-True $out.Contains('Its first, `v0.1.0`') 'a tag named as history is left alone'
Assert-Throws { Set-HouseStyleSkillPin -Text $skillText -From 'v0.0.1' -To 'v9.9.9' -Commit $commit -Hashes $hashes } 'a page without links at the old tag refuses'

$rulesText = [System.IO.File]::ReadAllText($Rules)
$newRules = Set-HouseStyleRetiredList -Text $rulesText -Tag 'v9.9.9' -Names @('--a', '--b')
Assert-True $newRules.Contains('as of the tag the skill pins (v9.9.9). #>') 'the docstring names the new tag'
$sb = [scriptblock]::Create(($newRules -replace '(?m)^Set-StrictMode.*$', ''))
. $sb
Assert-Equal '--a,--b' ((Get-HouseStyleRetiredTokens) -join ',') 'the rewritten lib returns the new list'
. $Rules
$roundTrip = Set-HouseStyleRetiredList -Text $rulesText -Tag 'v9.9.9' -Names $current
. ([scriptblock]::Create(($roundTrip -replace '(?m)^Set-StrictMode.*$', '')))
Assert-Equal ($current -join ',') ((Get-HouseStyleRetiredTokens) -join ',') 'the current list survives a rewrite, wrapped'
. $Rules
Assert-Throws { Set-HouseStyleRetiredList -Text 'function Other {}' -Tag 'v9.9.9' -Names @() } 'a lib in another shape refuses'

$scaffold = @(
    '## feat/house-style-v9-9-9', '', '> guidance', '', '### PLAN', '', '### CREATE', '',
    '- [ ] TODO: the first step of this branch', '', '### TEST', '', '### DEPLOY: feat/house-style-v9-9-9', '',
    '**Score:**', '', '#### What makes this deploy extra special', '', '**Score:**', '', '#### Pull Request', '',
    'house-style skill: repoint at dkj-brandbook v9.9.9', ''
) -join "`n"
$doc = Set-HouseStyleRepointDocument -Text $scaffold -From 'v0.2.0' -To 'v9.9.9' -Commit $commit -FilesChanged $true -JsChanged $false -Added @('--gone') -Removed @()
Assert-True (-not $doc.Contains('TODO: the first step')) 'the scaffolded step is replaced'
Assert-Equal 0 ([regex]::Matches($doc, '- \[ \]')).Count 'no step is left open while house-theme.js is unchanged'
$jsDoc = Set-HouseStyleRepointDocument -Text $scaffold -From 'v0.2.0' -To 'v9.9.9' -Commit $commit -FilesChanged $true -JsChanged $true -Added @() -Removed @()
Assert-Equal 1 ([regex]::Matches($jsDoc, '- \[ \] Read the `house-theme\.js` diff')).Count 'a changed house-theme.js leaves one step open for a person'
Assert-True ($jsDoc -match "harmless\n\n### DEPLOY:") 'that step sits in TEST, one blank line from DEPLOY'
Assert-Equal 3 ([regex]::Matches($doc, '- \[x\]')).Count 'the three repoint steps are done'
Assert-True ($doc -match "checksums\.\n\n### DEPLOY: feat/house-style-v9-9-9\n\nThe ``house-style`` skill now fetches") 'DEPLOY is written, one blank line from TEST'
Assert-Equal 2 ([regex]::Matches($doc, '(?m)^\*\*Score:\*\*$')).Count 'both scores are left for the person who ships it'
Assert-True $doc.Contains('newly retired: `--gone`') 'a newly retired name is named'
Assert-True $doc.Contains('Both files changed') 'a changed file is said'
Assert-True $doc.Contains("`n> guidance`n") 'the guidance above PLAN is untouched'
Assert-Throws { Set-HouseStyleRepointDocument -Text '## x' -From 'v0.2.0' -To 'v9.9.9' -Commit $commit -FilesChanged $false -JsChanged $false -Added @() -Removed @() } 'a document without the phases refuses'

Write-Host ''
Write-Host "house-style-repoint: $script:pass passed, $script:fail failed."
if ($script:fail) { exit 1 }
exit 0
