<#
Folds one or more changelog entry files into CHANGELOG.md's flat list of changes, and then clears them.

WHERE THE ENTRY COMES FROM (Dave, August 6, 2026; one file since August 23, 2026). A branch carries its
whole working state in dkj-policy/<branch>.md, and the ENTRY is a section of it: the
fourth phase, '## `<branch>` DEPLOY'. Split-Development is what finds the boundary, so this script
holds no second definition of where an entry begins.

AND EVERY OLDER FORM IS STILL FOLDED, which is not politeness towards history. A branch created before the
merge carries the pair branch/branch-deployment.md + branch/branch-cycle.md; one created before
August 19, 2026 carries branch/branch-changelog.md + branch/branch-progress.md; one created before the
branch/ split carries a <branch-name>.md in the repo ROOT. All of them exist right now, here and in every
consumer, and they receive these scripts through a plugin update rather than by choosing to. Recognise
every one, write one.

AND THEY ARE ALL CLEARED THE SAME WAY: a folded entry's file is DELETED. That was briefly untrue. A root
entry is named after its branch and has never survived its fold, while the branch document then sat at a
fixed path, and rewriting it to an empty state was how the trunk kept a document the next branch could expect to find.
Since August 23, 2026 (Dave) the document is branch-lifetime -- new-branch creates it, this script removes
it, and between branches the trunk carries none. Removing it clears the step list with the entry, because
they are sections of one file. What makes a second fold impossible is simply that there is nothing left to
fold; the branch-NAME test that used to do that job still runs upstream, in Resolve-BranchFilePath, for
branches cut before the change that are still carrying a trunk-declaring copy.

THERE ARE NO SECTIONS ANY MORE (Dave, August 5, 2026). CHANGELOG.md used to carry one
'## Tier N - Pull Requests' section per tier, and the fold's first job was to pick one from a repo-owned
map. The document is a FLAT RANKED LIST now: everything above the first '## ' heading is the intro, and
from there down every '## ' IS a change. So the boundary this script inserts against is derived
STRUCTURALLY instead of read from a configured heading -- which retires Get-ChangelogTierHeadings, the
legacy single-section Get-ChangelogHeading (issue #178) and the '## Pull Requests' fallback in one move.
There is no heading left to name, so there is no heading left to get wrong: the whole class of failure
the old "could not find the heading -- stopping" path existed for cannot occur.

WHERE IN that list is NEWEST FIRST (Dave, August 16, 2026), and since September 3, 2026 that is measured
rather than assumed (issue #1280). CHANGELOG.md is a chronological record and reads as one; the entry being
folded leads when it actually landed last, which is the ordinary case and no longer the only one this
script can express. It used to insert at the TOP for every entry, on the premise that "the entry being
folded is the most recently merged one" -- and a LATE fold is exactly what breaks that premise. This script
is where late folds come from: the commit is a direct push to the trunk, so a push it cannot make holds the
entry while later branches merge and fold ahead of it, and the held entry then led a list it was no longer
the newest member of. The stamp on the heading and the position in the list came from two sources and
nothing compared them. They come from one now -- Get-EntryInsertOffset takes the same $mergeStamp that is
written onto the heading -- so the document cannot contradict itself. Measured in this repo's own
CHANGELOG.md, where '20260903-102422' sat above '20260903-103107'.

IT RANKED ON (TIER, SIGNIFICANCE) UNTIL AUGUST 16, 2026 (issue #467), and the argument for it was that the cut
EMPTIES the pending list, so document order at cut time IS the order the release documents inherit. That
turned out to hold for exactly one section. Build-ReleaseNotes passes -RankByTier for every tier from 1
up, and Build-ReleaseNoteDraft ranks at the repo's own audience tier -- both re-rank from the scores and inherit
nothing. The one place that does inherit is the development notes' TIER 0 section, whose own comment asks
for "complete and chronological, which is what a record is for" and was quietly getting score-descending
order instead. So this made that comment true rather than breaking anything.

INSERT-ONLY, NEVER A RE-SORT, deliberately and unchanged -- #1280 included, which is why it derives a
POSITION and does not sort: this commit lands directly on main, so a bug must be able to misplace at most
the one entry being folded rather than scramble a list it did not write. So an out-of-order pair an earlier
always-top fold already left in the document stays exactly where it is; repairing that is a branch's job,
not this commit's.

The TIER and SIGNIFICANCE are still read here, from the entry's own sections -- they are printed on the
console line and they decide the version bump at the cut. They just no longer decide this position. An
entry with no declaration falls back to the older 'Tier: N' line, which is correct rather than tolerated:
every entry written before this format has no score to rank by.

NOTHING IS CONSUMED ANY MORE, AND THAT IS A REVERSAL RATHER THAN AN OMISSION. While the sections existed,
the HEADING stated the tier, so an entry restating it below was the same fact in two places -- the drift
shape this repo has paid for three times -- and this script therefore stripped both the 'Tier: N' line and
an unscored impact table. With the sections gone there is nothing above the entry stating anything, so the
entry is the only carrier and both now SURVIVE the fold:

  * the impact table is folded in whole, scored or not. '### Who is this for' is a named section of every
    entry, and a section with its answer cut out is worse than a scaffold row: the reader cannot tell
    "nobody was asked" from "somebody deleted it".
  * the legacy 'Tier: N' line is KEPT. Removing it now would leave the folded entry declaring no reach at
    all, so every downstream reader would read it back as tier 0 -- silent, correct-looking, and wrong in
    the one direction that empties a release document.

A missing score is reported and folded anyway: refusing the fold of an already-merged branch is the
silent half-state this repo has measured, and cut-release.ps1 is the refusal point instead. A malformed
table DOES stop the run -- it decides where the entry lands, and getting that wrong is a move on main.

In fold-all mode (no -Branch) only files that are actually changelog entries are folded: an entry opens
with its own heading -- an H3 since the August 26, 2026 shift, an H2 in the flat window before it -- so
repo-root meta docs (CONTRIBUTING.md, SECURITY.md, ...) that open with an H1 are left untouched. -Branch
mode targets exactly the named entry and is unaffected.

What the fold adds is exactly what does not exist until the merge, and since August 19, 2026 it is one
fact per place: the closing line '[PR #NN](url)', and the landing moment stamped on the 'Pull Request'
section's own heading -- the counterpart of the creation stamp the cycle file carries. That closing line
held ' <midDot> merged <date>' as well until that day; the heading holds the moment now -- except in a
pre-dossier entry, which has no such heading, and where the line keeps carrying it rather than losing it.
The ENTRY'S heading is left as its author wrote it --
the fold used to prepend '#NN <midDot> ' to the title as well, and that is gone (Dave, August 5, 2026).
Nothing is lost by it: the number is still in the entry, on that closing line, where the url makes it
clickable rather than merely printed. What the heading gains is being readable as a sentence, and it is the
one line every reader of the changelog and of all three release documents scans.

The number, url and merge timestamp are fetched via one `gh pr list` (on -Branch, or in fold-all mode
derived from the file name) -- which can only happen after opening the PR. If no PR is found (e.g. a manual
merge without a PR), no closing line is added and the heading is untouched either way.

AN ENTRY FILE WRITTEN AT AN OLDER LEVEL IS RE-LEVELLED, NOT PASSED THROUGH. It arrives at the level
CHANGELOG.md's entries carry -- an H3 since August 26, 2026 -- because a heading at any other level is not
an entry boundary to a reader of that list: a shallower one splits the list above it, and a deeper one is
swallowed into the block above and inherits that block's PR link. The case is not hypothetical: a branch
parked before a shift carries exactly such a file and is folded after it. The WHOLE BLOCK moves, so an
entry's own sections stay one level beneath its heading (see Set-EntryHeadingLevel at the loop below);
only the LEVELS change, and the heading's fields (the title, the type, and a date where one was
scaffolded in) are left exactly as written.

THE DATE MOVED HERE FROM THE SCAFFOLD ON AUGUST 5, 2026 (Dave), and that half is unchanged: it is the
FOLD's to write, because new-branch.ps1 runs when the branch is created and could only ever record the
branch's birth date -- wrong by however many days the branch lived, in the one document whose subject is
when things landed. WHERE in the entry it goes changed on August 19, 2026: it stamps the 'Pull Request'
heading rather than closing the block, so the section's heading says when it landed and its last line says
which PR it was.

Nothing here parses that date back out, and neither does anything downstream: release-lib reads the
TYPE off the heading by matching the known branch types rather than by counting fields from the end,
so a heading with or without a trailing date is read the same way. That was a required part of this
change -- the old parse took the second-to-last field, which would have silently made every entry's
type 'Other' the moment the date left.

Usage:
  .\scripts\release\fold-changelog-entry.ps1 -Branch feat/new-plugin
  .\scripts\release\fold-changelog-entry.ps1              # folds all present entry files
  .\scripts\release\fold-changelog-entry.ps1 -RepoRoot C:\path\to\worktree   # explicit root (#101)
  .\scripts\release\fold-changelog-entry.ps1 -Branch feat/x -Push            # fold, commit and push

Run this on main, right after merging a branch.

COMMITTING IS OPT-IN (-Commit, or -Push which implies it). Without either, the fold is left on disk for
you to commit -- the behaviour this script always had. With them it makes the commit itself, naming
CHANGELOG.md and the entry files as the commit's pathspec so nothing else can be swept in: this commit
lands directly on the main branch under one of the two named exceptions to "never commit directly", and
an exception only stays safe while it stays the size it was granted at.

EXIT CODES. 0 folded (or found nothing to fold, which is not an error); 1 refused or failed; 2 refused
by the trunk-freshness pre-pass alone -- the checkout is behind origin/<trunk>, and NOTHING was written;
3 folded and committed, the push was refused, and EVERY entry the commit carries is already upstream with
an identical body -- the fold happened, somebody else made it. Both are non-zero like every other
refusal, so a caller testing `-ne 0` needs no change; each exists for the one caller that can act on it.
2 is for the job re-triggered by the very push that made the checkout stale (fold-on-merge.yml), which
can stand down on it instead of going red -- see the pre-pass itself for why no other refusal may share
it. 3 is for the caller that has just merged the PR this fold belongs to (ship-pr.ps1): nothing is
missing upstream, so the SHIP succeeded and only this checkout's own trunk is left holding a redundant
commit. The two codes must not be confused: after 2 nothing was written, after 3 there is a commit on
the local trunk that its caller has to tell the operator about.
#>

param(
    [string]$Branch,
    # #101: explicit override of the repo root, for a consumer that runs the fold from a
    # temporary/detached worktree (e.g. a ship-pr.ps1 that checks out main elsewhere) and wants to
    # write to that tree instead of whatever CLAUDE_PROJECT_DIR/git-root would resolve to. Default
    # (omitted): unchanged behavior below.
    [string]$RepoRoot,
    # Commit the fold. OFF BY DEFAULT, deliberately: this commit lands directly on the main branch,
    # which is one of the two named exceptions to "never commit directly" -- so it has to be asked for,
    # exactly like teardown.ps1 requires -Apply before it removes anything.
    #
    # The scope limit the exception grants is enforced by git rather than by care: the commit names its
    # paths, so CHANGELOG.md and the entry files this run folded are the only things that can end up in
    # it, whatever else is lying around in the tree or already staged.
    [switch]$Commit,
    # Push the fold commit. Implies -Commit. Separate because a fold commit sitting unpushed on main is
    # its own silent half-state -- the repo looks folded locally and unfolded to everyone else -- and
    # that is precisely the class of half-finished state this repo keeps finding the expensive way.
    [switch]$Push,
    # The escape valve for the duplicate-entry gate below, and for nothing else. It overrules a JUDGEMENT
    # about content -- "the changelog already carries an entry naming this branch" -- rather than skipping
    # a tool, which is the same test the entry scaffold gate's -Force is granted on. No case that needs it
    # has been measured; it exists so a false positive cannot wedge a fold that has to land, since this is
    # the step that writes the record and the branch is usually gone by the time anyone notices.
    [switch]$Force,
    # The escape valve for the trunk-freshness pre-pass, and for nothing else. Deliberately NOT -Force:
    # that flag overrules a JUDGEMENT about content ("the changelog already carries an entry naming this
    # branch"), and its own comment above says it is for the duplicate gate and nothing else. This one
    # skips a MEASUREMENT of the checkout -- the same distinction open-pr.ps1 draws with
    # -SkipLint/-SkipTests and ship-pr.ps1 with -SkipStaleCheck. Folding a duplicate and folding onto a
    # stale trunk are two different mistakes, and one flag that waves through both is a flag nobody can
    # use safely for either.
    [switch]$SkipTrunkCheck
)

$ErrorActionPreference = "Stop"

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Repo root -- dual context: if a consumer runs the shared plugin mirror, CLAUDE_PROJECT_DIR
# supplies its repo root; in the workshop root (or outside a session) it falls back to the git
# root. This way the SAME file works in both locations, and the root copy and the plugin mirror
# stay byte-identical (guarded by the shared-scripts drift lint).
# -RepoRoot (#101), when supplied, wins over both -- see the param comment above. Note: PowerShell
# variable names are case-insensitive, so $RepoRoot (the param) and $repoRoot (used below) are the
# same variable; the guard below only computes the dual-context fallback when it is still empty.
if (-not $repoRoot) {
    $repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (git rev-parse --show-toplevel).Trim() }
}
Set-Location $repoRoot

# Pre-flight (#86): fold relies on scripts\repo-config.ps1 in the consumer's repo root. If that is
# missing -- typically on a clean consumer -- stop with a clear pointer instead of a raw
# dot-source error on the . (dot-source) line below.
$configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Error "fold-changelog cannot run -- missing repo-owned file: $configPath (Get-RepoName / Get-RepoBlobUrl / Get-LintScript). This file is repo-specific and belongs in the consumer's repo root. Create it (the specialists-init bootstrap lays down a VUL-IN scaffold, or take an existing consumer / the source repo as a model) and run again afterward."
    exit 1
}

