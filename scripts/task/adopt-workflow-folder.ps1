<#
.SYNOPSIS
    Scaffolds the workflow's own root folder -- dkj-policy/ -- in a consuming repo: the folder
    docs, the releases root the audience notes land in, and the branch dossier in its reset state.

.DESCRIPTION
    EVERYTHING PORTABLE ABOUT THE WORKFLOW GATHERS IN ONE FOLDER (Dave, August 14, 2026). A consumer
    used to receive the workflow's belongings scattered through their root -- a branch dossier from the first
    new-branch run, a releases/ tree from the first cut, a CONTRIBUTING.md if they wrote one -- while
    the conventions those files answer to travel with the plugin. This command puts the folder down in
    one move:

        dkj-policy/
          releases/README.md     this repo's answers to RELEASES-portable.md (the release LIST is a
                                 second file beside it, not this one; see the closing advice)
          CHANGELOG.md           this folder's own pending-changes list, isolated from any changelog
                                 the repo already keeps at its root
          (releases/audience/ is NOT placed -- the first cut creates it when it writes the note there)
          (<branch>.md is NOT placed -- one per branch, living only while that branch is open)
          (README.md and CONTRIBUTING.md are NOT placed ANY MORE -- #2171, September 20, 2026; the
           block further down that reports an existing copy carries the whole reasoning)

    AND IT ANSWERS ONE SEAM, FOR A FRESH ADOPTION ONLY (issue #1150). Get-ReleaseNoteRoot's shared
    fallback is 'releases/notes' at the repo root, and it deliberately does not move -- a repo that
    answers nothing must keep meaning what it meant yesterday. That argument is about a consumer who
    ALREADY has notes on disk, and it does not reach a repo this command scaffolded a minute ago: there
    the scaffolded docs named one destination while the cut wrote to another, so one clean adoption plus
    one clean release left the note outside the folder the adoption had just built. So where -- and ONLY
    where -- this repo defines no answer AND has no note of its own at that fallback, the run writes the
    answer into scripts/repo-config.ps1 rather than printing it as an instruction. Any repo with notes
    already at the fallback keeps them and is told what to do instead; nothing is ever moved.

    AND THREE FILES OUTSIDE IT (inbound #789; issues #1843, #2037):

        .github/workflows/branch-entry.yml   the CI gate that holds every PR to carrying a written
                                             entry, by calling the shipped check-branch-entry.ps1
        .github/workflows/always-on-budget.yml  the CI gate that holds every PR to not growing the
                                             always-on document path -- CLAUDE.md plus its '@'-import
                                             closure, which every session pays before a single
                                             assignment is given. Beside the entry gate rather than in
                                             Part 3 because both fire on `pull_request` and gate what is
                                             about to land, where Part 3's runners repair what a merge
                                             nobody watched left behind
        .github/pull_request_template.md     the PR body open-pr fills in -- copied from the plugin's
                                             own templates/ reference, because GitHub reads a PR
                                             template only from this path in your repo and so it is
                                             the one file in the cycle that cannot be imported

    A PLUGIN INSTALL CANNOT CREATE THIS FOLDER -- an install is a clone into the plugin cache and
    writes nothing into the repo -- so the folder arrives through this command, and
    check-script-contract.ps1 (surfaced by the script-contract session hook) reports at session start
    while it is missing.

    STRICTLY ADDITIVE, NEVER OVERWRITES. Every file that already exists is left exactly as it is,
    whatever it contains -- the same rule specialists-init and adopt-config follow, and what makes a
    re-run find nothing to do. The scaffolded docs carry VUL-IN markers where only this repo can answer.

    AND SINCE #2171 THERE IS NO EXCEPTION AT ALL. One remained until then: the UPDATE section of the
    folder README, a fenced region this run replaced on every -Apply, because a page scaffolded once is
    never corrected afterwards -- "right owner, wrong reach", the shape recorded for PR #734 and stated
    for CLAUDE.md below. That answer went with the page it was written into: this command no longer
    scaffolds the folder's README.md or CONTRIBUTING.md, so there is nothing here it owns a region of,
    and "nothing that already exists is ever touched" is now true without qualification.

    NOTHING HERE IS EVER REWRITTEN, INCLUDING THE BRANCH DOCUMENT. Until August 23, 2026 this command also
    placed branch/templates/ and new-branch refreshed those on drift -- the one exception to "additive
    only", because they were generated references rather than anybody's writing. The merged document
    carries its own guidance, so there is no reference beside it to keep current, and the exception is gone
    with the thing it existed for.

    REFUSED IN A REPO THAT PUBLISHES PLUGINS (.claude-plugin/marketplace.json present). The source repo
    of this workflow arranges that folder by hand -- it is the product's home, not a consumer -- so
    scaffolding it there would write a layout over one its owner composed deliberately.
    AND ITS ANSWER DIFFERS FROM WHAT THIS COMMAND WRITES, in one way worth knowing before copying it:
    the source has NO root CONTRIBUTING.md, keeping that floor in its CLAUDE.md instead (Dave,
    August 27, 2026), while the page scaffolded below assumes a consumer has one. That is the source's
    own housekeeping rather than the model -- see CONTRIBUTING-portable.md, which recommends the root
    page and says why.

.PARAMETER Apply
    Write the files. Without it the command is a DRY RUN that prints exactly what it would create and
    touches nothing -- the same default adopt-config uses, and for the same reason: the first run of a
    command that adds files to your repo should show you the list.

.EXAMPLE
    .\scripts\task\adopt-workflow-folder.ps1
    .\scripts\task\adopt-workflow-folder.ps1 -Apply
#>

[CmdletBinding()]
param(
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Dual-context repo root: a consumer running the plugin mirror gets it from CLAUDE_PROJECT_DIR, the
# workshop root copy falls back to the git root. Same resolution as every other mirrored script.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'adopt-workflow-folder.ps1'

# The scaffolded branch files come from the same formatters new-branch and the fold call, so this
# command cannot write a shape of its own. repo-config.ps1 first and optional, exactly as new-branch
# loads it: it only supplies wording overrides here, and every string has a built-in default.
$repoConfig = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
    try { . $repoConfig } catch { Write-Warning "scripts/repo-config.ps1 failed to load ($($_.Exception.Message)) -- the built-in wording is used." }
}
. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
# Get-SeamValue + the computed defaults (issue #885): this scaffold reads the SAME seam definitions the
# cut and the fold now read, so the paths this folder's own docs name can never disagree
# with where the workflow actually reads and writes.
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')

# THE SOURCE OF *THIS* WORKFLOW arranges that folder by hand -- see the header -- so this command refuses
# there. It sits below the dot-sources because the test it needs lives in seam-lib, and it still runs
# before anything is written: loading a lib changes nothing on disk.
#
# NARROWED, ISSUE #998 (August 27, 2026). This used to be the bare one-file test -- does this repo have a
# .claude-plugin/marketplace.json -- which answers "does this repo publish plugins", not "is this repo the
# source of this workflow". Under Dave's own one-product-one-repository rule the next product gets its own
# marketplace, so this refusal was on course to turn away a genuine consumer from the one command that
# scaffolds the folder it needs, with a message telling it that it arranges that folder by hand. It does
# not. Test-IsWorkflowSourceRepo reads the manifest now, so only the repo that publishes this workflow is
# refused.
if (Test-IsWorkflowSourceRepo -RepoRoot $repoRoot) {
    Write-Host 'REFUSED: this repo publishes this workflow, so it is its source rather than a consumer.' -ForegroundColor Red
    Write-Host 'The source arranges dkj-policy/ by hand, and its answer differs from what this'
    Write-Host 'command writes: it keeps NO root CONTRIBUTING.md at all (Dave, August 27, 2026), while the'
    Write-Host 'page scaffolded here assumes you have one. Nothing was written.'
    exit 1
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$nl = "`n"

# WHERE THIS REPO KEEPS ITS RELEASE LIST, read rather than assumed. The pages below name that path, and
# naming the default where a repo has repointed the seam would send its reader to a file that is not
# theirs -- the same mistake cut-release's missing-file warning was repaired for (August 4, 2026). Read
# through the shared seam reader, so a repo that defines nothing gets the same computed default the cut
# itself would fall back to -- 'releases/README.md' cannot be assumed here any more (issue #885, group E):
# this script already refused above for a repo that publishes plugins, so every caller reaching this line
# is a consumer, and the computed default for a consumer is now inside this very folder.
#
# history.md, NOT README.md -- 'dkj-policy/releases/README.md' is ALREADY this folder's seam-ANSWERS
# page (the $releasesReadme target below). The list and the answers are two different kinds of document in
# this repo's own root (README.md holds the answers, root releases/README.md holds the list) purely because
# they sit at different directory levels; folded into the SAME directory they need different names, or the
# scaffold below would be asked to write two documents to one path.
$historyRelPath = Get-SeamValue -Name 'Get-ReleaseHistoryPath' -Default (Get-DefaultReleaseHistoryPath -RepoRoot $repoRoot)
Assert-WorkflowIsolatedSeamPath -RepoRoot $repoRoot -RelativePath $historyRelPath -SeamName 'Get-ReleaseHistoryPath'
# WHERE THIS REPO KEEPS ITS CHANGELOG (issue #885, group A). Same reasoning: the scaffold below has to
# name the same path the cut/fold seam resolves to, not a literal that can drift from it.
$changelogRel = Get-SeamValue -Name 'Get-ChangelogPath' -Default (Get-DefaultChangelogPath -RepoRoot $repoRoot)
Assert-WorkflowIsolatedSeamPath -RepoRoot $repoRoot -RelativePath $changelogRel -SeamName 'Get-ChangelogPath'

# WHERE THE HAND-WRITTEN RELEASE NOTE WILL LAND (issue #1150), resolved here for the same reason the two
# seams above are: the pages below name this path, and naming a destination the cut does not use sends
# their reader to a directory nothing will ever write. Get-ReleaseNoteRoot was the one root that escaped
# that rule -- the docs asserted 'releases/audience/' flatly while the fallback wrote to the repo root.
#
# THIS IS THE ONE SEAM THIS COMMAND ANSWERS, and the narrowness is the whole safety argument. adopt-config
# never places a 'decide' record, because copying the source's answer would assert something about a repo
# it merely found. That reasoning does not hold here: this run CREATES the folder, so for a repo with no
# answer and no notes it is not describing a tree, it is making one. Three conditions, all required --
# repo-config.ps1 exists to append to, the seam is unanswered, and no note sits at the fallback -- so the
# only repo that gets an answer written is the one that cannot have anything to lose by it.
$noteRootFallback  = 'releases/notes'
$workflowFolder    = Get-WorkflowFolderName -RepoRoot $repoRoot
$noteRootIsolated  = "$workflowFolder/releases/audience"
$noteRootAnswered  = [bool](Test-FunctionDefined 'Get-ReleaseNoteRoot')
# A DIRECTORY IS NOT A NOTE, and the difference is measurable rather than pedantic: cut-release created a
# stray releases/notes/<X>.x/ at every cut for a fortnight while writing the note elsewhere (see its own
# comment at the note write). Git tracks no empty directory, so such a tree appears in no commit and would
# read here as "this repo has notes" if existence were the test. Markdown files are the test.
$noteRootHasNotes  = $false
$fallbackAbs = Join-Path $repoRoot ($noteRootFallback -replace '/', '\')
if (Test-Path -LiteralPath $fallbackAbs -PathType Container) {
    # Streamed, not collected: Select-Object -First 1 stops the enumeration, while wrapping the call in
    # @() would walk the whole tree first to answer a question that one file settles.
    $noteRootHasNotes = $null -ne (Get-ChildItem -LiteralPath $fallbackAbs -Filter '*.md' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)
}
$repoConfigExists  = Test-Path -LiteralPath $repoConfig -PathType Leaf
$writeNoteRootSeam = (-not $noteRootAnswered) -and (-not $noteRootHasNotes) -and $repoConfigExists
# COERCED TO A STRING AND FALLBACK-GUARDED. This value comes out of a function in somebody else's file,
# so it can be $null or empty however carefully the contract is worded -- and every use below is a string
# operation that would throw under this script's strict mode rather than report anything useful.
$noteRootRelPath   = if ($noteRootAnswered) { [string](Get-ReleaseNoteRoot) }
                     elseif ($writeNoteRootSeam) { $noteRootIsolated }
                     else { $noteRootFallback }
if ([string]::IsNullOrWhiteSpace($noteRootRelPath)) { $noteRootRelPath = $noteRootFallback }
$noteRootRelPath = ($noteRootRelPath -replace '\\', '/').TrimEnd('/')
# --- What the folder contains ---------------------------------------------------------------------
# One list, each entry a repo-relative path plus the content it gets WHEN ABSENT. The docs name their
# portable halves in code rather than linking them, the same choice DEVELOPMENT-portable.md explains: the
# portable pages live in the plugin install, and a relative link into a plugin cache is a path that is
# wrong on every machine but this one.

$releasesReadme = @(
    '# Releases',
    '',
    'The release model -- the tiers, what a release must earn, which documents a cut writes -- is the',
    'plugin''s `RELEASES-portable.md`. This page is this repo''s answers to it.',
    '',
    '<!-- VUL-IN: the seam answers in force here: Get-ReleaseNoteRoot, Get-ReleaseHistoryPath,',
    '     Get-ReleaseAudienceTier, Get-ReleaseConsumerBumps, Get-ReleaseNotesGrouping -- state what this',
    '     repo chose and why, so a reader does not have to open scripts/repo-config.ps1 to learn it. -->',
    '',
    ('**The release LIST is not on THIS page** -- it lives beside it, at `' + $historyRelPath + '`,'),
    'which is where `Get-ReleaseHistoryPath` points. Two different documents even though both are now',
    'inside this folder: this page is your hand-written ANSWERS to the seam (prose, decisions), rewritten',
    'only by you; the list is machine-appended, one row per release, and never touched by hand except to',
    'start it. The source repo carries exactly this pair in exactly this folder since August 27, 2026, when',
    'its own release list moved in beside its answers page -- a document somebody edits and a document a',
    'script owns should never share a path.',
    '',
    ('That file is **not** scaffolded, deliberately: see the closing advice of `adopt-workflow-folder` for'),
    'what it has to contain before your first cut, and why a half-written one would be worse than none.'
)

# THE ONE FILE THIS COMMAND PLACES OUTSIDE THE FOLDER, and it is deliberate (inbound #789). The branch
# entry is a convention the plugin ships every reader of, while nothing enforced it: open-pr refuses to
# push an unwritten entry and ship-pr refuses to merge on an unresolved step, but both are LOCAL, and a
# branch pushed by hand or a PR opened in the GitHub UI meets neither. Both existing consumers therefore
# wrote a CI gate from scratch, against the same convention, and both had already drifted from it. So the
# gate ships as a script and this places the six lines that call it. Precedent for a plugin placing a
# workflow: adopt-shopify-floor writes .github/workflows/theme-check.yml.
#
# IT TRACKS main RATHER THAN A TAG, which is the one choice here worth arguing. A pinned gate keeps
# enforcing the shape it was pinned at -- and the entry's own path has moved twice already, so a stale pin
# does not fail loudly, it fails the wrong way: refusing branches that do carry an entry at the current
# path. Tracking the tip means the gate follows the convention it enforces. A consumer who needs
# reproducibility over currency pins a tag and accepts owning the bump.
#
# AND THAT IS HALF THE TRADE. The paragraph above weighs the ENTRY's path moving; it never weighed the
# SCRIPT's own path moving, which is what happened -- plugins/workflows/contributing-davekjohn/ became
# plugins/dkj-policy/, and every consumer scaffolded before the move kept naming the old path. Tracking
# the tip protects a consumer from a stale convention and exposes them to a moved script. Measured
# September 10, 2026 (#1805): two consumers red on every pull request, unnoticed because neither had
# opened one since the September 5 move. (The report said August 3 and five weeks; the path they name
# only existed from August 26, so the break is five DAYS old -- the whole timeline is in
# consumer-runner-lib.ps1's header, with the git log it comes off.)
#
# THE PIN STAYS, AND THE EXPOSURE IS COVERED AT THE OTHER END -- because it cannot be covered here. This
# command writes the path once, at adoption, and nothing rewrites it afterwards, so no change made in
# this file can reach a repo that adopted in August. What can: check-connectors.ps1's check 6, which
# reads the runners a registered consumer actually has and reports a path this tree no longer holds; and
# this command's own suite, which now DERIVES the emitted path from the emitted file and asserts it
# exists here, where the three literal asserts in adopt-ci-floor.tests.ps1 compared the output
# against itself and stayed green through the move.
$entryGateWorkflow = @(
    '# Every PR into the trunk carries a WRITTEN changelog entry.',
    '#',
    '# The check itself is not in this file: it is check-branch-entry.ps1, shipped by the',
    '# dkj-policy plugin, which calls the same two functions open-pr calls locally. That is the',
    '# point -- there is one definition of "written" in the system, and this is not a second one. A gate',
    '# hand-written in shell is a second definition, free to drift from the fold that reads the first.',
    '#',
    '# WHY THE HEAD REF IS PASSED EXPLICITLY: a pull_request checkout is a detached merge commit, so',
    '# ''git rev-parse --abbrev-ref HEAD'' answers ''HEAD'' there. The script refuses rather than guessing.',
    '#',
    '# WHY WINDOWS: the shared scripts target Windows PowerShell 5.1, which is what ''shell: powershell'' is.',
    '#',
    '# WHICH BRANCHES OWE NOTHING: answer Get-EntryGateExemptPrefixes in scripts/repo-config.ps1. It',
    '# defaults to ''sync'' -- a mirror branch carries somebody else''s work, so it has nothing to declare.',
    '#',
    '# THE PINNED REF is deliberately a moving branch: a pinned gate enforces the shape it was pinned at,',
    '# and the entry path has moved twice. Pin a tag instead if you would rather own the bump.',
    'name: Branch entry',
    '',
    'permissions:',
    '  contents: read',
    '',
    'on:',
    '  pull_request:',
    '    branches: [main]',
    '',
    'jobs:',
    '  branch-entry:',
    '    runs-on: windows-latest',
    '    steps:',
    '      - uses: actions/checkout@v5',
    '',
    '      - name: Fetch the shared workflow scripts',
    '        uses: actions/checkout@v5',
    '        with:',
    '          repository: DKJ-Solutions/dkj-claude-plugins',
    '          ref: main',
    '          path: .workflow-scripts',
    '',
    '      - name: Changelog entry written',
    '        shell: powershell',
    '        env:',
    '          CLAUDE_PROJECT_DIR: ${{ github.workspace }}',
    '        run: |',
    '          powershell -NoProfile -ExecutionPolicy Bypass -File .workflow-scripts/plugins/dkj-policy/scripts/lint/check-branch-entry.ps1 -Branch "${{ github.head_ref }}"',
    '          exit $LASTEXITCODE'
)

# THE SECOND PR GATE THIS COMMAND PLACES (issue #2037): a PR may not grow what every session pays before
# a single assignment is given -- CLAUDE.md plus everything it '@'-imports.
#
# BESIDE branch-entry.yml AND NOT IN PART 3, and that was a correction to the issue's own proposal rather
# than a preference. #2037 named Part 3, and in the same sentence named branch-entry.yml as the runner it
# is modelled on -- which is this command's, not adopt-ci-floor's. The split is by TRIGGER and by what the
# runner is for: these two fire on `pull_request` and gate what is about to land, while Part 3's three
# repair what a merge the shipping session never observed left behind, on `push` and on a schedule.
#
# WHY A CI HALF AT ALL, when open-pr already refuses locally: a branch pushed by hand, or a PR opened in
# the GitHub UI, meets no local gate. That is the same hole branch-entry.yml exists for, and this path is
# the one thing in a repo whose cost is paid by every future session rather than by whoever merged.
#
# NO -Record, DELIBERATELY. The ratchet's memory is lowered by the LOCAL gate, inside the branch's own
# commit, where the change is reviewable. A CI runner that rewrote it would be the one carrier able to
# move the baseline with nothing in any diff to say so.
#
# THE PINNED REF is the same moving branch branch-entry.yml above uses, for the reason argued there at
# length, and the exposure it names applies here identically: this command writes the path once, at
# adoption, and check-connectors.ps1's check 6 is what notices later if the path moves.
$alwaysOnGateWorkflow = @(
    '# The always-on budget: a PR may not grow what every session pays before a single assignment is',
    '# given -- CLAUDE.md plus everything it ''@''-imports.',
    '#',
    '# The check itself is not in this file: it is check-always-on-budget.ps1, shipped by the',
    '# dkj-policy plugin, which reads the same verdict open-pr reads locally and the session hook',
    '# reports at start. One definition, three carriers.',
    '#',
    '# WHAT THE CEILING IS: answer Get-AlwaysOnBudget in scripts/repo-config.ps1, in BYTES. Unanswered,',
    '# it is 100,000. A repo already over it is NOT refused on day one -- the gate holds the path at a',
    '# recorded baseline and refuses growth, so a repo converges on the ceiling instead of failing',
    '# against it from a standing start.',
    '#',
    '# WHY THIS RUNNER AGREES WITH THE LOCAL GATE even though it has no plugin cache: the baseline',
    '# records every document on the path by its import target, and the check carries the recorded',
    '# figure for anything it cannot resolve here -- the orchestrator persona most of all, which a',
    '# runner has no marketplace clone to read.',
    '#',
    '# WHY WINDOWS: the shared scripts target Windows PowerShell 5.1, which is what ''shell: powershell'' is.',
    '#',
    '# THE PINNED REF is deliberately a moving branch, for the reason branch-entry.yml states.',
    'name: Always-on budget',
    '',
    'permissions:',
    '  contents: read',
    '',
    'on:',
    '  pull_request:',
    '    branches: [main]',
    '',
    'jobs:',
    '  always-on-budget:',
    '    runs-on: windows-latest',
    '    steps:',
    '      - uses: actions/checkout@v5',
    '',
    '      - name: Fetch the shared workflow scripts',
    '        uses: actions/checkout@v5',
    '        with:',
    '          repository: DKJ-Solutions/dkj-claude-plugins',
    '          ref: main',
    '          path: .workflow-scripts',
    '',
    '      - name: The always-on document path is inside its budget',
    '        shell: powershell',
    '        env:',
    '          CLAUDE_PROJECT_DIR: ${{ github.workspace }}',
    '        run: |',
    '          powershell -NoProfile -ExecutionPolicy Bypass -File .workflow-scripts/plugins/dkj-policy/scripts/lint/check-always-on-budget.ps1',
    '          exit $LASTEXITCODE'
)

# CHANGELOG.md (issue #885, group A): this folder's own pending-changes list, isolated from any
# CHANGELOG.md the consumer already keeps at their root -- the workflow never reads or writes that one
# again. Deliberately GENERIC prose rather than this repo's own evolved intro (which cites this repo's
# own dates and links): a fresh consumer gets the shape the mechanism actually requires, nothing this
# repo has accumulated. The release-list link is relative to THIS file's own location (inside the
# folder), computed from $historyRelPath rather than assumed, because a repo that repointed the seam
# outside the folder needs '../' where one that left it alone needs none.
$historyRelFromFolder = if ($historyRelPath -like 'dkj-policy/*') {
    $historyRelPath.Substring('dkj-policy/'.Length)
} else {
    "../$historyRelPath"
}
#
# THE HEADING LEVEL IS COMPOSED, NEVER TYPED (inbound #1098). This sentence said `##` while the fold has
# written `###` ever since the levels shifted, so the one piece of prose a consumer ever reads ABOUT their
# own changelog contradicted the entry three lines below it. Nothing breaks, which is why it survived: no
# gate compares the intro against the constant, and the first person to notice is somebody debugging why
# their hand-written `##` entry did not fold. Reading Get-EntryHeadingLevel (dot-sourced above) is what
# stops the sentence drifting from the constant again -- and it also answers the repo that legitimately
# overrode the level, which a corrected literal would not.
$entryHashes = '#' * (Get-EntryHeadingLevel)
#
# AND THE PENDING HEADING IS PLACED, COMPOSED THE SAME WAY (issue #1518). This array had no
# '## [Unreleased]' line in it and nothing else in the tree wrote one, so every repo this command
# scaffolded got the pre-August-26 FLAT shape -- an intro followed directly by one entry per change --
# while entry-scaffold-lib called that heading "the heading every un-cut entry sits under". Nothing broke,
# which is why it survived: the fold inserts at the first entry heading or, where there is none, at the end
# of the content, and the cut writes the head back whatever is in it. Both shapes fold and cut correctly,
# so no gate had anything to say.
#
# WHAT FORCED IT IS THE PORTABLE PAGE, NOT THE COMMENT. DEVELOPMENT-portable.md travels to every consumer
# with the plugin and instructs them unconditionally: "before you write that a behaviour changed, grep
# `[Unreleased]` for what it used to be." In a repo scaffolded here, that grep matched nothing at all. A page
# that reaches a consumer cannot name a heading only the source repo has -- which is what ruled out the two
# other readings on that issue (that the heading is this repo's own, or the consumer's choice) rather than a
# preference between them. entry-scaffold-lib says the same thing from the other side, in the block that
# defines the label: the reason it is a single constant rather than a seam is that "nothing migrates the
# document" -- the heading is "already committed in this repo's CHANGELOG.md and in every consumer's". That
# second half is what this change makes true of a fresh adoption; before it, the consumer had no heading to
# migrate away from OR to keep.
#
# IT GOES LAST, AND THAT IS THE WHOLE PLACEMENT RULE. The heading sits one level SHALLOWER than an entry, so
# Split-Changelog's boundary lands below it and it stays part of the head, preserved by every cut; and the
# first fold into an entry-less document appends at the end of the content, which is beneath it. Composed
# from Get-ChangelogUnreleasedHeading rather than typed, for exactly the reason $entryHashes above is: a repo
# that repointed the entry level or translated the label gets its own heading, and the one sentence a
# consumer ever reads ABOUT their changelog cannot drift from the constant their parsers read.
$unreleasedHeading = Get-ChangelogUnreleasedHeading
$changelogIntro = @(
    '# Changelog',
    '',
    ('Everything merged since the last release sits under `' + $unreleasedHeading + '`, newest first:'),
    ('one `' + $entryHashes + '` per change, and under it the sections your own `CONTRIBUTING.md` names'),
    'for your audience tier. The mechanism itself -- the branch document a change is written in, the fold',
    'that moves it here, and what the release cut does with this list -- is the plugin''s',
    '`CONTRIBUTING-portable.md`, which travels with `dkj-policy` and is not restated here.',
    '',
    ('This file is emptied down to this intro and that heading at every release; what was in it moves into'),
    ('that release''s own documents instead. See [`' + $historyRelPath + '`](' + $historyRelFromFolder + ')'),
    'for the list of releases actually cut.',
    '',
    $unreleasedHeading
)

# THE SECOND FILE THIS COMMAND PLACES OUTSIDE THE FOLDER, and unlike the gate above it is a COPY rather
# than six lines calling a shipped script (issue #1843). GitHub reads a PR template only from
# .github/pull_request_template.md in the consumer's own repo, so this is the one file in the whole cycle
# that cannot be imported -- CONTRIBUTING-portable.md said exactly that, and then left the copying to a
# person, which this change ends and that page now records. Nothing anywhere had stated a reason for
# leaving it manual, and that is what separated it from every genuine 'decide' seam in this workflow:
# those are answered by hand because only the repo knows the answer, and here the plugin already ships
# the answer.
#
# WHY A MISSING ONE COSTS MORE THAN A MISSING FILE USUALLY DOES: open-pr wraps its whole body-building
# block in 'if (Test-Path $templatePath)' with no else, so a consumer without the file gets a PR with no
# body at all -- no description, no type box, nothing -- and no warning. The one warning that block does
# carry fires when a placeholder does not MATCH, which is a different state and the only one anybody has
# been told about. So the absence is silent at exactly the moment a reviewer needs the description.
#
# THE CONTENT COMES OFF THE SHIPPED REFERENCE, NEVER RETYPED. The whole interface is one line -- the
# placeholder open-pr recognises verbatim -- so a literal copy of it here would be a second definition,
# free to drift from the first. That is the same argument the gate above makes for not hand-writing its
# check in shell. The reference sits at the plugin root in both contexts this script runs in (the released
# mirror and the source tree), so one relative path reaches it from either.
#
# AN ABSENT REFERENCE PLACES NOTHING, rather than falling back to a literal. A fallback would be that
# second definition wearing an emergency jacket, and it would be the copy that ships in the one case
# nobody is watching. Everything else this command places is unaffected; the run names the file it could
# not read.
#
# TWO CANDIDATE PATHS, BECAUSE THIS FILE EXISTS TWICE AND THE DRIFT LINT HOLDS THE TWO BYTE-IDENTICAL.
# In the released mirror, scripts/task/ sits under the plugin root and '..\..\templates' is the shipped
# folder. In the source tree the same bytes also sit at the repo's own scripts/task/, where that path
# points at a <repo>/templates that does not exist and the reference is one level deeper, under
# plugins/dkj-policy/. Both hang off $PSScriptRoot and NEITHER off $repoRoot, which is the consuming
# repo being scaffolded -- a tree that by definition does not ship this plugin. Getting that wrong is
# not a silent miss: the fallback simply never fires and the template is never placed, which is how
# this pair was measured rather than reasoned.
$prTemplateRef = @(
    (Join-Path $PSScriptRoot '..\..\templates\pull_request_template.md'),
    (Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\templates\pull_request_template.md')
) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1

$prTemplateTargets = @()
if ($prTemplateRef) {
    $prTemplateTargets = @(
        @{ Rel = '.github/pull_request_template.md'; Content = ([System.IO.File]::ReadAllText($prTemplateRef)) }
    )
} else {
    # BOTH candidates are named, not just the first. This branch only fires on a checkout that is
    # already broken, which is exactly the reader who cannot afford to be told half of what was tried.
    Write-Warning ("The shipped PR template reference could not be found -- .github/pull_request_template.md is not placed by this run.`n" +
        "  Looked for: $(Join-Path $PSScriptRoot '..\..\templates\pull_request_template.md')`n" +
        "         and: $(Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\templates\pull_request_template.md')`n" +
        '  Everything else below is unaffected. Copy it by hand from the plugin''s templates/ folder, or open-pr builds PR bodies with no description at all.')
}

$targets = @(
    @{ Rel = '.github/workflows/branch-entry.yml';     Content = (($entryGateWorkflow -join $nl) + $nl) },
    @{ Rel = '.github/workflows/always-on-budget.yml'; Content = (($alwaysOnGateWorkflow -join $nl) + $nl) }
) + $prTemplateTargets + @(
    @{ Rel = 'dkj-policy/releases/README.md';  Content = (($releasesReadme -join $nl) + $nl) },
    @{ Rel = $changelogRel;                            Content = (($changelogIntro -join $nl) + $nl) }
    # NO releases/audience/.gitkeep ANY MORE (issue #1150). It was placed on the stated ground that "the
    # audience root must exist before the first cut writes into it", and that premise is false: the cut
    # creates the note's own parent directory before writing it (cut-release.ps1, at the note write --
    # added there in August 2026 precisely because Write-Utf8NoBom is a bare WriteAllText and makes no
    # directories). So the file bought nothing the cut needed, and what it did buy was the contradiction
    # this issue reported -- an empty committed directory asserting a destination the unanswered seam did
    # not use. The seam answer above replaces it: the destination is now stated where the cut reads it
    # rather than implied by a placeholder, and the directory appears when there is a note to put in it.
    #
    # NO <branch>.md, AND THAT IS THE ADOPTION'S HALF OF THE LIFETIME RULE (Dave, August 23, 2026).
    # This placed the document in its reset state so a consumer's first look at the folder was also their
    # reference for what a branch gets. The document is branch-lifetime now -- new-branch creates it, the
    # fold removes it -- so placing one here would put a file on their trunk that their own first fold then
    # deletes, and it would be the only thing in this list that is not permanently theirs. What it used to
    # buy, a reader seeing the whole form at once, is DEVELOPMENT-portable.md's job; that page travels
    # with every plugin update, which a file scaffolded once never does.
)
# NO branch/templates/ ANY MORE. The reference copies of the two branch files were placed here because the
# working files deliberately carried no guidance; the merged document carries its own, so the reference and
# the thing you write in are the same file. A consumer adopting the folder today gets one fewer directory
# and nothing less to read.

# --- Place (or list) ------------------------------------------------------------------------------
Write-Host "== adopt-workflow-folder -- $repoRoot ==" -ForegroundColor Cyan
if (-not $Apply) { Write-Host '  DRY RUN -- nothing is written. Re-run with -Apply to place the files below.' -ForegroundColor Yellow }

$created = 0
$kept = 0
foreach ($t in $targets) {
    $abs = Join-Path $repoRoot ($t.Rel -replace '/', '\')
    if (Test-Path -LiteralPath $abs) {
        $kept++
        Write-Host "  [exists]  $($t.Rel) -- left as it is" -ForegroundColor DarkGray
        continue
    }
    $created++
    if ($Apply) {
        $dir = Split-Path -Parent $abs
        if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
        [System.IO.File]::WriteAllText($abs, $t.Content, $Utf8NoBom)
        Write-Host "  [created] $($t.Rel)" -ForegroundColor Green
    } else {
        Write-Host "  [create]  $($t.Rel)" -ForegroundColor Green
    }
}

# --- Two pages this command NO LONGER WRITES (#2171, Dave, September 20, 2026) ---------------------
# The folder's README.md and CONTRIBUTING.md were scaffolded by this command until this change, and both
# are retired: two more pages in the consumer's own tree made that repo more complicated and produced more
# inconsistency than they removed. THERE IS ONE CONTRIBUTING FOR A CONSUMER TO READ and it is the plugin's
# CONTRIBUTING-portable.md. What a consumer's own repo answers goes into that repo's specialist lens,
# where the rest of its repo-specific answers already live -- one destination instead of two.
#
# WHAT WENT WITH THEM, so nobody restores half of it: the refreshable fenced block (#1766) and its four
# top-up states. That block existed because a page scaffolded once is never corrected afterwards, which is
# the right repair for a page the plugin OWNS -- and this change removes the page instead. It answers the
# same defect one level up rather than contradicting it, and the UPDATE chapter it carried belongs to
# whichever page that repo keeps its own answers on.
#
# AN EXISTING COPY IS REPORTED AND NEVER TOUCHED, and no delete command is printed. Several consumers hold
# these pages today; a copy may carry the only written statement of something that repo answered, and
# nothing here can tell that from a stale scaffold. Printing a paste-ready delete would push a reader
# towards losing it for the sake of tidiness this command does not have to buy.
#
# THE GATES THAT READ THEM ARE DELIBERATELY UNCHANGED -- check-consumer-prose still runs its detectors
# over both names and check-policy-drift still lists them -- so a page that is still there keeps exactly
# the standing its repo gives it. What stopped is the AUTHORING, not the reading: a gate narrowed to match
# this change would retire itself in the five repos whose pages are the reason it exists.
$legacyPages = @(
    @("$workflowFolder/README.md", "$workflowFolder/CONTRIBUTING.md") |
        Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot ($_ -replace '/', '\')) -PathType Leaf }
)
if ($legacyPages.Count -gt 0) {
    foreach ($legacyPage in $legacyPages) {
        Write-Host "  [legacy]  $legacyPage -- this command no longer writes or refreshes it" -ForegroundColor Yellow
    }
    Write-Host '            One CONTRIBUTING is the plugin''s portable page; what THIS repo answers belongs' -ForegroundColor DarkGray
    Write-Host '            in its specialist lens. Nothing here deletes either page and keeping them is a' -ForegroundColor DarkGray
    Write-Host '            complete answer -- but the plugin''s fenced block in the README is frozen from' -ForegroundColor DarkGray
    Write-Host '            now on, so read it as this repo''s own writing rather than as current.' -ForegroundColor DarkGray
}

# --- The one seam this run may answer (issue #1150) ------------------------------------------------
# APPENDED, NEVER MERGED, and never over a function that is already there -- the same two rules
# adopt-config places a record under, for the same reason: the file belongs to this repo, and an
# inserter hunting for "the right place" in it would be rewriting somebody else's file on a guess.
#
# EVERY BRANCH BELOW PRINTS, including the ones that write nothing. A run that silently declined to
# answer the seam is indistinguishable from one that never considered it, and the difference is the
# whole subject of this issue -- the reader has to be able to tell "your notes stay where they are"
# from "nobody thought about your notes".
$noteRootSeamAnswer = @(
    '',
    # EVERY CONCATENATED ELEMENT IS PARENTHESISED, and it is load-bearing rather than style: inside an
    # array literal PowerShell binds the comma tighter than the '+', so an unwrapped 'a' + $x + 'b' becomes
    # THREE elements and -join $nl then writes them as three lines. This block generates PowerShell source,
    # so that mistake does not fail here -- it ships a repo-config.ps1 with an unterminated string in it.
    ('# --- Answered by adopt-workflow-folder.ps1 when it scaffolded ' + $workflowFolder + '/ ---'),
    'function Get-ReleaseNoteRoot {',
    '    <#',
    '        Where the hand-written release note is written and read back from.',
    '',
    ('        Written by adopt-workflow-folder.ps1 rather than left to the shared ''' + $noteRootFallback + ''' fallback,'),
    '        because at the moment that folder was scaffolded this repo defined no answer AND had no note',
    '        of its own at that fallback -- so there was nothing here for this answer to move, and leaving',
    '        it unanswered would have put the notes outside the folder the adoption had just built.',
    '',
    '        This is this repo''s file now. Edit it freely; nothing overwrites a function already here.',
    '    #>',
    ('    ''' + $noteRootIsolated + ''''),
    '}'
)

if ($writeNoteRootSeam) {
    if ($Apply) {
        # APPENDED WITH AppendAllText RATHER THAN REWRITTEN, and the difference is not style. Reading the
        # file and writing it back re-encodes it: ReadAllText strips a byte-order mark and a NoBom write
        # does not put it back, so a consumer whose repo-config.ps1 carries one -- which on a .ps1 is the
        # FIX rather than the defect, since Windows PowerShell 5.1 otherwise decodes it as the system ANSI
        # code page -- would have it silently removed by a command that was only meant to add a function.
        # Appending leaves every existing byte exactly where it is.
        $existingConfig = [System.IO.File]::ReadAllText($repoConfig)
        $appendix = (($noteRootSeamAnswer -join $nl) + $nl)
        if ($existingConfig.Length -gt 0 -and -not $existingConfig.EndsWith("`n")) { $appendix = $nl + $appendix }
        [System.IO.File]::AppendAllText($repoConfig, $appendix, $Utf8NoBom)
        Write-Host "  [answered] Get-ReleaseNoteRoot -> '$noteRootIsolated' in scripts/repo-config.ps1" -ForegroundColor Green
    } else {
        Write-Host "  [answer]   Get-ReleaseNoteRoot -> '$noteRootIsolated' in scripts/repo-config.ps1" -ForegroundColor Green
    }
} elseif ($noteRootAnswered) {
    Write-Host "  [seam]     Get-ReleaseNoteRoot is already answered here ('$noteRootRelPath') -- left as it is" -ForegroundColor DarkGray
} elseif ($noteRootHasNotes) {
    Write-Host "  [seam]     Get-ReleaseNoteRoot left UNANSWERED -- you already have notes at $noteRootFallback/" -ForegroundColor Yellow
} else {
    Write-Host '  [seam]     Get-ReleaseNoteRoot left unanswered -- this repo has no scripts/repo-config.ps1' -ForegroundColor Yellow
}

Write-Host ''
if ($Apply) {
    Write-Host "Done: $created file(s) created, $kept left as they were." -ForegroundColor Green
} else {
    Write-Host "Would create $created file(s); $kept already exist. Re-run with -Apply." -ForegroundColor Yellow
}

# --- What only this repo can answer, said out loud rather than left to be discovered ---------------
# One 'decide' seam points the release machinery at the folder. Since issue #1150 this run ANSWERS it
# where it safely can -- see the seam block above for the three conditions -- so what is printed below
# is a report of what happened to it rather than an instruction in every case. Where it was left
# unanswered the cut keeps writing hand-written notes to the shared default at the repo root, which is a
# working state but not the one this folder is for.

# RE-ADOPTION MIGRATION NOTE (issue #885): the one transition this run cannot do for you, because it
# is prose in somebody else's file. Same shape as this repo's own releases/README.md migration advice
# ("if it carries a release list from before this split, move that list").
if (Test-Path -LiteralPath (Join-Path $repoRoot 'CHANGELOG.md') -PathType Leaf) {
    Write-Host ''
    Write-Host 'YOUR ROOT CHANGELOG.md EXISTS, so read this before your next merge:' -ForegroundColor Yellow
    Write-Host "  Any entry PENDING there right now (not yet released) will NOT be picked up by the next"
    Write-Host "  fold or cut -- both now read $changelogRel instead. Carry a genuinely pending entry over"
    Write-Host "  by hand, or it ships in neither list."
}

Write-Host ''
if ($writeNoteRootSeam) {
    $verb = if ($Apply) { 'is now' } else { 'will be' }
    Write-Host "Get-ReleaseNoteRoot $verb answered here: $noteRootIsolated." -ForegroundColor Cyan
    Write-Host 'WRITTEN RATHER THAN PRINTED AS AN INSTRUCTION (issue #1150), and only because this repo had' -ForegroundColor DarkGray
    Write-Host 'no answer and no note at the shared fallback. Its contract record explains why the shared' -ForegroundColor DarkGray
    Write-Host 'DEFAULT still stays ''releases/notes'' -- a repo that answers nothing must keep meaning what it' -ForegroundColor DarkGray
    Write-Host 'meant yesterday -- and that argument is about a repo with notes already on disk, which this' -ForegroundColor DarkGray
    Write-Host 'one is not. Repoint it if you would rather keep your notes somewhere else; nothing here is' -ForegroundColor DarkGray
    Write-Host 'rewritten by a later run.' -ForegroundColor DarkGray
} elseif ($noteRootAnswered) {
    Write-Host "Get-ReleaseNoteRoot was already answered here ($noteRootRelPath) and was left alone." -ForegroundColor Cyan
    Write-Host 'Your answer always wins over this command''s, exactly as adopt-config never overwrites one.' -ForegroundColor DarkGray
} else {
    Write-Host "Get-ReleaseNoteRoot is UNANSWERED, so your cut writes hand-written notes to $noteRootFallback/" -ForegroundColor Yellow
    Write-Host 'at your repo root -- outside the folder this command just scaffolded. That is a working state,' -ForegroundColor Yellow
    Write-Host 'not the one this folder is for. To move it, in scripts/repo-config.ps1:' -ForegroundColor Yellow
    Write-Host "  Get-ReleaseNoteRoot     -> '$noteRootIsolated'"
    if ($noteRootHasNotes) {
        Write-Host ''
        Write-Host "  AND MOVE THE NOTES YOU ALREADY HAVE. This run refused to answer the seam for you because" -ForegroundColor Yellow
        Write-Host "  $noteRootFallback/ holds at least one note: repointing the seam without moving them makes the" -ForegroundColor Yellow
        Write-Host "  cut report 'no release note was found', which reads as a repo that has never cut one."
    }
}
Write-Host ''
Write-Host "Get-ReleaseHistoryPath IS ALREADY ISOLATED BY DEFAULT NOW (issue #885): $historyRelPath." -ForegroundColor Cyan
Write-Host 'RE-ADOPTING AN EXISTING CONSUMER, READ THIS: your next cut starts a NEW list here, beside' -ForegroundColor Yellow
Write-Host 'whatever history already sits at your root releases/README.md -- the same duplication-accepted' -ForegroundColor Yellow
Write-Host 'trade the changelog seam makes, deliberately (Dave, August 25, 2026): rather two lists than any' -ForegroundColor Yellow
Write-Host 'chance of writing into a file this workflow does not own. Repoint the seam back to your existing' -ForegroundColor Yellow
Write-Host 'root file instead if you would rather keep one list.' -ForegroundColor Yellow
Write-Host ''
Write-Host "AND THAT FILE IS YOURS TO CREATE, before your first cut: $historyRelPath" -ForegroundColor Cyan
Write-Host '  It needs a section heading naming your first major and a table header under it:'
Write-Host ''
Write-Host '    #### 1.x'
Write-Host ''
Write-Host '    | Version | Date | Type | Title |'
Write-Host '    |---|---|---|---|'
Write-Host ''
Write-Host 'THIS COMMAND DOES NOT SCAFFOLD IT, and that is a decision rather than an omission (inbound'
Write-Host '#786). A file that exists with a table but no <major>.x heading reads as DONE to cut-release:'
Write-Host 'the row lands in it, while the guardrail that refuses to file a v2 row under a 1.x heading is'
Write-Host 'silently off, because that check skips when it finds no section. Same reasoning that keeps'
Write-Host 'adopt-shopify-floor from writing a VUL-IN stub -- a hole with a comment on it is worse than an'
Write-Host 'absent file. And the major in that heading is a version decision this command cannot make for'
Write-Host 'you. Missing altogether, the cut is not silent: it warns'
Write-Host "  ""$historyRelPath is missing -- row not added: <the row>"""
Write-Host 'and cuts the release anyway, so the cost of forgetting is one row you add by hand.'

# THE TWO GENERATED NOTE ROOTS #914 MOVED, WHICH HAD NO WARNING AT ALL (issue #955, August 27, 2026).
# Both sibling seams above got an explicit re-adoption note when #885 isolated them; #914 did the same
# thing to these two on August 26 and nothing followed it, so a consumer's next cut would start two
# fresh trees inside the folder beside the history already sitting at their root -- no error, no
# warning, nowhere in the adoption or the cut.
#
# WHAT IT COST, MEASURED RATHER THAN IMAGINED. djcylow-react had run every adoption skill on every
# bump and still carried 39 files under releases/development/ and 2 under releases/github/ at its repo
# root. They found it themselves and repaired it with git mv (their PR #158), and their own
# repo-config.ps1 now records that nothing in the plugin migrated the files and nothing warned that it
# had to. That note is this block: the next consumer should not have to write it a second time.
#
# GET-RELEASEINTERNALNOTESROOT IS DELIBERATELY NOT HERE. For a consumer it has resolved inside the
# folder since #885 -- it never had a root answer to split away from, so there is nothing to warn
# about. Two roots, not three, and the issue's own third seam name is the retired alias of the first.
#
# RESOLVED BUT NOT ASSERTED, on purpose. The cut already runs Assert-WorkflowIsolatedSeamPath over both
# of these; adding a second refusal here would turn an informational adoption run into one that can
# exit 1 on a seam the reader has not been told about yet, which is the opposite of what this block is.
$changelogNotesRel = Get-SeamValue -Name 'Get-ReleaseChangelogNotesRoot', 'Get-ReleaseDevelopmentNotesRoot' `
    -Default (Get-DefaultReleaseChangelogNotesRoot -RepoRoot $repoRoot)
$githubNotesRel = Get-SeamValue -Name 'Get-ReleaseGithubNotesRoot' `
    -Default (Get-DefaultReleaseGithubNotesRoot -RepoRoot $repoRoot)

Write-Host ''
Write-Host 'THE TWO GENERATED NOTE ROOTS ARE ALSO ISOLATED BY DEFAULT NOW (issue #914):' -ForegroundColor Cyan
Write-Host "  Get-ReleaseChangelogNotesRoot -> $changelogNotesRel"
Write-Host "  Get-ReleaseGithubNotesRoot    -> $githubNotesRel"

# The pre-isolation answers, asked of the same lookup the cut's own tolerance uses rather than listed
# again here -- so a name added there is warned about here without this block learning it separately.
$strandedNoteRoots = @()
foreach ($seamName in @('Get-ReleaseChangelogNotesRoot', 'Get-ReleaseGithubNotesRoot')) {
    foreach ($legacyRel in @(Get-PreIsolationSeamPath -SeamName $seamName)) {
        $legacyAbs = Join-Path $repoRoot ($legacyRel -replace '/', '\')
        if (Test-Path -LiteralPath $legacyAbs -PathType Container) {
            $count = @(Get-ChildItem -LiteralPath $legacyAbs -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue).Count
            $strandedNoteRoots += [pscustomobject]@{ Seam = $seamName; Rel = $legacyRel; Count = $count }
        }
    }
}

if ($strandedNoteRoots.Count) {
    Write-Host ''
    Write-Host 'RE-ADOPTING AN EXISTING CONSUMER, READ THIS: a generated-notes tree is still sitting at' -ForegroundColor Yellow
    Write-Host 'your repo root, where these two seams pointed before #914 isolated them:' -ForegroundColor Yellow
    foreach ($s in $strandedNoteRoots) {
        Write-Host ("  $($s.Rel)/  -- $($s.Count) .md file(s), read by $($s.Seam) until 4.20.0") -ForegroundColor Yellow
    }
    Write-Host 'Your next cut writes into the isolated paths named above instead, and leaves that tree' -ForegroundColor Yellow
    Write-Host 'behind silently -- two brand-new, empty-looking trees beside your real history. Nothing' -ForegroundColor Yellow
    Write-Host 'in the plugin moves the files for you. Two honest answers: git mv the tree onto the' -ForegroundColor Yellow
    Write-Host 'isolated path so the computed default is right again, or define the seam in' -ForegroundColor Yellow
    Write-Host 'scripts/repo-config.ps1 to keep pointing at your root tree. The cut accepts that root' -ForegroundColor Yellow
    Write-Host 'answer for these two seams specifically (issue #956), so repointing is not a fight with' -ForegroundColor Yellow
    Write-Host 'the isolation guard.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'And if your Get-MojibakePaths copy predates August 14, 2026, re-adopt it: the old copy still'
Write-Host 'names the retired root branch/ location, so the moved files sit outside its coverage.'
