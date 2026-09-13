<#
.SYNOPSIS
    Adopts the source's repo-owned workflow config from the shipped blueprint: places what is safe to
    copy, and proposes -- never places -- what the consuming repo has to decide for itself (issue #456).

.DESCRIPTION
    The shared workflow scripts are repo-agnostic and dot-source two REPO-OWNED libs from this repo:
    scripts/lib/branch-info.ps1 and scripts/repo-config.ps1. check-script-contract.ps1 already reports
    which functions are missing and what the shared script FALLS BACK TO. What it cannot tell you is
    what the source repo chose and why -- so every consumer has been re-deriving those answers by hand,
    or not at all.

    This command reads the blueprint the source ships (blueprint/config-blueprint.json in this plugin),
    compares it against the functions this repo actually defines, and acts on the marker each record
    carries:

      copy   -- the value states the shared WAY OF WORKING and asserts nothing about this repo, so the
                source's own function text (comments and all) is written into the right lib.
      decide -- the value states WHAT A REPO IS. Copying it would assert something about this repo that
                may be false, so it is written to a PROPOSAL document instead, with the source's answer
                and its reasoning, for a person to act on.

    WHY 'decide' RECORDS ARE NEVER WRITTEN AS STUBS, which is the shape this could obviously have
    taken: a stub returning a placeholder is WORSE than an absent function. Absent means the shared
    script uses its documented fallback -- for Get-ReleasePluginTier that fallback is computed from the
    tree and is usually right. A stub returning 'VUL-IN' overrides a correct fallback with a value that
    is wrong in a way nothing checks. So the mechanism cannot place them, rather than choosing not to.

    NOTHING IS EVER OVERWRITTEN. A function this repo already defines is left exactly as it is, whatever
    the blueprint says -- the source's answer never wins over an answer somebody here already gave. That
    makes the command safe to re-run: a second run finds nothing to do.

    NOT A BOOTSTRAP. If a contract lib is missing altogether, this stops and points at the
    specialists-init skill instead of half-creating one: the bootstrap owns the file's existence, this
    command owns its contents.

.PARAMETER Apply
    Write the changes. Without it the command is a DRY RUN that prints exactly what it would do and
    touches nothing -- the same default the teardown skill uses, and for the same reason: the first run
    of a command that edits your config should show you the edit.

.PARAMETER ProposalPath
    Where the 'decide' proposal document is written, repo-root-relative.
    Default: config-adoption-proposal.md in the repo root.

.PARAMETER BlueprintPath
    Explicit path to the blueprint artefact. Normally resolved automatically; a test points it at a
    fixture.
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$ProposalPath = 'config-adoption-proposal.md',
    [string]$BlueprintPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

# Dual-context repo root: a consumer running the plugin mirror gets it from CLAUDE_PROJECT_DIR, the
# workshop root copy falls back to the git root. Same resolution as every other mirrored script, which
# is what lets both copies stay byte-identical.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'adopt-config.ps1'

# Which plugins a repo publishes, for the workshop-side blueprint lookup below. A $PSScriptRoot-relative
# sibling like every other lib this script's neighbours load: it travels in the same mirror, so it
# resolves from the workshop root and from a consumer's plugin cache alike. In a consumer it answers
# "none", which is the right answer there.
. (Join-Path $PSScriptRoot '..\lib\plugin-tree-lib.ps1')

# --- Locate the blueprint -------------------------------------------------------------------------
# Two layouts, because this script runs from two places. In the plugin mirror it sits at
# <plugin>/scripts/task/, so the artefact is ..\..\blueprint\. In the workshop root copy it sits at
# scripts/task/ and the artefact is inside whichever plugin folder ships it. Tried in that order: a
# consumer must find the plugin's copy, never a stray one.
function Resolve-Blueprint {
    param([string]$Explicit, [string]$RepoRoot)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit -PathType Leaf)) {
            throw "no blueprint at the path given: '$Explicit'."
        }
        return (Resolve-Path -LiteralPath $Explicit).Path
    }

    # $PSScriptRoot-relative first and $RepoRoot-relative last, deliberately: the artefact travels with
    # the SCRIPT, and a consumer whose CLAUDE_PROJECT_DIR points somewhere else entirely must still find
    # the blueprint next to the file it is running.
    $candidates = @(
        # the plugin mirror: <plugin>/scripts/task/ -> <plugin>/blueprint/. This is the one a consumer
        # hits, and it names no plugin and assumes no depth -- it is simply "beside me".
        (Join-Path $PSScriptRoot '..\..\blueprint\config-blueprint.json')
    )
    # THE WORKSHOP FALLBACKS ARE DERIVED, NOT SPELLED OUT. They used to be two literals naming the
    # plugin folder, which is a statement about the tree rather than about the blueprint -- and this
    # repo's tree has moved twice. Only a repo that PUBLISHES a plugin carrying a blueprint has a root
    # to find here, which is exactly the case these candidates exist for; a consumer yields none and
    # falls through to the mirror path above, where the file actually is for them.
    #
    # TWO ROOTS, IN THIS ORDER, AND THE ORDER IS THE POINT -- it is what the literals encoded and what a
    # first attempt at deriving them lost. The script's OWN location comes first: the workshop copy must
    # find the workshop's blueprint even when CLAUDE_PROJECT_DIR points at some other repo entirely,
    # which is precisely how the test suite runs it. $RepoRoot comes last, for a checkout laid out like
    # neither. Measured when the order was briefly reversed: every adopt-config test failed, because the
    # only root consulted was the fixture consumer's, which publishes nothing.
    $blueprintRoots = @()
    foreach ($searchRoot in @((Join-Path $PSScriptRoot '..\..'), $RepoRoot)) {
        if (-not (Test-Path -LiteralPath $searchRoot)) { continue }
        foreach ($root in @(Get-RepoPluginRoots -RepoRoot (Resolve-Path -LiteralPath $searchRoot).Path)) {
            $bp = Join-Path $root.Root 'blueprint\config-blueprint.json'
            if ((Test-Path -LiteralPath $bp -PathType Leaf) -and ($blueprintRoots -notcontains $bp)) {
                $blueprintRoots += $bp
            }
        }
    }
    $candidates += $blueprintRoots
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) { return (Resolve-Path -LiteralPath $c).Path }
    }
    throw "the config blueprint could not be found. It ships with the workflow plugin at blueprint/config-blueprint.json; if that plugin is enabled, update it (claude plugin update dkj-policy@dkj-claude-plugins --scope project)."
}

