<#
.SYNOPSIS
    Bootstrap script for the specialists-init skill: sets up the non-plugin layer of the
    Claude-Specialists system in a CONSUMING repo -- the orchestrator + main loop personas
    (Chris/Derek/Rendall) via @-imports in CLAUDE.md, plus a documented settings/hooks proposal.
.DESCRIPTION
    A Claude Code plugin can provide subagents, but CANNOT inject always-on main-loop context
    and cannot edit a consumer's CLAUDE.md. Chris (the orchestrator) is precisely such
    main-loop context: he is loaded via an @-import at the bottom of the consumer's CLAUDE.md.
    This script fills that gap. It is invoked by the skill AFTER the consumer has already set up
    the marketplace source + enabledPlugins and restarted the session (otherwise the skill
    itself is not yet available -- the chicken-and-egg documented by the skill in step 0).

    The repo lenses live at the PLUGIN PATH (.claude/plugins/<family>/<plugin>/, the standard) and
    the persona lenses are LENS-ONLY: no body copy, only the repo's own '## Specific to this repo' slot.
    The portable body comes directly from the plugin install via an @-import (the ~/.claude/plugins/
    marketplaces/... path). This way, every behavior rule lives in one place (the plugin), not duplicated.

    It performs only SAFE, additive actions -- it never overwrites existing content:
      1. Places a LENS-ONLY extension per persona (<plugin>/personas/<g>-<id>-persona.md) in
         <ConsumerRoot>/.claude/plugins/<family>/<plugin>/<g>-<id>-extension.md -- only if it does
         not exist yet. The body comes from the plugin install; the extension only carries the repo lens slot.
      1b. Places an empty lens scaffold on the plugin path for each subagent of the ENABLED
         plugin(s), clearly marked as VUL-IN. Enabled plugins are read via Get-EnabledPlugins
         (check-report-lib.ps1) from the whole settings chain Claude Code honors -- the user
         ~/.claude/settings.json, .claude/settings.json and .claude/settings.local.json, per plugin id,
         local winning. With no 'enabledPlugins' key anywhere in that chain: only its own plugin, and it
         SAYS so. Reading settings.json alone is what once made this script place 19 lenses instead of
         24 without a word about the 5 it never considered (inbound #294): the second plugin was enabled
         in settings.local.json, the file the proposal in step 3 points the reader at.
      1c. Places the repo-specific script config scaffolds required by the shared workflow skills
         (open-pr / fold-changelog / new-branch / check-roster-sync): scripts/repo-config.ps1 and
         scripts/lib/branch-info.ps1. Both as VUL-IN scaffolds with an EMPTY branch table -- taxonomy
         differs per repo. Without these files, a clean consumer hits a raw dot-sourcing error (#86).
         Never overwrites.
         The scaffolds define EVERY function check-script-contract marks required, deliberately: the
         contract used to grow (Test-BranchName, Get-RosterPath, Get-RosterIgnoredIds) without the
         scaffolds following, so a freshly bootstrapped repo got 3 [ERROR] lines about files the
         bootstrap had just written, phrased as "this lib predates the contract" (issue #226). The
         invariant is guarded by a test that runs this bootstrap and then the real contract check --
         do not add a required contract entry without extending the scaffold below.
      2. Ensures that <ConsumerRoot>/CLAUDE.md carries the TWO orchestrator @-imports at the bottom:
         the body from the plugin install (~/.claude/plugins/marketplaces/.../01-01-persona.md) and
         the repo lens (.claude/plugins/<family>/<plugin>/01-01-extension.md). If CLAUDE.md is missing,
         it writes a minimal scaffold; if the imports already exist, it does nothing.
      3. Writes TWO settings proposals, and DOES NOT touch settings.json in either case -- the
         placement is the owner's act, and a session may not widen a permissions file at all.
         a. .claude/settings.suggested.jsonc -- the ANNOTATED proposal: both permissions halves + a
            hooks stub, with the reasoning for each rule beside it. Explanation, not a replacement.
         b. .claude/settings.proposed.json -- the MERGED end result (inbound #1124): the consumer's own
            .claude/settings.json key for key with those halves folded in, strict JSON, no comments,
            no hooks stub. So adopting the proposal is 'replace one file with the other' instead of a
            hand-merge against a destination that already holds enabledPlugins and
            extraKnownMarketplaces -- the keys a whole-file paste of (a) silently deletes, which lands
            the reader in #1076's zero-surface state through a file that parses perfectly.
            Written only when settings.json can be read WHOLE; see the block itself for the three
            shapes that are refused and why refusing beats writing a lossy file called safe to paste.

    Exit code: 0 = done (even if everything was already present). 1 = plugin persona source or
    ConsumerRoot was not found.
.PARAMETER ConsumerRoot
    Root of the consuming repo. Default: current working directory.
.EXAMPLE
    powershell -File bootstrap.ps1
.EXAMPLE
    powershell -File bootstrap.ps1 -ConsumerRoot C:\path\to\my-repo
#>
[CmdletBinding()]
param(
    [string]$ConsumerRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# The persona source is two levels above this script: <plugin>/skills/specialists-init/ -> <plugin>/personas/
$personaDir = Join-Path $PSScriptRoot '../../personas'
if (-not (Test-Path -LiteralPath $personaDir -PathType Container)) {
    Write-Host "Cannot find the persona source ($personaDir) -- stopping." -ForegroundColor Red
    exit 1
}
$personaDir = (Resolve-Path -LiteralPath $personaDir).Path
if (-not (Test-Path -LiteralPath $ConsumerRoot -PathType Container)) {
    Write-Host "ConsumerRoot '$ConsumerRoot' does not exist -- stopping." -ForegroundColor Red
    exit 1
}
$ConsumerRoot = (Resolve-Path -LiteralPath $ConsumerRoot).Path

# --- Derive plugin + the ~ path to the plugin install ---------------------------------------------
# personaDir = <...>/plugins/<plugin>/personas (source/marketplace-clone layout) or
# <...>/<marketplace>/<plugin>/<version>/personas (plugin-cache layout). From that we derive the plugin
# carrying the personas. The portable body comes from the plugin install; if personaDir falls under user
# home (~), the standard marketplace cache, we express that path as a ~ path for the @-import in CLAUDE.md.
#
# DERIVED FROM THE PARENT, NEVER FROM A NAMED SEGMENT (#405). This used to look up the index of the
# literal segment 'claude-code-plugins' and take two further segments to skip the family level. That
# lookup is unusable now the directory is called 'plugins': the segment occurs a SECOND time in every
# real install path (~/.claude/plugins/marketplaces/<mp>/plugins/<plugin>/personas), IndexOf returns
# the first, and the derivation would yield the MARKETPLACE name -- the exact defect #179 fixed, back
# again through a rename. The parent walk below needs no segment name and covers all three layouts:
# the plugin directory is simply personas' parent, one level further up when a version directory sits
# in between. personaDir is resolved above, so no '..' segment can reach here.
#
# The FAMILY segment is deliberately NOT derived here either (issue #179). It used to be, and in the
# plugin-cache layout that derivation yields the MARKETPLACE name: a repo installed through
# 'specialists@dkj-claude-plugins' got its lenses written to .claude/plugins/dkj-claude-plugins/,
# while check-roster-sync.ps1 only ever looked under 'claude-specialists' -- so it reported 16 existing
# lenses as missing, and the fix it suggested would have created a second copy of each on a second
# path. The family is a property of the plugin family, not of the marketplace it came from, so it now
# comes from Get-LensFamily in check-report-lib.ps1: one value, shared by this writer, sync-roster.ps1
# and the check.
$pdParent = Split-Path $personaDir -Parent
if ((Split-Path $pdParent -Leaf) -match '^\d+\.\d+\.\d+') {
    $personaPlugin = Split-Path (Split-Path $pdParent -Parent) -Leaf
} else {
    $personaPlugin = Split-Path $pdParent -Leaf
}
# check-report-lib.ps1 travels in the same plugin payload as this skill, so a $PSScriptRoot-relative
# dot-source resolves from the source repo, the marketplace clone and the plugin cache alike (the same
# reasoning sync-roster.ps1 relies on). A missing lib must never stop a bootstrap -- this is the script
# that sets a repo up in the first place -- so it falls back to the same literal the lib returns.
$lensLib = Join-Path $PSScriptRoot '../../scripts/lib/check-report-lib.ps1'
if (Test-Path -LiteralPath $lensLib -PathType Leaf) { . $lensLib }
$family = if (Get-Command Get-LensFamily -ErrorAction SilentlyContinue) { Get-LensFamily } else { 'claude-specialists' }
# Durable body path: the written @-import must NEVER point to the version-pinned cache. The cache
# (~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/) is ephemeral -- after a plugin update,
# the old version directory is purged (~7 days) and an import pointing to it breaks; the orchestrator body
# then fails to load. The marketplaces clone (~/.claude/plugins/marketplaces/<marketplace>/) is versionless
# and pulled upon update: that is the durable anchor. @-imports do NOT support variable expansion
# (${CLAUDE_PLUGIN_ROOT} etc. do not work there), so we write a fixed, versionless path. If bootstrap already
# runs from the marketplaces clone or a non-cache location (e.g. source repo consuming itself), $personaDir
# is already durable and nothing changes.
function Get-DurablePersonaDir([string]$PersonaDir, [string]$Plugin) {
    $parts = ($PersonaDir -replace '/', '\') -split '\\' | Where-Object { $_ }
    $cacheIdx = [array]::IndexOf([string[]]$parts, 'cache')
    # Only intervene on real cache layout .../plugins/cache/<mp>/<plugin>/<version>/personas.
    if ($cacheIdx -lt 1 -or ($cacheIdx + 1) -ge $parts.Count) { return $PersonaDir }
    if ($parts[$cacheIdx - 1] -ne 'plugins') { return $PersonaDir }
    $marketplace = $parts[$cacheIdx + 1]
    if ($marketplace -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { return $PersonaDir }
    $clone = Join-Path (($parts[0..($cacheIdx - 1)] -join '\')) (Join-Path 'marketplaces' $marketplace)
    if (-not (Test-Path -LiteralPath $clone -PathType Container)) { return $PersonaDir }
    # Search clone for personas directory under a directory named exactly as the plugin and carrying
    # the orchestrator body (01-01-persona.md is the import target -- it must actually exist).
    $hit = Get-ChildItem -LiteralPath $clone -Recurse -Directory -Filter 'personas' -ErrorAction SilentlyContinue |
        Where-Object {
            (Split-Path $_.Parent.FullName -Leaf) -eq $Plugin -and
            (Test-Path -LiteralPath (Join-Path $_.FullName '01-01-persona.md'))
        } | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $PersonaDir
}
$durablePersonaDir = Get-DurablePersonaDir -PersonaDir $personaDir -Plugin $personaPlugin

$homeDir = $HOME
if ($durablePersonaDir.StartsWith($homeDir, [System.StringComparison]::OrdinalIgnoreCase)) {
    $personaTilde = '~' + $durablePersonaDir.Substring($homeDir.Length)
} else {
    $personaTilde = $durablePersonaDir
}
$personaTilde = $personaTilde -replace '\\', '/'

# Plugin path in the consumer (the PRE-SEAM location for lenses; still written for a consumer that
# already has a lens tree there).
$padRel = ".claude/plugins/$family"
$padDirRoot = Join-Path $ConsumerRoot (".claude/plugins/$family")

# THE SEAM (issue #221). A FRESH consumer gets one directory and one line: lenses flat in
# .claude/specialists/lenses/, everything specialist-shaped behind .claude/specialists/SPECIALISTS.md,
# and a single '@'-import in CLAUDE.md -- so an uninstall is "remove one directory and one line" instead
# of hand-cutting a roster woven through six sections.
#
# An ALREADY-ADOPTED consumer keeps its existing tree. Get-LensWriteDir makes that call, and the reason
# it is not "always the seam" matters: writing seam lenses beside a legacy tree would split the surface
# in two, leaving the teardown to reason about both at once and a reader to find half a roster in each.
# Migrating is the owner's act (four steps, in the family README); once they have moved the files, this
# follows them automatically because the legacy tree is gone.
#
# Same fallback discipline as $family above: a missing lib must never stop a bootstrap, and without it
# the script simply behaves as it did before the seam existed.
$seam = if (Get-Command Get-SeamPaths -ErrorAction SilentlyContinue) { Get-SeamPaths -RepoRoot $ConsumerRoot } else { $null }
$seamMode = $false
if ($seam -and (Get-Command Get-LensWriteDir -ErrorAction SilentlyContinue)) {
    $seamMode = ((Get-LensWriteDir -RepoRoot $ConsumerRoot -PluginName $personaPlugin) -eq $seam.LensDir)
}

function Get-LensDest {
    <# Where THIS run writes the lens for <group>-<id> of $Plugin. One function, so the persona-lens
       loop and the scaffold loop cannot drift into two slightly different notions of "where lenses go"
       -- the bug class this repo keeps meeting. In seam mode the tree is FLAT: <group>-<id> is unique
       family-wide, so a per-plugin subdirectory would only add a path segment for the teardown to walk. #>
    param(
        [Parameter(Mandatory = $true)][string]$Plugin,
        [Parameter(Mandatory = $true)][string]$Id
    )
    if ($script:seamMode) { return (Join-Path $script:seam.LensDir "$Id-extension.md") }
    return (Join-Path (Join-Path $script:padDirRoot $Plugin) "$Id-extension.md")
}

# What the console lines and the closing "next steps" call the lens location.
$lensRelDisplay = if ($seamMode) { "$($seam.RelDir)/lenses" } else { "$padRel/<plugin>" }

Write-Host "== specialists-init bootstrap -- $ConsumerRoot ==" -ForegroundColor Cyan

# Lens inventory per plugin, collected while the lenses below are written or found. It feeds the
# register proposal this script prints at the end: 'which <group>-<id>s does this repo have a lens
# for' is exactly what the workshop's connector manifest records in its 'extensions' array. Collected
# for BOTH the created and the already-present case -- the manifest describes the repo's state, not
# what this particular run happened to do.
$registerInventory = @{}

function Add-RegisterId {
    <# Record an id under a plugin in the inventory. Hashtable + ArrayList are reference types, so this
       works from inside the ForEach-Object blocks below; keeping it one function stops the two lens
       loops from growing two slightly different versions of the same bookkeeping. #>
    param([hashtable]$Inventory, [string]$Plugin, [string]$Id)
    if (-not $Inventory.ContainsKey($Plugin)) { $Inventory[$Plugin] = New-Object System.Collections.ArrayList }
    if (-not $Inventory[$Plugin].Contains($Id)) { [void]$Inventory[$Plugin].Add($Id) }
}

# --- 1. Persona lenses (LENS-ONLY), never overwritten --------------------------------------
# Destination comes from Get-LensDest: the seam for a fresh consumer, the existing tree otherwise.
$personaDest = Split-Path (Get-LensDest -Plugin $personaPlugin -Id '01-01') -Parent
if (-not (Test-Path -LiteralPath $personaDest)) { New-Item -ItemType Directory -Path $personaDest -Force | Out-Null }

$copied = 0; $kept = 0
Get-ChildItem -Path $personaDir -Filter '*-persona.md' -File | Sort-Object Name | ForEach-Object {
    if ($_.BaseName -notmatch '^(\d{2})-(\d{2})-persona$') { return }
    $g = $Matches[1]; $id = $Matches[2]
    $dest = Get-LensDest -Plugin $personaPlugin -Id "$g-$id"
    Add-RegisterId -Inventory $registerInventory -Plugin $personaPlugin -Id "$g-$id"
    if (Test-Path -LiteralPath $dest -PathType Leaf) {
        Write-Host "  [keep]  $(Split-Path $dest -Leaf) already exists -- not overwritten." -ForegroundColor DarkGray
        $script:kept++
        return
    }
    # Extract title (first # heading) from template; we do NOT copy the body itself (lens-only).
    # Read as UTF8 -- title contains an emoji and em-dash that otherwise become mojibake.
    $title = ''
    foreach ($line in (([System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)) -split "`r?`n")) {
        if ($line -match '^#\s') { $title = $line.TrimEnd(); break }
    }
    if (-not $title) { $title = "# $g-$id" }
    $bodyPath = "$personaTilde/$($_.Name)"
    if ($g -eq '01' -and $id -eq '01') {
        $loadNote = if ($script:seamMode) {
            'Chris loads his body automatically -- `CLAUDE.md` imports `.claude/specialists/SPECIALISTS.md`, which imports this lens and the body; other personas are read on-demand from this path.'
        } else {
            'Chris loads his body automatically via the `@` import at the bottom of `CLAUDE.md`; other personas are read on-demand from this path.'
        }
    } else {
        $loadNote = 'The body is read on-demand from this path when Chris brings in this persona (no static `@` import).'
    }
    $content = @"
---
id: $id
group: $g
---

$title

> Repo-lens (lens-only persona) -- portable body lives in the plugin source:
> ``$bodyPath``.
> $loadNote

## Specific to this repo (VUL-IN)

<!-- TODO (fill in after bootstrap): replace this placeholder with the repo lens of this
     specialist -- who he or she directs or serves in THIS repo and along which agreements:
     team and routing, pipelines and gatekeepers (safety rules, branch discipline,
     and PR rule; refer to repo-CLAUDE.md#safety-rules). The portable expertise remains in the
     plugin persona; only repo-specific matters belong here. -->
"@
    [System.IO.File]::WriteAllText($dest, ($content.TrimEnd() + "`n"), $Utf8NoBom)
    Write-Host "  [create] lens-only $lensRelDisplay/$(Split-Path $dest -Leaf)" -ForegroundColor Green
    $script:copied++
}

# --- 1b. Empty lens scaffolds for subagent specialists (never overwrite) --------------------
# Agent definitions come from plugin(s); repo lens per specialist lives at consumer's plugin path.
# For each agent of enabled plugin(s), place an empty, marked scaffold.

# Own plugin name: in source layout, directory name is plugin name; in plugin cache, it is
# directory above version directory (...\<plugin>\<x.y.z>\).
function Get-OwnPluginName([string]$PluginRoot) {
    $leaf = Split-Path $PluginRoot -Leaf
    if ($leaf -match '^\d+\.\d+\.\d+') { return (Split-Path (Split-Path $PluginRoot -Parent) -Leaf) }
    return $leaf
}

# subagents/ directory of a plugin in both layouts (source: sibling directory; cache: <name>\<version>\subagents).
# BOTH LEAF NAMES ARE READ, new first: this family renamed agents/ to subagents/ on September 9, 2026
# (#1698), and a consumer's cache still holds whatever version that machine last installed -- so a
# bootstrap knowing only the new leaf would find no agent defs at all in a pre-rename install and
# scaffold an empty roster, which is the one wrong answer that looks like a correct one.
# Note dual role of $parent (Victor finding): in source layout it's family directory, in cache layout
# plugin name directory (above version directories) -- $market resolves to proper parent root in both cases.
function Get-PluginAgentsDir([string]$PluginName, [string]$OwnPluginRoot) {
    $parent = Split-Path $OwnPluginRoot -Parent
    foreach ($leaf in @('subagents', 'agents')) {
        $src = Join-Path $parent (Join-Path $PluginName $leaf)
        if (Test-Path -LiteralPath $src -PathType Container) { return (Resolve-Path -LiteralPath $src).Path }
    }
    $market = Split-Path $parent -Parent
    $nameDir = Join-Path $market $PluginName
    if (Test-Path -LiteralPath $nameDir -PathType Container) {
        # Semantic sort via [version] (Victor finding): plain string sort puts 1.9.0 above
        # 1.10.0 once a version segment reaches two digits.
        $versions = Get-ChildItem -LiteralPath $nameDir -Directory |
            Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
            Sort-Object { [version]$_.Name } -Descending
        foreach ($v in $versions) {
            foreach ($leaf in @('subagents', 'agents')) {
                $a = Join-Path $v.FullName $leaf
                if (Test-Path -LiteralPath $a -PathType Container) { return (Resolve-Path -LiteralPath $a).Path }
            }
        }
    }
    return $null
}

$ownPluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$ownPluginName = Get-OwnPluginName $ownPluginRoot

# Enabled plugins from the consumer's whole settings chain (inbound #294 -- Get-EnabledPlugins carries
# the measurement and the reasoning). Without an 'enabledPlugins' key anywhere: only own plugin.
# Plugin names validated as slugs before converting to paths.
$pluginNames = @($ownPluginName)
# The FULL plugin ids ('<name>@<marketplace>'), kept alongside the bare names: the workshop's
# connector manifest identifies a plugin by its full id, so the register proposal at the end of this
# script needs the '@marketplace' part that the name-only list above deliberately drops.
$pluginIdByName = @{}
# Same defensive shape as $family above: the lib is dot-sourced only IF PRESENT, because a missing lib
# must never stop the script that sets a repo up in the first place. Deliberately NO inline settings
# reader as a fallback -- re-typing a narrower version of the chain here is precisely the duplication
# that produced inbound #294 (one reader per call site, tightened in none of them). Saying out loud that
# the enable state could not be read is the honest degraded mode.
$enabledPlugins = $null
if (Get-Command Get-EnabledPlugins -ErrorAction SilentlyContinue) {
    $enabledPlugins = Get-EnabledPlugins -RepoRoot $ConsumerRoot
} else {
    Write-Host "  [notice] check-report-lib.ps1 not found -- the enabled-plugin state was not read; lens scaffolds only for '$ownPluginName'." -ForegroundColor Yellow
}

if ($null -ne $enabledPlugins) {
    foreach ($badLayer in @($enabledPlugins.Unreadable)) {
        Write-Host "  [notice] $badLayer does not parse as JSON -- its enabledPlugins entries were not read." -ForegroundColor Yellow
    }
    if ($enabledPlugins.Ids.Count -gt 0) {
        $pluginNames = @($enabledPlugins.Ids | ForEach-Object { $_.Split('@')[0] })
        foreach ($id in $enabledPlugins.Ids) { $pluginIdByName[$id.Split('@')[0]] = $id }
    }
}

# WHICH MARKETPLACE IS OURS (inbound #1084). The consumer's chain can enable plugins from several
# marketplaces -- this machine's own does -- and the connector register at the end of this run is
# THIS family's. Read off this script's own plugin id rather than derived from a path: the id is what
# the register itself keys on, and the path-derivation this file already warns about twice (#179,
# #405) yields the marketplace in one layout and the plugin in another. $null where the chain does
# not name our own plugin, which the notices just below already report as a partial answer.
$ownMarketplace = if ($pluginIdByName.ContainsKey($ownPluginName)) {
    ($pluginIdByName[$ownPluginName] -split '@', 2)[1]
} else { $null }
function Test-OurMarketplace([string]$PluginName) {
    if (-not $script:ownMarketplace) { return $true }   # cannot tell -- the caller says so out loud
    if (-not $script:pluginIdByName.ContainsKey($PluginName)) { return $false }
    return (($script:pluginIdByName[$PluginName] -split '@', 2)[1] -eq $script:ownMarketplace)
}

# Say what was NOT considered, and why (inbound #294, proposal 3). The old version only spoke up for an
# UNREADABLE settings.json, so the one case that actually happened -- a perfectly valid settings.json
# without the key, while the enable sat in settings.local.json -- passed in complete silence, and the
# closing "19 lens-scaffold(s) created" was consistent with what this script decided rather than with
# what the consumer has switched on. A count that matches the wrong thing is worse than a missing count:
# nothing in it invites a second look.
if ($null -eq $enabledPlugins) {
    # Already reported above -- nothing to add beyond which plugin this fell back to.
} elseif ($enabledPlugins.Ids.Count -eq 0) {
    if (-not $enabledPlugins.AnyFileExists) {
        Write-Host "  [notice] no settings file in this repo's chain -- lens scaffolds only for '$ownPluginName'." -ForegroundColor Yellow
    } elseif (-not $enabledPlugins.AnyKeyFound) {
        Write-Host "  [notice] no 'enabledPlugins' key in $($enabledPlugins.Summary) -- lens scaffolds only for '$ownPluginName'." -ForegroundColor Yellow
    } else {
        Write-Host "  [notice] 'enabledPlugins' enables nothing in $($enabledPlugins.Summary) -- lens scaffolds only for '$ownPluginName'." -ForegroundColor Yellow
    }
} elseif ($pluginNames -notcontains $ownPluginName) {
    # Its own case on purpose: this script's own plugin is demonstrably enabled (it is running), so a
    # chain that does not name it means the reader is looking at a partial answer.
    Write-Host "  [notice] '$ownPluginName' is not among the enabled plugins in $($enabledPlugins.Summary) -- no lens scaffolds for it." -ForegroundColor Yellow
}

# The OTHER asymmetry (inbound #302). Since #294 this script says what it SKIPPED ("agents directory of
# plugin '...' not found"); it said nothing about what it placed for a plugin that is enabled here but has
# no install record for this path. Measured in a throwaway consumer: 27 lens files written, 4 personas and
# 23 scaffolds, for specialists that exist in no session of that repo -- and the closing count read as a
# clean, complete setup.
#
# Reported here rather than refused: the scaffolds are harmless and the state is usually one install
# command away from intended, so placing them is right. What was wrong is placing them silently. Counted
# into one line after the loop, mirroring the closing report's own shape.
# FULL plugin ids, not the bare names: the remedy this line names is 'claude plugin install <id>', and an
# id without its '@marketplace' part is not a command the reader can copy.
$notInstalledIds = @()
if ($null -ne $enabledPlugins -and $enabledPlugins.Ids.Count -gt 0 -and (Get-Command Get-InstallRecord -ErrorAction SilentlyContinue)) {
    $ownInstalls = Get-InstallRecord -RepoRoot $ConsumerRoot
    if ($ownInstalls.Exists -and -not $ownInstalls.Readable) {
        Write-Host "  [notice] $($ownInstalls.Path) does not parse as JSON -- whether the enabled plugins are installed for this path was not checked." -ForegroundColor Yellow
    }
    $notInstalledIds = @($enabledPlugins.Ids |
        Where-Object { -not (Test-PluginInstalledHere -InstallRecord $ownInstalls -PluginId $_) })
}

$scaffolded = 0; $lensKept = 0
foreach ($pluginName in ($pluginNames | Sort-Object -Unique)) {
    if ($pluginName -notmatch '^[a-z0-9][a-z0-9-]*$') {
        Write-Host "  [notice] plugin name '$pluginName' is not a valid slug -- skipped." -ForegroundColor Yellow
        continue
    }
    $agentsDir = Get-PluginAgentsDir -PluginName $pluginName -OwnPluginRoot $ownPluginRoot
    if ($null -eq $agentsDir) {
        # SAY WHAT THE SKIP MEANS, not just what was not found (inbound #1084). Worded as a missing
        # DIRECTORY, this line read as an error about the plugin's layout, and the consequence a
        # reader actually acts on -- what the register proposal at the end of this run will say about
        # that plugin -- was left for them to infer several hundred lines later. For a plugin of this
        # family that consequence is now "nothing": it reaches the manifest either way. For a plugin
        # of another marketplace it is real, and the line has to say which of the two this is.
        $regNote = if (Test-OurMarketplace $pluginName) {
            "It IS in the register proposal below, with an empty 'extensions' array."
        } else {
            "It is not this marketplace's plugin either, so it is not in the register proposal below -- that register is this family's."
        }
        Write-Host "  [notice] plugin '$pluginName' has no agents/ directory -- it ships no lenses, so it gets no scaffolds. $regNote" -ForegroundColor Yellow
        continue
    }
    $pluginPad = Split-Path (Get-LensDest -Plugin $pluginName -Id '00-00') -Parent
    if (-not (Test-Path -LiteralPath $pluginPad)) { New-Item -ItemType Directory -Path $pluginPad -Force | Out-Null }
    Get-ChildItem -Path $agentsDir -Filter '*-agent.md' -File | Sort-Object Name | ForEach-Object {
        if ($_.BaseName -notmatch '^(\d{2})-(\d{2})-agent$') { return }
        $group = $Matches[1]; $id = $Matches[2]
        $dest = Get-LensDest -Plugin $pluginName -Id "$group-$id"
        Add-RegisterId -Inventory $registerInventory -Plugin $pluginName -Id "$group-$id"
        if (Test-Path -LiteralPath $dest -PathType Leaf) { $script:lensKept++; return }
        $midDot = [char]0x00B7
        # Rename-proof (issue #145): the header carries the STABLE '<group>-<id>' slug, never the
        # persona's first name -- so a later rename of the agent-def never drifts this generated
        # header. The name lives in exactly one place, the agent-def's `name:` frontmatter.
        $slug = "$group-$id"
        # The TITLE deliberately carries no (VUL-IN) -- the same rule, and for the same reason, as the
        # SPECIALISTS.md scaffold further down: only the SLOT heading may carry the marker, because
        # filling the lens replaces that heading and nothing ever touches the title. Test-LooksGenerated
        # keys on '(VUL-IN)' at ANY heading level, so a marked title survives a filled-in lens and makes
        # the teardown read authored repo knowledge as a disposable scaffold. Inbound #451 measured that
        # in a consumer with 24 lenses: three filled specialist lenses holding 153 lines between them all
        # printed [remove], and -Apply would have taken them. Until then this template did exactly what
        # the comment on the SPECIALISTS.md branch already forbade, for every lens instead of one file.
        $template = @"
---
id: $id
group: $group
---

# $slug $midDot repo lens

> Repo lens alongside portable domain guide for specialist $slug in ``$pluginName`` plugin.
> Created by ``specialists-init`` as empty template; agent definition reads it automatically.
> Fill in repo-specific tasks and context below that specialist $slug needs in this repo.

## Specific to this repo (VUL-IN)

<!-- TODO: describe what this specialist does in THIS repo:
     - which files/directories belong to their domain;
     - repo-specific tasks, conventions, and agreements;
     - references to safety rules / gatekeepers for this repo.
     Portable expertise remains in plugin manual; only repo-specific matters belong here. -->
"@
        [System.IO.File]::WriteAllText($dest, $template, $Utf8NoBom)
        Write-Host "  [create] lens scaffold $lensRelDisplay/$group-$id-extension.md" -ForegroundColor Green
        $script:scaffolded++
    }
}

# --- 1c. Repo-specific script config scaffolds (never overwrite) -----------------------------------
# Two repo-specific files in the consumer's repo root. Without them, a clean consumer hits a raw
# dot-source error (#86). specialists-init places them as VUL-IN scaffolds: repo-agnostic structure
# with empty spots to fill. Branch taxonomy differs per repo and deliberately remains an EMPTY table
# -- never another repo's taxonomy.
#
# SPLIT BY WHO ASKS FOR IT (August 8, 2026), because the workflow moved into its own opt-in plugin.
# Only two of these functions serve the core: Get-RosterPath and Get-RosterIgnoredIds, both read by
# check-roster-sync. Everything else -- the repo name, the lint gate, the changelog heading, the live
# stage, the PR markers -- and the WHOLE of branch-info.ps1 serve the branch/release scripts, which a
# repo that never enabled the workflow plugin does not have. Scaffolding those unconditionally asked a
# consumer to configure scripts that are not there, which is the exact defect the
# plugin-serves-the-consumer doctrine names. So the roster half is always written and the workflow
# half joins it only when the pack is enabled.
#
# ASSEMBLED FROM PARTS RATHER THAN WRITTEN AS TWO COMPLETE VARIANTS: a second full scaffold would put
# a second copy of the roster functions in this file, free to drift from the first.
$repoConfigHeader = @'
<#
.SYNOPSIS
    Repo-specific configuration read by the Claude Specialists scripts.
.DESCRIPTION
    Placed by specialists-init. The scripts themselves are repo-agnostic and read this small block of
    repo data from the repo root. Anything below carrying a VUL-IN marker is yours to fill in; a
    section without one is complete as generated.

    No Set-StrictMode here: dot-sourcing would modify calling script's strict mode.
    Pure ASCII (repo convention for .ps1): Windows PowerShell 5.1 reads BOM-less script as ANSI.
#>

'@

$repoConfigRosterPart = @'
# Repo-root-relative path to the file holding the specialist roster, read by check-roster-sync.
# Points at the seam inclusion, because that is where specialists-init puts the roster slot -- change it
# only if you move the roster somewhere else. Required by the contract, so the scaffold defines it rather
# than leaving the session check to report it against a missing function (issue #226).
#
# It used to say 'CLAUDE.md', which is where the roster lived BEFORE the seam existed. The consequence was
# not cosmetic: the check read a file containing only the @-import, found no roster rows, and reported
# every specialist as missing -- naming CLAUDE.md as the place to fix it, while this bootstrap's own
# next-steps block says the roster does NOT go there (inbound #333).
$script:RosterPath = '__SEAM_ROSTER_PATH__'

function Get-RosterPath {
    return $script:RosterPath
}

# '<group>-<id>' ids deliberately kept OUT of the roster and lenses. Normally empty: every specialist
# an enabled plugin ships belongs in the roster, and adopting one that arrives with a plugin update is
# the default, not a question. Fill this in only for a deliberate, self-authored exception -- and note
# that without it 'skip this one' is not an implementable outcome at all, which is exactly why the
# contract marks it required.
$script:RosterIgnoredIds = @()

function Get-RosterIgnoredIds {
    return $script:RosterIgnoredIds
}

'@

# The workflow half: written only for a consumer that enabled the workflow plugin. Every function here
# is called by a branch/release script, so a repo without that pack has nothing that reads any of it.
$repoConfigWorkflowPart = @'
# --- The workflow plugin's half -------------------------------------------------------------------
# These are read by the branch/release scripts (open-pr, fold-changelog, ship-pr, cut-release). They
# are here because this repo enabled dkj-policy; without that plugin nothing
# reads them. Fill in the VUL-IN values below and remove the VUL-IN markers.

# VUL-IN: GitHub repo hosting this repository (owner/name), e.g. 'DaveKJohn/my-repo'.
$script:RepoName = 'VUL-IN/repo'

function Get-RepoName {
    return $script:RepoName
}

function Get-RepoBlobUrl {
    return "https://github.com/$($script:RepoName)/blob/main/"
}

# VUL-IN: repo-root-relative path to lint gate executed by open-pr before PR,
# e.g. 'scripts/lint/check-plugin-integrity.ps1' or 'scripts/maintenance/lint-brain.ps1'.
$script:LintScript = 'VUL-IN'

function Get-LintScript {
    return $script:LintScript
}

# Optional (#177): if this repo has a separate "go live" stage after cutting a release -- e.g. a
# push to a live deploy target -- describe it here so the cut-release skill's Block 2 (the live push
# + moving the '<- LIVE' marker) applies. Left empty: most repos (this workshop, life-hub) cut a
# release without one, so the skill only prints Block 1 (cutting).
$script:LiveStage = ''

function Get-LiveStage {
    return $script:LiveStage
}

# Optional (#101): if this repo's PR template uses different marker text than the workshop's own,
# or a PR should carry a default assignee/milestone, define any of these four functions --
# Get-PrDescriptionPlaceholder, Get-PrApprovalPattern, Get-PrAssignee, Get-PrMilestone -- and
# open-pr.ps1 picks them up automatically. Left undefined here on purpose: open-pr.ps1 falls back
# to its own built-in defaults (this repo's current markers, no assignee/milestone) when any of
# these four are absent, so a fresh consumer needs none of this to get started.
'@

$branchInfoScaffold = @'
<#
.SYNOPSIS
    Shared branch conventions for workflow scripts (repo-specific prefix table).
.DESCRIPTION
    Placed by specialists-init as a VUL-IN scaffold. Provides Get-BranchTypes, Get-BranchPrefix,
    Get-BranchInfo and Test-BranchName -- every function check-script-contract marks required for this
    lib. Prefix table determines GitHub label for PR and changelog entry type, and is
    DIFFERENT PER REPO -- fill in your branch taxonomy below (table intentionally empty).

    No Set-StrictMode here: dot-sourcing would modify calling script's strict mode.
    Pure ASCII (repo convention for .ps1).
#>

# VUL-IN: canonical branch types in release notes order, e.g. @('Feat', 'Fix', 'Docs', 'Chore').
$script:BranchTypeOrder = @()

# VUL-IN: prefix -> GitHub label (PR) + branch type (changelog entry). Example:
#   feat  = @{ Label = 'enhancement';   Type = 'Feat' }
#   fix   = @{ Label = 'bug';           Type = 'Fix' }
#   docs  = @{ Label = 'documentation'; Type = 'Docs' }
#   chore = @{ Label = 'documentation'; Type = 'Chore' }
$script:BranchPrefixTable = @{
}

function Get-BranchTypes {
    return $script:BranchTypeOrder
}

function Get-BranchPrefix {
    param([Parameter(Mandatory = $true)][string]$Branch)
    if ($Branch -match '/') { return ($Branch -split '/')[0] }
    return ($Branch -split '-')[0]
}

function Get-BranchInfo {
    param([Parameter(Mandatory = $true)][string]$Branch)
    $prefix = Get-BranchPrefix -Branch $Branch
    $known  = $script:BranchPrefixTable.ContainsKey($prefix)
    [pscustomobject]@{
        Branch   = $Branch
        Prefix   = $prefix
        IsKnown  = $known
        Label    = $(if ($known) { $script:BranchPrefixTable[$prefix].Label } else { $null })
        Type     = $(if ($known) { $script:BranchPrefixTable[$prefix].Type } else { $null })
        SafeName = $Branch -replace '/', '-'
    }
}

# Validates a branch name before it is used (new-branch.ps1), instead of repeating the reject rules
# inline. Required by the contract, so the scaffold defines it rather than leaving the session check to
# report it against a missing function (issue #226). Hard rejects: an empty name, 'main', and any name
# containing 'final' (deliberately broad, so 'finalize' is rejected too). An UNKNOWN PREFIX is not a
# hard reject -- the caller reads IsKnown and decides for itself, consistent with the other shared
# scripts, which fall back on an unknown prefix rather than blocking.
function Test-BranchName {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Branch)

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        return [pscustomobject]@{ IsValid = $false; Reason = "Branch name must not be empty."; IsKnown = $false }
    }
    if ($Branch -eq 'main') {
        return [pscustomobject]@{ IsValid = $false; Reason = "Branch name must not be 'main'."; IsKnown = $false }
    }
    if ($Branch -match 'final') {
        return [pscustomobject]@{ IsValid = $false; Reason = "Branch name must not contain the token 'final'."; IsKnown = $false }
    }

    $info = Get-BranchInfo -Branch $Branch
    [pscustomobject]@{ IsValid = $true; Reason = $null; IsKnown = $info.IsKnown }
}
'@

# Derive repo name from consumer's git remote (ergonomics): eliminates manual setup for RepoName.
# Remote URL is external input placed into written .ps1 and later used in `gh --repo` -- strictly validate
# (Sean advice) and fall back to VUL-IN placeholder on any doubt. Git invocation must never crash bootstrap
# (missing git/no origin -> clean fallback), wrapped in try/catch.
# Intentionally `git config --get remote.origin.url` NOT `git remote get-url`: latter applies
# `insteadOf` rewrites (CI runners and some dev setups set globally, e.g. git@github.com: -> https),
# making returned format unpredictable. `config --get` gives RAW stored origin -- exactly what consumer configured.
function Get-DerivedRepoName([string]$Root) {
    # Intentionally NO `... | Select-Object -First 1` directly on git call: pipe aborts upstream (git)
    # prematurely on first line, terminating process with non-zero exit code if git hasn't cleanly exited -- timing-dependent.
    # Flaky `$LASTEXITCODE` caused guard below to return `$null` (VUL-IN instead of derived name), causing non-deterministic red CI.
    # Capture complete output first, record exit code immediately, then apply `Select-Object` on static array.
    try {
        $out  = & git -C $Root config --get remote.origin.url 2>$null
        $code = $LASTEXITCODE
    } catch {
        return $null
    }
    if ($code -ne 0) { return $null }
    $url = ($out | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($url)) { return $null }
    # Only github.com; all common forms (https/ssh/git scheme + scp-like git@github.com:).
    # owner/repo as strict slug; remove .git suffix and trailing slash. Scheme forms may carry optional
    # userinfo (e.g. 'x-access-token:TOKEN@' -- how git insteadOf rule rewrites remote, or origin URL with credentials);
    # userinfo intentionally NOT captured -- owner/repo only. Userinfo cannot contain '/', so 'evil.com/x@github.com' spoof won't match.
    $m = [regex]::Match($url.Trim(), '^(?:(?:https|ssh|git)://(?:[^/@]+@)?github\.com/|git@github\.com:)(?<owner>[A-Za-z0-9][A-Za-z0-9._-]*)/(?<repo>[A-Za-z0-9][A-Za-z0-9._-]*?)(?:\.git)?/?$')
    if (-not $m.Success) { return $null }
    return "$($m.Groups['owner'].Value)/$($m.Groups['repo'].Value)"
}

# The roster path comes from Get-SeamPaths, the same source that decides where this bootstrap WRITES the
# roster slot -- so the writer and the value the consumer's check reads back cannot drift apart. It was a
# hand-typed 'CLAUDE.md' in the scaffold above and it was simply wrong (inbound #333). A single-quoted
# here-string cannot interpolate, hence the placeholder rather than a $(...) in the template.
#
# The fallback matters for the one path where the lib is absent: without it the consumer would receive a
# literal '__SEAM_ROSTER_PATH__' as its roster path, which is worse than the bug being fixed. It repeats the
# literal knowingly, and the test asserts the two agree.
$seamRosterRel = if ($seam) { $seam.RelInclusion } else { '.claude/specialists/SPECIALISTS.md' }
$repoConfigRosterPart = $repoConfigRosterPart.Replace('__SEAM_ROSTER_PATH__', $seamRosterRel)

# Did this repo choose the workflow plugin? Read from the SAME enabled-plugin answer the lens loop uses
# (Get-EnabledPlugins over the whole settings chain) rather than from a second reader -- one reader per
# question is the lesson of inbound #294. A chain that could not be read at all degrades to "no": the
# roster half is what every consumer needs, and writing a workflow half nobody reads is the defect being
# repaired, so the safe direction is to leave it out and say so.
# EVERY PRIOR NAME IS ACCEPTED WHILE CONSUMERS MIGRATE (#886, August 26, 2026; #1437, September 5, 2026).
# The plugin was renamed 'workflow-davekjohn' -> 'contributing-davekjohn' -> 'dkj-policy', and this reader
# is in the CORE team, which every
# consumer enables and updates on its own schedule -- so a consumer can be on a core that knows the new
# name while their settings still say an old one. Matching only the new name would then write the roster
# half alone and say the pack is not enabled, which is the exact silent-degradation defect the paragraph
# above describes as the thing being repaired. The old names are a migration allowance, not second
# supported ids: each can go once every register entry has moved off it.
$workflowPluginName  = 'dkj-policy'
$workflowPluginNames = @($workflowPluginName, 'contributing-davekjohn', 'workflow-davekjohn')
# Which of those names this repo actually enabled, captured once: $hasWorkflowPack asks whether
# there is one, and the settings proposal further down needs to know WHICH -- a consumer still on the
# migration name has that segment in their plugin path, and a rule anchored on the other spelling
# would match nothing for them.
$workflowNamesHere   = @($pluginNames | Where-Object { $workflowPluginNames -contains $_ })
$hasWorkflowPack     = ($workflowNamesHere.Count -gt 0)
$workflowNameHere    = if ($hasWorkflowPack) { $workflowNamesHere[0] } else { $workflowPluginName }

$repoConfigScaffold = $repoConfigHeader + $repoConfigRosterPart
if ($hasWorkflowPack) {
    $repoConfigScaffold += "`n" + $repoConfigWorkflowPart

    # Insert derived name into repo config scaffold (before $scriptScaffolds assembly so new content is
    # included). If derivation fails, VUL-IN placeholder remains. Only meaningful in the workflow half --
    # RepoName lives there, so with the pack absent there is nothing to derive into.
    $derivedRepo = Get-DerivedRepoName $ConsumerRoot
    if ($derivedRepo) {
        $repoConfigScaffold = $repoConfigScaffold.Replace(
            "# VUL-IN: GitHub repo hosting this repository (owner/name), e.g. 'DaveKJohn/my-repo'.",
            "# Derived by specialists-init from git remote (origin) of this repo. Adjust if incorrect.")
        $repoConfigScaffold = $repoConfigScaffold.Replace(
            "`$script:RepoName = 'VUL-IN/repo'",
            "`$script:RepoName = '$derivedRepo'")
    }
} else {
    $derivedRepo = $null
    Write-Host "  [notice] '$workflowPluginName' is not enabled here -- scripts/repo-config.ps1 gets the roster half only, and scripts/lib/branch-info.ps1 is not scaffolded at all. Nothing in this repo reads them: the branch/release scripts ship with that pack. Enable it and re-run this to have both filled in." -ForegroundColor DarkGray
}

$scriptScaffolds = @(
    @{ Rel = 'scripts/repo-config.ps1';     Content = $repoConfigScaffold }
)
# branch-info.ps1 is ENTIRELY the workflow plugin's: both its contract functions are called only by
# new-branch and open-pr. A repo without the pack has nothing that dot-sources it.
if ($hasWorkflowPack) {
    $scriptScaffolds += @{ Rel = 'scripts/lib/branch-info.ps1'; Content = $branchInfoScaffold }
}
# The functions the shared scripts call on each lib. Kept next to the scaffolds that define them, so a
# contract that grows is noticed here rather than at a consumer's next session start. Split the same way
# the scaffold is: the roster pair is the core's, the rest belongs to the workflow plugin, so a repo
# without it is never told it is missing a function nothing there calls.
$contractFunctions = @{
    'scripts/repo-config.ps1'     = @('Get-RosterPath', 'Get-RosterIgnoredIds')
}
if ($hasWorkflowPack) {
    $contractFunctions['scripts/repo-config.ps1'] += @('Get-RepoName', 'Get-LintScript')
    $contractFunctions['scripts/lib/branch-info.ps1'] = @('Get-BranchInfo', 'Test-BranchName')
}

$scriptScaffolded = 0; $scriptKept = 0
$repoConfigDerived = $false
foreach ($s in $scriptScaffolds) {
    $dest = Join-Path $ConsumerRoot $s.Rel
    if (Test-Path -LiteralPath $dest -PathType Leaf) {
        Write-Host "  [keep]   $($s.Rel) already exists -- not overwritten." -ForegroundColor DarkGray
        # KEEPING IT IS RIGHT; SAYING NOTHING ELSE IS NOT (inbound #271). These addresses are occupied in
        # any repo that predates the plugin -- the scaffolds are precisely the files that were extracted
        # FROM repos like these -- and an existing one has no reason to carry the plugin's own contract
        # functions. check-roster-sync then calls Get-RosterPath on a file that does not define it, and
        # the consumer gets [ERROR] lines at every session start with nothing connecting them to this
        # moment. Reported by a consumer who hit exactly that.
        #
        # Only the MISSING ones are named: listing all four at a repo that already has them would be the
        # noise that teaches people to skim this output.
        $missing = @()
        if ($contractFunctions.ContainsKey($s.Rel)) {
            $existing = [System.IO.File]::ReadAllText($dest, [System.Text.Encoding]::UTF8)
            $missing = @($contractFunctions[$s.Rel] | Where-Object { $existing -notmatch "(?m)^\s*function\s+$([regex]::Escape($_))\b" })
        }
        if ($missing.Count -gt 0) {
            Write-Host "           it does not define $($missing -join ', ') -- the shared scripts call those, so add them or check-roster-sync/open-pr will report them missing at every session start." -ForegroundColor Yellow
        }
        $scriptKept++
        continue
    }
    $destDir = Split-Path $dest -Parent
    if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    [System.IO.File]::WriteAllText($dest, ($s.Content.TrimEnd() + "`n"), $Utf8NoBom)
    $note = ''
    if ($s.Rel -eq 'scripts/repo-config.ps1' -and $derivedRepo) {
        $note = " (RepoName derived: $derivedRepo)"
        $repoConfigDerived = $true
    }
    Write-Host "  [create] script scaffold $($s.Rel)$note" -ForegroundColor Green
    $scriptScaffolded++
}

# --- 2. The import(s) at the bottom of CLAUDE.md ---------------------------------------------------
# Pre-seam: two lines (plugin body + repo lens). Seam mode: ONE line pointing at SPECIALISTS.md, which
# carries those two imports itself. Verified before this was designed: "Imported files can recursively
# import other files, with a maximum depth of four hops" -- the seam spends two (CLAUDE.md ->
# SPECIALISTS.md -> body/lens), and a relative import resolves against the file that CONTAINS it, which
# is why SPECIALISTS.md can say '@lenses/...'.
$bodyImport = "@$personaTilde/01-01-persona.md"
$claudeMd = Join-Path $ConsumerRoot 'CLAUDE.md'

# The explanatory line is kept as its own variable so BOTH the idempotence guard below and
# specialists-teardown can recognise it literally, and it is deliberately IDENTICAL in both modes:
# the teardown matches this exact sentence to tidy a leftover copy, and a mode-dependent wording would
# silently stop that from working. Measured in a real consumer round-trip
# (davekokbwj/smartwatchbanden, 2026-07-29): the guard used to test only for the lens import, so after a
# teardown -- which removes '@' lines and deliberately nothing else -- the paragraph was still there
# while the import was gone. The guard then read "not present" and re-appended the WHOLE block,
# paragraph included. One extra copy per teardown->init cycle, counted 1 -> 2 -> 3, and no gate
# reported it. Idempotence has to cover everything the script WRITES, not just the line it happens
# to look for.
#
# SECOND TIME (inbound #271): the note is TWO lines -- this head plus a generated tail -- and both this
# guard and the teardown matched the head only, each by re-typing the literal. So the tail orphaned and
# accumulated, invisibly, because every counter keys on the head. The head now comes from
# Get-OrchestratorNote in check-report-lib.ps1, and both removers use Test-IsOrchestratorNoteLine from
# that same source: a literal mirrored by hand in two scripts is what caused this.
$importNote = (Get-OrchestratorNote).Head
# Inside SPECIALISTS.md the same sentence needs no "from ..." tail: the reader is already in the file.
$importNoteSeam = $importNote + ' from `lenses/`.'

if ($seamMode) {
    # The inclusion itself. Never overwritten -- once the owner has put their roster in here it is
    # authored content, exactly like a filled-in lens.
    if (-not (Test-Path -LiteralPath $seam.Dir)) { New-Item -ItemType Directory -Path $seam.Dir -Force | Out-Null }
    if (Test-Path -LiteralPath $seam.Inclusion -PathType Leaf) {
        Write-Host "  [keep]   $($seam.RelDir)/SPECIALISTS.md already exists -- not overwritten." -ForegroundColor DarkGray
    } else {
        # The TITLE deliberately carries no (VUL-IN): only the roster slot does. Filling in the roster
        # therefore removes the marker, and the teardown -- which keys on an unfilled slot HEADING --
        # then correctly reads the file as authored. A (VUL-IN) title would survive a filled-in roster
        # and make the teardown delete somebody's work.
        $inclusion = @"
# The Claude Specialists -- this repo's inclusion

<!-- Written by specialists-init. CLAUDE.md imports THIS ONE FILE; everything specialist-shaped lives
     here or under lenses/. That is the whole point: an uninstall is "remove one directory and one
     line". Keep the roster below rather than in CLAUDE.md, or that property is lost again. -->

$importNoteSeam

$bodyImport

@lenses/01-01-extension.md

## The roster (VUL-IN)

<!-- TODO (fill in after bootstrap): the roster, the routing table and the chains belong HERE, not in
     CLAUDE.md -- which specialist takes which signal, and in what order they hand off. Leaving this
     heading in place tells the teardown the file is still an untouched scaffold and may be removed;
     replace it once you have written your roster. -->
"@
        [System.IO.File]::WriteAllText($seam.Inclusion, ($inclusion.TrimEnd() + "`n"), $Utf8NoBom)
        Write-Host "  [create] $($seam.RelDir)/SPECIALISTS.md -- the single inclusion (roster slot: VUL-IN)." -ForegroundColor Green
    }
    $guardImport = $seam.ImportLine
    $importBody = $seam.ImportLine
    $importTail = "from ``$($seam.RelDir)/``; that file carries the body import, the lens import and this repo's roster."
} else {
    $lensImport = "@$padRel/$personaPlugin/01-01-extension.md"
    $guardImport = $lensImport
    $importBody = "$bodyImport`n`n$lensImport"
    $importTail = "from plugin path; routes on-demand to specialists in ``$padRel/``."
}
$importBlock = @"

$importNote
$importTail

$importBody
"@

if (-not (Test-Path -LiteralPath $claudeMd -PathType Leaf)) {
    # The heading and the two prose lines come from Get-ClaudeMdScaffold in check-report-lib.ps1, for the
    # same reason $importNote does: the teardown has to RECOGNISE this exact wording to report it, and a
    # literal re-typed in a second script is what produced both instances of the accumulation bug (inbound
    # #271, #331). Written by one script, recognised by another, defined in one place.
    $sc = Get-ClaudeMdScaffold
    $scaffold = @"
$($sc.Heading)

$($sc.Prose -join "`n")
$importBlock
"@
    [System.IO.File]::WriteAllText($claudeMd, $scaffold, $Utf8NoBom)
    # SINGULAR: since the seam, CLAUDE.md carries exactly ONE import. The plural was left over from the
    # pre-seam layout, where the body and the lens imports both sat here -- and this script's own next-step
    # 1b already got it right ("CLAUDE.md, which keeps exactly one import line"), so the two disagreed
    # (inbound #337).
    Write-Host "  [create] CLAUDE.md scaffold created with the orchestrator import." -ForegroundColor Green
} else {
    $md = [System.IO.File]::ReadAllText($claudeMd, [System.Text.Encoding]::UTF8)
    if ($md -match [regex]::Escape($guardImport)) {
        Write-Host "  [keep]   CLAUDE.md already has the orchestrator import(s)." -ForegroundColor DarkGray
    } else {
        # Drop a leftover explanatory line from an earlier cycle before appending, so a
        # teardown -> init round-trip cannot accumulate copies of it. Matches the literal generated
        # sentence only: a consumer who reworded or translated it has authored that text, and this
        # must not touch it.
        # $keptLines, NOT $kept: $kept is the persona-lens "already present" COUNTER declared at the
        # top of this script, and assigning an array to it here silently destroyed the final report --
        # PowerShell then interpolated the whole of CLAUDE.md into the summary line where a number
        # belonged. Measured 2026-07-30 against a consumer that already had its own CLAUDE.md.
        #
        # WHY NO TEST CAUGHT IT, which is the part worth keeping: this block runs ONLY when the
        # consumer already has a CLAUDE.md without the guard import -- i.e. on exactly the path a real
        # adoption takes, and never on the path where the report is asserted. A fresh fixture with no
        # CLAUDE.md takes the other branch, so every suite stayed green while the normal case printed
        # garbage. Third instance of the same lesson in this repo (the $pid note in check-roster-sync,
        # and the shared-counter collision here): a name reused for a second purpose in the same scope
        # breaks somewhere else entirely, and the report is the last place anyone looks.
        $mdLines = @($md -split "`r?`n")
        # Filters the whole note BLOCK (head + either tail), not just the head -- the omission behind
        # inbound #271. One source with the teardown: Test-IsOrchestratorNoteLine.
        $keptLines = @($mdLines | Where-Object { -not (Test-IsOrchestratorNoteLine -Line $_) })
        $dropped = $mdLines.Count - $keptLines.Count
        if ($dropped -gt 0) {
            $md = $keptLines -join "`n"
            Write-Host "  [tidy]   removed $dropped leftover orchestrator note line(s) from a previous cycle." -ForegroundColor DarkGray
        }
        # Match the file's own line endings. WriteAllText with a "`n"-built block used to paste LF
        # into a CRLF file -- measured as 8 lone LFs in a real consumer, invisible to every gate.
        $nl = if ($md -match "`r`n") { "`r`n" } else { "`n" }
        $block = (($importBlock -replace "`r`n", "`n") -replace "`n", $nl)
        $md = $md.TrimEnd() + $nl + $block + $nl
        [System.IO.File]::WriteAllText($claudeMd, $md, $Utf8NoBom)
        Write-Host "  [add]    orchestrator import added to bottom of CLAUDE.md." -ForegroundColor Green
    }
}

# --- 3. Settings/hooks proposal (DOES NOT touch settings.json) -------------------------------------
# The header below offers settings.local.json as an equal alternative, and as of inbound #294 that is
# finally true of this family's own checks: the enable state is read from the whole chain, so a reader
# who follows this advice is no longer invisible to the bootstrap, the roster check and the connector
# check. Before that fix this line pointed at the one file none of the three read -- the plugin
# recommending a configuration it could not see. Keep the two in step: widening this hint again means
# widening Get-SettingsChainPaths first.
$claudeDir = Join-Path $ConsumerRoot '.claude'
if (-not (Test-Path -LiteralPath $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }
# BOTH artifact names come from Get-SettingsArtifactNames, so this writer and specialists-teardown's
# remover cannot drift apart -- see that function for why a name typed twice is the shape this repo has
# already been bitten by three times. The fallback keeps a missing lib from stopping the one script whose
# job is to set a repo up, exactly as $family does above.
$settingsArtifacts = if (Get-Command Get-SettingsArtifactNames -ErrorAction SilentlyContinue) {
    Get-SettingsArtifactNames
} else {
    [pscustomobject]@{ Suggested = '.claude\settings.suggested.jsonc'; Proposed = '.claude\settings.proposed.json' }
}
$suggestPath  = Join-Path $ConsumerRoot $settingsArtifacts.Suggested
$proposedPath = Join-Path $ConsumerRoot $settingsArtifacts.Proposed
# The destination the merged file is built from and replaces. NOT the settings chain: $enabledPlugins
# above is read from all three layers (user, project, local) and the merge must not flatten somebody's
# user-scope configuration into their repo. Merging THIS file alone is what makes 'replace it with the
# merged one' provably lossless whatever the rest of the chain holds.
$settingsPath = Join-Path $claudeDir 'settings.json'

# THE ALLOW HALF (inbound #1075). Until it existed, this proposal carried exactly one permissions
# half -- 'deny' -- so a consumer who followed the adoption to the letter got a repo that FORBIDS the
# five things the workflow must never do and PERMITS nothing it must do. Under a prompting mode that
# is a prompt per step; under auto mode the classifier can refuse outright, with no prompt to approve.
# And the gap can only be closed from OUTSIDE a session: a permissions file is never agent-editable
# (dkj-subagents-alpha's own settings manual says so, and that boundary is correct), so the human is the only
# one who can paste the lines -- which makes shipping them more important, not less.
#
# THE PATHS ARE WILDCARDED, AND THAT IS THE FIX RATHER THAN A SHORTCUT. The report proposed writing
# the resolved plugin root into each rule. That path is VERSION-PINNED -- an install record reads
# .../plugins/cache/<marketplace>/<plugin>/<version>/ -- so a rule naming today's root stops matching
# at the consumer's next plugin update, silently, while still reading as covered. A permission rule
# that expires is worse than none. The '*' stands in for the machine-specific root and the version;
# every token before it is literal, which is what holds the rule to this plugin's script of that name
# and keeps it clear of the startup warning that fires when an allow rule wildcards the program or
# the subcommand. Rule syntax per the permission reference: '*' matches at any position, and
# PowerShell rules take the same shape as Bash rules.
#
# NAMED BY THE PLUGIN THAT IS ACTUALLY ENABLED, not by the current id -- $workflowNameHere, resolved
# where $hasWorkflowPack is: a consumer still on a migration name ('contributing-davekjohn',
# 'workflow-davekjohn') has that
# segment in their cache path, and a rule anchored on the other spelling would match nothing for them.
# THE RULES ARE DATA, AND THE TWO FILES ARE BOTH RENDERINGS OF IT (inbound #1124). The annotated .jsonc
# below and the merged .json beside it have to carry the SAME rules -- a proposal explaining why a rule
# exists next to a pasteable file that does not contain it is worse than either alone. So the rules are
# declared once here and each file is generated from them; neither can be edited without the other
# following.
$allowRules = if ($hasWorkflowPack) {
    @(
        "Bash(powershell -NoProfile -ExecutionPolicy Bypass -File *$workflowNameHere*new-branch.ps1*)",
        "Bash(powershell -NoProfile -ExecutionPolicy Bypass -File *$workflowNameHere*open-pr.ps1*)",
        "Bash(powershell -NoProfile -ExecutionPolicy Bypass -File *$workflowNameHere*ship-pr.ps1*)",
        "PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File *$workflowNameHere*new-branch.ps1*)",
        "PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File *$workflowNameHere*open-pr.ps1*)",
        "PowerShell(powershell -NoProfile -ExecutionPolicy Bypass -File *$workflowNameHere*ship-pr.ps1*)",
        'Bash(gh repo edit --delete-branch-on-merge*)'
    )
} else { @() }
$denyRules = @(
    'Bash(git push --force:*)',
    'Bash(git push -f:*)',
    'Bash(git reset --hard:*)',
    'Bash(git rebase:*)',
    'Bash(rm -rf:*)'
)

# Rendered at the .jsonc's own indentation (6 spaces inside "permissions"), so the annotated file reads
# exactly as it did when the rules were typed into the here-string.
$allowJsonc = ($allowRules | ForEach-Object { '      "' + $_ + '"' }) -join ",`n"
$denyJsonc  = ($denyRules  | ForEach-Object { '      "' + $_ + '"' }) -join ",`n"

$allowBlock = if ($hasWorkflowPack) {
    @"
    // The workflow's own entry points -- the three commands the documented cycle is made of. Both
    // tool shapes, because the same line can arrive through the Bash tool or the PowerShell tool.
    //
    // DELIBERATELY ABSENT: cut-release.ps1, because it cuts a release and that one is worth a
    // prompt; and 'gh repo delete' / 'gh repo archive', for the same reason. 'gh repo edit' earns
    // its place in the single form the workflow assumes -- it needs deleteBranchOnMerge on.
    "allow": [
$allowJsonc
    ],
"@
} else {
    @'
    // Empty on purpose: no workflow plugin is enabled here, so there is no scripted entry point to
    // permit -- this repo keeps the way of working it already had, and its commands are its own.
    // The 'deny' half below still applies. Enable 'dkj-policy' and re-run
    // specialists-init, and this half is filled in with that workflow's entry points.
    "allow": [],
'@
}

$suggestion = @"
// PROPOSAL -- created by specialists-init. This is NOT active configuration.
// The rules below, with the reasoning for each. To ADOPT them, replace .claude/settings.json with
// settings.proposed.json beside this file -- that is these same rules already merged into your
// settings.json -- and then delete both. Copying individual blocks from here into settings.json (or
// settings.local.json) also works, and the caveats for that route are below. Hooks are a STUB:
// scripts are repo-specific and do not exist here yet -- replace with guards/lints appropriate for
// this repo (or omit).
//
// THIS FILE IS AN EXPLANATION, NOT A REPLACEMENT -- DO NOT PASTE IT WHOLE (inbound #1124). It holds
// the permission halves and nothing else, while .claude/settings.json ALREADY HOLDS the two keys
// that got you this far: "enabledPlugins" and "extraKnownMarketplaces". Overwriting that file with
// this one deletes both, and the result is a settings file that parses perfectly and loads no
// plugins at all -- no skills, no subagents, no SessionStart hooks, and no message of any kind
// saying so (that state, measured: inbound #1076). Whatever you copy from here, those two keys stay.
//
// SO USE THE FILE BESIDE THIS ONE. settings.proposed.json is this proposal already merged INTO your
// settings.json -- strict JSON, every key you had, both halves below folded in. Replacing
// settings.json with it is one act with nothing to reconstruct by hand. Read on here for WHY each
// rule is in it.
//
// AND STRIP EVERY '//' LINE ON THE WAY OUT, INCLUDING THIS ONE. This file is JSONC, where comments
// are legal; settings.json and settings.local.json are strict JSON, where they are not. Claude Code
// does not partially apply a settings file it cannot parse -- it ignores the whole file -- so one
// comment carried across silently switches off the deny half below, the allow half, enabledPlugins
// and extraKnownMarketplaces together. The only signal is a startup line reading "Invalid or
// malformed JSON", which names a parse error rather than "your safety rules are off" (inbound #1097).
{
  // Governance: permit what the way of working is made of, block the destructive git actions the
  // safety rules prohibit. Both halves are ready to use as they stand.
  "permissions": {
$allowBlock
    "deny": [
$denyJsonc
    ]
  },
  // Safety hooks: STUB, and the path below is a PLACEHOLDER -- this bootstrap does not create that
  // script and nothing else ships it. Copying this block as-is activates a hook pointing at nothing.
  // Replace the angle-bracketed name with a real script in this repo, or drop the "hooks" key.
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command",
          "command": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/maintenance/<your-check>.ps1",
          "timeout": 30 } ] }
    ]
  }
}
"@
# TRAILING NEWLINE, because the here-string above ends at its closing brace and WriteAllText adds
# nothing (inbound #363). Same defect the #337.2 warning names for CLAUDE.md, one file over -- and that
# warning does not cover this one, so nothing pointed at it.
$suggestion = $suggestion.TrimEnd("`r", "`n") + "`n"
[System.IO.File]::WriteAllText($suggestPath, $suggestion, $Utf8NoBom)
# The FULL path, not the relative name (#241). This file is the one artifact that can go completely
# unnoticed: many consumers gitignore '.claude/*' (measured in davekokbwj/smartwatchbanden), so it
# never shows up in 'git status' and 'git checkout .' does not clean it up either -- an operator
# verifying a round-trip with git alone will not see it exists. It cannot be made to announce itself
# through git, so it announces itself here, in the only output that is guaranteed to be read.
#
# ASK GIT WHICH SIDE THIS REPO IS ON rather than hedging (inbound #337). The old wording -- "gitignored in
# many repos, so this path is your only pointer to it" -- is conditional and gave the reader no way to tell
# whether it applied to them. For a fresh consumer (this script's own audience) "no .gitignore yet" is the
# likely case, and the measured v10 repo had none, so the file DID show up in git status and the warning was
# simply wrong there. check-ignore answers it in one call; git absent or erroring falls back to the honest
# conditional rather than claiming either way.
#
# ASKED PER FILE, because the answer differs per file and the merged one carries more. A rule naming
# '.claude/settings.json' or '.claude/settings.suggested.jsonc' by name -- both real shapes -- covers one
# of these paths and not the other, so one reading cannot speak for the pair. Three call sites want it,
# so it is a function rather than the same six lines three times.
function Test-PathGitIgnored([string]$Root, [string]$Path) {
    try {
        & git -C $Root check-ignore --quiet -- $Path 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { return $true }
        if ($LASTEXITCODE -eq 1) { return $false }
    } catch { }
    return $null   # git absent or erroring: say so, rather than claiming either way
}
$suggestIgnored = Test-PathGitIgnored -Root $ConsumerRoot -Path $suggestPath

$suggestNote = if ($suggestIgnored -eq $true) {
    'gitignored in this repo, so this path is your only pointer to it'
} elseif ($suggestIgnored -eq $false) {
    'NOT gitignored in this repo, so it will show up in git status until you delete it'
} else {
    'gitignored in many repos, so this path may be your only pointer to it'
}
Write-Host "  [create] $suggestPath placed (annotated proposal -- not active; $suggestNote)." -ForegroundColor Green

function Format-JsonIndented {
    <# Re-indent COMPRESSED JSON with two spaces per level. Windows PowerShell 5.1's own pretty-printer
       aligns each value to the column its key ends at, which is unreadable past two levels and re-flows
       whole blocks when a key is renamed -- see the caller for why that matters for this file
       specifically.

       IT IS A SCANNER, NOT A REGEX, and that is the whole design. The characters it acts on -- { } [ ] ,
       and : -- are all legal INSIDE a JSON string, and a consumer's settings can hold any of them (a hook
       command with a brace, a permission rule with a comma). So it tracks whether it is inside a string
       and whether the previous character was a backslash, and touches nothing while it is. Feeding it
       compressed output is what keeps that the only question it has to answer: no whitespace outside
       strings to preserve or strip, and no formatting of PowerShell's to second-guess.

       Empty containers stay on one line: '{}' rather than a brace, a blank line and a brace. #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Json,
        [string]$Indent = '  '
    )
    $sb = New-Object System.Text.StringBuilder
    $depth = 0
    $inString = $false
    $escaped = $false
    for ($i = 0; $i -lt $Json.Length; $i++) {
        $c = [string]$Json[$i]
        if ($inString) {
            [void]$sb.Append($c)
            if ($escaped)          { $escaped = $false }
            elseif ($c -eq '\')    { $escaped = $true }
            elseif ($c -eq '"')    { $inString = $false }
            continue
        }
        switch ($c) {
            '"' { $inString = $true; [void]$sb.Append($c) }
            ':' { [void]$sb.Append(': ') }
            ',' { [void]$sb.Append(",`n" + ($Indent * $depth)) }
            { $_ -eq '{' -or $_ -eq '[' } {
                $close = if ($c -eq '{') { '}' } else { ']' }
                if (($i + 1) -lt $Json.Length -and [string]$Json[$i + 1] -eq $close) {
                    [void]$sb.Append($c + $close); $i++
                } else {
                    $depth++
                    [void]$sb.Append($c + "`n" + ($Indent * $depth))
                }
            }
            { $_ -eq '}' -or $_ -eq ']' } {
                $depth--
                [void]$sb.Append("`n" + ($Indent * $depth) + $c)
            }
            default { [void]$sb.Append($c) }
        }
    }
    return $sb.ToString()
}

# --- 3b. The MERGED end result, as a strict-JSON file that can be pasted in one act (#1124) --------
# WHY A SECOND FILE RATHER THAN MORE WARNING TEXT. The .jsonc above cannot be copied whole for three
# independent reasons, and two of them were already warned about: its comments are illegal in the
# destination (#1097) and its hooks path is a placeholder (#363). The third was not warned about
# anywhere, and it is the expensive one -- the destination is NOT EMPTY. It carries enabledPlugins and
# extraKnownMarketplaces, and a whole-file paste deletes them, producing a settings file that parses
# perfectly and loads nothing: no skills, no subagents, no SessionStart hooks, no message. That is the
# state #1076 measured (3 -> 0 hooks, 6 -> 0 skills, 15 -> 0 subagents across one restart), reached by a
# second route.
#
# And it lands there in the ONE ACT THIS FAMILY RESERVES FOR THE HUMAN. A session may not widen a
# permissions file -- dkj-subagents-alpha's own settings manual says so and that boundary is right -- so this
# paste cannot be delegated: it is performed once per repo, by the person least practised at it, and it
# fails silently and totally. The instruction that stood here, 'copy what fits', asked that person to
# invent a hand-merge against a destination the page never mentioned already held something load-bearing.
# More warning text does not make a file pasteable; a merged file does. Reported from testrun 3 by the
# repo owner, not the runner: 'if I have to do this myself, I want to be able to copy and paste the whole
# file with no extra steps.'
#
# THE HOOKS STUB IS OMITTED HERE, deliberately and only here. The annotated file keeps it, because there
# it is an illustration a reader adapts; a file whose whole promise is 'paste this' must not ship a Stop
# hook pointing at scripts/maintenance/<your-check>.ps1, which nothing creates. The page already offers
# 'or drop the hooks key' as a legitimate outcome, so this is not a new judgment call. An existing hooks
# key of the consumer's own is preserved like every other key -- what is skipped is OUR stub.
$proposedWritten = $false
# Declared here rather than where it is measured, because the next-steps read it on BOTH paths and
# StrictMode makes an unset variable a terminating error rather than a blank.
$proposedIgnored = $null

# Read the destination. An empty or absent file is an ordinary state, not a failure: the enable may sit
# in the user layer or in settings.local.json, and a settings.json holding only permissions is then a
# correct and complete answer.
$existingSettings = [pscustomobject]@{}
# The reason, not a boolean: the notice below has to name WHICH shape it refused, or it sends a reader
# hunting for a syntax error in a file that parses perfectly.
$settingsRefusal = $null
if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
    $parsed = $null
    try {
        $rawSettings = [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8)
        if ($rawSettings.Trim().Length -gt 0) { $parsed = $rawSettings | ConvertFrom-Json }
    } catch { $settingsRefusal = 'does not parse as JSON' }

    if (-not $settingsRefusal -and $null -ne $parsed) {
        # A settings file is a JSON OBJECT. Anything else that happens to parse -- an array, a bare
        # number -- has no keys to preserve and cannot be merged into.
        if (-not ($parsed -is [System.Management.Automation.PSCustomObject])) {
            $settingsRefusal = 'parses, but is not a JSON object'
        } else {
            # AND THE SAME QUESTION ONE LEVEL DOWN. The merge replaces 'permissions' wholesale, so a
            # permissions key that is not an object -- a string, a list -- would be dropped by the very
            # file advertised as losing nothing. That is the defect this whole block exists to prevent,
            # arriving through the fix. Refuse instead, exactly as for a root that cannot be read.
            $permProp = @($parsed.PSObject.Properties | Where-Object { $_.Name -eq 'permissions' })
            if ($permProp.Count -gt 0 -and -not ($permProp[0].Value -is [System.Management.Automation.PSCustomObject])) {
                $settingsRefusal = "has a 'permissions' key that is not an object"
            } else {
                # AND ONE LEVEL DOWN AGAIN: allow/deny have to be lists of strings, because that is what
                # the merge concatenates onto. A null is fine and means 'no rules' -- absent and null are
                # the same statement, so folding one into the other loses nothing. Anything else is not:
                # an object or a number there would ride into the merged file as a rule that is not a
                # rule, and a permission list with one nonsense entry in it is worse than a refusal,
                # because it looks like it was reviewed.
                foreach ($half in @('allow', 'deny')) {
                    if ($settingsRefusal -or $permProp.Count -eq 0) { continue }
                    $existing = @($permProp[0].Value.PSObject.Properties | Where-Object { $_.Name -eq $half })
                    if ($existing.Count -eq 0 -or $null -eq $existing[0].Value) { continue }
                    if (@(@($existing[0].Value) | Where-Object { -not ($_ -is [string]) }).Count -gt 0) {
                        $settingsRefusal = "has a 'permissions.$half' that is not a list of rules"
                    }
                }
                if (-not $settingsRefusal) { $existingSettings = $parsed }
            }
        }
    }
}

if ($settingsRefusal) {
    # NO MERGED FILE ON A DESTINATION WE CANNOT ACCOUNT FOR, because composing one from a file we could
    # not fully read is the very data loss this whole block exists to prevent -- and it would arrive
    # wearing the label 'safe to paste'. The reader is told what to fix and still has the annotated
    # proposal, so nothing is taken away from them.
    Write-Host "  [notice] $settingsPath $settingsRefusal, so no merged proposal was written -- a merge built from a file that cannot be read whole would silently drop part of it. Repair that file and re-run, or copy from the annotated proposal by hand." -ForegroundColor Yellow
} else {
    # Every key the consumer already has, in the order they had it; then the two permission halves folded
    # into whatever 'permissions' they had (their own rules first, ours appended, no duplicates). Any
    # other permissions sub-key -- ask, defaultMode, additionalDirectories -- rides along untouched.
    $merged = [ordered]@{}
    foreach ($prop in $existingSettings.PSObject.Properties) { $merged[$prop.Name] = $prop.Value }

    $permOut = [ordered]@{}
    if ($merged.Contains('permissions') -and $merged['permissions'] -is [System.Management.Automation.PSCustomObject]) {
        foreach ($prop in $merged['permissions'].PSObject.Properties) { $permOut[$prop.Name] = $prop.Value }
    }
    foreach ($half in @(
        [pscustomobject]@{ Key = 'allow'; Rules = $allowRules },
        [pscustomobject]@{ Key = 'deny';  Rules = $denyRules }
    )) {
        # NOT '$have = if (...) { @($x) } else { @() }', which is what this was first written as and what
        # the fixture caught. An if-EXPRESSION returns its block through the output pipeline, and the
        # pipeline unrolls a one-element array to the bare element -- so a consumer with exactly ONE
        # existing allow rule got a String here, '+' then concatenated our rules onto it as text, and the
        # merged file shipped a single rule reading 'Bash(npm run build:*)Bash(powershell...'. Valid JSON,
        # silently permitting nothing. A plain assignment does not unroll, which is the whole fix.
        # The null test is not belt-and-braces: '"allow": null' means the KEY EXISTS, so Contains says
        # yes, and @($null) is an array holding one $null -- which would ship '"allow": [null, ...]'.
        # Null and absent are the same statement here, so both take the empty path.
        $have = @()
        if ($permOut.Contains($half.Key) -and $null -ne $permOut[$half.Key]) { $have = @($permOut[$half.Key]) }
        $add = @($half.Rules | Where-Object { $have -notcontains $_ })
        $permOut[$half.Key] = @($have + $add)
    }
    $merged['permissions'] = $permOut

    # ConvertTo-Json escapes the four HTML-sensitive characters (& < > ') as \uXXXX on Windows
    # PowerShell 5.1 -- valid JSON, but this file BECOMES the consumer's settings.json and they read and
    # edit it forever after, so a hook command reading 'a && b' should not arrive as an escape. Only code
    # points >= 0x20 are restored: below that, JSON requires the escape. Same treatment, and the same
    # reason, as publish-to-business.ps1 gives its generated manifest.
    #
    # -Compress, THEN INDENT OURSELVES. Windows PowerShell 5.1 pretty-prints JSON by aligning every value
    # to the column its key ends at, so a settings.json three levels deep arrives with values starting
    # past column 40 and a key rename re-flows the block. That is tolerable for a generated manifest
    # nobody opens; it is not what to hand somebody as the file they will edit for the life of the repo.
    # Compressing first means the indenter's input is canonical -- one line, no whitespace outside
    # strings -- so it has one job and no formatting of PowerShell's to second-guess.
    #
    # AND THE UN-ESCAPE COUNTS THE BACKSLASHES IN FRONT OF IT, which the obvious one-liner does not.
    # '\\u([0-9a-fA-F]{4})' matches the SECOND backslash of an escaped pair, so a consumer whose hook
    # command names a Windows path like C:\uadded\check.ps1 -- JSON '"C:\\uadded\\check.ps1"' -- has
    # '\uadde' folded into one character, leaving an invalid escape behind. Measured: the file no longer
    # parses, and it is still written and still announced as 'ready to replace settings.json'. That is
    # this whole feature's own failure mode arriving through its formatting step, which is why the run
    # of backslashes is counted rather than assumed: an EVEN run means every one of them is itself
    # escaped, so the 'u' after it is literal text and nothing here is an escape at all. Same reasoning
    # as Format-JsonIndented being a scanner rather than a regex, applied one line earlier.
    $proposedJson = ($merged | ConvertTo-Json -Depth 20 -Compress)
    $proposedJson = [regex]::Replace($proposedJson, '\\+u[0-9a-fA-F]{4}', {
        param($m)
        $text = $m.Value
        $slashes = $text.Substring(0, $text.Length - 5)
        if ($slashes.Length % 2 -eq 0) { return $text }
        $code = [int]('0x' + $text.Substring($text.Length - 4))
        if ($code -lt 0x20) { return $text }
        return $slashes.Substring(0, $slashes.Length - 1) + [string][char]$code
    })
    [System.IO.File]::WriteAllText($proposedPath, ((Format-JsonIndented -Json $proposedJson).TrimEnd("`r", "`n") + "`n"), $Utf8NoBom)
    $proposedWritten = $true

    # SAY WHICH CASE THIS IS, rather than promising preservation in a repo that had nothing to preserve.
    # 'your keys are kept' is reassuring and, on a repo whose enable sits in settings.local.json or the
    # user layer, simply not a statement about anything -- and a reader who trusts it stops checking.
    $carried = @($existingSettings.PSObject.Properties | ForEach-Object { $_.Name } | Where-Object { $_ -ne 'permissions' })
    $carriedNote = if ($carried.Count -gt 0) {
        "your settings.json plus the permissions -- it keeps $($carried -join ', ')"
    } else {
        'permissions only -- .claude/settings.json holds nothing else here, so there was nothing to carry over'
    }
    Write-Host "  [create] $proposedPath placed (merged, strict JSON, ready to replace settings.json: $carriedNote)." -ForegroundColor Green

    # THE MERGED FILE IS A COPY OF SETTINGS.JSON, SO IT INHERITS WHATEVER THAT FILE WAS HIDING. A repo
    # that gitignores '.claude/settings.json' by name -- the usual reason being an 'env' block with a
    # token in it -- has an ignore rule that does NOT match a new neighbouring path, so this run would
    # otherwise drop an untracked, un-ignored second copy of that secret into the tree and say nothing.
    # The bootstrap cannot know what is in there and must not guess, so it reports the fact rather than
    # the risk, and only in the one combination where the two files disagree.
    $proposedIgnored = Test-PathGitIgnored -Root $ConsumerRoot -Path $proposedPath
    if ((Test-PathGitIgnored -Root $ConsumerRoot -Path $settingsPath) -eq $true -and $proposedIgnored -eq $false) {
        Write-Host "  [notice] .claude/settings.json is gitignored here and the merged copy beside it is NOT -- it holds every key that file held. If it was ignored to keep something out of the repo, adopt the file and delete it before you commit, or extend the ignore rule to cover it." -ForegroundColor Yellow
    }
}

# --- Report ----------------------------------------------------------------------------------------
Write-Host ""
Write-Host "Done: $copied persona-lens(es) created, $kept already present; $scaffolded lens-scaffold(s) created, $lensKept already present; $scriptScaffolded script-scaffold(s) created, $scriptKept already present." -ForegroundColor Cyan
if ($notInstalledIds.Count -gt 0) {
    # Directly under the closing count, because that count is what this line qualifies (inbound #302).
    Write-Host "  [notice] $($notInstalledIds.Count) of the enabled plugin(s) have no install record for this path -- a session here loads none of them, so the lenses above are in place for a specialist surface this repo does not yet have. Run this from this root (Step 1 of INSTALL.md, act 4):" -ForegroundColor Yellow
    foreach ($id in ($notInstalledIds | Sort-Object -Unique)) {
        Write-Host "             claude plugin install $id --scope project" -ForegroundColor Yellow
    }
}
Write-Host "Next steps (manual -- script intentionally leaves settings.json/hooks untouched):" -ForegroundColor Cyan
Write-Host "  1. Fill '## Specific to this repo' slot in each $lensRelDisplay/*-extension.md with repo lens (VUL-IN scaffolds can stay empty until specialist has work here)." -ForegroundColor Gray
# THE MARKER IS LOAD-BEARING, SO SAY SO WHERE THE FILLING IS INSTRUCTED (inbound #451). Replacing the slot
# heading is what tells specialists-teardown the lens is authored; leaving a '(VUL-IN)' heading anywhere in
# a lens you HAVE filled makes that script read it as a disposable scaffold. This bootstrap no longer marks
# the title, but a lens scaffolded by an EARLIER version still carries one -- and that repo cannot be
# reached from here, so the instruction is the only route to it.
Write-Host "     Filling a lens means the '(VUL-IN)' goes: replace the slot heading with your own. On a" -ForegroundColor Gray
Write-Host "     lens scaffolded before this fix, remove it from the '... repo lens (VUL-IN)' TITLE as" -ForegroundColor Gray
Write-Host "     well -- specialists-teardown keys on that marker at any heading level, so one left on" -ForegroundColor Gray
Write-Host "     the title makes it list your written lens as removable." -ForegroundColor Gray
if ($seamMode) {
    Write-Host "  1b. Put this repo's roster, routing table and chains in $($seam.RelDir)/SPECIALISTS.md (the '## The roster (VUL-IN)' slot) -- NOT in CLAUDE.md, which keeps exactly one import line." -ForegroundColor Gray
}
if (-not $hasWorkflowPack) {
    # The honest step for a repo that did not take the pack: it has its own way of working, and nothing
    # here needs filling in. Naming the pack is not a nudge to enable it -- it is what makes the absence
    # of the branch/release scaffolds legible instead of looking like a gap.
    Write-Host "  2. Branches, PRs and releases run this repo's own way here -- the specialists use plain git/gh. The scripted workflow (new-branch / open-pr / ship-pr / cut-release) is a separate opt-in plugin, '$workflowPluginName'; enable it and re-run this only if you want THAT way of working." -ForegroundColor Gray
} elseif ($repoConfigDerived) {
    Write-Host "  2. Want to use the workflow skills (open-pr / fold-changelog)? RepoName already derived from git remote ($derivedRepo) -- fill Get-LintScript in scripts/repo-config.ps1 and branch prefix table in scripts/lib/branch-info.ps1." -ForegroundColor Gray
} else {
    Write-Host "  2. Want to use the workflow skills (open-pr / fold-changelog)? Fill scripts/repo-config.ps1 (RepoName + LintScript) and scripts/lib/branch-info.ps1 (branch prefix table) -- VUL-IN scaffolds ready." -ForegroundColor Gray
}
# THE REMINDER HAS TO COVER WHAT THE SENTENCE IT SITS IN NAMES. Step 3 now says "delete BOTH proposals",
# and this reading was taken for the .jsonc alone -- so where the two files fall on different sides of
# the ignore rules (a rule naming '.claude/settings.suggested.jsonc', or a '*.jsonc' pattern; both real
# shapes) the reader was told git would not remind them about a file git will in fact keep showing. So
# the two readings are combined, and they only claim a definite answer where they agree.
$bothIgnored = if ($null -eq $proposedIgnored) { $suggestIgnored }
               elseif ($suggestIgnored -eq $proposedIgnored) { $suggestIgnored }
               else { $null }   # they disagree -- neither claim is true of both, so make none
# '{0}' is the pronoun, because the two branches of step 3 delete a different NUMBER of files: the
# merged path deletes both, the refusal path deletes the one that got written.
$reminderTemplate = if ($bothIgnored -eq $true) { 'gitignored here, so git will not remind you' }
                    elseif ($bothIgnored -eq $false) { 'not gitignored here, so git status will keep showing {0} until you do' }
                    else { 'gitignored in many repos, so git may not remind you' }
# ONE ACT, NAMED AS ONE (inbound #1124). This line is the instruction a reader acts on, and for three
# rounds it said "copy desired parts" -- which is a hand-merge, against a destination the step never
# mentioned already held enabledPlugins and extraKnownMarketplaces. Each round added a caveat to it
# (#363 the hook stub, #1075 what the permissions block now does, #1097 the comments) and none of them
# made the file pasteable. Now there IS a pasteable file, so the step names the replacement first and
# keeps the caveats only for the reader who declines it.
if ($proposedWritten) {
    Write-Host "  3. Replace .claude/settings.json with $proposedPath -- one move, no merging. Then delete both proposals ($($reminderTemplate -f 'them'))." -ForegroundColor Gray
    Write-Host "     That file is your settings.json with the permissions already folded in: strict JSON," -ForegroundColor Gray
    Write-Host "     no comments to strip, no hooks stub, and every key you had is still in it. The" -ForegroundColor Gray
    Write-Host "     annotated $(Split-Path -Leaf $suggestPath) stays for WHY each rule is there." -ForegroundColor Gray
} else {
    Write-Host "  3. Copy desired parts from $suggestPath to settings.json and delete proposal ($($reminderTemplate -f 'it'))." -ForegroundColor Gray
    Write-Host "     No merged file was written this run -- see the [notice] above -- so this one IS a" -ForegroundColor Gray
    Write-Host "     hand-merge. Keep 'enabledPlugins' and 'extraKnownMarketplaces': they are already in" -ForegroundColor Gray
    Write-Host "     settings.json, they are what makes the plugins load, and the proposal does not" -ForegroundColor Gray
    Write-Host "     contain them. Overwrite the file with the proposal and you lose both silently." -ForegroundColor Gray
}
# AND SAY THAT THE COMMENTS CANNOT COME WITH IT (inbound #1097). The third caveat this one line has
# needed, and the same shape as the other two: "copy desired parts" is the instruction a reader acts
# on, and it named no exception. The proposal is .jsonc and its extension ANNOUNCES that comments are
# legal -- they are, in that file. settings.json is strict JSON, and this line is the only place that
# can carry the warning across the boundary it invites the reader over.
#
# WHY IT EARNS A LINE RATHER THAN A footnote: the failure is silent and TOTAL. Claude Code does not
# partially apply a settings file it cannot parse -- it ignores the whole file. So one carried-over
# comment switches off the deny half (git push --force, git reset --hard, rm -rf), the allow half,
# enabledPlugins and extraKnownMarketplaces together, and the only signal is a startup line naming a
# parse error rather than "your safety rules are off". Measured in the testrun-2 adoption,
# August 29, 2026: the copy was otherwise perfect -- no trailing comma, no structural error -- and the
# six comment lines were the entire defect. Inbound #335 established this same reader model for the
# QUICKSTART fragment ("the block is labelled jsonc, which suggests comments are fine"); its repair
# landed there and never reached the instruction that moves the file.
#
# IT SURVIVES #1124 UNCHANGED, and the scoping line in front of it is the whole edit. The merged file
# makes hand-copying optional, not impossible -- a reader who wants only the deny half still opens the
# .jsonc -- so removing this warning would re-open #1097 for exactly the reader who took the harder
# route. What it gains is a first clause saying WHEN it applies, so the reader who pasted the merged
# file is not left wondering which comments they were supposed to strip.
Write-Host "     Note, if you copy from the annotated file by hand instead:" -ForegroundColor Gray
Write-Host "     $(Split-Path -Leaf $suggestPath) is JSONC and settings.json is strict JSON --" -ForegroundColor Gray
Write-Host "     strip the '//' lines as you copy. A single one left in makes the WHOLE settings file" -ForegroundColor Gray
Write-Host "     unparseable, and Claude Code then ignores all of it: permissions, enabledPlugins and" -ForegroundColor Gray
Write-Host "     extraKnownMarketplaces alike, with one startup line about malformed JSON as the only" -ForegroundColor Gray
Write-Host "     warning. The same applies to settings.local.json." -ForegroundColor Gray
# THE CAVEAT BELONGS WHERE THE INVITATION IS (inbound #363). The proposal file says twice that its hooks
# are a stub, but this line -- "copy desired parts" -- is the instruction a reader actually acts on, and
# it named no exception. The permissions block is ready to use; the hook block points at a script no
# part of this family creates. A reader who copied both got a Stop hook firing at a missing file.
#
# AND SAY WHAT THE PERMISSIONS BLOCK NOW DOES (inbound #1075). "Ready to use as-is" was true and beside
# the point while the block had one half: copying it made the repo safer and no more usable, and the
# reader had no way to tell that from this line. So it names both halves and what the allow half covers.
Write-Host "     Note: the 'permissions' block is ready to use as-is -- it now has BOTH halves." -ForegroundColor Gray
if ($hasWorkflowPack) {
    Write-Host "     Its 'allow' half permits this workflow's own entry points (new-branch / open-pr /" -ForegroundColor Gray
    Write-Host "     ship-pr, plus 'gh repo edit --delete-branch-on-merge'); cut-release is deliberately" -ForegroundColor Gray
    Write-Host "     NOT in it. You are the only one who can widen a permissions file, so nothing in a" -ForegroundColor Gray
    Write-Host "     session can place these for you." -ForegroundColor Gray
} else {
    Write-Host "     Its 'allow' half is empty and says why: no workflow plugin is enabled here, so there" -ForegroundColor Gray
    Write-Host "     is no scripted entry point to permit." -ForegroundColor Gray
}
Write-Host "     The 'hooks' block is NOT ready -- its script path is a placeholder this bootstrap does" -ForegroundColor Gray
Write-Host "     not create. Point it at a real script in this repo or leave the block out." -ForegroundColor Gray
if ($proposedWritten) {
    # The merged file settles that question by leaving the stub out, which is worth one line: otherwise
    # the warning above reads as something the reader still has to act on after pasting, and the honest
    # answer is that they do not.
    Write-Host "     The merged file leaves it out entirely, so if you pasted that, this one is done." -ForegroundColor Gray
}
Write-Host "  4. Restart Claude Code session to activate new @-imports + config." -ForegroundColor Gray
Write-Host "  5. Register this repo in the workshop's connector register -- paste-ready block below." -ForegroundColor Gray

# --- Register proposal (workshop-side) -------------------------------------------------------------
# Why this block exists: bootstrapping a consumer used to leave NO trace towards the register, and
# nothing else fills that gap either. The register lives in the workshop
# (connectors/<repo>.json) while this script runs in the
# consumer, and the register's own doctrine is explicit that it never writes cross-repo -- so this
# script cannot create the manifest, only hand you one. Without it the workshop is blind to this repo:
# no plugin-version check, no lens-inventory check, no agent-def drift check. Found 2026-07-28, after a
# third consumer had been running (and filing inbound issues) unregistered for days without anyone
# noticing -- see also the [UNREGISTERED] signal that check-connectors now surfaces at session start.
#
# Proposal only, deliberately: 'visibility' and 'localCheckout' cannot be derived here (this script
# does not know where the workshop checkout sits relative to this repo, and guessing a path is exactly
# what the register's marker check exists to prevent), so they stay VUL-IN -- the repo's standard
# fill-in marker.
#
# THE ROW SET IS THE ENABLED PLUGINS, NOT THE LENS INVENTORY (inbound #1084). $registerInventory is
# filled only while walking each plugin's agents/ directory, so a plugin that ships skills, scripts
# and hooks and NO agents never entered it and could not reach this block -- and the workflow plugin
# is exactly that shape. A consumer pasting the proposal verbatim then registered a manifest with
# that row missing, which is not merely terse: check-connectors reports PER PLUGIN off this list, so
# the repo drops out of the version view for that plugin specifically, and the '[ERROR] machine
# record is on vX, source on vY' line that exists to catch a stale consumer cannot fire for it.
# Silently, because a row that is simply absent looks exactly like a plugin that is not enabled
# there. Every manifest already in connectors/ lists the workflow plugin, so the old proposal
# disagreed with the register it is a proposal for.
#
# An empty "extensions" array is a TRUE statement about a plugin that ships no lenses, and it is what
# the register's readers already handle: the row records that plugin's version without claiming a
# lens. The slug filter is the same one the lens loop applies, so a name that is not a plugin name
# cannot reach the manifest through this path either.
#
# AND THE ROWS ARE SCOPED TO THIS MARKETPLACE, which the old accident got right for the wrong reason.
# Get-PluginAgentsDir only ever looked beside this plugin's own root, so a plugin from ANOTHER
# marketplace could not enter the inventory either -- and widening the row set to "every enabled
# plugin" without this filter would have handed the consumer a manifest naming plugins this register
# knows nothing about. check-connectors classifies such a row as a well-formed name the marketplace
# no longer declares and reports "this consumer has not migrated to the current names yet", which
# would be a false statement about a plugin that was never this family's. Test-OurMarketplace makes
# that call once, up where the enabled ids are read, so this block and the per-plugin notice in the
# lens loop cannot answer it two different ways -- the drift this file already carries scars from.
Write-Host ""
Write-Host "-- connector register proposal (for the WORKSHOP repo, not this one)" -ForegroundColor Cyan
if (-not $ownMarketplace) {
    Write-Host "  [notice] this script's own plugin id is not in the settings chain, so the rows below could not be limited to one marketplace -- drop any plugin that is not part of this family before saving." -ForegroundColor Yellow
}
$registerPlugins = @($pluginNames | Sort-Object -Unique |
    Where-Object { $_ -match '^[a-z0-9][a-z0-9-]*$' } |
    Where-Object { Test-OurMarketplace $_ })
if ($registerPlugins.Count -eq 0) {
    Write-Host "  [notice] no enabled plugin of this marketplace was resolved -- nothing to register yet." -ForegroundColor Yellow
} else {
    $repoField = if ($derivedRepo) { $derivedRepo } else { 'VUL-IN/repo' }
    $leaf = Split-Path $ConsumerRoot -Leaf
    $pluginBlocks = @()
    foreach ($pn in $registerPlugins) {
        $fullId = if ($pluginIdByName.ContainsKey($pn)) { $pluginIdByName[$pn] } else { "$pn@VUL-IN" }
        $ids = if ($registerInventory.ContainsKey($pn)) {
            @($registerInventory[$pn] | Sort-Object) | ForEach-Object { '"' + $_ + '"' }
        } else { @() }
        $pluginBlocks += @"
    {
      "id": "$fullId",
      "extensions": [$($ids -join ', ')]
    }
"@
    }
    $manifest = @"
{
  "repo": "$repoField",
  "visibility": "VUL-IN (private|public)",
  "localCheckout": "VUL-IN (relative to the workshop root, e.g. ../$leaf)",
  "plugins": [
$($pluginBlocks -join ",`n")
  ],
  "notes": ""
}
"@
    foreach ($line in ($manifest -split "`r?`n")) { Write-Host "  $line" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "  Save as connectors/$leaf.json in the WORKSHOP repo," -ForegroundColor Gray
    Write-Host "  via that repo's normal branch + PR flow. Fill in the two VUL-IN fields first." -ForegroundColor Gray
    Write-Host "  Privacy boundary: the workshop is public -- metadata only, never lens content or absolute paths." -ForegroundColor Gray
}
exit 0