# Repo name from the repo root's local repo-config (single source), no longer hardcoded.
# Deliberately from $repoRoot and not $PSScriptRoot: from the plugin mirror, $PSScriptRoot points
# to the plugin cache, while repo-config always lives in the consumer's repo root.
. (Join-Path $repoRoot 'scripts\repo-config.ps1')
$repo = Get-RepoName

# Pre-flight (#86): an unfilled scaffold (repo-config still at VUL-IN) would otherwise only fail
# further down with an unclear gh error. Stop here with a clear pointer.
if ($repo -match 'VUL-IN') {
    Write-Error "fold-changelog cannot run -- scripts\repo-config.ps1 still contains VUL-IN placeholders. Fill in Get-RepoName with this repo's value and run again."
    exit 1
}

# The 'Plugins:' detection: Get-TouchedPlugins plus the plugin roots it reads (#103, Victor #3).
# $PSScriptRoot-relative, like the two libs below and for the same reason -- this lib travels in the
# same mirror payload as this script, so it resolves from the workshop root, a consumer's plugin cache
# and the mirror tree alike.
#
# IT USED TO LOOK release-lib.ps1 UP UNDER $repoRoot, guarded, and the comment here justified that by
# saying release-lib "is deliberately NOT mirrored to the plugin". That stopped being true on August 8,
# 2026, when the lib was registered as a mirror pair -- so a consumer running the fold had a perfectly
# good copy sitting beside the script and looked for it in their own scripts\lib\ instead, where it is
# not. The outcome was right by accident and for the wrong reason, which is the shape that survives a
# review.
#
# THE DEPENDENCY IS THE SMALL LIB, NOT release-lib. Get-TouchedPlugins moved down into plugin-tree-lib
# on August 9, 2026 precisely so this dot-source could be the dependency-free one: release-lib pulls
# entry-scaffold-lib in behind it, thousands of lines, and this script runs immediately after a merge
# and directly on the trunk.
#
# What decides the 'Plugins:' line is the marketplace, not the presence of a lib: a repo that declares
# no plugins yields no roots and therefore no line. That is an answer rather than a degradation, so the
# $canDetectPlugins gate is gone along with the reason it existed for.
. (Join-Path $PSScriptRoot '..\lib\plugin-tree-lib.ps1')

# Shared native-capture helper (#114 item 1). $PSScriptRoot-relative, not $repoRoot: like
# check-report-lib.ps1 this lib is not repo-owned -- it travels with the SAME plugin/mirror payload
# as this script (registered in scripts\lib\shared-scripts-lib.ps1), so it resolves from the
# workshop root, a consumer's plugin cache, or the plugin mirror tree alike.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# The entry format: the heading levels this script recognises and normalises to, the impact table it reads
# the reach and the significance from, and the ranked insert offset it places the entry at.
# $PSScriptRoot-relative for the same reason as the lib above -- it travels with this script, so the writer
# (new-branch.ps1), the validator (open-pr.ps1) and this reader always hold the same version of
# the format.
. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')

# Get-SeamValue + Get-DefaultChangelogPath (issue #885, group A): this script used to probe inline for
# every other seam it reads and hard-code the changelog path outright. The changelog is the one seam
# more than one reader (this script and cut-release.ps1; session-status.ps1 was a third until #957) must
# agree on, so it is the one read through the shared definition rather than a fourth private idiom.
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')

# THE CLOSE-OUT RECEIPT SHAPE (issue #1884), printed as this run's last line -- see closeout-lib.ps1
# for why step 6 of the ritual got a mechanism after losing four times in prose. Guarded on
# git-porcelain-lib's grounds: a consumer whose mirror predates this lib must not crash on load, and
# the call site tests for the function rather than assuming the dot-source took.
$foldCloseoutLib = Join-Path $PSScriptRoot '..\lib\closeout-lib.ps1'
if (Test-Path -LiteralPath $foldCloseoutLib -PathType Leaf) { . $foldCloseoutLib }

