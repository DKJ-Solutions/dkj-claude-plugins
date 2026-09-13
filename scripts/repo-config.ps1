<#
.SYNOPSIS
    Repo-owned configuration for the workflow scripts (single source of truth for repo data).

.DESCRIPTION
    Dot-source this file from a script:

        . (Join-Path $PSScriptRoot '..\repo-config.ps1')   # from scripts/<folder>/
        . (Join-Path $PSScriptRoot 'repo-config.ps1')       # from scripts/ itself

    This is the small, local block of repo data that the (increasingly generic) workflow scripts
    read in. The scripts themselves are repo-agnostic; everything that differs per repo lives
    here. This way a change to the shared flow does not need to be checked in every consumer --
    only this file differs between life-hub, smartwatchbanden and the workshop.

    Supplies Get-RepoName and Get-RepoBlobUrl. Replaces the repo name that used to be hardcoded in
    open-pr.ps1, fold-changelog-entry.ps1 (2x) and cut-release.ps1 (via release-lib).

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script and
    could break loose code there (same reason as branch-info.ps1 / release-lib.ps1).

    Deliberately pure ASCII (repo convention for .ps1): Windows PowerShell 5.1 reads a BOM-less
    script as ANSI and would mangle an accented literal.
#>

# The GitHub repo where this workshop lives (owner/name). Single place this is stated.
$script:RepoName = 'DKJ-Solutions/dkj-claude-plugins'

function Get-RepoName {
    <# owner/name of this repo, e.g. for `gh ... --repo`. #>
    return $script:RepoName
}

# --- Names this repo has been renamed AWAY from (Dave, September 10, 2026; issue #1769) -----------
#
# A rename does not reach the files other repositories already hold. Three of this workflow's CI
# runners are scaffolded INTO a consumer and check this repository out by name --
# `repository: <owner>/<name>` -- so every consumer scaffolded before a rename goes on naming the old
# one. Those runners keep working, because GitHub answers a transfer redirect; what stops working is
# the GUARD over them. check-connectors' check 6 finds a runner by matching the name half of that
# `repository:` line, and after a rename it matches nothing -- so every consumer reads as clean, which
# is indistinguishable from being clean and is the exact silence #1805 was filed to end.
#
# SO THE RETIRED NAMES ARE DATA, not a sweep. They are read alongside Get-RepoName and never expire:
# a consumer's runner is repaired when that consumer is next touched for its own reasons, and until
# then the guard has to be able to see it. This is the same reasoning check 6 already carries for the
# old OWNER (its scenario 12c) -- a transfer left `DaveKJohn/` in consumers that still resolve -- one
# axis over: owner and name are renamed by different acts and expire on different days.
#
# NEWEST FIRST, and the list only ever grows. 'claude-code-specialists' was this repo's name until
# September 10, 2026. Read as an optional function, so a repo that has never been renamed simply does
# not define it and check 6 matches on the current name alone.
$script:RetiredRepoNames = @('claude-code-specialists')

function Get-RetiredRepoNames {
    <# Name halves this repo has previously been called, newest first. Empty = never renamed. #>
    return $script:RetiredRepoNames
}

function Get-RepoBlobUrl {
    <# Base URL for blob links to main, e.g. to make root-relative links absolute. #>
    return "https://github.com/$($script:RepoName)/blob/main/"
}

# --- Where the marketplace is published for the business organisation (Dave, August 14, 2026) ------
#
# scripts/release/publish-to-business.ps1 overwrites this repo with the marketplace subset of the
# workshop (manifest, plugins/, the reader-facing root docs), so Claude Enterprise can sync it as a
# plugin marketplace for colleagues without GitHub access. The target repo is repo data, so it is
# stated here -- the same rule that moved Get-RepoName out of open-pr and fold -- and the script reads
# it as an optional function with a fallback: absent or empty means "no publication target", and the
# script then requires -TargetRepo instead of guessing. -TargetRepo also overrides a filled-in value,
# for publishing the same set to a second organisation.
#
# The published repo keeps the marketplace NAME 'claude-code-specialists' even though it is called
# claude-plugins-bwj: the name is the key in every consumer's enabledPlugins
# ('dkj-subagents-alpha@claude-code-specialists'), so aligning it with the repo name would break that line in
# every consuming repo. Decision by Dave, August 14, 2026.
#
# AMENDED September 10, 2026 (#1769) -- the paragraph above stays as written, both readings legible.
# Dave has decided to rename this marketplace from 'claude-code-specialists' to 'dkj-claude-plugins',
# accepting the exact cost the August 14 reasoning identified (every consumer's enabledPlugins key
# breaks; no redirect for a marketplace name). It runs as a phased migration -- decision and plan on
# #1769, fase 0 was the prep branch.
#
# THE MIRROR FOLLOWS THE SOURCE'S NEW NAME. Decision by Dave, September 10, 2026. It was carried as an
# open fase 4 question until then, and that framing did not survive reading the script it would be
# carried out by: publish-to-business.ps1 GENERATES the mirror's marketplace.json rather than copying
# it, but only its 'plugins' array -- Remove-UnpublishedPlugins reads the source manifest, replaces
# $manifest.plugins with the keep-set and writes it back. It never touches $manifest.name, there is no
# name parameter (-TargetRepo, -Plugins, -RepoRoot, -Message, -Branch, -DryRun, -KeepClone is the whole
# surface), and no assignment to .name exists in the file. So 'the mirror follows' was never a choice
# to be made in fase 4 -- it is what the first publish after the fase 1 merge DOES, whoever runs it;
# and 'the mirror keeps the old name' would have required building a name override first. Dave took
# the default deliberately rather than by omission: one product, one name.
#
# WHAT THAT COSTS, so it is not discovered by a colleague instead: the mirror's own consumers are BWJ
# colleagues on Claude Enterprise, who key on '<plugin>@claude-code-specialists' exactly as a CLI
# consumer does and who are NOT in #1769's fase 2 list, because they have no checkout to prepare. They
# need the same migration, delivered through Claude Enterprise rather than a CLI, and the release
# notes of the flag-day cut are where it reaches them (fase 5).
#
# WHERE TO READ THE STATE, rather than a claim about it. The source-side rename landed with the fase 3
# flag day: .claude-plugin/marketplace.json and every '<plugin>@<marketplace>' literal in this tree
# read 'dkj-claude-plugins', in one movement with the repository rename, the major cut and the
# per-machine re-installs. #1769 carries the phase-by-phase record and the re-install ledger; the fase 0
# sentence 'no name is changed anywhere' described fase 0 and nothing since.
#
# THIS PARAGRAPH IS DELIBERATELY WRITTEN TO BE TRUE ON BOTH SIDES OF THAT MERGE, and that is a lesson
# rather than a style choice. It said 'FASE 1 IS BUILT, NOT MERGED' until September 10, 2026 -- an
# honest sentence that goes false at the merge, so the branch carried a step to rewrite it on the day.
# The trouble is WHERE that lands: open-pr refuses to push while a step above DEPLOY is unresolved, so
# the edit could only be made after the last chance to make it, and the flag day would have opened with
# a gate deadlock at the least convenient moment. A sentence that has to be corrected by the act it
# describes is a sentence to reword, not a step to schedule.
$script:BusinessMarketplaceRepo = 'BWJ-ecommerce/claude-plugins-bwj'

function Get-BusinessMarketplaceRepo {
    <# owner/name (or full git URL) of the business repo publish-to-business.ps1 publishes the
       marketplace subset to. Empty string means: no publication target configured. #>
    return $script:BusinessMarketplaceRepo
}

# --- Which plugins travel to that target (Dave, August 15, 2026; issue #683) ------------------------
#
# THE TARGET SERVES CLAUDE APP USERS, AND A WORKFLOW CANNOT WORK THERE. A workflow plugin is a method
# for moving work through a REPOSITORY -- branches, a changelog entry, a PR, a fold, a release cut --
# and every one of its skills ends in a PowerShell script run against a checkout. A Claude App user has
# no checkout, so offering them a workflow offers something that can only fail at the last step. THE RULE
# IS ABOUT THE KIND, NOT ABOUT THE ONE PLUGIN THAT CURRENTLY HAS IT: the seam below is an allowlist of
# teams, so a workflow is excluded by not being named rather than by being named, and a second workflow
# added later is excluded on arrival. It read 'both workflows' until issue #886 removed workflow-default
# and left one.
#
# WHY THIS IS AN EXCLUSION AND NOT A HIDE FLAG. The manifest format has no per-entry way to gate an
# entry, and inventing one would need Claude to honour it. A plugin that does not travel is not offered
# because it is not there -- the mechanism this repo already has, and the one that cannot be
# misconfigured into offering the thing anyway.
#
# THE UNIT IS THE PLUGIN, NOT THE ITEM, AND THAT IS DELIBERATE. dkj-subagents-alpha ships three PowerShell
# skills (specialists-init, specialists-teardown, sync-roster) and one SessionStart hook that a Claude
# App user cannot run either. They travel anyway: the plugin published here has to be byte-identical to
# the plugin released here, or its version number stops meaning one thing. Those four items are already
# handled where they can be handled without forking the plugin -- the hook is inert in a plain Chat
# session, and v4.9.0 (#672) made all three skills non-model-invocable and had each name its PowerShell
# dependency in its own description, so the model cannot walk a user into one. Per-item filtering would
# buy a little tidiness and cost the single-source-of-truth guarantee.
#
# AN UNSTATED SEAM MEANS WHAT IT MEANT YESTERDAY. Absent, empty or $null answers "every plugin in the
# manifest", which is what the script did before this function existed -- so a consumer that has never
# heard of it publishes exactly as it did.
$script:BusinessMarketplacePlugins = @(
    'dkj-subagents-alpha'
    'dkj-subagents-lifehub'
    'dkj-subagents-shopify'
    'dkj-subagents-ecomm'
)