$bpPath = Resolve-Blueprint -Explicit $BlueprintPath -RepoRoot $repoRoot
$blueprint = Get-Content -LiteralPath $bpPath -Raw | ConvertFrom-Json

Write-Host '== adopt-config ==' -ForegroundColor Cyan
Write-Host "  repo:      $repoRoot"
Write-Host "  blueprint: $bpPath (from $($blueprint.sourceRepo))"
if (-not $Apply) {
    Write-Host '  DRY RUN -- nothing is written. Re-run with -Apply to make these changes.' -ForegroundColor Yellow
}

# --- What does this repo already answer? ----------------------------------------------------------
# Probed by dot-sourcing in a CHILD scope with StrictMode OFF, exactly as check-script-contract does:
# the real runtime callers never set strict mode, and the repo-owned libs are written on that
# assumption. Probing inside the block keeps the functions visible to Get-Command while nothing leaks
# into this script's own strict scope.
function Get-PresentFunctions {
    param([string]$LibPath, [string[]]$Names)

    return & {
        Set-StrictMode -Off
        $present = @{}
        try { . $args[0] } catch { return $present }
        foreach ($fn in $args[1]) {
            $present[$fn] = [bool](Test-FunctionDefined $fn)
        }
        return $present
    } $LibPath $Names
}

