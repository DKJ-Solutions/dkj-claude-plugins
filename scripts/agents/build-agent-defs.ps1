<#
.SYNOPSIS
    Builds the agent defs: fills every shared-block region (<!-- BEGIN/END shared:NAME -->) with
    the canonical source from plugins/dkj-subagents/subagent-shared/<name>.md.
.DESCRIPTION
    Verbatim-shared bullets under **Boundaries** (e.g. the inbound rule, 19/19) are maintained in
    ONE place (subagent-shared/) and filled in here across all agent defs. If you change a shared
    block, run this script: every agent def carrying that block gets updated. The content stays
    literally in the agent def (always-loaded, self-contained); this script keeps it in sync.

    Runs over all <plugin>/agents/*-agent.md AND all <plugin>/personas/*-persona.md in every plugin.
    The personas are in scope because the specialists whose craft is itself a way of working (DevOps,
    release management) ship as personas, so a shared block about process would otherwise never reach
    them. Writes BOM-less, LF, only when something changes.

    -Check: writes nothing; reports drift (a block that deviates from its source) or a structural
    problem (BEGIN without END, unknown block) and ends with exit code 1. This is the mode
    check-plugin-integrity.ps1 and CI use as a gate.

    Pure ASCII (repo convention for .ps1).
.EXAMPLE
    ./scripts/agents/build-agent-defs.ps1
.EXAMPLE
    ./scripts/agents/build-agent-defs.ps1 -Check
#>
[CmdletBinding()]
param([switch]$Check)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot '..\lib\subagent-shared-lib.ps1')
$SharedDir = Get-AgentSharedDir -RepoRoot $RepoRoot
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path -LiteralPath $SharedDir -PathType Container)) {
    Write-Host "Source folder subagent-shared/ is missing ($SharedDir) -- stopping." -ForegroundColor Red
    exit 1
}

Write-Host "== build-agent-defs$(if ($Check) {' -Check'}) -- $RepoRoot ==" -ForegroundColor Cyan

# THE PERSONAS ARE IN SCOPE TOO, and that is not a widening for its own sake. The two specialists whose
# craft IS a way of working -- the DevOps engineer (branches, PRs, merges) and the release manager
# (changelog, versions, releases) -- ship as PERSONAS, not as agent defs, because they run in the main
# loop. A shared block about adapting to the repo you are installed in would therefore have missed
# exactly the two readers it is most for. Foreseen rather than invented: the orchestrator's own routing
# already names "extending the generator/lint, e.g. to personas" as the case where this machinery grows.
#
# Personas carry no agent def, so nothing else in this repo couples the two file kinds -- the sentinel
# region is self-describing, and Expand-AgentDefShared only ever looked at content.
# The outer @() is load-bearing: Sort-Object returns a SCALAR for a single-element collection, and a
# scalar has no .Count under StrictMode. This repo has 30 of these so it would never show up here -- it
# showed up in the lint's fixtures, which are one agent def and no persona.
$sharedFiles = @(@(
    Get-ChildItem -Path $RepoRoot -Recurse -Filter '*-agent.md' -File |
        Where-Object { $_.FullName -match '\\agents\\' }
    Get-ChildItem -Path $RepoRoot -Recurse -Filter '*-persona.md' -File |
        Where-Object { $_.FullName -match '\\personas\\' }
) | Sort-Object FullName)

$changed = 0
$problemCount = 0
foreach ($f in $sharedFiles) {
    $raw = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $rel = $f.FullName.Replace($RepoRoot, '.')
    $problems = New-Object System.Collections.Generic.List[string]
    $expanded = Expand-AgentDefShared -Content $raw -SharedDir $SharedDir -Problems $problems
    foreach ($p in $problems) {
        Write-Host "  [problem]    ${rel}: $p" -ForegroundColor Red
        $problemCount++
    }
    $current = ($raw -replace "`r`n", "`n")
    if ($expanded -ne $current) {
        $changed++
        if ($Check) {
            Write-Host "  [drift]      $rel -- shared block deviates from the source (run build-agent-defs.ps1)" -ForegroundColor Red
        } else {
            [System.IO.File]::WriteAllText($f.FullName, $expanded, $Utf8NoBom)
            Write-Host "  [updated]    $rel" -ForegroundColor Green
        }
    }
}

Write-Host ""
if ($Check) {
    if ($changed -gt 0 -or $problemCount -gt 0) {
        Write-Host "Summary: $changed drift, $problemCount problem -- NOT in sync." -ForegroundColor Red
        exit 1
    }
    Write-Host "Summary: all shared blocks in sync with the source." -ForegroundColor Green
    exit 0
}
if ($problemCount -gt 0) {
    Write-Host "Summary: $changed updated, $problemCount problem (fix that first)." -ForegroundColor Yellow
    exit 1
}
Write-Host "Summary: $changed file(s) updated, the rest already in sync." -ForegroundColor Cyan
exit 0
