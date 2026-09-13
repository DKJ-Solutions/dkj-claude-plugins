<#
.SYNOPSIS
    Cuts a repo-wide release directly on main: bumps all plugin versions in lockstep,
    generates the changelog notes in dkj-policy/releases/changelog/, empties CHANGELOG.md down to its intro,
    updates the overview table in releases/README.md, commits that on main, and sets +
    pushes the git tag vX.Y.Z.

.DESCRIPTION
    A release here is a *recorded moment*: all plugins get the same version number
    (lockstep, repo-wide) and the state is tagged as vX.Y.Z. This script itself publishes nothing
    to GitHub Releases -- only a git tag, the generated notes in dkj-policy/releases/, and a row in the overview
    table. For a Minor/Major bump, publishing a GitHub Release is a manual follow-up step
    the release manager takes afterward, per the cut-release skill's closing checklist; a Patch
    bump skips that step entirely (tag only).

    NOTHING IS WRITTEN BACK INTO CHANGELOG.md, and that is a change this header used to contradict
    (August 5, 2026). The cut used to append a '## Latest Release' block naming the version, the date
    and a pointer to the notes; that accumulating section had grown to 434 of the file's 1,062 lines
    across 72 blocks that each said no more than "see the notes", while the overview table already
    listed all 72 with a date, a type and a descriptive title. So the intro carries a one-line pointer
    to that page, and a cut leaves this document at its intro.

    A release deliberately does NOT run via a branch + PR. Like the fold commit, the release
    commit is an allowed direct-on-main action (the second of three exceptions to "everything via
    branch + PR" -- see the safety rules). The script therefore runs on main itself and is started
    ONLY at Dave's explicit request.

    THE THIRD EXCEPTION IS THE ONE THAT FOLLOWS THIS SCRIPT (Dave, August 23, 2026): the
    hand-written release notes are committed straight onto main too, so a cut runs in one place from
    end to end -- fold the changelog, bump the version, write the release notes. It reverses the
    August 4, 2026 answer, which sent those documents through a branch + PR, and it is bounded the
    same way the other two are: the hand-written documents of a cut that was asked for, and nothing
    else in the tree.

    SHARED, WITH THE REPO'S OWN ANSWERS IN THE SEAM (issue #417). This script is mirrored into the
    plugin, so a consumer runs it rather than forking it. Everything that legitimately differs per
    repo is read from the OPTIONAL functions in scripts/repo-config.ps1, and every fallback is what
    this script did before it was shared. THE LIST IS THE EIGHT THIS SCRIPT ACTUALLY READS, and it is
    kept that way deliberately: a consumer configures from this list, so a name that does nothing costs
    them an afternoon and a name that is missing hides a knob they needed.

      Get-LintScript              which script the lint gate in step 1 runs
      Get-ReservedRootMd          which root docs are permanent
      Get-ReleaseNotesGrouping    notes foldered per major ('major') or per minor
      Get-ReleaseHistoryPath      where the release overview table lives (step 3 files the new row
                                  under that page's top major section, and REFUSES a new major whose
                                  section does not exist yet -- opening one is a deliberate act)
      Get-ReleasePluginTier       whether this repo publishes plugins at all: it gates the lockstep
                                  bump, and it is what decides whether the current version comes from
                                  a plugin.json or from the newest vX.Y.Z tag
      Get-ReleaseConsumerBumps    which bumps get a stakeholder document; see step 3d. The retired name
                                  Get-ReleaseHighlightsBumps is still read as a fallback
      Get-ReleaseMajorMinMinors   how many minors a major must recap
      Get-TestCommands            extra test commands the test gate in step 1 runs beside the
                                  *.tests.ps1 suites (e.g. 'npm test') -- read inside the shared
                                  Invoke-TestSuiteGate, so open-pr's gate sees the same list

    TWO NAMES THAT USED TO BE ON THIS LIST ARE GONE, and they are named here rather than silently
    dropped, because a consumer's repo-config may still define them: Get-ReleaseLiveMarker described
    the retired release block in CHANGELOG.md (see the seam comment further down), and
    Get-ReleaseCategoryTitles labelled the category headings the flat document retired. Defining either
    today does nothing at all -- which is worse than an error, because it looks configured.

    THE TIER MODEL (August 5, 2026). CHANGELOG.md is an intro followed by one '##' per change, ranked
    furthest-reach-first and, within a reach, highest-significance-first -- there are no sections to file
    into, and each entry declares its own reach in the '### Significance' section it carries. Three
    things here follow from it: the bump gate in step 1, the tier grouping of the notes in step 3, and
    the consumer document in step 3d being the tier-2 entries rather than a category guess.

    All three switch themselves off where NO PENDING ENTRY DECLARED ITS IMPACT AT ALL, so a consumer
    that has not adopted the model cuts exactly the release it always did. That test counts
    DECLARATIONS, and it must not be turned back into a count of sections: a flat changelog gives an
    unadopted repo and an adopting one exactly one group each, so a section-count test would read every
    repo as not adopting and switch the gate off in silence, with nothing erroring.

    Steps (all on main):
      1. Guardrails: clean main, no unfolded entry files in the root, THE BASELINE AGREEING WITH THE
         RELEASE OVERVIEW'S NEWEST ROW (-Type overrules by stating the type outright), THE BUMP EARNED BY
         THE PENDING TIERS (the bump follows the highest tier pending -- tier 0 only is a patch, tier 1 or
         higher earns a minor, a major needs enough minors behind it -- Test-ReleaseBumpEarned;
         -SkipTierGate overrules), lint gate green, AND all test suites green (-SkipTests overrules).
      2. Determines the current version -- the lockstep value from every
         <plugin>/.claude-plugin/plugin.json where this repo publishes plugins, otherwise the newest
         vX.Y.Z tag -- CROSS-CHECKS IT AGAINST THE NEWEST ROW OF THE RELEASE OVERVIEW and refuses on a
         disagreement (-Type states the type where the divergence is deliberate), then the new version
         (-Version or -Bump) and the bump type. Neither the manifests nor the tag line is the document
         that says which release is which, and a baseline from a different release mislabels this one in
         four places at once without warning: the notes, the overview row, the tier gate's question, and
         whether a consumer document is drafted. Inbound #802.
      3. Generates <changelog root>/<X>.x/<X.Y.Z>.md from the pending entries, grouped by TIER,
         adds a row to releases/README.md, empties CHANGELOG.md down to its intro, and bumps all
         plugin.json's. Within a tier the entries are RANKED BY THEIR OWN SIGNIFICANCE SCORES FROM
         TIER 1 UP, and deliberately not at tier 0: the changelog note is the record, so it stays in
         the order the folds left. There is no category grouping any more -- the categories keyed on the
         branch prefix, which this repo has measured does not predict impact, so a document's most
         consequential change could only be reordered within whichever label its prefix produced.
      3b/3c. RETIRED, AUGUST 8, 2026 -- the per-plugin CHANGELOG.md and the per-plugin RELEASE.md card.
          The step numbers are kept here rather than renumbered, so that a reader who has seen an older
          copy of this script, or a consumer's release notes referring to "step 3b", lands on the answer
          instead of on a step that now means something else. The full reasoning is at the point in the
          code where they used to run; in short, a marketplace source is a git clone of the WHOLE repo,
          so those ten files were 11,684 lines restating what the reader already had.
      3d. Writes a second, stakeholder-facing rendering of the same release:
          releases/consumer/<dir>/<X.Y.Z>.md. TWO CONDITIONS, BOTH REQUIRED: the bump type is one the
          seam names in Get-ReleaseConsumerBumps, AND at least one pending entry declared tier 2.
          The second half is the load-bearing one since a minor stopped needing a tier-2 entry to be
          earned (August 7, 2026) -- it is what keeps a tier-1-only minor from handing someone outside
          the project a document about work they cannot see.
          Written for NON-DEVELOPERS, and it is the TIER-2 ENTRIES -- what a consumer notices was
          declared by each entry's own author, so there is no "remove before publishing" marker left to
          cut by hand. Still a draft: the selection is right, the prose is still written for developers.
          Markdown only -- no HTML, deliberately (see release-lib.ps1's tier-2 header).
      4. Commits that directly to main (release: vX.Y.Z) and sets an annotated tag vX.Y.Z, then names
         the documents it deliberately did NOT write: the consumer draft still needs editing, and the
         internal summary (the third tier, for colleagues and management, at EVERY release including a
         patch) has its own script -- new-internal-note.ps1, which needs the notes step 3 just produced.
         Both are hand-written and both are committed straight onto main, in the commit after this
         one -- the third direct-on-main exception, so the whole cut stays on the trunk.
      5. Pushes main + the tag (unless -NoPush).

.PARAMETER Version
    Explicit new version X.Y.Z (e.g. "1.1.0"). Use this OR -Bump.

.PARAMETER Bump
    Bump the current version automatically: major | minor | patch. Use this OR -Version.

.PARAMETER Type
    STATE the bump type instead of having it inferred from the two version numbers, e.g.
    `-Version 2.39.1 -Type patch`. Belongs with -Version; refused alongside -Bump, which already says the
    same thing.

    IT EXISTS FOR ONE SITUATION: a repo whose git tag line and whose recorded release numbering have
    deliberately diverged (tags used for something other than releases, per-component tags in a monorepo,
    imported history). The baseline guardrail refuses such a cut, because a baseline that is not about
    this release mislabels it in four places at once and in silence -- and this is the way through, rather
    than a -Skip switch that would hand back the very label the guardrail caught. Inbound #802.

.PARAMETER Title
    Short description of the release as a whole (1 sentence, optional) -- goes into the notes +
    the table row.

.PARAMETER SummaryFile
    Path to a markdown file whose content is placed in the release notes between the -Title line and
    the generated per-PR entries, followed by a horizontal rule.

    FOR A MILESTONE RELEASE, where the point is the arc across many releases rather than the diff since
    the last one. -Title is one sentence and the entries are per-PR, so neither can carry "here is what
    changed between 2.2.0 and 2.16.0" -- and hand-editing a generated file afterwards is not a
    repeatable release, which is the whole reason this script exists.

    The file may live outside the repo (a scratch path is fine, and is the expected case): its canonical
    home becomes the generated notes file itself, so keeping a second copy under releases/ purely to
    feed this parameter would duplicate content for no gain. A missing or empty file is a hard stop --
    an empty one would otherwise produce an ordinary release while the operator believes they cut a
    milestone.

.PARAMETER NoPush
    Everything locally (commit + tag) but do not push main/tag -- for inspection beforehand.

.PARAMETER SkipLint
    Deliberately skip the lint gate (escape valve).

.PARAMETER SkipTests
    Deliberately skip the test-suite gate (escape valve). Separate from -SkipLint for the reason those two
    are separate in open-pr.ps1: they are two different tools, and skipping one is not a reason to skip the
    other. The suites run BEFORE anything is written, so skipping them means a release can be committed and
    tagged on main while a suite is red.

.PARAMETER MaxParallel
    How many test suites the gate above runs at once. 0 (the default) leaves the resolution to
    Invoke-TestSuiteGate exactly as before, so passing nothing is byte-identical to the behaviour this
    parameter was added to.

    IT MATTERS MOST HERE, of the three callers that got it in issue #1443 (September 5, 2026). The other
    two open a PR, and a PR that does not open costs a retry. This one commits and tags on main -- and the
    sentence directly above is the reason the alternative is unacceptable: -SkipTests means a release can
    be cut while a suite is red. So a gate that will not FINISH must not be answered by skipping it. Run
    it smaller: measured on an 18-core machine, the default's 16 lanes were killed twice for running out
    of memory where -MaxParallel 4 passed the same 68 suites in 888s against 716s. open-pr.ps1's own
    .PARAMETER MaxParallel carries the rest of the numbers.

.PARAMETER SkipSignificanceGate
    Cut even though a pending tier-1-or-higher entry has not declared how much it weighs (issue #467).
    The score orders the release documents, so without it an entry cannot be placed; the gate refuses
    rather than sorting it last, because quietly demoting a forgotten line is worst in the one document
    whose subject is which change matters most.

    SEPARATE FROM -SkipTierGate as well as from -SkipLint, because the three overrule different things:
    -SkipLint skips a tool, -SkipTierGate overrules whether the release should exist at all, and this
    overrules how its contents are ordered. One flag for all three would let someone waving through a
    missing score also wave through an unearned version number.

.PARAMETER SkipTierGate
    Cut a bump the pending changelog tiers have not earned (escape valve).

    DELIBERATELY SEPARATE FROM -SkipLint, and for the same reason the scaffold gate's -Force is separate:
    this overrules a judgement about CONTENT -- whether the work reaches far enough to deserve this
    version number -- while -SkipLint skips a tool. Folding them into one flag would let someone skipping
    a slow lint run also, silently, cut a minor with nothing in it for a consumer.

.EXAMPLE
    ./scripts/release/cut-release.ps1 -Version 1.0.0 -Title "First official release"

.EXAMPLE
    ./scripts/release/cut-release.ps1 -Bump minor -NoPush

.EXAMPLE
    ./scripts/release/cut-release.ps1 -Bump major -Title "A new milestone" -SummaryFile ..\summary.md -NoPush
    # Milestone release: the authored summary opens the notes, the pending entries follow it.

.NOTES
    COVERAGE, STATED RATHER THAN LEFT TO INFERENCE (#708, August 15, 2026). This is the
    highest-blast-radius script here -- it commits on the trunk and tags before any PR or CI can look at
    the result -- so what is and is not tested should not have to be worked out from the tests directory.
    Until #708 it said nothing, while its sibling ship-pr.ps1 named its own gap twice, and an absent
    statement reads as coverage.

    DRIVEN END TO END by scripts/tests/cut-release-drive.tests.ps1, against a throwaway `git init` repo
    with no remote: the lockstep bump across every plugin.json, CHANGELOG.md emptied to its intro, the
    development note written at the grouped path carrying the entry the changelog lost, the row inserted
    into the release history, the commit, the tag pointing at it, and a clean tree afterwards. Plus three
    refusals, each asserted to leave the tree untouched: a bump the pending entries have not earned, a
    new major whose section does not exist yet, and a baseline that disagrees with the release overview's
    newest row -- that last one paired with the -Type run that gets through it, asserting the LABEL that
    comes out rather than only the exit code, because a bypass producing the wrong label would pass a
    refusal test and still be the defect.

    STILL NOT COVERED, and deliberately: the push (every driven run passes -NoPush, because a suite must
    not be able to reach a remote), and the hand-written documents downstream of the cut, which are prose
    a person writes. The source-text asserts in cut-release-guardrail.tests.ps1 remain the other half --
    they pin what this file SAYS (the reserved-root allowlist, the gate ordering, the escape valves)
    where the driven suite pins what it DOES.
#>
[CmdletBinding()]
param(
    [string]$Version,
    [ValidateSet('major', 'minor', 'patch')][string]$Bump,
    [ValidateSet('major', 'minor', 'patch')][string]$Type,
    [string]$Title = '',
    [string]$SummaryFile = '',
    [switch]$NoPush,
    [switch]$SkipLint,
    [switch]$SkipTests,
    [switch]$SkipTierGate,
    [switch]$SkipSignificanceGate,
    # Lanes for the test gate; 0 keeps Invoke-TestSuiteGate's own default. See .PARAMETER MaxParallel.
    [int]$MaxParallel = 0
)
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Repo root -- dual context, the same contract every shared script here follows (#81): if a consumer
# runs the plugin mirror, CLAUDE_PROJECT_DIR supplies its repo root; in the workshop root (or outside
# a session) it falls back to the git root. This is what lets the root copy and the mirror stay
# byte-identical, which the shared-scripts drift lint enforces.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'cut-release.ps1'
Set-Location $repoRoot

# Pre-flight, before the dot-sources below turn a missing file into a raw path-not-found (#86, the
# same guard open-pr.ps1 carries). Both files are REPO-OWNED and live in the consumer's root.
$needed = @('scripts\repo-config.ps1', 'scripts\lib\branch-info.ps1')
$absent = @($needed | Where-Object { -not (Test-Path -LiteralPath (Join-Path $repoRoot $_)) })
if ($absent.Count -gt 0) {
    Write-Error ("cut-release cannot run -- missing repo-owned configuration in the repo root ($repoRoot):`n  " + ($absent -join "`n  ") + "`n`nCreate them (the specialists-init bootstrap lays down a VUL-IN scaffold, or take an existing consumer / the source repo as a model) and run again afterward.")
    exit 1
}

# $repoRoot, not $PSScriptRoot: from the plugin mirror $PSScriptRoot points into the plugin cache,
# while repo-config and branch-info always live in the consumer's repo root. branch-info is dot-sourced
# HERE rather than left to release-lib, because release-lib travels into the mirror and its sibling
# branch-info does not -- Get-ReleaseChangeTypes probes for Get-BranchTypes and finds what we load here.
. (Join-Path $repoRoot 'scripts\lib\branch-info.ps1')
. (Join-Path $repoRoot 'scripts\repo-config.ps1')

# Plugin-owned libraries, from $PSScriptRoot: these travel WITH this script, so the sibling is the
# right one in both locations.
. (Join-Path $PSScriptRoot '..\lib\release-lib.ps1')
# The entry format (Test-EntrySignificanceActive for the significance gate, Get-EntryImpactFindings for
# what it reports). release-lib dot-sources this lib itself, so this line adds no function that was not
# already in scope -- it is here for the same reason branch-info is dot-sourced above rather than left to
# release-lib: a dependency this script's own gates rest on should be visible at the place that rests on
# it, not inherited from another lib's internals.
. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
# Shared native-capture helper (#114): the #107 EAP=Continue -> capture -> $LASTEXITCODE dance for
# the git mutations in the final block lives here in one tested place.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
# Get-SeamValue (issue #885, group A): this used to be a private copy defined below; it is now the one
# definition every seam reader in this workflow shares. See seam-lib.ps1's synopsis for why.
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
# Get-InstallRecord / Test-PluginInstalledHere, for the self-consumption reminder at the foot of this
# script (#1445). It reads the install administration to decide whether a `plugin update` command is
# runnable in THIS repo at all -- a question `.claude/settings.json` cannot answer. Dot-sourced here for
# the same reason as the two above: a dependency a printed instruction rests on is visible at the script
# that rests on it. The predicate is deliberately the shared one -- "one reader per call site, tightened
# in none of them" is the sentence #294 was filed about.
# NO DOT-SOURCE HERE ANY MORE (#1917): check-report-lib is now loaded at the repo-root resolution at the
# top of this script, which needs Resolve-RepoRootOrFail before anything else runs. This note stays
# because the REASON this script depends on the lib is still this one, and it is not the reason above.

# THE CLOSE-OUT RECEIPT SHAPE (issue #1884) -- see closeout-lib.ps1
# for why step 6 of the ritual got a mechanism after losing four times in prose. Guarded on
# git-porcelain-lib's grounds: a consumer whose mirror predates this lib must not crash on load, and
# the call site tests for the function rather than assuming the dot-source took.
$cutCloseoutLib = Join-Path $PSScriptRoot '..\lib\closeout-lib.ps1'
if (Test-Path -LiteralPath $cutCloseoutLib -PathType Leaf) { . $cutCloseoutLib }

# --- The repo's own answers, read once (#417) -----------------------------------------------------
# Every one of these is OPTIONAL in the script contract, and every fallback is what this script did
# before it was shared -- so a consumer that defines none of them gets the unchanged behaviour.
# Get-SeamValue itself now lives in seam-lib.ps1, dot-sourced above.

$notesGrouping = Get-SeamValue -Name 'Get-ReleaseNotesGrouping' -Default 'major'
# WHERE THE FULL RELEASE LIST LIVES -- the one survivor of the three changelog-release seams (August 5,
# 2026). Get-ReleaseLiveMarker and Get-ReleaseHistoryMode described the release BLOCK in CHANGELOG.md: the
# "currently live" suffix on its newest row, and whether that section accumulated or kept only the newest
# behind a pointer. A cut writes no such block any more -- it empties the changelog down to its intro -- so
# both knobs describe machinery that is gone and are retired. This one stays because the row inserter below
# still writes into that file, which is now the only list of releases there is.
# COMPUTED DEFAULT SINCE ISSUE #885 (was the literal 'releases/README.md'): source keeps its root file,
# a consumer is isolated into dkj-policy/releases/history.md by default. See
# Get-DefaultReleaseHistoryPath's own doc comment for the reversal and the accepted cost.
$historyRelPath = Get-SeamValue -Name 'Get-ReleaseHistoryPath' -Default (Get-DefaultReleaseHistoryPath -RepoRoot $repoRoot)
Assert-WorkflowIsolatedSeamPath -RepoRoot $repoRoot -RelativePath $historyRelPath -SeamName 'Get-ReleaseHistoryPath'
# The computed fallback is a fact, not a guess: no marketplace manifest means there are no plugins to
# version or card. Stated in repo-config here anyway, because in this repo the answer is load-bearing.
$pluginTier    = Get-SeamValue -Name 'Get-ReleasePluginTier' `
    -Default (Test-Path -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json'))

# The consumer tier (#417 phase 2). Empty by default, which is the tier switched OFF -- what this
# script did for its whole life as a workshop-only file, so nothing changes for a consumer.
#
# ONE KNOB NOW, NOT THREE. Get-ReleaseHighlightsStakeholderTypes and Get-ReleaseHighlightsWording are
# retired (August 5, 2026): both configured the "remove before publishing" marker, and the tier model
# replaced that marker with the entries' own tier-2 declaration. See release-lib.ps1's tier-2 header.
#
# TWO NAMES READ, ONE WRITTEN (August 10, 2026). The knob was Get-ReleaseHighlightsBumps until the tier
# was renamed after its reader, and the old name is read second rather than dropped -- the standing
# "recognise both, write one" rule, load-bearing here because the fallback for "not defined" is @(),
# the tier switched OFF. A consumer whose seam still says Highlights would therefore cut a minor with no
# document for the very reader it was cut for, and nothing in the run would say so.
$consumerBumps = @(Get-SeamValue -Name 'Get-ReleaseConsumerBumps', 'Get-ReleaseHighlightsBumps' -Default @())

# AND WHICH TIER'S ENTRIES FILL THAT DOCUMENT'S "what changed" section (inbound #747). The selection
# below was the literal 2 for its whole life, which in a repo whose audience is tier 1 rendered that
# section NEVER rather than rarely: its entries declare tier 0 and tier 1, so nothing ever landed in the
# tier-2 group, and the draft came out carrying only the two sections that cannot be generated. The
# document read as finished and never said what shipped.
#
# NOT A SECOND READER OF THE SEAM. Get-EntryAudienceTier already resolves Get-ReleaseAudienceTier for the
# scaffolder -- probing rather than requiring, rejecting a value outside the model, and returning $null
# where the repo has stated none -- and entry-scaffold-lib.ps1 is dot-sourced above. A private copy here
# is how the two would drift into disagreeing about the same repo's audience.
#
# $null FALLS BACK TO 2 BECAUSE 2 IS WHAT THIS FILE HARDCODED, so a repo that has answered nothing keeps
# producing exactly the document it produced before this line existed -- absent means UNCHANGED, the same
# reading Get-EntryAudienceTier takes of the same absence. The alternative, treating "stated none" as
# "select nothing", would empty the section in every consumer the moment they took the plugin update.
$audienceTier = Get-EntryAudienceTier
if ($null -eq $audienceTier) { $audienceTier = 2 }

# AND WHERE THAT DOCUMENT GOES, which until now was the one path in this file with no knob (inbound
# #616, reported from a consumer). Everything around it was already answered per repo -- the folder
# component by Get-ReleaseNotesGrouping, the release list by Get-ReleaseHistoryPath -- so the file
# already accepted that the folder inside this path varies while its root did not. That left the tier
# above UNANSWERABLE for a repo whose hand-written notes live elsewhere: naming the bumps would have
# pointed the cut at a directory that does not exist there and left the one that does out of the
# release, so the only safe answer was @(), the tier switched off.
#
# Get-ReleaseHistoryPath was the precedent for the reasoning, not any more for the CONSEQUENCE (issue
# #885): its default is now COMPUTED rather than flat, so something DOES change for a consumer who sets
# nothing -- deliberately, and the accepted cost is recorded at the computed default itself
# (Get-DefaultReleaseHistoryPath). The name follows this file's own vocabulary for the document
# (Get-ReleaseNoteWording, below) rather than the tier that reads it: since the two hand-written
# documents merged there is one release note with a named section per reader, and the consumer is a
# section of it, not its title.
#
# Get-ReleaseNoteRoot's DEFAULT deliberately does NOT move with this branch, unlike the three seams
# below it and Get-ReleaseHistoryPath above -- see its own contract record. Every one of those had NO
# seam at all until #885, so a computed default redefines nothing anyone was relying on; this one
# already had consumers configuring it or relying on its literal fallback, and "a repo that answers
# nothing must keep meaning what it meant yesterday" still holds for exactly that reason.
$noteRootRelPath = Get-SeamValue -Name 'Get-ReleaseNoteRoot' -Default 'releases/notes'

# THE THREE GENERATED ROOTS GAIN SEAMS HERE (issue #885, group E) -- the tier-0 changelog notes, the
# GitHub Release body and the tier-1 internal note. #885 is the measurement the comment above waited for:
# "a seam nobody can be shown to need is a knob a consumer has to read past. It comes back when somebody
# measures it." The first two are computed the same for BOTH kinds of repo since #914 -- they exist only
# because the workflow does, so they live in its folder everywhere -- while the internal root still keeps
# the source-versus-consumer branch #885 gave it, because #914 did not include it. Read together because
# all three name the SAME generated-notes tree at different tiers, and new-internal-note.ps1 must agree
# with the last two -- see its own matching seam reads.
#
# TWO NAMES READ, ONE WRITTEN (issue #947, August 26, 2026), the same shape as Get-ReleaseConsumerBumps
# further up. #914 renamed the DIRECTORY development -> changelog and deliberately left the seam alone,
# which left the two halves of one mechanism disagreeing by name: the seam said 'Development' while its
# own computed default said 'Changelog'. The current name is preferred and the retired one still
# answers, because a consumer receives this rename through a plugin update rather than by choosing to --
# without the fallback, a repo that had defined the old name would drop to the computed default in
# silence and the cut would start a second tree beside the one holding its notes.
$devNotesRootRelPath = Get-SeamValue -Name 'Get-ReleaseChangelogNotesRoot', 'Get-ReleaseDevelopmentNotesRoot' -Default (Get-DefaultReleaseChangelogNotesRoot -RepoRoot $repoRoot)
Assert-WorkflowIsolatedSeamPath -RepoRoot $repoRoot -RelativePath $devNotesRootRelPath -SeamName 'Get-ReleaseChangelogNotesRoot'
$githubNotesRootRelPath = Get-SeamValue -Name 'Get-ReleaseGithubNotesRoot' -Default (Get-DefaultReleaseGithubNotesRoot -RepoRoot $repoRoot)
Assert-WorkflowIsolatedSeamPath -RepoRoot $repoRoot -RelativePath $githubNotesRootRelPath -SeamName 'Get-ReleaseGithubNotesRoot'

# How many minors a major line must have had before a major may be cut. A major here is a RECAP of the
# minors before it, so what earns one is their accumulation -- 10 in this repo. Repo-owned because it is
# a release-cadence policy: a repo that cuts minors rarely would be pinned to a major it never reaches,
# and forking a shared script over one integer is exactly what the seam exists to prevent (#417).
$majorMinMinors = [int](Get-SeamValue -Name 'Get-ReleaseMajorMinMinors' -Default 10)

# RETIRED WITH THE RELEASE BLOCK (August 5, 2026): Get-ChangelogReleaseWording (inbound #462) configured
# the four strings a cut wrote into CHANGELOG.md -- the release section's intro, the notes pointer, and the
# sentence repointing it at the internal note. The cut writes none of them now. What replaced that block is
# the changelog intro's own one-line pointer to the release history: hand-written prose in a file the repo
# owns, which needs no seam to be in the repo's language because it simply is. See release-lib.ps1's
# retirement note for what the consumer who asked for #462 does and does not lose.

# BOM-less UTF8 -- the rest of the repo has no BOM.
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

# Root .md files this repo has named as permanent, checked FIRST as a manual override: never scanned
# regardless of content. No longer load-bearing for safety (see the content check below), so a repo
# that defines nothing and adds a new root doc is still safe -- but naming one here still costs nothing
# and settles it outright for a repo that would rather not rely on the content test.
#
# THE LIST MOVED TO THE SEAM IN #417 and no longer lives here. It had gone stale three times, each
# time blocking a release over a document nobody had failed to fold (#165, then QUICKSTART.md +
# UNINSTALL.md in #405, then ADOPTION.md in #408) -- three incidents that were the actual reason the
# stray-entry test below no longer treats "not on this list" as the danger signal (issue #885, group
# D). The fallback below is the workshop's own list, so a consumer that defines nothing still gets the
# override this script always had -- and it tracks that list rather than a snapshot of it: the install
# and uninstall pages left the root for plugins/, so they left here too.
$reservedRootMd = @(Get-SeamValue -Name 'Get-ReservedRootMd' -Default @(
    'CHANGELOG.md', 'CLAUDE.md', 'README.md', 'LICENSE.md', 'CONTRIBUTING.md', 'SECURITY.md'))

$script:marketplaceJsonText = $null
function Get-MarketplaceJsonText {
    # THE one read of marketplace.json, shared by the two things derived from it: which plugins exist,
    # and what the marketplace is called. Cached rather than re-read per caller -- two reads of one
    # file during a release that also WRITES files is exactly how the two answers start disagreeing,
    # and a function whose comment promises a single read has to deliver one.
    if ($null -eq $script:marketplaceJsonText) {
        $marketplacePath = Join-Path $repoRoot '.claude-plugin\marketplace.json'
        if (-not (Test-Path -LiteralPath $marketplacePath)) {
            Write-Error ".claude-plugin/marketplace.json is missing."; exit 1
        }
        $script:marketplaceJsonText = (Get-Content -Path $marketplacePath -Raw -Encoding UTF8)
    }
    return $script:marketplaceJsonText
}

function Get-PluginManifests {
    # The marketplace definition is the source of truth about what a plugin is: the set is derived from
    # plugins[] (incl. the containment check) by Get-PluginRoots in plugin-tree-lib.ps1 -- pure there and
    # thus tested. Here only the IO: the existence check.
    #
    # RETURNS THE ROOT OBJECTS, NOT BARE PATHS, and that removes two identical derivations further down.
    # Both this error and the bump report used to reconstruct the plugin's name by walking three
    # Split-Paths up from the manifest -- which is only the name because of where the folder happens to
    # sit. The marketplace states the name outright, so both now read it instead of inferring it.
    $roots = @(Get-PluginRoots -RepoRoot $repoRoot -MarketplaceJson (Get-MarketplaceJsonText))
    foreach ($p in $roots) {
        if (-not (Test-Path -LiteralPath $p.ManifestPath)) {
            Write-Error "Plugin '$($p.Name)' is listed in marketplace.json but is missing its manifest ($($p.ManifestPath))."; exit 1
        }
    }
    $roots
}

# --- Guardrails: on main, clean, no unfolded entries ---------------------------------------
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'main') { Write-Error "A release is cut directly on main; you are on '$branch'."; exit 1 }
if ((git status --porcelain)) { Write-Error "Working tree not clean -- commit/stash first."; exit 1 }

# ISSUE #885, GROUP D: inverted from a name blocklist to a CONTENT test. The old form treated every
# root *.md not on $reservedRootMd as an unfolded entry -- catch-all by name, so any permanent doc a
# consumer added had to be listed there too, or a release falsely refused to cut over a file nobody
# forgot to fold (measured three times: #165, #405, #408). An entry is recognisable by what it IS, not
# by what it is not: Test-BranchChangelogIsFilled is the same predicate the branch's own document is
# held to (see the branch/ guard just below), and it is true only for a document that either declares a
# non-trunk branch or opens with an entry-level heading (## or ###) -- a shape a consumer's own README,
# ticket file or ADOPTION.md essentially never has, since those open with a plain # title. So a new
# permanent root doc is safe with NO configuration, and $reservedRootMd above becomes an optional
# override rather than something that has to be kept current.
#
# -OpeningHeadingOnly IS WHAT MAKES THAT PROMISE TRUE (inbound #1099). It was not, and the gap was exactly
# the words "since those open with a plain # title": the name test does not read only the opening line, it
# scans EVERY heading, so one backticked word anywhere -- '## Deploying `web`', '## The `build` step' --
# declared a branch and turned an ordinary root doc into an unfolded entry. Measured in a live consumer on
# a test run's own log, whose '## Step 3 -- `specialists-init` * **PASS**' read as the branch
# 'specialists-init'. The switch stops the heading scan after the document's first heading, which is where
# every real entry declares its branch, so the class of file this comment calls safe now is.
$strayEntries = @(Get-ChildItem -Path $repoRoot -Filter '*.md' -File |
    Where-Object { $reservedRootMd -notcontains $_.Name } |
    Where-Object { Test-BranchChangelogIsFilled -Text ([System.IO.File]::ReadAllText($_.FullName)) -OpeningHeadingOnly } |
    Select-Object -ExpandProperty Name)
if ($strayEntries.Count -gt 0) {
    # THE REMEDY COVERS BOTH WAYS THIS GATE FIRES (inbound #1099, the #1081 lesson in another script).
    # "Fold them first" is right for the case the guard is FOR and DESTRUCTIVE for the other one -- a
    # permanent doc read as an entry gets pasted into CHANGELOG.md and deleted. The gate cannot tell the
    # two apart; the reader can, so it names both routes and the seam that settles it, which nothing on
    # screen used to mention.
    Write-Error ("There are still unfolded changelog entry files in the root: $($strayEntries -join ', '). " +
        "Fold them first (fold-changelog-entry.ps1) -- or, if one of them is NOT a changelog entry, add its " +
        "name to Get-ReservedRootMd in scripts\repo-config.ps1 and cut again.")
    exit 1
}

# THE SAME GUARD FOR branch/ (Dave, August 6, 2026). Since the split the entry arrives at a FIXED path, so
# the catch-all above cannot see it: that one is "every root *.md that is not a permanent doc", and this
# file is neither in the root nor stray -- it is a permanent part of the repo whose CONTENT decides whether
# work is pending. The test is therefore the content, not the file's existence, and it is the same
# structural test the fold uses to decide the file holds an entry at all.
#
# WHY IT MATTERS MORE HERE THAN THE ROOT VERSION DID. A cut EMPTIES CHANGELOG.md; an entry still sitting
# unfolded at this moment does not land in the release documents and is then orphaned on a trunk whose
# pending list has just been cleared. The root form announced itself by being a file nobody expected. The
# branch/ form looks exactly like the reset state at a glance, which is precisely why it needs a gate
# rather than a reader's attention.
$cutBranchDeploymentRel = Resolve-BranchFilePath -Kind Deployment -RepoRoot $repoRoot
$cutBranchDeployment = Join-Path $repoRoot $cutBranchDeploymentRel
if ((Test-Path -LiteralPath $cutBranchDeployment) -and
    (Test-BranchChangelogIsFilled -Text ([System.IO.File]::ReadAllText($cutBranchDeployment)))) {
    Write-Error "$cutBranchDeploymentRel still holds an unfolded entry. Fold it first (fold-changelog-entry.ps1); a cut empties CHANGELOG.md, so an entry left here would miss this release and be orphaned afterwards."
    exit 1
}

# --- Determine version + bump type ------------------------------------------------------------
# WHERE THE CURRENT VERSION COMES FROM depends on the plugin tier, and the two sources are not
# interchangeable (#417). With plugins, the manifests ARE the record and Get-LockstepVersion also
# proves they agree -- a disagreement is a defect this must not paper over. Without them there is no
# manifest to read, so the newest reachable tag is the record, which is what a repo with no plugins
# has always used. Deliberately not "tag if the manifests are missing": in this repo a manifest that
# vanished would then silently downgrade to a tag read, and the lockstep check would go with it.
$manifests = @()
$marketplaceName = ''
if ($pluginTier) {
    $manifests = @(Get-PluginManifests)
    if ($manifests.Count -eq 0) { Write-Error "No plugin manifests found."; exit 1 }
    # Read once, outside the per-plugin loop that consumes it: the name is a property of the marketplace,
    # not of the plugin, so re-deriving it per plugin would invite four answers to a one-answer question.
    $marketplaceName = Get-MarketplaceName -MarketplaceJson (Get-MarketplaceJsonText)
    # KEYED ON THE PLUGIN NAME rather than the manifest path. The key is only ever read back in
    # Get-LockstepVersion's error text, where a lockstep disagreement has to be readable at a glance --
    # 'dkj-subagents-alpha: 3.9.0' says which plugin is out of step; an absolute path makes the reader work out
    # the same fact from a folder name.
    $manifestContents = @{}
    foreach ($p in $manifests) { $manifestContents[$p.Name] = (Get-Content -Path $p.ManifestPath -Raw -Encoding UTF8) }
    $current = Get-LockstepVersion -ManifestContents $manifestContents
    # WHERE THE BASELINE CAME FROM, carried along as prose. The cross-check below refuses on a
    # disagreement between this number and the recorded release numbering, and a refusal that names only
    # the two numbers leaves the reader to work out which of them this script read and which it did not.
    $currentSource = 'the lockstep version in every plugin.json'
} else {
    $latestTag = @(git tag --list 'v*' --sort=-v:refname) | Select-Object -First 1
    if ($latestTag) {
        $current = ($latestTag -replace '^v', '')
        $currentSource = "the highest 'v*' git tag ($latestTag)"
    } elseif ($Version) {
        # First release in a repo with neither manifests nor tags: -Version says what it is, and
        # 0.0.0 exists only so the bump-type label below has something to compare against.
        $current = '0.0.0'
        $currentSource = 'neither a plugin manifest nor a v* tag -- this is a first release'
    } else {
        Write-Error "This repo publishes no plugins (Get-ReleasePluginTier is false) and carries no vX.Y.Z tag, so there is no current version to bump from. Pass -Version <X.Y.Z> for the first release."
        exit 1
    }
}

# -Type STATES what -Bump would already have said, so together they are two answers to one question --
# and where they disagree there is no reading of the command line that is obviously right. Refused rather
# than resolved by precedence, which is the same call the -Version/-Bump pair makes one line down.
if ($Type -and $Bump) { Write-Error "-Type states the bump type and -Bump already does -- use one. -Type belongs with -Version."; exit 1 }
if ($Version) {
    if ($Version -notmatch '^\d+\.\d+\.\d+$') { Write-Error "-Version must have the form X.Y.Z (e.g. 1.0.0)."; exit 1 }
    $new = $Version
} elseif ($Bump) {
    $new = Get-NextVersion -Current $current -BumpKind $Bump
} else {
    Write-Error "Provide -Version <X.Y.Z> or -Bump <major|minor|patch>. Current version: $current."
    exit 1
}
if ($new -eq $current) { Write-Error "New version ($new) equals the current one -- nothing to bump."; exit 1 }

# --- The release overview, read once ------------------------------------------------------------
# READ HERE, AHEAD OF THE FIRST GATE, for the reason the changelog read below gives: TWO guardrails
# need this file -- the baseline cross-check directly under this, and the new-major section check
# further down -- and a gate that runs after the first write is not a gate. One read, one snapshot, so
# the two cannot end up judging different versions of the same document.
$relReadmePath = Join-Path $repoRoot ($historyRelPath -replace '/', '\')
$historyContent = if (Test-Path -LiteralPath $relReadmePath) {
    Get-Content -LiteralPath $relReadmePath -Raw -Encoding UTF8
} else { $null }

# --- Guardrail: the baseline agrees with the RECORDED release numbering (inbound #802) -----------
# The baseline above is read from the manifests or the tag line. NEITHER IS THE DOCUMENT THAT SAYS WHICH
# RELEASE IS WHICH, and until August 21, 2026 nothing compared the two. Where they disagree, the number
# being cut can still be right while everything derived from the baseline is wrong at once and in
# silence: the '**Type:**' line in the notes, the Type cell of the overview row, the question the tier
# gate asks, and whether the hand-written consumer document is drafted at all.
#
# IT REFUSES ON BOTH ROUTES IN, WHICH GOES FURTHER THAN THE REPORT ASKED FOR (it proposed refusing only
# where -Version was passed). The reason is that -Bump is the worse of the two, not the safer one: with
# -Version the author has named the number and only its LABEL is wrong, while -Bump computes the number
# FROM the baseline, so a wrong baseline produces a version that belongs to a different release
# altogether. The reporting consumer met exactly that -- '-Bump minor' off a lagging tag proposed 2.14.0
# when the documents stood at 2.39.0 -- and was saved by an unrelated refusal further down, which is luck
# rather than a guard.
#
# -Type IS THE WAY THROUGH, and deliberately not a -Skip switch. A bypass would hand back the same wrong
# label the check exists to catch; stating the type produces a correct release from a repo whose tag line
# and numbering genuinely diverge. That is the report's own third option, taken as the escape valve for
# its first.
$recordedVersion = if ($historyContent) { Get-OverviewLatestVersion -ReadmeContent $historyContent } else { $null }
if ($recordedVersion -and $recordedVersion -ne $current -and -not $Type) {
    Write-Error @"
The baseline this release would be measured from does not match the one $historyRelPath records.

  baseline read here : $current   (from $currentSource)
  newest recorded    : $recordedVersion   (the first row of the release overview)

Nothing was written. Cutting from the wrong baseline does not necessarily produce the wrong version
NUMBER -- it produces the wrong bump TYPE, in four places at once and without a warning: the notes, the
overview row, the tier gate's judgement, and whether a consumer document is drafted.

Either close the disagreement -- tag the recorded release, or correct the overview's newest row,
whichever of the two is actually behind -- or state the type instead of having it inferred:

  -Version <X.Y.Z> -Type <major|minor|patch>

Use the second form where the divergence is deliberate (tags used for something other than releases,
per-component tags, imported history). It says what this release is rather than guessing it from a
number that is not about this release at all.
"@
    exit 1
}

# THE TYPE IS STATED WHERE -Type SAYS SO, and inferred from the two numbers otherwise. Get-BumpType is a
# pure SemVer comparison and was never the defect -- the baseline it was being fed was.
$bumpType = if ($Type) { $Type } else { Get-BumpType -From $current -To $new }
$typeLabel = @{ major = 'Major'; minor = 'Minor'; patch = 'Patch' }[$bumpType]
$tagName = "v$new"
if ((git tag --list $tagName)) { Write-Error "Tag $tagName already exists."; exit 1 }

# --- The changelog, read once -------------------------------------------------------------------
# READ HERE RATHER THAN FURTHER DOWN, because the tier gate below needs it and a gate that runs after
# the first write is not a gate. Nothing between this read and the write at the end touches the file, so
# reading early costs nothing and means the whole run judges ONE snapshot of the changelog.
#
# SEAMED (issue #885, group A): this used to be hard-coded to 'CHANGELOG.md', with no seam and no guard,
# so a repo whose changelog is not at the root threw an unhandled error rather than a refusal that said
# what was wrong. Get-DefaultChangelogPath's computed default keeps this repo's own answer unchanged --
# it publishes plugins, so the default IS 'CHANGELOG.md' -- while a consumer is isolated by default.
$changelogRel = Get-SeamValue -Name 'Get-ChangelogPath' -Default (Get-DefaultChangelogPath -RepoRoot $repoRoot)
Assert-WorkflowIsolatedSeamPath -RepoRoot $repoRoot -RelativePath $changelogRel -SeamName 'Get-ChangelogPath'
$changelogPath = Join-Path $repoRoot $changelogRel
# READ DEFENSIVELY, same reasoning fold-changelog-entry.ps1 already reads by: an absent changelog is not
# a reason to crash, it is nothing pending -- Get-PullRequestEntriesByTier finds no block in '' correctly.
$changelogRaw = ''
if (Test-Path -LiteralPath $changelogPath) {
    $changelogRaw = [string](Get-Content -Path $changelogPath -Raw -Encoding UTF8)
}
$tierGroups = @(Get-PullRequestEntriesByTier -Content $changelogRaw)
$entries = @($tierGroups | ForEach-Object { $_.Entries } | Where-Object { $_ })

# --- Guardrail: has this bump been earned? (the tier model, August 5, 2026) ------------------------
# The rules live in Test-ReleaseBumpEarned (release-lib, tested) AND ITS DOCSTRING IS THE STATEMENT OF
# THEM -- read them there, not here. In outline: THE BUMP FOLLOWS THE HIGHEST TIER PENDING, and a major
# additionally needs enough minors behind it. The version number was always supposed to mean this; until
# the tier model nothing checked, so the meaning depended on whoever typed the flag.
#
# DELIBERATELY NOT RESTATED, BECAUSE THE RESTATEMENT IS WHAT WENT WRONG (issue #1140, August 30, 2026).
# These lines summarised the function so a reader would not have to open it -- and then carried the
# PRE-AUGUST-7 LADDER for three weeks after Dave loosened both of its halves: "any release needs a
# tier-1 entry at minimum" (a tier-0-only release cuts as a PATCH -- publishing to no audience is what a
# patch is for) and "a minor needs a tier-2 one" (tier 1 or higher earns a minor -- the version speaks to
# all stakeholders, not to consumers alone). A reader who trusted this walked away with a STRICTER model
# than the gate enforces, in both directions, and at least one did: the sentence was copied into a draft
# assert and caught only by opening Test-ReleaseBumpEarned to check the major rule.
#
# IT WAS NOT THE FIRST COPY OF THIS DRIFT, WHICH IS THE ARGUMENT FOR THE POINTER. release-lib's own
# $notable counter carried a stale tier-2 count for exactly the same reason and was cleaned up on
# August 12, 2026; the note there says so. That copy sat INSIDE the function and still went stale -- so a
# copy two files away, at the call site, was never going to hold. The gate is one dot-source away; send
# the reader there.
#
# PLACED WITH THE OTHER GUARDRAILS, BEFORE ANYTHING IS WRITTEN, for the same reason the new-major check
# is: failing after the notes file exists leaves a release half-cut on main.
#
# IT SWITCHES ITSELF OFF where no pending entry declared its impact at all -- which means the repo has not
# adopted the model, not that nothing qualifies. That test used to be "does the repo declare more than one
# changelog section", and it had to change with the sections: a flat changelog gives an unadopted repo and
# an adopting one exactly one group each, so the old signal would have read every repo as unadopted and
# switched this gate off silently. See Test-ReleaseBumpEarned for why 'declared tier 0' and 'declared
# nothing' must not be confused.
if (-not $SkipTierGate) {
    $earned = Test-ReleaseBumpEarned -BumpType $bumpType -TierGroups $tierGroups `
        -CurrentVersion $current -MinMinorsForMajor $majorMinMinors
    if ($earned.Active -and -not $earned.Earned) {
        $breakdown = ($tierGroups | ForEach-Object {
            "  tier $($_.Tier): $(@($_.Entries | Where-Object { $_ }).Count) entry/entries"
        }) -join "`n"
        $suggestion = if ($earned.EarnedBump) {
            "What the pending work does earn: -Bump $($earned.EarnedBump)."
        } else {
            "Nothing pending earns a release. Raise the tier of an entry that deserves it, or wait for work that does."
        }
        Write-Error @"
This $bumpType has not been earned by the pending changelog entries. Nothing was written.

$($earned.Reason)

Pending, per tier:
$breakdown

$suggestion

The tiers are how far a change reaches: 0 = only this repo's own developers notice, 1 = management and
the employer/commissioner get something out of it, 2 = a subscriber of the service notices it. An entry's
tier is the highest row of its own impact table in CHANGELOG.md; raise it, or correct the bump.
-SkipTierGate overrules this, deliberately separate from -SkipLint because it overrules a judgement
about content rather than skipping a tool.
"@
        exit 1
    }
}

# --- Guardrail: has every entry that gets ranked said how much it weighs? (issue #467) --------------
# The significance score orders the release documents, so an entry without one cannot be placed -- and the
# fallback ("sorts last") would quietly punish a forgotten line in the very document whose subject is
# which change matters most. This is Dave's chosen refusal point (August 5, 2026): the branch may merge
# without a score, the release may not be cut without one. By now the branch is long gone, so the fix is
# one edit in CHANGELOG.md rather than a reopened PR.
#
# ONLY TIER 1 AND UP ARE ASKED, because only they reach a ranked document. Tier 0 is the record: complete
# and chronological, and never sorted.
#
# THE TIER COMES FROM THE ENTRY, which is the reversal in this change. It used to come from the changelog
# SECTION, because the fold consumed the 'Tier:' line the moment the section took over stating it -- so
# $tierGroups was the only thing that knew, and this gate could not have lived in the fold. With the
# sections gone the entry carries its own declaration into the changelog, and $tierGroups is simply where
# that declaration has already been read once.
#
# SAME OFF-SWITCH AS THE SCAFFOLD AND THE FOLD: Test-EntrySignificanceActive, which now defaults ON with
# Get-EntrySignificanceEnabled as the opt-out. A repo that sets it $false opted out of all three at once --
# a score that is demanded but never read is worse than no score. Note this is a DIFFERENT off-switch from
# the bump gate's above: that one asks whether the repo declares tiers at all, this one whether it wants
# them ranked, and a repo can want the first without the second.
if (-not $SkipSignificanceGate -and (Test-EntrySignificanceActive)) {
    $significanceProblems = @()
    foreach ($group in $tierGroups) {
        if ([int]$group.Tier -lt 1) { continue }
        foreach ($entry in @($group.Entries | Where-Object { $_ -and $_.Trim() })) {
            $findings = @(Get-EntryImpactFindings -EntryText $entry)
            if ($findings.Count -eq 0) { continue }
            # Named by its heading, so the operator can find the entry in a 1,000-line changelog. The
            # heading is the entry's first line; '### #468 <md> Title <md> Feat' is enough to locate it.
            $heading = (($entry -split "`r?`n")[0] -replace '^#+\s*', '').Trim()
            foreach ($finding in $findings) { $significanceProblems += "  $heading`n      $finding" }
        }
    }
    if ($significanceProblems.Count -gt 0) {
        $rubric = (Format-EntrySignificanceRubricLines) -join "`n"
        Write-Error @"
$($significanceProblems.Count) pending entry/entries have not said how much they weigh. Nothing was written.

$($significanceProblems -join "`n")

The rubric:
$rubric

The score decides where in its release document an entry sits -- highest first -- so the most
consequential change leads. Every tier an entry reaches owes a row, because every tier is a document with
its own reader:

  | Tier | Significance | Why |
  |---|---|---|
  | 2 | 5 | what a subscriber of the service gets out of it |
  | 1 | 4 | what management and the employer/commissioner get out of it |

Add the rows to the entries in CHANGELOG.md and cut again.

-SkipSignificanceGate overrules this, deliberately separate from -SkipLint: this overrules a judgement
about content, while -SkipLint skips a tool.
"@
        exit 1
    }
    if (-not $earned.Active) {
        Write-Host "  (no pending entry declares its impact -- this repo has not adopted the tier model, so the bump gate does not apply.)" -ForegroundColor DarkGray
    }
}

# --- Guardrail: a NEW MAJOR needs its own overview section before the row can land ----------------
# Placed here, with the other guardrails, because it must stop the run BEFORE anything is written: the
# row insertion happens after the notes file already exists, and failing there would leave a release
# half-cut. Get-OverviewTargetMajor (release-lib, tested) answers where the row would actually go.
#
# The failure this prevents is silent, not loud: the inserter matches the FIRST table header, so on a
# major bump a 'v3.0.0' row is filed neatly under '### 2.x' and nothing errors. And it has never been
# hit, because the grouping-by-major arrived in v2.0.1 -- one release after the only major ever cut.
# Rare plus silent is the worst combination for a manual step, which is why this speaks up instead.
#
# The path comes from Get-ReleaseHistoryPath rather than being hardcoded (August 4, 2026). That seam
# already answers "where does this repo keep its release history?" for the changelog's pointer, and the
# overview table IS that history -- so one answer serves both. Two hardcoded copies would be two places
# that have to keep agreeing, and the day they stop, the changelog points at one file while the row
# lands in another.
#
# IT READS THE SNAPSHOT TAKEN AT THE BASELINE CROSS-CHECK rather than opening the file a second time
# (August 21, 2026, with inbound #802). Two reads of one document meant two answers were possible to the
# question of what it says, and the two guardrails that ask it sit on either side of the tier gate.
$newMajor = ($new -split '\.')[0]
if ($historyContent) {
    $targetMajor = Get-OverviewTargetMajor -ReadmeContent $historyContent
    if ($null -ne $targetMajor -and $targetMajor -ne $newMajor) {
        # The heading is QUOTED BACK AT THE LEVEL THE DOCUMENT USES, not at a level this script assumes.
        # It hardcoded '###' until August 4, 2026, which broke the moment the release list was nested one
        # deeper under a repo-specific section heading: the advice then told you to add a heading whose
        # level the guardrail would not recognise, so following it exactly would leave the guardrail off.
        # Get-OverviewSectionHeading reports what was actually matched, from the same pattern.
        $targetHeading = Get-OverviewSectionHeading -ReadmeContent $historyContent
        $hashes = ($targetHeading -split '\s+')[0]
        $newHeading = "$hashes $newMajor.x"

        # The message must state what is actually KNOWN, not assume a direction. The mismatch is
        # reachable both ways, and the two ways need different remedies:
        #   newMajor > target -- the usual case: a new major whose section does not exist yet.
        #   newMajor < target -- the section exists but is not on top, because a HIGHER major was opened
        #     already. Saying "has no '2.x' section yet" there would be plainly false, and a
        #     guardrail that misdescribes the repo teaches people to bypass it.
        $advice = if ([int]$newMajor -lt [int]$targetMajor) {
            "'$newHeading' does exist, but '$targetHeading' sits above it, so that is where the row goes.`n" +
            "Releasing an older major after a newer one has been opened needs a decision this script will not make for`n" +
            "you: either move the row by hand after cutting, or reconsider the version."
        } else {
            # Positioned RELATIVE to the heading that was actually found, not under a named heading of
            # its own. It used to say "directly under '## Overview'", which was stale from the day the
            # overview moved out of releases/README.md into its own history page -- and naming any fixed
            # heading is wrong on principle here, because the history file is repo-owned via
            # Get-ReleaseHistoryPath and a consumer's may be structured differently. The '<n>.x' heading
            # is the one shape this script does depend on, so that is the one it may point at.
            # THE ADVICE NAMES BOTH EDITS, NOT JUST THE SECTION (August 9, 2026). A repo may also PIN the
            # major its overview targets in a test -- this repo does, deliberately, so the overview and the
            # pin are one fact written twice and a half-done edit cannot land quietly. The consequence is
            # that opening the section turns that test red, and until this message said so, the second
            # commit arrived as a surprise AFTER following advice that read as complete. Naming it costs two
            # lines and removes nothing: the pin is still repointed by a person, which is the whole point of
            # having it. Phrased as a conditional because the pin is repo-owned -- a consumer without one
            # reads a sentence that does not apply, which is strictly better than hitting a red test with no
            # idea it was coming.
            #
            # AND THE CLOSING SENTENCE INHERITS THAT CONDITION RATHER THAN OVERRIDING IT (inbound #1152,
            # August 30, 2026). It read "Both edits belong to this cut", which is true HERE -- a section edit
            # and a pin edit -- and false in a consumer repo that has no pin, where the sentence before it
            # said so in capitals. Measured in a fresh consumer (DaveKJohn/ccs-testrun-4, cutting v1.0.0
            # against v4.26.0): a reader who correctly concluded "that paragraph is not mine" was told one
            # line later to make two edits, and went looking for the second. The conditional phrasing above
            # was deliberate for exactly this reader; a closing sentence that counts the edits unconditionally
            # takes it back, at a milestone moment where the message has just told them to be careful.
            "Add the section first -- directly ABOVE '$targetHeading', at that same heading level:`n`n" +
            "$newHeading`n`n| Version | Date | Type | Title |`n|---|---|---|---|`n`n" +
            "Then, IF this repo pins the targeted major in a test, repoint that assertion at '$newMajor' and`n" +
            "write down why, next to it -- opening the section is what turns it red, and that is the pin doing`n" +
            "its job rather than a broken test. The section edit belongs to this cut, and the pin with it if`n" +
            "this repo has one, so each goes on the trunk ahead of the release commit.`n`n" +
            "Then run this again. Opening a new major's section is a deliberate milestone moment, which is why it`n" +
            "is not done for you."
        }
        Write-Error @"
This release is v$new, but a new row in $historyRelPath would be filed under '$targetHeading'
(the first table in the overview). Nothing was written.

$advice
"@
        exit 1
    }
}

# --- Lint gate ----------------------------------------------------------------------------------
# The release route's OWN gate, and it needs one precisely because this route does not travel via a
# PR: nothing else here ever meets open-pr's copy of it.
#
# RESOLVED THROUGH THE SEAM, not by a fixed path (inbound #464). Until August 5, 2026 this read
# `Join-Path $PSScriptRoot '..\lint\check-plugin-integrity.ps1'` -- the SOURCE repo's own lint script,
# by a path that only exists in the source repo. From a consumer's plugin cache that file is not
# there, so every consumer release ran with no gate at all and said so in a warning nobody had to act
# on. Get-LintScript is the same seam open-pr already reads for exactly this question, so the two
# routes now run the same repo's gate instead of one of them running this repo's.
#
# The measured cost of not having it, in the repo that reported this: two dead links reached its main
# through the release route and would have blocked every subsequent PR. That repo ran a lint here for
# that reason, and adopting the shared script silently took it away again.
#
# A MISSING SCRIPT IS A HARD STOP rather than a warning, which is the second half of the repair. A
# gate that switches itself off on a condition the operator did not choose is not a gate; -SkipLint is
# how you choose it, and choosing it is recorded in the command instead of in output that scrolls past.
if (-not $SkipLint) {
    $lintRel  = Get-SeamValue -Name 'Get-LintScript' -Default 'scripts\lint\check-plugin-integrity.ps1'
    $lintPath = Join-Path $repoRoot $lintRel
    if (-not (Test-Path -LiteralPath $lintPath)) {
        Write-Error "the lint gate '$lintRel' does not exist in the repo root ($repoRoot) -- release aborted. Point Get-LintScript in scripts\repo-config.ps1 at this repo's lint script, or run with -SkipLint to cut without a gate."
        exit 1
    }
    Write-Host "lint gate: integrity check for the release ($lintRel)..." -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $lintPath
    if ($LASTEXITCODE -ne 0) { Write-Error "the lint gate found errors -- release aborted. Fix them, or run with -SkipLint."; exit 1 }
}

# THE TEST GATE, ADDED AUGUST 7, 2026 (issue #510). Until then the release ran the lint ALONE, which made
# the release commit the least-checked commit in the whole workflow: every ordinary PR passes the lint AND
# all the suites locally, and CI runs both again before the merge is allowed. The release ran one of the
# two, and its push to main is not held back by the required check -- so a red suite could be committed,
# tagged and pushed, with CI reporting it only afterwards, when the tag was already on it.
#
# BEFORE ANY WRITE, deliberately -- same position as the lint above. A release that fails halfway through
# leaves a half-bumped tree on main under one of this repo's two direct-commit exceptions, which is the
# one place a failure is expensive to unpick.
#
# WHAT THIS STILL CANNOT SEE, so nobody reads more into it than it gives: the suites run against the tree
# BEFORE the cut, so a defect the cut itself introduces -- a malformed RELEASE.md card, a broken generated
# note -- is invisible to them. CI on the main push is what catches that, after the fact. The two are
# complementary and neither replaces the other; that is why #510 asks for both.
#
# Shares Invoke-TestSuiteGate with open-pr.ps1 rather than repeating its loop -- one owner, so the two
# gates cannot drift into checking different things.
if (-not $SkipTests) {
    if (-not (Invoke-TestSuiteGate -TestsDir (Join-Path $repoRoot 'scripts\tests') -Context 'the release' -MaxParallel $MaxParallel)) {
        Write-Error "test gate found failing suites -- release aborted, nothing written. Fix the tests, or run with -SkipTests to cut without them."
        exit 1
    }
}

# --- Build content (before the write actions, so a parse error leaves nothing behind) --------
# The notes folder: '<X>.x' per major (this workshop) or '<X.Y>' per minor, from the seam (#417).
# $notesDirName is used for the path, the README row link and the directory creation below, so the
# scheme is answered once rather than three times.
$notesDirName = if ($notesGrouping -eq 'minor') {
    $p = $new -split '\.'; "$($p[0]).$($p[1])"
} else {
    ($new -split '\.')[0] + '.x'
}
$notesRelPath = "$devNotesRootRelPath/$notesDirName/$new.md"
$today = (Get-Date -Format 'yyyy-MM-dd')

# $changelogPath / $changelogRaw / $tierGroups / $entries were read up with the bump gate, which had to
# see them before the first write. $entries is the flat list, in document order across the tiers -- the
# per-plugin loop below selects on the 'Plugins:' line and is deliberately tier-blind: a plugin's
# consumer-facing CHANGELOG carries everything that touched that plugin.

# -SummaryFile: an authored milestone block, read here rather than passed as a string, because a
# multi-page summary does not survive a command line. Deliberately NOT required to live in the repo:
# its canonical home becomes the generated notes file, and keeping a second copy under releases/ just
# to feed this parameter would be the duplication this repo removes elsewhere.
$summaryText = ''
if ($SummaryFile) {
    if (-not (Test-Path -LiteralPath $SummaryFile -PathType Leaf)) {
        Write-Error "-SummaryFile '$SummaryFile' does not exist. Nothing was written."
        exit 1
    }
    $summaryText = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $SummaryFile).Path, [System.Text.Encoding]::UTF8)
    if (-not $summaryText.Trim()) {
        # An empty file is a mistake worth stopping on: it would silently produce an ordinary release
        # while the operator believes they cut a milestone.
        Write-Error "-SummaryFile '$SummaryFile' is empty. Nothing was written."
        exit 1
    }
}

# The changelog notes are ORDERED by tier, each tier a flat ranked list of entries, at CHANGELOG.md's own
# heading levels -- literally the same shape, which is what makes this tier "the whole changelog, raw and
# complete", and what lets a hand-written note paste an entry at the level it was written at (#881). A repo
# whose entries declare no tier gets one group and the same document in arrival order.
#
# THE LINK PREFIX IS DERIVED, exactly as the hand-written draft below does it, and this call was the ONE
# that still left it at Build-ReleaseNotes' '../../../' default (issue #914, August 26, 2026). That default
# is the depth of a root sitting directly under releases/, which is where this tree sat until #914 moved it
# into dkj-policy/ -- one level deeper, so every relative link in every note this cut writes
# would have pointed one directory short. Nothing would have errored: a dead relative link in a generated
# document is discovered by a reader, and this repo has already paid for that once (the v4.6.0 overview
# row). The derivation is what makes the root a seam rather than a constant.
#
# AND IT IS MEASURED FROM THE CHANGELOG, NOT FROM THE REPO ROOT (inbound #1047, August 28, 2026). It used
# to count the note's own segments back to the root -- `('../' * $notesDepth)` -- which is the entry's base
# only while CHANGELOG.md sits AT the root. It stopped sitting there when #914 made the changelog
# isolate-by-default, and in this repo when it moved into contributing-davekjohn/ on August 27, 2026, so
# the prefix was one directory too deep and every link the PR gate had just dictated landed dead in a
# tagged, immutable document. Get-EntryLinkPrefix answers both halves at once and is shared with the draft
# below, so the two documents cannot disagree about where the entry text came from.
$notesLinkPrefix = Get-EntryLinkPrefix -NoteRelPath $notesRelPath -ChangelogRelPath $changelogRel
$notesContent = Build-ReleaseNotes -TierGroups $tierGroups -Version $new -Date $today -Type $typeLabel `
    -Title $Title -Summary $summaryText -LinkPrefix $notesLinkPrefix
# THE CHANGELOG IS EMPTIED, AND NOTHING IS WRITTEN BACK INTO IT (August 5, 2026). This call used to hand
# over the version, the date, the type, the notes path and three seam values to rebuild a release block and
# one section per tier. There is no block and there are no sections: the intro stays as the repo wrote it,
# the entries this release just consumed are removed, and the only thing left saying where releases live is
# the pointer in that intro -- which is why this now takes the content and nothing else.
$changelogNew = Convert-ChangelogForRelease -Content $changelogRaw

# AND THE PENDING TALLY IS RESET WITH THEM (issue #1515). The line sits in the document's HEAD, which is
# exactly what Convert-ChangelogForRelease keeps verbatim -- so without this call a freshly cut changelog
# would carry an intact "15 / 37 minor entries" over an empty list, which is the worst shape a derived line
# can take: not missing, but confidently wrong. It is re-derived rather than blanked, so the empty state is
# written by the same function that writes every other state.
$changelogNew = Set-ChangelogPendingSummary -Content $changelogNew

# The ONE hand-written release document, drafted here with everything else so a failure leaves no
# half-written release behind. Two documents used to be written per release -- an internal note for the
# organisation and a consumer document -- and both were written at all twelve releases since the internal
# tier existed, about the same changes. This is one file with a named section per reader (Dave, August 10,
# 2026); the measurement that refused a BLENDED document instead is in Build-ReleaseNoteDraft.
#
# THE TWO CONDITIONS SPLIT ACROSS TWO DECISIONS NOW, which is the change. The seam decides whether a
# document is written AT ALL -- so a patch writes none and the release is announced by the generated body
# alone. The audience-entry count decides only whether that document gets its AUDIENCE SECTION: the
# organisational half applies to every release the seam names, while a section about work the audience
# cannot see is worse than no section, because it looks written.
#
# BEFORE THIS, BOTH CONDITIONS GATED THE WHOLE FILE, so a tier-1-only minor produced no consumer document
# and an internal note from a second script. The audience of each SECTION follows the tier; whether there
# is a document follows the bump.
#
# AND WHICH TIER THAT AUDIENCE SECTION DRAWS FROM IS THE REPO'S ANSWER, not the literal 2 (inbound #747).
# In this repo the answer IS 2, so this call produces exactly the document it produced before -- the
# change is only visible in a repo that answered 1, where the section existed in no release at all.
$audienceEntries = @($tierGroups | Where-Object { [int]$_.Tier -eq $audienceTier } | ForEach-Object { $_.Entries } | Where-Object { $_ })
$cutNote = ($consumerBumps -contains $bumpType)
$noteRelPath = "$noteRootRelPath/$notesDirName/$new.md"
if ($cutNote) {
    $noteWording = Get-SeamValue -Name 'Get-ReleaseNoteWording', 'Get-InternalNoteWording' -Default @{}
    # The link prefix is DERIVED rather than left at the '../../../' default (August 14, 2026): that
    # default is the depth of releases/audience/<X>.x/ under a repo-root changelog, and a consumer whose
    # note root sits inside the workflow folder is one level deeper -- every relative link in the note
    # would silently point one directory short. Measured from the CHANGELOG's directory since inbound
    # #1047, by the same one owner as the tier-0 notes above; see that call's comment for why the repo
    # root was the wrong base.
    $noteLinkPrefix = Get-EntryLinkPrefix -NoteRelPath $noteRelPath -ChangelogRelPath $changelogRel
    $noteContent = Build-ReleaseNoteDraft -Entries $audienceEntries -Version $new -Date $today `
        -Type $typeLabel -Title $Title -Wording $noteWording -LinkPrefix $noteLinkPrefix `
        -AudienceTier $audienceTier
}

# --- Write the release-notes file -------------------------------------------------------------
# EVERY target is checked before ANY of them is written. With the consumer tier on there are two
# files, and stopping halfway through would leave a release whose notes exist and whose stakeholder
# document does not -- discovered by the release manager rather than by this guard.
# Kept as REPO-RELATIVE paths and joined per check: the message has to name the file the way the repo
# does, and [System.IO.Path]::GetRelativePath does not exist in the .NET Framework that Windows
# PowerShell 5.1 runs on -- it would throw here instead of reporting the collision it was written for.

# --- The GitHub Release body (generated, every release) -------------------------------------------
# WRITTEN HERE BECAUSE IT CANNOT BE WRITTEN LATER: this run empties CHANGELOG.md, so the entries the
# body is a list of are gone by the time anyone reaches the publish step. Its pointer is gated on a
# hand-written document actually being expected -- naming an attachment that will not exist is exactly
# the sort of confidently wrong line this repo keeps finding in published records.
#
# IT LIVES IN ITS OWN ROOT, AND THE ROOT IS THE STATEMENT (Dave, August 12, 2026). This file used to be
# written into the tier-0 root as '<X.Y.Z>-github-body.md', which put the one GENERATED document that
# does get published inside the directory whose whole job is the record nobody publishes. Each root answers
# one question now: changelog/ is the record, audience/ is the hand-written published document, github/ is
# the generated published one. The '-github-body' suffix went with the move, because the root says it and
# both siblings are '<X.Y.Z>.md' already.
#
# SEAMED NOW (issue #885, group E) -- see $devNotesRootRelPath's own comment above for why the same
# measurement that ended the "no seam, deliberately" era applies to this root too.
$bodyRelPath = "$githubNotesRootRelPath/$notesDirName/$new.md"
$bodyPointer = if ($cutNote) {
    "Whether you need to act, and what it is worth: see the notes attached to this release."
} else {
    ''
}
$bodyContent = Build-GitHubReleaseBody -Entries $entries -Version $new -Title $Title -NotePointer $bodyPointer

$plannedFiles = @($notesRelPath, $bodyRelPath)
if ($cutNote) { $plannedFiles += @($noteRelPath) }
foreach ($rel in $plannedFiles) {
    if (Test-Path -LiteralPath (Join-Path $repoRoot ($rel -replace '/', '\'))) {
        Write-Error "$rel already exists. Nothing was written."
        exit 1
    }
}
$notesAbs = Join-Path $repoRoot ($notesRelPath -replace '/', '\')

$notesDir = Join-Path $repoRoot (($devNotesRootRelPath -replace '/', '\') + "\$notesDirName")
New-Item -ItemType Directory -Force -Path $notesDir | Out-Null
Write-Utf8NoBom -Path $notesAbs -Content $notesContent
Write-Host "  created: $notesRelPath ($($entries.Count) entries)" -ForegroundColor DarkGray
# THE BODY'S DIRECTORY IS DERIVED FROM ITS OWN PATH rather than rebuilt from the root and the grouping.
# It used to land in $notesDir, so the single New-Item above covered it; now that the two roots differ, a
# second hand-built path would be a second definition of where this file goes. The first cut into a fresh
# major is the run that would find out, because that is the only one where the directory does not exist yet.
$bodyAbs = Join-Path $repoRoot ($bodyRelPath -replace '/', '\')
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $bodyAbs) | Out-Null
Write-Utf8NoBom -Path $bodyAbs -Content $bodyContent
Write-Host "  created: $bodyRelPath (the GitHub Release body -- generated, no editing needed)" -ForegroundColor DarkGray

# --- Update the releases/README.md overview table ------------------------------------------------
# The overview table header is English ("Version | Date | Type | Title", #114 follow-up), so
# $headerRe below matches that; a new row is inserted right after it. The overview is grouped by
# major version (### 2.x, ### 1.x, ... newest first), each group its own table with this same
# header; $headerRe.Match returns the FIRST match, so the row always lands in the top (current
# major) table -- correct for every minor/patch bump. A brand-new major starts a new top section
# manually first (a deliberate milestone moment), after which its table becomes the insertion target.
# Same seam as the guardrail above, so the file this row lands in and the file the changelog points at
# cannot drift apart.
$shortTitle = if ($Title) { $Title } else { "$typeLabel release" }
# THE VERSION CELL POINTS AT THE MOST READABLE DOCUMENT THIS RELEASE HAS, and the cut can finally write
# that itself. It used to always name the development notes, with new-internal-note.ps1 repointing the cell
# afterwards (Set-ReleaseInternalNoteLink) for the one reason that the note did not exist while this ran.
# The hand-written note is drafted above now, so the row is right the first time and there is no second
# writer of the same cell. A release with no note -- a patch -- keeps pointing at the record, which is the
# most readable document it has.
# AND IT READS Get-ReleaseNoteRoot RATHER THAN SPELLING THE ROOT OUT. This line carried the literal
# 'notes/' and produced a dead row the day that seam became 'releases/audience' (caught at the v4.6.0 cut,
# August 12, 2026, by the -NoPush inspection). Nothing errored: the row pointed at a file the same run had
# just written somewhere else, and every neighbouring row was correct because a PR had repointed them by
# hand. The rename moved the directory, the reader and the archives, and missed the one place the path was
# a string -- which is why the release manager's lens states 'read the seam, never hardcode the root'.
# AND THE ROW IS COMPUTED RELATIVE TO THE HISTORY FILE'S OWN DIRECTORY (August 14, 2026). This was
# `-replace '^releases/'`, with a comment conceding that a history root outside releases/ "would need a
# '../' here, which no repo has yet asked for" -- the workflow folder was that ask: between August 14 and
# 19, 2026 this repo's history sat at dkj-policy/releases/README.md while the generated
# development notes stayed at the repo root. Get-RelativeLinkPath answers both layouts, and for this repo
# it produces byte-identical rows to the old strip. The history moved back to releases/README.md on
# August 19 -- the handling stays, because a consumer may still answer the seam with a root elsewhere.
$historyDirRel = if ($historyRelPath -match '/') { $historyRelPath -replace '/[^/]+$', '' } else { '' }
$rowTargetRel = if ($cutNote) { "$noteRootRelPath/$notesDirName/$new.md" } else { "$devNotesRootRelPath/$notesDirName/$new.md" }
$versionTarget = Get-RelativeLinkPath -FromDir $historyDirRel -To $rowTargetRel
$newRow = "| [$new]($versionTarget) | $today | $typeLabel | $shortTitle |"
if (Test-Path -LiteralPath $relReadmePath) {
    $rm = Get-Content -LiteralPath $relReadmePath -Raw -Encoding UTF8
    $rmNl = Get-DocumentNewline -Content $rm
    $headerRe = [regex]"(?m)^\| Version \| Date \| Type \| Title \|\r?\n\|[-| ]+\|\r?\n"
    $hm = $headerRe.Match($rm)
    if ($hm.Success) {
        $at = $hm.Index + $hm.Length
        $rm = $rm.Substring(0, $at) + $newRow + $rmNl + $rm.Substring($at)
        Write-Utf8NoBom -Path $relReadmePath -Content $rm
        Write-Host "  updated: $historyRelPath" -ForegroundColor DarkGray
    } else {
        Write-Warning "Overview table not found in $historyRelPath -- add the row manually: $newRow"
    }
} else {
    # $historyRelPath, not the literal: the two messages above already use the seam, and this is the one
    # that fires when the file is MISSING -- i.e. exactly when the reader is about to go looking for the
    # path it names. A repo that had repointed the seam was being sent to the default instead.
    Write-Warning "$historyRelPath is missing -- row not added: $newRow"
}

Write-Utf8NoBom -Path $changelogPath -Content $changelogNew

# RETIRED, AUGUST 8, 2026: the per-plugin CHANGELOG.md and RELEASE.md card.
#
# The cut used to write two documents into every plugin directory -- a per-plugin history and a
# snapshot card naming the current version -- on the reasoning that they "travel along with the
# plugin cache" and are therefore what a consumer can actually read. Measured on the day they were
# removed, that reasoning does not hold: the marketplace source is a GIT CLONE OF THE WHOLE REPO, so
# a consumer already has the root CHANGELOG.md and the full releases/ tree at
# ~/.claude/plugins/marketplaces/<marketplace>/. The 11,684 lines in those ten files were a second
# copy of something the reader had all along -- and a copy that could disagree, which is what checks
# 9 and 17 existed to police.
#
# One repository, one product, one changelog. Decision by Dave, August 8, 2026.
#
# What this deliberately does NOT change: the lockstep version bump. plugin.json is still the place a
# plugin's version lives, and it is still bumped for every plugin in step 3a -- a consumer running
# the core team alongside an add-on team still needs matching versions. What is gone is a SECOND statement of that
# same version, in prose, in a file nothing reads back.

# --- 3d. The consumer document (stakeholder-facing; only for the bump types the seam names) ---------
# Content and collision were both settled above, so this block is pure IO. It writes NOTHING when the
# tier is off, which is every release in this repo -- see the seam for why the answer here is empty.
#
# THE NOTE'S DIRECTORY IS DERIVED FROM ITS OWN PATH, exactly as the Release body's is twenty lines up
# and for the same reason. This line built it from a hardcoded 'releases\notes\' until August 13, 2026,
# which is the seam escaping in a THIRD spelling: the two asserts that guard the seam match the
# fully-qualified 'releases/notes', the overview row's escape was the bare 'notes/', and this one was
# invisible to both because it is spelled with a BACKSLASH. Same shape every time -- a matcher that
# reads as thorough and cannot see the instance.
#
# IT WAS NOT COSMETIC. Write-Utf8NoBom is a bare File.WriteAllText and creates no directories, so this
# line made releases/notes/<X>.x/ while the write below went to releases/audience/<X>.x/. It worked only
# because releases/audience/4.x/ already existed from earlier cuts in this major. The first cut into a
# FRESH major would have created the wrong directory, thrown DirectoryNotFoundException on the write,
# and died mid-run on main -- after the development notes, the Release body and the releases/README.md
# row, before the version bump and the commit. Found on a filesystem rather than by a gate: git tracks
# no empty directory, so the stray releases/notes/4.x/ this left behind at every cut since the rename
# appeared in no commit, no git status, and in front of nothing.
if ($cutNote) {
    $noteAbs = Join-Path $repoRoot ($noteRelPath -replace '/', '\')
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $noteAbs) | Out-Null
    Write-Utf8NoBom -Path $noteAbs -Content $noteContent
    $sectionCount = if ($audienceEntries.Count -gt 0) { 'audience + organisation sections' } else { "organisation section only -- no entry reached tier $audienceTier" }
    Write-Host "  created: $noteRelPath (draft -- $sectionCount)" -ForegroundColor DarkGray
}

# --- Bump plugin versions (regex on the version line -- preserves the JSON formatting) -----------
foreach ($p in $manifests) {
    $raw = Get-Content -Path $p.ManifestPath -Raw -Encoding UTF8
    $bumped = [regex]::Replace($raw, '("version"\s*:\s*")\d+\.\d+\.\d+(")', "`${1}$new`$2", 1)
    Write-Utf8NoBom -Path $p.ManifestPath -Content $bumped
    Write-Host "  bumped: $($p.Name)/.claude-plugin/plugin.json -> $new" -ForegroundColor DarkGray
}

# The follow-up documents this script deliberately does NOT write, printed once at the end whether or
# not the tag was pushed. Both are hand-written and both need the notes that only exist after this run:
# the consumer DRAFT (generated above -- the tier-2 entries, selected but not yet rewritten for their
# reader) and the internal note (its own script, because a skeleton committed here would sit inside the
# release tag).
#
# GATED ON THE SCRIPT EXISTING rather than on a config knob: whether a repo has an internal tier is a
# fact its file tree already answers, so a repo without that script simply never sees the line. Same
# reasoning as Get-ReleasePluginTier's computed fallback.
#
# WHICH FILE TREE, THOUGH -- that is what inbound #461 caught. The probe looked only in the CONSUMER's
# repo root, where a consumer has no copy, that being the entire point of the mirror. So the reasoning
# above held in the source and inverted everywhere else: the tree answered "no internal tier" for a repo
# that has one, and the line about the one tier written at EVERY release, patch included, was the one
# line a consumer never got. It is also the tier nothing else reminds you about.
#
# So the repo's own copy is tried first and the sibling that travels with THIS script second. The fact
# is still read off a file tree; it is now read off the tree that can answer it -- a repo running this
# script has the note's script beside it, because they are mirrored together.
#
# AND THE PRINTED PATH IS THE RESOLVED ONE (inbound #460's class, one file over): './scripts/release/...'
# is a command in the source repo and a dead path in a consumer. A checklist that prints something
# unrunnable is worse than one that prints something long.
function Write-FollowUpSteps {
    # The body is generated, so it is reported whether or not anything is left to write by hand -- a
    # patch with no hand-written document still gets a Release page, which is the whole point of
    # generating it.
    Write-Host ""
    Write-Host "The GitHub Release body is written for you:" -ForegroundColor Cyan
    Write-Host "  gh release create $tagName --title `"$tagName - <short title>`" --notes-file $bodyRelPath"

    # ONE DOCUMENT, AND NO SECOND SCRIPT TO INVOKE (Dave, August 10, 2026). This block used to name two
    # follow-ups: the consumer draft, and an invocation of new-internal-note.ps1 gated on that script being
    # present in one of two trees -- machinery that existed only because the second document was written by
    # a second tool AFTER the cut. The draft above is both readers' sections in one file, so the follow-up
    # is an edit rather than a command. new-internal-note.ps1 is still shipped and still works for a repo
    # running the two-document flow; nothing here calls it.
    Write-SelfConsumptionReminder

    # THE RECEIPT SHAPE (issue #1884), placed INSIDE this function rather than after its two call
    # sites, so the early-exit path and the full cut are covered by one edit and cannot drift apart.
    # It sits above the hand-written-document block deliberately: that block is a genuine next STEP,
    # and a reminder about the close-out must not read as the last item on a to-do list.
    if (Test-FunctionDefined 'Write-CloseOutReceipt') {
        Write-CloseOutReceipt -Cite "the release notes for $tagName"
    }

    if (-not $cutNote) { return }
    Write-Host ""
    Write-Host "Still to write by hand (commit it straight onto main -- the release-notes exception):" -ForegroundColor Cyan
    Write-Host "  - $noteRelPath"
    if ($audienceEntries.Count -gt 0) {
        Write-Host "      the audience section is a DRAFT (the tier-$audienceTier entries, in the words their authors wrote for a reviewer);"
        Write-Host "      'what it is worth' and 'what was still open' are empty and cannot be generated."
    } else {
        Write-Host "      no entry reached tier $audienceTier, so it carries the organisation's sections only -- both empty."
    }
}

function Write-SelfConsumptionReminder {
    <#
        A repo that ENABLES the plugins it just released is now one version behind itself, and nothing
        else says so.

        THE LOOP HAS A MISSING RETURN EDGE. A cut commits straight to the trunk, so no PR and no CI run
        afterwards; the installed plugin cache keeps whatever version it had, and the only thing that
        notices is the connector session check -- at the START of some later session, as an [ERROR] that
        reads like a fault rather than like the completely ordinary consequence of having just cut.
        Measured on 2026-08-15: this repo sat on v4.9.0 against a v4.11.0 source, six connector rows red,
        after two releases were cut the same day. One consequence was invisible until looked for: a hook
        the release had ADDED could not fire, because the cache predated it.

        Deliberately conditional, and deliberately a REMINDER. It prints only when this repo enables a
        plugin from the marketplace it declares -- a repo that releases a product it does not itself run
        has nothing to refresh, and telling it otherwise would be noise. And it prints rather than acts:
        a plugin update rewrites what every future session in this repo loads, which is not something a
        release script should do to you while your attention is on the tag.

        WHAT IT PRINTS DEPENDS ON THE ADOPTION ROUTE, because one of the two cannot run `plugin update`
        at all (#1445, measured here on 2026-09-05 right after the v4.30.0 cut). `enabledPlugins` is the
        DECLARATIVE route and `plugin update` operates on an INSTALL RECORD, so a repo adopted the
        declarative way has no record -- and this function used to read only the settings key, which made
        the very source it consulted the one that guaranteed the command it printed could not succeed:

            claude plugin update dkj-subagents-alpha@dkj-claude-plugins --scope project
            -> Failed to update plugin "...": Plugin "dkj-subagents-alpha" is not installed

        Both halves were measured rather than reasoned about, because the report that found this flagged
        the second as inferred and the repair differs per answer:
          - declarative only (`enabledPlugins`, no record): `plugin update` REFUSES. The marketplace
            refresh alone is the whole remedy -- the clone advanced to 4.30.0 and the plugins resolve
            from it on the next session. A restart is what applies it.
          - `claude plugin install --scope project`: a record is written, and `plugin update` WORKS
            (`already at the latest version (4.30.0)`).
        And the trap that makes the detection necessary: `plugin install --scope project` writes the SAME
        `enabledPlugins` key into `.claude/settings.json` that the declarative route uses. The two routes
        are therefore indistinguishable from that file, which is why the answer has to come from the
        install administration instead.

        Test-PluginInstalledHere is deliberately the SHARED predicate rather than a fourth private one
        (see check-report-lib.ps1's block above it): it is permissive when the administration is absent or
        unreadable, which is the right default here too -- "I could not look" is not evidence of absence,
        and erring that way can only restore the old line, never suppress a command that would have worked.
        Its one edge, a PATHLESS record, therefore also gets an update line; that state is a broken
        administration rather than an adoption route, and it is check-connectors' shape report to name.
    #>
    $enabled = @()
    $marketplaceName = ''
    $installed = @()
    $declarative = @()
    try {
        $marketplaceName = ((Get-MarketplaceJsonText | ConvertFrom-Json).name)
        if (-not $marketplaceName) { return }
        $settingsPath = Join-Path $repoRoot '.claude\settings.json'
        if (-not (Test-Path -LiteralPath $settingsPath)) { return }
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $props = @($settings.PSObject.Properties | Where-Object { $_.Name -eq 'enabledPlugins' })
        if ($props.Count -eq 0 -or $null -eq $props[0].Value) { return }
        $enabled = @($props[0].Value.PSObject.Properties |
            Where-Object { $_.Value -and $_.Name -like "*@$marketplaceName" } |
            ForEach-Object { $_.Name })
        # MOVED INSIDE THE TRY, where it used to sit just after it: there is nothing to ask the install
        # administration about for an empty set, and every other exit above is a return, so a copy left
        # below this block would be unreachable rather than a second guard.
        if ($enabled.Count -eq 0) { return }

        # Which of those the install administration can actually attest to for THIS repo.
        $record = Get-InstallRecord -RepoRoot $repoRoot
        $installed = @($enabled | Where-Object { Test-PluginInstalledHere -InstallRecord $record -PluginId $_ })
        $declarative = @($enabled | Where-Object { $installed -notcontains $_ })
    } catch {
        # Never let a reminder break a cut that has already committed and tagged.
        return
    }

    Write-Host ""
    Write-Host "This repo runs the plugins it just released, so its own install is now a version behind:" -ForegroundColor Cyan
    Write-Host "  claude plugin marketplace update $marketplaceName"
    foreach ($id in $installed) {
        Write-Host "  claude plugin update $id --scope project"
    }
    if ($declarative.Count -gt 0) {
        # The ids go on their own lines rather than into the sentence: one id read "... are enabled"
        # otherwise, and the line ran past the width every other line here keeps to. No `@`-target in the
        # prose either, deliberately -- it is ABOUT the command rather than an instruction to run it,
        # which is the same discriminator lint check 11 uses to tell those two apart.
        Write-Host "      Enabled declaratively, with no install record for this repo -- these resolve"
        Write-Host "      straight from the marketplace clone, so the refresh above is their whole"
        Write-Host "      remedy and a restart is what applies it. An update command would refuse"
        Write-Host "      them as `"not installed`", which is not a failure to chase:"
        foreach ($id in $declarative) { Write-Host "        $id" }
    }
    Write-Host "      Until then the connector check reports this repo as outdated, and any hook or agent"
    Write-Host "      def this release added is not loaded here yet."
}

# --- Commit + tag directly on main ---------------------------------------------------------
# Native git writes chatter to stderr (the LF->CRLF warning from `git add`, `remote:` on push).
# Under ErrorActionPreference=Stop, PowerShell 5.1 would promote that to a terminating
# NativeCommandError before the $LASTEXITCODE checks -- the pitfall that broke cutting v1.12.0 on
# `git add` (#107). Invoke-NativeCapture (#114) runs each git call under EAP=Continue and hands back
# output + exit code, so we rely purely on $LASTEXITCODE; the captured chatter is echoed so the
# release run stays as verbose as before.
$add = Invoke-NativeCapture -FilePath 'git' -Arguments @('add', '-A')
$add.Output | ForEach-Object { Write-Host $_ }
if ($add.ExitCode -ne 0) { Write-Error "git add failed."; exit 1 }

$commit = Invoke-NativeCapture -FilePath 'git' -Arguments @('commit', '-m', "release: v$new")
$commit.Output | ForEach-Object { Write-Host $_ }
if ($commit.ExitCode -ne 0) { Write-Error "git commit failed."; exit 1 }

$tag = Invoke-NativeCapture -FilePath 'git' -Arguments @('tag', '-a', $tagName, '-m', "Release $tagName")
$tag.Output | ForEach-Object { Write-Host $_ }
if ($tag.ExitCode -ne 0) { Write-Error "git tag failed."; exit 1 }

if ($NoPush) {
    Write-Host ""
    # THE TWO NUMBERS THE WHOLE LABELLING HANGS ON, ON THIS PATH TOO (inbound #802, August 21, 2026). The
    # push path below has always closed with '($current -> $new, $typeLabel)'; this branch exits before it
    # and printed neither. So the flag whose entire purpose is inspecting a release before it is public was
    # the one path that concealed the baseline -- and a wrong baseline is visible in nothing else.
    Write-Host "Release v$new recorded locally on main ($current -> $new, $typeLabel; commit + tag $tagName), not pushed." -ForegroundColor Green
    Write-Host "Push it yourself when ready:" -ForegroundColor Cyan
    Write-Host "  git push origin main; git push origin $tagName"
    Write-FollowUpSteps
    exit 0
}

$pushMain = Invoke-NativeCapture -FilePath 'git' -Arguments @('push', 'origin', 'main')
$pushMain.Output | ForEach-Object { Write-Host $_ }
if ($pushMain.ExitCode -ne 0) { Write-Error "git push of main failed."; exit 1 }

$pushTag = Invoke-NativeCapture -FilePath 'git' -Arguments @('push', 'origin', $tagName)
$pushTag.Output | ForEach-Object { Write-Host $_ }
if ($pushTag.ExitCode -ne 0) { Write-Error "git push of the tag failed."; exit 1 }

Write-Host ""
Write-Host "Done: v$new has been cut ($current -> $new, $typeLabel), committed on main and tagged as $tagName. Recorded." -ForegroundColor Green
Write-FollowUpSteps