function Get-BusinessMarketplacePlugins {
    <# The plugin NAMES (as in marketplace.json) that travel to the business target. An empty list
       means "all of them" -- the pre-#683 behaviour, and what an unstated seam has to keep meaning. #>
    return $script:BusinessMarketplacePlugins
}

# This repo's lint gate, repo-root-relative. open-pr.ps1 runs this before the PR. This is the
# only repo-specific part of open-pr: every consumer has its own lint (the workshop
# check-plugin-integrity, a Brains repo e.g. lint-brain). The test gate runs the convention
# (scripts/tests/*.tests.ps1) plus whatever the optional Get-TestCommands names (inbound #644);
# this repo deliberately defines none -- its suites are all PowerShell, so the convention IS the gate.
$script:LintScript = 'scripts\lint\check-plugin-integrity.ps1'

function Get-LintScript {
    <# Repo-root-relative path to the lint gate that open-pr.ps1 runs before the PR. #>
    return $script:LintScript
}

# WHICH CHECK'S GREEN PROVES THIS REPO'S TEST SUITES (issue #1715). open-pr skips its local test gate
# when this check is green on the exact commit it would ship -- see Get-CiTestCertificate in
# scripts/lib/gate-lib.ps1. Here that is 'lint-en-tests', the one context `main-ci-gate` requires,
# whose four `suites (1)`-`(4)` shards run the very same suites the local gate does.
#
# IT NAMES A CHECK RATHER THAN SAYING "ANY REQUIRED CHECK", and the difference is the whole safety of
# the skip. Two independent reviews of the first draft found the same hole from opposite sides: trusting
# whatever `gh pr checks --required` returns means a consumer whose trunk requires a CLA bot, a
# PR-title linter or a theme-check has its local test gate skipped the moment THAT goes green -- and,
# where a trunk requires two contexts, a green on the unrelated one certifies while the test check has
# not even registered yet (the registration race Get-RequiredCheckContexts documents in
# pr-issues-lib.ps1, in its partial-payload shape rather than its empty one).
#
# UNSTATED IS THE SAFE ANSWER: no name, no certificate, and the gate runs exactly as it did before this
# seam existed. That is why it is optional -- a consumer adopting the plugin gets today's behaviour
# until it deliberately says which of its checks carries this weight.
#
# NAME A CHECK THE TRUNK ACTUALLY REQUIRES. The certificate is read from the REQUIRED set, so a check
# this trunk does not require never certifies -- deliberately: skipping local proof on a check the merge
# does not depend on would lower the bar rather than move it.
$script:CiTestCheckName = 'lint-en-tests'

function Get-CiTestCheckName {
    <# The check context whose green proves this repo's test suites. Empty/absent = no certificate. #>
    return $script:CiTestCheckName
}

# The file that holds the roster (the specialists table/list). check-roster-sync.ps1 reads this to
# decide which agent ids are "present in the roster". Repo-root-relative; 'CLAUDE.md' by default.
# There is deliberately NO Get-RosterFormat: the check is format-agnostic (it scans the text for each
# <group>-<id> token), so it works whether the roster is a table or a list.
# The roster moved behind the seam (issue #221): CLAUDE.md now carries one import line and no roster,
# so check-roster-sync must read the inclusion instead. Getting this wrong is silent in the worst way --
# the check would find zero specialists in a file that legitimately has none, and report the whole roster
# as missing.
$script:RosterPath = '.claude/specialists/SPECIALISTS.md'

function Get-RosterPath {
    <# Repo-root-relative path to the file that holds the roster (specialists table/list). #>
    return $script:RosterPath
}

# Specialist ids ('<group>-<id>') that are ENABLED but deliberately have no roster row and no lens, so
# check-roster-sync.ps1 must not flag them as drift.
#
# EMPTY, and that is the normal state -- for this workshop as much as for a fresh consumer. Every
# enabled specialist belongs in the roster. Adopting one is the default and needs no approval (Dave,
# July 28, 2026): the lens scaffold is empty on purpose and may stay empty until that specialist has
# work here, so adopting costs a file nobody has to fill in today. See the sync-roster skill's
# SKILL.md for the full reasoning.
#
# Why this is worth a comment rather than just an empty array -- the list used to hold six ids, and
# none of them were ever a decision. It was introduced on 2026-07-20 by the very commit that built
# check-roster-sync (d2c8393), pre-populated with Paula/Vera/Gwen/Cody, and justified in this file as
# "a documented choice in CLAUDE.md". CLAUDE.md said no such thing: it said those specialists "rarely
# has work here and therefore has no repo lens (yet)" -- a statement about the current state, with an
# explicit "yet". The list converted "not yet" into "never report this", and then cited Dave for it.
# Auden (06-30) was added on 2026-07-24 as a blocking code-review finding whose stated reason was
# literally "so the roster hook does not flag Auden as drift after merge"; Bianca (03-02) was added on
# 2026-07-28 with the same reflex. Dave, asked about it, did not recognise the list as his.
#
# So the rule, in one line: a check that reports something inconvenient is not silenced by a list.
# If a specialist ever genuinely has no place in a repo, that goes here as a deliberate statement with
# a comment naming who and why -- written on your own initiative, never as a way to quiet a finding.
$script:RosterIgnoredIds = @()

function Get-RosterIgnoredIds {
    <# Ids of enabled agents/personas intentionally kept out of the roster/lenses (skipped by the
       check). #>
    return $script:RosterIgnoredIds
}

# --- RETIRED, AUGUST 5, 2026: Get-ChangelogTierHeadings ------------------------------------------
#
# This mapped tier -> the literal '## ' heading its entries were folded under, and CHANGELOG.md carried
# one section per tier: '## Tier 2 - Pull Requests' and its two siblings, in that order, so a reader met
# the changes that reach furthest first.
#
# CHANGELOG.md HAS NO SECTION HEADINGS ANY MORE. An entry IS an H3 and the document is an intro followed
# by a flat list of them, ordered tier-descending then significance-descending -- which keeps exactly what
# the three headings communicated, as an ordering rather than as structure. So there is no heading for
# this map to name.
#
# The fold and release-lib derive the intro/list boundary structurally instead (the first entry heading,
# from Get-EntryHeadingLevel), which is why the resolver that read this seam --
# Get-ChangelogTierSections in scripts/lib/entry-scaffold-lib.ps1 -- retired with it. The older
# single-section Get-ChangelogHeading (issue #178) is no longer read either, and was already absent here.
#
# Removed rather than left returning a value nothing reads, which is this file's own rule about
# write-once config. A consumer that still defines either function is unaffected: nothing calls them.

# Whether this repo has a separate "go live" stage after cutting a release -- e.g. a push to a live
# deploy target, distinct from the tag/GitHub Release. Empty by default: this workshop (like
# life-hub) cuts a release without one, so the cut-release skill's Block 2 (the live push + moving
# the '<- LIVE' marker) never applies here. A repo that DOES have a live stage (e.g. a theme repo
# pushing to a live Shopify theme) describes its target in this string; the cut-release skill then
# prints Block 2 using it. Optional in the contract (see check-script-contract.ps1): a consumer
# without this function simply gets Block 1 only, same pattern as Get-ChangelogHeading (#178).
$script:LiveStage = ''

function Get-LiveStage {
    <# Short description of this repo's "go live" push target for the cut-release skill's Block 2.
       Empty string means: no separate live stage -- the skill only prints Block 1 (cutting). #>
    return $script:LiveStage
}

# --- The stub wording new-branch.ps1 writes into an entry file (issue #410) ---------------
#
# The four strings below are the entire visible output of the shared new-branch.ps1: the title
# placeholder, the body heading, the fallback body, and the changelog type an unknown branch prefix
# falls back to. They used to be hardcoded in that script, which is fine for an English repo and wrong
# for any other -- the FILE it writes is repo-owned, so its wording is too.
#
# The concrete case (inbound #410, smartwatchbanden): a Dutch-language repo kept its own copy of
# new-branch.ps1 at the same relative path, purely to change these four strings. Two entry
# points then wrote two formats for the same branch -- the branch flow called the repo copy, the
# new-branch skill called the shared one -- which is exactly the duplication the skill exists to
# prevent. Dropping the copy fixed the duplication and cost them Dutch stubs; these functions give the
# wording back without the copy.
#
# All four are OPTIONAL in the script contract: a consumer that defines none of them gets the values
# below, which are also what the script hardcoded before. Same pattern as Get-ChangelogHeading (#178)
# and Get-LiveStage (#177). Four separate functions rather than one map-returning function, so the
# contract check can name the exact default per knob in its [INFO] line.
#
# TWO OF THEM ARE NOW GATE-ONLY (August 6, 2026). Since the branch/ split, new-branch.ps1 writes
# neither the body heading nor the old to-do placeholder -- branch-cycle.md carries the step list, and
# the entry's placeholder asks what the change DOES. The body heading stays defined here because it is
# still a marker open-pr refuses, so a consumer who translated it keeps a gate that recognises their
# wording rather than only the English one. See $script:EntryScaffoldDefaults in entry-scaffold-lib.ps1.
$script:EntryTitlePlaceholder = 'TODO: title'
$script:EntryBodyHeading      = '**To do / where I left off:**'
$script:EntryBodyPlaceholder  = 'TODO: what this change does, for whoever reads CHANGELOG.md later.'
$script:EntryFallbackType     = 'Chore'

function Get-EntryTitlePlaceholder {
    <# Placeholder title for an entry created without an explicit -Title. #>
    return $script:EntryTitlePlaceholder
}

function Get-EntryBodyHeading {
    <# The bold line above the entry body. Must be a single line; it is written verbatim. #>
    return $script:EntryBodyHeading
}

function Get-EntryBodyPlaceholder {
    <# Fallback body when no -Intent was given -- a directional prompt, not an empty placeholder. #>
    return $script:EntryBodyPlaceholder
}

function Get-EntryFallbackType {
    <# The changelog type an unknown branch prefix falls back to. Must be one of the types this repo's
       own branch table produces, since cut-release groups entries by it. #>
    return $script:EntryFallbackType
}

