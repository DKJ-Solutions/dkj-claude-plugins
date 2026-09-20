<#
.SYNOPSIS
    Roster-sync check: detects when a consumer's repo roster and repo lenses lag behind the agents
    that the ENABLED plugins actually ship (LAYER 1 -- detection only, no fixes).

.DESCRIPTION
    When a plugin release adds a new specialist (e.g. Ravi 06-24), a consumer that updates the plugin
    gets no signal that its roster (a table/list in CLAUDE.md) and its repo lenses now lag behind.
    This script surfaces that drift by comparing three sources:

      (a) Specialists of the ENABLED plugins -- agents AND personas. Enabled plugins are read via
          Get-EnabledPlugins (check-report-lib.ps1) from the SAME settings chain Claude Code honors --
          the user ~/.claude/settings.json, .claude/settings.json and .claude/settings.local.json, per
          plugin id, local winning (enabledPlugins: a plugin id like 'specialists@dkj-claude-plugins'
          counts as enabled when its value is $true). Reading only .claude/settings.json is what made
          this check answer "roster in sync" for a repo with no roster at all (inbound #294): the enable
          lived in settings.local.json, so the check saw nothing enabled, the [BOOTSTRAP] branch could
          not fire, and an exit-0 run with no findings reads as health. For each enabled plugin
          the versioned dir is resolved in the local plugin cache (semantically highest version,
          [version]-sort -- the same approach bootstrap.ps1 uses so 1.10.0 beats 1.9.0). Agent ids
          ('<group>-<id>', e.g. 06-24) come from <plugin-dir>/agents/<g>-<id>-agent.md, persona ids
          from <plugin-dir>/personas/<g>-<id>-persona.md (inbound #204 -- see the persona note below).
      (b) The consumer's roster. Its path comes from Get-RosterPath in scripts/repo-config.ps1
          (repo-root-relative; the bootstrap scaffolds it to the seam inclusion
          .claude/specialists/SPECIALISTS.md, which is where specialists-init writes the roster slot --
          it used to scaffold 'CLAUDE.md' and that made this check read a file holding only the
          @-import, inbound #333). 'CLAUDE.md' remains the fallback when repo-config is absent
          entirely. "Present in the roster" is decided by scanning the
          roster text for each '<group>-<id>' token (format-agnostic -- works for a table OR a list;
          deliberately NOT a brittle table parser).
      (c) The lens files, looked up via Get-LensDirCandidates (check-report-lib.ps1 -- the same source
          the writers use, issues #179 and #221): the canonical seam
          .claude/specialists/lenses/<g>-<id>-extension.md, the pre-seam
          .claude/plugins/claude-specialists/<plugin>/ path that is still written for a consumer with a
          tree there, a non-canonical family segment left behind by a pre-#179 bootstrap, and the
          legacy .claude/extensions/<g>-<id>-extension.md.

    Findings + severity (same [OK]/[INFO]/[ERROR] convention as check-connectors.ps1):
      - an '@'-import in the roster file that does NOT resolve -> [ERROR] (inbound #414). The roster is
                                                 repo-local and always loads; the orchestrator's BODY is
                                                 the only part that comes from outside it, through one
                                                 import. A wrong path there fails SILENTLY -- the session
                                                 starts, the roster renders, the persona table is intact,
                                                 and the orchestrator runs with none of his ritual or
                                                 delegation rules. It happened for real when the
                                                 marketplace was renamed on August 3, 2026: every
                                                 consumer's body import broke at once and the only signal
                                                 available was noticing that the orchestrator sounded
                                                 generic. This is the one file in the system whose
                                                 absence nothing reported.
      - agent/persona WITHOUT a roster row -> [ERROR] (the core case this feature exists for: a new
                                                 specialist that is invisible in the governance doc).
      - agent/persona WITHOUT a lens file  -> [ERROR] (actionable drift for a real specialist: no
                                                 landing spot for its repo-specific context).
      - orphan (a roster token OR a lens file whose '<group>-<id>' has NO matching agent AND no
        matching persona in any enabled plugin) -> [INFO] (could be a just-removed specialist; also
        soft because personas are counted as backing, see below), PLUS one [ORPHANS] roll-up line
        stating the count. That roll-up is non-counting (like [OK]) and exists so the orphan trail is
        not silent at session start: the hook suppresses [INFO] but does surface [ORPHANS], so the
        finding reaches a session without turning a legitimate transition red (inbound #204).
      - lens on a NON-CANONICAL family segment -> [INFO] (issue #179): a pre-fix bootstrap derived the
                                                 family from the install path and so wrote the lenses
                                                 under the marketplace name. The lens works and counts
                                                 as present; the line only points at the misalignment
                                                 (reported once per directory, not once per lens). The
                                                 two locations current writers actually use -- the seam
                                                 and the pre-seam plugin path -- are NOT reported; see
                                                 Get-OnPathLensDirs.
      - lens header still naming a STALE persona name -> [INFO] (issue #145): an older scaffold baked
        the first name into the lens header ("# Sean <midDot> repo-lens"); after a rename that name is
        stale, but the lens is present, so it is a cosmetic mismatch, not missing-lens drift. Soft on
        purpose (silent at session start); the sync-roster skill stages a paste-ready reconcile.
      - a missing LENS whose id IS named by a markdown file in the lens directory that this check does
        not recognise as a lens -> HELD, and rolled up into one non-counting [LENS-NAMING] line (issue
        #2219). The readers here resolve two spellings and never three (Get-SpecialistFileShapes), which
        covers a consumer meeting a rename through a plugin update and cannot look FORWARD -- and a
        session loads the last RELEASED payload, so a rename in the source leaves every not-yet-updated
        session with no vocabulary for the tree in front of it. Measured September 20, 2026: 30 such
        lines out of a v5.5.0 payload against a tree on the #2135 lens naming, every one of them
        prescribing that the reader create a file already sitting there under another name. Not an error,
        because the repo is correct and no edit to it can help; never silent, because "every specialist
        lost its lens" must not read as drift. The evidence is per id, so a specialist that is genuinely
        lens-less keeps erroring. See Get-UnknownLensNameById -- including why the missing-ROSTER-ROW
        half of that same wall is not held here (#2130 already repaired it).
      - plugin ENABLED but with no install record for this path -> one [NOT-INSTALLED-HERE] roll-up
        (non-counting, like [ORPHANS]) plus a non-counting detail line per plugin naming the enabling
        layer and the administration consulted (inbound #302). Enabling is only half
        of what Claude Code needs; without a record in ~/.claude/plugins/installed_plugins.json for THIS
        projectPath a session loads none of that plugin -- no skills, no subagents, no hooks -- and every
        drift line this check prints about it then describes a surface the repo does not have. Measured:
        27 [ERROR] lines about a session that had loaded zero specialists. Not an error, because the repo
        is not broken and the state is usually one install command away from intended; never silent,
        because "no hooks because the plugin is not loaded" reads exactly like "no hooks because all is
        well". See Get-InstallRecord in check-report-lib.ps1.
      - plugin enabled AND recorded for this path, but the record is not the shape the documents assume
        (exactly one, scoped 'project') -> one [RECORD-SHAPE] roll-up (non-counting) plus a non-counting
        detail line per plugin naming the shape and its remedy (inbound #314/#315). The roll-up counts
        only the plugins THIS REPO's own settings enable (issue #1138); the detail lines fire for every
        shape regardless, since they are what carry the remedy. Two measured shapes: a
        record scoped 'local', which is what a SESSION START leaves behind, and more than one record for
        one path, which the prescribed repair install produces. Round v8 established why this marker is
        needed at all: the session start CREATES a missing record before any hook can look, so
        [NOT-INSTALLED-HERE] heals itself out of existence and the state a consumer is actually left in --
        a wrongly shaped record -- was reported by nothing. Not an error: the plugin loads from a 'local'
        record just as well, and neither shape can indicate tampering (the CLI writes both). See
        Get-RecordShape in check-report-lib.ps1.

    Personas: main-loop specialists (Chris 01-01, Derek 05-05, Rendall 05-06, ...) ship as
    <plugin>/personas/<g>-<id>-persona.md, NOT as agents, yet legitimately have a roster row and a
    lens. They count as "backing" so they are never flagged as orphans -- and, since inbound #204,
    they are ALSO checked for a missing roster row / missing lens, exactly like agents. Those used to
    be one decision; they are two, and only the first followed from the reasoning. "A persona is not an
    orphan" is right. "A persona can therefore never be missing" does not follow: measured in life-hub,
    the check validated 20 specialists where that repo's own duplicate compared 24 -- the gap being
    precisely the persona-only specialists, so the roster could lose Chris's row and stay green.
    The ONE persona exception left is the lens-header drift check (see Get-CheckedSpecialists and the
    header-drift block), which needs a `name:` field personas do not have.

    Consequence worth knowing when adopting this: a persona a consumer deliberately does NOT roster is
    now real drift. That is what the Get-RosterIgnoredIds ignore-list is for -- record the choice there
    (this workshop does so for Bianca 03-02), rather than relying on the check being blind to it.

    What to DO with an [ERROR] from this check (Dave, July 28, 2026): adopt. A specialist that arrives
    with a plugin update is adopted by default -- no approval question, and no per-specialist "which of
    these do you want?". The sync-roster skill stages it; its SKILL.md carries the full reasoning. The
    scaffold is empty on purpose and may stay empty until that specialist has work here, so adopting
    costs nothing that has to be filled in today. The ignore-list above is the deliberate exception you
    write on your own initiative, not the answer to a question this check asks.

    Exit-code: 0 = no errors (INFO does not count), 1 = at least one error.

.PARAMETER ConsumerPathOverride
    (Optional, for tests) Use this path as the consumer repo root instead of the dual-context default.

.PARAMETER CacheRootOverride
    (Optional, for tests) Use this dir as the plugin cache root instead of
    $env:USERPROFILE/.claude/plugins/cache -- lets a fixture supply a controlled agent set / versions.

.PARAMETER UserHomeOverride
    (Optional, for tests) Use this dir as the user home when resolving the user layer of the settings
    chain (~/.claude/settings.json), instead of $env:USERPROFILE -- lets a fixture exercise the chain
    without touching the real machine's user settings. Scoped to the SETTINGS CHAIN only: the install
    administration (inbound #302) is a different file answering a different question and is read via
    $env:USERPROFILE, so a fixture that wants to control it redirects that env var for the child process
    -- the pattern the connector version test already uses.

.EXAMPLE
    .\scripts\sync\check-roster-sync.ps1
#>
[CmdletBinding()]
param(
    [string]$ConsumerPathOverride = '',
    [string]$CacheRootOverride = '',
    [string]$UserHomeOverride = ''
)

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:errors = 0
$script:infos  = 0

# Middle dot used in the scaffold-lineage lens header; kept as a code point so this file stays ASCII.
$midDot = [char]0x00B7

# Write-Ok/Write-Info/Write-Failure + Test-PluginNameSlug/Test-PluginMarketplaceSlug + Resolve-PluginDir
# + Resolve-CheckRoot/Write-CheckScope: shared with check-connectors.ps1 and
# skills/sync-roster/sync-roster.ps1 (single source, issue #114). This script is a whole-file mirror
# (scripts/lib/shared-scripts-lib.ps1); check-report-lib.ps1 is registered in that same pair set and
# therefore travels along, so a $PSScriptRoot-relative dot-source (not $repoRoot -- this lib is not
# repo-owned, unlike repo-config.ps1/branch-info.ps1) resolves correctly whether this file runs from
# the workshop root or the plugin mirror. Dot-sourced BEFORE the repo-root resolution below, which
# now comes from that same shared lib.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')

# Repo-root -- dual-context via the shared Resolve-CheckRoot: a consumer running the plugin mirror
# gets its repo-root from CLAUDE_PROJECT_DIR; in the workshop-root (or outside a session) it falls
# back to the git-root. This keeps the root-copy and the plugin-mirror byte-identical (guarded by the
# shared-scripts drift-lint). -ConsumerPathOverride wins so a fixture can point the check at a
# throwaway consumer. The returned Source/Note travel into the [SCOPE] line further down, so a
# finding surfaced by the session hook always names the repo it is about (inbound #203).
$scope = Resolve-CheckRoot -Override $ConsumerPathOverride
if (-not $scope.Path) {
    Write-Host '== check-roster-sync ==' -ForegroundColor Cyan
    Write-Failure "no repo root could be resolved ($($scope.Note)) -- nothing was checked."
    Write-CheckSummary
}
$repoRoot = $scope.Path

# Plugin cache root (overridable for tests).
$cacheRoot = if ($CacheRootOverride) { $CacheRootOverride } else { Join-Path $env:USERPROFILE '.claude\plugins\cache' }

# Agent ids ('<group>-<id>') a plugin ships (source a).
function Get-AgentIds {
    param([string]$PluginDir)
    $dir = Get-SubagentDirPath -PluginDir $PluginDir
    if (-not $dir) { return @() }
    # BOTH SPELLINGS (#2130), and this reader is the reason the dual-name layer is not optional: it runs
    # against a CONSUMER'S plugin cache, which holds whatever version that machine last installed. A
    # reader that knew only one spelling would report a plugin as shipping no subagents at all -- the one
    # answer that is false in both directions, exactly as Get-SubagentDirName's docstring says of the
    # directory leaf one level up.
    return @(Get-SpecialistFiles -Path $dir -Kind Subagent |
        ForEach-Object { Get-SpecialistFileId -Kind Subagent -Name $_.Name } |
        Where-Object { $_ } |
        Sort-Object -Unique)
}

# Persona ids ('<group>-<id>') a plugin ships (source a', alongside the agents).
function Get-PersonaIds {
    param([string]$PluginDir)
    $dir = Join-Path $PluginDir 'personas'
    # No Test-Path guard needed any more: Get-SpecialistFiles treats a missing directory as an empty
    # answer, which is what the guard said.
    return @(Get-SpecialistFiles -Path $dir -Kind Persona |
        ForEach-Object { Get-SpecialistFileId -Kind Persona -Name $_.Name } |
        Where-Object { $_ } |
        Sort-Object -Unique)
}

# Ids that BACK a roster token / lens: agents + personas. Personas run in the main loop (not as
# subagents) but are real specialists with roster rows + lenses, so counting them prevents false orphans.
function Get-BackingIds {
    param([string]$PluginDir)
    return @(@(Get-AgentIds -PluginDir $PluginDir) + @(Get-PersonaIds -PluginDir $PluginDir) | Sort-Object -Unique)
}

# The specialists whose roster row + lens this check REQUIRES: agents and personas alike, each tagged
# with its kind so a finding can name what it is about.
#
# Why personas belong here (inbound #204): the old exclusion bundled two decisions into one, and only
# the first followed from the reasoning. "A persona is not an orphan" is right -- Get-BackingIds above
# keeps that intact. "A persona can therefore never be MISSING" does not follow: a persona is a real
# specialist with a roster row and a lens, exactly like an agent, and when the row or the lens is gone
# that is actionable drift of precisely the kind this check exists for. Measured in life-hub: the check
# validated 20 specialists where the repo's own duplicate compared 24 -- the gap being exactly the
# persona-only main-loop specialists. The roster could lose Chris's or Derek's row and stay green.
#
# An id that is BOTH an agent and a persona counts as an agent: the agent file is the one with a
# `name:` to compare a lens header against, so that kind carries strictly more checking.
function Get-CheckedSpecialists {
    param([string]$PluginDir)
    $agentIds = @(Get-AgentIds -PluginDir $PluginDir)
    $records = @($agentIds | ForEach-Object { [pscustomobject]@{ Id = $_; Kind = 'agent' } })
    # NOT $pid -- that is a PowerShell automatic variable (the process id); shadowing it in a loop is
    # the kind of quiet breakage that surfaces somewhere else entirely.
    foreach ($personaId in (Get-PersonaIds -PluginDir $PluginDir)) {
        if ($agentIds -contains $personaId) { continue }
        $records += [pscustomobject]@{ Id = $personaId; Kind = 'persona' }
    }
    return @($records | Sort-Object Id)
}

# "Present in the roster": scan the roster text for the literal '<group>-<id>' token, bounded so
# '06-24' still matches inside '06-24-extension.md' but NOT inside '106-240' or an ISO date like
# '2026-07-25'. The boundary itself is Get-RosterIdTokenPattern's (check-report-lib.ps1) single
# source, shared with the orphan-scan below -- issue #182. Format-agnostic on purpose (table or
# list) -- see the Get-RosterPath note in repo-config.ps1.
function Test-InRoster {
    param([string]$RosterText, [string]$Id)
    return ($RosterText -match (Get-RosterIdTokenPattern -Id $Id))
}

# The lens path for '<group>-<id>': the first of Get-LensDirCandidates that actually holds the file --
# the canonical plugin-path, a non-canonical family segment left by a pre-#179 bootstrap, or the legacy
# extensions-path; $null when none does. The candidate list is the shared source the writers
# (bootstrap.ps1, sync-roster.ps1) derive their target path from, so reader and writer cannot drift.
function Get-LensPath {
    param([string]$RepoRoot, [string]$PluginName, [string]$Id)
    # Two candidate axes now, and the order is deliberate: every NAME is tried inside a directory before
    # moving to the next directory (#2130). A consumer mid-migration can hold both spellings in different
    # directories, and answering with the canonical directory's file -- whatever it is called -- is the
    # same preference this list has always expressed, one axis wider.
    $names = @(Get-SpecialistFileNameCandidates -Kind Lens -Id $Id)
    foreach ($d in (Get-LensDirCandidates -RepoRoot $RepoRoot -PluginName $PluginName)) {
        foreach ($n in $names) {
            $c = Join-Path $d $n
            if (Test-Path -LiteralPath $c -PathType Leaf) { return $c }
        }
    }
    return $null
}

# A lens for '<group>-<id>' exists at any of the candidate locations.
function Test-LensExists {
    param([string]$RepoRoot, [string]$PluginName, [string]$Id)
    return [bool](Get-LensPath -RepoRoot $RepoRoot -PluginName $PluginName -Id $Id)
}

# Markdown files in this plugin's lens directories that this check does NOT recognise as a lens, mapped
# to the specialist id their name carries -- the measurable trace of a lens naming generation NEWER than
# the payload running this check.
#
# WHY IT EXISTS (issue #2219). Every reader here resolves two spellings and never three:
# Get-SpecialistFileShapes holds the one a writer writes plus the one before it, deliberately, so a
# consumer meeting a rename through a plugin update keeps resolving its own files. What that layer cannot
# do is look FORWARD. A session loads an extracted payload frozen at the last RELEASE, so the moment the
# source renames the lens files again, every session still on the previous release meets a tree it has no
# vocabulary for -- and this check then reports every single specialist as lens-less, each line
# prescribing that the reader create a file that is already sitting there under another name.
#
# Measured in this repo on September 20, 2026: 34 error lines out of a payload at v5.5.0 against a tree
# that had moved to 'specialist-<g>-<id>-lens.md' (#2135). Thirty said "no repo-lens" about a specialist
# whose lens was on disk, and those thirty are what this function holds: acting on them would have added
# a second, obsolete generation beside the one already there -- thirty wrong repairs, each carrying a
# citation. The other four said "no roster row" about a persona whose only roster token sits inside such
# a filename, and they are NOT this function's subject, because #2130 had already repaired that half --
# it replaced the token boundary '(?<![\d-])', which rejected every id preceded by a hyphen, with
# '(?<!\d)(?<!\d-)'. Verified against the same tree on the same day: the cached payload reports 34 and
# the current one reports 0, with the four going away alongside the thirty.
#
# THE EVIDENCE IS PER ID, not a global verdict, and that is what keeps a genuinely missing lens visible:
# a specialist that arrived with a plugin update has nothing in the lens directory naming it, so nothing
# is held for it and its finding prints exactly as before. That also covers the mixed state a migration
# passes through, where some lenses carry the new spelling and some the old. The id is matched with the
# shared Get-RosterIdTokenPattern rather than a substring test, so '106-240' cannot pass for '06-24'.
#
# It reads names only -- no content, no network, no version comparison. A version comparison was the
# obvious alternative and is the wrong instrument: the check cannot learn what the SOURCE currently holds
# without reaching for a clone it does not own, and the clone is a different channel from the payload
# that is running (the one the report behind this conflated them).
# TWO GUARDS NARROW WHAT COUNTS AS EVIDENCE, and they are the load-bearing half: this predicate REPLACES
# an error with a soft advisory, so a file wrongly admitted here downgrades a genuine "this specialist has
# no lens" to a yellow line saying nothing needs changing -- the exact inversion of what the marker is for.
#   (a) A file recognised as a specialist file of ANOTHER kind is not evidence. A manual or a persona that
#       has been dropped in the lens directory by hand is a misplaced file of a known generation, not a
#       trace of an unknown one, and 'specialist-<g>-<id>-manual.md' would otherwise back that id.
#   (b) The name must be the SHAPE a specialist filename has always had -- the id with nothing but letters
#       and hyphens around it. That excludes a scratch note ('06-24 notes.md'), a dated file
#       ('2026-06-24-meeting.md') and a suffixed backup, none of which says anything about a naming
#       generation. The id itself is still recognised through the shared Get-RosterIdTokenPattern rather
#       than a second spelling; the anchor around it is what tightens the answer.
# The cost is stated rather than hidden: a future generation that puts something other than letters and
# hyphens around the id is not recognised, and the old wall returns for it. That is the safe direction to
# err in -- too tight restores a known, visible defect, too loose hides a finding nobody sees at all.
#
# THE PER-DIRECTORY ANSWER IS CACHED because the seam lens dir is plugin-INDEPENDENT (one directory holds
# every enabled plugin's lenses) while this runs once per plugin: without the cache a repo enabling six
# plugins walks that one directory six times and re-probes every file in it each time.
$script:unknownLensDirCache = @{}
function Get-UnknownLensNameById {
    param([string]$RepoRoot, [string]$PluginName, [string[]]$Ids)
    $map = @{}
    if (@($Ids).Count -eq 0) { return $map }
    foreach ($d in (Get-LensDirCandidates -RepoRoot $RepoRoot -PluginName $PluginName)) {
        if (-not $script:unknownLensDirCache.ContainsKey($d)) {
            $names = @()
            if (Test-Path -LiteralPath $d -PathType Container) {
                foreach ($f in @(Get-ChildItem -LiteralPath $d -Filter '*.md' -File -ErrorAction SilentlyContinue)) {
                    # A spelling this check DOES know is no evidence of anything: Get-LensPath has already
                    # answered for it, and a recognised file that backs no checked id is an orphan, which
                    # is a different finding with its own marker.
                    if (Get-SpecialistFileId -Kind Lens -Name $f.Name) { continue }
                    # Guard (a).
                    $otherKind = $false
                    foreach ($k in @('Manual', 'Persona', 'Subagent')) {
                        if (Get-SpecialistFileId -Kind $k -Name $f.Name) { $otherKind = $true; break }
                    }
                    if ($otherKind) { continue }
                    $names += $f.Name
                }
            }
            $script:unknownLensDirCache[$d] = @($names)
        }
        foreach ($n in $script:unknownLensDirCache[$d]) {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($n)
            foreach ($id in $Ids) {
                if ($map.ContainsKey($id)) { continue }
                # Guard (b). '-match' is case-insensitive, so '[a-z-]' covers a capitalised spelling too.
                if ($base -match ('^[a-z-]*' + (Get-RosterIdTokenPattern -Id $id) + '[a-z-]*$')) { $map[$id] = $n }
            }
        }
    }
    return $map
}

# The directories a lens may live in WITHOUT being off-path -- what the writers actually produce today,
# canonical first. Candidates 0 and 1 of Get-LensDirCandidates: the seam .claude/specialists/lenses/
# (issue #221, where a FRESH consumer's lenses land) and the pre-seam .claude/plugins/<family>/<plugin>/
# path (where Get-LensWriteDir still writes for a consumer that already has a tree there). Neither is a
# misalignment, so neither belongs in the off-path report.
#
# This function used to be Get-CanonicalLensDir and returned ONLY the pre-seam path, hardcoded -- while
# the shared source (Get-LensDirCandidates/Get-SeamPaths in check-report-lib.ps1) had already named the
# seam canonical. A repo that migrated onto the seam therefore had every one of its OWN lenses reported
# as living somewhere non-canonical, with the remedy pointing back at the layout it had just left: a
# reader following that advice would undo the migration. Derive both from the shared source, so the
# reader cannot drift from the writers again the way it did here.
function Get-OnPathLensDirs {
    param([string]$RepoRoot, [string]$PluginName)
    return @(
        (Get-SeamPaths -RepoRoot $RepoRoot).LensDir,
        (Join-Path (Join-Path (Join-Path $RepoRoot '.claude\plugins') (Get-LensFamily)) $PluginName)
    )
}

# A path rendered relative to the repo root, for display in a finding. Used for BOTH sides of the
# off-path report's "X instead of Y" sentence, so the canonical target it names is the same value the
# comparison actually used rather than a literal repeated in the message.
function Get-RelativeToRoot {
    param([string]$RepoRoot, [string]$Path)
    if ($Path.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($RepoRoot.Length).TrimStart('\', '/')
    }
    return $Path
}

# The agent's display name from its cache-file frontmatter (best-effort; '' when absent). Only the
# `name:` line is needed here -- lighter than sync-roster's Get-AgentInfo, which also reads the desc.
function Get-AgentName {
    param([string]$PluginDir, [string]$Id)
    $subDir = Get-SubagentDirPath -PluginDir $PluginDir
    if (-not $subDir) { return '' }
    $p = ''
    foreach ($n in (Get-SpecialistFileNameCandidates -Kind Subagent -Id $Id)) {
        $c = Join-Path $subDir $n
        if (Test-Path -LiteralPath $c -PathType Leaf) { $p = $c; break }
    }
    if (-not $p) { return '' }
    foreach ($ln in (Get-Content -LiteralPath $p -TotalCount 15)) {
        if ($ln -match '^name:\s*(.+?)\s*$') { return $Matches[1].Trim() }
    }
    return ''
}

# The leading name token of a scaffold-lineage lens header "# <Name> <midDot> repo[- ]lens" (both the
# sync-roster and specialists-init generators write that shape). Returns '' when the first heading is
# NOT that shape -- so a hand-customized header (no "<midDot> repo-lens" tail) is never touched, and
# the new nameless scaffold "# <g>-<id> <midDot> repo-lens" returns the '<g>-<id>' token (which the
# caller treats as up-to-date, not drift). $MidDot is passed in so this file stays pure ASCII.
function Get-ScaffoldHeaderName {
    param([string]$LensPath, [string]$MidDot)
    if (-not $LensPath) { return '' }
    $rx = [regex]("^#\s+(?<nm>[^\s#" + [regex]::Escape($MidDot) + "]+)\s+" + [regex]::Escape($MidDot) + "\s+repo[- ]lens")
    foreach ($ln in (Get-Content -LiteralPath $LensPath -TotalCount 30 -Encoding UTF8)) {
        $m = $rx.Match($ln)
        if ($m.Success) { return $m.Groups['nm'].Value }
        if ($ln -match '^#\s') { return '' }
    }
    return ''
}

# All lens ids present in the consumer (every candidate dir for each enabled plugin + the legacy path),
# mapped to a display path -- used to surface lens files that back no agent (orphans).
function Get-LensIds {
    param([string]$RepoRoot, [string[]]$PluginNames)
    $dirs = @()
    foreach ($pn in $PluginNames) { $dirs += @(Get-LensDirCandidates -RepoRoot $RepoRoot -PluginName $pn) }
    # -Unique: the legacy .claude/extensions dir is a candidate for every plugin, so with two enabled
    # plugins it would otherwise be walked twice.
    $dirs = @($dirs | Sort-Object -Unique)
    $result = @{}
    foreach ($d in $dirs) {
        foreach ($f in (Get-SpecialistFiles -Path $d -Kind Lens)) {
            $id = Get-SpecialistFileId -Kind Lens -Name $f.Name
            if (-not $id) { continue }
            if (-not $result.ContainsKey($id)) { $result[$id] = $f.FullName }
        }
    }
    return $result
}

# The '@'-import lines in a markdown file, in order. Deliberately NARROW: the whole line must be an '@'
# followed by a path ending in .md, and nothing else. Two things that shape must not swallow -- the
# roster's own prose says a specialist can be invoked as '@specialists:<name>', and a fenced block may
# quote an example import. The first is excluded by requiring a '.md' tail, the second by tracking fences.
#
# Deliberately NOT the same pattern as the '^\s*@' strip further down, which is looser on purpose:
# stripping one line too many from the roster TEXT costs at worst a false orphan, while CHECKING one line
# too many would raise an error about a line nobody wrote as an import.
function Get-MarkdownImports {
    param([string]$Text)
    $found = @()
    $inFence = $false
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        $m = [regex]::Match($line, '^\s*@(?<p>[^\s`]+\.md)\s*$')
        if ($m.Success) { $found += $m.Groups['p'].Value }
    }
    return @($found)
}

# Where an '@'-import points, resolved the way Claude Code resolves it: '~' is the user home, an absolute
# path is taken as-is, and anything else is relative to the file the import is written in.
#
# $env:USERPROFILE rather than -UserHomeOverride: that parameter is documented as scoped to the SETTINGS
# CHAIN, and widening it here would make one flag mean two things in one script. A fixture that needs to
# control this redirects the env var for the child process -- the pattern the connector version test
# already uses, and the same split this file already applies to the install administration.
function Resolve-ImportTarget {
    param([string]$Import, [string]$BaseDir)
    $p = $Import -replace '/', '\'
    if ($p -match '^~\\') {
        $userHome = $env:USERPROFILE
        if (-not $userHome) { $userHome = $env:HOME }
        if (-not $userHome) { return $null }
        return (Join-Path $userHome $p.Substring(2))
    }
    if ([System.IO.Path]::IsPathRooted($p)) { return $p }
    return (Join-Path $BaseDir $p)
}

Write-Host '== check-roster-sync ==' -ForegroundColor Cyan
Write-CheckScope -Scope $scope -CheckName 'check-roster-sync'

# Roster path from repo-config's Get-RosterPath (default 'CLAUDE.md'). repo-config is repo-specific and
# lives in the consumer repo-root; if it is absent we fall back to the default (this check has a sane
# default and does not hard-require repo-config, unlike open-pr/fold).
$rosterRel = 'CLAUDE.md'
$ignoredIds = @()
$configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    # Dot-source + call the consumer's repo-config in a CHILD scope with StrictMode explicitly OFF --
    # sibling of the check-script-contract.ps1 fix: the real runtime callers of repo-config.ps1
    # (open-pr.ps1, fold-changelog-entry.ps1, ...) never enable StrictMode, and repo-config.ps1 is
    # explicitly documented as written on that no-strict-mode assumption (harmless loose top-level
    # code is expected there). Probing inside the same block keeps the dot-sourced functions visible
    # to Get-Command while nothing leaks into this script's own strict scope. A genuine failure (a
    # real syntax error, not just strict-mode noise) falls back to the sane defaults below rather than
    # crashing this whole check -- this check does not hard-require repo-config.
    $probe = & {
        Set-StrictMode -Off
        $result = [pscustomobject]@{ Loaded = $true; Error = $null; RosterPath = $null; IgnoredIds = $null }
        try {
            . $args[0]
        } catch {
            $result.Loaded = $false
            $result.Error = $_.Exception.Message
            return $result
        }
        if (Test-FunctionDefined 'Get-RosterPath') { $result.RosterPath = Get-RosterPath }
        if (Test-FunctionDefined 'Get-RosterIgnoredIds') { $result.IgnoredIds = @(Get-RosterIgnoredIds) }
        return $result
    } $configPath

    if ($probe.Loaded) {
        if ($null -ne $probe.RosterPath) { $rosterRel = $probe.RosterPath }
        # Ids that are enabled but deliberately kept out of the roster/lenses (a documented repo choice);
        # they are skipped rather than flagged as drift. Empty on a fresh consumer.
        if ($null -ne $probe.IgnoredIds) { $ignoredIds = @($probe.IgnoredIds) }
    } else {
        Write-Info "scripts\repo-config.ps1 failed to load ($($probe.Error)) -- falling back to defaults (roster '$rosterRel', no ignored ids)."
    }
}
$rosterPath = Join-Path $repoRoot $rosterRel
if (Test-Path -LiteralPath $rosterPath -PathType Leaf) {
    $rosterText = [System.IO.File]::ReadAllText($rosterPath, [System.Text.Encoding]::UTF8)
} else {
    $rosterText = ''
    Write-Info "roster file '$rosterRel' not found in the repo-root -- treated as empty."
}

# --- Does every '@'-import in the roster file actually resolve? (inbound #414) --------------------
# THE ONE FILE IN THIS SYSTEM WHOSE ABSENCE NOTHING REPORTS, until now.
#
# The roster is a repo-local file, so it always loads. The orchestrator's BODY is the only part that
# comes from outside it, through a single '@'-import. If that path is wrong the session still starts,
# the roster still renders, the persona table is still there -- and the orchestrator runs without his
# ritual, without his delegation discipline, and without the rule that nothing happens anonymously.
# Claude Code reports nothing, because an unresolvable import fails silently.
#
# It has already happened once. The August 3, 2026 marketplace rename broke the body import in every
# consumer at once, and the only available signal was somebody noticing that the orchestrator was
# behaving generically -- a judgement call about tone, made against a persona nobody had in front of
# them. The repair was by hand, per repo.
#
# So this is checked BEFORE the strip below, which needs the raw text: the strip exists because the
# import path CONTAINS an id token ('01-01') and was satisfying the roster test on its own (#227) --
# the same line, read for two different reasons, and both of them silent when it is wrong.
#
# [ERROR] rather than [INFO], deliberately, and it stays an error even when the cause is "the plugin is
# not installed on this machine": that is not a false positive, it is precisely the state in which this
# session's orchestrator has no body. What the finding must not do is leave the reader guessing which of
# the plausible causes applies, so it names them.
$seamImports = @(Get-MarkdownImports -Text $rosterText)
if ($seamImports.Count -gt 0) {
    Write-Host "`n-- imports in $rosterRel" -ForegroundColor Cyan
    $rosterDir = Split-Path -Parent $rosterPath
    foreach ($imp in $seamImports) {
        $target = Resolve-ImportTarget -Import $imp -BaseDir $rosterDir
        # Format-SafePathToken, NOT Format-SafeToken (inbound #414): these lines are forwarded into
        # session context by the hook and the value is arbitrary text out of a markdown file, so it must
        # be sanitized -- but the id-shaped sanitizer strips '~', '\' and ':', which would print
        # 'C:\Users\...' as 'CUsers...' and drop the '~' that says where a home-relative path starts. A
        # finding whose whole job is to name the missing path must print a path the reader can look up.
        $impShown = Format-SafePathToken -Value $imp
        if ($target -and (Test-Path -LiteralPath $target -PathType Leaf)) {
            Write-Ok "import '$impShown' resolves"
        } else {
            $where = if ($target) { Format-SafePathToken -Value $target } else { 'a path that could not be resolved (no user home)' }
            # THE CAUSE LIST IS SPLIT BY IMPORT CLASS, because the closing instruction was wrong for one
            # of them (#2224, September 20, 2026). A '~/'-relative import resolves into the machine-wide
            # marketplace CLONE, and that clone tracks the TRUNK: it advances on
            # 'claude plugin marketplace update' alone -- not on a release, not on a push, not on a
            # 'plugin update'. So for that class the likeliest cause is not a wrong path at all, it is a
            # file renamed on the trunk that this machine's clone has not been refreshed to.
            #
            # Measured: the persona rename of #2128 had landed here while this machine's clone sat 510
            # commits back, so the orchestrator's body was silently absent from every session -- and the
            # finding said 'Repair the path', naming only causes that imply the path is wrong. Followed
            # literally that reverts a path which is already correct, re-breaking the rename in the one
            # file that carries it, and the next refresh then breaks it again the other way. The repair
            # order is what had to change: refresh first, edit only if that does not resolve it.
            #
            # The in-tree class keeps the original wording. There is no clone under it, so a refresh
            # cannot help and 'Repair the path' is the right instruction there.
            $common = "the '@'-import '$impShown' in $rosterRel points at '$where', which does not exist -- and Claude Code fails an unresolvable import SILENTLY. Everything that file was supposed to bring in is simply absent from every session here, while the roster around it keeps rendering, so nothing looks wrong. For the persona-body import that means the orchestrator runs without his ritual and his delegation rules."
            if ($imp -match '^\s*~[\\/]') {
                # The marketplace name is the segment after 'marketplaces/', and it is what the refresh
                # command takes. Validated as a slug before it is printed INTO a command line: an
                # unvalidated segment out of repo markdown would be a command for the reader to paste.
                # Where the path carries no usable one, the bare command is still correct -- it refreshes
                # every registered marketplace.
                $market = if ($imp -match 'marketplaces[\\/]([^\\/]+)') { Format-SafeToken -Value $Matches[1] } else { '' }
                $refresh = if ($market -and (Test-PluginMarketplaceSlug -Marketplace $market)) {
                    "claude plugin marketplace update $market"
                } else {
                    'claude plugin marketplace update'
                }
                Write-Failure ($common + " This import points into the machine-wide marketplace CLONE, which tracks the trunk and advances on a refresh alone -- not on a release, a push, or a 'plugin update'. Usual causes, in order of likelihood: this machine's clone is behind the trunk and the file was renamed there; the marketplace or plugin directory was renamed and this path was not; the plugin is not installed on this machine; or the file moved inside the plugin. REFRESH FIRST -- $refresh -- and edit the path in $rosterRel only if that does not resolve it. Editing first reverts a path that may already be correct.")
            } else {
                Write-Failure ($common + " Usual causes, in order of likelihood: the marketplace or plugin directory was renamed and this path was not; the plugin is not installed on this machine; or the file moved inside the plugin. Repair the path in $rosterRel.")
            }
        }
    }
}

# Drop '@'-import lines before anything reads this text (issue #227). The bootstrap writes
# '@.claude/plugins/<family>/<plugin>/01-01-extension.md' into CLAUDE.md, and that path CONTAINS the
# token '01-01' -- so the roster test was satisfied by the import itself and Chris counted as rostered
# with no roster row anywhere in the file. Measured: 18 ids reported missing after a bootstrap instead
# of 19, and 01-01 is the worst possible one to lose, because a persona appears in no always-on listing
# and the roster row is the ONLY thing that makes them exist for a session.
#
# Narrow on purpose. Get-RosterIdTokenPattern's docstring records that binding the token to a
# roster-row/table shape was DELIBERATELY rejected (inbound #182): Test-InRoster is asked about an id in
# free prose, and a table shape would change behaviour for consumers who format their roster as a list.
# That reasoning still holds and is not overturned here. An '@'-import is a different thing entirely --
# a line the bootstrap writes, never a roster row under any formatting convention -- so excluding it
# needs none of that risk.
#
# Residual, unchanged and deliberately not chased: a repo whose roster file happens to reference a lens
# path in ORDINARY PROSE still satisfies the test for that id. This repo does exactly that (Chris's lens
# is linked from the routing prose), so its 01-01 would pass even without a table row -- harmless here,
# because the real roster row exists. Same accepted class as the prose false positives in #182.
$rosterText = (($rosterText -split "`r?`n") | Where-Object { $_ -notmatch '^\s*@' }) -join "`n"

# Enabled plugins from the whole settings chain, not settings.json alone (inbound #294 -- the shared
# Get-EnabledPlugins carries the measurement and the reasoning; same source the bootstrap uses).
$enabled = Get-EnabledPlugins -RepoRoot $repoRoot -UserHomeOverride $UserHomeOverride
$enabledIds = @($enabled.Ids)

# A settings file that does not parse is an ERROR, not a crash. It used to be the latter: under
# $ErrorActionPreference = 'Stop' a malformed settings.json killed the run, and the hook could only say
# "the roster check could not complete (exit N)" without naming the file. Get-EnabledPlugins keeps
# reading the rest of the chain, so the check still reports everything it can AND says which layer is
# broken -- and it must stay an error, because a chain the check could not fully read is exactly the
# state in which "nothing enabled" would be an unearned conclusion.
foreach ($badLayer in @($enabled.Unreadable)) {
    Write-Failure "$badLayer does not parse as JSON -- its enabledPlugins entries were not read."
}

# [NOTHING-ENABLED]: its own non-counting roll-up, so the session hook can give this state its own
# verdict instead of letting it fall through to "roster in sync with the enabled plugins" (inbound
# #294, symptom 1). Same shape as [ORPHANS]/[BOOTSTRAP]: the [INFO] lines below stay for a deliberate
# run, and this one line is what reaches a session. It is NOT an error -- a repo that has genuinely
# enabled nothing is not broken -- but it must never read as a checked, healthy roster.
if ($enabledIds.Count -eq 0) {
    Write-Host "  [NOTHING-ENABLED] no plugin is enabled for this repo -- checked $($enabled.Summary); nothing was compared against the roster." -ForegroundColor Yellow
    if (-not $enabled.AnyFileExists) {
        Write-Info "no settings file in the chain ($(($enabled.Layers | ForEach-Object { $_.Label }) -join ', ')) -- nothing enabled to check."
    } elseif (-not $enabled.AnyKeyFound) {
        Write-Info "no 'enabledPlugins' key in $($enabled.Summary) -- nothing to check."
    } else {
        # KeySummary, not Summary (inbound #304). Summary phrases the layers that EXIST, which is exactly
        # right one line up ("-- checked <Summary>": a claim about what was inspected) and wrong here,
        # where the layer IS the answer. Measured against life-hub: the key sat in one of three layers --
        # the user one, as an empty object -- and this line named all three, sending a reader looking for
        # it to two repo-owned files that demonstrably do not have it. See Get-EnabledPlugins' KeyIn.
        Write-Info "'enabledPlugins' is present in $($enabled.KeySummary) but enables nothing -- nothing to check."
    }
}

# --- Enabled, but is it installed for THIS path? (inbound #302) -----------------------------------
# The second half of what Claude Code needs, and until now the half no check read. An enable without an
# install record for this project path loads nothing -- no skills, no subagents, no hooks -- while this
# script happily reports every specialist of that plugin as drift. See Get-InstallRecord for the
# measurement (27 [ERROR] lines about a session surface that was not there) and for why a record without
# a projectPath still counts.
#
# Only asked when something is enabled at all. With nothing enabled the question has no subject, and the
# [NOTHING-ENABLED] roll-up above has already said everything there is to say -- adding a second line
# about an administration nobody is waiting for is the session-start noise PR #99 removed.
if ($enabledIds.Count -gt 0) {
    $installRecord = Get-InstallRecord -RepoRoot $repoRoot

    # An administration that exists but does not parse is an [ERROR], on the same reasoning as an
    # unreadable settings layer above: it is the authority on this question, and an authority the check
    # could not read is exactly the state in which any conclusion drawn from it is unearned.
    if ($installRecord.Exists -and -not $installRecord.Readable) {
        Write-Failure "$($installRecord.Path) does not parse as JSON ($($installRecord.Error)) -- whether the enabled plugins are installed for this path was not checked."
    }

    $notInstalledHere = @($enabledIds | Where-Object { -not (Test-PluginInstalledHere -InstallRecord $installRecord -PluginId $_) })

    # [NOT-INSTALLED-HERE]: its own non-counting roll-up, in the family of [NOTHING-ENABLED]/[BOOTSTRAP]/
    # [ORPHANS]. NOT an error -- the repo is not broken, and the state is usually one command away from
    # intended -- but it must never read as a checked, healthy roster, because every finding printed below
    # it is about a specialist surface no session in this repo can see.
    #
    # ONE line, naming the count and the ids, rather than one line per plugin: the session hooks surface
    # this marker, and a repo with several enabled plugins would otherwise produce a wall of
    # near-identical lines at every start -- the noise PR #99 removed. The per-plugin detail follows as
    # [INFO], visible on a deliberate run.
    #
    # Worth knowing about its own reach: in the WORST case of this state -- no plugin installed for this
    # path at all -- nothing in this repo runs the hook that would surface this line, because the hook
    # ships in the plugin. That is not an argument against the marker but the reason the same query now
    # also runs in check-connectors, from the workshop, ABOUT each registered consumer: the one vantage
    # point that still has a voice when a consumer has gone silent.
    if ($notInstalledHere.Count -gt 0) {
        # Format-SafeToken on every id before it is joined into this line (inbound #309). A plugin id is
        # an 'enabledPlugins' KEY NAME, so it is an arbitrary JSON string that may carry newlines -- and
        # this is a line the session hooks forward into the session context, where an unsanitized value
        # could forge a line of its own. Same reasoning Set-CheckScope has carried since #203; it just
        # was not applied to the ids.
        $shownIds = (@($notInstalledHere | ForEach-Object { Format-SafeToken -Value $_ }) -join ', ')
        Write-Host "  [NOT-INSTALLED-HERE] $($notInstalledHere.Count) of $($enabledIds.Count) enabled plugin(s) have no install record for this path ($shownIds) -- a session here will not load them, so anything reported below about them concerns a surface this repo does not have. Fix: 'claude plugin install <id> --scope project' from this root." -ForegroundColor Yellow
        # NON-COUNTING supporting facts, deliberately not [INFO]. The roll-up above is the signal; these
        # add the enabling layer (the #294 promise: never leave a reader guessing WHERE an enable came
        # from) and the administration path that was consulted. Two reasons they must not count:
        #   - one enabled plugin without a record would otherwise add a permanent info signal to every
        #     run, and "this repo reports 0 signals" is an assertion the test suite leans on to mean
        #     something. A baseline that can never be zero is a baseline nobody reads twice.
        #   - inbound #302 asked for this as a verdict, not an error and not a counting signal, on the
        #     grounds that the repo is not broken. Counting it would have smuggled the severity back in
        #     through the summary line.
        foreach ($plugId in $notInstalledHere) {
            Write-Skip "'$(Format-SafeToken -Value $plugId)' is enabled in $($enabled.LayerById[$plugId]) but has no record for this path in $($installRecord.Path) -- enabled is not installed."
        }
    } elseif (-not $installRecord.Exists) {
        # Said out loud rather than passed over: 'no administration file' is the one shape in which every
        # plugin looks installed to the predicate above (absence of the authority is not evidence of
        # absence), so a reader must not mistake that silence for a positive answer. Non-counting for the
        # same reason as above -- it is a statement about what could not be checked, not a finding about
        # this repo.
        Write-Skip "no plugin administration found at $($installRecord.Path) -- whether the enabled plugins are installed for this path could not be checked."
    }

    # --- Installed here, but is the record the shape we assume? (inbound #314/#315) ----------------
    # [RECORD-SHAPE]: the fifth instance of the non-counting marker pattern, after [ORPHANS] (#204),
    # [UNREGISTERED] (#208), [INVENTORY] (#220) and [BOOTSTRAP] (#225) -- reached for rather than invented,
    # exactly as the pattern's own rule says to.
    #
    # It closes the gap round v8 opened between what [NOT-INSTALLED-HERE] was built to catch and what a
    # consumer is actually left in. That marker fires when there is no evidence for this path at all; a
    # session start writes the missing record itself before any hook can look, so from a session it is
    # practically unreachable. What survives that write is a record of the wrong SHAPE -- and nothing
    # reported any of them until #314/#315/#323. See Get-RecordShape for all three measured shapes, for why
    # this is not an [ERROR], and for why "the state heals itself" (this comment's earlier claim) was
    # falsified: a SECOND session start writes nothing, so the post-write state persists rather than heals.
    #
    # Ordered after the [NOT-INSTALLED-HERE] branch, and the two still cannot describe the same plugin --
    # but the boundary moved with #323 and is now drawn by EVIDENCE rather than by path: no evidence at all
    # is that marker's subject, while any evidence of the wrong shape is this one's, INCLUDING a pathless
    # record with none for this path. That last case is the one both markers used to stay silent about,
    # each correctly by its own rule.
    $recordShapes = @($enabledIds | ForEach-Object { Get-RecordShape -InstallRecord $installRecord -PluginId $_ } | Where-Object { $_ })
    # THE COUNT IS GATED ON ENABLE PROVENANCE; THE ARMS ARE NOT (issue #1138). $countedShapes drives the
    # roll-up alone -- the loop below still walks $recordShapes, so every shape keeps its detail line and
    # its remedy. Suppressing a detail was never on the table: those lines are the only place the remedy
    # lives, which is the whole point #324 gave them the marker for.
    $repoEnabledIds = @($enabled.RepoEnabledIds)
    $countedShapes = @($recordShapes | Where-Object { $repoEnabledIds -contains $_.Id })
    if ($countedShapes.Count -gt 0) {
        # Format-SafeToken on every id, same reasoning as the roll-up above (inbound #309): a plugin id is
        # an arbitrary JSON key that may carry newlines, and this line is forwarded into session context.
        $shapeIds = (@($countedShapes | ForEach-Object { Format-SafeToken -Value $_.Id }) -join ', ')
        # IT REPORTS THE COUNT AND LEAVES THE VERDICT TO THE ARMS (inbound #1130) -- the same repair #1095
        # applied one line lower, arriving late at the line the reader meets first. It used to open with
        # "not the assumed shape" and close with "what is wrong is the administration", both unconditional,
        # and both contradicted by the 'pathless-only' arm below: since #1095 that arm says in so many words
        # that the state may be deliberate and needs no action. Two lines about one plugin in one hook
        # output, saying opposite things, at every session start -- a sharper defect than #1095 reported,
        # because before that repair the two lines at least agreed.
        #
        # AND SINCE #1138 IT COUNTS ONLY WHAT THIS REPO ENABLED. The gate #1095 left standing -- stop
        # counting a plugin the repo's own settings never enabled -- reads a field the demotion does not
        # touch, so unlike the scope gate withdrawn there it was never disproved by #323; it was merely
        # UNMEASURED. The measurement is now taken and it says yes, more strongly than the question asked:
        # 'claude plugin install --scope project' does not merely usually write the enable into the repo's
        # own settings, it REFUSES TO INSTALL AT ALL when it cannot, leaving no register record behind. So
        # a record for this path with no repo-owned enable is not a state the CLI can produce, and
        # suppressing the count for one costs no coverage. Get-EnabledPlugins carries the six shapes that
        # were measured and why the predicate reads BOTH repo layers rather than settings.json alone.
        #
        # ONLY THE COUNT AND THE HEADLINE MOVED. Every shape still gets its detail line below, because the
        # remedy lives only there and the reader this marker exists for is the one who needs it.
        #
        # "Details below." is gone as a sentence and kept as a promise -- the deferral names the detail
        # lines, so #324's property (they carry the marker, and therefore reach a session) is still what
        # makes this line honest rather than a hand-wave.
        Write-Host "  [RECORD-SHAPE] $($countedShapes.Count) of $($repoEnabledIds.Count) plugin(s) enabled by this repo have an install record for this path that differs from the assumed shape -- exactly one record, scoped 'project' ($shapeIds). The plugin still loads, and nothing else reports this; whether it needs action differs per shape, so the verdict is on the detail lines below rather than here." -ForegroundColor Yellow
    }
    # OUTSIDE THE ROLL-UP'S BRANCH, not merely after it (issue #1138). These lines used to be nested in it,
    # which was invisible while the two fired together -- gating the count on enable provenance made the
    # nesting a silencer: a machine-wide plugin would have lost its remedy along with its headline, which is
    # the one outcome this change must not produce. The loop walks $recordShapes; only the roll-up above
    # reads $countedShapes.
    #
    # NON-COUNTING per-plugin detail, for the same two reasons as [NOT-INSTALLED-HERE]'s: a permanent
    # info signal would make 'this repo reports 0 signals' unassertable, and the severity must not
    # re-enter through the summary line. Each line names the shape AND its remedy, because they differ:
    # a wrong scope is removed at that scope, a duplicate by dropping the stale one, a demotion by
    # re-installing at project scope.
    #
    # THE DETAIL LINES CARRY THE [RECORD-SHAPE] MARKER THEMSELVES, and that is the fix for inbound #324
    # rather than a formatting whim. They used to be [SKIP] lines, and roster-sessioncheck forwards only
    # lines matching \[RECORD-SHAPE\] -- so in a SESSION the roll-up's closing promise of details was
    # false: the reader was told an administration problem exists, told the details follow, and got
    # neither the detail nor a way to reach it. The remedy lives ONLY in these lines, and the whole
    # point of giving this marker its own verdict line was to make that reader actionable. Marking them
    # makes the promise true in both contexts and needs no change in the hook's filter. Still plain
    # Write-Host, NOT Write-Info: carrying the marker must not smuggle the severity back in through the
    # counting summary.
    foreach ($shape in $recordShapes) {
        $safeId = Format-SafeToken -Value $shape.Id
        $scopeList = (@($shape.Scopes | ForEach-Object { Format-SafeToken -Value $_ }) -join ', ')
        if ($shape.Shapes -contains 'no-project-scope') {
            Write-Host "  [RECORD-SHAPE] '$safeId' has $($shape.Count) record(s) for this path, scoped '$scopeList' and none 'project' -- the shape a SESSION START leaves behind (it creates a missing record and flips 'project' to 'local'). Remove it at that scope, then re-install at project scope from this root." -ForegroundColor DarkGray
        }
        if ($shape.Shapes -contains 'duplicate') {
            Write-Host "  [RECORD-SHAPE] '$safeId' has $($shape.Count) records for this path (scopes: $scopeList) -- the stray second record specialists-init step 0c warns about, which a repair install at a DIFFERENT scope produces rather than prevents. Remove the stale one at ITS scope; one 'project' record must remain." -ForegroundColor DarkGray
        }
        if ($shape.Shapes -contains 'pathless-only') {
            # The shape nothing reported before #323. Named in full, because the reader's own
            # verification query prints NOTHING for this plugin while it is plainly loading -- so
            # without this line the only visible evidence is an absence.
            #
            # IT REPORTS THE OBSERVATION AND ASKS THE READER FOR THE HISTORY (inbound #1095). It used to
            # state the demotion as fact -- "the shape a SESSION START leaves behind when it demotes",
            # "this repo simply no longer has its own record" -- and close with a bare
            # "Re-install at project scope from this root." Both halves are wrong in the common case.
            # The conjunction this arm fires on (no record for this path, a pathless one exists) is ALSO
            # the resting state of every correctly user-installed plugin in every repo that has not
            # project-installed it, so the line fires machine-wide, at every session start, for a
            # deliberately chosen install shape -- and then instructs the reader to undo it, which
            # converts a machine-wide install into a per-repo one and adds a record nobody wanted.
            # Measured in a fresh consumer on August 29, 2026, on a plugin installed machine-wide three
            # weeks before that repo existed.
            #
            # AND THE CAUSE IS NOT RECOVERABLE FROM THE DATA, which is why the fix is the wording rather
            # than a predicate. The obvious gate -- suppress this for scope 'user' -- was proposed and
            # withdrawn on the same issue: #323 measured the demotion directly, and it WRITES
            # scope='user', drops projectPath, and merges away any pre-existing pathless record. A
            # demoted record is byte-for-byte the shape of an ordinary machine-wide install. Gating on
            # scope would restore exactly the silence #314/#315/#323 were built to end.
            #
            # So the arm keeps firing and stops claiming. The one question that separates the two states
            # is one the reader answers instantly and the register cannot answer at all: did YOU install
            # this here at project scope? The remedy is conditional on that, and the no-action branch is
            # stated out loud -- an unstated "or this is fine" reads as a defect the reader must clear.
            Write-Host "  [RECORD-SHAPE] '$safeId' has no record for this path, only a pathless one (scope: '$scopeList') -- so it loads from a machine-wide install and prints NOTHING in the specialists-init step 0c query while it is plainly loading. Two states look identical here and the register cannot tell them apart: if you installed this plugin at project scope FROM THIS ROOT, that record is gone (#323) -- re-install it at project scope. If it is installed machine-wide on purpose, this line is expected and needs no action." -ForegroundColor DarkGray
        }
    }
}

# --- Is this repo bootstrapped at all? (issue #225) -----------------------------------------------
# A repo that has never run specialists-init has no lenses and no roster rows, so EVERY enabled
# specialist is "missing" twice over. Measured on a fresh consumer: 38 [ERROR] lines from this check
# alone, and nothing anywhere naming the skill that resolves them -- which reads as "this plugin is
# broken" rather than "you are not done yet". Drift reporting is right for a bootstrapped repo and
# wrong for an unbootstrapped one, and until now the check could not tell those apart.
#
# The predicate is deliberately strict -- no lens ANYWHERE and no roster row for ANY id. A repo with
# roster rows but no lenses is a maintained repo that has drifted, and must keep erroring; the same
# holds the other way round. Only the state where neither exists is "never bootstrapped".
#
# The seam directory belongs in this scan, and its absence was the same pre-seam hardcode as
# Get-OnPathLensDirs': a consumer whose lenses live in .claude/specialists/lenses/ (i.e. any consumer
# bootstrapped since #221) looked lens-less here, so one empty roster slot was enough to declare it
# never bootstrapped -- and the [BOOTSTRAP] line would then swallow every real finding behind advice to
# run specialists-init on a repo that already has its whole lens tree in place.
$anyLensFile = $false
$lensFiles = @()
foreach ($dir in @((Get-SeamPaths -RepoRoot $repoRoot).Dir, (Join-Path $repoRoot '.claude\plugins'), (Join-Path $repoRoot '.claude\extensions'))) {
    $found = @(Get-SpecialistFiles -Path $dir -Kind Lens -Recurse)
    if ($found.Count -gt 0) {
        $anyLensFile = $true
        $lensFiles += $found
    }
}
# Any '<gg>-<ii>' token at all in the roster, using the same boundary rule as Test-InRoster so a
# stray ISO date or a page range cannot pass for a roster row (issue #182).
#
# IT WAS A HAND-COPIED PATTERN UNTIL #2130, AND THE COPY HAD DRIFTED: it carried the trailing boundary
# '(?![\d-])' where the shared source has '(?!\d)'. That is the tighter of the two, and it excludes
# exactly the case the source's own docstring names as the legitimate one -- an id immediately followed
# by a hyphen, which is every lens reference ever written. So a roster whose only ids sit inside lens
# filenames read as NO roster row here, and the [BOOTSTRAP] line would then swallow every real finding
# behind advice to run specialists-init on a repo that already has its whole lens tree. The comment
# above claimed the two were the same rule while the literal below said otherwise, which is #182's own
# shape one file over. Calling the function is the repair; there is no second spelling left to drift.
$anyRosterRow = $rosterText -match (Get-RosterIdTokenPattern)

$unbootstrapped = ($enabledIds.Count -gt 0) -and (-not $anyLensFile) -and (-not $anyRosterRow)

# --- The third state: bootstrapped, but nobody has filled anything in yet (inbound #333) ----------
# MEASURED ON THE DOCUMENTED HAPPY PATH. On a virgin profile, immediately after a completely successful
# specialists-init plus restart -- every count correct -- the next session start printed NINETEEN [ERROR]
# lines, one per specialist, saying each has no roster row. Nothing was broken; filling the lenses is a
# step of its own in INSTALL.md (Step 4) that the reader has legitimately not reached yet, and [ERROR]
# is the heaviest level these checks have. (That page said "at your own pace" when this was measured;
# #408 promoted it to a numbered step, which sharpens the point rather than changing it -- a step you
# have not reached is not an error either.)
# The risk is habituation: whoever learns to ignore nineteen false errors ignores the twentieth too.
#
# The state was invisible to the predicate above because that one is strict on purpose -- no lens ANYWHERE
# and no roster row for ANY id -- and a bootstrapped repo HAS lenses. So it fell through to full drift
# reporting, which is right for a maintained repo and wrong for one whose owner has not started.
#
# THE DISCRIMINATOR IS MEASURABLE, which is what makes this safe to add: every lens file the bootstrap
# writes is a VUL-IN scaffold. If lenses exist, EVERY ONE of them is still an unfilled scaffold, and no
# roster row exists for any id, then nobody has written anything yet -- there is no work to have drifted
# from. The moment one lens is filled in, or one roster row appears, the repo is being maintained and the
# [ERROR] lines are correct again. A repo that lost its roster while carrying real lens content therefore
# still errors, which is the case the strictness above exists for.
$allLensesAreScaffolds = $false
if ($anyLensFile) {
    # -notmatch over the whole file: a scaffold carries the marker, a filled-in lens does not. Read
    # failures count as "not a scaffold" -- erring toward reporting, never toward silence.
    $filled = @($lensFiles | Where-Object {
        $text = ''
        try { $text = [System.IO.File]::ReadAllText($_.FullName) } catch { $text = '' }
        (-not $text) -or ($text -notmatch 'VUL-IN')
    })
    $allLensesAreScaffolds = ($filled.Count -eq 0)
}
$rosterPending = ($enabledIds.Count -gt 0) -and $anyLensFile -and $allLensesAreScaffolds -and (-not $anyRosterRow) -and (-not $unbootstrapped)
# Counts specialists actually resolved from a cache dir, so the marker below only fires when there was
# genuinely something to report. Deliberately NOT an early exit before the plugin loop: a first version
# did that and broke the "plugin enabled but not in the cache" case, telling the reader to run
# specialists-init when the real problem was that the plugin is not installed on this machine at all.
# The loop therefore still runs and still reports everything else it knows -- not-in-cache, orphans,
# off-path lenses -- and only the two "missing twice over" findings per specialist are replaced.
$suppressedForBootstrap = 0
# Counted separately from the one above, because they stand for different states with different advice:
# "run specialists-init" versus "fill in the roster when you get to it".
$suppressedForRosterPending = 0
# Counted separately again, and for the third distinct state (issue #2219): the missing-lens findings
# held because this check's own file-naming vocabulary is older than the tree it is reading. One per
# specialist, so the count IS the specialist count. The second tally collects the filenames, because the
# marker names one of them and that is the only part of it a reader can verify by looking.
$suppressedForLensNaming = 0
$lensNamingFiles = @{}
$allBackingIds = @{}
$pluginNames = @()

foreach ($plugId in ($enabledIds | Sort-Object -Unique)) {
    $parts = $plugId.Split('@')
    $name = $parts[0]
    $marketplace = if ($parts.Count -gt 1) { $parts[1] } else { '' }

    # The DISPLAY form of this id, bound once per iteration (inbound #309). $plugId itself must stay raw:
    # it is a hashtable key ($enabled.LayerById) and the source of the path segments below, so sanitizing
    # it in place would break lookups and silently change which directory is resolved. Two variables, with
    # one job each -- the raw value for logic, this one for every message. Bound here rather than wrapped
    # at each of the dozen call sites below, so a message added later cannot forget it.
    $plugIdShown = Format-SafeToken -Value $plugId

    # Guardrail: plugin-name/marketplace come from settings and become path segments -- validate as
    # slugs before touching the filesystem (mirrors check-connectors' Get-PluginDir).
    #
    # These two use Format-SuspectToken, not Format-SafeToken: here the id IS the complaint, so showing a
    # cleaned-up version without saying so would present a plausible id as the subject of an "invalid id"
    # error -- hiding the very characters that made it invalid.
    if (-not (Test-PluginNameSlug -Name $name)) {
        Write-Failure "invalid plugin id '$(Format-SuspectToken -Value $plugId)' in $($enabled.LayerById[$plugId]) -- skipped."
        continue
    }
    if (-not $marketplace) {
        Write-Info "plugin '$plugIdShown' has no '@marketplace' suffix -- cannot resolve its cache dir, skipped."
        continue
    }
    if (-not (Test-PluginMarketplaceSlug -Marketplace $marketplace)) {
        Write-Failure "invalid marketplace in plugin id '$(Format-SuspectToken -Value $plugId)' -- skipped."
        continue
    }

    # -RepoRoot makes the INSTALL RECORD the first answer to "which version does this repo load?", with
    # the highest-version cache scan as the fallback it always was. Without it this check reports on the
    # newest version present on the machine, which stops being the same thing the moment a second
    # consumer pulls a newer one into the shared cache -- see Resolve-PluginDir for the measured case.
    #
    # -UserHomeOverride is deliberately NOT passed through, for the reason Get-InstallRecord states on
    # its own parameter: that flag pins the USER LAYER OF THE SETTINGS CHAIN, and the administration is a
    # different file answering a different question. A fixture that wants to control the administration
    # redirects $env:USERPROFILE for the child process.
    $pluginDir = Resolve-PluginDir -Name $name -Marketplace $marketplace -CacheRoot $cacheRoot -RepoRoot $repoRoot
    if ($null -eq $pluginDir) {
        # TWO REASONS, TOLD APART, because Resolve-PluginDir answers $null for both and they are different
        # facts about this machine (August 6, 2026). It requires an agents/ dir at every return path, so a
        # plugin that is cached and simply ships no agents came back indistinguishable from one that is not
        # installed here -- and this line reported the second. Measured on figma@claude-plugins-official:
        # present in the cache at 2.2.90, its installPath in the administration, and reported as "not found
        # in the cache". The skip was right, the reason was false, and a reader acting on it would have gone
        # looking for a broken install. See Get-CachedPluginDirs.
        $cachedDirs = @(Get-CachedPluginDirs -Name $name -Marketplace $marketplace -CacheRoot $cacheRoot)
        if ($cachedDirs.Count -gt 0) {
            Write-Info "plugin '$plugIdShown' is enabled and present in the cache ($(Split-Path $cachedDirs[0] -Leaf)), but ships no agents/ directory -- there is no roster for this check to read, skipped. A plugin of skills, hooks or MCP servers only is the ordinary case for this, not a fault."
        } else {
            Write-Info "plugin '$plugIdShown' is enabled but not found in the cache ($cacheRoot) -- skipped (the install may run on another machine)."
        }
        continue
    }

    $pluginNames += $name
    foreach ($bid in (Get-BackingIds -PluginDir $pluginDir)) { $allBackingIds[$bid] = $true }
    # Agents AND personas (inbound #204) -- see Get-CheckedSpecialists for why the persona exclusion
    # only ever held for the orphan side.
    $specialists = @(Get-CheckedSpecialists -PluginDir $pluginDir)

    # The enabling LAYER travels in this header (inbound #294). Same reasoning as the [SCOPE] line: a
    # reader who is surprised that a plugin is being checked here at all needs the one fact that explains
    # it, and with a three-file chain -- one of which is outside the repo -- "enabled" is no longer
    # self-evidently a property of .claude/settings.json.
    Write-Host "`n-- plugin: $plugIdShown (cache $(Split-Path $pluginDir -Leaf), enabled in $($enabled.LayerById[$plugId]))" -ForegroundColor Cyan
    if ($specialists.Count -eq 0) { Write-Info "no agents or personas found for '$plugIdShown'."; continue }

    $onPathLensDirs   = @(Get-OnPathLensDirs -RepoRoot $repoRoot -PluginName $name)
    $canonicalLensDir = $onPathLensDirs[0]
    $legacyLensDir    = Join-Path $repoRoot '.claude\extensions'
    # Non-canonical family dirs found while walking this plugin's specialists -- reported once per dir
    # after the loop instead of once per lens, so a whole pre-#179 tree yields one line, not sixteen.
    $offPathDirs = @{}
    # One scan per plugin, not one per specialist: what it answers is a property of the directories
    # rather than of the id being looked up (issue #2219). Skipped outright on an unbootstrapped repo --
    # that state is "no lens file anywhere", so the scan could only ever come back empty, and saying so
    # at the call site is clearer than a function that quietly returns nothing.
    $unknownLensNames = @{}
    if (-not $unbootstrapped) {
        $unknownLensNames = Get-UnknownLensNameById -RepoRoot $repoRoot -PluginName $name `
            -Ids @($specialists | ForEach-Object { $_.Id })
    }

    foreach ($spec in $specialists) {
        $id   = $spec.Id
        $kind = $spec.Kind
        if ($ignoredIds -contains $id) {
            Write-Info "$kind '$id' ($plugIdShown) deliberately kept out of the roster/lenses (repo-config ignore-list) -- skipped."
            continue
        }
        $inRoster = Test-InRoster -RosterText $rosterText -Id $id
        $lensPath = Get-LensPath -RepoRoot $repoRoot -PluginName $name -Id $id
        $hasLens  = [bool]$lensPath
        if ($unbootstrapped) {
            # Never bootstrapped, so both findings are guaranteed for every specialist and neither says
            # anything the one [BOOTSTRAP] line after the loop does not say better. Counted rather than
            # silently dropped, so the marker can state how much it stands in for.
            $suppressedForBootstrap++
        } else {
            # The evidence the lens arm below consults (issue #2219): a markdown file in this repo's lens
            # directories that NAMES this specialist in a spelling this check cannot read. Bound to
            # '-not $hasLens': where the lens DID resolve, this check's vocabulary demonstrably worked for
            # this id, and a stray unrecognised file beside it proves nothing.
            $unknownLensName = ''
            if ((-not $hasLens) -and $unknownLensNames.ContainsKey($id)) { $unknownLensName = $unknownLensNames[$id] }
            if (-not $inRoster) {
                if ($rosterPending -and $hasLens) {
                    # Freshly bootstrapped and untouched: the row is missing because nobody has written the
                    # roster yet, which the marker after the loop says once. Scoped to ids that DO have a
                    # lens on purpose -- a specialist that arrived later with a plugin update has neither,
                    # and that IS drift a reader must see even in this state.
                    $suppressedForRosterPending++
                } else {
                    # NOT ALSO HELD BY THE NAMING MARKER, and that is a decision rather than an omission
                    # (issue #2219). The measured wall carried four of these -- personas whose only roster
                    # token sits inside a lens filename of the newer generation -- so it is tempting to
                    # hold them on the same evidence. Two things rule it out. The coupling is historical,
                    # not structural: Test-InRoster reads Get-RosterIdTokenPattern, which owes nothing to
                    # Get-SpecialistFileShapes; they merely moved in the same rename series. And that half
                    # is ALREADY repaired -- #2130 replaced the boundary '(?<![\d-])', which rejected every
                    # id preceded by a hyphen, with '(?<!\d)(?<!\d-)', so a roster that names the specialist
                    # only through 'specialist-<g>-<id>-lens.md' now matches. Verified on this repo: the
                    # four lines are gone from a current payload while the thirty lens lines remain. An arm
                    # for them could therefore never fire, and unreachable suppression is the one shape a
                    # suppressor must not have.
                    Write-Failure "$kind '$id' ($plugIdShown) has no roster row in $rosterRel -- add it to the roster."
                }
            }
            if (-not $hasLens) {
                if ($unknownLensName) {
                    $suppressedForLensNaming++
                    $lensNamingFiles[$unknownLensName] = $true
                } else {
                    # The finding names the spelling a reader should CREATE, not every spelling the check
                    # looked for (#2130): this line is advice, and offering two names invites the reader to
                    # pick the one that is on its way out.
                    Write-Failure "$kind '$id' ($plugIdShown) has no repo-lens (.claude/specialists/lenses/$(Get-SpecialistFileName -Kind Lens -Id $id), the pre-seam .claude/plugins/$(Get-LensFamily)/$name/ path, or the legacy .claude/extensions/ path)."
                }
            }
        }
        if ($inRoster -and $hasLens) { Write-Ok "$kind '$id' present in roster + lens" }

        # Lens on a non-canonical family segment (INFO -- issue #179): a bootstrap from before that fix
        # derived the family from the install path, which in the plugin-cache layout is the MARKETPLACE
        # name. The lens is present and fully functional, so this is NOT missing-lens drift -- flagging
        # it as such is exactly the misleading report #179 was filed about. Soft on purpose: silent at
        # session start, visible on a deliberate run, and the @-import in CLAUDE.md is the thing to
        # check when the tree is moved.
        if ($hasLens) {
            $lensDir = Split-Path $lensPath -Parent
            if ($onPathLensDirs -notcontains $lensDir -and $lensDir -ne $legacyLensDir) {
                if (-not $offPathDirs.ContainsKey($lensDir)) { $offPathDirs[$lensDir] = 0 }
                $offPathDirs[$lensDir]++
            }
        }

        # Header drift (INFO -- issue #145): a lens generated by an older scaffold bakes the persona's
        # first name into its header ("# Sean <midDot> repo-lens"). After a rename that name is stale in
        # every consumer, yet the lens itself is present, so this is NOT missing-lens drift -- it is a
        # cosmetic mismatch. Kept INFO on purpose: silent at session start (the hook only surfaces
        # [ERROR]), shown on a deliberate run, and staged as a paste-ready reconcile by the sync-roster
        # skill. The nameless header the scaffold now writes never triggers this (its token is the g-id).
        #
        # AGENTS ONLY, and that is a known gap rather than an oversight (inbound #204). The comparison
        # needs the specialist's CURRENT name, which Get-AgentName reads from the agent file's `name:`
        # frontmatter. A persona file has no such field (only id/group), so for a persona there is no
        # authoritative name to compare against: Get-AgentName would return '', Get-DisplayName would
        # fall back to the id, and every persona lens whose header carries a name -- i.e. all of the
        # older ones -- would be reported as drifting from its own id. That is a false signal, and a
        # false signal in the exact register the hook is being taught to trust is worse than a missing
        # one. Header drift for personas stays undetectable until a persona carries a name in its
        # frontmatter; the missing-row/missing-lens checks above do cover personas.
        if ($hasLens -and $kind -eq 'agent') {
            $staleName = Get-ScaffoldHeaderName -LensPath $lensPath -MidDot $midDot
            if ($staleName -and $staleName -ne $id) {
                $current = Get-DisplayName -RawName (Get-AgentName -PluginDir $pluginDir -Id $id) -Fallback $id
                if ($current -and $staleName -ne $current) {
                    # NAMES THE COMMAND AND WHO TYPES IT (inbound #1104): 'sync-roster' carries
                    # disable-model-invocation, so a session reading this cannot invoke it and cannot
                    # read the page that would explain the route. Check 33 holds every printed
                    # message to this; the reasoning in full is at the [BOOTSTRAP] marker below.
                    Write-Info "lens '$id' ($plugIdShown) header still names '$staleName' (agent is now '$current') -- type /dkj-subagents-alpha:sync-roster to reconcile the header; that command is reserved for explicit user invocation, so an agent has to hand it to the repo owner."
                }
            }
        }
    }

    $canonicalRel = Get-RelativeToRoot -RepoRoot $repoRoot -Path $canonicalLensDir
    foreach ($d in ($offPathDirs.Keys | Sort-Object)) {
        $rel = Get-RelativeToRoot -RepoRoot $repoRoot -Path $d
        Write-Info "$($offPathDirs[$d]) lens file(s) for '$plugIdShown' live in '$rel' instead of the canonical '$canonicalRel' -- they are found and counted as present; move them (and the CLAUDE.md @-import along with them) to align with the standard."
    }
}

# Orphans (INFO): roster tokens / lens files whose id has no backing agent or persona among the
# resolved enabled plugins. Only run when at least one plugin resolved -- otherwise we have no basis to
# call anything an orphan (e.g. the only enabled plugin is not on this machine).
if ($pluginNames.Count -gt 0) {
    Write-Host "`n-- orphans" -ForegroundColor Cyan
    $lensIds = Get-LensIds -RepoRoot $repoRoot -PluginNames ($pluginNames | Sort-Object -Unique)
    $rosterTokenIds = @([regex]::Matches($rosterText, (Get-RosterIdTokenPattern)) |
        ForEach-Object { $_.Value } | Sort-Object -Unique)

    $orphanCount = 0
    foreach ($id in (@($lensIds.Keys) + $rosterTokenIds | Sort-Object -Unique)) {
        if ($allBackingIds.ContainsKey($id)) { continue }
        $where = @()
        if ($lensIds.ContainsKey($id)) { $where += 'lens' }
        if ($rosterTokenIds -contains $id) { $where += 'roster' }
        Write-Info "orphan '$id' ($($where -join ' + ')) -- no matching agent/persona in any enabled plugin."
        $orphanCount++
    }
    if ($orphanCount -eq 0) {
        Write-Ok "no orphan roster tokens / lens files"
    } else {
        # One machine-readable roll-up so the orphan trail is not silent at session start (inbound #204,
        # change 2). The per-orphan lines above stay [INFO] and stay suppressed by the hook, which is
        # deliberate: an orphan can be a legitimately just-removed specialist, and promoting it to
        # [ERROR] would put a red line in every session during any transition. But "only visible to
        # whoever deliberately runs the script" is in practice nobody, so the count gets its own
        # non-counting token that the hook DOES surface -- one line, and only when there is something
        # to say. Deliberately not a general "N info signals" line: this repo permanently carries
        # ignore-list [INFO]s, so that would fire at every single session start -- exactly the noise
        # the quieter session start (PR #99) removed.
        Write-Host "  [ORPHANS] $orphanCount roster token(s)/lens file(s) have no backing agent or persona in any enabled plugin -- a removed specialist leaves this behind." -ForegroundColor Yellow
    }
}

if ($suppressedForBootstrap -gt 0) {
    # Non-counting marker the session hooks surface, same shape as [ORPHANS] above and
    # [UNREGISTERED]/[INVENTORY] in connector-sessioncheck: the plugin install is fine, only this
    # repo's own side of the setup has not happened. Counting it as an error would put a red line and
    # exit 1 in every session of a repo whose owner has simply not got round to the bootstrap -- and
    # not shouting at that person is the entire point of issue #225.
    #
    # NAME THE COMMAND AND WHO TYPES IT, NOT THE SKILL (inbound #1093 / #1096). This line used to say
    # "run the 'specialists-init' skill", and the reader it lands on hardest is the MODEL: this is a
    # SessionStart hook, so on a fresh consumer it is the first thing in context, at the top of every
    # session until the repo is adopted. That skill carries disable-model-invocation, so a model
    # following the instruction verbatim is refused by the harness -- and the state it is left in is the
    # worst available one: told to act, given nothing it can act on, and barred from the page that
    # documents the route (the flag removes the skill's description from context entirely, so it cannot
    # even learn the skill exists). What a model does NEXT is the actual cost: bootstrap.ps1 sits in the
    # plugin cache reachable by absolute path, and this is the moment it is most tempted to substitute.
    # Measured in the testrun-2 adoption, August 29, 2026, where the run stopped here.
    #
    # DUAL AUDIENCE, WHICH IS WHY THIS IS NOT THE REPORT'S LITERAL WORDING. The report proposed
    # "Ask the user to run ..." -- correct for the model and odd for the OWNER, who reads this same line
    # on their own terminal and is not a third party to themselves. Naming the command and stating who
    # must type it serves both: the owner reads an instruction they can follow, the model reads a
    # handover it can make. The '/dkj-subagents-alpha:' prefix is deliberate and load-bearing -- before this fix
    # that string appeared in no shipped file in either plugin, so a model that correctly gave up had to
    # reconstruct the command it was handing over.
    #
    # The 'adopt-dkj-policy' line in the contract check stays a bare imperative on purpose: that
    # skill has no such flag, so its reader CAN comply. The rule is not a phrasing convention -- it is
    # that a message must not name a skill barred to the reader it addresses.
    Write-Host "  [BOOTSTRAP] the specialists plugin is enabled here but this repo has not been set up yet: no repo lenses and no roster rows exist, so all $suppressedForBootstrap specialist(s) would each be reported missing twice over. Nothing is broken -- the subagents work; what is missing is the orchestrator and the repo-specific setup. Run /dkj-subagents-alpha:specialists-init to put them in place -- that command must be TYPED by the repo owner, because the skill is reserved for explicit user invocation and an agent cannot start it. It is additive and never overwrites anything you have written." -ForegroundColor Yellow
}

if ($suppressedForRosterPending -gt 0) {
    # The sixth non-counting marker, and the one that exists because the DOCUMENTED HAPPY PATH ended in
    # nineteen [ERROR] lines (inbound #333). Its own line rather than folding under [BOOTSTRAP]: that one
    # says "run specialists-init", which this reader has just done successfully, and being told to run it
    # again is exactly the kind of advice that teaches people the checks are wrong.
    # NO LITERAL '[ERROR]' IN THIS TEXT, and that is a correctness rule rather than a style one: the session
    # hook counts its error signals by matching '\[ERROR\]' over the check's whole output, so a marker line
    # merely MENTIONING the token would be counted as an error and push the hook into its drift branch --
    # announcing "roster drift found" about the one state this marker exists to say is fine. Caught by the
    # fixture on the first run. Same trap for any future marker text.
    Write-Host "  [ROSTER-PENDING] this repo was bootstrapped but the roster is still empty: $suppressedForRosterPending specialist(s) have a lens scaffold and no roster row in $rosterRel. Nothing is broken and nothing has drifted -- every lens is still an unfilled VUL-IN scaffold, so there is no work to have drifted from. Fill in the roster and the lenses at your own pace; this turns into real drift, reported per specialist, as soon as some of it is filled in and some is not." -ForegroundColor Yellow
}

if ($suppressedForLensNaming -gt 0) {
    # The seventh non-counting marker, and the first whose subject is THIS CHECK rather than the repo
    # (issue #2219). Its own line rather than folding under [BOOTSTRAP] or [ROSTER-PENDING]: both of
    # those say the repo has work left to do, and here the repo has none -- what is behind is the payload
    # doing the reading, which is the one thing no amount of editing in the repo can repair.
    #
    # NON-COUNTING, on the family's own rule: nothing is broken, and an exit 1 would put a red line in
    # every session of a repo that is entirely correct. The whole defect being repaired is a wall of
    # errors prescribing wrong repairs, so replacing it with one error would keep the habituation cost
    # this marker exists to remove.
    #
    # AND NO OTHER MARKER TOKEN IN IT EITHER, for a neighbouring mechanism rather than the same one: the
    # marker-column check (#2142) holds every verdict token to the start of its line, because
    # Select-CheckMarkerLine anchors to '^\s*' and a token mid-sentence would make the hook drop the line
    # it appears in. This text named the record-shape marker in passing while pointing at it, and the gate
    # refused the push -- so it says the words instead of the token.
    #
    # NO LITERAL '[ERROR]' IN THIS TEXT -- the same correctness rule [ROSTER-PENDING] carries above, for
    # the same mechanism: the session hook counts its error signals by matching that token over the whole
    # output, so a marker merely MENTIONING it would be counted as one and push the hook into the drift
    # branch it exists to keep this state out of.
    #
    # It names ONE example file rather than the list. The reader's move is to look in the lens directory,
    # where they see all of them at once; a marker that prints thirty filenames is the wall again in a
    # different colour. Sanitized with Format-SafePathToken because the value comes off disk and this
    # line is forwarded into session context by the hook -- the same treatment the import finding gets,
    # and the path-shaped sanitizer rather than the id-shaped one for the reason stated there.
    $lensNamingExample = Format-SafePathToken -Value (@($lensNamingFiles.Keys | Sort-Object)[0])
    Write-Host "  [LENS-NAMING] $suppressedForLensNaming specialist(s) would each have been reported without a repo-lens, and were held instead: this check cannot read the lens file naming this repo uses. Files such as '$lensNamingExample' name a specialist in a spelling this check has no vocabulary for, so each held finding would have prescribed creating a file that is already there under another name. NOTHING IN THE REPO NEEDS CHANGING. This check ships in the plugin and a session loads the last RELEASED payload, so the tree has moved on ahead of it: refresh the marketplace and update the plugins this repo enables ('claude plugin marketplace update <marketplace>', then 'claude plugin update <id> --scope <scope>'), and this line goes away on its own. READ THAT SCOPE OFF THE INSTALL RECORD rather than assuming 'project' (#1986) -- a plugin installed at 'user' or 'local' scope is not updated by a 'project' call, and the record-shape lines this check prints above are where such a record is reported. A specialist that is genuinely missing a lens is NOT held -- nothing in the lens directory names it, so its finding is still reported above." -ForegroundColor Yellow
}

Write-CheckSummary