# BOM-less UTF8 -- Set-Content -Encoding UTF8 always adds a BOM in Windows PowerShell 5.1,
# and the rest of the repo (CHANGELOG.md etc.) has no BOM.
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Test-IsChangelogEntryFile {
    # A changelog entry file (created by new-branch.ps1) always opens with its own heading, an H3
    # ('### <title>') since the August 26, 2026 level shift. Repo-root meta docs (CONTRIBUTING.md,
    # SECURITY.md, a future CODE_OF_CONDUCT.md, ...) open with an H1 ('# ...').
    # Fold-all mode keys off this structural signature so it only ever folds a genuine entry, never
    # whatever other *.md happens to sit in the repo root. Deliberately independent of the branch-
    # prefix table: consumer-extended prefixes (Shopify's style/, liquid/, ...) still fold, since an
    # entry from any prefix is written in this same format. The denylist below stays as a cheap
    # first filter; this is the actual gate.
    #
    # TWO LEVELS ARE ACCEPTED, and the range is built from the lib rather than written out, so this and
    # check-plugin-integrity.ps1 cannot end up recognising different things. An entry file lives only on a
    # branch, so a branch opened in the flat window (August 5-26, 2026) still carries the shape from then:
    # the entry at H2. Refusing to recognise it would silently leave that entry unfolded in the root --
    # the exact half-state this repo keeps rediscovering -- so the range runs DOWN from the current level,
    # not up: '#{entryLevel-1,entryLevel}'. This is the same direction Test-BranchChangelogIsFilled took on
    # August 26 and for the same reason; 'entryLevel+1' (an H4 no entry has ever opened with, per the #953
    # post-mortem further down this file) was the stale reading, issue #1344. The fold PROMOTES a
    # below-level entry to the current level as it lands, whole block at once, via Set-EntryHeadingLevel
    # (see the loop below).
    #
    # The bound is a RANGE, not a hardcoded '{2,3}': '^#{2,3}\s' looks like it also matches an H4 by
    # prefix, but it does not -- '^#{2,3}' consumes at most three '#' and then needs '\s', which fails on
    # the fourth '#', which is why the alternation has to be spelled as a quantifier over the whole run.
    param([Parameter(Mandatory = $true)][string]$Path)
    $entryLevel  = Get-EntryHeadingLevel
    $legacyLevel = $entryLevel - 1
    $rx = '^#{' + $legacyLevel + ',' + $entryLevel + '}\s'
    foreach ($line in [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        return ($line -match $rx)
    }
    return $false
}

# THE ENTRY ARRIVES IN THE WORKFLOW FOLDER, AND THE ROOT FORM IS STILL FOLDED (Dave, August 6, 2026 --
# the folder is 'dkj-policy/' since #1437, September 5, 2026, and carried 'contributing-davekjohn/' and 'workflow-davekjohn/' before that).
# new-branch.ps1 writes the branch's development document; every branch created before the branch/ split -- here and in
# every consumer, who get these scripts through a plugin update rather than by choosing to -- carries a root
# <branch-name>.md instead. Recognising only the new path would leave those entries sitting unfolded in the
# root, which is precisely the silent half-state this repo keeps rediscovering. So both are discovered, in
# both modes: "recognise both, write one".
#
# WHICH NAME THIS TREE ACTUALLY CARRIES. Since August 23, 2026 it is one file; a branch created before that
# carries branch-cycle.md / branch-deployment.md, and one created before August 19, 2026 carries
# branch-progress.md / branch-changelog.md. The fold is the script that meets those branches at their very
# last step. Resolve-BranchFilePath answers per kind and resolves on WHICH FILE DECLARES THIS BRANCH rather
# than on existence -- which it has to, because a branch cut before August 23, 2026 that has merged main is
# carrying the trunk's reset copy of the new file beside the pair holding its real work. So a mixed tree
# folds and clears exactly the files it has, which is the same
# "recognise both, write one" rule the paragraph above states for the root form.
#
# AND SINCE #1255 THE BRANCH IS HANDED IN WHERE THE CALLER NAMED ONE, which matters here more than at any
# other call site: this script runs ON THE TRUNK, after the merge. Left to default to HEAD the resolver
# would look for the TRUNK's document, find none, and fall through to discovery -- which answers correctly
# while exactly one unfolded document is present and picks the alphabetically first of several when the
# folds have been blocked for a while. -Branch makes it exact instead of merely usually right. Empty (a
# fold-all run) it degrades to that discovery on purpose: that mode is asking "what is here", not "where is
# this branch's".
$branchDeploymentRel = Resolve-BranchFilePath -Kind Deployment -RepoRoot $repoRoot -Branch $Branch
$branchCycleRel      = Resolve-BranchFilePath -Kind Cycle -RepoRoot $repoRoot -Branch $Branch
$branchDeploymentPath = Join-Path $repoRoot $branchDeploymentRel
$branchDeploymentFilled = (Test-Path -LiteralPath $branchDeploymentPath) -and
    (Test-BranchChangelogIsFilled -Text ([System.IO.File]::ReadAllText($branchDeploymentPath)))

# WHICH BRANCH THE ENTRY BELONGS TO, read from the development document's own heading.
#
# THE FILENAME IS A WRITE CONVENTION AND A READ CANDIDATE, NEVER THE AUTHORITY -- and that is the reason
# the branch line is in the document rather than only in the scaffolder's head. In fold-all mode the branch
# is what the PR lookup keys on, and the heading is the one place that DECLARES it. Same answer
# Resolve-BranchFilePath gives one level down, and it buys the same thing here: a branch renamed after
# new-branch ran, or a document written by hand under a name that does not match, still folds against the
# right PR.
#
# THIS USED TO BE FRAMED AS THE ONE THING THE FIXED FILENAME COST, and #1335 retired the framing rather
# than the rule. From August 23 to September 3, 2026 the document was the single 'development.md', while
# the branch used to be recovered from the entry's file NAME (feat-x.md -> feat/x). A fixed name carries no
# branch, so the filename would have been read as a branch called 'development', found no PR, and folded
# the entry with neither number nor merge date -- silently, since a missing PR is a legitimate outcome the
# script already prints and moves past. The name carries the branch again now, so there is nothing left
# being paid for and nothing to weigh the heading read against: it stands on the paragraph above on its
# own merits, which is what #1339 kept it for.
#
# WHY THE FILENAME IS NOT TRUSTED FOR THIS, worth a line because the name has moved under the reasoning
# more than once: while the file was 'development-cycle.md' the mis-parse produced 'development/cycle' -- a
# plausible-looking branch name, because the hyphen became the slash. The fixed 'development.md' that
# briefly followed yielded a bare 'development' with no slash, an obviously wrong answer; the per-branch
# '<branch>.md' name since #1335 flattens the branch's own slashes to hyphens, so a mis-parse is
# convincingly wrong again. Reading the branch from the document's heading sidesteps every one of those shapes.
#
# READ BEFORE THE LOOP, WHICH IS ALSO BEFORE THE REMOVAL in it: on main after the merge the
# progress file still names the branch that was just merged, which is exactly the fact needed here.
$branchFileOwner = ''
if ($branchDeploymentFilled) {
    $progressFile = Join-Path $repoRoot $branchCycleRel
    if (Test-Path -LiteralPath $progressFile) {
        $declared = Get-BranchFileDeclaredBranch -Text ([System.IO.File]::ReadAllText($progressFile))
        if ($declared -and $declared -ne (Get-BranchTrunkName)) { $branchFileOwner = $declared }
    }
}

if ($Branch) {
    # Explicit target: the caller named the branch, so trust it. The legacy root file is named after that
    # branch, so it qualifies on EXISTING. The development document qualifies on being FILLED instead --
    # it is named after the branch too since #1335, but Resolve-BranchFilePath has already answered which
    # path this branch's document sits at, and that answer is as often a legacy name as today's
    # '<branch>.md', so the name is not what is being tested here.
    $entryFiles = @()
    if ($branchDeploymentFilled) { $entryFiles += $branchDeploymentRel }
    $legacyName = ($Branch -replace '/', '-') + ".md"
    if (Test-Path -LiteralPath (Join-Path $repoRoot $legacyName)) { $entryFiles += $legacyName }
}
else {
    # Fold-all: never fold a file that is not an actual changelog entry (structural gate above).
    $reserved = @("CHANGELOG.md", "CLAUDE.md", "README.md")
    $entryFiles = @()
    if ($branchDeploymentFilled) { $entryFiles += $branchDeploymentRel }
    # EVERY PER-BRANCH DOCUMENT IN THE FOLDER, not only the one the resolver names (#1255). Until the
    # documents were named per branch this loop could not exist and did not need to: there was ONE shared
    # path, so the resolver's single answer was all there could be. Now the trunk can carry several at once
    # -- which is precisely the state a run of blocked folds leaves behind -- and folding one per invocation
    # would leave the rest sitting unfolded with nothing saying so. That is the silent half-state this
    # script's own header keeps naming, so fold-all sweeps the pattern.
    #
    # THE THREE TESTS ARE THE SAME ONES APPLIED EVERYWHERE ELSE HERE, deliberately, rather than a fourth
    # definition: it must DECLARE a branch, that branch must not be the trunk (a reset document is not an
    # entry), and it must be FILLED. The legacy 'development-cycle.md' matches this pattern too and needs no
    # exception -- if it passes all three it IS an unfolded entry and folding it is right.
    #
    # AND IT MUST NOT BE ONE OF THIS FOLDER'S OWN RESERVED PAGES (#1497, and #1493's own PR before it --
    # the first real fold-all run against this tree since CHANGELOG.md, CONTRIBUTING.md and README.md
    # started sharing this directory with every branch's dossier, #1437).
    #
    # THREE REAL, MEASURED FALSE POSITIVES, NOT A HYPOTHETICAL ONE -- and between them they rule out
    # reaching for a content-based fix instead of a name-based one. CHANGELOG.md's own newest
    # '### DEPLOY: <branch>' heading satisfies Get-BranchFileDeclaredBranch's entry pattern (that function
    # reads it correctly for the document it was built for, a single branch's own dossier -- it was never
    # asked whether a document holding MANY such headings might be handed to it too), so the whole file was
    # read as one unfolded entry and every one of its already-folded 'Score:' pairs came back as the same
    # tier declared twice. dkj-policy/README.md's title -- '# `dkj-policy/` -- the workflow's own folder in
    # this repo' -- carries a backtick-quoted term with a slash in it, which is exactly the shape that
    # function's widest pattern is built to recognise; it matched on the OPENING heading, so
    # -OpeningHeadingOnly (built for an arbitrary-document scan exactly like this one) would not have saved
    # it either. CONTRIBUTING.md is the third and was missed by the report that named the other two: it
    # declares '<branch>.md' off a backtick-quoted path placeholder in an ordinary '###' heading. All three
    # read as FILLED as well. The fold moves a document into the changelog and then DELETES it, so with the
    # changelog OUTSIDE this folder -- the layout every consumer predating #1437 still has -- that
    # succeeds and exits 0.
    #
    # THE LISTING IS Get-PerBranchDocumentRels' AND NOT THIS SCRIPT'S (#1497), which is the part worth
    # reading twice, because the exclusion above is not what was missing. Get-BranchFilePaths.ReservedNames
    # has named these three all along and Get-PerBranchDocumentRels has applied it all along; this loop
    # simply never asked either of them. It was three lines inline here -- a Get-ChildItem over the folder
    # with the Pattern glob -- which is the shape every caller had while that glob was 'development-*.md'
    # and carried its own guard in the prefix. #1335 widened it to '*.md', moved the narrowing out of the
    # glob into ReservedNames, and converted the four callers it knew about; this loop was a fifth nobody
    # counted. So the repair is not a sixth copy of the exclusion but the removal of the last hand-rolled
    # sweep -- it is the failure Get-PerBranchDocumentRels' own docstring predicts by name, and a sixth copy
    # would leave the mechanism that produced it intact.
    #
    # The root scan below keeps its OWN $reserved list rather than borrowing this one, and that is not the
    # same duplication: it sweeps the repo ROOT, where the set that must not be folded is a different one
    # (CLAUDE.md sits there and not in the folder, CONTRIBUTING.md sits in the folder and not there), and
    # it has excluded its own set correctly since it was written.
    $foldAllTrunk = Get-BranchTrunkName
    foreach ($devRel in @(Get-PerBranchDocumentRels -RepoRoot $repoRoot)) {
        if ($entryFiles -contains $devRel) { continue }
        $devText = [System.IO.File]::ReadAllText((Join-Path $repoRoot ($devRel -replace '/', '\')), [System.Text.Encoding]::UTF8)
        $devDeclared = Get-BranchFileDeclaredBranch -Text $devText
        if (-not $devDeclared -or $devDeclared -eq $foldAllTrunk) { continue }
        if (Test-BranchChangelogIsFilled -Text $devText) { $entryFiles += $devRel }    }
    $entryFiles += @(Get-ChildItem -Path $repoRoot -Filter "*.md" -File |
        Where-Object { $reserved -notcontains $_.Name } |
        Where-Object { Test-IsChangelogEntryFile -Path $_.FullName } |
        Select-Object -ExpandProperty Name)
}

if ($entryFiles.Count -eq 0) {
    Write-Host "No entry files found to fold." -ForegroundColor Yellow
    exit 0
}

$changelogRel = Get-SeamValue -Name 'Get-ChangelogPath' -Default (Get-DefaultChangelogPath -RepoRoot $repoRoot)
Assert-WorkflowIsolatedSeamPath -RepoRoot $repoRoot -RelativePath $changelogRel -SeamName 'Get-ChangelogPath'
$changelogPath = Join-Path $repoRoot $changelogRel

# --- The document has to BE a flat list before anything is inserted into it (inbound #561) ---------
#
# THE ASSUMPTION THIS SCRIPT MAKES IS THAT EVERY H2 BELOW THE INTRO IS ONE CHANGE, and until August 10,
# 2026 it made that assumption without ever checking it. cut-release.ps1 makes the same one and has
# refused over it by name since August 5 -- the two came apart in the direction that loses the least
# noise and the most trust. Measured in a consumer on 2026-08-09, one day after they adopted the entry
# convention:
#
#   Folded and removed: dkj-policy/<branch>.md (tier 1, significance 3 -- placed above 2 existing entries)
#   CHANGELOG.md updated.
#
# Exit 0, no warning. Their "2 existing entries" were two SECTION headings ('## Pull Requests',
# '## Releases'), which sit at exactly the level an entry now occupies -- so the insert landed above the
# first of them, outside the section they keep their entries in. The only way to see it is to open the
# file afterwards, which is precisely what nobody does after a green fold.
#
# SO IT REFUSES, AND IT REFUSES HERE: in the pre-pass, before the first entry is written and before any
# entry file is deleted. A fold-all run writes one entry at a time, so finding this on the third
# file would leave the first two folded into the wrong place with their sources already gone.
#
# NO -Force, AND THAT IS DELIBERATE. Every other refusal in this workflow that overrules a judgement about
# content has an escape valve; this one overrules a FACT about the document, and there is no state in which
# writing into the wrong section is what the caller wanted. The cut has no valve for it either.
#
# WHAT IT COSTS, SAID OUT LOUD RATHER THAN GLOSSED. This script runs after a merge, so a refusal leaves an
# unfolded entry on the trunk -- the silent half-state this repo has measured, and the reason a missing
# significance score is warned about here instead of refused. The difference is that a missing score still
# produces a CORRECT write, while this cannot: the choice is between a state the caller is told about in
# full and a wrong write nothing reports. So the message names the file that is still waiting and both ways
# out of it, which is what turns a half-state into a next step.
#
# READ DEFENSIVELY, because this is now the FIRST read of the document rather than the third. An absent or
# empty CHANGELOG.md used to reach the loop below and fail there; '' keeps that unchanged -- the check finds
# nothing in an empty document, which is correct (there is no block to misread), and whatever the loop did
# about a missing file it still does.
$changelogRaw = ''
if (Test-Path -LiteralPath $changelogPath) {
    $changelogRaw = [string](Get-Content -Path $changelogPath -Raw -Encoding UTF8)
}
$preFlat = Get-PreFlatChangelogRefusal -Content $changelogRaw `
    -Consequence 'this entry would be inserted ABOVE the first of them -- outside the section you keep your entries in, which is only visible to somebody who opens the file afterwards'
if ($preFlat) {
    Write-Host "Nothing was folded -- CHANGELOG.md is not the flat list this script writes into:" -ForegroundColor Red
    Write-Host "  $preFlat" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Your entry is untouched: $($entryFiles -join ', '). Either migrate CHANGELOG.md as described above and run this again, or paste the entry under your own section by hand and delete the file." -ForegroundColor Yellow
    exit 1
}

# Does this repo rank its entries at all (issue #467)? Switchable off via Get-EntrySignificanceEnabled --
# see Test-EntrySignificanceActive. Resolved once here rather than per entry.
#
# IT NO LONGER GOVERNS THE ORDERING, only what is said about it, and that is deliberate. The tier decides
# the position first, and with the sections gone that ordering IS what the three headings used to say -- so
# it cannot be optional without the document losing the distinction it was restructured to keep. The score
# is read unconditionally too (an absent one is simply 0, which sorts to the bottom of its tier). What this
# flag still buys is the WARNING below: a repo that has switched ranking off should not be told off for not
# ranking.
$significanceActive = Test-EntrySignificanceActive

# --- Pre-pass: every entry's impact is resolved and checked BEFORE anything is folded --------------
# A fold-all run writes one entry at a time, so a problem found on the third file would leave the first
# two already folded and their source files deleted -- a half-state that has to be unpicked by hand on
# main. The failure this catches is cheap to see up front and impossible to undo afterwards, so it is
# checked here rather than in the loop: an impact table that does not parse.
#
# THE SECOND PRE-PASS FAILURE IS GONE WITH THE SECTIONS. "This repo declares no changelog section for
# tier N" was the other refusal here, and it existed because the tier had to be mapped to a heading that
# might not be there. A flat list has no such mapping, so a tier the repo happens not to use is no longer
# an error state -- it is simply a position in the order.
#
# Nothing else moves to a pre-pass. The gh lookup stays in the loop where it always was: it depends on
# state this pass cannot know (the PR, and a changelog the previous iteration has already rewritten).
$tierByFile = @{}
$tierProblems = @()
foreach ($file in $entryFiles) {
    $filePath = Join-Path $repoRoot $file
    if (-not (Test-Path $filePath)) { continue }
    $raw = Get-Content -Path $filePath -Raw -Encoding UTF8
    # One read answers both halves of the position: the reach (the highest tier a row claims) and the weight
    # at that reach (that row's significance). Resolve-EntryImpact falls back to the older 'Tier: N' line
    # when the entry carries no table, so an entry written before this format still ranks correctly.
    $impact = Resolve-EntryImpact -EntryText $raw
    $tier = [pscustomobject]@{ Tier = $impact.Tier; Declared = $impact.Declared }
    $impactErrors = @(@($impact.Errors) | Where-Object { $_ })
    if ($impactErrors.Count -gt 0) {
        # A tier that cannot be honoured stops the whole run, exactly as a malformed 'Tier:' line did: it
        # decides where in the list the entry goes, and guessing that wrong is a move on main.
        foreach ($problem in $impactErrors) { $tierProblems += "  $file -- $problem" }
        continue
    }
    # The significance score that decides WHERE IN its tier this entry lands (issue #467). Read here with
    # the tier, because the position depends on both.
    #
    # DELIBERATELY NOT A $tierProblems ENTRY, unlike a malformed table. This pass refuses before anything
    # is folded, and that is right for the failure it does catch: it is decidable before the merge, and
    # open-pr.ps1 refuses over it while the branch is still the only thing affected. A missing significance
    # score is different in the one way that matters here -- refusing the FOLD of an already-merged branch
    # produces the silent half-state this repo has measured (an unfolded entry file sitting in the repo root
    # the morning after its merge, with main looking finished). So a missing score is said out loud and the
    # fold proceeds; cut-release.ps1 is the refusal point Dave chose for it, and by then the branch is long
    # gone and the fix is one edit in CHANGELOG.md.
    #
    # READ UNCONDITIONALLY, warned about only where the repo ranks -- see $significanceActive above. The
    # entry sits at its OWN tier's position in the list, so that tier's row is the one that orders it.
    $rankScore = Get-EntryImpactScore -Impact $impact -Tier $tier.Tier
    if ($significanceActive -and $tier.Tier -ge 1 -and $rankScore -le 0) {
        # 'at the bottom of its tier', and stating the position is the point: an unscored entry reads as 0,
        # which is the LOWEST rank rather than the absence of one, so it sinks below everything scored at the
        # same reach. Saying "unranked" alone would leave the author expecting it at the top.
        Write-Host "  ($file declares no significance for tier $($tier.Tier) -- folded at the bottom of tier $($tier.Tier), because an unscored entry reads as 0. The release cut will refuse until it has one.)" -ForegroundColor DarkYellow
    }
    $tierByFile[$file] = [pscustomobject]@{
        Tier      = $tier.Tier
        Declared  = $tier.Declared
        RankScore = $rankScore
    }
}
if ($tierProblems.Count -gt 0) {
    Write-Host "Nothing was folded -- these entries could not be filed:" -ForegroundColor Red
    $tierProblems | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    exit 1
}

# --- Pre-pass: THE TRUNK THE GATE IS ABOUT TO READ IS THE CURRENT ONE (inbound #1405) --------------
#
# WHAT THE DUPLICATE GATE COULD NOT SEE. Get-FoldedEntryForBranch below reads $changelogContent -- the
# WORKING COPY -- and that is the only trunk state it has ever looked at. On one machine that is the
# whole truth. Dave works one repo from more than one device at the same time, deliberately and
# permanently, so here it is a snapshot of whichever trunk this checkout last pulled: the other device
# may have folded this very branch already, and a gate reading a stale file says "no entry yet" with
# complete confidence.
#
# WHY IT REFUSES WHERE new-branch.ps1 WARNS. That script's own comment (inbound #1046) says refusing
# "matches the lane script and stays open as a follow-up", and holds back because it is mirrored into
# every consumer and arrives by plugin UPDATE rather than by choice. The calculation is different here
# and this is the place the follow-up lands: new-branch puts a stale BASE under a branch, which is
# recoverable with an ordinary pull, while this script's next act is a commit DIRECTLY ON THE TRUNK
# under a named exception. Get it wrong and the consumer is left holding a fold commit on main that
# their own safety rules forbid every route out of -- no rebase on a shared branch, no reset --hard,
# and a merge commit on main is not one of the permitted direct-to-trunk subjects, so even a pull
# cannot finish. Measured: a denied rebase, a denied soft reset, an aborted mid-conflict merge left on
# the trunk, and two commands finally hand-typed by Dave.
#
# SO THE SAME ARGUMENT THE DUPLICATE GATE ITSELF MAKES APPLIES, and it is the reason refusing is safe
# rather than merely strict: a fold that does not happen leaves the entry file exactly where it is, on
# a branch whose work is already merged. Nothing is lost by stopping and one pull resumes it, which is
# what makes this the second place in this script where a refusal costs nothing.
#
# IT CANNOT REFUSE ON A QUESTION IT DID NOT ANSWER. Get-TrunkGap returns Measured=$false for a repo with
# no origin/<trunk> ref -- no remote, or a clone that has never fetched -- and that is NOT "behind".
# Every fixture in this repo's own suite is such a repo, so conflating the two would refuse every fold
# in the gate.
if (-not $SkipTrunkCheck) {
    $trunkGap = Get-TrunkGap -RepoRoot $repoRoot -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    if ($trunkGap.Measured -and -not $trunkGap.Fresh) {
        # Git's own reason is printed rather than swallowed -- see Get-TrunkGap's header for why this
        # fetch keeps its stderr where new-branch.ps1's discards it.
        $trunkGap.Output | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
        Write-Host "  (could not reach origin, so the count below is against the $($trunkGap.Ref) you last saw -- the real gap may be larger.)" -ForegroundColor DarkYellow
    }
    if ($trunkGap.Measured -and $trunkGap.Behind -gt 0) {
        $seen = if ($trunkGap.Fresh) { "origin/$($trunkGap.Trunk)" } else { "the origin/$($trunkGap.Trunk) you last saw" }
        Write-Host "Refused: this checkout is $($trunkGap.Behind) behind $seen, so nothing was folded." -ForegroundColor Red
        Write-Host "  The duplicate gate reads CHANGELOG.md from THIS tree, and a stale one cannot show an entry another device has already folded." -ForegroundColor DarkGray
        Write-Host "  Bring the trunk up to date and run the fold again:" -ForegroundColor DarkGray
        Write-Host "    git checkout $($trunkGap.Trunk); git fetch --prune origin; git merge --ff-only origin/$($trunkGap.Trunk)" -ForegroundColor DarkGray
        Write-Host "  Nothing is lost by stopping: the entry is still in the branch document, and the fold is the same one command later. -SkipTrunkCheck folds anyway." -ForegroundColor DarkGray
        # EXIT 2, NOT 1 -- THE ONE REFUSAL IN THIS SCRIPT THAT CARRIES ITS OWN CODE (inbound #1586).
        #
        # It is still non-zero, so nothing that reads this the way ship-pr.ps1 does (`-ne 0`) changes
        # behaviour: a person at a keyboard, and every other caller, sees the same refusal it always was.
        # What the code buys is one caller that can act on it -- a job triggered by EVERY push to the
        # trunk, which is what fold-on-merge.yml is. There, a trunk that moved between the checkout and
        # this pre-pass means the push that moved it has its own run queued behind this one, whose
        # checkout is at-or-after that push; so this run standing down loses nothing, while going red
        # invents a fourth, self-healing meaning for a red `Fold on merge` and weakens the three real
        # ones that file's header teaches a reader to tell apart.
        #
        # WHAT MAKES THAT SAFE IS THE POSITION OF THIS BLOCK, not the caller's optimism: it sits in a
        # PRE-PASS, before a single entry is folded, so a run that ends here has written nothing and
        # there is no half-state for the successor to inherit. Do not move this refusal below the fold
        # loop, and do not give any refusal that CAN follow a partial fold this same code.
        #
        # AND THE CODE IS THE CONTRACT BECAUSE THE PROSE CANNOT BE. This script is mirrored into
        # plugins/dkj-policy/scripts/release/ and reaches consumers by release, while the workflow that
        # reads it reaches them through adopt-ci-floor.ps1's template -- two independent boundaries
        # for one agreement. fold-on-merge.yml already matches two sentences out of these scripts'
        # stdout; a third, spanning both boundaries, is drift waiting to happen.
        exit 2
    }
}

# What this run actually folded -- the source for both the commit message and the committed pathspec.
$folded = @()
# What this run REFUSED to fold -- see the duplicate gate in the loop. Kept so the run can end on a
# non-zero code without stopping the entries around it: in fold-all mode a duplicate is one file's
# problem, and the others still have to land.
$refused = @()

foreach ($file in $entryFiles) {
    $filePath = Join-Path $repoRoot $file
    if (-not (Test-Path $filePath)) {
        Write-Host "Entry file '$file' not found - skipped." -ForegroundColor Yellow
        continue
    }

    $fileContent = (Get-Content -Path $filePath -Raw -Encoding UTF8).TrimEnd()

    # THE ENTRY IS A SECTION OF THE FILE, NOT THE FILE (August 23, 2026). Until the merge this script read a
    # document that was nothing but the entry, so the whole file was the block to fold. The branch's
    # development document holds the branch's plan above its entry, and folding the plan into CHANGELOG.md would publish somebody's
    # ticked checkboxes as a change description.
    #
    # Split-Development owns where the boundary is, so the fold does not carry a second definition of it
    # -- the same reason the entry FORMAT lives in one formatter that this script never reimplements.
    #
    # A LEGACY FILE HAS NO BOUNDARY TO FIND, and the splitter says so rather than guessing:
    # branch-deployment.md IS an entry from its first line, so Found is false and the whole text is what
    # folds. That keeps a branch created before the merge folding exactly as it always did.
    $split = Split-Development -Text $fileContent
    $entryContent = if ($split.Found) { $split.Entry } else { $fileContent }
    $changelogContent = Get-Content -Path $changelogPath -Raw -Encoding UTF8

    $nl = Get-DocumentNewline -Content $changelogContent
    $entryContent = ($entryContent -replace "`r`n", "`n") -replace "`n", $nl

    # THE GUIDANCE COMMENTS ARE STRIPPED HERE, AND THIS IS THE ONLY PLACE THAT DOES IT. Every field in the
    # dossier form carries an HTML comment saying what a good answer looks like -- that is the form, not the
    # author's answer, and it has no business in CHANGELOG.md or in the three release documents built from
    # it. Stripping at the fold is what makes the guidance safe to be generous with: nobody has to remember
    # to delete it, so leaving a block standing is not a defect and the scaffold gate has one less thing to
    # police.
    #
    # WIRED IN LATE, AND THE GAP WAS REAL. Remove-EntryHtmlComments was written for this caller and its own
    # header said "the fold calls this" while nothing did -- so between the guidance shipping and this line,
    # every comment block in an entry would have folded into the changelog verbatim. Found by reading the
    # fold rather than by anything failing, which is how a stripper that is never called stays invisible:
    # the output is well-formed either way, just full of form text.
    #
    # BEFORE the promote and the footer below, so the comment count cannot change what those measure.
    $entryContent = (Remove-EntryHtmlComments -EntryText $entryContent).TrimEnd()

    # THE 'Plugins:' LINE IS THE FOLD'S TO WRITE, so a copy already in the entry is removed here, before
    # the footer below appends the authoritative one (issue #1015). That line is derived from the PR's
    # touched files further down; an author who mirrored the folded-entry shape into the branch
    # document's '#### Pull Request' section left a second one behind, and 22 doubled 'Plugins:' lines
    # reached the changelog -- 8 in a single cut -- before this strip existed. The unconditional append
    # below could not tell a written entry from an already-folded one.
    #
    # SAID OUT LOUD RATHER THAN DONE SILENTLY. The stray line is the author's, the branch-entry gate now
    # refuses it on the branch, and Remove-EntryPluginsLine is one call -- but a branch opened before
    # that gate shipped still arrives here, so the fold names what it dropped and where it came from.
    if ([regex]::IsMatch($entryContent, '(?m)^Plugins:\s')) {
        Write-Host "  ($file carried a 'Plugins:' line -- the fold writes that line itself, so the copy in the entry was dropped. Delete it from the branch document's '#### Pull Request' section.)" -ForegroundColor DarkYellow
        $entryContent = (Remove-EntryPluginsLine -EntryText $entryContent).TrimEnd()
    }

    # THE DOCUMENT'S TAIL IS NORMALISED BEFORE ANYTHING IS MEASURED IN IT: it ends with exactly one blank
    # line, whatever it ended with before. BOTH insertion paths below need that, and only one of them used
    # to ensure it -- the one that runs when nothing is pending, which is the rarer of the two.
    #
    # WHAT IT PREVENTS. Get-EntryInsertOffset returns the slice's LENGTH for the lowest-ranked entry -- the
    # COMMON case, since tier 0 sinks to the bottom of the list -- so the insert lands at the very end of the
    # content. On a document ending in '---' with nothing after it, that produces '---## <title>' on ONE line.
    # That is not a heading any more: '^## ' does not match it, so Split-Changelog does not see the entry, the
    # cut leaves it out of every release document, and the entry FILE has already been deleted by then. The
    # markdown stays well-formed, nothing errors, and one merged change is gone -- the failure shape this repo
    # keeps paying for.
    #
    # FOUND IN A WORKING TREE RATHER THAN IN THE HISTORY, and that is why nothing had caught it. The branch
    # behind PR #486 was handed over with CHANGELOG.md's final newline stripped by an editor, and it was
    # repaired in the pre-commit diff review -- so the commit, the PR and the fold that followed all ran on a
    # well-formed document. Which is exactly why 'git log' holds no trace of the condition and no gate ever
    # met it: the CONDITION is ordinary editing, the LOSS is what this line prevents, and the demonstration
    # that the loss follows from the condition is the regression test, not an incident.
    #
    # Idempotent, so the happy path is byte-identical: a document already ending in '---' plus one blank line
    # comes back unchanged. It also caps the trailing blanks a hand-edit can leave behind, which is the same
    # accumulation Split-Changelog strips from the head.
    #
    # THE TRADEOFF, SO IT IS A CHOICE RATHER THAN AN OVERSIGHT: TrimEnd() takes all trailing whitespace, not
    # only line breaks, so a markdown HARD BREAK (two spaces) on the document's very last line loses those two
    # spaces. Unreachable on a machine-written tail, which always ends in '---', and it can only be a
    # hand-typed intro's closing line -- where a hard break before end-of-file has nothing to break onto.
    $changelogContent = $changelogContent.TrimEnd() + $nl + $nl

    # The pre-pass has already proved the entry's impact is usable, so this is a lookup rather than a
    # decision. NOTHING IS STRIPPED FROM THE ENTRY HERE, and that reverses what this block used to do.
    # While CHANGELOG.md had tier sections, the HEADING above an entry stated its reach, so the entry's own
    # 'Tier: N' line was the same fact twice and an unscored table was a question nobody had put. With the
    # sections gone the entry is the only carrier of both: strip the line and the entry reads back as tier 0,
    # which is how a change silently drops out of the release documents; strip the scaffold row and
    # '### Who is this for' has a heading with its answer cut out, which reads as somebody having deleted it.
    # The header at the top of this file carries the full reasoning.
    $filed = $tierByFile[$file]
    if (-not $filed.Declared) {
        # Worth saying out loud rather than absorbing. Tier 0 is the documented default and the safe
        # one, but an author who simply forgot has produced work that cannot carry a release on its own --
        # and the moment to learn that is now, not when the cut refuses.
        Write-Host "  ($file declares no tier -- filed as tier 0, which no release can be cut from on its own.)" -ForegroundColor DarkYellow
    }

    # THE ENTRY IS BROUGHT TO THE CURRENT LEVEL AS A WHOLE BLOCK, whatever level it was written at -- its
    # own heading AND the sections under it, shifted by one delta. An entry written at any other level is
    # not an entry boundary to any reader of this list (Get-EntryInsertOffset, the release renderers, a
    # human scanning the file), so it would be absorbed into the block above it and inherit that block's
    # PR link.
    #
    # DONE HERE RATHER THAN INSIDE THE PR BLOCK BELOW, which is where it started out. The prepend of
    # '#NN <midDot> ' only runs when gh found a PR, and an entry folded WITHOUT one -- a manual merge, or gh
    # unavailable -- would then have kept its written level silently. Two jobs, two substitutions.
    #
    # IT WAS A FIRST-LINE REGEX UNTIL inbound #953 (August 27, 2026), and it was wrong twice over:
    #
    #   * THE RANGE WAS DERIVED FROM TODAY'S LEVEL -- '#{level,level+1}', which reads as H3-or-H4 now that
    #     the level is 3. H4 is a level no entry has ever opened with, and H2 -- the level every entry
    #     written in the flat window (August 5-26, 2026) carries -- fell outside it. The range had been
    #     correct while the level was 2 and silently stopped being correct when the level moved, which is
    #     the whole argument for measuring a legacy level instead of computing one.
    #   * AND EVEN WHERE IT MATCHED IT MOVED ONE LINE. Its own comment argued for count 1 so a '### '
    #     section inside the body would keep its level -- true while the delta is 0 and nothing needs to
    #     move, and exactly backwards for the case the promotion exists for. A flat-window entry is H2 with
    #     H3 sections; lifting only its heading to H3 puts the heading and its own sections at ONE level,
    #     and Split-EntryBlocks then reads that single entry as four. Widening the range would have turned
    #     a stray-heading defect into a split-entry one.
    #
    # SO IT CALLS THE RE-LEVELLER THAT ALREADY SOLVED THIS. Set-EntryHeadingLevel measures the block's own
    # level and shifts every non-fenced heading by that delta -- the repair the release renderers got on
    # August 5, 2026 for the identical reason, and the reason it moved down into entry-scaffold-lib is that
    # this script could not reach it in release-lib.
    #
    # MEASURED IN djcylow-react: a pending branch-changelog.md written at the flat H2 level folded into a
    # freshly migrated CHANGELOG.md landed as '## `branch` changelog' -- a sibling of '## [Unreleased]'
    # rather than a child of it -- while all seven pre-existing entries sat correctly at H3.
    $entryHashes = '#' * (Get-EntryHeadingLevel)
    # The level the AUTHOR wrote it at, read before the shift, because that -- not string inequality -- is
    # what the message below reports. Inequality would also fire on the re-leveller's newline normalisation.
    $writtenLevel = Get-EntryBlockHeadingLevel -EntryText $entryContent
    # Back to the document's newline: Set-EntryHeadingLevel returns pure LF (it is a pure function over a
    # block) and everything assembled around this one uses $nl, which is CRLF wherever CHANGELOG.md is.
    $promoted = (Set-EntryHeadingLevel -EntryText $entryContent -EntryLevel (Get-EntryHeadingLevel)) -replace "`n", $nl
    if ($writtenLevel -ne 0 -and $writtenLevel -ne (Get-EntryHeadingLevel)) {
        Write-Host "  ($file was written with its entry heading at H$writtenLevel -- the whole block is re-levelled to '$entryHashes ' so it is an entry boundary in the list and its sections stay beneath it.)" -ForegroundColor DarkYellow
    }
    $entryContent = $promoted

    # THE HEADING IS JUST THE TITLE (Dave, August 5, 2026). The fold adds the PR link as the entry's
    # closing line and stamps the merge moment on the 'Pull Request' heading, and touches the ENTRY's
    # heading no further -- it used to also prepend '#NN <midDot> ' to the title, and that prepend is gone.
    #
    # NOTHING IS LOST, WHICH IS WHY IT COULD GO: the number is still in the entry, on the closing
    # '[PR #NN](url)' line, where the url makes it clickable rather than merely
    # printed. What the heading gains is being readable as a sentence -- it is the one line every reader of
    # the changelog and of all three release documents scans, and it now says what changed and nothing else.
    # The two facts the merge owns already had a home together at the end of the block; the number was the
    # last one still stated twice.
    #
    # WHAT HAD TO MOVE WITH IT, because the number was load-bearing in one reader: new-internal-note.ps1
    # recognised an entry in the development notes by counting middot fields in its heading. That was
    # already broken by the flat format -- the type and date had left the heading, so every real entry fell
    # under its threshold and the one heading that still matched was a QUOTED example inside a fenced block,
    # which it turned into the note's only bullet. It now reads the format's own sections instead.
    #
    # The PR number only exists after the merge; we fetch it via the branch -- from -Branch, or in fold-all
    # mode derived from the file name (<prefix>-<rest>.md -> <prefix>/<rest>).
    $midDot = [char]0x00B7
    $branchForPr = $Branch
    if (-not $branchForPr) {
        if ($file -eq $branchDeploymentRel) {
            # From the development document's own heading -- see $branchFileOwner above for why the file name
            # cannot answer this any more.
            $branchForPr = $branchFileOwner
            if (-not $branchForPr) {
                Write-Host "  $($branchCycleRel) names no branch, so there is nothing to look a PR up by. Pass -Branch to get the number and merge date." -ForegroundColor Yellow
            }
        } else {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $branchForPr = $base -replace '^([^-]+)-', '$1/'
        }
    }

    # ONE BRANCH, ONE ENTRY -- the second line of defence for the route inbound #1077 opened, reported
    # separately as #1082 because the step that WRITES the record had nothing to say about writing it
    # twice. Measured in a consumer: two entries, same branch, same text, two PR numbers, both folds
    # reported as a success. Nothing downstream catches it either -- the cut counts a duplicate twice in
    # its tier breakdown and prints it twice in the published note, under two links that both work.
    #
    # WHY REFUSING IS SAFE HERE AND IS NOT SAFE FOR A MISSING SCORE, which this file's header is explicit
    # about ("refusing the fold of an already-merged branch is the silent half-state this repo has
    # measured"). That reasoning turns on what the refusal LEAVES BEHIND: an unscored entry that is not
    # folded leaves merged work with no record at all, while a duplicate that is not folded leaves the
    # record already standing. There is nothing to lose by stopping, which is exactly what makes this the
    # one place a refusal costs nothing.
    #
    # THE BRANCH NAME IS THE KEY AND THE STAMP IS NOT -- Get-FoldedEntryForBranch's own docstring carries
    # why, since that is a fact about the entry FORMAT rather than about this script.
    $alreadyFolded = if ($branchForPr) { Get-FoldedEntryForBranch -ChangelogText $changelogContent -Branch $branchForPr } else { $null }
    if ($alreadyFolded -and -not $Force) {
        $whichOne = if ($alreadyFolded.PrNumber -gt 0) { "PR #$($alreadyFolded.PrNumber)" } else { 'an entry carrying no PR number' }
        Write-Host "Refused: CHANGELOG.md already carries an entry for '$branchForPr' ($whichOne) -- '$file' was NOT folded." -ForegroundColor Red
        Write-Host "  $($alreadyFolded.Heading)" -ForegroundColor DarkGray
        Write-Host "  A second cycle on the same subject gets its own branch, which new-branch names -v2. Pass -Force to fold anyway." -ForegroundColor DarkGray
        $refused += $file
        continue
    }
    # gh can write messages to stderr; Invoke-NativeCapture runs it under EAP=Continue so that
    # cannot become a terminating error before the graceful exit-code handling below (#107).
    # -DiscardStderr (2>$null) keeps stderr out of the captured JSON. 'files' is simply included in
    # --json (Victor #4, #103) -- gh pr list supplies that field just as well as gh pr view, so the
    # second gh call (previously gh pr view --json files) has been dropped: one PR lookup suffices
    # for both the number/url and the touched files.
    # 'mergedAt' joined the field list on August 5, 2026 for the merge date below -- at no cost, since
    # this call already happens and gh returns whatever fields are asked for in one roundtrip.
    #
    # SKIPPED ENTIRELY WITHOUT A BRANCH NAME. 'gh pr list --head ""' is not a no-op -- it drops the head
    # filter and returns the repo's most recent PR, whichever branch that came from -- so an entry whose
    # branch could not be determined would be stamped with a stranger's PR number, url and merge date. A
    # wrong reference in the changelog is worse than none, and none is a state this script already handles.
    # RESET PER ITERATION, DELIBERATELY. This is assigned inside the PR block below and read at the insert,
    # so in fold-all mode an entry whose PR lookup found nothing would otherwise be placed by the PREVIOUS
    # entry's landing moment -- the same leak the $folded record two screens down had to guard $num against,
    # and the same consequence: a wrong fact about one entry, silently, in a commit that lands on the trunk.
    $mergeStamp = ''
    if ($branchForPr) {
        $prList = Invoke-NativeCapture -FilePath 'gh' -Arguments @('pr', 'list', '--head', $branchForPr, '--state', 'all', '--json', 'number,url,files,mergedAt', '--limit', '1', '--repo', $repo) -DiscardStderr
        $ghCode = $prList.ExitCode
        $prJson = $prList.Output
        if ($ghCode -ne 0) { Write-Host "  (gh pr list returned exit code $ghCode -- PR-number enrichment skipped; run gh manually for the reason.)" -ForegroundColor DarkYellow }
        $prs = if ($ghCode -eq 0 -and $prJson) { @($prJson | ConvertFrom-Json) } else { @() }
    } else {
        $prs = @()
    }
    if ($prs.Count -ge 1) {
        $num = $prs[0].number
        # The heading is left exactly as its author wrote it. $entryHashes is still what the promotion above
        # uses, so a pre-format entry file still arrives at the right level.

        # Deriving touched plugins from the PR files (automation-first): a file under a plugin root
        # this repo's marketplace declares becomes a 'Plugins:' line, which the release notes read
        # (Get-EntryPlugins). It fed the per-plugin CHANGELOGs too until those were retired on
        # August 8, 2026 -- the line outlived them. The detection itself lives in the pure
        # Get-TouchedPlugins (plugin-tree-lib.ps1, #103 -- release-lib.ps1 until August 9, 2026, and
        # this script no longer loads that file at all); 'files' already came along with the gh pr
        # list call above, so no separate gh roundtrip is needed.
        #
        # No guard around it any more: a repo that declares no plugins yields no roots and therefore no
        # line, so the empty case answers itself instead of being tested for here.
        $paths = @($prs[0].files | ForEach-Object { $_.path })
        $touched = @(Get-TouchedPlugins -Files $paths -PluginRoots (Get-RepoPluginRoots -RepoRoot $repoRoot))
        if ($touched.Count -gt 0) {
            $entryContent = $entryContent.TrimEnd() + "$nl$nl" + ('Plugins: ' + ($touched -join ', '))
        }

        # THE CLOSING LINE CARRIES THE PR ITSELF; THE HEADING ABOVE IT CARRIES WHEN IT LANDED (Dave,
        # August 5, 2026 for the line, August 19, 2026 for the split). Built by Format-EntryFoldFooter in
        # entry-scaffold-lib.ps1 -- the lib that owns the entry FORMAT, so the one place that writes this
        # line is the one place a test can read it.
        #
        # THE MOMENT IS READ ONCE AND WRITTEN IN EXACTLY ONE OF TWO PLACES. The 'Pull Request' heading
        # takes it -- the counterpart of the creation stamp the cycle file's heading carries -- and the
        # closing line then carries only the link, so one fact stands in one place.
        #
        # UNLESS THE ENTRY HAS NO SUCH HEADING, which is a shape this script explicitly still folds rather
        # than a hypothetical: a pre-dossier entry carried its title AS its heading and has no named
        # sections at all. Set-EntryMergeStamp finds nothing to stamp there and returns the text unchanged,
        # silently -- so without this test the date would simply be missing from an entry that carried one
        # the day before, in the one document whose subject is when things landed. Test-EntryHasSection is
        # the same reader the emptiness gate uses for "absent versus empty", so the two cannot disagree
        # about which shape they are looking at.
        # The fallback is UTC, matching Format-EntryMergeStamp's own rendering (inbound #1542): since
        # #1280 this stamp is Get-EntryInsertOffset's sort key, and a local-time fallback on one machine
        # would sort against UTC stamps written on another.
        $mergeStamp = Format-EntryMergeStamp -MergedAt ([string]$prs[0].mergedAt) `
            -FallbackNow ((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss'))
        $stampFitsTheHeading = Test-EntryHasSection -EntryText $entryContent -Key 'PullRequest'
        $entryContent = $entryContent.TrimEnd() + "$nl$nl" + (Format-EntryFoldFooter `
            -Number $num -Url $prs[0].url `
            -MergedStamp $(if ($stampFitsTheHeading) { '' } else { $mergeStamp }))
        $entryContent = Set-EntryMergeStamp -EntryText $entryContent -Stamp $mergeStamp
    }
    else {
        # No PR: no number, no url -- and no merge date either, deliberately. There is nothing to read a
        # landing date off, and inventing one from the clock would put a fact in the changelog that
        # nothing backs. An entry folded this way simply carries no closing line and no stamp on its
        # 'Pull Request' heading: both facts have the same single source, so they are absent together.
        Write-Host "  No PR found for '$branchForPr' - entry without PR number/url or merge date." -ForegroundColor Yellow
    }

    # WHERE THE LIST BEGINS, derived structurally rather than read from a configured heading. Everything
    # above the FIRST entry heading is the document's intro; from there down is the ranked list. That one
    # regex replaces the seam, the '## Pull Requests' fallback and the "could not find the heading --
    # stopping" refusal that used to sit here: there is no name to look up, so there is nothing to mismatch.
    #
    # It cannot mistake a section heading of the entry FORMAT for the list, because those are one level
    # deeper: '^## ' does not match '### Who is this for' -- after '##' comes '#', not a space.
    $listMatch = ([regex]('(?m)^' + $entryHashes + ' ')).Match($changelogContent)
    if ($listMatch.Success) {
        $listStart = $listMatch.Index
    }
    else {
        # Nothing pending yet: the whole file is intro, so this entry opens the list. The blank line the
        # heading needs is already there -- an intro whose last line has none would get the heading glued to
        # it, which markdown renders as one paragraph and no heading at all. That used to be ensured HERE,
        # for this path only; the tail normalisation above now does it for both, which is the whole point of
        # having moved it.
        $listStart = $changelogContent.Length
    }

    # WHERE IN the list. The fold is the only moment at which CHANGELOG.md's pending list can be ordered,
    # because the cut empties it: whatever order is left here IS the order the development notes' tier 0
    # section inherits, since it reads the list in document order and sorts nothing. That is what makes the
    # ordering reproducible across the fold and the cut.
    #
    # THE SLICE, AND WHY THE OFFSET IS RELATIVE TO IT: Get-EntryInsertOffset only ever returns an entry
    # boundary or the slice's end, so adding $listStart back cannot land mid-entry. The insert itself is
    # unchanged -- '<entry>\n\n---\n\n' is correct before any entry heading and at the list's end alike,
    # because every folded entry is followed by its own separator AND the tail normalisation above has
    # guaranteed the content ends on a line break. Landing at the end is where that guarantee is load-bearing.
    #
    # NEWEST FIRST SINCE AUGUST 16, 2026 (Dave), AND PLACED BY THE STAMP SINCE #1280: CHANGELOG.md is
    # newest-first, and the entry being folded leads only when it actually landed last. Which is what
    # $mergeStamp answers -- the same moment this script has just written onto the entry's own heading, read
    # off the PR's mergedAt. It used to be assumed instead, and this script is where that assumption fails:
    # the fold is a direct push to the trunk, so a push it cannot make holds the entry while later branches
    # merge and fold ahead of it. The stamp and the position now come from one source, so they cannot
    # contradict each other in the document.
    #
    # AN EMPTY STAMP MEANS THE TOP, and that is the no-PR case rather than a gap: with no PR there is
    # nothing to read a landing moment off, this script deliberately writes no stamp on the heading either,
    # and both facts stay absent together.
    #
    # The rank is still PASSED and is still ignored by the callee -- see its parameter block for why the
    # signature kept it -- because $filed.RankScore and .Tier are read here for the console line and by the
    # cut for the version bump.
    $listText = $changelogContent.Substring($listStart)
    $insertPos = $listStart + (Get-EntryInsertOffset -SectionText $listText -Score $filed.RankScore -Tier $filed.Tier -Stamp $mergeStamp)

    $entryBlock = "$entryContent$nl$nl---$nl$nl"
    $changelogContent = $changelogContent.Substring(0, $insertPos) + $entryBlock + $changelogContent.Substring($insertPos)

    # WHERE IT LANDED, READ NOW -- BEFORE the tally rewrite below (issue #1564). Set-ChangelogPendingSummary
    # rebuilds the whole document from its lines and returns a NEW string, so every offset taken against the
    # current $changelogContent -- $insertPos, $listStart, $entryBlock.Length -- is stale from that line on.
    # It only threw on the first fold after a cut: the empty-list sentence is the longest tally this repo
    # writes, so replacing it with a counted one SHORTENS the document, while $insertPos sits at the old end
    # because there was no entry to insert above -- and $insertPos + $entryBlock.Length then points past the
    # new length. Reading the counts here fixes both Substring calls at once: they are position facts about
    # the list, and the tally line is not an entry heading, so taking them before the rewrite changes neither.
    #
    # BOTH SIDES OF THE POSITION SINCE #1280, and the second half is what the first half could not say. Only
    # "above N" was printed while every entry landed at the top, where the count below is always 0 by
    # construction. A stamp-placed entry can land mid-list, and there "above 46 entries" reads exactly like
    # the old always-top line -- so the number that tells a reader a LATE fold happened is the one that was
    # missing. Printed only when it is not zero, so the ordinary fold's line is unchanged.
    $entryRx = [regex]('(?m)^' + $entryHashes + ' ')
    $tailFromEntry = $changelogContent.Substring($insertPos + $entryBlock.Length)
    $aheadOf = @($entryRx.Matches($tailFromEntry)).Count
    $behind = @($entryRx.Matches($changelogContent.Substring($listStart, $insertPos - $listStart))).Count
    $placedNote = "placed above $aheadOf existing $(if ($aheadOf -eq 1) { 'entry' } else { 'entries' })"
    if ($behind -gt 0) {
        $placedNote += " and below $behind that landed later -- a LATE fold, placed by its own stamp rather than at the top"
    }

    # THE PENDING TALLY, RE-DERIVED FROM THE LIST THIS RUN JUST CHANGED (issue #1515). It answers how much
    # is waiting for the next release and how much of it reaches this repo's audience -- both from the
    # entries themselves, so there is no counter here to increment and nothing that can drift. Placed
    # AFTER the insert deliberately: it must count the entry this iteration just added, and this loop
    # folds one entry per pass, so each pass leaves the line correct rather than only the last one.
    $changelogContent = Set-ChangelogPendingSummary -Content $changelogContent

    Write-Utf8NoBom -Path $changelogPath -Content $changelogContent

    # DISPOSAL IS THE SAME FOR EVERY ENTRY AGAIN (Dave, August 23, 2026): a folded entry's file is deleted.
    # It was briefly asymmetric. A legacy ROOT entry is named after its branch, so once folded it has no
    # reason to exist -- while the branch document then sat at a fixed path, and rewriting it to an empty state was
    # how the trunk kept a file the next `git checkout -b` could expect to find. The document is
    # branch-lifetime now: new-branch creates it, this line removes it, and the trunk carries no copy at all.
    # So there is nothing for the next branch to inherit and nothing for a reader to mistake for work.
    #
    # WHAT STOPS A SECOND FOLD, since a reader arriving here wants to know. Until this change it was the
    # branch NAME in the rewritten file -- the reset declared the trunk, and Test-BranchChangelogIsFilled
    # read that as unfilled -- and before the merge it was the heading LEVEL. It is neither now: the file is
    # gone, so a second run finds nothing to fold. The name test still earns its place upstream in
    # Resolve-BranchFilePath, for branches cut before this change that are carrying a trunk-declaring copy.
    Remove-Item -Path $filePath -Force
    # WHERE it landed, not just that it landed: with the sections gone there is no heading name to report, so
    # $placedNote (built above, before the tally rewrite strands its offsets) carries the position in the
    # list instead -- which is what makes a misplacement visible without opening the file.
    $rankNote = if ($filed.RankScore -gt 0) { ", significance $($filed.RankScore)" } else { ', unranked' }
    Write-Host "Folded and removed: $file (tier $($filed.Tier)$rankNote -- $placedNote)" -ForegroundColor Green
    # Captured per iteration rather than read back afterwards. $num in particular survives from one loop
    # pass to the next, so an entry whose PR lookup found nothing would otherwise inherit the previous
    # entry's number -- into a commit message, where a wrong PR reference is worse than none.
    $folded += [pscustomobject]@{
        File   = $file
        # The file name as the fallback, so a fold whose branch could not be determined still produces a
        # commit subject that names something. Without it the message would read 'fold:  changelog' --
        # a commit on main that says nothing about what it folded.
        Branch = $(if ($branchForPr) { $branchForPr } else { $file })
        Pr     = $(if ($prs.Count -ge 1) { $prs[0].number } else { $null })
    }
}

# Only when something actually landed: after a run whose every entry was refused as a duplicate, this
# line was the loudest true-sounding thing on screen and said the opposite of what happened.
if ($folded.Count -gt 0) { Write-Host "CHANGELOG.md updated." -ForegroundColor Green }

# THE STEP LIST GOES WITH THE ENTRY, and since August 23, 2026 that needs no write at all. The two were
# separate files: the entry was cleared in the loop above and the step list here, keyed on the entry
# actually having been folded so that a fold-all run finding only legacy root entries left it alone. One
# document means the loop above already removed both halves -- they are sections of the same file.
#
# WHAT STAYS IS THE LEGACY CASE, and it is the reason this block did not simply disappear. A branch created
# before the merge has its step list in branch-cycle.md, a DIFFERENT file from the entry that was just
# folded, and leaving a merged branch's ticked-off steps on the trunk would greet the next branch with
# somebody else's work. It used to be rewritten to today's empty document; it is DELETED now, for the same
# reason the entry is -- the trunk carries no branch document between branches, and a legacy path is the
# last place that should be the exception.
$removedPaths = @()
if ((@($folded | ForEach-Object { $_.File }) -contains $branchDeploymentRel) -and
    ($branchCycleRel -ne $branchDeploymentRel)) {
    $progressPath = Join-Path $repoRoot $branchCycleRel
    if (Test-Path -LiteralPath $progressPath) {
        Remove-Item -Path $progressPath -Force
        $removedPaths += $branchCycleRel
        Write-Host "Removed: $($branchCycleRel)" -ForegroundColor Green
    }
}

# THE RE-READ NOTE IS NOT PRINTED HERE ANY MORE (August 23, 2026), and dropping it is the point rather than
# an oversight. Inbound #817 measured that this script's out-of-band WRITE cost a session its tracked view
# of the branch document, so both writers said so where they printed the path. This script no longer writes
# that document -- it removes it -- and "re-read this before your next write" is advice about a file that is
# gone. new-branch.ps1 still prints it, which is the moment it is true: the file exists again there.

# --- The fold commit ------------------------------------------------------------------------------
# WHY THIS IS IN THE SCRIPT AT ALL. The fold has always ended with a hand-typed commit, and on
# August 2, 2026 that happened four times in one session -- the exact "noticed once, automated the
# second time" trigger this house works by. It is also the step where a mistake is least visible: the
# fold itself is verified by the lint gate, while the commit around it is typed from memory each time.
#
# THE SCOPE IS ENFORCED BY GIT, NOT BY CARE. 'git commit -- <paths>' commits exactly those paths and
# ignores the index, so whatever else is modified or already staged cannot ride along. That matters
# more here than anywhere else in this repo: this commit goes straight to the main branch under a named
# exception to "never commit directly", and an exception is only safe while it stays the size it was
# granted at.
if ($Push) { $Commit = $true }
if ($Commit) {
    if ($folded.Count -eq 0) {
        Write-Host "Nothing was folded, so there is nothing to commit." -ForegroundColor Yellow
        # Non-zero when the reason nothing was folded is a REFUSAL: ship-pr reads this code, and a
        # duplicate that ends the run on 0 is the silent success this gate exists to stop.
        if ($refused.Count -gt 0) { exit 1 }
        exit 0
    }
    $subjects = @($folded | ForEach-Object {
        if ($_.Pr) { "$($_.Branch) (#$($_.Pr))" } else { $_.Branch }
    })
    # 'fold:' IS THE TYPE, NOT 'chore:' (Dave, August 10, 2026). Folding is a named act with its own
    # script, its own exception to "never commit directly on main" and its own place in the cycle;
    # 'chore' said only "housekeeping" and left the reader to parse the rest of the line to find out
    # which housekeeping. It is also the second half of a shape this repo already chose: 'merge:' was
    # invented on August 7 for exactly the same reason -- a commit that belongs to no branch still
    # deserves a type -- and merge + fold are one movement written as two commits, so they now read as
    # one pair. With 'chore/' refused as a branch prefix since August 7, this was the last thing in the
    # repo still producing a 'chore:' subject.
    #
    # NOTHING TO RECOGNISE ON THE WAY OUT, checked rather than assumed: no script, gate or hook parses
    # this subject -- only this line writes it and one assert in fold-changelog.tests.ps1 reads it back.
    # ('^chore(/|$)' in branch-info.ps1 matches a BRANCH NAME and is untouched.) So the usual "recognise
    # both, write one" rule has nothing to attach to here; every 'chore: fold ...' already in this repo's
    # history and in every consumer's stays exactly as valid as it was, because nobody was reading it.
    # 'fold:' still reads as a conventional-commits subject to anything keying on the SHAPE '^[a-z]+:'
    # rather than on a list of types, which is the general case. This used to cite the default workflow's
    # discovery script as the witness for that; issue #886 removed that plugin, so the shape rule is
    # stated as what it always was rather than as a fact about a script that no longer exists.
    #
    # THE PR NUMBER STAYS (Dave's call, weighed against the shorter form): it is the only link from this
    # commit back to the PR it folded, and it is what makes the subject line up field for field with the
    # 'merge: <branch> (#NN)' one commit below it.
    # The singular form is composed from Branch and Pr rather than from $subjects, because the number
    # belongs at the END of the line -- '<branch> (#NN) changelog' would bury it mid-sentence. The plural
    # form does use $subjects: there the number has to travel with each branch it belongs to.
    $message = if ($folded.Count -eq 1) {
        $prSuffix = if ($folded[0].Pr) { " (#$($folded[0].Pr))" } else { '' }
        "fold: $($folded[0].Branch) changelog$prSuffix"
    } else {
        "fold: $($folded.Count) changelogs: " + ($subjects -join ', ')
    }
    # CHANGELOG.md plus the entry files -- named, and nothing else. The entry files are gone from disk
    # by now; naming a deleted path is how git is told to record the deletion.
    #
    # ONLY THE ONES GIT ALREADY KNOWS. In the normal flow the entry file was committed on the branch and
    # came to main with the merge, so it is tracked and its deletion belongs in this commit. But an entry
    # written and folded without ever being committed is untracked, and naming an untracked path makes
    # 'git commit' fail on the pathspec -- after the fold has already deleted the file, which is the
    # worst possible moment for an avoidable error. Read from the index rather than from disk, because by
    # now the file is gone from disk and still in the index, which is exactly the state that needs
    # recording.
    # THE LEGACY STEP LIST RIDES ALONG, because this run removed it. It is not an entry and was not folded,
    # but leaving it out would produce a commit that clears half the pair -- the entry gone from main and the
    # step list still showing the merged branch's ticked boxes. Named explicitly rather than swept up, so the
    # enforced scope stays exactly as small as it was: CHANGELOG.md, the entries, and the one file the fold
    # itself removed beside them.
    $entryPaths = @($folded | ForEach-Object { $_.File })
    $writtenPaths = @($entryPaths) + @($removedPaths | Where-Object { $entryPaths -notcontains $_ })
    $lsFiles = Invoke-NativeCapture -FilePath 'git' -Arguments (@('ls-files', '--') + $writtenPaths)
    # git reports its own paths with forward slashes; the entry names are plain file names in the repo
    # root, so normalising both sides costs nothing and removes the one way this could silently drop a
    # deletion from the commit.
    $tracked = @($lsFiles.Output | Where-Object { $_ } | ForEach-Object { ($_ -replace '/', '\').Trim() })
    $paths = @($changelogRel) + @($writtenPaths | Where-Object { $tracked -contains ($_ -replace '/', '\') })
    $untracked = @($writtenPaths | Where-Object { $tracked -notcontains ($_ -replace '/', '\') })
    if ($untracked.Count -gt 0) {
        # Every disposal is a deletion again, so this can name it. The hedge here dated from the split, when
        # an untracked path might have been reset rather than removed, and naming the wrong one sent the
        # reader looking for a file that was still on disk.
        Write-Host "  (not in the commit, because git never tracked them: $($untracked -join ', ') -- the fold deleted them from disk all the same.)" -ForegroundColor DarkYellow
    }
    $commitRun = Invoke-NativeCapture -FilePath 'git' -Arguments (@('commit', '-m', $message, '--') + $paths)
    if ($commitRun.ExitCode -ne 0) {
        Write-Host ($commitRun.Output -join "`n") -ForegroundColor Red
        Write-Host "The fold is on disk but NOT committed (git commit exited $($commitRun.ExitCode)). Commit it by hand; do not re-run the fold, it has already removed the entry files." -ForegroundColor Red
        exit 1
    }
    Write-Host "Committed: $message" -ForegroundColor Green

    if ($Push) {
        # BOUNDED (inbound #1179). The state this flag exists to avoid -- committed on main and not
        # pushed -- is exactly what a hang produces, except a hang does not REPORT it: it reads as a
        # push still in progress, and the fold commit sits on the trunk unnoticed. The lib's
        # non-interactive environment closes the measured credential-prompt cause; the bound makes any
        # other stall land in the branch below, which already says the right thing.
        $pushRun = Invoke-NativeCapture -FilePath 'git' -Arguments @('push') `
                                        -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
        if ($pushRun.ExitCode -ne 0) {
            Write-Host ($pushRun.Output -join "`n") -ForegroundColor Red
            $why = if ($pushRun.TimedOut) { "git push did not answer within $NativeCaptureNetworkTimeoutSeconds seconds; see the [timeout] lines above" } else { "git push exited $($pushRun.ExitCode)" }

            # --- WHY THE PUSH WAS REFUSED, ESTABLISHED HERE INSTEAD OF BY HAND (inbound #1405) ---------
            #
            # WHAT THIS STEP USED TO SAY, AND WHY IT WAS NOT ENOUGH. 'git push exited 1' plus git's own
            # "the remote contains work that you do not have locally" is the SAME sentence a plain
            # divergence gives -- and at this exact moment the two situations need OPPOSITE actions. If
            # the remote merely moved, the fold commit is real work that has to be integrated and pushed.
            # If the other device already folded THIS branch, the fold commit is a duplicate, and pushing
            # it by hand -- which is precisely what this block used to advise -- produces the
            # two-entries-one-branch state inbound #1082 was filed and closed for.
            #
            # IT IS A RACE, NOT A STALE CHECKOUT, WHICH IS WHY THE PRE-PASS ABOVE CANNOT COVER IT. The
            # measured sequence had a trunk that was CURRENT when the fold started -- checkout, pull
            # --ff-only, gate read, all correct -- and the other device folded the same branch inside the
            # window between that read and this push. No check at the top of the run can close a window
            # that opens after it. This is the only place standing on the far side of it.
            #
            # EVERYTHING NEEDED TO TELL THE TWO APART IS ALREADY IN HAND. Separating them took five
            # commands typed by a person: a fetch, a log of HEAD..origin/main, a grep of the remote
            # changelog for the entry heading, a count to prove it appeared once, and a diff of the two
            # entry bodies to prove nothing was lost. All five are derivable right here, from the branch
            # names this run just folded and a changelog the remote already has. So they are.
            #
            # THE BODIES ARE COMPARED, NOT THE BLOCKS. Both devices stamp the heading at THEIR fold time
            # and the two stamps cannot match, so a whole-block comparison would report every genuine
            # duplicate as a difference -- the one answer that would send the operator the wrong way.
            #
            # IT DIAGNOSES AND STOPS, REPAIRING NOTHING, DELIBERATELY. The fold commit is on the trunk by
            # now, and every route off a trunk -- a reset, a rebase, a merge commit -- is a history
            # operation the consumer's own safety rules reserve to the operator. Being exact about the
            # state is the whole job here; deciding what to do about it is not this script's call.
            $redundant = @()
            $gap = $null
            if (-not $pushRun.TimedOut) {
                $gap = Get-TrunkGap -RepoRoot $repoRoot -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
                if (-not $gap.Measured) {
                    Write-Host "  (origin/$($gap.Trunk) could not be measured, so why the push was refused is not established here.)" -ForegroundColor DarkYellow
                } elseif ($gap.Behind -le 0) {
                    Write-Host "  $($gap.Ref) holds nothing this checkout is missing, so a stale trunk is NOT the reason -- git's own words above are the diagnosis." -ForegroundColor DarkYellow
                } else {
                    $plural = if ($gap.Behind -eq 1) { 'commit' } else { 'commits' }
                    Write-Host "  $($gap.Ref) moved $($gap.Behind) $plural while this fold was running:" -ForegroundColor Yellow
                    $moved = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'log', '--oneline', "HEAD..$($gap.Ref)") -DiscardStderr
                    if ($moved.ExitCode -eq 0) {
                        $moved.Output | Where-Object { $_ -and "$_".Trim() } | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
                    }
                    # Read straight out of the fetched ref: no checkout, and nothing in the working tree
                    # is touched to answer this. git addresses its own paths with forward slashes on every
                    # platform, so the repo-relative path is normalised rather than passed as written.
                    $clSpec = ($changelogRel -replace '\\', '/')
                    $remoteShow = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'show', "$($gap.Ref):$clSpec") -DiscardStderr
                    $localShow  = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'show', "HEAD:$clSpec") -DiscardStderr
                    if ($remoteShow.ExitCode -ne 0) {
                        Write-Host "  (could not read $clSpec from $($gap.Ref), so the entries could not be compared.)" -ForegroundColor DarkYellow
                    } else {
                        $remoteText = ($remoteShow.Output -join "`n")
                        $localText  = if ($localShow.ExitCode -eq 0) { ($localShow.Output -join "`n") } else { '' }
                        # An entry block minus its heading line -- see THE BODIES ARE COMPARED above.
                        $bodyOf = {
                            param([string]$block)
                            $ls = @(($block -replace "`r`n", "`n") -split "`n")
                            if ($ls.Count -le 1) { return '' }
                            return (($ls[1..($ls.Count - 1)] -join "`n").Trim())
                        }
                        foreach ($rec in $folded) {
                            # Branch falls back to the FILE NAME when it could not be determined, and a file
                            # name matches no heading -- so such a record reports "not upstream" and keeps
                            # this run out of the redundant verdict, which is the safe direction.
                            $b = $rec.Branch
                            if (-not $b) { continue }
                            $there = @(Get-EntryBlocksForBranch -ChangelogText $remoteText -Branch $b)
                            if ($there.Count -eq 0) {
                                Write-Host "  '$b' has NO entry on $($gap.Ref) -- this fold is real work rather than a duplicate." -ForegroundColor Yellow
                                continue
                            }
                            $here = @(Get-EntryBlocksForBranch -ChangelogText $localText -Branch $b)
                            $same = $false
                            if ($here.Count -ge 1) { $same = ((& $bodyOf $here[0]) -eq (& $bodyOf $there[0])) }
                            $times = if ($there.Count -eq 1) { 'once' } else { "$($there.Count) TIMES" }
                            $bodyNote = if ($same) { 'and its body is identical to the one this run just wrote' } else { 'and its body DIFFERS from the one this run just wrote -- compare them before discarding anything' }
                            Write-Host "  '$b' is ALREADY folded on $($gap.Ref): present $times, $bodyNote." -ForegroundColor Yellow
                            if ($same) { $redundant += $b }
                        }
                    }
                }
            }

            # ALL OF THEM, OR THE ADVICE DOES NOT CHANGE. In fold-all mode one entry may be upstream while
            # another is genuinely new, and that commit still carries work: only a run whose every folded
            # entry is already upstream is safe to call redundant.
            $named = @($folded | Where-Object { $_.Branch })
            if ($named.Count -gt 0 -and $redundant.Count -eq $named.Count) {
                Write-Host "Committed locally but NOT pushed ($why). Do NOT push this commit by hand: every entry it carries is already on $($gap.Ref), so pushing it would fold the same branch twice." -ForegroundColor Red
                Write-Host "  The local fold commit is redundant -- nothing in it is missing upstream, and discarding it loses no work." -ForegroundColor DarkGray
                Write-Host "  What to do with a commit already sitting on the trunk is yours to decide: this script does not rewrite trunk history." -ForegroundColor DarkGray
                # EXIT 3, NOT 1 -- THE SECOND REFUSAL IN THIS SCRIPT THAT CARRIES ITS OWN CODE (issue #1792).
                #
                # WHAT IT SAYS THAT 1 CANNOT. Every line above has just established that the fold HAPPENED:
                # the entry is on the trunk, present once, with a body identical to the one this run wrote.
                # That is not a failure, and the one caller standing on the far side of it -- ship-pr.ps1,
                # which merged the PR seconds earlier -- has no other way to tell it apart from the fold
                # having refused or crashed. Reading 1 there, it reports a hard failure over a ship that
                # succeeded in every externally visible way, and ends with the operator holding a trunk they
                # may not realign with the obvious command (CLAUDE.md reserves reset --hard and a rebase on a
                # shared branch to a person). Measured shipping PR #1789 on 2026-09-10, where fold-on-merge.yml
                # folded first and this script lost the push by seconds.
                #
                # IT IS NOT THE PRE-PASS'S 2 AND MUST NEVER BE MERGED WITH IT. After 2 nothing was written and
                # there is nothing to clean up; here a commit is sitting on the local trunk. A caller that
                # treated them as one code would either invent a leftover after 2 or stay silent about a real
                # one after 3 -- and this script deliberately does not clean it up itself, so silence is the
                # one outcome that leaves the operator worse off than the old hard failure did.
                #
                # AND IT IS THE NARROWEST ARM, BY THE SAME TEST THAT WROTE IT. Only a run whose EVERY named
                # entry is already upstream with a matching body reaches this line; the else below -- a
                # genuine divergence, or a fold-all where one entry is new -- keeps 1, because that commit
                # carries work and its author has to push it.
                exit 3
            } else {
                Write-Host "Committed locally but NOT pushed ($why) -- the state this flag exists to avoid. Push by hand." -ForegroundColor Red
            }
            exit 1
        }
        Write-Host "Pushed." -ForegroundColor Green
    }
}