# --- Which files the mojibake tool examines by default (issue #413) -------------------------------
#
# scripts/maintenance/fix-mojibake.ps1 used to carry this list itself, and the list is workshop-shaped:
# it walks plugins/** for the manuals, agent defs and personas, and releases/** for the archived notes.
# In a consumer neither directory exists, so the tool's own Test-Path filter quietly reduced the set to
# whatever root docs happened to be there -- a gate that examines almost nothing while reporting
# "clean". Which files a repo has is a property of the repo, so the list belongs here.
#
# Takes the repo root as a parameter rather than resolving one of its own: the caller has already done
# that (dual-context, CLAUDE_PROJECT_DIR or the git root), and a second resolution here is a second
# answer to a one-answer question. The Get-ChildItem work sits INSIDE the function on purpose -- this
# file is dot-sourced by every workflow script, and none of the others should pay for a directory walk
# they never use.
#
# OPTIONAL in the contract: a consumer without this function gets the tool's own repo-agnostic
# fallback -- every *.md in the repo root, which covers the changelog, the root docs and the unfolded
# entry files in any repo. That fallback is deliberately broader than what this workshop's list used to
# be, because an entry file is exactly the kind of freshly written, non-ASCII-carrying file the damage
# shows up in first.
function Get-MojibakePaths {
    <# Absolute paths of the files fix-mojibake.ps1 examines when called without -Path. #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    # Every markdown file in the repo root: README.md, CLAUDE.md and the rest of the root docs. It named
    # CHANGELOG.md first until August 27, 2026, when that file moved into contributing-davekjohn/ and so
    # arrives through the recurse below instead.
    $paths = @(Get-ChildItem -LiteralPath $RepoRoot -Filter '*.md' -File |
        Select-Object -ExpandProperty FullName)

    # dkj-policy/ -- the workflow's own root folder, which holds the branch's entry and step list
    # (under branch/, covered by the root glob above until the split moved them on August 6, 2026, and
    # under this folder since August 14, 2026; the folder itself renamed off 'workflow-davekjohn/' on
    # August 26, 2026, #886, and off 'contributing-davekjohn/' on September 5, 2026, #1437). The entry is
    # the single highest-value file in this set: its text is pasted
    # verbatim into CHANGELOG.md and from there into the release notes, so a mis-decode caught anywhere
    # later has already been copied twice.
    # -Recurse covers the folder's other pages -- the release notes under releases/audience/ and, in a
    # consumer, the scaffolded docs. It also covered branch/templates/ until the merged development document
    # retired that directory on August 23, 2026.
    # EVERY NAME IS SCANNED, and the reason is what this check is for: a repo mid-rename has prose in
    # whichever folder it still uses, and a mojibake check that silently skips the folder a consumer
    # actually has is worse than no check -- it reports a clean run over nothing.
    foreach ($workflowFolderName in @('dkj-policy', 'contributing-davekjohn', 'workflow-davekjohn')) {
        $workflowDir = Join-Path $RepoRoot $workflowFolderName
        if (Test-Path -LiteralPath $workflowDir) {
            $paths += @(Get-ChildItem -LiteralPath $workflowDir -Recurse -Filter '*.md' -File |
                Select-Object -ExpandProperty FullName)
        }
    }

    # Every markdown file under plugins/: the manuals, agent defs, personas and skill pages -- all prose,
    # all equally able to carry a mis-decode. It used to name the per-plugin CHANGELOG.md and RELEASE.md
    # first; those were retired on August 8, 2026 and the rest of the set is unchanged.
    #
    # -Filter, NOT -Include, and that is a bug fix rather than a preference. PowerShell SILENTLY IGNORES
    # -Include when the path is given as -LiteralPath, so the previous form --
    # `Get-ChildItem -LiteralPath $pluginRoot -Recurse -File -Include 'CHANGELOG.md','RELEASE.md'` --
    # returned EVERY file under plugins/, .ps1 and .json included, while the comment above it named two
    # file names. Nothing broke, because the extra files were clean and the tool leaves anything that is
    # not mojibake alone; what was wrong is that the code and its own description disagreed, and the
    # description is what the lint gate quotes to the reader as its coverage. Worth keeping now that the
    # two named files are gone: the WIDE set is what this function has actually returned all along.
    $pluginRoot = Join-Path $RepoRoot 'plugins'
    if (Test-Path -LiteralPath $pluginRoot) {
        $paths += @(Get-ChildItem -LiteralPath $pluginRoot -Recurse -File -Filter '*.md' |
            Select-Object -ExpandProperty FullName)
    }

    # THE ARCHIVED RELEASE NOTES, added August 2, 2026 after they turned out to hold the largest single
    # concentration of damage in the repo (474 sequences in 3.1.0.md alone, more than the root
    # changelog). They sit outside the language rule because they are history, but the two questions are
    # not the same: not translating an old note preserves what it said, while leaving mojibake in it
    # preserves a mis-decode nobody wrote.
    #
    # THIS REPO NO LONGER HAS THAT DIRECTORY (August 27, 2026): its notes sit under
    # dkj-policy/releases/ and arrive through the recurse above. The block stays, because the
    # Test-Path is what makes it correct rather than stale -- a repo that still keeps notes at its root
    # gets them scanned, and one that does not pays a single Test-Path. Removing it would narrow a
    # consumer's coverage to buy nothing here.
    $releasesRoot = Join-Path $RepoRoot 'releases'
    if (Test-Path -LiteralPath $releasesRoot) {
        $paths += @(Get-ChildItem -LiteralPath $releasesRoot -Recurse -File -Filter '*.md' |
            Select-Object -ExpandProperty FullName)
    }

    return @($paths | Sort-Object -Unique)
}

# --- How ship-pr.ps1 merges a PR (issue #411) -----------------------------------------------------
#
# 'merge', 'squash' or 'rebase' -- the flag ship-pr.ps1 hands `gh pr merge`. This workshop merges, so
# every PR keeps its own commits on main; a repo that squashes says so here instead of keeping a
# private copy of ship-pr.
#
# Declared even though inbound #411 argued a shared ship-pr would need NO new contract function. That
# claim did not survive reading both files: the source merges with --merge while the reporting repo
# describes its own flow as squash-merging, so the two genuinely differ on exactly this, and a shared
# script with a hardcoded --merge would silently impose one repo's policy on the other. OPTIONAL, with
# 'merge' as the fallback, so nothing changes for a consumer that does not care.
$script:PrMergeMethod = 'merge'

function Get-PrMergeMethod {
    <# The merge method ship-pr.ps1 uses: 'merge', 'squash' or 'rebase'. #>
    return $script:PrMergeMethod
}

# --- Machine-local tracked paths -- files a `git add -A` can sweep into a branch (issue #1559) ----
#
# A tracked file that a person edited for THEIR OWN clone -- .claude/settings.json with four extra
# plugins enabled locally and "autoUpdate": false -- rides into a branch commit on a `git add -A` and
# past every gate: measured on PR #1557, where it reached the merge queue. The scaffold, step-list,
# backing, impact and link gates all read the branch's development document, never the diff's file
# set; the backing gate reads the diff but asks the opposite question (work MISSING from the commit,
# not surplus in it). So open-pr.ps1 probes this list and, when the branch's committed diff touches
# one of these paths, says so -- twice, advisory, never a refusal. The refusal shape was declined in
# the issue on purpose: a branch that legitimately changes the shared settings file must not need an
# escape valve, and this repo has scar tissue from findings-list gates (the stale-path check, 124
# findings, all false).
#
# The sanctioned home for a MACHINE'S OWN enablement is .claude/settings.local.json, which is
# gitignored -- so the note points there, for that case and no other. #303 (v3.0.7) already
# documented that `claude plugin install --scope project` writes enabledPlugins into the tracked
# settings.json; this is the gate side of the same class.
#
# BUT THE FILE ITSELF IS NOT MACHINE-LOCAL, and the note must not read as though it were (#1574).
# What settings.json declares is a shared, tracked answer every clone inherits, so a branch whose
# subject IS that declaration -- a plugin added to the enabled set, one turned off -- is the happy
# path, and this gate fires on it: measured on PR #1573, a branch that existed to make that change.
# The note states BOTH cases and prescribes the move only for the clone's own edit. Wrong advice on the
# intended path is how an advisory note gets scrolled past, and it is then scrolled past on the day it
# is right -- the failure the neighbouring Shopify floor check argues against in its own .DESCRIPTION
# ("a check that goes quiet for the right-looking reason is worse than one that speaks").
#
# OPTIONAL and probed with Get-Command, following Get-PrAssignee / Get-PrDescriptionPlaceholder
# rather than the script contract: absent or an empty return means "nothing is machine-local here"
# and the gate stays silent. A repo-root-relative path; end an entry with '/' to match a whole
# directory rather than one file.
$script:MachineLocalPaths = @('.claude/settings.json')

function Get-MachineLocalPaths {
    <# Repo-root-relative paths whose edits belong to a clone, not the tree. open-pr.ps1 reports
       (never refuses) when the branch's committed diff touches one. A trailing '/' matches a
       directory. Return @() to disable the check. #>
    return $script:MachineLocalPaths
}

