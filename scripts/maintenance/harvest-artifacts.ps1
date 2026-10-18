<#
.SYNOPSIS
    Adds to scripts/dashboard/artifacts.json every claude.ai Artifact a session in this repo published on
    THIS machine that the register lacks, read from the session transcripts (#3112).

.DESCRIPTION
    The register is what the dev server's /artifacts page lists, and it is committed so both owners see one
    list. Each owner's transcripts are on their own machine, so each harvests their own and the register
    is the union. The run is a report unless -Apply is given; with -Apply it rewrites the register in the
    working copy and nothing else -- committing it is the ordinary branch and PR, like any other change.

    A session counts as this repo's when the cwd its records carry lies under this checkout, or under a
    sibling checkout named after a name this repo has had (Get-RetiredRepoNames in scripts/repo-config.ps1).
    What counts as a publish, and why the merge only adds, is in scripts/lib/artifact-harvest-lib.ps1.

    Exit 0 whether or not anything was found; exit 1 when the register cannot be read, since rewriting a
    file that did not parse would replace it with the harvest alone.

    Pure ASCII (repo convention for .ps1). The repo-local harvest-artifacts skill documents it.

.PARAMETER TranscriptRoot
    Where the session transcripts live. Defaults to ~/.claude/projects.

.PARAMETER Apply
    Write the merged register. Without it the run lists what it would add and writes nothing.
#>
param(
    [string]$TranscriptRoot = (Join-Path $HOME '.claude\projects'),
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'

# Repo-local and never mirrored into a plugin, so the root is where this file sits.
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
.(Join-Path $RepoRoot 'scripts\lib\artifact-harvest-lib.ps1')
. (Join-Path $RepoRoot 'scripts\repo-config.ps1')

$roots = @($RepoRoot)
$parent = Split-Path -Parent (Split-Path -Parent $RepoRoot)
foreach ($n in @(Get-RetiredRepoNames)) {
    $roots += @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName $n })
}

$regPath = Join-Path $RepoRoot 'scripts\dashboard\artifacts.json'
try { $register = [IO.File]::ReadAllText($regPath) | ConvertFrom-Json }
catch { Write-Host "[ERROR] scripts/dashboard/artifacts.json could not be read: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }

Write-Host '== harvest-artifacts =='
if (-not (Test-Path -LiteralPath $TranscriptRoot -PathType Container)) {
    Write-Host "  [WARN] no transcripts at $TranscriptRoot -- nothing to harvest on this machine." -ForegroundColor Yellow
    exit 0
}
$started = Get-Date
$files = @(Get-ChildItem -LiteralPath $TranscriptRoot -Recurse -Filter '*.jsonl' -File -ErrorAction SilentlyContinue)
$found = @()
foreach ($f in $files) { $found += @(Read-ArtifactPublishes -Path $f.FullName -Root $roots) }
$secs = ((Get-Date) - $started).TotalSeconds.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
Write-Host "  read $($files.Count) transcripts in ${secs}s: $($found.Count) publishes from this repo"

$merged = Merge-ArtifactRegister -Register $register -Found $found
foreach ($u in $merged.Added) {
    $a = @($merged.Artifacts | Where-Object { $_.url -eq $u })[0]
    Write-Host "  [NEW]     $($a.created)  $($a.kind)  $($a.title)  $u" -ForegroundColor Green
}
foreach ($u in $merged.Widened) {
    $a = @($merged.Artifacts | Where-Object { $_.url -eq $u })[0]
    Write-Host "  [DATES]   $($a.created)..$($a.updated)  $($a.title)  $u"
}
if (-not ($merged.Added.Count + $merged.Widened.Count)) {
    Write-Host '  [OK] the register already holds every Artifact this machine published here.' -ForegroundColor Green
    exit 0
}
if (-not $Apply) {
    Write-Host "  Dry run: nothing written. Re-run with -Apply to write $($merged.Added.Count) new and $($merged.Widened.Count) widened rows into scripts/dashboard/artifacts.json."
    exit 0
}

$today = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
$text = ConvertTo-ArtifactRegisterJson -About ([string]$register.about) -Date $today `
    -Method 'harvest-artifacts: Artifact publish calls and Claude Docs creates in the session transcripts of each machine that ran it, merged' `
    -Artifacts $merged.Artifacts
[IO.File]::WriteAllText($regPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  [OK] wrote scripts/dashboard/artifacts.json: $($merged.Added.Count) added, $($merged.Widened.Count) widened. Commit it on a branch like any other change." -ForegroundColor Green
exit 0
