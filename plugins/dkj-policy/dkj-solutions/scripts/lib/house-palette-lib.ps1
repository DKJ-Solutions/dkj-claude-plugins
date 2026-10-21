<#
.SYNOPSIS
    The colour model of the house style (#3235): eleven tokens per theme, computed from the theme's hue and
    mode, so a theme is never tuned by hand again.

.DESCRIPTION
    Per theme, in the owner's words (issue #3235, October 21, 2026), on a light theme:
      --primary        ONE colour: the most saturated colour of the theme's HSL hue (saturation 100%) that
                       reads at 4.5:1 on all four paper steps, so white (and every paper step) reads on it too.
      --paper-1..4     FOUR colours that read on the primary, from white towards a little darker: the page, the
                       card, the line, the stronger border -- and the text on a primary fill.
      --muted          a grey of the colour that reads extra well (7:1) on the page.
      --muted-inverse  a grey of the colour that reads extra well (7:1) on the far end (an inverted surface).
      --fg-1..4        FOUR text colours that read on the page, near black, in very small steps: fg-4 is still
                       very dark, only a little less so than fg-1.
    A dark theme is the mirror: the paper runs from black towards a little lighter and the text is near white. Its
    primary is much lighter than a mirror would give (owner, October 21, 2026): it reaches 9:1 on all four paper
    steps, not 4.55:1, so it is a light tint of the colour rather than the colour at full strength, and the dark paper
    on it, the text on a primary fill, reads at 9:1 too. At 4.55:1 a fill was a vivid band under near-black text.
    And no dark primary is more saturated than OKLCH chroma 0.13 (Roze's, the most saturated of the light tints):
    Cyaan and Geel reach 9:1 at full strength already, so the floor alone left them neon (owner, the same day); above
    the cap the primary is taken again at that chroma, at the lightness where it reaches 9:1.

    Every threshold is 4.55:1 or 7.05:1 rather than 4.5 and 7, which leaves room for the rounding to #rrggbb.
    Pure ASCII (repo convention for .ps1).
#>

# ---- the twelve themes: id, mode and the HSL hue of the owner's original theme colour ------------------------
function Get-HousePaletteThemes {
    @(
        @{ Id = 'magenta'; Mode = 'light'; Hue = 317 }
        @{ Id = 'purple';  Mode = 'light'; Hue = 270 }
        @{ Id = 'blue';    Mode = 'light'; Hue = 240 }
        @{ Id = 'teal';    Mode = 'light'; Hue = 185 }
        @{ Id = 'ochre';   Mode = 'light'; Hue = 53  }
        @{ Id = 'rust';    Mode = 'light'; Hue = 29  }
        @{ Id = 'pink';    Mode = 'dark';  Hue = 327 }
        @{ Id = 'lilac';   Mode = 'dark';  Hue = 270 }
        @{ Id = 'sky';     Mode = 'dark';  Hue = 240 }
        @{ Id = 'cyan';    Mode = 'dark';  Hue = 185 }
        @{ Id = 'yellow';  Mode = 'dark';  Hue = 47  }
        @{ Id = 'orange';  Mode = 'dark';  Hue = 23  }
    )
}

# The steps, per mode: OKLCH lightness and chroma of the four paper and the four text colours. Paper-1 and fg-1
# keep the anchors of October 20, 2026 (the edge of white and black); the steps after them are small by design.
function Get-HousePaletteSteps {
    param([ValidateSet('light', 'dark')][string]$Mode)
    if ($Mode -eq 'light') {
        @{ PaperL = @(0.995, 0.975, 0.945, 0.905); PaperC = @(0.006, 0.014, 0.028, 0.045)
           FgL    = @(0.12, 0.16, 0.20, 0.24);     FgC    = @(0.030, 0.030, 0.028, 0.026); MutedC = 0.03; PrimaryFloor = 4.55 }
    } else {
        @{ PaperL = @(0.13, 0.155, 0.19, 0.235);   PaperC = @(0.020, 0.024, 0.032, 0.045)
           FgL    = @(0.99, 0.955, 0.92, 0.885);   FgC    = @(0.006, 0.010, 0.012, 0.014); MutedC = 0.03; PrimaryFloor = 9.0; PrimaryChromaMax = 0.13 }
    }
}

# ---- colour math ----------------------------------------------------------------------------------------------
function ConvertTo-LinearChannel([double]$c) { if ($c -le 0.04045) { $c / 12.92 } else { [math]::Pow(($c + 0.055) / 1.055, 2.4) } }
function ConvertFrom-LinearChannel([double]$c) { if ($c -le 0.0031308) { 12.92 * $c } else { 1.055 * [math]::Pow($c, 1 / 2.4) - 0.055 } }

function ConvertFrom-HexColor {
    param([string]$Hex)
    $h = $Hex.TrimStart('#')
    # each channel in parentheses: in PowerShell the comma binds tighter than the division
    @(([Convert]::ToInt32($h.Substring(0, 2), 16) / 255.0), ([Convert]::ToInt32($h.Substring(2, 2), 16) / 255.0), ([Convert]::ToInt32($h.Substring(4, 2), 16) / 255.0))
}

function ConvertTo-HexColor {
    param([double[]]$Rgb)
    '#' + (($Rgb | ForEach-Object { '{0:x2}' -f [int][math]::Round(([math]::Min(1.0, [math]::Max(0.0, [double]$_)) * 255.0)) }) -join '')
}

function Get-RelativeLuminance {
    param([string]$Hex)
    $l = ConvertFrom-HexColor $Hex | ForEach-Object { ConvertTo-LinearChannel $_ }
    0.2126 * $l[0] + 0.7152 * $l[1] + 0.0722 * $l[2]
}

function Get-ContrastRatio {
    param([string]$A, [string]$B)
    $la = Get-RelativeLuminance $A; $lb = Get-RelativeLuminance $B
    ([math]::Max($la, $lb) + 0.05) / ([math]::Min($la, $lb) + 0.05)
}

function ConvertFrom-Hsl {
    param([double]$H, [double]$S, [double]$L)
    $c = (1 - [math]::Abs(2 * $L - 1)) * $S
    $hp = ($H % 360) / 60
    $x = $c * (1 - [math]::Abs(($hp % 2) - 1))
    $rgb = switch ([math]::Floor($hp)) { 0 { $c, $x, 0 } 1 { $x, $c, 0 } 2 { 0, $c, $x } 3 { 0, $x, $c } 4 { $x, 0, $c } default { $c, 0, $x } }
    $m = $L - $c / 2
    ConvertTo-HexColor @(($rgb[0] + $m), ($rgb[1] + $m), ($rgb[2] + $m))
}

# OKLab (Bjorn Ottosson, 2020) from and to linear sRGB. The cone responses are $cl/$cm/$cs and the Lab axes
# $okL/$okA/$okB: PowerShell variable names ignore case, so the usual l/L, a/A, b/B pairs would be one variable.
function ConvertTo-OkLch {
    param([string]$Hex)
    $r, $g, $bl = ConvertFrom-HexColor $Hex | ForEach-Object { ConvertTo-LinearChannel $_ }
    $cl = [math]::Pow(0.4122214708 * $r + 0.5363325363 * $g + 0.0514459929 * $bl, 1 / 3)
    $cm = [math]::Pow(0.2119034982 * $r + 0.6806995451 * $g + 0.1073969566 * $bl, 1 / 3)
    $cs = [math]::Pow(0.0883024619 * $r + 0.2817188376 * $g + 0.6299787005 * $bl, 1 / 3)
    $okL = 0.2104542553 * $cl + 0.7936177850 * $cm - 0.0040720468 * $cs
    $okA = 1.9779984951 * $cl - 2.4285922050 * $cm + 0.4505937099 * $cs
    $okB = 0.0259040371 * $cl + 0.7827717662 * $cm - 0.8086757660 * $cs
    $hue = [math]::Atan2($okB, $okA) * 180 / [math]::PI; if ($hue -lt 0) { $hue += 360 }
    @{ L = $okL; C = [math]::Sqrt($okA * $okA + $okB * $okB); H = $hue }
}

function ConvertFrom-OkLchRaw {
    param([double]$L, [double]$C, [double]$H)
    $okA = $C * [math]::Cos($H * [math]::PI / 180); $okB = $C * [math]::Sin($H * [math]::PI / 180)
    $cl = [math]::Pow($L + 0.3963377774 * $okA + 0.2158037573 * $okB, 3)
    $cm = [math]::Pow($L - 0.1055613458 * $okA - 0.0638541728 * $okB, 3)
    $cs = [math]::Pow($L - 0.0894841775 * $okA - 1.2914855480 * $okB, 3)
    @((4.0767416621 * $cl - 3.3077115913 * $cm + 0.2309699292 * $cs),
      (-1.2684380046 * $cl + 2.6097574011 * $cm - 0.3413193965 * $cs),
      (-0.0041960863 * $cl - 0.7034186147 * $cm + 1.7076147010 * $cs))
}

# An OKLCH colour as #rrggbb; out of gamut, the chroma is reduced (lightness and hue held) until it fits.
function ConvertFrom-OkLch {
    param([double]$L, [double]$C, [double]$H)
    $lo = 0.0; $hi = $C
    $lin = ConvertFrom-OkLchRaw $L $hi $H
    if (($lin | Where-Object { $_ -lt -0.0001 -or $_ -gt 1.0001 }).Count -gt 0) {
        for ($i = 0; $i -lt 30; $i++) {
            $mid = ($lo + $hi) / 2
            $t = ConvertFrom-OkLchRaw $L $mid $H
            if (($t | Where-Object { $_ -lt -0.0001 -or $_ -gt 1.0001 }).Count -gt 0) { $hi = $mid } else { $lo = $mid }
        }
        $lin = ConvertFrom-OkLchRaw $L $lo $H
    }
    ConvertTo-HexColor ($lin | ForEach-Object { ConvertFrom-LinearChannel ([math]::Min(1.0, [math]::Max(0.0, [double]$_))) })
}

# The lightness (in [Lo, Hi]) closest to $Toward at which a colour built by $Make still reaches $Ratio against
# $Against -- the colour that recedes furthest while still reading. Contrast falls monotonically towards $Against.
function Find-LightnessAtContrast {
    param([scriptblock]$Make, [string]$Against, [double]$Ratio, [double]$Lo, [double]$Hi, [ValidateSet('high', 'low')][string]$Toward)
    for ($i = 0; $i -lt 40; $i++) {
        $mid = ($Lo + $Hi) / 2
        $ok = (Get-ContrastRatio (& $Make $mid) $Against) -ge $Ratio
        if ($Toward -eq 'high') { if ($ok) { $Lo = $mid } else { $Hi = $mid } }
        else                    { if ($ok) { $Hi = $mid } else { $Lo = $mid } }
    }
    & $Make $(if ($Toward -eq 'high') { $Lo } else { $Hi })
}

# ---- the palette ----------------------------------------------------------------------------------------------
function Get-HousePalette {
    <# The eleven tokens of one theme, as an ordered map of token name to #rrggbb. #>
    param([Parameter(Mandatory)][double]$Hue, [Parameter(Mandatory)][ValidateSet('light', 'dark')][string]$Mode)
    $steps = Get-HousePaletteSteps -Mode $Mode
    $okHue = (ConvertTo-OkLch (ConvertFrom-Hsl $Hue 1 0.5)).H
    $paper = 0..3 | ForEach-Object { ConvertFrom-OkLch $steps.PaperL[$_] $steps.PaperC[$_] $okHue }
    $fg    = 0..3 | ForEach-Object { ConvertFrom-OkLch $steps.FgL[$_] $steps.FgC[$_] $okHue }

    # the primary: HSL saturation 100%, the lightness closest to 50% that still reaches the mode's floor on the
    # furthest paper step (4.55:1 on light, 9:1 on dark)
    $makePrimary = { param($l) ConvertFrom-Hsl $Hue 1 $l }.GetNewClosure()
    if ($Mode -eq 'light') { $primary = Find-LightnessAtContrast $makePrimary $paper[3] $steps.PrimaryFloor 0 0.5 'high' }
    else                   { $primary = Find-LightnessAtContrast $makePrimary $paper[3] $steps.PrimaryFloor 0.5 1 'low' }
    if ($steps.PrimaryChromaMax -and (ConvertTo-OkLch $primary).C -gt $steps.PrimaryChromaMax) {
        $cap = $steps.PrimaryChromaMax; $capHue = (ConvertTo-OkLch $primary).H
        $makeCapped = { param($l) ConvertFrom-OkLch $l $cap $capHue }.GetNewClosure()
        $primary = Find-LightnessAtContrast $makeCapped $paper[3] $steps.PrimaryFloor 0 1 'low'
    }

    # the greys: as close to their ground as 7:1 allows, so they recede by colour while still reading extra well
    $mc = $steps.MutedC
    $makeMuted = { param($l) ConvertFrom-OkLch $l $mc $okHue }.GetNewClosure()
    if ($Mode -eq 'light') {
        $muted   = Find-LightnessAtContrast $makeMuted $paper[0] 7.05 0 1 'high'
        $inverse = Find-LightnessAtContrast $makeMuted $fg[0] 7.05 0 1 'low'
    } else {
        $muted   = Find-LightnessAtContrast $makeMuted $paper[0] 7.05 0 1 'low'
        $inverse = Find-LightnessAtContrast $makeMuted $fg[0] 7.05 0 1 'high'
    }

    $p = [ordered]@{}
    for ($i = 0; $i -lt 4; $i++) { $p["--paper-$($i + 1)"] = $paper[$i] }
    $p['--primary'] = $primary
    $p['--muted'] = $muted
    $p['--muted-inverse'] = $inverse
    for ($i = 0; $i -lt 4; $i++) { $p["--fg-$($i + 1)"] = $fg[$i] }
    $p
}

function Format-HousePaletteDeclarations {
    <# The eleven tokens as one line of CSS declarations, in the stylesheet's order. #>
    param([Parameter(Mandatory)]$Palette)
    ($Palette.Keys | ForEach-Object { "$($_): $($Palette[$_]);" }) -join ' '
}

function Get-HousePaletteContrast {
    <# The pairings the model promises, each with its ratio and the floor it must reach. #>
    param([Parameter(Mandatory)]$Palette)
    $rows = @()
    foreach ($n in 1..4) { $rows += @{ Pair = "primary on paper-$n"; Ratio = Get-ContrastRatio $Palette['--primary'] $Palette["--paper-$n"]; Floor = 4.5 } }
    foreach ($n in 1..4) { foreach ($k in 1..4) { $rows += @{ Pair = "fg-$n on paper-$k"; Ratio = Get-ContrastRatio $Palette["--fg-$n"] $Palette["--paper-$k"]; Floor = 7 } } }
    $rows += @{ Pair = 'muted on paper-1'; Ratio = Get-ContrastRatio $Palette['--muted'] $Palette['--paper-1']; Floor = 7 }
    $rows += @{ Pair = 'muted on paper-2'; Ratio = Get-ContrastRatio $Palette['--muted'] $Palette['--paper-2']; Floor = 4.5 }
    $rows += @{ Pair = 'muted on paper-4'; Ratio = Get-ContrastRatio $Palette['--muted'] $Palette['--paper-4']; Floor = 4.5 }
    $rows += @{ Pair = 'muted-inverse on fg-1'; Ratio = Get-ContrastRatio $Palette['--muted-inverse'] $Palette['--fg-1']; Floor = 7 }
    $rows += @{ Pair = 'paper-1 on muted'; Ratio = Get-ContrastRatio $Palette['--paper-1'] $Palette['--muted']; Floor = 4.5 }
    $rows
}