# --- THIS REPO HAS NO SHOPIFY STORE, AND SAYS SO (issue #1579; the seam from inbound #1570) --------
#
# dkj-subagents-shopify is enabled here and this repo is not a store. It is on for validation: the repo
# that ships a plugin is also a repo that loads it, so an agent def, a manifest, a frontmatter or a
# hook that stops resolving surfaces at this repo's own session start instead of in somebody else's.
# The repo slot in CLAUDE.md states that reason, for all four add-on teams at once.
#
# WHICH LEFT THE FLOOR CHECK ASKING A QUESTION THIS REPO CANNOT ANSWER TRUTHFULLY.
# shopify-floor-sessioncheck.ps1 wants Get-ShopifyLiveThemeId -- the live theme's numeric id -- because
# the live-theme guard is armed for publish, delete and an '--allow-live' push and cannot recognise a
# push aimed at live BY ID without it. With no store there is no such id: seeding one would arm that
# guard over a revenue-serving theme on a number nobody verified, and a 'VUL-IN' placeholder reads as
# forgotten. So the check reported an [ERROR] at every session start here -- correctly, and forever.
#
# ANSWERING IS NOT SILENCING, and that distinction is the whole reason this function exists rather
# than a seeded id. inbound #1570 (PR #1578) gave the check the third state it lacked: a repo declares
# it has no store, and the half-armed finding goes quiet -- exactly as it does for a repo that HAS
# answered the id. What makes that safe is that it follows a deliberate, self-authored DECLARATION and
# never an inference the check drew from the tree (a theme directory, a shopify.theme.toml). It
# suppresses that first finding ONLY; the duplicate-guard finding beside it is independent and still
# speaks. This repo's own rule for such lists applies unchanged -- a check that reports something
# inconvenient is not silenced, it is answered (see Get-RosterIgnoredIds above, which is empty for it).
#
# OPTIONAL, probed with Get-Command -- like Get-MachineLocalPaths above rather than via the script
# contract. Absent, which is every store repo, means "this repo has a store": the answer the check
# acted on before the seam existed. The check dot-sources this file with StrictMode OFF in a child
# scope, so the function takes no parameters and does nothing but answer.
#
# THE DAY THIS REPO GETS A STORE, THE FUNCTION GOES rather than being flipped to $false. Both readings
# mean the same thing to the check, and only removal takes this comment with it -- a stated $false
# would leave the paragraphs above describing a repo that no longer exists.
$script:ShopifyRepoHasNoStore = $true

function Get-ShopifyRepoHasNoStore {
    <# $true when this repo enables dkj-subagents-shopify without owning a store, which is what stops
       shopify-floor-sessioncheck.ps1 asking for a live-theme id this repo cannot truthfully give.
       Remove the function outright if this repo ever gets a store. #>
    return $script:ShopifyRepoHasNoStore
}

# --- What cut-release.ps1 does differently per repo (issue #417) -----------------------------------
#
# cut-release.ps1 became a SHARED script in #417, after an audit in a second consumer found the two
# repos running two independently evolved files of the same name. The stated goal is that both repos
# run exactly the same release workflow, and the inbound issue named three divergences. Reading both
# files found SIX, and the largest one was not on that list -- so the knobs below are what the
# measurement produced rather than what the report predicted:
#
#   1. where the notes are grouped        Get-ReleaseNotesGrouping    (named in the issue)
#   2. the consumer tier                  Get-ReleaseConsumerBumps    (named in the issue)   RENAMED Aug 10
#   3. the LIVE marker                    Get-ReleaseLiveMarker       (named in the issue)   RETIRED Aug 5
#   4. the plugin/marketplace half        Get-ReleasePluginTier       (NOT named -- the largest block)
#   5. the category labels                Get-ReleaseCategoryTitles   (NOT named)            RETIRED Aug 5
#   6. the permanent root docs            Get-ReservedRootMd          (NOT named)
#
# TWO OF THE SIX ARE GONE (August 5, 2026), and both for the same reason rather than two: the flat
# changelog. Knob 3 marked the live row of a release section CHANGELOG.md no longer has; knob 5 labelled
# category headings the release documents no longer have. Each retirement is written out at the place it
# used to sit, below. Recorded here too because this list is the record of what the #417 measurement
# found, and a list that quietly shrinks stops being that.
#
# KNOB 2 LANDED IN PHASE 2 AS THREE FUNCTIONS AND IS BACK TO ONE (August 5, 2026). "The consumer
# tier" was three independent questions -- whether, for whom, and in whose words -- and the second and
# third existed only to configure the remove-before-publishing marker. The tier model retired that
# marker (see the block further down), which retired both knobs with it: what a consumer notices is now
# declared per entry rather than guessed per branch type. Only 'whether, and for which bump types'
# survives, because that is the one question the entries cannot answer for the repo.
#
# ALL SIX ARE OPTIONAL in the script contract, and every fallback is this workshop's CURRENT
# behaviour -- so a consumer that defines none of them gets exactly what the unshared script did.
# Same pattern as the changelog section headings (#178, now the tier map) and the entry-stub wording
# (#410).

# 'major' -> <changelog root>/<X>.x/<X.Y.Z>.md   (this workshop)
# 'minor' -> <changelog root>/<X.Y>/<X.Y.Z>.md   (a repo that cuts often enough for that to help)
$script:ReleaseNotesGrouping = 'major'

function Get-ReleaseNotesGrouping {
    <# How the generated release notes are foldered: 'major' or 'minor'. #>
    return $script:ReleaseNotesGrouping
}

# --- RETIRED, AUGUST 5, 2026: Get-ReleaseLiveMarker ------------------------------------------------
#
# The "this is the version currently live" suffix Convert-ChangelogForRelease moved from the previous
# release row onto the new one. There are no release rows in CHANGELOG.md any more -- a cut empties the
# document down to its intro -- so the marker has nothing to sit on and nothing to be moved from.
#
# It was EMPTY here throughout its life, and that was never an oversight: a marketplace has no live stage,
# so there is no such thing as the live version -- consumers install from `main` at a moment of their own
# choosing. Get-LiveStage above is a different question and stays: "do you have a live stage" is prose the
# cut-release skill reads to decide whether to print its live-push block, where this was a string a script
# wrote into a file. A repo could always have the first without wanting the second, and now only the first
# exists.

# --- Where this repo keeps its release history (Dave, August 4, 2026) -----------------------------
#
# THE MEASUREMENT BEHIND THIS PATH BECOMING LOAD-BEARING. CHANGELOG.md used to carry an accumulating
# release section that had grown to 434 of the file's 1,062 lines -- 41% -- across 72 blocks that each
# said no more than "see the notes". Every one of those 72 versions was ALSO in releases/README.md, with a
# date, a type and a descriptive title: verified in both directions, zero missing either way. So the
# section was not a long list but a poorer copy of a better one, and the changelog's own subject -- what
# changed since the last release -- was sitting under it.
#
# Get-ReleaseHistoryMode retired on August 5, 2026, and this is the other half of that same measurement
# playing out. It chose between 'all' (a block per release) and 'latest' (only the newest, behind a
# pointer); the flat changelog keeps NEITHER, because a cut now empties the document down to its intro.
# There is no mode left to select, and the file below is not "where the pointer points" any more but the
# only list of releases there is.
#
# THE PRECONDITION IS THEREFORE ABSOLUTE RATHER THAN A CAUTION: this file must really list every release,
# because from now on nothing else does. It did before this change too -- that is what made removing the
# blocks safe rather than lossy.
#
# The path answers ONE question and three things read it: the guardrail that checks which major a new row
# would land in, the inserter that writes that row, and new-internal-note.ps1, which repoints that row's
# Version cell at the internal note once the note exists. One edit here moves all three.
#
# IT IS BACK AT THE DEFAULT, releases/README.md, since August 19, 2026 (Dave), and the round trip is the
# instructive part. It moved to the workflow folder on August 14 with the hand-kept release pages, on the
# reasoning that everything the workflow owns gathers in the workflow's own folder. That swept up one
# thing the workflow does NOT own: a repo that has cut releases has a HISTORY, whichever tooling cut it,
# and an index of files living in releases/ had no business sitting in a plugin folder that a teardown
# removes. The audience notes stayed behind deliberately -- those exist only BECAUSE the tier model does,
# so they are the workflow's; the list is not. The list lived in its own HISTORY.md for one day
# (August 4, 2026), on the reasoning that one
# page should describe the process and another the outcome. That reasoning was superseded the same day:
# the pages had since been reorganised portable-half first with everything repo-specific in one named
# slot, and once that split exists, process-versus-outcome stops earning a file boundary -- the outcome
# IS repo-specific content, so it is simply the last section of the slot. Merging them also removed four
# cross-references the two pages needed to introduce each other, and left a consumer with one file to
# mirror instead of two.
# UNDER contributing-davekjohn/ SINCE AUGUST 27, 2026 (Dave), which REVERSES the August 19 answer
# recorded three paragraphs up -- amended rather than silently flipped, so both readings stay legible.
# That answer sent the list back to the repo root on one premise: an index of releases had no business
# sitting in "a plugin folder that a teardown removes". THE PREMISE EXPIRED BEFORE THE ANSWER DID.
# Issue #885 settled that dkj-policy/ is PERMANENT -- no command in this plugin removes it and
# no future teardown may, precisely because it holds a repo's own changelog and release history -- and
# UNINSTALL.md's "what is left behind" list says so to every consumer. Once that is true the durability
# worry is answered a different way, and the folder is the safer home rather than the riskier one. It is
# also the answer the computed default has been giving every CONSUMER since #885; the source was the
# holdout, on a reason that no longer holds.
#
# THE FILENAME CHANGES WITH THE MOVE, and that is not cosmetic: this folder's own 'releases/README.md' is
# its seam-ANSWERS page. The list and the answers are two different documents that shared a filename only
# because they sat at different directory levels. 'history.md' is the name Get-DefaultReleaseHistoryPath
# already computes for a consumer, so the source stops being the one repo that names it differently.
#
# AND UNDER dkj-policy/ SINCE SEPTEMBER 5, 2026 (#1437), when the folder renamed with the plugin it is
# named after. The seam VALUES below carry today's name; every dated sentence around them keeps the name
# it was written with, which is the #952 rule.
$script:ReleaseHistoryPath = 'dkj-policy/releases/history.md'

function Get-ReleaseHistoryPath {
    <# Repo-root-relative path to the file that lists every release this repo has cut. #>
    return $script:ReleaseHistoryPath
}

