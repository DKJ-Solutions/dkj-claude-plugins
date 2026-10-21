<#
.SYNOPSIS
    Compute the twelve colour tokens of every house-style theme (#3235) and, with -Apply, write them into
    house-style.css.

.DESCRIPTION
    The model is in scripts/lib/house-palette-lib.ps1 beside this script. Without -Apply this prints each
    theme's declarations and the contrast of every pairing the model promises, and writes nothing. With
    -Apply it rewrites, in the stylesheet, each theme's line (keeping any token that is not a palette token,
    such as a theme's own --warning-3), the light default block (-LightDefault) and the two dark default
    blocks (-DarkDefault).

    Exit 1 when a pairing misses its floor, and then -Apply writes nothing.
    Pure ASCII (repo convention for .ps1).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File build-house-palette.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File build-house-palette.ps1 -Apply
#>
param(
    [switch]$Apply,
    [string]$StylePath = (Join-Path $PSScriptRoot '..\..\assets\house-style\house-style.css'),
    [string]$LightDefault = 'blue',
    [string]$DarkDefault = 'cyan'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\house-palette-lib.ps1')

$palettes = [ordered]@{}
$failed = 0
foreach ($t in Get-HousePaletteThemes) {
    $p = Get-HousePalette -Hue $t.Hue -Mode $t.Mode
    $palettes[$t.Id] = $p
    Write-Host ("{0} ({1}, hue {2})" -f $t.Id, $t.Mode, $t.Hue)
    Write-Host ("  " + (Format-HousePaletteDeclarations $p))
    foreach ($row in Get-HousePaletteContrast $p -Mode $t.Mode) {
        if ($row.Ratio -lt $row.Floor) {
            $failed++
            Write-Host ("  [FAIL] {0}: {1:N2}:1, floor {2}:1" -f $row.Pair, $row.Ratio, $row.Floor) -ForegroundColor Red
        }
    }
}
if ($failed -gt 0) { Write-Host "[ERROR] $failed pairing(s) miss their floor -- nothing written." -ForegroundColor Red; exit 1 }
Write-Host "[OK] every pairing reaches its floor in all $($palettes.Count) themes."
if (-not $Apply) { exit 0 }

foreach ($id in @($LightDefault, $DarkDefault)) { if (-not $palettes.Contains($id)) { throw "unknown default theme '$id'" } }
$isPaletteToken = '^--(paper-\d|ink-\d|primary|primary-fill|muted|muted-inverse|fg-\d):'
$lines = [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $StylePath).Path)
$standalone = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match '^(:root\[data-theme="([a-z]+)"\], \.theme-swatch\[data-id="\2"\] \{ )(.*?)( \})$' -and $palettes.Contains($Matches[2])) {
        $head = $Matches[1]; $tail = $Matches[4]; $id = $Matches[2]
        $keep = @($Matches[3] -split ';\s*' | Where-Object { $_ -and $_ -notmatch $isPaletteToken } | ForEach-Object { "$($_.Trim());" })
        $lines[$i] = $head + ((@(Format-HousePaletteDeclarations $palettes[$id]) + $keep) -join ' ') + $tail
    } elseif ($line -match '^(\s+)--paper-1(?=:)') {   # (?=:), so the house-style gate does not read the pattern as a definition
        # the default blocks: the first is the light one, the two after it the dark one (OS-followed and forced)
        $id = if ($standalone -eq 0) { $LightDefault } else { $DarkDefault }
        $lines[$i] = $Matches[1] + (Format-HousePaletteDeclarations $palettes[$id])
        $standalone++
    }
}
if ($standalone -ne 3) { throw "expected 3 default token lines in $StylePath, found $standalone -- nothing written" }
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $StylePath).Path, (($lines -join "`n") + "`n"))
Write-Host "[OK] wrote the palettes of $($palettes.Count) themes and the defaults ($LightDefault, $DarkDefault) into $StylePath"
