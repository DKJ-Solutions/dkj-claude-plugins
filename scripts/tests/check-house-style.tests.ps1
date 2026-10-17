<#
.SYNOPSIS
    Tests for the house-style gate (#3035): plugins/dkj-policy/dkj-solutions/scripts/lint/check-house-style.ps1,
    its rules in scripts/lib/house-style-rules.ps1 beside it, and the session check in hooks/.

.DESCRIPTION
    Group 1 pins the rules on strings: the pin read from the skill page, the CRLF-tolerant hash, which
    token and class occurrences count, the allowlist's shape and the quoted-path decode. Group 2 holds the
    retired-name list to the vendored v0.2.0 copy, so a name the tag defines again can never be
    listed as retired. Group 3 runs the gate and the session check as child processes against scratch git
    repos -- a clean one, a drifted one, one without a copy, one answered by its allowlist -- and once
    against this repo, which runs the gate on itself.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Plugin   = Join-Path $RepoRoot 'plugins\dkj-policy\dkj-solutions'
$Gate     = Join-Path $Plugin 'scripts\lint\check-house-style.ps1'
$Hook     = Join-Path $Plugin 'hooks\house-style-sessioncheck.ps1'
$Skill    = Join-Path $Plugin 'skills\house-style\SKILL.md'
$Vendored = Join-Path $RepoRoot 'scripts\dashboard\house-style'
# $PID and a guid in the fixture path: the test gate runs suites in parallel.
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "house-style-$PID-$([guid]::NewGuid().ToString('n'))"

. (Join-Path $Plugin 'scripts\lib\house-style-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

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
# No hit binds $null to $Hits, and @($null) is one element -- so filter before reading a key.
function Get-HitNames($Hits) { (@($Hits | Where-Object { $_ }) | ForEach-Object { "$($_.Kind) $($_.Name)" }) -join ', ' }

Write-Host '-- group 1a: the pin, read from the skill page' -ForegroundColor Cyan

$pin = Get-HouseStylePin -SkillText ([System.IO.File]::ReadAllText($Skill))
Assert-True ($null -ne $pin) 'the skill page carries a complete checksum table'
Assert-Equal 'v0.2.0' $pin.Tag 'the tag is read from the fetch URL'
foreach ($leaf in 'house-style.css', 'house-theme.js') {
    $hashes = Get-HouseStyleSha256 -Bytes ([System.IO.File]::ReadAllBytes((Join-Path $Vendored $leaf)))
    Assert-True (@($hashes) -contains $pin.Hashes[$leaf]) "this repo's vendored $leaf is the pinned copy"
}
Assert-True ($null -eq (Get-HouseStylePin -SkillText '| `house-style.css` | `x` | `aa` |')) 'a page without both rows is no pin'

Write-Host '-- group 1b: a CRLF checkout of the pinned file is still the pinned file' -ForegroundColor Cyan

$lf   = [System.Text.Encoding]::ASCII.GetBytes("a{}`nb{}`n")
$crlf = [System.Text.Encoding]::ASCII.GetBytes("a{}`r`nb{}`r`n")
$lfHash = @(Get-HouseStyleSha256 -Bytes $lf)[0]
Assert-True (@(Get-HouseStyleSha256 -Bytes $crlf) -contains $lfHash) 'the CRLF bytes also hash as their LF form'
Assert-Equal 1 @(Get-HouseStyleSha256 -Bytes $lf).Count 'LF bytes yield one hash, not two'

Write-Host '-- group 1c: which token occurrences count' -ForegroundColor Cyan

$names = @('--primary', '--good', '--page')
Assert-Equal 'defines --good' (Get-HitNames (Find-HouseStyleTokenHit -Text ':root { --good: green; }' -Names $names)) 'a CSS definition'
Assert-Equal 'defines --good' (Get-HitNames (Find-HouseStyleTokenHit -Text "el.style = { '--good': 'x' }" -Names $names)) 'a quoted JS key'
Assert-Equal '' (Get-HitNames (Find-HouseStyleTokenHit -Text 'color: var(--good);' -Names $names)) 'a read is not a definition'
Assert-Equal 'reads --good' (Get-HitNames (Find-HouseStyleTokenHit -Text 'color: var( --good);' -Names $names -IncludeReads)) 'a read, with -IncludeReads'
Assert-Equal '' (Get-HitNames (Find-HouseStyleTokenHit -Text "p.add_argument('--page', type=int)" -Names $names -IncludeReads)) 'an argparse flag is not a stylesheet'
Assert-Equal '' (Get-HitNames (Find-HouseStyleTokenHit -Text 'a { --primary-7: red; color: var(--primary-7) }' -Names $names -IncludeReads)) '--primary-7 is not bare --primary'
$h = @(Find-HouseStyleTokenHit -Text "x`ny`n  --good: 1;" -Names $names)
Assert-Equal 3 $h[0].Line 'the line number of a hit'

Write-Host '-- group 1d: which class rules count' -ForegroundColor Cyan

$classes = @('card', 'btn', 'badge')
Assert-Equal 'styles .card' (Get-HitNames (Find-HouseStyleClassHit -Text '.card { color: red; }' -Classes $classes)) 'the house class itself'
Assert-Equal 'styles .card' (Get-HitNames (Find-HouseStyleClassHit -Text '.card:hover{}' -Classes $classes)) 'a state of it'
Assert-Equal 'styles .card' (Get-HitNames (Find-HouseStyleClassHit -Text 'main > .card {}' -Classes $classes)) 'under an element, it restyles every card'
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text '.card .my-row {}' -Classes $classes)) 'a domain class as the subject'
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text '.my-panel .card {}' -Classes $classes)) 'a house class placed inside a domain component'
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text '.my-thing.card {}' -Classes $classes)) 'a house class scoped by a domain class'
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text '.btn--ghost {}' -Classes $classes)) '.btn--ghost is not .btn'
Assert-Equal 'styles .btn' (Get-HitNames (Find-HouseStyleClassHit -Text '.x { a: b; } .btn, .y {}' -Classes $classes)) 'one selector of a list, after another rule'
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text '@media (min-width: 1px) {}' -Classes $classes)) 'an at-rule prelude is no selector'
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text 'if ($x.card) { }' -Classes $classes)) 'a property access in code is no selector'
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text "if (document.querySelector('.card')) { }" -Classes $classes)) 'a class in a quoted string is no selector'
Assert-Equal 'styles .card' (Get-HitNames (Find-HouseStyleClassHit -Text ".card[data-x='a b'] {}" -Classes $classes)) 'a space inside an attribute value is no combinator'
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text '.my-row:is(.a .b) {}' -Classes $classes)) 'nor one inside :is()'
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text "sb.AppendLine('.my-list li .card { }')" -Classes $classes)) 'a domain class right after a string''s quote still scopes the rule'
# Script shapes measured in three consumers (#3040): a method call or an object spread before a `{`.
$jsClasses = @('card', 'sort', 'map', 'meta')
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text "return [...g]`n  .sort(([a], [b]) => a - b)`n  .map(([k, v]) => ({`n    k, v`n  }));" -Classes $jsClasses)) 'a chained method call before an arrow returning an object is no selector'
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text "return [...H].sort((a, b) => {`n  return a - b;`n});" -Classes $jsClasses)) 'nor one before an arrow with a block body'
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text "const x = {`n  ...meta,`n  nested: {`n    a: 1`n  }`n};" -Classes $jsClasses)) 'nor an object spread'
Assert-Equal 'styles .card' (Get-HitNames (Find-HouseStyleClassHit -Text '[data-x].card {}' -Classes $jsClasses)) 'a house class after an attribute selector still counts'
Assert-Equal 'styles .card' (Get-HitNames (Find-HouseStyleClassHit -Text ':not(.a).card {}' -Classes $jsClasses)) 'and after a functional pseudo-class'
Assert-Equal 'styles .card' (Get-HitNames (Find-HouseStyleClassHit -Text "list.map(x => x);`n.card { color: red; }" -Classes $jsClasses)) 'a method call elsewhere in the file does not hide a real rule'
# Measured in dkj-music-library (#3095): a property access between a call's closing parens, then an object literal.
Assert-Equal '' (Get-HitNames (Find-HouseStyleClassHit -Text 'expect(validate({ sort: { key: "year" } }, OPTIONS).sort).toEqual({ key: "year" });' -Classes $jsClasses)) 'a property access inside unbalanced parens is no selector'
Assert-Equal 'styles .card' (Get-HitNames (Find-HouseStyleClassHit -Text ':is(:not(.a)).card {}' -Classes $jsClasses)) 'nested functional pseudo-classes still fold to a selector'