# --- Where this repo keeps its changelog (Dave, August 27, 2026) -----------------------------------
#
# THE SAME MOVE, ON THE SAME DAY AND FOR THE SAME REASON as the release history above -- read that record
# first. Get-DefaultChangelogPath computes 'CHANGELOG.md' for a repo that publishes plugins, i.e. for the
# workflow's SOURCE, and 'dkj-policy/CHANGELOG.md' for everybody else. This repo is the source
# and now answers the consumer's way, so the seam has to be stated rather than left to the default.
#
# NOT A CHANGE OF MIND ABOUT THE DEFAULT. The default is right about what a repo adopting this workflow
# should get and says nothing about what THIS repo prefers; the seam exists for exactly this, a repo that
# wants to differ from its computed answer. Nothing about a consumer changes here.
#
# WHAT IT COSTS. A relative link inside a changelog entry now resolves from dkj-policy/ rather
# than from the repo root, because that is where the fold pastes it. new-branch composes the branch
# document's guidance from this very seam, so a writer is told the right thing without having to know it,
# and check-plugin-integrity validates each entry's links against the same resolved location.
$script:ChangelogPath = 'dkj-policy/CHANGELOG.md'

function Get-ChangelogPath {
    <# Repo-root-relative path to the changelog the fold writes into and the cut empties. #>
    return $script:ChangelogPath
}

# Where the generated internal note (tier 1) is written. Stated for one reason: without it
# Get-DefaultReleaseInternalNotesRoot would answer 'releases/internal' here -- the source branch of that
# default -- and recreate a root releases/ directory the August 27, 2026 move above just emptied. The
# other two generated roots (changelog/, github/) need no statement: their defaults stopped branching on
# the source at #914 and already point into this folder.
$script:ReleaseInternalNotesRoot = 'dkj-policy/releases/internal'

function Get-ReleaseInternalNotesRoot {
    <# Repo-root-relative directory the generated internal (tier 1) note is written into. #>
    return $script:ReleaseInternalNotesRoot
}

# Where the hand-written release note goes -- the one document with a named section per reader, since the
# consumer note and the internal note merged (August 10, 2026). Declared here rather than left to the
# fallback, even though it IS the fallback, because this repo is the source: a knob nobody states is a
# knob the next reader has to go find in a script to learn exists.
#
# The per-release folder inside it comes from Get-ReleaseNotesGrouping, so this is the root alone. It was
# 'releases/highlights' until the rename that named each document for its reader, and the DIRECTORY moved
# with it -- this is not a compatibility fallback, and a repo still holding notes under the old name says
# so here rather than relying on anything to guess.
#
# 'releases/audience' SINCE AUGUST 12, 2026 (Dave; inbound #620), completing the same naming rule one step
# further. Every note root now names WHO reads it: changelog/ (development/ until #914) is the record for
# this repo's own developers, github/ is the generated Release body, audience/ is the one hand-written
# document written for whoever this repo publishes to. 'notes/' named the FORM -- the mistake 'highlights/'
# made, caught two days later in the sibling it was renamed alongside rather than in itself. It is also the
# root that has to agree with Get-ReleaseAudienceTier: the tier says which reader, so the directory should
# not say something orthogonal to it.
#
# THE SHARED DEFAULT IS DELIBERATELY *NOT* MOVED WITH IT. cut-release.ps1 and build-release-notes-page.ps1
# still fall back to 'releases/notes', and script-contract-lib still records that as the Default, because
# an unstated seam has to keep meaning what it meant yesterday. A consumer who never answered this knob has their
# documents in releases/notes/ right now and receives these scripts through a plugin update rather than by
# choosing to -- moving the fallback would have the cut write to a root nobody has and the reader look in a
# root nobody filled, reported as "no release note was found", which reads as a repo that has not cut one.
# This is a repo-level rename, so it is stated here, which is the only place that can state it.
#
# UNDER contributing-davekjohn/ SINCE AUGUST 14, 2026 (Dave; the folder renamed off workflow-davekjohn/ on
# August 26, #886, and on to dkj-policy/ on September 5, #1437). It moved together with the release
# history that day, which went back to the repo root on August 19 while this stayed -- the split the
# paragraph below finishes. The
# hand-kept release pages are the workflow's portable belongings, so they live in its folder -- the same
# answer the adopt-workflow-folder scaffold proposes to every consumer.
#
# AND THE GENERATED TREES FOLLOWED ON AUGUST 26, 2026 (Dave; issue #914). This block used to say they
# stayed at the repo root deliberately -- "the machine-written record and the publish artefact", with
# roots "hardcoded by design". Both halves of that reason expired: #885 gave each of them a seam, so
# nothing is hardcoded any more, and once they are seams the question is no longer what THIS repo does
# but what every repo's default should be -- and a tree nothing writes but a cut exists only because the
# workflow does, exactly like the hand-written note that was already in the folder. So the three note
# roots are siblings now, and releases/ holds nothing but the release LIST. THAT LIST FOLLOWED THEM ON
# AUGUST 27, 2026 (Dave) and the root releases/ directory is gone -- this paragraph used to end by saying
# it had not, on the reasoning that a repo that has cut releases has a history whichever tooling cut it.
# That reasoning was about durability rather than ownership, and Get-ReleaseHistoryPath's own record above
# is where it is answered. The history-table row and the note's link prefix are both computed from these seam values, which is
# what makes each of these repointings a few lines rather than a dead-link generator.
$script:ReleaseNoteRoot = 'dkj-policy/releases/audience'

function Get-ReleaseNoteRoot {
    <# Repo-root-relative directory the hand-written release note is written into and read back from. #>
    return $script:ReleaseNoteRoot
}

# Whether cut-release runs the plugin/marketplace half: enumerating the manifests from
# .claude-plugin/marketplace.json and bumping every plugin.json in lockstep. TRUE here -- that half IS
# this repo's release. It also wrote a consumer-facing CHANGELOG.md and RELEASE.md card per plugin
# until August 8, 2026; the lockstep bump is what the half is now.
#
# THE ONE KNOB WITH A COMPUTED FALLBACK, and the reason is that its answer is a fact rather than a
# preference: a repo with no .claude-plugin/marketplace.json has no plugins to bump, so a consumer
# that never heard of this function gets the right behaviour without stating anything. Stated
# explicitly here anyway, because in THIS repo the answer is load-bearing and a release that
# silently skipped the lockstep bump would be discovered by a consumer rather than by a gate.
$script:ReleasePluginTier = $true

function Get-ReleasePluginTier {
    <# $true if this repo publishes plugins whose versions cut-release must bump in lockstep. #>
    return $script:ReleasePluginTier
}

# --- RETIRED, AUGUST 5, 2026: Get-ReleaseCategoryTitles -------------------------------------------
#
# Display labels for the release-notes category headings, keyed on the branch types: Feat -> Features,
# Fix -> Fixes, Docs -> Documentation, Chore -> Maintenance, plus an 'Other' catch-all. It existed for a
# non-English consumer, where an unlabelled type degrades to the type NAME -- the wrong word rather than a
# missing one, precisely the #410 case.
#
# THE RELEASE DOCUMENTS HAVE NO CATEGORY HEADINGS ANY MORE. They are ranked lists of changes, exactly as
# CHANGELOG.md is, and each change states its own type inside it under a '### Type of change' section. So
# there is no heading for these labels to be the text of.
#
# WHY THE GROUPING WENT, since retiring a whole seam deserves the reason: the grouping was derived from the
# BRANCH PREFIX, which this repo measured does not predict what a change is worth -- the single most
# consequential change for a consumer at v3.2.0 arrived on a chore/ branch. So the grouping put a
# document's most important change third, under whichever label its prefix produced, and the significance
# ranking added in #467 could only reorder the categories rather than escape them.
#
# It was EMPTY here throughout, which was the correct state for an English repo. A consumer that still
# defines it is unaffected: nothing calls it.

# The permanent root *.md files that are NOT unfolded changelog entries. cut-release treats every
# OTHER root *.md as an entry somebody forgot to fold (deliberately catch-all, so an entry with an
# unknown branch prefix is never missed), and refuses to cut while one exists.
#
# THIS LIST HAS GONE STALE THREE TIMES AND EACH TIME IT BLOCKED A RELEASE OVER A DOCUMENT NOBODY HAD
# FAILED TO FOLD: #165 first, then QUICKSTART.md + UNINSTALL.md in #405 when flattening moved them to
# the root, then ADOPTION.md in #408. It lived in the script until now, which made it a fourth thing a
# consumer would have had to fork the script over -- so it moves here, where the answer actually
# lives. Add a new permanent root doc here, and nowhere else.
# AND THE THREE IT BLOCKED OVER ARE OFF IT AGAIN, because they left the root for plugins/. Keeping them
# would not have blocked anything -- an allowlist entry for a file that is not there is inert -- but it
# would have made the list describe a root that no longer exists, and it would have SILENCED the one
# signal worth having: a QUICKSTART.md reappearing in the root now means somebody moved it back by
# accident, and cut-release should say so rather than wave it through.
# CHANGELOG.md AND CONTRIBUTING.md STAY ON, THOUGH THEY LEFT THE ROOT ON AUGUST 27, 2026, and that is the
# one place the paragraph above does NOT generalise. Taking them off was tried the same day, on its
# reasoning -- an inert entry describes a root that no longer exists, and a CHANGELOG.md reappearing there
# would be worth a word. It broke the cut, loudly and correctly: this list is read by the PORTABLE
# cut-release to decide which root *.md files are permanent documents rather than unfolded entries, and a
# repo that keeps its changelog at the root -- every fixture in cut-release-drive.tests.ps1, and any
# consumer that answers the seam that way -- then has its own changelog reported as an entry somebody
# forgot to fold, which refuses the release. So the list is about the NAME of a permanent document, not
# about whether this particular repo currently has one at its root, and the two names belong on it as long
# as any repo reading this file might.
$script:ReservedRootMd = @(
    'CHANGELOG.md', 'CLAUDE.md', 'README.md', 'LICENSE.md', 'CONTRIBUTING.md', 'SECURITY.md',
    # INSTALL.md and UNINSTALL.md moved here from plugins/ on August 14, 2026 (inbound #664). They are
    # install plumbing, not plugin payload, so the folder boundary is what keeps them out of the set
    # published to a business marketplace -- the same reason connectors/ sits at the root. Listing them
    # here is not bookkeeping: without it the next unfolded-entry scan reads two permanent documents as
    # changelog entries somebody forgot to fold.
    'INSTALL.md', 'UNINSTALL.md'
)

