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
          README.md              what this folder is, where each page's portable half lives, and how
                                 to update the plugins in another checkout of this repo
          CONTRIBUTING.md        this repo's answers to CONTRIBUTING-portable.md, plus the session rules for
                                 this folder -- one page since #886, not two
          releases/README.md     this repo's answers to RELEASES-portable.md (the release LIST is a
                                 second file beside it, not this one; see the closing advice)
          (releases/audience/ is NOT placed -- the first cut creates it when it writes the note there)
          (<branch>.md is NOT placed -- one per branch, living only while that branch is open)

    AND IT ANSWERS ONE SEAM, FOR A FRESH ADOPTION ONLY (issue #1150). Get-ReleaseNoteRoot's shared
    fallback is 'releases/notes' at the repo root, and it deliberately does not move -- a repo that
    answers nothing must keep meaning what it meant yesterday. That argument is about a consumer who
    ALREADY has notes on disk, and it does not reach a repo this command scaffolded a minute ago: there
    the scaffolded docs named one destination while the cut wrote to another, so one clean adoption plus
    one clean release left the note outside the folder the adoption had just built. So where -- and ONLY
    where -- this repo defines no answer AND has no note of its own at that fallback, the run writes the
    answer into scripts/repo-config.ps1 rather than printing it as an instruction. Any repo with notes
    already at the fallback keeps them and is told what to do instead; nothing is ever moved.

    AND TWO FILES OUTSIDE IT (inbound #789; issue #1843):

        .github/workflows/branch-entry.yml   the CI gate that holds every PR to carrying a written
                                             entry, by calling the shipped check-branch-entry.ps1
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

    WITH ONE BOUNDED EXCEPTION, AND IT IS ADDITIVE TOO: the UPDATE section of the folder README. Create-
    when-absent is right for a page the repo then writes in, and it is also why a section added to this
    scaffold LATER reaches an already-adopted repo not at all -- "right owner, wrong reach", the shape
    recorded for PR #734 and stated for CLAUDE.md below. That section carries a marker comment, so this
    run can recognise it, APPEND it once when it is missing, and never touch anything else in the file.
    It is bounded to one append at the end of one file, in the folder Get-WorkflowFolderName says this
    repo actually has; nothing is read back beyond the marker test, and nothing is ever rewritten.

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
$repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (git rev-parse --show-toplevel).Trim() }


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
# How the folder README names it: folder-relative while it is inside the folder, and repo-root-relative
# with the fact said out loud while it is not -- a reader of that page is standing in the folder.
$noteRootDisplay = if ($noteRootRelPath -eq $workflowFolder -or $noteRootRelPath.StartsWith("$workflowFolder/")) {
    '`' + $noteRootRelPath.Substring([Math]::Min($workflowFolder.Length + 1, $noteRootRelPath.Length)) + '/`'
} else {
    '`' + $noteRootRelPath + '/` at your repo root'
}

# --- What the folder contains ---------------------------------------------------------------------
# One list, each entry a repo-relative path plus the content it gets WHEN ABSENT. The docs name their
# portable halves in code rather than linking them, the same choice DEVELOPMENT-portable.md explains: the
# portable pages live in the plugin install, and a relative link into a plugin cache is a path that is
# wrong on every machine but this one.

# --- The UPDATE section, and the plugin ids it names ----------------------------------------------
# WHY IT IS SCAFFOLDED AT ALL: the two update commands are per-CHECKOUT, and nothing in a session reports
# that this one is behind. A consumer holding the workflow on two machines has no page of their own that
# says so -- the measurements live in the family's INSTALL.md, one repo away from the plugin they
# installed -- so the folder index is where it belongs, beside the seam answers a session already reads
# here.
#
# THE IDS ARE READ, NOT ASSUMED. check-report-lib is dot-sourced GUARDED, the idiom this script already
# uses for the source-repo guard: without the lib the section still scaffolds, naming the SHAPE of the
# command instead of this repo's own ids. A page printing a command a reader can paste is worth the read;
# a page printing a WRONG id is worse than one printing a placeholder, which is why the fallback is the
# placeholder rather than a guess at what this repo enabled.
$updateIds = @()
$updateMarketplace = ''
$reportLib = Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1'
if (Test-Path -LiteralPath $reportLib -PathType Leaf) {
    try {
        . $reportLib
        if (Test-FunctionDefined 'Get-EnabledPlugins') {
            # RepoEnabledIds, not Ids: an enable arriving from the machine layer is not this repo's to
            # document, and a scaffolded page claiming it would be describing somebody's laptop.
            $updateIds = @((Get-EnabledPlugins -RepoRoot $repoRoot).RepoEnabledIds | Where-Object { $_ -like '*@*' })
        }
    } catch {
        Write-Warning "the enabled-plugin list could not be read ($($_.Exception.Message)) -- the UPDATE section is scaffolded with placeholders."
    }
}
if ($updateIds.Count -gt 0) { $updateMarketplace = ($updateIds[0] -split '@', 2)[1] }
$updateRefreshLine = 'claude plugin marketplace update ' +
    $(if ($updateMarketplace) { $updateMarketplace } else { '<marketplace>' }) +
    '   # 1. refresh the cached clone first'
$updateCommandLines = if ($updateIds.Count -gt 0) {
    @($updateIds | ForEach-Object { 'claude plugin update ' + $_ + ' --scope project' })
} else {
    @('claude plugin update <plugin>@<marketplace> --scope project   # 2. one line per plugin you enabled')
}

# THE MARKER IS WHAT MAKES THIS SECTION TOP-UP-ABLE, and that is the whole reason it has one. Every other
# file here is placed once and never touched again, which is right for a page a repo then writes in -- and
# it also means a section added to this scaffold later reaches an already-adopted repo NOT AT ALL: the
# "right owner, wrong reach" shape recorded for PR #734, and stated for CLAUDE.md further down. A marker
# plus a section-level append is the narrowest answer that closes it: nothing existing is read back,
# rewritten or merged, which is exactly the rule the note-root seam answer below appends under.
#
# AND SINCE #1766 IT IS A FENCED REGION RATHER THAN A ONE-SHOT APPEND, which is the second bounded
# exception to "never rewrites" and the only one. The append closed "a section added later never
# arrives"; it did not close "a section that arrived is never CORRECTED", and the second half is what a
# consumer actually reported. Their folder README still named the branch document `development.md` and
# still carried two pre-rename plugin ids -- because everything in this block is generated from the
# arrays below. It is the plugin's own writing, sitting in a file the plugin had promised never to touch
# again, with no way to correct it and no way for the reader to tell whose sentence had gone stale.
#
# WHAT THE FENCE BUYS, AND WHAT IT DELIBERATELY DOES NOT. Content BETWEEN the two markers is the
# plugin's and is replaced on every -Apply; everything outside them is the repo's and is never read. So
# the surface #1766 asks for -- a block identical in every consumer, kept current -- costs one closing
# marker rather than a vendored copy of the portable pages in every repo. It is NOT a licence to rewrite
# a page this scaffold did not fence: an opening marker with NO closing one is a section from before
# #1766, possibly edited since, and it is left exactly as it is and REPORTED. The write block further
# down answers all four states.
#
# THE TWO SHAPES #1766 PROPOSED ARE BOTH DECLINED, with reasons rather than by preference. A vendored
# `HELP/` subtree (its shape 1) duplicates ~203 KB of portable prose into every consumer and reverses
# this file's governing rule outright -- and it repeats the defect #664 closed, publishing plumbing to an
# audience that cannot act on it. A separate pointer page (its shape 2) duplicates what the intro above
# already says, which creates a second drift surface inside one folder: the exact complaint. Neither
# repairs the staleness that was measured, because both leave the stale README standing.
$updateSectionMarker    = '<!-- dkj-policy:update-section -->'
$updateSectionEndMarker = '<!-- /dkj-policy:update-section -->'
$folderReadmeUpdate = @(
    '',
    $updateSectionMarker,
    '## The `dkj-policy` workflow',
    '',
    '**Everything between the two markers around this block is the plugin''s writing, and a re-run of the',
    '`adopt-dkj-policy` skill (Part 1) replaces it.** Write outside it -- above the block or below it --',
    'and your words are never read or touched. To own these paragraphs yourself instead, delete the two',
    'marker comments: the block becomes ordinary text in your file and no run will write it again.',
    '',
    'The conventions this workflow runs on do not live in this repo. They travel with the plugin as three',
    'portable pages -- `CONTRIBUTING-portable.md`, `DEVELOPMENT-portable.md` and `RELEASES-portable.md` --',
    'and every page in this folder beside them is *your* answers to one of them. They are named here in',
    'code rather than linked because the path to your plugin install differs per machine; ask your Claude',
    'for the `adopt-dkj-policy` skill, or read them in the source repo.',
    '',
    '### Which version am I running?',
    '',
    'Run `/dkj-policy:plugin-versions`. **The answer is a command rather than a number written here,',
    'because a plugin version is a property of the (plugin, checkout) pair** -- recorded per machine and',
    'keyed on this checkout''s folder path, so one repo can sit on two different versions on two machines',
    'at once. A number committed into this file would be correct for at most one clone and stale',
    'everywhere else, while reading as authoritative.',
    '',
    '## Updating the plugins',
    '',
    'A release ANNOUNCES a new version; nothing delivers it. From this repo''s root:',
    '',
    '```powershell',
    $updateRefreshLine
) + $updateCommandLines + @(
    '```',
    '',
    'Then **restart the session** -- a skill or a hook that arrived with the update is not in a session',
    'that started before it.',
    '',
    '**`plugin-versions` tells you, per machine, whether that pair is even due.** This plugin ships it as',
    'a skill: one read-only run in this checkout prints, per enabled plugin, the version and commit this',
    'checkout installed against the marketplace clone''s version and HEAD, with a verdict -- up to date,',
    'update this plugin, or refresh the clone -- and the command for each. It reads the clone this',
    'checkout already holds, so it cannot tell you whether that clone itself trails `origin`.',
    '',
    '**Both things those commands touch are per-checkout state, and nothing in a session reports it.** The',
    'marketplace is a cached git clone, and the install record is keyed on this checkout''s **folder path**.',
    'So a version picked up on one machine changes nothing in the next checkout -- another machine, a',
    'colleague''s clone of this repo, a second checkout beside this one -- while the workflow there keeps',
    'working at whatever version it last installed. Every checkout runs the pair itself, and renaming or',
    'moving one unlinks its install record with no error.',
    '',
    '**Neither part of the pair is optional.** Without the refresh an `install` was measured serving the',
    '*previous* version; without `--scope project` the command looks in user scope and does not act on a',
    'project-scoped install at all. Both measurements, and why the version number is not the code you are',
    'running, are in the family''s `INSTALL.md` under *Staying up to date* -- in your plugin install or in',
    'the source repo.',
    '',
    '**And an update can leave this repo owing the newer scripts an answer.** They dot-source',
    '`scripts/repo-config.ps1` and `scripts/lib/branch-info.ps1` from here, so a newer version can call a',
    'function this repo has never had; `script-contract-sessioncheck` names it at the next session start,',
    'and the `adopt-dkj-policy` skill''s Part 2 fills it in.',
    '',
    'Placed and kept current by that skill''s Part 1: it writes this block when the markers are missing',
    'and replaces what sits between them when they are present, so a correction to any sentence above',
    'reaches this repo on the next run. **The rest of the page is yours and is never read** -- and if you',
    'want these paragraphs too, delete the two markers and they stop being the plugin''s.',
    $updateSectionEndMarker
)

$folderReadme = @(
    '# `dkj-policy/` -- the workflow''s own folder in this repo',
    '',
    'Everything portable about the `dkj-policy` workflow gathers here, so the workflow occupies',
    'one folder in this repo''s root instead of scattering through it. The conventions themselves travel',
    'with the plugin as portable pages, readable in your plugin install or in the source repo. There are',
    'three -- `CONTRIBUTING-portable.md`, `DEVELOPMENT-portable.md` and `RELEASES-portable.md` -- and each',
    'page in this folder is this repo''s own set of answers to one of them. Ticket work -- the layer before',
    'a branch, in a repo whose work arrives from somebody else''s tracker -- is step 1 of the first of',
    'those; skip that section if nothing reaches you that way.',
    '',
    '| here | what it holds |',
    '|---|---|',
    '| [`CONTRIBUTING.md`](CONTRIBUTING.md) | this repo''s answers to the contribution cycle |',
    '| `<branch>.md` | the branch''s own document, one per branch and present only while that branch is open: its plan, and the DEPLOY section that folds into the changelog |',
    '| [`CHANGELOG.md`](CHANGELOG.md) | this folder''s own pending-changes list, isolated from any changelog you already keep at your repo root |',
    # The third item is conditional for the same reason the sentence further down is (issue #1150): the
    # hand-written notes are only in this folder where the note-root seam points into it, and claiming
    # them here regardless is how a scaffolded page ends up describing a tree the repo does not have.
    ('| [`releases/`](releases/) | this repo''s release answers, the release LIST' + $(if ($noteRootRelPath.StartsWith("$workflowFolder/")) { ' and the published audience notes' } else { ' (the hand-written notes are at `' + $noteRootRelPath + '/`, outside this folder)' }) + ' |'),
    '',
    'Scaffolded by the `adopt-dkj-policy` skill (Part 1); strictly additive, so everything here past the',
    'VUL-IN markers is this repo''s own writing.'
) + $folderReadmeUpdate

# ONE PAGE SINCE AUGUST 26, 2026 (#886), WHERE THERE WERE TWO. This array used to have a sibling,
# $folderClaude, scaffolding a CLAUDE.md beside it: one page layered over the consumer's root
# CONTRIBUTING.md and the other over their root CLAUDE.md, and each said so about itself. Dave merged the
# source repo's pair for that reason -- "that should be the center of this folder" -- so the scaffold
# follows, and the session rules that lived in the other page are folded in below.
#
# AN EXISTING ADOPTER KEEPS THEIR CLAUDE.md, and that is not a gap to repair here. This scaffold never
# overwrites, so a consumer who already ran it has both files and this change reaches them not at all --
# the "right owner, wrong reach" shape the technical writer's lens records for PR #734. Removing their
# file is theirs to do; nothing here breaks while they have it.
$folderContributing = @(
    '# Contributing -- the workflow''s layer, and the centre of this folder',
    '',
    'This page sits ON TOP of your repo''s own root `CONTRIBUTING.md` AND its root `CLAUDE.md`. Those two',
    'describe what holds in your repo whether or not this plugin is installed; this one carries the',
    'workflow''s own mechanics, and where they disagree this page wins. Keeping them apart is what makes an',
    'uninstall a folder you remove rather than an operating guide you untangle.',
    '',
    'The contribution cycle itself -- a branch, its development document, the PR gates, the significance model --',
    'is the plugin''s `CONTRIBUTING-portable.md`, which travels with `dkj-policy` and is not',
    'restated here. This page holds only what the portable half leaves to each repo.',
    '',
    '## The rules a session needs in this folder',
    '',
    '- `<branch>.md` belongs to the **branch it is named after**, and exists only while that branch is open. One per branch since #1255 and named after the branch alone since #1335: a shared name collided on every merge, and a conflicting pull request gets no check suite at all.',
    '  `new-branch` creates it, the fold removes it at the merge, so the trunk carries no copy -- if you',
    '  are looking at this folder and the file is not there, that is the trunk in its normal state.',
    '- **Four `##` headings and never a fifth** -- PLAN, CREATE, TEST, DEPLOY are its whole top level, and',
    '  a section needing its own heading goes in as a `###` under whichever of the four owns it. Nothing',
    '  branch-specific belongs above `## PLAN` either: that region is the scaffolder''s generic guidance,',
    '  identical in every branch document. No gate reads a heading, so both are on you.',
    '- **PLAN / CREATE / TEST** carry the steps, and they gate the PR and the merge (`- [x]` done,',
    '  `- [~]` dropped with the reason on the line). The fourth phase, the DEPLOY section, IS the changelog',
    '  entry: it folds **verbatim** into `CHANGELOG.md` at the merge, so write its links relative to the',
    '  repo ROOT rather than to this folder. A checkbox inside that section is prose, not a step, and no',
    '  gate reads it as one.',
    '- The HTML comments in it are the form, not somebody''s notes: they say what a good answer looks',
    '  like, and the fold strips them on the way to `CHANGELOG.md`. Leaving one standing is not a defect.',
    ('- **`CHANGELOG.md` here is this folder''s own** -- isolated from any `CHANGELOG.md` you already keep'),
    '  at your repo root, which this workflow never reads and never writes. A change may end up recorded',
    '  in both, in each one''s own shape; that duplication is accepted rather than resolved, so the',
    '  plugin never has to guess at the shape of a file it does not own.',
    ('- `releases/README.md` here states this repo''s release ANSWERS, and is NOT the release LIST.'),
    ('  That list is the separate `' + $historyRelPath + '`, where the cut inserts one row per release --'),
    '  a history that stays with the repo that cut it, and the one document here that nothing scaffolds:',
    '  see this command''s closing advice for what it has to contain before your first cut. A row added by',
    ('  hand to `releases/README.md` is a row the cut will never see. ' + $noteRootDisplay + ' is where'),
    '  the cut drafts the hand-written note -- it appears at the first cut that writes one, since git',
    '  tracks no empty directory; `releases/changelog/`, `releases/github/` and `releases/internal/`',
    '  hold the generated documents.',
    '',
    '## Specific to this repo',
    '',
    '<!-- VUL-IN: this repo''s answers. The seam values in force (branch prefixes, trunk name, audience',
    '     tier, merge method, note root), who approves what, and anything the portable cycle leaves',
    '     open. scripts/repo-config.ps1 is where the machine-read answers live; this page is the prose',
    '     for a person. -->'
)

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
    @{ Rel = '.github/workflows/branch-entry.yml'; Content = (($entryGateWorkflow -join $nl) + $nl) }
) + $prTemplateTargets + @(
    @{ Rel = 'dkj-policy/README.md';           Content = (($folderReadme -join $nl) + $nl) },
    @{ Rel = 'dkj-policy/CONTRIBUTING.md';     Content = (($folderContributing -join $nl) + $nl) },
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
# Counted separately from $created because it is a different ACT: the loop below creates files that were
# absent, and the block after it appends a section to a file that was already there.
$toppedUp = 0
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

# --- The one section this run tops up in a file it did NOT create ---------------------------------
# THE ONLY PLACE THIS COMMAND WRITES INTO AN EXISTING PAGE, and it is bounded to one append at the end
# of one file. Everything above is create-when-absent, which is right for a page the repo then writes in
# -- and it is also why a section added to this scaffold later reaches an already-adopted repo not at all.
# The marker makes the narrow answer possible: recognise the section, append it once when it is missing,
# and never look at anything else in the file.
#
# THE FOLDER IS THE ONE THIS REPO ACTUALLY HAS, not the name $targets scaffolds. Get-WorkflowFolderName
# prefers whichever folder is on disk, newest name first, and every seam default is composed from its
# answer -- so a repo still holding a folder under one of this workflow's earlier names reads THAT page,
# and topping up the name it does not use would put the section where nobody looks.
#
# FOUR STATES SINCE #1766, WHERE THERE WERE THREE, and the new one is the pre-fence page. Read in the
# order below, because two of them are told apart only by the CLOSING marker:
#   1. no page              -- the loop above already reported it; this block says nothing
#   2. BOTH markers         -- the block between them is the plugin's; -Apply replaces it
#   3. opening marker only  -- a section from before #1766, possibly edited since. LEFT ALONE, reported
#                              with the one thing the reader can do about it
#   4. neither marker       -- appended, exactly as before
#
# STATE 3 IS THE WHOLE REASON THE FENCE IS SAFE, so it is not a fallback. A page carrying the old
# unfenced section has no machine-readable end: replacing "from the marker to the end of the file" would
# take everything the repo wrote below it, and this command has never had permission to do that. There is
# no heuristic worth guessing with here -- the honest answer is to say the page predates the fence and
# name the two-character edit that opts in. That keeps "nothing is ever rewritten" true of every page
# this scaffold did not itself fence.
#
# THE REPLACE IS STILL NOT A MERGE, and reads back only what it must. State 2 reads the file once, cuts
# on the two markers, and writes head + fresh block + tail with the same UTF-8-no-BOM encoder the append
# uses -- so a re-encode reaches only a file this command already owns a region of. States 3 and 4 keep
# AppendAllText and the marker test, for the encoding reason the seam answer below states.
#
# EVERY BRANCH PRINTS. "Your page already has it" has to be distinguishable from "nobody looked" -- the
# whole failure this block exists for was silent by construction. Since #1766 that has a third value:
# "it is here and it was brought up to date" is a different fact again, and a run that quietly refreshed
# a page would be the same silence wearing the opposite face.
$folderReadmeRel = "$workflowFolder/README.md"
$folderReadmeAbs = Join-Path $repoRoot ($folderReadmeRel -replace '/', '\')
if (-not (Test-Path -LiteralPath $folderReadmeAbs -PathType Leaf)) {
    # Either it was just created with the section in it, or this repo has no such page at all. Both are
    # already reported by the loop above, so this block says nothing.
} elseif ((Get-Content -LiteralPath $folderReadmeAbs -Raw) -match [regex]::Escape($updateSectionEndMarker)) {
    # STATE 2 -- fenced. The end marker is what is tested, because a fenced page carries BOTH and a
    # pre-fence page carries only the opening one: testing the opening marker cannot tell them apart.
    $existingReadme = [System.IO.File]::ReadAllText($folderReadmeAbs)
    $startIdx = $existingReadme.IndexOf($updateSectionMarker)
    $endIdx   = $existingReadme.IndexOf($updateSectionEndMarker)
    if ($startIdx -lt 0 -or $endIdx -lt $startIdx) {
        # A closing marker with no opening one before it. Nothing here knows where the block begins, so
        # nothing here may cut -- the same reasoning as state 3, reached from the other side.
        Write-Host "  [section] $folderReadmeRel carries a closing marker with no opening one -- left as it is" -ForegroundColor Yellow
        Write-Host "            repair the pair by hand, or delete both markers to own the block yourself." -ForegroundColor DarkGray
    } else {
        $head = $existingReadme.Substring(0, $startIdx)
        $tail = $existingReadme.Substring($endIdx + $updateSectionEndMarker.Length)
        # THE PAGE'S OWN LINE ENDINGS, not this script's $nl (inbound #1829). Everything else here is
        # composed with $nl -- pure LF -- which is right for a file this run CREATES, and wrong for the
        # one file it compares against: $existingReadme is read byte-exact, so on a page checked out CRLF
        # every single line of the composed block differs from the identical committed line, the compare
        # below always fails, and the verdict reads 'drifted' on every fresh checkout. That is the whole
        # value of the verdict gone -- a genuinely stale block reads the same as a current one. #788 is
        # the same failure in a different check ('the drift read cries wolf 37 times out of 37'): a
        # verdict that fires every time carries no information, whichever reader it is written for.
        #
        # AND -Apply MADE IT WORSE RATHER THAN REPAIRING IT. The rewrite kept head and tail untouched
        # (they are substrings) and wrote the fresh block LF, leaving a MIXED file: measured on a fixture
        # page, 19 CRLF above and below an all-LF block. Under core.autocrlf=true git normalises that
        # back to the committed content, so `git diff` came up empty and the second dry run then said
        # 'already carries the current block' -- the defect repairing its own symptom while leaving the
        # page in a state nobody wrote. Without autocrlf it is a whole-file whitespace diff instead.
        #
        # SO THE STYLE IS READ OFF THE PAGE, through the same helper release-lib.ps1 and pr-body-lib.ps1
        # read it with on the documents they edit in place. Both halves follow from one reading: the
        # compare stops seeing a difference that is not there, and the write stops introducing one. The
        # reading was hand-typed here and at eight other sites until #1832 gave it one definition;
        # document-newline-lib.ps1's banner carries the whole-file limit of it, which is accepted rather
        # than overlooked and is the same in every caller.
        $pageNl = Get-DocumentNewline -Content $existingReadme
        # The block is composed with its own leading blank line, so the head is trimmed of trailing
        # newlines to keep a re-run from growing the gap above it by one line every time.
        $fresh = (($folderReadmeUpdate -join $pageNl).TrimStart("`r", "`n"))
        $rebuilt = $head.TrimEnd("`r", "`n") + $pageNl + $pageNl + $fresh + $tail
        if ($rebuilt -eq $existingReadme) {
            Write-Host "  [section] $folderReadmeRel already carries the current block -- nothing to do" -ForegroundColor DarkGray
        } elseif ($Apply) {
            [System.IO.File]::WriteAllText($folderReadmeAbs, $rebuilt, $Utf8NoBom)
            $toppedUp++
            Write-Host "  [topped]  $folderReadmeRel -- the plugin's block was brought up to date" -ForegroundColor Green
        } else {
            $toppedUp++
            Write-Host "  [top up]  $folderReadmeRel -- the plugin's block has drifted; it would be replaced" -ForegroundColor Green
        }
    }
} elseif ((Get-Content -LiteralPath $folderReadmeAbs -Raw) -match [regex]::Escape($updateSectionMarker)) {
    # STATE 3 -- the pre-fence section. It has no end, so it is not ours to cut.
    Write-Host "  [section] $folderReadmeRel carries the UPDATE section from before it was fenced -- left as it is" -ForegroundColor DarkGray
    Write-Host "            to take the current block, delete the '$updateSectionMarker' line and its section, then re-run." -ForegroundColor DarkGray
} elseif ($Apply) {
    $existingReadme = [System.IO.File]::ReadAllText($folderReadmeAbs)
    # STATE 4 TAKES THE SAME READING, for the write half of #1829 rather than the compare half. There is
    # nothing to compare here -- an append has no verdict to get wrong -- but appending an LF block to a
    # CRLF page leaves exactly the mixed file state 2 was leaving, in the one branch that puts the block
    # into a page this command has never touched before. A consumer's FIRST adoption is the worst moment
    # to do that, so it reads the style off the page for the same one-line cost.
    $pageNl = Get-DocumentNewline -Content $existingReadme
    $readmeAppendix = (($folderReadmeUpdate -join $pageNl) + $pageNl)
    if ($existingReadme.Length -gt 0 -and -not $existingReadme.EndsWith("`n")) { $readmeAppendix = $pageNl + $readmeAppendix }
    [System.IO.File]::AppendAllText($folderReadmeAbs, $readmeAppendix, $Utf8NoBom)
    $toppedUp++
    Write-Host "  [topped]  $folderReadmeRel -- the plugin's block was appended" -ForegroundColor Green
} else {
    $toppedUp++
    Write-Host "  [top up]  $folderReadmeRel -- has no plugin block; it would be appended" -ForegroundColor Green
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
    Write-Host "Done: $created file(s) created, $kept left as they were$(if ($toppedUp) { ", $toppedUp section(s) topped up" })." -ForegroundColor Green
} else {
    Write-Host "Would create $created file(s)$(if ($toppedUp) { ", top up $toppedUp section(s)" }); $kept already exist. Re-run with -Apply." -ForegroundColor Yellow
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