Write-Host '-- group 1e: the allowlist and the quoted path' -ForegroundColor Cyan

Assert-True (ConvertTo-HouseStyleAllowlist -Raw $null).Ok 'no answer is an empty allowlist'
$a = ConvertTo-HouseStyleAllowlist -Raw @(@{ Path = 'web/*' })
Assert-True (-not $a.Ok -and $a.Problem -match 'Reason') 'an entry without a Reason is refused'
$a = ConvertTo-HouseStyleAllowlist -Raw 'web/*'
Assert-True (-not $a.Ok -and $a.Problem -match 'hashtable') 'a string is refused'
$entries = @(@{ Path = 'web/*'; Name = '--good'; Reason = 'x' })
Assert-True (Test-HouseStyleAllowed -Path 'web/a.css' -Name '--good' -Allow $entries) 'a matching path and name are answered'
Assert-True (-not (Test-HouseStyleAllowed -Path 'web/a.css' -Name '--bad' -Allow $entries)) 'another name on that path is not'
Assert-Equal ('caf' + [char]0x00E9 + '.css') (ConvertFrom-GitQuotedPathHs -Line '"caf\303\251.css"') 'a git-quoted UTF-8 path is decoded'
Assert-Equal 'plain.css' (ConvertFrom-GitQuotedPathHs -Line 'plain.css') 'an unquoted path is left alone'