function Get-ReservedRootMd {
    <# File names in the repo root that are permanent docs rather than unfolded changelog entries. #>
    return $script:ReservedRootMd
}

# --- The consumer tier: whether, and for which bumps (issue #417 knob 2; narrowed August 5, 2026) ---
#
# NAMED FOR ITS READER SINCE AUGUST 10, 2026 (Dave). This tier was called "highlights" everywhere --
# the directory, this seam, the renderer -- and that name described the FORM (a selection of the nice
# bits) rather than the audience. Its two neighbours name their reader (development = this repo's own
# developers, internal = the organisation), and the tier table one screen up has always said tier 2 is
# "consumers", so this was the one of the three whose name disagreed with the model it belongs to.
# Measured before renaming: of five dev-tool changelogs in the field (Linear, Stripe, Vercel, Raycast,
# GitHub) not one publishes anything called "highlights" -- the live names are "Changelog", "Release
# notes" and "What's new", all of which name the document or its reader. The form-name was also
# earning its keep in the wrong direction: it invited the register a self-selected best-of invites,
# which is exactly what v4.0.0's document was reviewed and found guilty of.
#
# The hand-written rendering of a release: releases/notes/<dir>/<X.Y.Z>.md. Written for NON-DEVELOPERS
# (Dave, July 13, 2026), and since the tier model its consumer section is assembled from the TIER-2
# ENTRIES rather than from a category guess plus a marker somebody deletes by hand. MARKDOWN ONLY -- the
# tier briefly also generated a print-ready .html and no longer does anywhere (Dave, August 3, 2026);
# whoever wants a PDF renders the markdown with a real tool.
#
# ONE DOCUMENT WITH A NAMED SECTION PER READER SINCE v4.3.0 (Dave, August 10, 2026), not two. It used to
# be releases/consumer/ beside releases/internal/, and at all twelve releases since the internal tier
# existed both were written about the same changes. The paragraphs below described that retired shape for
# two releases after the script stopped running it -- inbound #605 -- which mattered more here than in an
# ordinary comment: adopt-config copies this text VERBATIM into a consumer's own repo-config, so a stale
# description ships as their committed documentation of a directory the script will never write.
#
# ON IN THIS REPO SINCE AUGUST 3, 2026, for minor and major only -- Dave's decision, and it reversed
# what this file said one commit earlier. The reasoning that had it off was that this repo's release
# audience "is developers", so a stakeholder document would have no reader. That was the wrong unit of
# analysis: the audience question is not developer-vs-not, it is WHO DECIDES WHETHER TO UPDATE. That
# reader does not want the full per-PR record, and giving them only the developer notes is the same
# mismatch a storefront repo has with its management -- one tier serving two audiences badly.
#
# So this repo writes two documents per release plus a generated announcement:
#   dkj-policy/releases/changelog/<X>.x/<X.Y.Z>.md  tier 0  developers  -- every release, complete, raw
#   dkj-policy/releases/audience/<X>.x/<X.Y.Z>.md   tiers 1+2         -- minor/major here, hand-written
#   dkj-policy/releases/github/<X>.x/<X.Y.Z>.md     generated         -- every release, the announcement
#
# EACH ROOT ANSWERS ONE QUESTION, WHICH IS WHY THE BODY HAS ITS OWN (Dave, August 12, 2026). The generated
# announcement used to be written into the tier-0 root as '<X.Y.Z>-github-body.md' -- the one generated
# document that DOES get published, inside the directory whose whole job is the record nobody publishes.
# changelog/ is the record, github/ is the generated published document, and the hand-written one is the
# third root. The suffix went with the move: the root says it, and both siblings are '<X.Y.Z>.md' already.
#
# THE SECTIONS INSIDE THE NOTE FOLLOW THE TIER, while whether the note EXISTS follows the bump. Its
# organisational section ("what it is worth") applies to every release the seam names; its consumer
# section is written only when there are tier-2 entries, because a section about work no consumer can see
# is worse than no section -- it looks written. A patch gets no hand-written document at all and is
# announced by the generated body alone.
#
# THE TIER NUMBER AND THE SECTION ARE THE SAME SCALE, which is the point of the renumbering (Dave,
# August 5, 2026 -- they were 1/2/3 before, one off from the entries they describe). A tier-1 entry
# reaches the organisational section; a tier-2 entry reaches the consumer section AND, the ladder being
# cumulative, the organisational one as well. The development note carries everything, tier 0 included,
# because it is the record.
#
# PER MAJOR, NOT PER MINOR (Dave, August 3, 2026). The consumer this came from folders its notes per
# minor; this repo keeps <X>.x for all three tiers, which Get-ReleaseNotesGrouping above already says
# and every tier reads from that one answer rather than restating it.
#
# WHY MINOR/MAJOR AND NOT PATCH: a minor here is cut when a consumer actually notices something. That
# is the same test the version number itself answers, so the tier and the bump agree by construction --
# a patch has nothing a consumer would read, which is precisely why it is a patch.
#
# WHAT THIS KNOB DECIDES INVERTED IN v4.3.0, AND ITS VALUE DID NOT (inbound #605). This paragraph said
# the opposite until then: that the knob "no longer decides WHETHER there is anything to write -- the
# tier does -- only whether this repo wants the document for that bump type". That was true while a
# tier-1-only minor still produced an internal note from a second script, so switching the consumer tier
# off cost only the consumer half. It is now the whole document: @() here means those bumps get NO
# hand-written note at all, and the release goes out announced by the generated body alone.
#
# WHY THAT WAS INVISIBLE, and worth knowing because the shape recurs: the check compares which functions
# exist against which are requested, so a knob whose VALUES stay valid while its QUESTION changes passes
# every gate. @('minor','major') was correct before and is correct after; only the sentence explaining it
# was wrong, and no gate reads a sentence. It took a consumer aligning two versions to find it.
#
# The agreement between the tier and the bump is still enforced, just at the other end: cut-release
# refuses a minor that no tier-1-or-higher entry has earned, so "somebody outside this repo's developers
# is reading this bump" is a precondition of the bump rather than a convention about it.
$script:ReleaseConsumerBumps = @('minor', 'major')

function Get-ReleaseConsumerBumps {
    <# Bump types that get the hand-written release note: e.g. @('minor','major'). Empty = none at all. #>
    return $script:ReleaseConsumerBumps
}

# THE OLD NAME IS STILL READ, AND ONLY THE NEW ONE IS WRITTEN -- the standing "recognise both, write
# one" rule, and here it is load-bearing rather than polite: this is a CONSUMER-OVERRIDABLE seam, so a
# repo that defines Get-ReleaseHighlightsBumps in its own repo-config right now would, without the
# fallback in cut-release.ps1, silently fall back to the built-in default (@() -- the tier switched
# OFF) and cut a minor with no document for the reader it was cut for. Nothing would error. Consumers
# receive this rename through a plugin update rather than by choosing to, so the read has to cover
# both names for as long as any of them might still carry the old one.

# --- WHICH AUDIENCE THIS REPO PUBLISHES TO (Dave, August 12, 2026; inbound #620) ------------------
#
# Tier 1 and tier 2 are NOT two rungs of one ladder. They are two KINDS of audience, and a repo has
# exactly one:
#
#   1  management and the employer/commissioner -- a repo whose output is work DELIVERED to somebody, or
#      a shop selling a PRODUCT, whose buyers never read a release note.
#   2  the subscriber of a service -- a repo that IS the thing somebody subscribes to and decides to
#      upgrade.
#
# TWO IS THE ANSWER HERE, because this repo sells a service rather than a product. The consumer that
# filed #620 is a webshop and its answer is 1: its customers buy a product and never read these notes,
# while management and the commissioner do. Same model, opposite answer -- which is precisely why it is a
# knob and not a constant.
#
# THE MEASUREMENT BEHIND IT. Under the cumulative ladder a tier-2 entry OWED a tier-1 section, so the two
# were never independent readings. Across the 97 scored entries in this repo's record, 81 topped out at
# tier 2 and only 8 at tier 1 -- so 81 of the 89 tier-1 sections were ladder tax: the same reach argued
# twice, in a second register, for a reader who here is the same person. #620 measured the mirror image on
# its own side: 37 open entries, 15 declaring tier 1, zero ever declaring tier 2.
#
# AN UNSTATED ANSWER MEANS "ASK FOR ALL OF THEM", which is today's behaviour and the only safe default.
# The tempting reading of "the tier is enabled once the audience is clear" is that an unconfigured repo
# enables nothing -- and that would switch the audience tier OFF in every consumer the moment they take
# the plugin update, silently, in the direction that empties a release document. So absent means
# unchanged. The LOUD channel is the contract instead: this is a 'decide' record, so adopt-config
# scaffolds the question rather than copying this repo's answer, and check-script-contract reports a repo
# that never answered it. Nobody inherits somebody else's audience, and nobody is switched off unasked.
$script:ReleaseAudienceTier = 2

function Get-ReleaseAudienceTier {
    <# The one audience tier this repo publishes to: 1 (management and the employer) or 2 (subscribers of
       a service). Tier 0 -- the people maintaining the repo -- is always asked for, so it is deliberately
       not this function's business. #>
    return $script:ReleaseAudienceTier
}

