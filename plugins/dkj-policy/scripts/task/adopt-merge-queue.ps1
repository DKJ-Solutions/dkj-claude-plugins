<#
.SYNOPSIS
    The CI floor, in a consuming repo: place the two runners that keep the fold and the resolves
    verification alive across a merge this session never observes, report whether a required status
    check exists at all -- the one detect-and-rebase reads -- and, for a repo that has CHOSEN a merge
    queue, print the ruleset command WITHOUT running it. Issues #1516, #1546.

.DESCRIPTION
    A MERGE QUEUE IS NO LONGER THIS WORKFLOW'S POLICY (Dave, September 7, 2026, #1546). It was, from
    September 6 (#1492) -- and the policy was set in the one repo where its central constraint cannot
    be felt. GitHub offers merge queue on a PRIVATE repo only under Enterprise Cloud, and otherwise
    only on a PUBLIC repo owned by an organization; on Free, Pro or Team it HIDES the 'Require merge
    queue' checkbox rather than disabling it. This workflow's source repo is public on plan 'free', so
    it qualifies through the public clause while most consumers do not -- and this script reported that
    unreachable setting as a closable '[gap]', sending its reader through the ruleset UI after a
    control that is not rendered (#1540, measured in BWJ-Development/smartwatchbanden: private, plan
    'team', the whole floor built before the missing checkbox surfaced).

    SO THE STANDING MECHANISM IS DETECT-AND-REBASE, which every repo can run. ship-pr dates a PR's
    certificate from the run behind a REQUIRED check, counts what the trunk gained after it, and
    refuses the merge when that is not zero. It converges by repetition rather than by construction --
    bring the branch forward, CI re-runs, ship again -- which is weaker than a queue and available.

    WHICH MOVES THE ONE GAP THAT MATTERS. With no required check named, ship-pr says so and skips the
    step, so the staleness guard is simply off. That is now this script's headline finding, where it
    used to read as a precondition for a switch a reader might never be able to flip.

    THE TWO RUNNERS ARE EVERY REPO'S, QUEUE OR NO QUEUE, and this is the half most easily mis-read as
    queue machinery. What breaks the fold is a merge THE SHIPPING SESSION DOES NOT OBSERVE, and the
    GitHub UI merge button produces one in every repo on earth. A queue only makes it the normal case.

      1. THE MERGE. Under a queue `gh pr merge` does not merge -- gh's own help: "When targeting a
         branch that requires a merge queue ... the pull request will be added to the merge queue."
         ADDED, exit 0, not merged. ship-pr handles this already (#1506): it reads the trunk's rules
         before it merges and, where it finds a queue, enqueues, ends successfully, and folds nothing.
         That half travels with the plugin, so it is true in every consumer the day they install it and
         this script does not have to place it.

      2. THE FOLD. It ran from exactly one place -- ship-pr's own next step after its own merge call
         returned. Any merge that session does not observe skips it: a queue merge, and equally a PR
         merged from the GitHub UI by anybody at all. The branch document then sits on the trunk
         unfolded, with CHANGELOG.md never receiving the entry and a release cut in that window missing
         the change. The source repo answered it with .github/workflows/fold-on-merge.yml (#1493,
         #1507). A consumer has no such file, and nothing tells them: ship-pr's enqueue arm PROMISES one.

      3. THE RESOLVES VERIFICATION. verify-resolved-issues.ps1 is ship-pr's step 6, and it went the
         same way for the same reason (#1511). The closing itself is not at risk -- GitHub honours a
         body's keywords on any merge -- but the verification is, and so is the repair when a keyword
         missed, which is the case the script was built for.

    AND ONE PREREQUISITE BELONGS TO THE QUEUE ALONE (#1325): every workflow carrying a REQUIRED check
    context must trigger on `merge_group`. A required workflow without it never runs for a queue entry,
    so its check never reports -- and GitHub's own warning is that the merge then fails. That is a TOTAL
    MERGE OUTAGE on the trunk, not a degradation, and it is invisible until the first merge after the
    switch. In a repo with NO queue it is inert, so leaving it out costs nothing -- which is why it is
    reported as a gap only where a queue is actually active.

    DO NOT CONFUSE IT WITH THE REQUIRED CHECK ITSELF, because the two point opposite ways. Making a
    check required is every repo's business and turns detect-and-rebase on. Adding merge_group to it is
    a queue repo's business and does nothing anywhere else. A consumer who follows the second without
    the first has done work for a queue they do not have.

    AND THE PLUGIN'S OWN branch-entry GATE CANNOT BE THAT REQUIRED CHECK (#1538). It reads
    github.head_ref, which is empty in a merge_group event -- there is no pull request left to read --
    so it stays a pull-request check. The source repo requires its own lint-en-tests instead, a
    repo-owned workflow triggering on both pull_request and merge_group; that arrangement is right and
    was nowhere written down, so a consumer could not reach it by reading. This script now says it.

    SO THE ORDER MATTERS AND THIS SCRIPT KEEPS IT: report the required check and the trigger first, then
    the runners, and the queue last. A run that placed the queue first would be the outage.

    IT NEVER FLIPS THE SETTING, AND THAT IS A RULE RATHER THAN A LIMITATION. A ruleset is a
    repo-settings change: irreversible in the sense that matters (it changes what every contributor's
    merge does, immediately, for everybody) and outward-facing. This workflow's own constitution puts
    that class in the owner's hands, so the run composes the exact `gh api` call and stops. Reading the
    rules needs only a token that can read them; writing them needs one that can administer the repo,
    and a script that quietly held the second would be a different kind of tool.

    STRICTLY ADDITIVE, NEVER OVERWRITES, DRY RUN BY DEFAULT -- the same three properties
    adopt-workflow-folder and adopt-config are trusted on, and for the same reason: the first run of a
    command that adds files to your repo should show you the list. A workflow file that is already
    there is left exactly as it is, whatever it contains.

    REFUSED IN THE REPO THAT PUBLISHES THIS WORKFLOW. The source arranges its own runners by hand --
    they are the originals these are derived from, they call its in-repo scripts rather than a
    checked-out mirror, and its fold runner holds a credential decision no scaffold should assert on
    somebody's behalf. Same refusal, same reasoning and the same test (Test-IsWorkflowSourceRepo) as
    adopt-workflow-folder's.

    RUN IT FROM THE ROOT OF THE CONSUMING REPO:

        powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-merge-queue.ps1"
        powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-merge-queue.ps1" -Apply

    Exit 0 while the queue is off and the floor is merely unbuilt -- that is a to-do, not a defect.
    Exit 1 when the queue is ACTIVE on the trunk and a piece of the floor is missing, because that is a
    live defect: entries are being stranded, or merges are about to stop.

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER Apply
    Write the runner workflows this repo does not have. Without it the command is a DRY RUN that prints
    exactly what it would create and touches nothing.

.PARAMETER RulesJsonOverride
    A file holding a `gh api repos/<repo>/rules/branches/<trunk>` payload, read instead of calling gh.
    For the test suite, which has to reach the queue-is-active arm without a network or a trunk. A
    consumer never types it.

.EXAMPLE
    .\scripts\task\adopt-merge-queue.ps1
    .\scripts\task\adopt-merge-queue.ps1 -Apply
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$RulesJsonOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Dual-context repo root: a consumer running the plugin mirror gets it from CLAUDE_PROJECT_DIR, the
# source's root copy falls back to the git root. Same resolution as every other mirrored script.
$repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (git rev-parse --show-toplevel).Trim() }

# repo-config.ps1 first and optional, exactly as adopt-workflow-folder loads it: it supplies the repo
# slug (Get-RepoName) and any trunk override, and every read below has a fallback.
$repoConfig = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
    try { . $repoConfig } catch { Write-Warning "scripts/repo-config.ps1 failed to load ($($_.Exception.Message)) -- the built-in defaults are used." }
}

. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# THE SOURCE OF *THIS* WORKFLOW arranges its runners by hand -- see the header -- so this command
# refuses there. Below the dot-sources because the test lives in seam-lib, and still before anything is
# written: loading a lib changes nothing on disk.
if (Test-IsWorkflowSourceRepo -RepoRoot $repoRoot) {
    Write-Host 'REFUSED: this repo publishes this workflow, so it is its source rather than a consumer.' -ForegroundColor Red
    Write-Host 'Its fold-on-merge.yml and verify-resolved.yml are the ORIGINALS these are derived from:'
    Write-Host 'they call its in-repo scripts rather than a checked-out mirror, and the fold runner carries'
    Write-Host 'a push-credential decision no scaffold should make on somebody else''s behalf. Nothing was'
    Write-Host 'written.'
    exit 1
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$nl = "`n"

# THE TRUNK IS READ, NOT ASSUMED. Every string below names it -- the workflow triggers, the rules
# endpoint, the ruleset payload -- and a repo that renamed its trunk would otherwise be handed a floor
# built for a branch it does not have. Get-BranchTrunkName reads the optional Get-TrunkBranchName seam
# and falls back to 'main'.
$trunk = Get-BranchTrunkName

# THE SOURCE OF THE SHARED SCRIPTS the placed runners call. Both files check the plugin's own tree out
# beside the consumer's, exactly as adopt-workflow-folder's branch-entry.yml does, and for the same
# reason: there is ONE definition of the fold and of the resolves check in this system, and a runner
# that carried a hand-written copy would be a second one, free to drift from the first.
$sharedRepo = 'DKJ-Solutions/dkj-claude-plugins'
$sharedRef  = 'main'
$sharedPath = '.workflow-scripts'
$pluginDir  = "$sharedPath/plugins/dkj-policy/scripts"

# ACTIONS/CHECKOUT IS PINNED BY SHA IN THE TWO WRITE-CAPABLE RUNNERS BELOW (issue #1904).
# This repo's own .github/workflows/fold-on-merge.yml and verify-resolved.yml have carried this pin
# since they were written, and the comment on the first of them states the reason: a mutable tag on
# that line could otherwise retag its way into exfiltrating a 366-day standing write token instead of
# an hour-lived one. The generator was handing every ADOPTING CONSUMER the same two jobs behind a
# floating tag -- the repo that wrote the warning protected, the repos that took its advice not.
#
# BOTH checkout steps in each of those jobs are pinned, not only the one holding the credential. The
# first checks out with persist-credentials on, so the token sits in the workspace git config for every
# later step of the same job; verify-resolved's job likewise holds issues: write for its whole length.
# An action is pinned because of the JOB it runs in, not because of the line it sits on.
#
# A READ-ONLY runner scaffolded here is deliberately NOT pinned -- it holds contents: read and no
# secret, and this repo's own copy of such a workflow is unpinned for that same reason.
#
# HOW THIS PIN GETS REFRESHED, which is the half a generated pin does not get for free. It is ONE
# variable rather than four literals, and pin-parity.tests.ps1 asserts it still equals the SHA in this
# repo's own fold-on-merge.yml. So the pin has a single refresh point and a gate that fails the moment
# a hand-maintained workflow here is bumped and the scaffolder is not -- a consumer's floor cannot
# quietly fall behind the floor this repo runs on itself.
$checkoutPin = 'actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09 # v5'

# --- What the trunk's own rules say -----------------------------------------------------------------
# READ, NEVER WRITTEN, and read once: both questions below (is there a queue, and which contexts are
# required) come off the same payload, which is the same economy ship-pr's step 0b makes.
#
# AN UNREADABLE PAYLOAD IS NOT "NO QUEUE", and this script must not collapse the two any more than
# ship-pr does. A consumer whose token cannot read a ruleset, or who is offline, gets a report that says
# the question was not answered -- and it still reports and places everything that does not depend on
# the answer, because the floor is worth building either way.
$rulesJson = ''
$rulesSource = ''
if ($RulesJsonOverride) {
    if (Test-Path -LiteralPath $RulesJsonOverride -PathType Leaf) {
        $rulesJson = [System.IO.File]::ReadAllText($RulesJsonOverride)
        $rulesSource = "the payload in $RulesJsonOverride"
    }
} else {
    $repoSlug = ''
    if (Test-FunctionDefined 'Get-RepoName') { $repoSlug = [string](Get-RepoName) }
    if (-not $repoSlug) {
        # No seam answer: ask gh what repo this checkout is. A consumer that has not answered
        # Get-RepoName yet is exactly the fresh adoption this command is for, so refusing here would
        # gate the floor on a seam that has nothing to do with it.
        $slugRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @('repo', 'view', '--json', 'nameWithOwner', '--jq', '.nameWithOwner')
        if ($slugRead.ExitCode -eq 0) { $repoSlug = ($slugRead.Output -join '').Trim() }
    }
    if ($repoSlug) {
        # -DiscardStderr because this output is PARSED: a gh warning merged into it would break the
        # ConvertFrom-Json and cost the read. Same reasoning as ship-pr's own rules call.
        $rulesRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @('api', "repos/$repoSlug/rules/branches/$trunk")
        if ($rulesRead.ExitCode -eq 0) {
            $rulesJson = $rulesRead.Output -join "`n"
            $rulesSource = "gh api repos/$repoSlug/rules/branches/$trunk"
        }
    }
}

$queueVerdict = Get-MergeQueueVerdict -BranchRulesJson $rulesJson
$queueReadable = $queueVerdict.Readable
$queueActive = ($queueVerdict.Readable -and $queueVerdict.Active)

# The REQUIRED check contexts, off the same payload. Get-DirectPushBlockingRules already collects them
# -- it reads them so its own refusal can name what the remote would have named -- so asking it here
# adds no parsing of its own and cannot disagree with what ship-pr reads.
$requiredContexts = @()
if ($queueReadable) {
    foreach ($rec in (Get-DirectPushBlockingRules -BranchRulesJson $rulesJson).Blocking) {
        $requiredContexts += @($rec.Contexts)
    }
    $requiredContexts = @($requiredContexts | Sort-Object -Unique)
}

# --- Which workflow carries which required check ----------------------------------------------------
function Get-WorkflowFacts {
    <#
        One record per .github/workflows/*.yml: its path, the job keys and job names it declares, and
        whether its `on:` block carries a merge_group trigger.

        THE TRIGGER IS MATCHED AS A KEY OF THE `on:` BLOCK, not as the word anywhere in the file. Every
        paragraph of reasoning about a queue names `merge_group` too, so a substring test would report a
        workflow as ready on the strength of a comment about it -- which is the exact silent state this
        whole command exists to prevent. Same property merge-queue-prereq.tests.ps1 asserts on the
        source's own ci.yml, and deliberately the same regex shape.

        A CHECK CONTEXT IS A JOB, NOT A FILE, which is why the job keys are collected at all. GitHub
        names an Actions check after the job's `name:` where it has one and after its key otherwise
        (measured on this workflow's source: the required context `lint-en-tests` is the key of a job
        in ci.yml that declares no name). Both are collected, and a context matching neither is
        reported as unmatched rather than guessed at -- an unmatched context is a real answer here,
        because a required check may come from something other than Actions.
    #>
    param([Parameter(Mandatory)][string]$WorkflowDir)

    $facts = @()
    if (-not (Test-Path -LiteralPath $WorkflowDir -PathType Container)) { return @() }
    foreach ($f in @(Get-ChildItem -LiteralPath $WorkflowDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.yml', '.yaml') })) {
        $text = [System.IO.File]::ReadAllText($f.FullName)

        $onBlock = [regex]::Match($text, '(?ms)^on:\r?\n(?<body>(?:[ \t]+\S[^\r\n]*\r?\n)+)')
        $hasMergeGroup = $onBlock.Success -and ($onBlock.Groups['body'].Value -match '(?m)^\s{2}merge_group:')
        $onPullRequest = $onBlock.Success -and ($onBlock.Groups['body'].Value -match '(?m)^\s{2}pull_request:')

        # The jobs block runs to the end of the file: `jobs:` is conventionally last, and a top-level key
        # after it would end the match at that key's own column-0 line.
        $jobsBlock = [regex]::Match($text, '(?ms)^jobs:\r?\n(?<body>(?:(?:[ \t]+[^\r\n]*|\s*)\r?\n)+)')
        $ids = @()
        if ($jobsBlock.Success) {
            foreach ($m in [regex]::Matches($jobsBlock.Groups['body'].Value, '(?m)^\s{2}(?<key>[A-Za-z0-9_.\-]+):\s*$')) {
                $ids += $m.Groups['key'].Value
            }
            foreach ($m in [regex]::Matches($jobsBlock.Groups['body'].Value, '(?m)^\s{4}name:\s*(?<name>\S[^\r\n]*)$')) {
                $ids += ($m.Groups['name'].Value.Trim().Trim('''"'))
            }
        }

        $facts += [pscustomobject]@{
            Name          = $f.Name
            Rel           = ".github/workflows/$($f.Name)"
            JobIds        = @($ids | Sort-Object -Unique)
            HasMergeGroup = $hasMergeGroup
            OnPullRequest = $onPullRequest
        }
    }
    return @($facts)
}

$workflowDir = Join-Path $repoRoot '.github\workflows'
$workflows = Get-WorkflowFacts -WorkflowDir $workflowDir

# --- The two runners, consumer-shaped ---------------------------------------------------------------
# DERIVED FROM THE SOURCE'S OWN, NOT COPIED. Two things differ, both of them structural rather than
# stylistic: the scripts are reached through a checkout of the plugin's tree instead of the repo's own
# (there is one definition of the fold in this system and this must not become a second), and
# CLAUDE_PROJECT_DIR is set so those mirrored scripts judge the CONSUMER's tree rather than the checked
# out one. The reasoning paragraphs are the source's, kept, because a runner whose "why" was stripped is
# the first thing a later sweep deletes as dead configuration.
$foldRunner = @(
    '# Folds a queue-merged PR''s changelog entry, since the session that ships it never sees the merge.',
    '#',
    '# WHAT THIS CLOSES. fold-changelog-entry.ps1 runs from exactly one place -- ship-pr.ps1, as the',
    '# shipping session''s own next step after its own merge call returns. A merge queue merges the PR',
    '# itself, minutes later, in a process that session never observes, so that step never runs: the',
    ('# branch''s development document sits on the trunk unfolded, the changelog never receives the entry,'),
    '# and a release cut in that window misses the change. This workflow is the fold running from the one',
    '# place that always sees a queue merge: a push to the trunk. It also catches a PR merged from the',
    '# GitHub UI, which skips the fold for the same reason.',
    '#',
    '# IT ADDS NO RULE OF ITS OWN, AND NO SECOND DETECTOR. It runs the plugin''s check-unfolded-entry.ps1',
    '# unchanged, and only when THAT finds a leftover does it call the plugin''s fold-changelog-entry.ps1.',
    '# Both are reached through a checkout of the plugin''s own tree rather than copied here, so there is',
    '# one definition of "a written entry stranded on the trunk" in the system instead of two.',
    '#',
    '# THE PUSH NEEDS A CREDENTIAL YOU HAVE TO CREATE -- FOLD_PUSH_TOKEN, AND THIS FILE DOES NOT WORK',
    '# WITHOUT IT. A merge_queue rule blocks every direct push to the trunk unless the pushing actor is a',
    '# listed bypass actor, and the default GITHUB_TOKEN pushes as the GitHub Actions app, which cannot be',
    '# added to that list (an Integration bypass actor has to be an app installed on the org, and that one',
    '# is not administered by yours). So this job checks out with a fine-grained personal access token',
    '# belonging to somebody who already bypasses the ruleset -- scoped to this repository only, and to',
    '# Contents: Read and write only. It is a STANDING credential, valid from anywhere until it expires,',
    '# and actions/checkout writes it into the workspace git config, so every step of this job holds it.',
    '# That is why nothing else is ever added to this job. Rotate it before it expires or this job starts',
    '# failing its push with no code-level cause.',
    '#',
    '# READ THE FOLD STEP''S OWN LAST LINES BEFORE CONCLUDING ANYTHING FROM A RED RUN. THREE different',
    '# things turn this job red, and only the log tells them apart (inbound #1539):',
    '#   1. the CHECKOUT failing -- an absent or under-scoped FOLD_PUSH_TOKEN fails actions/checkout, and',
    '#      every later step then shows `skipped`. Rule this one out FIRST: it is the only cause that',
    '#      leaves the fold step with no last lines to read at all. A fine-grained PAT lists repositories',
    '#      one by one, so a repo created rather than transferred (an org move with no GitHub transfer',
    '#      does exactly that) silently falls outside an existing token''s selection.',
    '#   2. the fold REFUSING -- it ran and declined; its own last lines say why. TWO refusals are not',
    '#      in this list and no longer turn the job red at all: the trunk-gap guard (exit 2, #1586) and',
    '#      the redundant-fold verdict (exit 3, #1796), which the fold step translates into a stood-down',
    '#      green.',
    '#   3. the fold SUCCEEDING and its push being rejected BY THE RULESET -- a clean fold above a GH013.',
    '#      Read the rejection: a push refused as a NON-FAST-FORWARD looks like this and is not it -- that',
    '#      is the race below, and where the fold can prove the entry is already upstream it never reaches',
    '#      this list (exit 3). GH013 names a rule and a ruleset; a non-fast-forward names a ref and tells',
    '#      you to fetch first. One the fold canNOT prove redundant is still exit 1 and still this cause.',
    '#',
    '# THE FIRST CHECKOUT TAKES THE TRUNK TIP, NOT THE EVENT SHA (inbound #1543). On a push event',
    '# actions/checkout defaults to github.sha; ship-pr then folds locally and pushes on top within',
    '# seconds, so by the time this slower runner reads the tree the trunk has already moved and the',
    '# checkout is one commit behind origin -- which the fold''s trunk-gap guard (#1405) then refuses on,',
    '# turning every ship-pr merge into a false red. Checking out the trunk tip makes this job answer the',
    '# question it exists for -- "does the trunk carry a leftover NOW" -- so a fold ship-pr already did is',
    '# simply not found.',
    '#',
    '# IT DOES NOT PUT THAT GUARD OUT OF REACH, WHICH THIS TEMPLATE CLAIMED UNTIL #1586. The ref is read',
    '# once, at the checkout; the guard measures the same trunk again seconds later, from inside the fold.',
    '# So a SECOND merge landing in that gap still trips it: the leftover is genuinely on the trunk and',
    '# correctly found, and by the time the fold runs somebody else has already folded it.',
    '#',
    '# SO THIS JOB STANDS DOWN ON THAT REFUSAL rather than going red -- exit code 2 from the fold,',
    '# which nothing else returns. The argument is #1543''s own, one step on: this job answers "does the',
    '# trunk carry a leftover NOW", and a trunk that moved under it has changed what "now" means. The push',
    '# that moved it is a push to the trunk too, so it has its own run of this workflow queued behind this',
    '# one, whose checkout includes it -- and nothing is lost, because that guard fires in a pre-pass',
    '# before a single entry is folded.',
    '#',
    '# THE RACE HAS A NARROW HALF TOO, AND IT NEEDS ITS OWN CODE (inbound #1796). Everything above is the',
    '# case where the other fold landed BEFORE this job''s pre-pass read the trunk. It can also land in the',
    '# window between that read and this job''s own push -- and then the pre-pass passes, entries are',
    '# folded, a commit is made, and the push is refused as a non-fast-forward. No check at the top of a',
    '# run can close a window that opens after it, so this is not a better-pre-pass problem.',
    '#',
    '# THE GROUND FOR STANDING DOWN THERE IS DIFFERENT, AND STRONGER. #1586''s is "nothing was written and',
    '# a successor run is queued"; neither holds here -- a commit WAS made, and no successor is owed,',
    '# because the trunk is ALREADY correct. What earns exit 3 is a measurement: every entry this run',
    '# folded is upstream already, present with an identical body. The redundant commit is real and it is',
    '# in an EPHEMERAL workspace, so it dies with the run -- which is why this job may stand down where a',
    '# session folding onto a real trunk may not. Every OTHER non-zero code still fails the job.',
    '#',
    '# NO CONCURRENCY CANCELLATION, AND A CONSTANT GROUP (inbound #1544). This job WRITES and pushes to',
    '# the trunk: cancel-in-progress: false so no push is dropped, AND a group name that is constant per',
    '# trunk (github.ref, not github.sha) so two trunk pushes close together QUEUE instead of racing for',
    '# the trunk -- a per-SHA group is its own group every time and serialises nothing.',
    '#',
    '# WINDOWS: the shared scripts target Windows PowerShell 5.1, which is what ''shell: powershell'' is.',
    'name: Fold on merge',
    '',
    '# contents: read, deliberately -- the actual push authenticates as FOLD_PUSH_TOKEN, wired into the',
    '# checkout step below, and never touches this block. pull-requests: read is not optional: the fold''s',
    '# own PR lookup needs it, and declaring any permissions block at all sets every unlisted scope to none.',
    'permissions:',
    '  contents: read',
    '  pull-requests: read',
    '',
    'on:',
    '  push:',
    ('    branches: [' + $trunk + ']'),
    '',
    'concurrency:',
    '  group: fold-on-merge-${{ github.ref }}',
    '  cancel-in-progress: false',
    '',
    'jobs:',
    '  fold-on-merge:',
    '    runs-on: windows-latest',
    '    steps:',
    '      # ref: the trunk tip, not the pushed SHA -- see the header comment (inbound #1543). This job',
    '      # asks whether the trunk carries a leftover NOW, and a fold ship-pr already pushed on top of',
    '      # the merge commit must not read as still-unfolded here.',
    ('      - uses: ' + $checkoutPin),
    '        with:',
    ('          ref: ' + $trunk),
    '          token: ${{ secrets.FOLD_PUSH_TOKEN }}',
    '',
    '      - name: Fetch the shared workflow scripts',
    ('        uses: ' + $checkoutPin),
    '        with:',
    ('          repository: ' + $sharedRepo),
    ('          ref: ' + $sharedRef),
    ('          path: ' + $sharedPath),
    '',
    '      # continue-on-error is deliberate: the check exits non-zero on a genuine FIND, which is the',
    '      # case this job exists to act on, not a step failure. The fold step below tells that apart',
    '      # from a real crash in the detector rather than folding blind on an outcome it cannot explain.',
    '      - name: Is there an unfolded changelog entry on the trunk?',
    '        id: check',
    '        shell: powershell',
    '        continue-on-error: true',
    '        env:',
    '          CLAUDE_PROJECT_DIR: ${{ github.workspace }}',
    '        run: |',
    ('          powershell -NoProfile -ExecutionPolicy Bypass -File ' + $pluginDir + '/lint/check-unfolded-entry.ps1 -Branch ' + $trunk + ' *>&1 | Tee-Object -FilePath check-output.txt'),
    '          exit $LASTEXITCODE',
    '',
    '      - name: Fold it (every leftover this push may carry)',
    '        if: ${{ steps.check.outcome == ''failure'' }}',
    '        shell: powershell',
    '        env:',
    '          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}',
    '          GH_REPO: ${{ github.repository }}',
    '          CLAUDE_PROJECT_DIR: ${{ github.workspace }}',
    '        run: |',
    '          # The check''s own known-good signature is what tells "a leftover was found" apart from',
    '          # "the script crashed for some other reason" -- both exit non-zero, and only one of them',
    '          # is safe to act on.',
    '          $checkOutput = Get-Content check-output.txt -Raw',
    '          if ($checkOutput -notmatch ''\[ERROR\] the trunk carries'') {',
    '            Write-Error "check-unfolded-entry.ps1 exited non-zero for a reason other than a reported leftover -- refusing to fold blind. Its output:`n$checkOutput"',
    '            exit 1',
    '          }',
    '',
    '          # Commit-metadata identity only -- who authored the commit. It is independent of the',
    '          # push''s credential (FOLD_PUSH_TOKEN, wired in by the checkout step above): a ruleset',
    '          # bypass is checked against the pushing token''s identity, not the commit author.',
    '          git config user.name "github-actions[bot]"',
    '          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"',
    ('          powershell -NoProfile -ExecutionPolicy Bypass -File ' + $pluginDir + '/release/fold-changelog-entry.ps1 -Commit -Push *>&1 | Tee-Object -FilePath fold-output.txt'),
    '          $foldExitCode = $LASTEXITCODE',
    '',
    '          # EXIT 2 IS "THE TRUNK MOVED UNDER ME", AND THIS JOB STANDS DOWN ON IT (#1586). It is the',
    '          # fold''s trunk-freshness pre-pass, which runs before a single entry is folded -- so this',
    '          # run wrote nothing, and the push that made the checkout stale has its own run of this',
    '          # workflow queued behind it. Keyed on the code and only on the code: every other non-zero',
    '          # code still fails below, so this is not a blanket "ignore the fold".',
    '          if ($foldExitCode -eq 2) {',
    '            Write-Host "Stood down: the trunk moved between this job''s checkout and the fold, so nothing was folded and nothing was written."',
    '            Write-Host "  The push that moved it has its own run of this workflow, whose checkout includes it. See this file''s header (#1586)."',
    '            exit 0',
    '          }',
    '',
    '          # EXIT 3 IS "SOMEBODY ELSE FOLDED THIS WHILE I WAS FOLDING IT" (#1796) -- the narrow half',
    '          # of the same race: the other fold landed in the window between the pre-pass and this',
    '          # push, so entries WERE folded and committed and the push came back a non-fast-forward.',
    '          # The fold earns this code by measuring that every entry it carried is already upstream',
    '          # with an identical body, so the trunk holds what this job exists to put there; a push',
    '          # refused for any other reason -- a ruleset GH013, a credential -- is still exit 1.',
    '          # The redundant commit is local to this runner''s workspace and dies with it, which is why',
    '          # this job may stand down where a session on a real trunk may not.',
    '          if ($foldExitCode -eq 3) {',
    '            Write-Host "Stood down: the fold''s push lost the race, and every entry it carried is already on the trunk with an identical body."',
    '            Write-Host "  The redundant commit is local to this runner''s workspace and dies with it. See this file''s header (#1796)."',
    '            exit 0',
    '          }',
    '',
    '          # The two scripts read the same trunk a moment apart and must agree: the check found a',
    '          # leftover, so the fold reporting nothing to fold is a real disagreement between them.',
    '          $foldOutput = Get-Content fold-output.txt -Raw',
    '          if ($foldOutput -match ''No entry files found to fold'') {',
    '            Write-Error "check-unfolded-entry.ps1 reported a leftover but fold-changelog-entry.ps1 found nothing to fold -- the two disagree, which should not happen. Its output:`n$foldOutput"',
    '            exit 1',
    '          }',
    '          exit $foldExitCode'
)

$resolvesRunner = @(
    '# Verifies the issues a merged PR declared it closes -- from the merge, since the shipping session',
    '# no longer sees one.',
    '#',
    '# WHAT THIS CLOSES. verify-resolved-issues.ps1 is ship-pr.ps1''s step 6: it reads a merged PR''s body',
    '# back out and checks that every issue declared there with a closing keyword is actually CLOSED,',
    '# closing the ones that are not. It ran from exactly one place -- the shipping session, right after',
    '# its own merge call returned. A merge queue takes that call away: ship-pr enqueues and exits, and',
    '# the merge lands minutes later in a process that session never observes.',
    '#',
    '# THE CLOSING ITSELF IS NOT AT RISK. GitHub honours a body''s keywords on a queue merge exactly as on',
    '# any other. What is lost is the VERIFICATION that it happened, and the REPAIR when a keyword missed',
    '# -- which is the case the script was built for: a body carrying a plain mention instead of a keyword',
    '# closes nothing, and nobody finds out.',
    '#',
    '# ITS OWN WORKFLOW, NOT A STEP IN fold-on-merge.yml, AND THAT IS THE SECURITY ARGUMENT. That job',
    '# checks out with a standing personal access token that actions/checkout writes into the workspace,',
    '# so every step of it holds that credential. Adding issues: write there would put a standing',
    '# credential and issue-write in one job. Here they never meet: this job checks out with the default',
    '# job-scoped GITHUB_TOKEN, which expires in about an hour and is unusable outside this run.',
    '#',
    '# THE SECOND REASON FOR ITS OWN FILE IS COVERAGE. The fold runner acts only when a leftover entry is',
    '# on the trunk, because an entry is what a fold needs. This check has to run for EVERY merge --',
    '# including one carrying no changelog entry at all -- so it resolves its PRs from the push itself.',
    '#',
    '# NO CONCURRENCY CANCELLATION, AND A CONSTANT GROUP (inbound #1544): this job ACTS, so letting a',
    '# later push supersede an in-flight run would drop the verification of whatever the earlier push',
    '# carried -- cancel-in-progress: false. The group is keyed on github.ref, not github.sha, so it is',
    '# constant per trunk; two overlapping runs are harmless here (the second finds every issue already',
    '# closed) but a constant group keeps them ordered anyway.',
    '#',
    '# WINDOWS: the shared scripts target Windows PowerShell 5.1, which is what ''shell: powershell'' is.',
    'name: Verify resolved issues',
    '',
    'permissions:',
    '  contents: read',
    '  pull-requests: read',
    '  # THE ONE WIDENING, and the whole of it: without this scope the repair is a 403 and this job is a',
    '  # reporter. Granted on the job-scoped GITHUB_TOKEN only.',
    '  issues: write',
    '',
    'on:',
    '  push:',
    ('    branches: [' + $trunk + ']'),
    '',
    'concurrency:',
    '  group: verify-resolved-${{ github.ref }}',
    '  cancel-in-progress: false',
    '',
    'jobs:',
    '  verify-resolved:',
    '    runs-on: windows-latest',
    '    steps:',
    '      # persist-credentials: false -- this job reads and calls the API, and never pushes. Nothing',
    '      # here needs a git credential left in the workspace.',
    ('      - uses: ' + $checkoutPin),
    '        with:',
    '          persist-credentials: false',
    '',
    '      - name: Fetch the shared workflow scripts',
    ('        uses: ' + $checkoutPin),
    '        with:',
    ('          repository: ' + $sharedRepo),
    ('          ref: ' + $sharedRef),
    ('          path: ' + $sharedPath),
    '',
    '      # THE EVENT''S VALUES ARRIVE THROUGH env:, NOT THROUGH ${{ }} INSIDE run:. Interpolating an',
    '      # expression into a shell body substitutes it as TEXT before the shell parses the line, which',
    '      # is the standard Actions script-injection shape. These are SHAs and a repository name GitHub',
    '      # computes itself, so there is nothing to inject today -- the point is that this file should',
    '      # not have to be re-argued if a later edit reaches for a branch name or a PR title.',
    '      - name: Verify the issues this push''s pull requests declared they close',
    '        shell: powershell',
    '        env:',
    '          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}',
    '          GH_REPO: ${{ github.repository }}',
    '          PUSH_BEFORE: ${{ github.event.before }}',
    '          PUSH_SHA: ${{ github.sha }}',
    '          CLAUDE_PROJECT_DIR: ${{ github.workspace }}',
    '        run: |',
    ('          powershell -NoProfile -ExecutionPolicy Bypass -File ' + $pluginDir + '/release/verify-pushed-merges.ps1 `'),
    ('            -Before $env:PUSH_BEFORE -Sha $env:PUSH_SHA -Trunk ' + $trunk + ' -Repo $env:GH_REPO'),
    '          exit $LASTEXITCODE'
)

$targets = @(
    @{ Rel = '.github/workflows/fold-on-merge.yml';   Content = (($foldRunner -join $nl) + $nl);     What = 'the fold, which the queue takes away from the shipping session' },
    @{ Rel = '.github/workflows/verify-resolved.yml'; Content = (($resolvesRunner -join $nl) + $nl); What = 'the resolves verification, which the queue takes away too' }
)

# --- Report ------------------------------------------------------------------------------------------
Write-Host "== adopt-merge-queue -- $repoRoot ==" -ForegroundColor Cyan
if (-not $Apply) { Write-Host '  DRY RUN -- nothing is written. Re-run with -Apply to place the files below.' -ForegroundColor Yellow }
Write-Host ''

$liveDefects = 0

# 1. THE TRIGGER, FIRST, because it is the one that is an OUTAGE rather than a gap. It is also the one
#    piece of the floor this command cannot place: the workflow carrying your required check is yours,
#    and adding a trigger to it is an edit to somebody else's file rather than an addition beside it.
Write-Host '-- 1. the required check, and (queue only) its merge_group trigger --' -ForegroundColor Cyan
if (-not $queueReadable) {
    Write-Host "  [skip]    the trunk's rules could not be read, so which checks are REQUIRED is unknown." -ForegroundColor DarkGray
    Write-Host '            Every workflow below is listed with its trigger so you can judge it yourself.' -ForegroundColor DarkGray
    foreach ($w in $workflows | Where-Object { $_.OnPullRequest }) {
        $mark = if ($w.HasMergeGroup) { 'has merge_group' } else { 'NO merge_group' }
        Write-Host "            $($w.Rel) -- $mark" -ForegroundColor DarkGray
    }
} elseif ($requiredContexts.Count -eq 0) {
    # THE REASON CHANGED WITH THE POLICY (#1546), AND IT GOT STRONGER. This used to read as a
    # precondition for switching a queue on -- which made it somebody else's problem in a repo that was
    # never going to have one. Detect-and-rebase reads the RUN BEHIND A REQUIRED CHECK to date the
    # certificate, so with nothing required ship-pr prints 'no required check name is known -- not
    # checked' and the staleness guard is simply off. That is the standing mechanism now, so this is the
    # one gap on this page that every repo should close.
    Write-Host "  [gap]     no required status check on '$trunk', so the staleness guard is OFF." -ForegroundColor Yellow
    Write-Host '            ship-pr dates a PR certificate from the run behind a REQUIRED check; with none' -ForegroundColor Yellow
    Write-Host '            named it says so and skips the step, which is honest and is also blind. Making' -ForegroundColor Yellow
    Write-Host '            one CI check required on the trunk is what turns detect-and-rebase on.' -ForegroundColor Yellow
    Write-Host '' -ForegroundColor Yellow
    Write-Host '            IT MUST BE A CHECK THAT CAN CARRY THE ROLE, and the branch-entry gate this' -ForegroundColor Yellow
    Write-Host '            plugin ships CANNOT: it reads github.head_ref, which is empty outside a pull' -ForegroundColor Yellow
    Write-Host '            request, so it stays a pull-request check. Use your own CI workflow. If you also' -ForegroundColor Yellow
    Write-Host '            run a queue, that workflow needs the merge_group trigger of this section too.' -ForegroundColor Yellow
} else {
    foreach ($ctx in $requiredContexts) {
        $owner = @($workflows | Where-Object { $_.JobIds -contains $ctx })
        if ($owner.Count -eq 0) {
            Write-Host "  [note]    required check '$ctx' matches no job in .github/workflows/ -- it comes from" -ForegroundColor Yellow
            Write-Host '            somewhere else (another app, or a job name this reader cannot see). If it IS an' -ForegroundColor Yellow
            Write-Host '            Actions job, that workflow needs the merge_group trigger too.' -ForegroundColor Yellow
            continue
        }
        foreach ($w in $owner) {
            if ($w.HasMergeGroup) {
                Write-Host "  [ok]      required check '$ctx' -> $($w.Rel), which triggers on merge_group." -ForegroundColor Green
            } elseif ($queueActive) {
                $liveDefects++
                Write-Host "  [ERROR]   required check '$ctx' -> $($w.Rel), which does NOT trigger on merge_group," -ForegroundColor Red
                Write-Host "            and a queue is ACTIVE on '$trunk'. That check never reports for a queue entry," -ForegroundColor Red
                Write-Host '            so every merge fails. Add to its on: block, at two spaces of indent:' -ForegroundColor Red
                Write-Host '              merge_group:' -ForegroundColor Red
            } else {
                Write-Host "  [gap]     required check '$ctx' -> $($w.Rel), which does NOT trigger on merge_group." -ForegroundColor Yellow
                Write-Host '            Inert today; a TOTAL MERGE OUTAGE the moment a queue is switched on. Add to its' -ForegroundColor Yellow
                Write-Host '            on: block, at two spaces of indent:' -ForegroundColor Yellow
                Write-Host '              merge_group:' -ForegroundColor Yellow
            }
        }
    }
}
Write-Host ''

# 2 + 3. THE TWO RUNNERS. These this command CAN place: they are new files beside yours, not edits to
#        one of them, which is the same line adopt-workflow-folder draws.
Write-Host '-- 2. the two runners ANY unobserved merge takes away (queue, or the UI button) --' -ForegroundColor Cyan
$created = 0
$kept = 0
foreach ($t in $targets) {
    $abs = Join-Path $repoRoot ($t.Rel -replace '/', '\')
    if (Test-Path -LiteralPath $abs) {
        $kept++
        Write-Host "  [exists]  $($t.Rel) -- left as it is" -ForegroundColor DarkGray
        continue
    }
    if ($queueActive -and -not $Apply) { $liveDefects++ }
    $created++
    if ($Apply) {
        $dir = Split-Path -Parent $abs
        if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
        [System.IO.File]::WriteAllText($abs, $t.Content, $Utf8NoBom)
        Write-Host "  [created] $($t.Rel) -- $($t.What)" -ForegroundColor Green
    } else {
        $marker = if ($queueActive) { '[MISSING]' } else { '[create] ' }
        $colour = if ($queueActive) { 'Red' } else { 'Green' }
        Write-Host "  $marker $($t.Rel) -- $($t.What)" -ForegroundColor $colour
    }
}
if ($created -gt 0) {
    Write-Host ''
    Write-Host '  THE FOLD RUNNER NEEDS A SECRET YOU HAVE TO CREATE: FOLD_PUSH_TOKEN.' -ForegroundColor Yellow
    Write-Host '  A merge_queue rule blocks every direct push to the trunk, and the default GITHUB_TOKEN' -ForegroundColor Yellow
    Write-Host '  cannot be given a bypass. Create a fine-grained PAT owned by somebody who already bypasses' -ForegroundColor Yellow
    Write-Host '  the ruleset, scoped to this repository and to Contents: Read and write, and store it as' -ForegroundColor Yellow
    Write-Host '  the repository secret FOLD_PUSH_TOKEN. Without it -- or with one that does not grant this' -ForegroundColor Yellow
    Write-Host '  repository -- actions/checkout FAILS and the job never reaches the fold: every later step' -ForegroundColor Yellow
    Write-Host '  shows skipped. Create it BEFORE you merge the floor, not after. (A fine-grained PAT lists' -ForegroundColor Yellow
    Write-Host '  repositories one by one, so a repo created rather than transferred falls outside an' -ForegroundColor Yellow
    Write-Host '  existing token''s selection.)' -ForegroundColor Yellow
}
Write-Host ''

# 4. THE QUEUE, LAST, NEVER PULLED HERE -- AND NEVER REPORTED AS A GAP (issues #1540, #1546).
#    It was a '[gap]' until September 7, 2026, on the reading that every repo running this workflow
#    adopts one. Most of them are not ALLOWED to: GitHub offers merge queue on private repos only under
#    Enterprise Cloud, and otherwise only on public repos owned by organizations -- and on Free, Pro or
#    Team it hides the 'Require merge queue' checkbox rather than disabling it. So the instruction could
#    not be followed and the gap could not be closed, and the reader went looking through the ruleset UI
#    for a control that is not rendered. Measured: this workflow's own source repo is public on plan
#    'free' and qualifies through the public clause, which is why the policy looked universal to the one
#    repo that set it. A missing queue is now the ORDINARY state and prints as a note.
Write-Host '-- 3. the queue (optional -- not this workflow''s policy) --' -ForegroundColor Cyan
if (-not $queueReadable) {
    Write-Host "  [skip]    the trunk's rules could not be read here -- no gh, no network, or a token that" -ForegroundColor DarkGray
    Write-Host '            cannot read rulesets. That is not "no queue": nothing above assumed either way.' -ForegroundColor DarkGray
    Write-Host "            Read it yourself with:  gh api repos/<owner>/<repo>/rules/branches/$trunk --jq '[.[].type]'" -ForegroundColor DarkGray
} elseif ($queueActive) {
    Write-Host "  [ok]      a merge_queue rule is active on '$trunk' ($rulesSource)." -ForegroundColor Green
    Write-Host '            Point 1 above is what keeps it honest -- a required check with no merge_group' -ForegroundColor DarkGray
    Write-Host '            trigger stops every merge in this repo.' -ForegroundColor DarkGray
} else {
    Write-Host "  [note]    no merge_queue rule on '$trunk' -- which is the ordinary state, not a gap." -ForegroundColor DarkGray
    Write-Host '            This workflow relies on detect-and-rebase instead: ship-pr refuses to merge on a' -ForegroundColor DarkGray
    Write-Host '            certificate the trunk has moved past, and you bring the branch forward. That works' -ForegroundColor DarkGray
    Write-Host '            in every repo, which a queue does not -- GitHub offers one on a PRIVATE repo only' -ForegroundColor DarkGray
    Write-Host '            under Enterprise Cloud, and otherwise only on a PUBLIC repo owned by an org. On' -ForegroundColor DarkGray
    Write-Host '            Free, Pro or Team the checkbox is not rendered at all, so this is usually not even' -ForegroundColor DarkGray
    Write-Host '            an available choice. What detect-and-rebase DOES need is point 1 above: a required' -ForegroundColor DarkGray
    Write-Host '            check to read a certificate from.' -ForegroundColor DarkGray
    Write-Host '' -ForegroundColor DarkGray
    Write-Host '            If your repo is eligible and you want one anyway, add the rule named' -ForegroundColor DarkGray
    Write-Host "            'Require merge queue' in Settings -> Rules -> Rulesets, on the ruleset that" -ForegroundColor DarkGray
    Write-Host "            already protects '$trunk'." -ForegroundColor DarkGray
    Write-Host '            THIS COMMAND WILL NOT DO IT FOR YOU, deliberately: a ruleset changes what' -ForegroundColor DarkGray
    Write-Host '            every contributor''s merge does, immediately, for everybody. Do points 1 and 2' -ForegroundColor DarkGray
    Write-Host '            FIRST -- flipping it with a required check that has no merge_group trigger is a' -ForegroundColor DarkGray
    Write-Host '            total merge outage on the first merge afterwards.' -ForegroundColor DarkGray
}
Write-Host ''

if ($Apply) {
    Write-Host "Done: $created runner(s) created, $kept left as they were." -ForegroundColor Green
} else {
    Write-Host "Would create $created runner(s); $kept already exist. Re-run with -Apply." -ForegroundColor Yellow
}

# EXIT 1 ONLY ON A LIVE DEFECT, and the distinction is the whole point of the two vocabularies above. A
# '[gap]' is work not yet done on a repo whose merges are fine today; an '[ERROR]' is a queue that is
# already running against a floor that is not there -- entries being stranded on the trunk, or merges
# about to stop. Exiting 1 on the first would make an honest to-do list read as a broken repo, which is
# how a report earns being ignored.
if ($liveDefects -gt 0) {
    Write-Host "$liveDefects live defect(s): the queue on '$trunk' is ACTIVE and the floor under it is incomplete." -ForegroundColor Red
    exit 1
}
exit 0
