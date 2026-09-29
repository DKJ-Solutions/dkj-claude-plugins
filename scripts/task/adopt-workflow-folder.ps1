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
          CHANGELOG.md           this folder's own pending-changes list, isolated from any changelog
                                 the repo already keeps at its root
          (releases/audience/ is NOT placed -- the first cut creates it when it writes the note there)
          (<branch>.md is NOT placed -- one per branch, living only while that branch is open)
          (README.md, CONTRIBUTING.md and releases/README.md are NOT placed ANY MORE -- #2171 and
           #2196, September 20, 2026; the block further down that reports an existing copy carries the
           whole reasoning. ONE file is left, and that list above is the whole of it)

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
                                             entry -- a few-line caller of the source's reusable
                                             workflow, which runs the shipped check-branch-entry.ps1
                                             (#2422; the budget gate below takes the same shape)
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

    AND THE CONSTITUTION IMPORT IN CLAUDE.md (issue #2531). The one '@'-line that loads the plugin's
    rules into every session is written by this run -- inserted above the first import of an existing
    CLAUDE.md, or as the whole of a new one -- where it used to be an instruction plus a session-start
    warning that a consumer could live with for weeks. The block that writes it carries the measurement.

    STRICTLY ADDITIVE, NEVER OVERWRITES. Every file this run places is left exactly as it is once it
    exists, whatever it contains -- the same rule specialists-init and adopt-config follow, and what makes
    a re-run find nothing to do. TWO WRITES REACH INTO A FILE THAT ALREADY EXISTS, and both only ADD: the
    note-root seam appended to scripts/repo-config.ps1 (#1150), and the constitution line inserted into
    CLAUDE.md (#2531). Neither changes or removes a byte that was there, and each is skipped where its
    answer is already present. The scaffolded docs carry VUL-IN markers where only this repo can answer.

    AND SINCE #2171 THERE IS NO EXCEPTION AT ALL. One remained until then: the UPDATE section of the
    folder README, a fenced region this run replaced on every -Apply, because a page scaffolded once is
    never corrected afterwards -- "right owner, wrong reach", the shape recorded for PR #734 and stated
    for CLAUDE.md below. That answer went with the page it was written into: this command no longer
    scaffolds the folder's README.md or CONTRIBUTING.md, so there is nothing here it owns a region of,
    and nothing it placed is ever rewritten. (The two additive writes above are not regions it owns: each
    adds its line once and never looks at it again.)

    NOTHING HERE IS EVER REWRITTEN, INCLUDING THE BRANCH DOCUMENT. Until August 23, 2026 this command also
    placed branch/templates/ and new-branch refreshed those on drift -- the one exception to "additive
    only", because they were generated references rather than anybody's writing. The merged document
    carries its own guidance, so there is no reference beside it to keep current, and the exception is gone
    with the thing it existed for.

    REFUSED IN A REPO THAT PUBLISHES PLUGINS (.claude-plugin/marketplace.json present). The source repo
    of this workflow arranges that folder by hand -- it is the product's home, not a consumer -- so
    scaffolding it there would write a layout over one its owner composed deliberately.
    AND ITS LAYOUT IS ITS OWN HOUSEKEEPING RATHER THAN THE MODEL, in one way worth knowing before
    copying it: the source has NO root CONTRIBUTING.md, keeping that floor in its CLAUDE.md instead
    (Dave, August 27, 2026), where CONTRIBUTING-portable.md recommends the root page and says why.

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
    try { . $repoConfig } catch { Write-Warning "scripts/repo-config.ps1 failed to load ($(Format-SafeProseToken -Value $_.Exception.Message)) -- the built-in wording is used." }
}
. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
# Get-SeamValue + the computed defaults (issue #885): this scaffold reads the SAME seam definitions the
# cut and the fold now read, so the paths this folder's own docs name can never disagree
# with where the workflow actually reads and writes.
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
# Get-WriteTargetReparsePoint (issue #2533): the two writes into files this repo already has -- the
# repo-config.ps1 seam append below and the CLAUDE.md import further down -- are refused when the file, or
# a directory between it and the repo root, is a symlink or junction, because the write would land outside
# the repo. Since #2540 the files this run CREATES are held to the same check, in the placement loop below.
. (Join-Path $PSScriptRoot '..\lib\write-target-lib.ps1')

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
    Write-Host 'The source arranges dkj-policy/ by hand, and its layout is its own housekeeping rather'
    Write-Host 'than the model: it keeps NO root CONTRIBUTING.md at all (Dave, August 27, 2026). Nothing'
    Write-Host 'was written.'
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
# history.md, NOT README.md -- and since #2196 this command writes no README.md in that folder at all,
# so the name is free. It is kept anyway, because the clash was never the only reason for it: history.md
# is the computed default every consumer adopted since #885 already resolves to, and moving a default
# renames a file under repos that never asked. The clash itself is recorded rather than erased --
# 'dkj-policy/releases/README.md' WAS this folder's seam-ANSWERS page, so a list a script appends to and a
# page somebody writes needed different names to share one directory. The answers page is retired now
# (see the legacy block below) and the list keeps the name it was given.
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
# A FOURTH CONDITION (issue #2533): repo-config.ps1 is not reached through a symlink or junction. Where it
# is, the seam is left unanswered and the instruction at the end of the run says how to answer it by hand.
$repoConfigReparse = if ($repoConfigExists) { Get-WriteTargetReparsePoint -Path $repoConfig -Root $repoRoot } else { $null }
$writeNoteRootSeam = (-not $noteRootAnswered) -and (-not $noteRootHasNotes) -and $repoConfigExists -and (-not $repoConfigReparse)
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

# THE ONE FILE THIS COMMAND PLACES OUTSIDE THE FOLDER, and it is deliberate (inbound #789). The branch
# entry is a convention the plugin ships every reader of, while nothing enforced it: open-pr refuses to
# push an unwritten entry and ship-pr refuses to merge on an unresolved step, but both are LOCAL, and a
# branch pushed by hand or a PR opened in the GitHub UI meets neither. Both existing consumers therefore
# wrote a CI gate from scratch, against the same convention, and both had already drifted from it. So the
# gate ships as a script and this places the few lines that call it (a caller since #2422). Precedent for a plugin placing a
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
#
# AND SINCE #2422 IT PLACES A CALLER, NOT THE RUNNER. Everything above argued for ONE definition of the
# check and then wrote the runner around it -- runner, both checkouts, the path, the ref and half a page
# of commentary -- into every consumer, once, where nothing corrected it afterwards. So the runner is a
# reusable workflow in the source now (.github/workflows/reusable-branch-entry.yml, `on: workflow_call`)
# and what lands here is the trigger and one `uses:` line. The `ref: main` argument travels with it
# unchanged: the caller names `@main`, and the reusable workflow checks the scripts out at `main` too.
# check-connectors' check 6 still sees the consumer, because consumer-runner-lib reads a `uses:` of a
# workflow in this repo as a reference into this tree, exactly as it reads a checkout step.
#
# NO timeout-minutes IN THE CALLER, and that is GitHub's rule rather than a gap: a job that calls a
# reusable workflow may carry only the keys a call takes, and timeout-minutes is not one. The cap lives in
# the called job, where workflow-timeouts.tests.ps1 holds it.
$entryGateWorkflow = @(
    '# Every PR into the trunk carries a WRITTEN changelog entry.',
    '#',
    '# The runner is not in this file: it is a reusable workflow in DKJ-Solutions/dkj-claude-plugins,',
    '# which runs check-branch-entry.ps1 -- the same two functions open-pr calls locally. One definition',
    '# of the gate, and a change to it reaches this repo without re-adopting. Its reasoning is written there.',
    '#',
    '# WHICH BRANCHES OWE NOTHING: answer Get-EntryGateExemptPrefixes in scripts/repo-config.ps1. It',
    '# defaults to ''sync'' -- a mirror branch carries somebody else''s work, so it has nothing to declare.',
    '#',
    '# @main IS DELIBERATE: a pinned gate enforces the shape it was pinned at, and the entry path has moved',
    '# twice. To pin, name a tag in `uses:` AND pass the same tag as `with: scripts-ref:`.',
    'name: Branch entry',
    '',
    '# pull-requests: read AND edited HOLD THE DEPLOY LOCK: the runner reads the PR body to refuse a DEPLOY',
    '# section changed since the PR opened, and edited lets it look again after open-pr -RefreshBody.',
    'permissions:',
    '  contents: read',
    '  pull-requests: read',
    '',
    'on:',
    '  pull_request:',
    '    types: [opened, synchronize, reopened, edited]',
    '    branches: [main]',
    '',
    'jobs:',
    '  branch-entry:',
    '    uses: DKJ-Solutions/dkj-claude-plugins/.github/workflows/reusable-branch-entry.yml@main'
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
# length, and since #2422 it is the same caller shape too: the runner is
# .github/workflows/reusable-always-on-budget.yml in the source, and check-connectors.ps1's check 6 reads
# the `uses:` line the way it reads a checkout step, so it still notices if that file moves.
$alwaysOnGateWorkflow = @(
    '# The always-on budget: a PR may not grow what every session pays before a single assignment is',
    '# given -- CLAUDE.md plus everything it ''@''-imports.',
    '#',
    '# The runner is not in this file: it is a reusable workflow in DKJ-Solutions/dkj-claude-plugins,',
    '# which runs check-always-on-budget.ps1 -- the same verdict open-pr reads locally and the session',
    '# hook reports at start. Its reasoning is written there.',
    '#',
    '# WHAT THE CEILING IS: answer Get-AlwaysOnBudget in scripts/repo-config.ps1, in BYTES. Unanswered,',
    '# it is 100,000. A repo already over it is held at a recorded baseline rather than refused.',
    '#',
    '# @main IS DELIBERATE, for the reason branch-entry.yml states. To pin, name a tag in `uses:` AND',
    '# pass the same tag as `with: scripts-ref:`.',
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
    '    uses: DKJ-Solutions/dkj-claude-plugins/.github/workflows/reusable-always-on-budget.yml@main'
)

# CHANGELOG.md (issue #885, group A): this folder's own pending-changes list, isolated from any
# CHANGELOG.md the consumer already keeps at their root -- the workflow never reads or writes that one
# again.
#
# IT CARRIES NO INTRO AT ALL (issue #2486, Dave, September 25, 2026). This used to scaffold a generic
# paragraph about the mechanism, and every repo then went on to write its own over it, so the head of
# one document said a different thing in every consumer. The head is now the fixed one
# (Get-ChangelogHeadLines in entry-scaffold-lib, dot-sourced above) -- the title and the pending heading,
# nothing else -- and the fold and the cut re-apply it, so what is scaffolded here is also what every
# later write leaves behind. The pending heading is last, so the first fold into this entry-less document
# appends beneath it (issue #1518).
$changelogIntro = @(Get-ChangelogHeadLines)

# THE SECOND FILE THIS COMMAND PLACES OUTSIDE THE FOLDER, and unlike the gate above it is a COPY rather
# than a few lines calling a shipped workflow (issue #1843). GitHub reads a PR template only from
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
$refused = 0
foreach ($t in $targets) {
    $abs = Join-Path $repoRoot ($t.Rel -replace '/', '\')
    # BEFORE the existence test (issue #2540): Test-Path follows a reparse point, so a dangling symlink at
    # the target reads as absent and the write below would create the link's target, and a junctioned
    # .github/ or dkj-policy/ would take the file outside the repo. Refused and reported, like #2533's two
    # writes into existing files.
    $reparse = Get-WriteTargetReparsePoint -Path $abs -Root $repoRoot
    if ($reparse) {
        $refused++
        Write-Host "  [refused] $($t.Rel) -- reached through a symlink or junction ($reparse), so writing it would land outside the repo; place it by hand" -ForegroundColor Yellow
        continue
    }
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

# --- Three pages this command NO LONGER WRITES (#2171 and #2196, Dave, September 20, 2026) ---------
# The folder's README.md and CONTRIBUTING.md went first (#2171), and releases/README.md followed the same
# day (#2196). All three are retired for one reason: a per-repo prose page beside a portable page made the
# consumer's own tree more complicated and produced more inconsistency than it removed. THERE IS ONE
# CONTRIBUTING FOR A CONSUMER TO READ and it is the plugin's CONTRIBUTING-portable.md; there is ONE
# RELEASES and it is RELEASES-portable.md. What a consumer's own repo answers goes into that repo's
# specialist lens, where the rest of its repo-specific answers already live -- one destination instead of
# two. The source repo did the same to its own three, and its release answers now sit in the release
# manager's and the system administrator's lenses, split by which of them owns the answer.
#
# WHAT WENT WITH THEM, so nobody restores half of it: the refreshable fenced block (#1766) and its four
# top-up states. That block existed because a page scaffolded once is never corrected afterwards, which is
# the right repair for a page the plugin OWNS -- and this change removes the page instead. It answers the
# same defect one level up rather than contradicting it, and the UPDATE chapter it carried belongs to
# whichever page that repo keeps its own answers on.
#
# THE RELEASE LIST IS NOT ONE OF THE THREE and is still not scaffolded, for the opposite reason: it is a
# document a script appends to, and the closing advice below is what tells a consumer to create it. A page
# a person writes and a file a script owns are different things, which is the whole of why they never
# shared a name.
#
# AN EXISTING COPY IS REPORTED AND NEVER TOUCHED, and no delete command is printed. Several consumers hold
# these pages today; a copy may carry the only written statement of something that repo answered, and
# nothing here can tell that from a stale scaffold. Printing a paste-ready delete would push a reader
# towards losing it for the sake of tidiness this command does not have to buy.
#
# THE GATES THAT READ THEM ARE DELIBERATELY UNCHANGED -- check-consumer-prose still runs its detectors
# over those names and check-policy-drift still lists them -- so a page that is still there keeps exactly
# the standing its repo gives it. What stopped is the AUTHORING, not the reading: a gate narrowed to match
# this change would retire itself in the five repos whose pages are the reason it exists.
$legacyPages = @(
    @("$workflowFolder/README.md", "$workflowFolder/CONTRIBUTING.md", "$workflowFolder/releases/README.md") |
        Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot ($_ -replace '/', '\')) -PathType Leaf }
)
if ($legacyPages.Count -gt 0) {
    foreach ($legacyPage in $legacyPages) {
        Write-Host "  [legacy]  $legacyPage -- this command no longer writes or refreshes it" -ForegroundColor Yellow
    }
    Write-Host '            One CONTRIBUTING and one RELEASES are the plugin''s portable pages; what THIS' -ForegroundColor DarkGray
    Write-Host '            repo answers belongs in its specialist lens. Nothing here deletes any of them and' -ForegroundColor DarkGray
    Write-Host '            keeping them is a complete answer -- but the plugin''s fenced block in the README' -ForegroundColor DarkGray
    Write-Host '            is frozen from now on, so read it as this repo''s own writing rather than as current.' -ForegroundColor DarkGray
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
} elseif ($repoConfigReparse) {
    Write-Host "  [refused]  Get-ReleaseNoteRoot left UNANSWERED -- scripts/repo-config.ps1 is reached through a symlink or junction ($repoConfigReparse), so writing it would land outside the repo" -ForegroundColor Yellow
} elseif ($noteRootHasNotes) {
    Write-Host "  [seam]     Get-ReleaseNoteRoot left UNANSWERED -- you already have notes at $noteRootFallback/" -ForegroundColor Yellow
} else {
    Write-Host '  [seam]     Get-ReleaseNoteRoot left unanswered -- this repo has no scripts/repo-config.ps1' -ForegroundColor Yellow
}

# --- The constitution import in CLAUDE.md (issue #2531) --------------------------------------------
# THE RULES THIS REPO RUNS UNDER ARRIVE THROUGH ONE '@'-LINE, AND THIS RUN WRITES IT. Until #2531 the line
# was an instruction on the skill page plus a session-start [WARNING], on the ground that this command
# "never edits a file that already exists" -- a ground the note-root seam above had already given up
# for scripts/repo-config.ps1 (#1150). Measured in dkj-etf-tracker: the line was never added, the
# warning fired at every session start for weeks, and a warning changes nothing a session KNOWS -- so the
# constitution's "by default, it does not wait" rule was never in context, and a finished PR sat
# unmerged until the owner asked why. A warning is the right tool for a line only a person can write;
# this line is the same for every consumer, so the adoption writes it.
#
# THE SAME DETECTOR THE WARNING USES, so the two can never disagree about whether the line is there:
# Test-ConstitutionImported over the '@'-import closure, which also counts the line when it sits in a
# file CLAUDE.md imports.
#
# THE WRITE ITSELF IS Add-ClaudeMdImportLine (claude-md-import-lib.ps1, #2532), shared with
# dkj-policy-bwj's adopt-extension-import.ps1 so the two adoptions cannot drift apart. It scans CLAUDE.md
# fence-aware (a line quoted in an example is neither "already there" nor a place to insert), inserts the
# line directly above the first '@'-import -- the constitution names its own import first and a companion
# extension on the line below it -- appends it when there is no import, and creates CLAUDE.md holding
# only this line when there is none. Not one existing byte changes: line endings, mixed or not, and a
# byte-order mark are kept. specialists-init appends the orchestrator import afterwards, as it does to
# any existing file.
. (Join-Path $PSScriptRoot '..\lib\consumer-check-lib.ps1')
$constitutionLine = Get-ConstitutionImportLine
$claudeMdPath     = Join-Path $repoRoot 'CLAUDE.md'
$constitutionElsewhere = (Test-Path -LiteralPath $claudeMdPath -PathType Leaf) -and
    (Test-ConstitutionImported -Documents @(Get-CheckProseCorpus -RepoRoot $repoRoot))
$constitutionAction = Add-ClaudeMdImportLine -Path $claudeMdPath -Root $repoRoot -Line $constitutionLine `
    -ImportedPattern '^\s*@\S*/plugins/dkj-policy/CLAUDE\.md\s*$' -ImportedElsewhere:$constitutionElsewhere -Apply:$Apply

switch ($constitutionAction) {
    'kept'   { Write-Host '  [keep]     CLAUDE.md already imports the dkj-policy constitution -- left as it is' -ForegroundColor DarkGray }
    'refused' { Write-Host "  [refused]  CLAUDE.md is a symlink or junction, so the constitution import was NOT written -- add it by hand: $constitutionLine" -ForegroundColor Yellow }
    'create' { $verb = if ($Apply) { '[created]' } else { '[create] ' }
               Write-Host "  $verb  CLAUDE.md, holding the constitution import: $constitutionLine" -ForegroundColor Green }
    default  { $verb = if ($Apply) { '[added]  ' } else { '[add]    ' }
               Write-Host "  $verb  the constitution import to CLAUDE.md: $constitutionLine" -ForegroundColor Green }
}

Write-Host ''
if ($Apply) {
    Write-Host "Done: $created file(s) created, $kept left as they were." -ForegroundColor Green
} else {
    Write-Host "Would create $created file(s); $kept already exist. Re-run with -Apply." -ForegroundColor Yellow
}
if ($refused -gt 0) {
    Write-Host "$refused file(s) refused -- reached through a symlink or junction; see the [refused] lines above." -ForegroundColor Yellow
}

# --- What only this repo can answer, said out loud rather than left to be discovered ---------------
# One 'decide' seam points the release machinery at the folder. Since issue #1150 this run ANSWERS it
# where it safely can -- see the seam block above for the three conditions -- so what is printed below
# is a report of what happened to it rather than an instruction in every case. Where it was left
# unanswered the cut keeps writing hand-written notes to the shared default at the repo root, which is a
# working state but not the one this folder is for.

# RE-ADOPTION MIGRATION NOTE (issue #885): the one transition this run cannot do for you, because it
# is prose in somebody else's file. Same shape as the migration advice the source repo's own
# releases/README.md used to carry ("if it carries a release list from before this split, move that
# list") -- that page is retired (#2196) and the advice it gave a re-adopting consumer lives on in the
# closing block below, which is where the run can actually print it.
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
Write-Host '  It is exactly this -- the fixed title, a section heading naming your first major, and a table'
Write-Host '  header under it:'
Write-Host ''
# The title is the one the cut re-applies (Get-ReleaseHistoryHeadLines, issue #2489), read rather than
# restated so the file this prints and the file the cut writes cannot disagree.
foreach ($headLine in @(Get-ReleaseHistoryHeadLines)) { Write-Host "    $headLine".TrimEnd() }
Write-Host '    #### 1.x'
Write-Host ''
Write-Host '    | Version | Date | Type | Title |'
Write-Host '    |---|---|---|---|'
Write-Host ''
Write-Host 'WRITE NOTHING ABOVE THAT SECTION HEADING: every cut replaces whatever sits there with the title'
Write-Host 'above (issue #2489), so every repo''s list reads the same. How the list works is on RELEASES-portable.md.'
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
