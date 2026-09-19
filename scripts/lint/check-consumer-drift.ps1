<#
.SYNOPSIS
    Drift lint for the shared Claude Specialists plugin: compares any local, possibly outdated
    agent-def copies in a consuming repo (life-hub/smartwatchbanden) with the canonical source in
    this plugin repo, and flags drift before such a copy is cleaned up.
.DESCRIPTION
    Topology: life-hub and swb point via a remote `github` marketplace source
    (`DKJ-Solutions/dkj-claude-plugins`) to this repo -- the Claude Code CLI clones and caches it
    itself (see README.md, "Consumption" section). So NO physical copy is needed once a consuming
    repo has been converted to the shared source. During the transition (Phase 3), however, a
    consuming repo can still have its own local copy of an
    agent def that has meanwhile also been shared here (e.g. life-hub .claude/agents/<group>-<id>-agent.md,
    or swb .claude-plugins/specialists/agents/<group>-<id>-agent.md). This script:

      1. Reads the ids + groups from every plugin this repo publishes (source of truth) -- the core
         team plus the add-on teams. The set comes from the marketplace, so this list does not name
         them: it named four by hand until August 9, 2026, and that hand-written list is exactly what
         Get-PluginSubdirs replaced.
      2. Looks in the given consuming repo, at the known legacy paths, for a local file with that
         same id.
      3. Reports one of three outcomes per found id:
           - MISSING   no local copy found -- already migrated, no action needed.
           - IDENTICAL the local copy is (after normalizing line endings/trailing whitespace) equal
                       to the canonical version -- a dead copy, safe to remove.
           - DRIFTED   the content differs -- review before removing; may be a not-yet-returned
                       change that first needs to go back here.

    Besides the agent-def copies, this script also compares the PERSONAS (the orchestrator +
    main-loop specialists such as Chris/Derek/Rendall). Those deliberately have no agent def; their
    portable source lives in <plugin>/personas/<g>-<id>-persona.md and is copied, when a consumer
    bootstraps, to the consumer's repo layer: .claude/plugins/claude-specialists/<plugin>/
    <g>-<id>-extension.md (since life-hub parity) or the legacy path
    .claude/extensions/<g>-<id>-extension.md. For every
    plugin persona this script compares the PORTABLE BODY (everything above the slot marker --
    'Eigen aan deze repo' or 'Specific to this repo'; the repo lens below it differs per repo and
    is not compared) with the
    body of the consumer copy. A consumer running the lens-only model (the extension opens with a
    '> Repo-lens (lens-only persona)' blockquote and deliberately carries no body copy) is reported
    as LENS-ONLY -- the body comes directly from the plugin, so there is nothing to compare. These
    persona findings are INFORMATIONAL: they do not count toward the
    exit code, since an existing consumer with a hand-written persona is by definition DRIFTED
    until it has been reconciled with the source -- that is the signal, not a gate breach.

    This script changes NOTHING in the consuming repo -- purely read-only signaling. Cleaning up or
    setting up the marketplace source itself is Phase-3 work in the consuming repo (Sylvester
    there), not something this plugin repo does cross-repo.

    Exit code: 0 = no DRIFTED agent-def findings. 1 = at least one DRIFTED agent-def finding
    (usable as a local gate in the consuming repo, alongside its own lint-brain.ps1).
    Persona drift does NOT affect the exit code.
.PARAMETER ConsumerPath
    Path to the root of the consuming repo (life-hub or smartwatchbanden). Required.
.PARAMETER Quiet
    Show only ids with a finding (DRIFTED/IDENTICAL); suppress MISSING lines.
.EXAMPLE
    ./scripts/lint/check-consumer-drift.ps1 -ConsumerPath C:\path\to\life-hub
.EXAMPLE
    ./scripts/lint/check-consumer-drift.ps1 -ConsumerPath C:\path\to\smartwatchbanden -Quiet
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ConsumerPath,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PluginRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')

