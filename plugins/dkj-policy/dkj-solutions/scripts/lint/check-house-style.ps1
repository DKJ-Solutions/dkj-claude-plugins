<#
.SYNOPSIS
    The house-style gate (#3035): every vendored house-style.css / house-theme.js is the copy the
    house-style skill pins, and the repo's own layer redefines no house token or class and uses no
    retired token name.

.DESCRIPTION
    The rules and the reasoning behind each are in scripts/lib/house-style-rules.ps1 beside this
    script; the pinned checksums are read from skills/house-style/SKILL.md, the one place they are
    written. This script resolves the repo, reads its allowlist, runs the checks and prints them.

    It runs in two places: as a CI gate, through the reusable workflow
    .github/workflows/reusable-house-style.yml in the source repo, and by hand. The informational
    session check (hooks/house-style-sessioncheck.ps1) calls the same lib.

    EXIT CODES: 0 clean, 1 a finding, 2 the check could not run (no git checkout, no readable pin,
    an allowlist the repo stated wrongly).

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/check-house-style.tests.ps1 in the
    source repo.

.PARAMETER RepoRoot
    The checkout to check. Defaults to CLAUDE_PROJECT_DIR, then the working directory.
#>
[CmdletBinding()]
param([string]$RepoRoot)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../lib/house-style-rules.ps1')

$root = if ($RepoRoot) { $RepoRoot } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$root = [System.IO.Path]::GetFullPath($root).TrimEnd('\', '/')

Write-Host "== check-house-style -- $root =="

$skillPath = Join-Path $PSScriptRoot '../../skills/house-style/SKILL.md'
if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
    Write-Host "[ERROR] the house-style skill page is not beside this script ($skillPath) -- reinstall or update the dkj-solutions plugin." -ForegroundColor Red
    exit 2
}
$pin = Get-HouseStylePin -SkillText ([System.IO.File]::ReadAllText($skillPath, [System.Text.Encoding]::UTF8))
if (-not $pin) {
    Write-Host '[ERROR] the house-style skill page carries no complete checksum table -- nothing to check the copies against.' -ForegroundColor Red
    exit 2
}

# A repo-config.ps1 that throws is a config the repo stated wrongly: exit 2, never the 1 of a finding.
try { $allow = Read-HouseStyleAllowlist -RepoRoot $root }
catch { $allow = @{ Ok = $false; Problem = "it throws when loaded: $($_.Exception.Message)" } }
if (-not $allow.Ok) {
    Write-Host "[ERROR] scripts/repo-config.ps1: $($allow.Problem)" -ForegroundColor Red
    exit 2
}

try { $result = Invoke-HouseStyleCheck -RepoRoot $root -Pin $pin -Allow $allow.Entries }
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

foreach ($c in $result.Copies) {
    if ($c.Ok) { Write-Host "  [pinned]   $($c.Path) -- the $($result.Tag) copy" -ForegroundColor DarkGray }
}
foreach ($n in $result.Notes) { Write-Host "  [note]     $n" -ForegroundColor Yellow }
foreach ($f in $result.Findings) {
    $where = if ($f.Line) { "$($f.Path):$($f.Line)" } else { $f.Path }
    Write-Host ("  [{0}] {1} {2}" -f $f.Check, $where, $f.Text) -ForegroundColor Red
}

$allowedNote = if ($result.Allowed) { ", $($result.Allowed) answered by Get-HouseStyleAllowlist" } else { '' }
if ($result.Findings.Count) {
    Write-Host "[FAIL] $($result.Findings.Count) finding(s) against the house style at $($result.Tag)$allowedNote." -ForegroundColor Red
    Write-Host '       A false positive is answered in scripts/repo-config.ps1, Get-HouseStyleAllowlist: @{ Path = ''<glob>''; Name = ''<token or .class>''; Reason = ''<why>'' }.'
    exit 1
}
Write-Host "[OK] the house style holds at $($result.Tag)$allowedNote." -ForegroundColor Green
exit 0