Write-Host '-- group 2: the retired names, held to the pinned copy' -ForegroundColor Cyan

$defs = Get-HouseStyleDefinitions -CssText ([System.IO.File]::ReadAllText((Join-Path $Vendored 'house-style.css')))
$live = @(Get-HouseStyleRetiredTokens | Where-Object { $defs.Tokens -contains $_ })
Assert-Equal '' ($live -join ' ') 'no retired name is defined by the pinned stylesheet'
Assert-True ($defs.Tokens -contains '--primary-7' -and $defs.Classes -contains 'card' -and $defs.Classes -contains 'btn--primary') 'the house tokens and classes are read from the copy'
Assert-True ($defs.Classes -notcontains 'media') 'an at-rule contributes no class'

Write-Host '-- group 3: the gate and the session check, against scratch repos' -ForegroundColor Cyan

function New-FixtureRepo([string]$Name) {
    $dir = Join-Path $Fixture $Name
    New-Item -ItemType Directory -Force -Path (Join-Path $dir 'web') | Out-Null
    Invoke-FixtureGitIn $dir init -q
    return $dir
}
function Add-PinnedCopy([string]$Dir) {
    Copy-Item -LiteralPath (Join-Path $Vendored 'house-style.css') -Destination (Join-Path $Dir 'web\house-style.css')
    Copy-Item -LiteralPath (Join-Path $Vendored 'house-theme.js') -Destination (Join-Path $Dir 'web\house-theme.js')
}
function Invoke-Child([string]$Script, [string]$Dir, [string]$ParamName) {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script "-$ParamName" $Dir 2>&1 | Out-String
    return @{ Code = $LASTEXITCODE; Out = $out }
}