# EVERY PUBLISHED PLUGIN'S agents/ AND personas/, ASKED OF THE MARKETPLACE (August 9, 2026). Both sets
# used to be hand-written lists of directories here, and the pair is why this changed rather than the
# tidiness: the agents list named four plugins and the personas list named three, with specialists-ecomm
# in the first and not the second.
#
# STATED PRECISELY, BECAUSE THE DIFFERENCE MATTERS: that asymmetry had cost nothing when it was found.
# specialists-ecomm ships no personas/ at all, so the shorter list and the longer one selected the same
# three directories on disk and the check's coverage was correct. What it was, was a trap with no way to
# see it -- the day that group gains a persona, it goes uncovered, silently, and no gate can report a
# hand-written list as incomplete because there is nothing to measure it against. Item 4 of the README's
# 'Adding a new team' checklist existed to keep both lists current by hand, and that is the
# maintenance this replaces.
#
# Existence-filtered, because not every plugin carries both: only the core ships personas/.
. (Join-Path $PSScriptRoot '..\lib\plugin-tree-lib.ps1')
$PublishedPlugins = @(Get-RepoPluginRoots -RepoRoot $PluginRoot.Path)
$SourceDirs = @(Get-PluginSubdirs -PluginRoots $PublishedPlugins -Leaf 'subagents') + @(Get-PluginSubdirs -PluginRoots $PublishedPlugins -Leaf 'agents')
if ($SourceDirs.Count -eq 0) {
    Write-Host "Cannot find any canonical agent-defs under $PluginRoot -- stopping." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $ConsumerPath)) {
    Write-Host "ConsumerPath '$ConsumerPath' does not exist -- stopping." -ForegroundColor Red
    exit 1
}
$ConsumerRoot = (Resolve-Path -LiteralPath $ConsumerPath).Path

# Get-LensDirCandidates: the shared source (issue #179) for where a consumer's repo lenses may live,
# so this reader cannot drift away from what specialists-init/sync-roster write. Only that helper is
# used here; the report helpers this lib also carries stay unused (no name collision -- this script
# writes its own Write-Host lines).
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')

function Read-NormalizedText {
    param([string]$Path)
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    # Normalize line endings and trailing whitespace per line -- purely a textual comparison,
    # no semantic diff. See category B/C in lint-brain.ps1 (life-hub) for the same heuristic approach.
    $lines = $raw -split "`r?`n" | ForEach-Object { $_.TrimEnd() }
    return ($lines -join "`n").Trim()
}

function Get-PortableBody {
    # Extracts the PORTABLE body from a persona template or an extensions copy: everything from
    # the first markdown H1 heading (^# ) up to JUST BEFORE the slot marker ('Eigen aan deze repo'
    # or 'Specific to this
    # repo'). Frontmatter and leading HTML comments fall outside it automatically (they come
    # before the first # heading). Same normalization as Read-NormalizedText, so a purely textual
    # comparison is possible.
    param([string]$Path)
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $lines = $raw -split "`r?`n"
    $body = New-Object System.Collections.Generic.List[string]
    $started = $false
    foreach ($line in $lines) {
        if (-not $started) {
            if ($line -match '^#\s') { $started = $true } else { continue }
        }
        # Back-compat: recognize both the legacy Dutch slot heading ('Eigen aan deze repo') and the
        # new English one ('Specific to this repo'), so a consumer with an old Dutch slot still
        # splits correctly on the marker.
        if ($line -match '^##\s+(Eigen aan deze repo|Specific to this repo)') { break }
        # The index line under the title has been location-independent since inbound #64 (plain
        # text, no longer a path-depth-dependent CLAUDE.md link). A consumer can therefore adopt
        # the body byte-identically at any path -- a purely textual comparison suffices, no link
        # normalization.
        $body.Add($line.TrimEnd())
    }
    return (($body -join "`n").Trim())
}

# --- Read the source of truth: id, group and content per shared specialist --------------------------
$sourceById = @{}
# Both spellings (#2130). This loop reads the id out of the FRONTMATTER rather than the filename, so it
# would have gone on working after the rename -- over an empty set. The enumeration is the half that
# breaks, and an empty source map here reports every consumer copy as an orphan rather than as drift.
Get-SpecialistFiles -Path $SourceDirs -Kind Subagent | ForEach-Object {
    $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    $idMatch = [regex]::Match($text, '(?m)^id:\s*(\d+)\s*$')
    $groupMatch = [regex]::Match($text, '(?m)^group:\s*(\d+)\s*$')
    if (-not $idMatch.Success -or -not $groupMatch.Success) {
        Write-Host "Warning: $($_.Name) is missing 'id:' or 'group:' in its frontmatter -- skipped." -ForegroundColor Yellow
        return
    }
    $id = $idMatch.Groups[1].Value
    $group = $groupMatch.Groups[1].Value
    $sourceById[$id] = [pscustomobject]@{
        Id            = $id
        Group         = $group
        File          = $_.FullName
        Normalized    = Read-NormalizedText $_.FullName
    }
}