$libs = @($blueprint.records | ForEach-Object { $_.lib } | Sort-Object -Unique)
$state = @{}
$missingLibs = @()

foreach ($libRel in $libs) {
    $libPath = Join-Path $repoRoot $libRel
    if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) {
        $missingLibs += $libRel
        continue
    }
    $names = @($blueprint.records | Where-Object { $_.lib -eq $libRel } | ForEach-Object { $_.function })
    $state[$libRel] = Get-PresentFunctions -LibPath $libPath -Names $names
}

if ($missingLibs.Count -gt 0) {
    Write-Host ''
    Write-Host ("  [STOP] this repo has no " + ($missingLibs -join ' and no ') + '.') -ForegroundColor Yellow
    Write-Host '         Those files are the repo-owned seam itself, and creating them is the bootstrap'
    # NAMES THE COMMAND AND WHO TYPES IT (inbound #1093 / #1096 / #1104). Not a SessionStart hook like
    # the roster check, but the same trap: a model that reached this [STOP] is told to run a skill the
    # harness will refuse it. Reasoning in full at check-roster-sync.ps1's [BOOTSTRAP] marker.
    Write-Host '         job, not this one: run /dkj-subagents-alpha:specialists-init first. That command must be'
    Write-Host '         TYPED by the repo owner -- the skill is reserved for explicit user invocation'
    Write-Host '         and an agent cannot start it. It lays those files down as scaffolds, and this'
    Write-Host '         command then fills in the answers.'
    exit 1
}

# --- Plan -----------------------------------------------------------------------------------------
$toCopy     = @()
$toPropose  = @()
$alreadySet = @()
$noAnswer   = @()

foreach ($rec in $blueprint.records) {
    $present = $state[$rec.lib][$rec.function]
    if ($present) { $alreadySet += $rec; continue }

    # The source leaves it at the fallback too, so there is no answer to offer. Reported rather than
    # skipped: "nobody states this" is worth knowing, and a silently shorter report is not.
    if (-not $rec.declared) { $noAnswer += $rec; continue }

    if ($rec.adopt -eq 'copy') { $toCopy += $rec } else { $toPropose += $rec }
}

Write-Host ''
Write-Host "  already answered here: $($alreadySet.Count)"
Write-Host "  to place (copy):       $($toCopy.Count)"
Write-Host "  to propose (decide):   $($toPropose.Count)"
Write-Host "  no answer to offer:    $($noAnswer.Count) -- the source leaves these at the built-in fallback as well"

if ($toCopy.Count -eq 0 -and $toPropose.Count -eq 0) {
    Write-Host ''
    Write-Host '  Nothing to adopt: every function the blueprint carries an answer for is already defined here.' -ForegroundColor Green
    exit 0
}

foreach ($rec in $toCopy) {
    Write-Host ("    [copy]   " + $rec.function + " -> " + $rec.lib) -ForegroundColor Green
}
foreach ($rec in $toPropose) {
    Write-Host ("    [decide] " + $rec.function + " -- proposed, not placed") -ForegroundColor Yellow
}

if (-not $Apply) {
    Write-Host ''
    Write-Host "  Re-run with -Apply to place the $($toCopy.Count) copyable answer(s) and write the proposal document."
    exit 0
}

