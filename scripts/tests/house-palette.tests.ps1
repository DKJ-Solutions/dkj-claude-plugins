<#
.SYNOPSIS
    Tests for the house-style colour model (#3235): plugins/dkj-policy/dkj-solutions/scripts/lib/house-palette-lib.ps1
    and the build script beside it, scripts/build/build-house-palette.ps1.

.DESCRIPTION
    Group 1 pins the colour math on known values: the WCAG contrast of black on white, OKLCH of pure blue, HSL, and a
    round trip. Group 2 holds every theme to the model's promises: the primary reads on all four paper steps, the
    text on every paper step, the greys at 7:1 on their ground, the four text steps in very small steps. Group 3 holds
    the stylesheet to the model: every theme line and the three default blocks carry exactly the computed values, so
    a hand edit to a colour is caught here rather than in a review. Group 4 runs the build script without -Apply.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Plugin   = Join-Path $RepoRoot 'plugins\dkj-policy\dkj-solutions'
$Build    = Join-Path $Plugin 'scripts\build\build-house-palette.ps1'
$Style    = Join-Path $Plugin 'assets\house-style\house-style.css'

. (Join-Path $Plugin 'scripts\lib\house-palette-lib.ps1')

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
function Assert-Near {
    param([double]$Expected, [double]$Actual, [double]$Tolerance, [string]$Name)
    Assert-True ([math]::Abs($Expected - $Actual) -le $Tolerance) ($Name + " (expected $Expected +/- $Tolerance, got $Actual)")
}

Write-Host '-- group 1: the colour math' -ForegroundColor Cyan

Assert-Near 21 (Get-ContrastRatio '#000000' '#ffffff') 0.001 'black on white is 21:1'
Assert-Near 1 (Get-ContrastRatio '#777777' '#777777') 0.001 'a colour on itself is 1:1'
$blue = ConvertTo-OkLch '#0000ff'
Assert-Near 0.452 $blue.L 0.001 'OKLCH lightness of pure blue'
Assert-Near 0.313 $blue.C 0.001 'OKLCH chroma of pure blue'
Assert-Near 264.05 $blue.H 0.05 'OKLCH hue of pure blue'
Assert-Equal '#0000ff' (ConvertFrom-Hsl 240 1 0.5) 'HSL 240/100/50 is pure blue'
Assert-Equal '#8040ff' (ConvertTo-HexColor @(0.5, 0.25, 1)) 'a fractional channel rounds, not truncates'
$t = ConvertTo-OkLch '#7f00ff'
Assert-Equal '#7f00ff' (ConvertFrom-OkLch $t.L $t.C $t.H) 'OKLCH round trip of an in-gamut colour'
Assert-True ((ConvertFrom-OkLch 0.9 0.4 264) -match '^#[0-9a-f]{6}$') 'an out-of-gamut colour is clipped to a valid hex'

Write-Host '-- group 2: every theme keeps the promises of the model' -ForegroundColor Cyan

$themes = @(Get-HousePaletteThemes)
Assert-Equal 12 $themes.Count 'twelve themes'
Assert-Equal 6 @($themes | Where-Object Mode -eq 'light').Count 'six light themes'
foreach ($th in $themes) {
    $p = Get-HousePalette -Hue $th.Hue -Mode $th.Mode
    Assert-Equal 11 $p.Count "$($th.Id): eleven tokens"
    $miss = @(Get-HousePaletteContrast $p | Where-Object { $_.Ratio -lt $_.Floor } | ForEach-Object { '{0} {1:N2}' -f $_.Pair, $_.Ratio })
    Assert-Equal '' ($miss -join '; ') "$($th.Id): every pairing reaches its floor"
    $l1 = (ConvertTo-OkLch $p['--fg-1']).L; $l4 = (ConvertTo-OkLch $p['--fg-4']).L
    Assert-True ([math]::Abs($l4 - $l1) -le 0.13) "$($th.Id): the four text steps lie close together (fg-1 to fg-4 within 0.13 L)"
    $dark = $th.Mode -eq 'dark'
    Assert-True ($dark -eq ((Get-RelativeLuminance $p['--fg-1']) -gt (Get-RelativeLuminance $p['--paper-1']))) "$($th.Id): the text is light on dark and dark on light"
    $lum = 1..4 | ForEach-Object { Get-RelativeLuminance $p["--paper-$_"] }
    $ordered = if ($dark) { $lum[0] -lt $lum[1] -and $lum[1] -lt $lum[2] -and $lum[2] -lt $lum[3] } else { $lum[0] -gt $lum[1] -and $lum[1] -gt $lum[2] -and $lum[2] -gt $lum[3] }
    Assert-True $ordered "$($th.Id): the paper steps run away from the page"
}

Write-Host '-- group 3: the stylesheet carries exactly the computed values' -ForegroundColor Cyan

$css = [System.IO.File]::ReadAllText($Style)
foreach ($th in $themes) {
    $expected = Format-HousePaletteDeclarations (Get-HousePalette -Hue $th.Hue -Mode $th.Mode)
    $line = ([regex]::Match($css, ":root\[data-theme=""$($th.Id)""\], \.theme-swatch\[data-id=""$($th.Id)""\] \{ ([^}]*)\}")).Groups[1].Value
    Assert-True ($line.StartsWith($expected)) "$($th.Id): its theme line starts with the computed eleven"
}
$blocks = @([regex]::Matches($css, '(?m)^\s+(--paper-1:[^\r\n]*)$') | ForEach-Object { $_.Groups[1].Value.Trim() })
Assert-Equal 3 $blocks.Count 'three default token lines'
Assert-Equal (Format-HousePaletteDeclarations (Get-HousePalette -Hue 240 -Mode light)) $blocks[0] 'the light default is Blauw'
Assert-Equal (Format-HousePaletteDeclarations (Get-HousePalette -Hue 185 -Mode dark)) $blocks[1] 'the OS-followed dark default is Cyaan'
Assert-Equal $blocks[1] $blocks[2] 'the two dark default blocks agree'
Assert-True ($css -notmatch '--ink-[1-7]\b') 'no --ink-* is left in the stylesheet'

Write-Host '-- group 4: the build script' -ForegroundColor Cyan

$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Build 2>&1 | Out-String
Assert-Equal 0 $LASTEXITCODE 'a dry run exits 0'
Assert-True ($out -match '\[OK\] every pairing reaches its floor in all 12 themes') 'a dry run reports every floor reached'
Assert-True ($out -notmatch '\[OK\] wrote') 'a dry run writes nothing'

Write-Host ''
Write-Host "house-palette: $script:pass passed, $script:fail failed."
if ($script:fail) { exit 1 }
exit 0