if ($sourceById.Count -eq 0) {
    Write-Host "No agent-defs found under $PluginRoot -- nothing to compare." -ForegroundColor Yellow
    exit 0
}

# --- Known legacy locations in a consuming repo, in order of likelihood -----------------------------
function Get-LegacyCandidates {
    param([string]$Root, [string]$Id, [string]$Group)
    @(
        (Join-Path $Root ".claude\agents\$Group-$Id-agent.md")
        (Join-Path $Root ".claude\agents\$Id-agent.md")
        (Join-Path $Root ".claude-plugins\specialists\agents\$Group-$Id-agent.md")
        (Join-Path $Root ".claude-plugin\specialists\agents\$Group-$Id-agent.md")
    )
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($id in ($sourceById.Keys | Sort-Object)) {
    $src = $sourceById[$id]
    $found = $null
    foreach ($candidate in (Get-LegacyCandidates -Root $ConsumerRoot -Id $src.Id -Group $src.Group)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $found = $candidate; break }
    }
    if (-not $found) {
        $results.Add([pscustomobject]@{ Id = $id; Status = 'MISSING'; Path = $null })
        continue
    }
    $localNormalized = Read-NormalizedText $found
    $status = if ($localNormalized -eq $src.Normalized) { 'IDENTICAL' } else { 'DRIFTED' }
    $results.Add([pscustomobject]@{ Id = $id; Status = $status; Path = $found })
}

# --- Report ------------------------------------------------------------------------------------------
Write-Host "== check-consumer-drift -- $ConsumerRoot ==" -ForegroundColor Cyan
$driftCount = 0
$identicalCount = 0
$missingCount = 0
foreach ($r in ($results | Sort-Object Id)) {
    $name = $sourceById[$r.Id].File | Split-Path -Leaf
    switch ($r.Status) {
        'MISSING' {
            $missingCount++
            if (-not $Quiet) { Write-Host "  [MISSING]   id $($r.Id) ($name) -- no local copy, already migrated." -ForegroundColor DarkGray }
        }
        'IDENTICAL' {
            $identicalCount++
            Write-Host "  [IDENTICAL] id $($r.Id) ($name) -- dead copy at $($r.Path), safe to remove." -ForegroundColor Green
        }
        'DRIFTED' {
            $driftCount++
            Write-Host "  [DRIFTED]   id $($r.Id) ($name) -- differs from the canonical version: $($r.Path)" -ForegroundColor Red
        }
    }
}
Write-Host ""
Write-Host "Agent-def summary: $missingCount missing, $identicalCount identical (dead copies), $driftCount drifted." -ForegroundColor Cyan

# --- Persona drift (informational): portable body of the plugin personas vs. the consumer copy ------
# The same derivation as $SourceDirs above, one leaf over -- this is the list that had gone out of step
# with it, and deriving both from the marketplace makes that impossible rather than fixing it once.
$personaDirs = @(Get-PluginSubdirs -PluginRoots $PublishedPlugins -Leaf 'personas')