# --- Apply: place the copyable answers ------------------------------------------------------------
# Appended, never merged into the existing text: the file belongs to this repo and an inserter that
# tried to find "the right place" would be rewriting somebody else's file on a guess.
$written = 0
foreach ($libRel in $libs) {
    $recs = @($toCopy | Where-Object { $_.lib -eq $libRel })
    if ($recs.Count -eq 0) { continue }

    $libPath = Join-Path $repoRoot $libRel
    $existing = [System.IO.File]::ReadAllText($libPath)

    $sb = New-Object System.Text.StringBuilder
    if (-not $existing.EndsWith("`n")) { [void]$sb.Append("`n") }
    [void]$sb.Append("`n# --- Adopted from the $($blueprint.sourceRepo) config blueprint ---------------------------------`n")
    [void]$sb.Append("#`n")
    [void]$sb.Append("# Each function below is the source's own text, comments included, for a value that states the`n")
    [void]$sb.Append("# shared way of working rather than a fact about this repo. Edit them freely -- they are this`n")
    [void]$sb.Append("# repo's files now, and adopt-config never overwrites a function that is already here.`n")

    foreach ($rec in $recs) {
        [void]$sb.Append("`n")
        [void]$sb.Append(($rec.text -replace "`r`n", "`n"))
        [void]$sb.Append("`n")
        $written++
    }

    [System.IO.File]::WriteAllText($libPath, $existing + $sb.ToString())
    Write-Host ("  placed $($recs.Count) function(s) in $libRel") -ForegroundColor Green
}

# --- Apply: write the proposal for what only a person can answer ----------------------------------
# The sync-roster shape, and the reason is the same one that skill records: a lens (or a config file
# stating what a repo IS) is continuous prose plus judgement, and a script that wrote into it would be
# guessing at meaning. It emits a document with one proposal per deviation; a specialist places them.
if ($toPropose.Count -gt 0) {
    $md = New-Object System.Text.StringBuilder
    [void]$md.Append("# Config adoption -- what only this repo can answer`n`n")
    [void]$md.Append("Written by ``adopt-config.ps1`` from the config blueprint shipped by **$($blueprint.sourceRepo)**.`n`n")
    [void]$md.Append("The $($toCopy.Count) value(s) that state the shared way of working have been placed in the libs already.`n")
    [void]$md.Append("The $($toPropose.Count) below were **not**, and deliberately: each one states what a repo *is*, so the`n")
    [void]$md.Append("source's answer would be a claim about this repo that may be false.`n`n")
    [void]$md.Append("Leaving one unanswered is a valid outcome -- every record here is optional or has a documented`n")
    [void]$md.Append("fallback, and an absent function uses it. Answer the ones where this repo genuinely differs.`n`n")
    [void]$md.Append("Delete this file once it has been worked through; re-running ``adopt-config.ps1`` regenerates it.`n")

    foreach ($rec in $toPropose) {
        [void]$md.Append("`n---`n`n## ``$($rec.function)```n`n")
        [void]$md.Append("**Lives in:** ``$($rec.lib)```n`n")
        [void]$md.Append("**Why this is yours to decide:** $($rec.adoptWhy)`n`n")
        if ($rec.returns) {
            [void]$md.Append("**What it must return:** $($rec.returns)`n`n")
        }
        if ($rec.optional) {
            $def = if ($rec.default) { "``$($rec.default)``" } else { 'a built-in fallback' }
            [void]$md.Append("**If you leave it out:** the shared script falls back to $def.`n`n")
        } else {
            [void]$md.Append("**This one is required:** the shared scripts that call it will crash without it.`n`n")
        }
        [void]$md.Append("**What the source does, for reference only -- do not paste this in unadapted:**`n`n")
        [void]$md.Append("``````powershell`n")
        [void]$md.Append(($rec.text -replace "`r`n", "`n").TrimEnd())
        [void]$md.Append("`n```````n")
    }

    $propPath = Join-Path $repoRoot $ProposalPath
    $propDir = Split-Path -Parent $propPath
    if ($propDir -and -not (Test-Path -LiteralPath $propDir)) { New-Item -ItemType Directory -Path $propDir -Force | Out-Null }
    [System.IO.File]::WriteAllText($propPath, $md.ToString())
    Write-Host ("  wrote the proposal for $($toPropose.Count) decision(s): $ProposalPath") -ForegroundColor Green
}

Write-Host ''
Write-Host "Done: $written function(s) placed, $($toPropose.Count) left for you to decide." -ForegroundColor Green
Write-Host 'Run check-script-contract.ps1 to see the contract from the shared scripts side.'