try {
    $clean = New-FixtureRepo 'clean'
    Add-PinnedCopy $clean
    Set-Content -LiteralPath (Join-Path $clean 'web\app.css') -Value ':root { --my-accent: var(--primary-7); } .my-card { color: var(--primary-9); }' -Encoding ascii
    Invoke-FixtureGitIn $clean add -A
    $r = Invoke-Child $Gate $clean 'RepoRoot'
    Assert-Equal 0 $r.Code 'a clean repo passes the gate'
    $r = Invoke-Child $Hook $clean 'RepoRootOverride'
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'holds at v0\.2\.0') 'the session check says the house style holds'

    $drift = New-FixtureRepo 'drift'
    Add-PinnedCopy $drift
    Add-Content -LiteralPath (Join-Path $drift 'web\house-theme.js') -Value '// edited'
    $py = "PAGE = '''<style>:root { --primary-7: red; } .card { padding: 0; } p { color: var(--muted); }</style>'''"
    Set-Content -LiteralPath (Join-Path $drift 'web\page.py') -Value $py -Encoding ascii
    Invoke-FixtureGitIn $drift add -A
    $r = Invoke-Child $Gate $drift 'RepoRoot'
    Assert-Equal 1 $r.Code 'a drifted repo fails the gate'
    Assert-True ($r.Out -match '\[pin\] web/house-theme\.js') 'check 1: an edited copy is named'
    Assert-True ($r.Out -match '\[redefine\] web/page\.py:1 defines the house token --primary-7') 'check 2: a redefined token, in CSS embedded in Python'
    Assert-True ($r.Out -match '\[redefine\] web/page\.py:1 styles the house class \.card') 'check 2: a restyled house class'
    Assert-True ($r.Out -match '\[retired\] web/page\.py:1 reads --muted') 'check 3: a retired name in use'
    $r = Invoke-Child $Hook $drift 'RepoRootOverride'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[WARN\] 4 finding') 'the session check reports the findings and still exits 0'

    New-Item -ItemType Directory -Force -Path (Join-Path $drift 'scripts') | Out-Null
    $config = "function Get-HouseStyleAllowlist { @(@{ Path = 'web/page.py'; Reason = 'a fixture' }, @{ Path = 'web/house-theme.js'; Reason = 'no use: a pin is never answered here' }) }"
    Set-Content -LiteralPath (Join-Path $drift 'scripts\repo-config.ps1') -Value $config -Encoding ascii
    $r = Invoke-Child $Gate $drift 'RepoRoot'
    Assert-True ($r.Code -eq 1 -and $r.Out -match '3 answered by Get-HouseStyleAllowlist' -and $r.Out -match '\[pin\]') 'the allowlist answers checks 2 and 3, never a drifted copy'
    Set-Content -LiteralPath (Join-Path $drift 'scripts\repo-config.ps1') -Value "function Get-HouseStyleAllowlist { @(@{ Path = 'web/*' }) }" -Encoding ascii
    $r = Invoke-Child $Gate $drift 'RepoRoot'
    Assert-Equal 2 $r.Code 'an allowlist entry without a Reason stops the gate'    Set-Content -LiteralPath (Join-Path $drift 'scripts\repo-config.ps1') -Value "throw 'broken config'" -Encoding ascii
    $r = Invoke-Child $Gate $drift 'RepoRoot'
    Assert-Equal 2 $r.Code 'a repo-config.ps1 that throws stops the gate with 2, not the 1 of a finding'

    $none = New-FixtureRepo 'none'
    Set-Content -LiteralPath (Join-Path $none 'web\app.js') -Value 'console.log(1)' -Encoding ascii
    Invoke-FixtureGitIn $none add -A
    $r = Invoke-Child $Gate $none 'RepoRoot'
    Assert-True ($r.Code -eq 1 -and $r.Out -match '\[missing\]') 'a repo without a vendored copy fails the gate'
    $r = Invoke-Child $Hook $none 'RepoRootOverride'
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'nothing to check') 'and the session check stays quiet about it'
} finally {
    Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue
}

$r = Invoke-Child $Gate $RepoRoot 'RepoRoot'
Assert-Equal 0 $r.Code 'this repo passes its own house-style gate'

Write-Host ''
# A broken fixture fails the run even when every assert passed (issue #1635).
$fixtureBroken = Write-FixtureGitSummary -Subject 'check-house-style'
Write-Host "check-house-style: $script:pass passed, $script:fail failed."
if ($script:fail -or $fixtureBroken) { exit 1 }
exit 0