$personaResults = New-Object System.Collections.Generic.List[object]
if ($personaDirs.Count -gt 0) {
    Get-SpecialistFiles -Path $personaDirs -Kind Persona | Sort-Object Name | ForEach-Object {
        $personaId = Get-SpecialistFileId -Kind Persona -Name $_.Name
        if (-not $personaId) { return }
        $srcBody = Get-PortableBody $_.FullName
        # The consumer copy can live on the canonical plugin path (.claude/plugins/<family>/<plugin>/,
        # since life-hub parity), on a non-canonical family segment left by a pre-#179 bootstrap, or on
        # the legacy path (.claude/extensions/) -- Get-LensDirCandidates enumerates all three in that
        # order, shared with check-roster-sync and the writers.
        # Both spellings, directory by directory (#2130) -- the consumer's copy may already have been
        # renamed while this source tree's persona has not, or the other way round, because the two live
        # in different repositories on different release clocks.
        $pluginName = Split-Path (Split-Path $_.DirectoryName -Parent) -Leaf
        $consumerExt = $null
        $lensNames = @(Get-SpecialistFileNameCandidates -Kind Lens -Id $personaId)
        foreach ($dir in (Get-LensDirCandidates -RepoRoot $ConsumerRoot -PluginName $pluginName)) {
            foreach ($n in $lensNames) {
                $candidate = Join-Path $dir $n
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { $consumerExt = $candidate; break }
            }
            if ($consumerExt) { break }
        }
        if ($null -eq $consumerExt) {
            $personaResults.Add([pscustomobject]@{ Name = $_.Name; Status = 'MISSING'; Path = $null })
        } else {
            $extRaw = [System.IO.File]::ReadAllText($consumerExt, [System.Text.Encoding]::UTF8)
            if ($extRaw -match '(?m)^>\s*Repo-lens \(lens-only persona\)') {
                # Lens-only model: the extension is purely the repo lens and carries no body copy --
                # the portable body comes directly from the plugin, so there is nothing to compare.
                # Without this recognition, Get-PortableBody would compare the lens text with the
                # template body and report the persona as DRIFTED forever (inbound life-hub #69).
                $personaResults.Add([pscustomobject]@{ Name = $_.Name; Status = 'LENS-ONLY'; Path = $consumerExt })
            } else {
                $localBody = Get-PortableBody $consumerExt
                $status = if ($localBody -eq $srcBody) { 'IDENTICAL' } else { 'DRIFTED' }
                $personaResults.Add([pscustomobject]@{ Name = $_.Name; Status = $status; Path = $consumerExt })
            }
        }
    }
}

# The section is printed UNCONDITIONALLY, and that is the fix rather than a detail (issue #221). It
# used to be wrapped in `if ($personaResults.Count -gt 0)`, and its closing line stated a verdict with
# no coverage: "Persona drift is INFORMATIONAL: 0 drifted." Run against a repo with no lens files --
# a torn-down consumer, a bad merge, a wrong -ConsumerPath -- that printed a clean persona verdict over
# personas it had never compared, and "0 drifted of 0 compared" read exactly like "0 drifted of 4
# compared". The count is now always stated, so the zero is visible instead of implied.
Write-Host ""
Write-Host "-- Personas (portable body vs. the <g>-<id>-extension.md copy in the consumer) --" -ForegroundColor Cyan
$pDrift = 0; $pMissing = 0; $pCompared = 0
foreach ($r in $personaResults) {
    switch ($r.Status) {
        'MISSING'   { $pMissing++; if (-not $Quiet) { Write-Host "  [MISSING]   $($r.Name) -- no extension-file copy in the consumer (not bootstrapped yet)." -ForegroundColor DarkGray } }
        'IDENTICAL' { $pCompared++; Write-Host "  [IDENTICAL] $($r.Name) -- body identical to the canonical source." -ForegroundColor Green }
        # LENS-ONLY counts as covered, not as compared: the check positively established that this lens
        # carries no body, which is a real finding about a real file -- unlike MISSING, where there was
        # no file to establish anything about.
        'LENS-ONLY' { $pCompared++; Write-Host "  [LENS-ONLY] $($r.Name) -- lens-only model: body comes from the plugin, nothing to compare." -ForegroundColor Green }
        'DRIFTED'   { $pDrift++; $pCompared++; Write-Host "  [DRIFTED]   $($r.Name) -- body differs from the canonical source: $($r.Path)" -ForegroundColor Yellow }
    }
}
if ($personaDirs.Count -eq 0) {
    Write-Coverage -Category 'personas' -Checked 0 `
        -Note "no personas/ directory found under $PluginRoot, so no persona could be compared -- this is a problem with the SOURCE tree, not with the consumer"
} else {
    $note = if ($pCompared -eq 0) {
        'the consumer holds no lens file for any persona -- expected after a deliberate teardown, and a red flag if you did not run one'
    } else { '' }
    Write-Coverage -Category 'personas' -Checked $pCompared -Of $personaResults.Count -Note $note
}
Write-Host "  Persona drift is INFORMATIONAL (does not affect the exit code): $pDrift drifted of $pCompared compared." -ForegroundColor DarkGray

if ($driftCount -gt 0) {
    Write-Host ""
    Write-Host "Review the DRIFTED agent-def files before removing them -- one may contain a change that must first be brought back here (canonical)." -ForegroundColor Yellow
    exit 1
}
exit 0
