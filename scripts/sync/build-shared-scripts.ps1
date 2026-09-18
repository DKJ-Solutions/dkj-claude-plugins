<#
.SYNOPSIS
    Mirrors the shared workflow scripts from their canonical root copy to the plugin mirror.

.DESCRIPTION
    The root copy is the tested source; the plugin mirror is what a consumer runs via a skill
    (issue #81). This script keeps the mirror in sync with the source -- exactly the pattern of
    scripts/agents/build-agent-defs.ps1, but for whole scripts instead of shared blocks.

    The registry lives in scripts/lib/shared-scripts-lib.ps1 (single source). Writes BOM-less, LF,
    only when something changes.

    -Check: writes nothing; reports drift (a mirror that deviates from its source) and ends with
    exit code 1. This is the mode check-plugin-integrity.ps1 and CI use as a gate.

    Pure ASCII (repo convention for .ps1).
.EXAMPLE
    ./scripts/sync/build-shared-scripts.ps1
.EXAMPLE
    ./scripts/sync/build-shared-scripts.ps1 -Check
#>
[CmdletBinding()]
param([switch]$Check)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot '..\lib\shared-scripts-lib.ps1')
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host "== build-shared-scripts$(if ($Check) {' -Check'}) -- $RepoRoot ==" -ForegroundColor Cyan

$pairs = @(Get-SharedScriptPairs -RepoRoot $RepoRoot)
$changed = 0
$problemCount = 0
foreach ($pair in $pairs) {
    $src = Get-NormalizedScriptContent -Path $pair.SourcePath
    if ($null -eq $src) {
        Write-Host "  [problem]    source missing: $($pair.SourceRel)" -ForegroundColor Red
        $problemCount++
        continue
    }
    $mirror = Get-NormalizedScriptContent -Path $pair.MirrorPath
    if ($src -ne $mirror) {
        $changed++
        if ($Check) {
            Write-Host "  [drift]      $($pair.MirrorRel) -- deviates from $($pair.SourceRel) (run build-shared-scripts.ps1)" -ForegroundColor Red
        } else {
            $dir = Split-Path -Path $pair.MirrorPath -Parent
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            [System.IO.File]::WriteAllText($pair.MirrorPath, $src, $Utf8NoBom)
            Write-Host "  [updated]    $($pair.MirrorRel)" -ForegroundColor Green
        }
    }
}

Write-Host ""
if ($Check) {
    if ($changed -gt 0 -or $problemCount -gt 0) {
        Write-Host "Summary: $changed drift, $problemCount problem -- NOT in sync." -ForegroundColor Red
        exit 1
    }
    Write-Host "Summary: all shared scripts in sync with their source." -ForegroundColor Green
    exit 0
}
if ($problemCount -gt 0) {
    Write-Host "Summary: $changed updated, $problemCount problem (fix that first)." -ForegroundColor Yellow
    exit 1
}
Write-Host "Summary: $changed mirror(s) updated, the rest already in sync." -ForegroundColor Cyan
exit 0