# A REFUSED ENTRY ENDS THE RUN NON-ZERO, and it is reported HERE rather than at the moment of refusal
# because in fold-all mode a duplicate is one file's problem: the entries around it still have to land.
# ship-pr reads this code, which is what carries the gate into the cycle instead of leaving it on screen.
if ($refused.Count -gt 0) {
    $what = if ($refused.Count -eq 1) { 'entry was' } else { 'entries were' }
    Write-Host "$($refused.Count) $what refused as a duplicate and NOT folded: $($refused -join ', ')" -ForegroundColor Red
    # BOTH ARMS CARRY THE RECEIPT (issue #1884), and this is the arm that needs it more: a refusal is
    # close-out shape C -- a blocker, already parked -- which is the shape most often written as prose
    # because the session has something to explain. The explanation belongs in the issue it files.
    if (Test-FunctionDefined 'Write-CloseOutReceipt') {
        Write-CloseOutReceipt -Cite 'the refused entry, by name above'
    }
    exit 1
}

# THE SUCCESS ARM'S LAST LINE. A standalone fold is a chain ending in its own right.
#
# AND ship-pr.ps1 DOES INVOKE THIS SCRIPT -- as a child process, `& powershell -File
# fold-changelog-entry.ps1`. This comment claimed the opposite when it was written, on a grep that had
# been truncated by `head`, and the code review on this branch caught what that cost: an ordinary ship
# printed the receipt three times, twice of them mid-chain. The double-print is prevented by the
# conductor declaring the chain (Push-CloseOutSuppression in ship-pr), which this run inherits through
# the environment -- not by the two never meeting, which they always did.
if (Test-FunctionDefined 'Write-CloseOutReceipt') {
    Write-CloseOutReceipt -Cite 'CHANGELOG.md'
}