# --- How many minors a major must recap (Dave, August 5, 2026) ------------------------------------
#
# A major here is not "a big release" but a RECAP of the minors before it -- which is what the two majors
# this repo has cut actually were: v2.0.0 consolidated v1.0 to v1.18, v3.0.0 consolidated v2.2.0 to
# v2.16.0. Both were written that way after the fact; this states it up front and lets the cut enforce it.
#
# TEN, and read off the CURRENT VERSION's minor component rather than counted from the tag list. Within
# major 3 the minors are 3.1 .. 3.10, so the component IS the number of minors cut in that line -- one
# number that cannot disagree with itself, where counting tags could (a deleted tag, a minor cut in
# another line). Held against this repo's own history the threshold is roughly right rather than
# arbitrary: the 1.x line ran to 1.18 and the 2.x line to 2.16 before each was recapped.
#
# Repo-owned because it is release cadence, not language: a repo that cuts minors rarely would be pinned
# to a major it never reaches, and forking a shared script over one integer is precisely what the seam
# exists to prevent (#417). Only read where a tier split is declared -- the whole bump gate is off
# without one.
$script:ReleaseMajorMinMinors = 10

function Get-ReleaseMajorMinMinors {
    <# The number of minors a major line must have had before a major may be cut. #>
    return $script:ReleaseMajorMinMinors
}

# --- RETIRED, AUGUST 5, 2026: Get-ReleaseHighlightsStakeholderTypes + Get-ReleaseHighlightsWording ---
#
# Both existed to serve ONE mechanism: the tier-2 generator wrote out every category, put Feat+Fix
# above a "remove before publishing" marker and left the release manager to cut the rest by hand. The
# marker was explicitly a PROPOSAL rather than a verdict, and the reason it could only ever be a
# proposal is the measurement this repo already had: held against the 19 entries pending at v3.2.0, the
# single most consequential change for a consumer -- renaming the marketplace, which breaks every
# existing install -- arrived on a chore/ branch and therefore landed below the marker.
#
# The tier model answers that question at the source instead of guessing at the end: the author of the
# entry says whether a consumer notices, and the generator selects on that. So the marker has nothing
# left to propose, and the two knobs that configured it -- which types to promote, and in whose words to
# label the block -- describe machinery that is gone. They are removed rather than left returning values
# nothing reads, which is this file's own rule about write-once config.
#
# A consumer that still defines either function is unaffected: nothing calls them, so they are simply
# dead code in that repo's seam, and its next fold and cut behave exactly as this repo's do.

# --- The internal tier's own text (the third tier, August 3, 2026) --------------------------------
#
# releases/internal/<X>.x/<X.Y.Z>.md, written by new-internal-note.ps1 for colleagues, employers and
# management -- at EVERY release including a patch, which is exactly what separates it from the consumer
# document: that one is what a CONSUMER notices, this one is what the ORGANISATION gets out of it. A
# release with nothing for a consumer (correctly a patch, so no consumer document) can still be the one
# where a team stopped needing a developer for a routine change.
#
# NO ON/OFF KNOB, deliberately, unlike the consumer tier. That tier is generated BY cut-release, so it
# needs to be told whether to run; this one is a script you invoke when you want a note. The switch is
# running it or not. cut-release only decides whether to PRINT the suggestion, and it does that by
# checking whether the script exists in the repo -- a fact rather than a preference, the same reasoning
# as Get-ReleasePluginTier's computed fallback.
#
# EMPTY HERE, for the third time in this file and for the same reason: an English repo is already served
# by the English defaults in the script. The knob exists for a consumer whose colleagues read another
# language, where an unset heading is the wrong word rather than a missing one -- the #410 class. Keys:
# Title, AudienceLabel, Audience, SkeletonNote, SectionChanged, SectionValue, HintValue, SectionOpen,
# HintOpen, NoEntries, Unknown. Merged over the defaults, so overriding one leaves the rest alone.
$script:InternalNoteWording = @{}

function Get-InternalNoteWording {
    <# Overrides for the internal note's headings, audience line and fill-in hints. Empty = English. #>
    return $script:InternalNoteWording
}

# THE NAME THE CUT ACTUALLY LOOKS FOR FIRST (inbound #605). cut-release.ps1 reads
# Get-ReleaseNoteWording and only falls back to Get-InternalNoteWording above -- so until this existed,
# this repo was being served by the retired name and had no way to notice. Nothing was broken, which is
# precisely why it went two releases undeclared: the fallback works, so no run ever complains.
#
# A SEPARATE MAP RATHER THAN AN ALIAS, because the two documents do not share a key set. This one is the
# ONE hand-written release note (a named section per reader): Title, AudienceLabel, Audience,
# SectionAudience, HintAudience, SectionValue, HintValue, SectionOpen, HintOpen. The four keys above
# that are missing here -- SkeletonNote, SectionChanged, NoEntries, Unknown -- belong to
# new-internal-note.ps1, which is still shipped and which nothing here calls.
#
# SectionAudience/HintAudience WERE SectionConsumers/HintConsumers until inbound #747, and both old names
# are still read -- "recognise both, write one". The rename is not cosmetic: that section now follows
# Get-ReleaseAudienceTier, so in a tier-1 repo it addresses the organisation, and a key whose own name said
# "consumers" would describe the wrong reader. A repo that overrode the old name keeps its heading.
#
# EMPTY HERE, for the same reason as its neighbour: an English repo is already served by the English
# defaults in the script. Merged over them, so overriding one leaves the rest alone.
$script:ReleaseNoteWording = @{}

function Get-ReleaseNoteWording {
    <# Overrides for the release note's headings, audience line and fill-in hints. Empty = English. #>
    return $script:ReleaseNoteWording
}

# --- The hosted page built from those notes (Dave, August 15, 2026) -------------------------------
#
# build-release-notes-page.ps1 turns the hand-written notes into one browsable page and, with
# -Worker, into a Cloudflare Worker that serves it. Two knobs, and neither of them says WHERE the
# page goes: that is derived from Get-ReleaseNoteRoot above, because the note root already states
# where this repo keeps its release documents and a second seam would be the same decision written
# twice.
#
# THE PAGE'S OWN NAME. It is what a reader sees in the tab and at the top, so it is the repo's to
# say rather than the script's. Without it the script falls back to the name half of Get-RepoName,
# which is a real answer -- 'dkj-claude-plugins' -- and simply not the one to send anybody.
# THE PRODUCT'S NAME AND NOTHING ELSE. It read 'Claude Specialists -- release notes' until August 21,
# 2026, which put those words on the page twice. This answer is the masthead's EYEBROW and half the window
# title; the heading itself is the template's own 'Release notes'. What the page IS belongs to the
# template, whose releases it carries belongs here.
$script:ReleasePageTitle = 'Claude Specialists'

function Get-ReleasePageTitle {
    <# The heading and window title of the generated release-notes page. #>
    return $script:ReleasePageTitle
}

# THE WORKER THAT HOSTS IT. Empty means this repo builds the page but hosts it nowhere, which is the
# right answer for most consumers and is why the default is empty rather than a name.
#
# WHAT THE NAME BUYS AND WHAT IT DOES NOT. The worker serves the page at /notes/<32 hex>, and that
# path is the only lock on it -- no login, anyone with the link reads it. That is a deliberate choice
# here (Dave, August 15, 2026) and it is defensible for exactly one reason: these notes are already
# public in this repository, so the path guards the ROUTE and not the content. It is also why the
# page carries noindex in both the header and the meta tag: a link nobody can guess is worth nothing
# once a crawler has published it.
#
# THE TOKEN IS NOT IN THIS REPOSITORY, and that is the half to remember. This repo is public, so a
# committed token would be a lock with its key taped to the door -- it lives in
# dkj-policy/releases/page/worker-path-token.txt, which .gitignore keeps out. Nothing in git
# therefore remembers the URL: whoever creates it records it outside the repo. A consumer whose repo
# is PRIVATE has the opposite answer available and should take it, since a tracked token survives a
# lost machine.
#
# BUT "NOT IN GIT" IS NOT "NOWHERE" (issue #1453). The deployed worker carries its route as a literal,
# so while the worker named below is up, Cloudflare holds a copy of the token that no machine here has
# -- readable from that worker's code view in the dashboard, or from the Workers script API. Losing
# every local copy is therefore recoverable, and only a worker that is ALSO gone makes the URL
# unrecoverable. Check the deployment before reaching for -InitToken, which mints a fresh path and
# 404s every link already sent.
$script:ReleasePageWorkerName = 'ccs-release-notes'

function Get-ReleasePageWorkerName {
    <# The Cloudflare Worker that serves the generated page; '' = this repo hosts it nowhere. #>
    return $script:ReleasePageWorkerName
}

# AND THE PALETTE (inbound #759). Empty on purpose, and it is an answer rather than an omission: this
# repo's page keeps the template's own colours because the template IS this repo's product. A consumer
# whose page goes to management and a commissioner has the opposite answer -- theirs has to look like
# the shop it reports on, which is what the seam exists for.
#
# STATED RATHER THAN LEFT TO THE DEFAULT, like Get-LiveStage above: the empty answer is the one a
# reader is most likely to mistake for "nobody has looked at this yet", and check-script-contract can
# only tell the two apart by the function being there.
$script:ReleasePageTheme = @{}

function Get-ReleasePageTheme {
    <# Custom-property overrides for the generated page, e.g. @{ '--accent' = '#FF4F01' }; an empty
       map means the shipped palette. 'color-scheme' is accepted as a name, which is how a brand with
       no dark variant pins 'light'. Values are validated, not escaped -- see Format-ReleasePageStyle
       in build-release-notes-page.ps1 for what passes and why. #>
    return $script:ReleasePageTheme
}

