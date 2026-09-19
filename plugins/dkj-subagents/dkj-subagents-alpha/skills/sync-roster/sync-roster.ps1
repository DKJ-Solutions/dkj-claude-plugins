<#
.SYNOPSIS
    Roster-sync recovery: STAGES the catch-up after the roster-sessioncheck hook flags that a
    specialist is missing from this repo's roster/lenses (LAYER 3 -- semi-automatic, additive only).

.DESCRIPTION
    Layer 1 (check-roster-sync.ps1) detects drift; layer 2 (the SessionStart hook) surfaces it. This
    script is layer 3: the human runs it to STAGE the recovery. It does the safe, mechanical part and
    leaves every judgment call (and every write to the governance doc) to the human:

      - Detection is DELEGATED, not re-implemented. This script invokes check-roster-sync.ps1 (the
        single source of truth for what counts as drift) as a child process and parses its [ERROR]
        lines. That avoids duplicating the enabled-plugins / highest-version-cache / agent-id
        resolution logic -- if the detection rule changes, it changes in one place.
      - For each agent MISSING A LENS it creates an empty lens scaffold, using the SAME additive,
        BOM-less-LF, never-overwrite format that specialists-init/bootstrap.ps1 writes (the lens-only
        blockquote intro + a "## Specific to this repo (VUL-IN)" slot). WHERE it lands is resolved by
        Get-LensWriteDir from check-report-lib.ps1 -- the same helper the bootstrap uses: the seam
        (.claude/specialists/lenses/) for a fresh or migrated consumer, the existing tree for one that
        has not migrated. Both writers therefore agree by construction, and a scaffold can never land
        where the check does not look (issues #179 and #221).
      - For each agent MISSING A ROSTER ROW it reads the agent's frontmatter (name + description) and
        PRINTS a proposed roster row to stdout for the human to paste. It NEVER edits the roster /
        CLAUDE.md.
      - For each lens whose header still carries a STALE persona name (an older scaffold baked the
        first name in; the agent-def was later renamed -- issue #145) it PRINTS the rename-proof,
        nameless replacement header to paste. It NEVER rewrites the lens file itself -- same
        propose-only stance as the roster rows.

    To read the agent frontmatter it resolves the plugin's cache dir the same way
    check-roster-sync.ps1 does (semantically highest version under the plugin cache). That is the only
    logic mirrored here, and only to LOCATE the agent file -- not to re-decide drift.

    What this script NEVER does: write to CLAUDE.md / the roster, commit, push, or touch a branch.
    main is sacred; recovery is staged for the human to review and place on a branch under their own
    governance.

    Exit-code: 0 (this is a staging helper -- drift is the expected input, not a failure).

.PARAMETER ConsumerPathOverride
    (Optional, for tests) Use this path as the consumer repo root instead of the dual-context default.
    Passed through to check-roster-sync.ps1.

.PARAMETER CacheRootOverride
    (Optional, for tests) Use this dir as the plugin cache root instead of
    $env:USERPROFILE/.claude/plugins/cache. Passed through to check-roster-sync.ps1 and used here to
    locate the agent files whose frontmatter feeds the proposed roster rows.

.PARAMETER CheckScriptOverride
    (Optional, for tests) Use this check-roster-sync.ps1 path instead of the resolved plugin one.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/sync-roster/sync-roster.ps1"
#>
[CmdletBinding()]
param(
    [string]$ConsumerPathOverride = '',
    [string]$CacheRootOverride = '',
    [string]$CheckScriptOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Repo-root -- dual-context, identical rule to check-roster-sync.ps1: -ConsumerPathOverride wins, then
# CLAUDE_PROJECT_DIR (a consumer session), else the git-root.
#
# THE GIT ARM IS NOT --show-toplevel (issue #2115): its output is a RAW path, which Windows PowerShell
# 5.1 decodes with [Console]::OutputEncoding, so in a consumer whose checkout sits under an accented
# directory name the Resolve-Path below threw on a root that was really there. Get-GitTopLevelPath is
# this plugin's OWN mirrored copy of the shared lib -- ..\..\scripts\lib\ resolves inside
# dkj-subagents-alpha, so this crosses no plugin boundary.
. (Join-Path $PSScriptRoot '..\..\scripts\lib\repo-root-lib.ps1')

$repoRoot = if ($ConsumerPathOverride) { $ConsumerPathOverride }
            elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
            else { (Get-GitTopLevelPath).Path }
$repoRoot = (Resolve-Path -LiteralPath $repoRoot).Path

# Plugin cache root (overridable for tests) -- same default as check-roster-sync.ps1.
$cacheRoot = if ($CacheRootOverride) { $CacheRootOverride } else { Join-Path $env:USERPROFILE '.claude/plugins/cache' }

$script:created    = 0
$script:kept       = 0
$script:proposed   = 0
$script:reconciled = 0

# Write-Ok + Test-PluginNameSlug/Test-PluginMarketplaceSlug + Resolve-PluginDir: shared with
# scripts/sync/check-roster-sync.ps1 and check-connectors.ps1 (single source, issue #114). This
# lib is not repo-owned (unlike repo-config.ps1/branch-info.ps1), so it needs no consumer scaffold
# -- it ships as part of the SAME plugin payload as this skill, two levels up under scripts/lib/,
# so the $PSScriptRoot-relative path resolves correctly from the workshop checkout and from a
# consumer's plugin cache alike.
. (Join-Path $PSScriptRoot '../../scripts/lib/check-report-lib.ps1')

# This script tracks created/kept/proposed (not error/info signals, and always exits 0 -- drift is
# the expected input here, not a failure), so it deliberately keeps its own non-counting
# Write-Info/Write-Failure instead of the lib's counting variants (an intentional, later redefinition
# in this same scope -- ordinary PowerShell function resolution).
function Write-Info ([string]$Msg) { Write-Host "  [INFO]  $Msg" -ForegroundColor Yellow }
function Write-Failure ([string]$Msg) { Write-Host "  [ERROR] $Msg" -ForegroundColor Red }

# Locate check-roster-sync.ps1: an explicit override (tests) wins; then the plugin-root copy (hook /
# consumer context via CLAUDE_PLUGIN_ROOT); else the mirror that ships beside this skill
# (<plugin>/scripts/sync/, reached two levels up from skills/sync-roster/ -- works in the workshop and
# in a consumer's plugin install alike).
function Resolve-CheckScript {
    if ($CheckScriptOverride) { return $CheckScriptOverride }
    if ($env:CLAUDE_PLUGIN_ROOT) {
        $c = Join-Path $env:CLAUDE_PLUGIN_ROOT 'scripts/sync/check-roster-sync.ps1'
        if (Test-Path -LiteralPath $c -PathType Leaf) { return $c }
    }
    $mirror = Join-Path $PSScriptRoot '../../scripts/sync/check-roster-sync.ps1'
    if (Test-Path -LiteralPath $mirror -PathType Leaf) { return (Resolve-Path -LiteralPath $mirror).Path }
    return $null
}

# Resolve-PluginDir comes from the dot-sourced check-report-lib.ps1 above (shared with
# check-roster-sync.ps1, so the frontmatter we read comes from the SAME cache dir the check
# inspected -- semantically highest version; [version]-sort so 1.10.0 beats 1.9.0).

function Get-LensRelPath {
    <# Repo-relative, forward-slashed path of a lens, resolved through Get-LensWriteDir -- the SAME
       writer helper specialists-init/bootstrap.ps1 uses. The seam for a fresh or migrated consumer,
       the consumer's existing tree for one that has not migrated.

       WHY THIS IS A FUNCTION AND NOT A LITERAL. Three places here used to hardcode
       '.claude/plugins/<family>/<plugin>/' -- the PRE-SEAM path. Since the seam (issue #221) the
       bootstrap writes to .claude/specialists/lenses/, so this script created scaffolds in a layout
       its own sibling had stopped using: run sync-roster after a plugin update and a migrated
       consumer's lens surface splits across two directories. Get-LensWriteDir's own docstring calls
       that outcome worse than either layout alone, and the check would then report the fresh
       scaffolds as off-path. A writer and the writer it mirrors must resolve their destination
       through one function, not through two literals that agree until one of them moves.

       PluginName may be empty when the plugin id could not be parsed (the stale-header case). It is
       then NOT passed on: Get-LensDirCandidates documents that the caller slug-validates the name
       before it becomes a path segment, and a placeholder like '<plugin>' would break that contract
       (and Test-Path on the illegal characters with it). The seam needs no plugin segment, so an
       unknown plugin resolves there -- which is also the only honest answer. #>
    param(
        [Parameter(Mandatory = $true)][string]$LensName,
        [string]$PluginName = ''
    )
    $dir = if ($PluginName) {
        Get-LensWriteDir -RepoRoot $repoRoot -PluginName $PluginName
    } else {
        (Get-SeamPaths -RepoRoot $repoRoot).LensDir
    }
    $rel = $dir.Substring($repoRoot.Length).TrimStart('\', '/')
    return (($rel -replace '\\', '/') + '/' + $LensName)
}

# Read an agent's display name + a short description from its cache file's frontmatter. Returns a
# hashtable @{ Name; Description } (both best-effort, may be empty). The description is a YAML folded
# scalar (`>` / `>-`) that continues over indented lines until the next top-level key.
function Get-AgentInfo {
    param([string]$PluginDir, [string]$Id)
    # Both leaf names, new first: agents/ became subagents/ on September 9, 2026 (#1698), and $PluginDir
    # is a CACHE directory, so it holds whichever shape that machine's installed version shipped.
    # Two axes now, for the same reason (#2130): the FILE name is renamed by #2128 exactly as the leaf
    # was by #1698, and this reads a cache directory either way.
    $agentNames = @(Get-SpecialistFileNameCandidates -Kind Subagent -Id $Id)
    $agentPath = ''
    foreach ($leaf in @('subagents', 'agents')) {
        foreach ($n in $agentNames) {
            $cand = Join-Path (Join-Path $PluginDir $leaf) $n
            if (Test-Path -LiteralPath $cand -PathType Leaf) { $agentPath = $cand; break }
        }
        if ($agentPath) { break }
    }
    if (-not $agentPath) { return $null }
    $lines = [System.IO.File]::ReadAllText($agentPath, [System.Text.Encoding]::UTF8) -split "`r?`n"

    $name = ''; $desc = ''; $descLines = @()
    $inFm = $false; $collecting = $false
    foreach ($ln in $lines) {
        if ($ln -match '^---\s*$') {
            if (-not $inFm) { $inFm = $true; continue } else { break }
        }
        if (-not $inFm) { continue }
        if ($collecting) {
            if ($ln -match '^\s+\S') { $descLines += $ln.Trim(); continue }
            $collecting = $false
        }
        if ($ln -match '^name:\s*(.+?)\s*$') {
            $name = $Matches[1].Trim()
        } elseif ($ln -match '^description:\s*(.*)$') {
            $v = $Matches[1].Trim()
            if ($v -eq '' -or $v -eq '>' -or $v -eq '>-' -or $v -eq '|' -or $v -eq '|-') { $collecting = $true }
            else { $desc = $v }
        }
    }
    if ($descLines.Count -gt 0) { $desc = ($descLines -join ' ') }
    $desc = ($desc -replace '\s+', ' ').Trim()

    return @{ Name = $name; Description = $desc }
}

# The lens scaffold text -- same shape specialists-init/bootstrap.ps1 writes (frontmatter + lens-only
# blockquote intro + the "## Specific to this repo (VUL-IN)" slot + a TODO). BOM-less LF, never
# overwrites. Prose is English (repo convention); "VUL-IN" is kept verbatim as the stable fill-in marker.
function New-LensScaffold {
    # Rename-proof (issue #145): the header carries the STABLE '<group>-<id>' slug, never the persona's
    # first name -- so a later rename of the agent-def never drifts this generated header. The name
    # lives in exactly one place, the agent-def's `name:` frontmatter.
    param([string]$Group, [string]$Id, [string]$PluginName)
    $midDot = [char]0x00B7
    $slug = "$Group-$Id"
    $template = @"
---
id: $Id
group: $Group
---

# $slug $midDot repo-lens (VUL-IN)

> Repo-lens for the portable manual of specialist $slug in the ``$PluginName`` plugin. This file was put
> in place by ``sync-roster`` as an empty template; the agent-def reads it along automatically.
> Fill in below the repo-specific tasks and context specialist $slug needs in this repo.

## Specific to this repo (VUL-IN)

<!-- TODO: describe what this specialist does in THIS repo:
     - which files/dirs are his or her domain;
     - the repo-specific tasks, conventions and agreements;
     - references to this repo's safety-rules / gatekeepers.
     The portable craft stays in the plugin manual; only repo-specific matters belong here. -->
"@
    return ($template.TrimEnd() + "`n")
}

# Get-DisplayName (sanitize + capitalize a raw agent name) comes from the dot-sourced
# check-report-lib.ps1 above -- single source shared with check-roster-sync.ps1 (issue #145). It is
# still used here for the proposed roster row (which keeps the friendly name) and for the header-drift
# comparison, NOT for the lens scaffold (that is now nameless -- see New-LensScaffold).

Write-Host "== sync-roster -- $repoRoot ==" -ForegroundColor Cyan

# --- 1. Delegate detection to check-roster-sync.ps1 -------------------------------------------------
$checkScript = Resolve-CheckScript
if (-not $checkScript -or -not (Test-Path -LiteralPath $checkScript -PathType Leaf)) {
    Write-Failure "check-roster-sync.ps1 not found -- cannot determine the drift. Nothing staged."
    exit 0
}

$checkArgs = @('-ConsumerPathOverride', $repoRoot)
if ($CacheRootOverride) { $checkArgs += @('-CacheRootOverride', $cacheRoot) }
$checkOut = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $checkScript @checkArgs)

# Parse the [ERROR] lines. check-roster-sync emits, per missing specialist:
#   [ERROR] <agent|persona> '<g>-<id>' (<plugin>@<marketplace>) has no roster row in <file> ...
#   [ERROR] <agent|persona> '<g>-<id>' (<plugin>@<marketplace>) has no repo-lens ...
# (An "invalid plugin id" ERROR does not match this pattern and is deliberately ignored here --
# it is a settings problem, not a recoverable roster gap.)
#
# 'persona' joined the alternation with inbound #204, which extended the check to persona-only
# specialists. It has to: check-roster-sync's own report and the session hook both point the reader at
# this skill to stage the catch-up, and a pattern that only matched 'agent' would have silently staged
# NOTHING for exactly the findings that change introduced -- advice that looks helpful and does nothing.
# Both downstream steps already cope: the lens scaffold has been nameless since #145 (no agent-file
# lookup), and for a roster row Get-AgentInfo simply returns $null for a persona, so the proposal falls
# back to the id plus a "(add a short description)" placeholder -- degraded but honest, and still a
# paste-ready row. A persona file carries no name/description to do better with.
$missingLens   = @()   # ordered list of @{ Id; PluginId }
$missingRoster = @()
$rx = [regex]"\[ERROR\]\s+(?:agent|persona) '(?<id>\d{2}-\d{2})' \((?<pid>[^)]+)\) has no (?<kind>roster row|repo-lens)"
foreach ($line in $checkOut) {
    $m = $rx.Match($line)
    if (-not $m.Success) { continue }
    $entry = @{ Id = $m.Groups['id'].Value; PluginId = $m.Groups['pid'].Value }
    if ($m.Groups['kind'].Value -eq 'repo-lens') { $missingLens += $entry } else { $missingRoster += $entry }
}

# Stale-header drift (issue #145): check-roster-sync emits, per lens whose header still names an old
# persona name:  [INFO] lens '<g>-<id>' (<pid>) header still names '<stale>' (agent is now '<current>')
# ... . We stage a paste-ready reconcile (never rewrite the lens itself -- same propose-only stance as
# the roster rows).
$staleHeaders = @()   # ordered list of @{ Id; PluginId; Stale; Current }
$rxHdr = [regex]"\[INFO\]\s+lens '(?<id>\d{2}-\d{2})' \((?<pid>[^)]+)\) header still names '(?<stale>[^']*)' \(agent is now '(?<cur>[^']*)'\)"
foreach ($line in $checkOut) {
    $mh = $rxHdr.Match($line)
    if (-not $mh.Success) { continue }
    $staleHeaders += @{ Id = $mh.Groups['id'].Value; PluginId = $mh.Groups['pid'].Value; Stale = $mh.Groups['stale'].Value; Current = $mh.Groups['cur'].Value }
}

if ($missingLens.Count -eq 0 -and $missingRoster.Count -eq 0 -and $staleHeaders.Count -eq 0) {
    Write-Ok "no missing-specialist drift or stale lens headers reported by check-roster-sync -- nothing to stage."
    Write-Host "`nSummary: 0 scaffold(s) created, 0 roster row(s) proposed, 0 header reconcile(s)." -ForegroundColor Green
    exit 0
}

# Split a validated plugin id into name + marketplace, or $null if either fails the slug guard.
# Guardrail: name/marketplace become path segments -- validate as slugs before filesystem access,
# via the shared Test-PluginNameSlug/Test-PluginMarketplaceSlug (mirrors check-roster-sync /
# check-connectors).
function Split-PluginId {
    param([string]$PluginId)
    $parts = $PluginId.Split('@')
    $name = $parts[0]
    $marketplace = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    if (-not (Test-PluginNameSlug -Name $name)) { return $null }
    if (-not $marketplace -or -not (Test-PluginMarketplaceSlug -Marketplace $marketplace)) { return $null }
    return @{ Name = $name; Marketplace = $marketplace }
}

# Cache the resolved plugin dir + agent info per plugin id so we resolve each plugin once.
$pluginDirCache = @{}
function Get-CachedPluginDir {
    param([string]$Name, [string]$Marketplace)
    $key = "$Name@$Marketplace"
    if (-not $pluginDirCache.ContainsKey($key)) {
        $pluginDirCache[$key] = Resolve-PluginDir -Name $Name -Marketplace $Marketplace -CacheRoot $cacheRoot
    }
    return $pluginDirCache[$key]
}

# --- 2. Missing-lens specialists: create the additive scaffold (never overwrite) --------------------
Write-Host "`n-- lens scaffolds" -ForegroundColor Cyan
if ($missingLens.Count -eq 0) { Write-Info "no specialist is missing a lens." }
foreach ($e in $missingLens) {
    $id = $e.Id
    $parts = $id.Split('-'); $group = $parts[0]; $idNum = $parts[1]
    $pi = Split-PluginId -PluginId $e.PluginId
    if ($null -eq $pi) { Write-Failure "skipping lens for '$id' -- invalid plugin id '$($e.PluginId)'."; continue }

    # WRITE one name, LOOK FOR both (#2130). The scaffold this script is about to create carries the
    # written spelling; the never-overwrite guard below it has to recognise a lens the owner has already
    # filled in under either, or "additive only" produces a second, empty copy of it.
    $lensWriteName = Get-SpecialistFileName -Kind Lens -Id $id
    $lensRel = Get-LensRelPath -LensName $lensWriteName -PluginName $pi.Name
    $dest = Join-Path $repoRoot $lensRel
    $destDirExisting = Split-Path $dest -Parent
    $alreadyThere = @(Get-SpecialistFileNameCandidates -Kind Lens -Id $id |
        ForEach-Object { Join-Path $destDirExisting $_ } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($alreadyThere.Count -gt 0) {
        Write-Info "lens $(Split-Path $alreadyThere[0] -Leaf) already exists -- left untouched (additive only)."
        $script:kept++
        continue
    }
    # Guard against a SECOND copy on a second path (issue #179): the check reports a lens as missing
    # only when no candidate location holds it, but a stale check output (or a hand-run) could still
    # reach here for a lens that sits on a non-canonical family segment. Writing the scaffold then
    # would leave the repo with two lenses for one specialist -- exactly the outcome #179 warns about.
    $lensReadNames = @(Get-SpecialistFileNameCandidates -Kind Lens -Id $id)
    $existingElsewhere = @(Get-LensDirCandidates -RepoRoot $repoRoot -PluginName $pi.Name |
        ForEach-Object { $d = $_; $lensReadNames | ForEach-Object { Join-Path $d $_ } } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($existingElsewhere.Count -gt 0) {
        Write-Info "lens $(Split-Path $existingElsewhere[0] -Leaf) already exists at '$($existingElsewhere[0])' (non-canonical path) -- no second copy written; move it to $lensRel yourself."
        $script:kept++
        continue
    }

    # The scaffold is nameless (issue #145) -- no agent-frontmatter lookup needed here anymore.
    $destDir = Split-Path $dest -Parent
    if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    [System.IO.File]::WriteAllText($dest, (New-LensScaffold -Group $group -Id $idNum -PluginName $pi.Name), $Utf8NoBom)
    Write-Ok "created lens scaffold $lensRel ($id)"
    $script:created++
}

# --- 3. Missing-roster specialists: PRINT a proposed row (never edit the roster) --------------------
# Best-effort match of the consumer's roster style: if the roster text contains a markdown table row,
# propose a table row; if it contains list bullets, propose a list line; otherwise default to a table
# row. Read the roster path via repo-config's Get-RosterPath (default CLAUDE.md), same as the check.
$rosterRel = 'CLAUDE.md'
$configPath = Join-Path $repoRoot 'scripts/repo-config.ps1'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    . $configPath
    if (Get-Command Get-RosterPath -ErrorAction SilentlyContinue) { $rosterRel = Get-RosterPath }
}
$rosterPath = Join-Path $repoRoot $rosterRel
$rosterText = if (Test-Path -LiteralPath $rosterPath -PathType Leaf) {
    [System.IO.File]::ReadAllText($rosterPath, [System.Text.Encoding]::UTF8)
} else { '' }

$rosterStyle = 'table'
if ($rosterText -match '(?m)^\s*\|.*\|\s*$') { $rosterStyle = 'table' }
elseif ($rosterText -match '(?m)^\s*[-*]\s+\S') { $rosterStyle = 'list' }

Write-Host "`n-- proposed roster rows (style: $rosterStyle) -- paste into $rosterRel" -ForegroundColor Cyan
if ($missingRoster.Count -eq 0) { Write-Info "no specialist is missing a roster row." }
foreach ($e in $missingRoster) {
    $id = $e.Id
    $parts = $id.Split('-'); $group = $parts[0]; $idNum = $parts[1]
    $pi = Split-PluginId -PluginId $e.PluginId
    if ($null -eq $pi) { Write-Failure "skipping roster row for '$id' -- invalid plugin id '$($e.PluginId)'."; continue }

    $displayName = "$group-$idNum"; $desc = ''
    $pluginDir = Get-CachedPluginDir -Name $pi.Name -Marketplace $pi.Marketplace
    if ($pluginDir) {
        $info = Get-AgentInfo -PluginDir $pluginDir -Id $id
        if ($info) {
            $displayName = Get-DisplayName -RawName $info.Name -Fallback "$group-$idNum"
            $desc = $info.Description
        }
    }
    if (-not $desc) { $desc = '(add a short description)' }
    # Short-form description: first sentence, capped at 160 chars -- a readability cap (not a hard
    # limit) that keeps the proposed table/list row on one line for the human to paste.
    $short = $desc
    $dotIdx = $short.IndexOf('. ')
    if ($dotIdx -gt 0) { $short = $short.Substring(0, $dotIdx + 1) }
    if ($short.Length -gt 160) { $short = $short.Substring(0, 157).TrimEnd() + '...' }

    # The roster row is a PROPOSAL somebody pastes, so it names the written spelling (#2130).
    $lensName = Get-SpecialistFileName -Kind Lens -Id $id
    $lensPath = Get-LensRelPath -LensName $lensName -PluginName $pi.Name
    if ($rosterStyle -eq 'list') {
        $row = "- **$displayName** #$idNum -- $short ([``$lensName``]($lensPath))"
    } else {
        # Escape any pipe in the (plugin-derived) name/description so it cannot break the table row
        # when the human pastes it (guardrail Sean).
        $nCell = $displayName.Replace('|', '\|'); $sCell = $short.Replace('|', '\|')
        $row = "| **$nCell** #$idNum | $sCell | [``$lensName``]($lensPath) |"
    }

    Write-Host "  agent $id ($displayName), plugin $($e.PluginId):" -ForegroundColor Yellow
    Write-Host "    $row"
    $script:proposed++
}

# --- 4. Stale lens headers: PRINT the reconciled (nameless) header (never rewrite the lens) ---------
# Propose-only, exactly like the roster rows above: this skill points at the drifted header and prints
# the rename-proof replacement to paste; it does not edit the lens file. The replacement carries no
# name (the g-id slug), so it can never drift again on a future rename (issue #145).
$midDot = [char]0x00B7
Write-Host "`n-- proposed lens-header reconciles -- replace the stale header in each lens" -ForegroundColor Cyan
if ($staleHeaders.Count -eq 0) { Write-Info "no lens carries a stale scaffold header." }
foreach ($h in $staleHeaders) {
    $pi = Split-PluginId -PluginId $h.PluginId
    # Without a parseable plugin id the plugin segment is genuinely unknown. In the seam that segment
    # does not exist at all, so there is nothing left to placeholder: Get-LensRelPath resolves an
    # unknown plugin to the seam. On a consumer still using the pre-seam tree the name IS the segment,
    # which is why it is passed on whenever it parsed (and never invented -- the family/plugin mix-up
    # behind issue #179).
    $pname = if ($pi) { $pi.Name } else { '' }
    # THIS LENS EXISTS -- the drift is in its header -- so the line names the file ON DISK rather than
    # the spelling this version would write (#2130). Pointing a reader at a path they do not have is
    # worse here than anywhere else in this script: every other message announces something about to be
    # created, and this one asks them to go and edit it.
    $lensPath = ''
    foreach ($n in (Get-SpecialistFileNameCandidates -Kind Lens -Id $h.Id)) {
        $rel = Get-LensRelPath -LensName $n -PluginName $pname
        if (Test-Path -LiteralPath (Join-Path $repoRoot $rel) -PathType Leaf) { $lensPath = $rel; break }
    }
    if (-not $lensPath) { $lensPath = Get-LensRelPath -LensName (Get-SpecialistFileName -Kind Lens -Id $h.Id) -PluginName $pname }
    Write-Host "  $lensPath -- header names '$($h.Stale)', but agent '$($h.Id)' is now '$($h.Current)':" -ForegroundColor Yellow
    Write-Host "    # $($h.Id) $midDot repo-lens" -ForegroundColor Green
    Write-Host "    (also update any remaining '$($h.Stale)' mention in the intro line just below the header.)" -ForegroundColor Gray
    $script:reconciled++
}

# --- Summary + the explicit sacred-main reminder ----------------------------------------------------
Write-Host "`nSummary: $($script:created) lens scaffold(s) created, $($script:kept) already present; $($script:proposed) roster row(s) proposed; $($script:reconciled) header reconcile(s) proposed." -ForegroundColor Cyan
Write-Host "Reminder -- this skill wrote NOTHING to $rosterRel / CLAUDE.md or any lens, and committed nothing (main is sacred)." -ForegroundColor Cyan
Write-Host "Next (human, judgment calls):" -ForegroundColor Cyan
Write-Host "  1. Fill in each created '## Specific to this repo (VUL-IN)' slot with the specialist's repo-lens." -ForegroundColor Gray
Write-Host "  2. Review each proposed roster row before pasting into $rosterRel -- the name/description are lifted from plugin metadata, so read the wording (it lands in a governance doc) and adjust it to the roster's real columns/style." -ForegroundColor Gray
Write-Host "  3. Apply each proposed header reconcile to the named lens file (the header line, plus the intro mention)." -ForegroundColor Gray
Write-Host "  4. Put the changes on a branch and open a PR under your own governance -- never straight on main." -ForegroundColor Gray
exit 0