# --- The GitHub-side settings this repo DECLARES, for check-repo-settings.ps1 (issue #1726) --------
#
# WHAT THIS SEAM IS FOR. A ruleset and a repo's merge switches are GitHub-side state: nothing in this
# tree changes when they change, no commit records it, and no gate read one until this seam existed.
# The docs record them anyway -- they have to, because they are load-bearing for the direct-on-`main`
# exceptions, for the fold, and for ship-pr's staleness guard -- so the record and the live state can
# disagree indefinitely with nothing saying so.
#
# THREE DRIFTS IN EIGHT DAYS, which is what turned this from a hypothetical into a build (#1726):
#   Sept 2-3   the org transfer emptied `bypass_actors`, killing all three direct-on-`main`
#              exceptions and blocking every fold (#1244). Found by a failing push, a day later.
#   Sept 6-9   `merge_queue` was added to the ruleset (#1499) and gone again by the 9th (#1720).
#              Neither event left a trace, so CLAUDE.md's always-on prose handed out the wrong answer
#              for a stretch nobody can now put a length on.
#   Sept 9     `allow_auto_merge` read `true` against four records in this tree saying `false`
#              (#1730) -- found by the first run of the check this seam serves.
#
# EACH RECORD CARRIES ITS OWN PROVENANCE, and that is the part worth copying rather than the values.
# `Where` names the document in this tree that states the fact -- a path plus the section, not a line
# number, which would go stale on the next edit to a file this one does not gate -- so a report says
# which document to repair when the drift turns out to be the intended change; `Recorded` is the date
# that statement was last measured, so a stale declaration is visible as a stale declaration. Without those two a
# red run would say only "these differ" and leave the reader to work out which side is wrong.
#
# WHAT IT DOES *NOT* DO: nothing here changes a setting, and the checker never writes to GitHub.
# Repo settings are the owner's surface under this repo's constitution, exactly as
# adopt-ci-floor.ps1 states for the ruleset command it composes and refuses to run.
#
# TO REPAIR A REPORTED DRIFT, decide which side is wrong FIRST. If the live value is wrong, change it
# at GitHub. If the declaration is wrong -- the setting was changed deliberately -- update the value
# here, the `Recorded` date with it, AND the document `Where` points at, because that document is
# what a session actually reads.
#
# AN UNSTATED FIELD IS NOT CHECKED. Adding a record is how a fact becomes watched; there is no
# implicit list, deliberately, so nothing here can go stale for a field nobody chose to declare.
$script:ExpectedRepoSettings = @(
    @{
        Field    = 'ruleset.rules'
        Expected = @('deletion', 'non_fast_forward', 'required_status_checks')
        Recorded = '2026-09-09'
        Where    = '.claude/specialists/lenses/05-15-extension.md (the ruleset bullet)'
        Why      = 'every record in that lens names required_status_checks as THE rule the three direct-on-main exceptions are bypassed for, and a rejected push reports one line per rule -- a fourth rule makes an extra line read as an unexplained second cause (#1499, #1720)'
    },
    @{
        Field    = 'ruleset.required_checks'
        Expected = @('lint-en-tests')
        Recorded = '2026-09-09'
        Where    = 'scripts/repo-config.ps1 (Get-CiTestCheckName) and .claude/specialists/lenses/05-15-extension.md'
        Why      = 'ship-pr dates a PR certificate from the run behind a REQUIRED check and skips its staleness guard entirely when none is named; open-pr skips the local test gate on this same context going green (#1715)'
    },
    @{
        Field    = 'ruleset.strict_required_status_checks_policy'
        Expected = $false
        Recorded = '2026-09-09'
        Where    = '.claude/specialists/lenses/05-15-extension.md (the #1325 block)'
        Why      = 'strict was on for ~45 minutes on #1325 and reverted: GitHub performs no server-side base-sync outside a merge queue, so strict converts the ~44% behind-at-merge rate into a hard block with no automatic resolution and no valve -- PR #1316 had to be landed with --admin'
    },
    @{
        Field    = 'repo.allow_auto_merge'
        Expected = $false
        Recorded = '2026-09-09'
        Where    = '.claude/specialists/lenses/05-15-extension.md, .github/workflows/ci.yml, scripts/tests/merge-queue-prereq.tests.ps1'
        Why      = 'with strict off, "up to date" is not a merge requirement, so auto-merge lands a stale-but-green certificate unattended -- #1292 exactly, and ship-pr step 3b cannot see it because an auto-merge happens without a shipping session (#1730)'
    },
    @{
        Field    = 'repo.allow_update_branch'
        Expected = $false
        Recorded = '2026-09-09'
        Where    = '.claude/specialists/lenses/05-15-extension.md (the #1325 block)'
        Why      = 'reverted with strict on #1325; it only shows a UI button to a human with write access and acts on nothing, so it buys no convergence and its being on misreports that it does'
    },
    @{
        Field    = 'repo.visibility'
        Expected = 'public'
        Recorded = '2026-09-09'
        Where    = 'CLAUDE.md (the repo slot: "This repo is public")'
        Why      = 'deliberate, so the remote github marketplace source can be read without gh auth -- and it is the clause this repo qualifies for a merge queue through, which most consumers do not (#1540). Going private silently breaks every consumer install and makes the no-secrets rule read as over-caution'
    },
    @{
        Field    = 'ruleset.bypass_actor_types'
        Expected = @('OrganizationAdmin', 'RepositoryRole')
        Recorded = '2026-09-09'
        Where    = '.claude/specialists/lenses/05-15-extension.md (the #1284 and #1244 blocks)'
        Why      = 'the bypass list is the only thing between a green main-ci-gate and three exceptions that cannot satisfy it -- a required status check can never be satisfied by a direct push. The transfer emptied it for a day and nothing reported that (#1244). Read only by a token that can administer the repo, so a CI run reports this one as unreadable rather than green'
    }
)

function Get-ExpectedRepoSettings {
    <# The GitHub-side ruleset and repo settings this repo declares, as records carrying Field,
       Expected, Recorded (the date the tree's statement was last measured), Where (the document
       stating it) and Why. Read by scripts/lint/check-repo-settings.ps1; an empty list means
       nothing is watched. #>
    return $script:ExpectedRepoSettings
}

# --- The triage-priority labels every dkj-policy consumer is invited to share (issue #1895) ---------
#
# THE GAP. `.claude/specialists/lenses/01-01-extension.md` already prescribes a priority label on
# every issue filed HERE -- 'prio-1' (lowest) through 'prio-4' (highest) -- but until now that scale
# was prose in one family's page and `dkj-policy` itself knew none of it. #1895 (split from #1843)
# asked three questions, and Dave answered all three on September 12, 2026:
#
#   1. Apply or print?  PRINT. adopt-triage-labels.ps1 composes the exact `gh label create` a person
#      would type and stops, on the same reasoning Get-MissingLabelNote already applies to a PR
#      label: creating a label is a GitHub-side write, and a script that quietly created or
#      substituted one would break any repo that later gates on it.
#   2. Is there a shared set at all?  YES, one set -- not a per-consumer table.
#   3. Where is it declared?  HERE, in its own seam -- not in branch-info.ps1 (see AdoptWhy below).
#
# 'copy', NOT 'decide', AND THE REASONING IS Get-ReachLabel's, ONE AXIS OVER (issue #1870), NOT
# Get-BranchInfo's. A 'decide' value states WHAT THE REPO IS -- Get-BranchInfo's three prefixes exist
# because THIS repo lands a release directly on its trunk, and copying that table into a consumer with
# a different policy would impose it on them. 'prio-1' through 'prio-4' assert nothing about the
# adopting repo at all: they are four rungs of urgency, and the rungs mean the same thing in every
# repo that adopts them -- the shared WAY OF WORKING Get-ReachLabel's own AdoptWhy already argues for
# the neighbouring axis. Refusing to share them would leave every dkj-policy consumer to reinvent four
# names and four colours on their own, which is the exact "prose in one family's page" #1895 was filed
# about.
#
# NOT THE SAME QUESTION AS #1686, AND NOT A REVERSAL OF IT. #1686 (closed September 9, 2026) kept this
# repo's `prio-*` rungs and the BWJ tracker's own reach BUCKETS deliberately disjoint, in both
# directions, so a session crossing families gets a refused label rather than one that quietly means
# something else there. This seam does not touch dkj-policy-bwj's buckets or Get-ReachLabel's reach
# axis at all -- it only offers the priority axis to an ORDINARY dkj-policy consumer, one with no BWJ
# board of its own, which is a question #1686 never asked.
#
# THE VALUES ARE THIS REPO'S OWN LIVE LABELS, read back from `gh label list` rather than invented for
# this function -- this repo already runs the convention its own orchestrator prescribes, so its
# answer IS the canonical one instead of a guess at what it should be. adopt-triage-labels.ps1 carries
# the same four values as its own built-in fallback, for a consumer that has not yet adopted this seam
# -- see that script's header for why the two copies must stay byte-identical, the same duality
# Get-EntryFallbackType's 'Chore' already has with entry-scaffold-lib.ps1.
#
# NO SCRIPT IN THIS WORKFLOW READS THIS EITHER, same as the priority axis has never been read by
# anything here (see Get-ReachLabel's own AdoptWhy for why that is not disqualifying): `gh issue
# create` fails outright on a label the repo does not have, so the four records below exist to be
# composed into a paste-ready `gh label create` line by adopt-triage-labels.ps1 rather than typed by
# hand into four separate terminals with four separate chances to mistype a hex colour.
$script:TriageLabels = @(
    [pscustomobject]@{ Name = 'prio-1'; Color = '006B75'; Description = 'Priority 1 of 4 (lowest) -- nobody is waiting for it' }
    [pscustomobject]@{ Name = 'prio-2'; Color = 'FBCA04'; Description = 'Priority 2 of 4 -- worth doing, no pressure' }
    [pscustomobject]@{ Name = 'prio-3'; Color = 'D93F0B'; Description = 'Priority 3 of 4 -- do this before the ordinary backlog' }
    [pscustomobject]@{ Name = 'prio-4'; Color = 'B60205'; Description = 'Priority 4 of 4 (highest) -- takes precedence over other work' }
)

function Get-TriageLabels {
    <# The four canonical triage-priority labels this workflow's consumers are invited to share --
       'prio-1' (lowest) through 'prio-4' (highest) -- as an array of objects with Name, Color and
       Description (the exact fields a `gh label create` call needs). Read by
       adopt-triage-labels.ps1, which composes and prints the create command for whichever of the
       four this repo's tracker is missing; it never creates a label itself. Optional in the script
       contract -- a consumer that has not answered this seam gets the same four values from that
       script's own built-in fallback, so an unanswered repo is already told the canonical set rather
       than a degraded one. #>
    return @($script:TriageLabels)
}
