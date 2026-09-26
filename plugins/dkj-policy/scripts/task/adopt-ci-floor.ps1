<#
.SYNOPSIS
    The CI floor, in a consuming repo: place the runners that keep the fold and the resolves
    verification alive across a merge this session never observes, place the scheduled check that a
    GitHub-side repo setting has not silently drifted, report whether a required status check exists at
    all -- the one detect-and-rebase reads -- and, where none does, print the exact `gh api` call that
    would create one, WITHOUT running it, AND where nothing in the tree triggers on pull_request at all,
    offer a minimal CI skeleton to require. A repo that has CHOSEN a merge queue is pointed at the UI
    instead: that switch is not composed here. Issues #1516, #1546, #1843, #1903, #1972.

.DESCRIPTION
    NAMED adopt-merge-queue.ps1 UNTIL SEPTEMBER 13, 2026 (#1903), AND THE OLD NAME IS GONE RATHER THAN
    FORWARDED. Nothing machine-side ever called it -- the one executable reference is the run line on
    adopt-dkj-policy's Part 3 page, and that page ships in the same plugin release as this file, so the
    two cannot disagree in a consumer's tree. A shim at the old path would need its own registry entry
    and its own test: two maintained names for one script, which is precisely the ambiguity the rename
    removes. A consumer who had automated the old path gets a loud file-not-found instead of a second
    silent name. The queue is the last and least reachable thing this command covers -- see the next
    paragraph -- and the name now says what the rest of it does.

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

    THE FOLD AND RESOLVES RUNNERS ARE EVERY REPO'S, QUEUE OR NO QUEUE, and this is the half most easily
    mis-read as queue machinery. What breaks the fold is a merge THE SHIPPING SESSION DOES NOT OBSERVE,
    and the GitHub UI merge button produces one in every repo on earth. A queue only makes it the normal
    case. The THIRD runner this command places -- the repo-settings drift check (#1843) -- is not queue-
    related at all, which is why $targets carries a QueueRelated flag per entry rather than a count.

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

    A FOURTH FILE THIS SCRIPT PLACES IS NOT ABOUT AN UNOBSERVED MERGE AT ALL (issue #1843):
    .github/workflows/repo-settings.yml, a SCHEDULED leg that asks whether a GitHub-side repo setting --
    a bypass actor, allow_auto_merge, which check is required -- still matches what scripts/repo-config.ps1
    declares (Get-ExpectedRepoSettings). It rides along in this same command because this is already the
    one place a consumer runs to build their CI floor, and the source repo measured three such drifts in
    eight days with nothing in its own tree saying so before it built the check this places
    (check-repo-settings.ps1). "The reachable goal is identical scripts available, not identical rules
    enforced" (Dave, September 12, 2026, on #1843) is why the VALUES stay the consumer's own to declare --
    an empty or absent declaration is a harmless [SKIP], never a refusal -- while the SCRIPT that compares
    them against GitHub is shared.

    A FIFTH FILE ANSWERS THE OTHER HALF OF #1843 -- A CONSUMER WITH NOTHING TO REQUIRE AT ALL. Section 1
    can compose the ruleset call the moment a required check exists somewhere in the tree, but until now
    a repo with NO workflow triggering on pull_request had nothing for that call to name -- only a
    placeholder. Where that is the state, this script also offers .github/workflows/ci.yml: a minimal
    workflow whose one job carries a placeholder step, empty on purpose ("a skeleton is portable; the
    body is not" -- what a merge should prove is this repo's own choice, never this script's to assert).
    Its job is named from the Get-CiTestCheckName seam when the repo has declared one, so the check this
    skeleton carries and the check open-pr's own local-gate-skip logic already looks for are the same
    name rather than two to reconcile by hand. Offered only when nothing else already triggers on
    pull_request, and only additively, like every other target here.

    A SIXTH FILE CLOSES A PROMISE ship-pr ALREADY MAKES IN EVERY CONSUMER (#2329):
    .github/workflows/merge-on-green.yml. ship-pr arms a pull request it refused on a red or pending
    required check with the merge-when-green label and says a sweep will finish the merge; this is that
    sweep, derived from the source repo's own runner (#2319). It reaches the plugin's
    pick-merge-on-green.ps1 and ship-pr.ps1 through the same checkout of the plugin tree, and runs both
    against THIS tree via CLAUDE_PROJECT_DIR. Its FOLD_PUSH_TOKEN needs Pull requests: write as well,
    and the run says so when it places the file.

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
    that class in the owner's hands. FOR THE REQUIRED-CHECK RULESET (section 1's '[gap]', #1972) the
    run composes the exact `gh api` call and stops -- reading the rules needs only a token that can
    read them; writing them needs one that can administer the repo, and a script that quietly held the
    second would be a different kind of tool. THE MERGE QUEUE (section 3) STAYS A UI HANDOVER, and
    that is not the same rule said twice for two different targets: composing it would mean asserting
    seven scheduling parameters -- merge method, grouping strategy, three limits, two timeouts -- that
    are policy nobody here has chosen, where the required-check payload has exactly one free choice
    (which job) and this script already knows how to answer that one from the tree it is standing in.

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

        powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-ci-floor.ps1"
        powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-ci-floor.ps1" -Apply

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

.PARAMETER SharedRefOverride
    The ref the three write runners check the shared scripts out at, used instead of resolving this
    plugin's release tag over the network. For the test suite, like -RulesJsonOverride. A consumer
    never types it.

.EXAMPLE
    .\scripts\task\adopt-ci-floor.ps1
    .\scripts\task\adopt-ci-floor.ps1 -Apply
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$RulesJsonOverride = '',
    [string]$SharedRefOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Dual-context repo root: a consumer running the plugin mirror gets it from CLAUDE_PROJECT_DIR, the
# source's root copy falls back to the git root. Same resolution as every other mirrored script.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'adopt-ci-floor.ps1'

# repo-config.ps1 first and optional, exactly as adopt-workflow-folder loads it: it supplies the repo
# slug (Get-RepoName) and any trunk override, and every read below has a fallback.
$repoConfig = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
    try { . $repoConfig } catch { Write-Warning "scripts/repo-config.ps1 failed to load ($(Format-SafeProseToken -Value $_.Exception.Message)) -- the built-in defaults are used." }
}

. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
# THE PRINT-SAFETY CONVENTION (issue #1972, security review). The section 1 '[gap]' arm below fills a
# ruleset payload with a job CONTEXT that can come off a workflow's `name:` VALUE -- arbitrary text off
# a line of the CONSUMER'S OWN YAML, not the restricted job-key charset -- so it is foreign text by the
# same reasoning ref-print-lib.ps1 was built for, not merely untrusted-in-theory. This is the one
# definition of "safe to paste" and of the prose-display strip; a fourth hand-rolled copy of either is
# exactly what pr-issues.tests.ps1's THREE-libs assert exists to catch.
. (Join-Path $PSScriptRoot '..\lib\ref-print-lib.ps1')
# Get-WriteTargetReparsePoint (issue #2546): a runner this floor creates is refused when its path passes
# through a symlink or junction -- a junctioned .github/ -- because the write would land outside the repo.
. (Join-Path $PSScriptRoot '..\lib\write-target-lib.ps1')

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
# repo-settings.yml, the read-only runner scaffolded below, is deliberately NOT pinned -- it holds
# contents: read and no secret, and this repo's own copy of it is unpinned for that same reason.
#
# HOW THIS PIN GETS REFRESHED, which is the half a generated pin does not get for free. It is ONE
# variable rather than four literals, and pin-parity.tests.ps1 asserts it still equals the SHA in this
# repo's own fold-on-merge.yml. So the pin has a single refresh point and a gate that fails the moment
# a hand-maintained workflow here is bumped and the scaffolder is not -- a consumer's floor cannot
# quietly fall behind the floor this repo runs on itself.
$checkoutPin = 'actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09 # v5'

# THE SHARED SCRIPTS ARE PINNED TOO -- IN THE SAME THREE WRITE RUNNERS, AND ONLY THERE (issue #2333).
# Pinning the ACTION is half of the job. The second checkout in each of those runners fetches this
# workflow's own scripts out of $sharedRepo and then EXECUTES them, in a job that holds FOLD_PUSH_TOKEN
# (fold, merge-on-green) or issues: write (resolves). At ref: main, a change landing on the source
# repo's trunk -- a bad merge, a compromised account -- reached standing Contents and Pull requests
# write in every adopted consumer on its next run, with no release in between. So those three check
# the scripts out at the commit the RELEASE THIS SCAFFOLDER CAME FROM was tagged at: the version is read
# off this plugin's own plugin.json, and the tag is resolved to its commit SHA, because a tag can be
# moved by the same account that could push a bad commit and a SHA cannot.
#
# THE READ-ONLY RUNNERS STAY ON ref: main, AND THE #1805 ARGUMENT IS WHY. branch-entry.yml and
# repo-settings.yml hold no write scope and no secret, so tracking the tip costs them nothing worth
# pinning against, and a pinned gate goes on enforcing a stale convention. That argument is right for
# them and was never weighed against a credential (#1851); the pin goes exactly where the credential is.
#
# A PIN HAS TO MOVE, AND THIS SCRIPT IS WHAT SAYS SO. It writes a runner once and never rewrites it, so
# re-running it reports every existing write runner still on main or pinned behind the version running
# now (section 2 below). Bumping it is editing one ref: line per file -- the value this run prints.
#
# WHERE THE SHA CANNOT BE RESOLVED (offline, no git), THE TAG IS WRITTEN AND THE RUN SAYS SO. A tag is
# weaker than a SHA and far stronger than main, and refusing the floor over it would leave the fold
# unguarded instead. Where not even the version can be read, the runners fall back to main, loudly.
function Get-ScaffoldingPluginVersion {
    # Two layouts: the plugin mirror (scripts/task -> the plugin root, which holds .claude-plugin/) and
    # this script's source copy (scripts/task -> the repo root, which holds plugins/dkj-policy/).
    foreach ($rel in @('..\..\.claude-plugin\plugin.json', '..\..\plugins\dkj-policy\.claude-plugin\plugin.json')) {
        $p = Join-Path $PSScriptRoot $rel
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
        try {
            $v = [string]((Get-Content -LiteralPath $p -Raw | ConvertFrom-Json).version)
            if ($v -match '^\d+\.\d+\.\d+$') { return $v }
        } catch { }
    }
    return ''
}

$writeRunnerVersion = Get-ScaffoldingPluginVersion
$writeRunnerRef = $sharedRef
$writeRunnerPinState = 'unpinned'
if ($SharedRefOverride) {
    # The test suite's route: a runner with no network still has to be read for WHERE the pin lands.
    $writeRunnerRef = $SharedRefOverride
    $writeRunnerPinState = 'override'
} elseif ($writeRunnerVersion) {
    $writeRunnerTag = "v$writeRunnerVersion"
    $lsRemote = Invoke-NativeCapture -FilePath 'git' -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds -Arguments @('ls-remote', "https://github.com/$sharedRepo.git", "refs/tags/$writeRunnerTag", "refs/tags/$writeRunnerTag^{}")
    $tagSha = ''
    if ($lsRemote.ExitCode -eq 0) {
        # An annotated tag answers twice: the tag object, and the commit it points at under '^{}'. The
        # commit is the one actions/checkout can take as a ref, so the peeled line wins when present.
        foreach ($line in @($lsRemote.Output)) {
            $m = [regex]::Match([string]$line, '^(?<sha>[0-9a-f]{40})\s+refs/tags/(?<tag>\S+)$')
            if (-not $m.Success) { continue }
            if ($m.Groups['tag'].Value -eq "$writeRunnerTag^{}") { $tagSha = $m.Groups['sha'].Value; break }
            if ($m.Groups['tag'].Value -eq $writeRunnerTag) { $tagSha = $m.Groups['sha'].Value }
        }
    }
    if ($tagSha) {
        $writeRunnerRef = "$tagSha # $writeRunnerTag"
        $writeRunnerPinState = 'sha'
    } else {
        $writeRunnerRef = $writeRunnerTag
        $writeRunnerPinState = 'tag'
    }
}

# The comment every write runner carries above its shared checkout, so the pin is argued where it sits.
$writeRunnerPinComment = @(
    '      # THE SHARED SCRIPTS ARE PINNED TO A RELEASE, NOT ref: main (issue #2333). This job holds a write',
    '      # credential, and code fetched at the tip of another repository would run beside it with no',
    '      # release in between. Move the pin when you update the dkj-policy plugin: re-running',
    '      # adopt-ci-floor.ps1 reports a runner pinned behind the version it came from.'
)

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
# $repoSlug IS HOISTED HERE (issue #1972). It used to live inside the `else` branch below, so under
# Set-StrictMode -Version Latest it was undefined on the -RulesJsonOverride path -- exactly the path
# the test suite takes, and the one the printed ruleset instruction in section 1 below also needs it
# on. Resolved from the Get-RepoName seam first, same as always; the gh fallback stays inside the
# network-reading branch below, because a consumer running with an override file and no network has
# no way to answer it and none is owed one -- section 1 prints a placeholder there instead.
$repoSlug = ''
if (Test-FunctionDefined 'Get-RepoName') { $repoSlug = [string](Get-RepoName) }
if ($RulesJsonOverride) {
    if (Test-Path -LiteralPath $RulesJsonOverride -PathType Leaf) {
        $rulesJson = [System.IO.File]::ReadAllText($RulesJsonOverride)
        $rulesSource = "the payload in $RulesJsonOverride"
    }
} else {
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

        THAT SENTENCE IS TRUE ONLY BECAUSE THE TEXT IS NORMALISED TO LF ON READ (inbound #2237). On a
        CRLF checkout the name half of "both" collected nothing, so "unmatched" stopped meaning what it
        says here and started meaning "this reader cannot see names at all". The reasoning, and why the
        damage reached past the note into the auto-filled ruleset, is at the read itself below.
    #>
    param([Parameter(Mandatory)][string]$WorkflowDir)

    $facts = @()
    if (-not (Test-Path -LiteralPath $WorkflowDir -PathType Container)) { return @() }
    foreach ($f in @(Get-ChildItem -LiteralPath $WorkflowDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.yml', '.yaml') })) {
        # NORMALISED TO LF ON READ, ONCE, BEFORE ANY REGEX BELOW SEES IT (inbound #2237).
        # Not a tidy-up. The job-`name:` capture below is anchored on '$', and .NET's multiline '$'
        # matches only immediately before a '\n' -- so against a CRLF file '[^\r\n]*' stops before the
        # '\r' and the anchor fails, collecting NO names at all. Its neighbour, the job-KEY capture,
        # survives the same file only by accident, because its '\s*$' absorbs the '\r' first.
        #
        # ONE OF A PAIR CRLF-TOLERANT AND THE OTHER NOT IS WORSE THAN A WRONG NOTE. $prJobIds then holds
        # ONE id where LF holds two (the key and the name), and ONE is exactly the count the paste-ready
        # ruleset call further down auto-fills on -- so a Windows consumer with a single named job in a
        # single pull_request workflow is handed a ruleset requiring the job KEY, while GitHub reports
        # that check under its NAME. A required check that never reports leaves every pull request
        # pending forever. On LF the same tree declines to auto-fill and prints the candidate list, which
        # is the safe path: the bug does not merely mute a note, it moves the script onto the branch it
        # would otherwise have refused. Measured from a consumer on `core.autocrlf=true`; this repo never
        # hit it because .gitattributes pins `eol=lf` AND its own ci.yml job declares no `name:`, so the
        # broken half of the pair had nothing to capture either way.
        #
        # NORMALISING BEATS ANCHORING BOTH ON '\r?$': it closes the whole class rather than the two
        # instances visible today, so a regex added to this function later cannot reintroduce it. The
        # `on:`/`jobs:` matchers keep their explicit '\r?\n' -- harmless on LF, and the honest record
        # that this text has more than one possible shape on disk. Same normalise-on-read
        # subagent-shared-lib.ps1 already does. It does NOT weaken the single-line guarantee the
        # auto-fill block downstream names this capture for: '[^\r\n]*' admits no newline of either
        # kind, before the normalisation or after it.
        $text = ([System.IO.File]::ReadAllText($f.FullName)) -replace "`r`n", "`n"

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

        # THE WORKFLOW'S OWN TOP-LEVEL name:, which is what a workflow_run trigger matches on (#2329) --
        # not the file name and not a job. Column 0 only, so a job's `name:` at four spaces is never it.
        # '' where the file declares none: GitHub then names the workflow after its path, and a runner
        # that guessed that spelling would be matching on something this reader did not see.
        $wfNameMatch = [regex]::Match($text, '(?m)^name:\s*(?<name>\S[^\r\n]*)$')
        $wfName = if ($wfNameMatch.Success) { ($wfNameMatch.Groups['name'].Value -replace '\s+#.*$', '').Trim().Trim('''"') } else { '' }
        # A BLOCK SCALAR (`name: >` or `name: |`) keeps the real name on the lines below, which this
        # one-line reader does not follow -- so it is treated as no name rather than as the indicator.
        if ($wfName -match '^[>|][+-]?\d*$') { $wfName = '' }

        $facts += [pscustomobject]@{
            Name          = $f.Name
            Rel           = ".github/workflows/$($f.Name)"
            WorkflowName  = $wfName
            JobIds        = @($ids | Sort-Object -Unique)
            HasMergeGroup = $hasMergeGroup
            OnPullRequest = $onPullRequest
        }
    }
    return @($facts)
}

$workflowDir = Join-Path $repoRoot '.github\workflows'
$workflows = Get-WorkflowFacts -WorkflowDir $workflowDir

# --- The CI skeleton, for a consumer with NO pull_request workflow at all (issue #1843) --------------
# Section 1 below already tells such a consumer how to make a check required; until now it could only
# print a placeholder job id, because there was nothing in the tree to name. This is the fourth thing
# this command offers: a minimal, adoptable .github/workflows/ci.yml that gives such a consumer
# something to require. THE BODY IS DELIBERATELY EMPTY -- "a skeleton is portable; the body is not" is
# the #1843 assessment's own phrase for it: lint/test/build steps are this repo's own choice, never this
# workflow's to assert, exactly the same line ci.yml itself would not cross if it tried to travel.
#
# OFFERED ONLY WHEN NOTHING ELSE ALREADY TRIGGERS ON pull_request. A consumer running CI under any other
# file name already has what this exists to give; placing a second, empty workflow beside a real one
# would be noise. Once either file carries that trigger, $workflows picks it up on the very next run and
# this arm has nothing left to offer -- no separate "already adopted" state to track.
$ciSkeletonRel = '.github/workflows/ci.yml'
$ciSkeletonAbs = Join-Path $repoRoot ($ciSkeletonRel -replace '/', '\')
$noPrWorkflowAtAll = (@($workflows | Where-Object { $_.OnPullRequest })).Count -eq 0
$ciSkeletonOffered = $noPrWorkflowAtAll -and -not (Test-Path -LiteralPath $ciSkeletonAbs)

# THE JOB'S NAME COMES FROM THE SEAM THAT ALREADY OWNS THIS QUESTION, Get-CiTestCheckName -- the same
# 'decide' record open-pr's own local-gate-skip logic reads (issue #1715). A consumer who has already
# declared it gets a skeleton whose check IS the one open-pr is already looking for, rather than a
# second name to reconcile by hand. Undeclared or empty falls back to the bare job key 'ci'.
#
# HOISTED TO SCRIPT SCOPE, SHARED WITH SECTION 1's RULESET ADVICE (Victor and Sebastian's review on
# #1843). A YAML double-quoted scalar and a JSON string literal forbid exactly the same two characters
# ('"' and '\', either of which would break out of the literal) and are vulnerable to exactly the same
# console-repainting class of control/format character -- so one predicate serves both sites rather
# than two copies under two names that a reader has to trust are kept in sync by hand. Section 1's own
# call site (Get-DirectPushBlockingRules' auto-fill, below) is the one this function was pulled out of;
# it needed no change beyond the name, because the two were already checking the same thing.
function Test-QuotedScalarSafe {
    <#
        Value -- text about to be interpolated, unescaped, into a hand-laid double-quoted scalar: a
        YAML job `name:` field (this skeleton's own use) or a JSON string literal inside a PowerShell
        here-string (section 1's ruleset-advice use, issue #1972). Returns $true when it may be used
        as-is. Two things are checked, because only two things can go wrong at either site:
          - '"' or '\' would break out of the literal (both forms escape both characters, and nothing
            here re-implements either escaper);
          - a \p{Cc}/\p{Cf}/\p{Zl}/\p{Zp}/\p{Mn}/\p{Me} character would repaint the console when the
            template carrying this value is Write-Host'd -- the same hazard Get-DisplayRef exists for,
            checked here via that same function rather than by retyping its pattern.
        REFUSE, DO NOT ESCAPE: a hand-rolled escaper for either literal shape is the fourth-copy risk
        ref-print-lib.ps1 exists to avoid, and getting one wrong is a payload that corrupts the
        generated YAML or JSON while the surrounding prose still says "paste it as-is" or "already
        filled in".
    #>
    param([AllowEmptyString()][AllowNull()][string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return $false }
    if ($Value.IndexOfAny([char[]]@('"', '\')) -ge 0) { return $false }
    return ((Get-DisplayRef -Ref $Value) -ceq $Value)
}

$ciSkeletonDeclaredName = if (Test-FunctionDefined 'Get-CiTestCheckName') { [string](Get-CiTestCheckName) } else { '' }
$ciSkeletonJobKey = 'ci'
$ciSkeletonCheckName = if (Test-QuotedScalarSafe -Value $ciSkeletonDeclaredName) { $ciSkeletonDeclaredName } else { $ciSkeletonJobKey }

$ciSkeletonRunner = @(
    '# A minimal CI workflow, scaffolded because nothing in this repo triggered on pull_request at all',
    '# (issue #1843). Its only purpose is to give this repo something to require on the trunk, which is',
    '# what switches ship-pr''s detect-and-rebase staleness guard on -- see this command''s own section 1:',
    '# with no required check named, that guard has no certificate to date and is simply off.',
    '#',
    '# THE BODY IS DELIBERATELY EMPTY. What a merge should have to prove -- lint, tests, a build -- is',
    '# this repo''s own choice, never this workflow''s to assert. REPLACE THE PLACEHOLDER STEP BELOW',
    '# before making this check required.',
    '#',
    '# merge_group IS ALREADY HERE, EVEN IF THIS REPO RUNS NO QUEUE (issue #1325). It is inert until one',
    '# exists, and a total merge outage the day one is switched on without it, on any workflow carrying a',
    '# required check -- cheaper to place now than to remember later.',
    '#',
    '# THE JOB''S name: NAMES THE CHECK adopt-ci-floor.ps1''s own ruleset advice already assumes: it reads',
    '# Get-CiTestCheckName, so a repo that has declared that seam gets a skeleton whose check IS the one',
    '# open-pr''s local-gate-skip logic already looks for, rather than a second name to reconcile by hand.',
    'name: CI',
    '',
    'permissions:',
    '  contents: read',
    '',
    'on:',
    '  pull_request:',
    '  merge_group:',
    '',
    'jobs:',
    ('  ' + $ciSkeletonJobKey + ':'),
    ('    name: "' + $ciSkeletonCheckName + '"'),
    '    runs-on: ubuntu-latest',
    '    # THE ONE NUMBER IN THIS FILE YOU ARE EXPECTED TO RE-SIZE (issue #2296). A job with no',
    '    # timeout-minutes runs to GitHub''s SIX-HOUR default, and a wedged job that carries a REQUIRED',
    '    # check does not fail the branch -- it leaves the check unreported, which reads as "still',
    '    # running" to every gate and to every person. 30 is a placeholder for a placeholder step: when',
    '    # you replace the step below with this repo''s own lint/test/build, re-size this to roughly',
    '    # twice the slowest run you have actually measured.',
    '    timeout-minutes: 30',
    '    steps:',
    '      - uses: actions/checkout@v5',
    '      - name: Replace this with whatever this repo wants a merge to prove',
    '        run: |',
    '          echo "TODO (issue #1843 template): this step is a placeholder."',
    '          echo "Replace it with this repo''s own lint/test/build, then make this check required."',
    '          exit 0'
)

# --- The runners, consumer-shaped ---------------------------------------------------------------
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
    '    # SKIP A FOLD-ONLY PUSH AT THE JOB LEVEL, NOT WITH A STEP-LEVEL if: -- A JOB SKIPPED BY if: IS',
    '    # NOT BILLED AT ALL, WHERE A SKIPPED STEP STILL PAYS FOR THE RUNNER STARTING (issue #2487,',
    '    # metered Actions minutes in a private consumer). About half of all trunk pushes here are',
    '    # `fold:` commits -- this job''s OWN OUTPUT, carrying nothing left to fold. The source repo''s',
    '    # own ci.yml already couples to this exact format for the same reason, so this is a second',
    '    # reader of an existing rule rather than a new coupling.',
    '    #',
    '    # EXACTLY ONE COMMIT, NOT MERELY A `fold:` SUBJECT ON THE HEAD. A `git push` can carry several',
    '    # commits at once, and github.event.head_commit is only the LAST of them -- a batch push whose',
    '    # head happens to be a fold commit can still carry real, unfolded work earlier in the same push,',
    '    # which this job must not skip. github.event.commits[0].id == github.event.head_commit.id is',
    '    # true only when the push carries exactly that one commit; commits[0] always exists once a push',
    '    # carries any commit at all, and an empty array reads it as null, which never equals a real SHA',
    '    # -- so a push this expression cannot classify RUNS, fail-open like every other guard here.',
    '    #',
    '    # SAFE HERE BECAUSE A FOLD COMMIT IS THIS JOB''S OWN OUTPUT: skipping fold-all mode on it costs',
    '    # nothing. Whatever it would have folded is still unfolded on the trunk, and the next trunk',
    '    # push -- whatever it is -- runs this job again and folds it then.',
    '    if: ${{ !(startsWith(github.event.head_commit.message, ''fold:'') && github.event.commits[0].id == github.event.head_commit.id) }}',
    '    # 10 minutes against a job that measures well under one (issue #2296). Without it a wedge here',
    '    # runs to GitHub''s six-hour default while holding a PAT that bypasses the trunk ruleset -- and',
    '    # nobody is watching this runner, because its whole reason for existing is that the shipping',
    '    # session has already gone.',
    '    timeout-minutes: 10',
    '    steps:',
    '      # ref: the trunk tip, not the pushed SHA -- see the header comment (inbound #1543). This job',
    '      # asks whether the trunk carries a leftover NOW, and a fold ship-pr already pushed on top of',
    '      # the merge commit must not read as still-unfolded here.',
    ('      - uses: ' + $checkoutPin),
    '        with:',
    ('          ref: ' + $trunk),
    '          token: ${{ secrets.FOLD_PUSH_TOKEN }}',
    ''
    ) + $writeRunnerPinComment + @(
    '      - name: Fetch the shared workflow scripts',
    ('        uses: ' + $checkoutPin),
    '        with:',
    ('          repository: ' + $sharedRepo),
    ('          ref: ' + $writeRunnerRef),
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
    '    # SKIP A FOLD-ONLY PUSH AT THE JOB LEVEL -- A JOB SKIPPED BY if: IS NOT BILLED AT ALL (issue',
    '    # #2487). This file''s own header already names the cost this closes: a PAT push (from the fold',
    '    # runner''s own commit) triggers this workflow same as any other, so every shipped branch already',
    '    # starts this job twice. See fold-on-merge.yml''s matching comment for why exactly one commit,',
    '    # not merely a `fold:` subject on the head, and why this is a second reader of an existing rule',
    '    # rather than a new coupling.',
    '    #',
    '    # SAFE HERE BECAUSE A DIRECTLY-PUSHED FOLD COMMIT RESOLVES NO PULL REQUEST. This job reads the',
    '    # pushed RANGE and resolves each commit''s own PR to verify its closing keywords; a fold commit',
    '    # is authored straight onto the trunk by this repo''s own tooling and carries no PR of its own --',
    '    # this job''s own run on the MERGE that triggered that fold already verified whatever that PR',
    '    # closed. A lone fold-commit push has nothing here to resolve.',
    '    #',
    '    # NOT SYMMETRIC WITH fold-on-merge.yml, AND WORTH SAYING SO. That job''s skip self-heals: fold-all',
    '    # mode re-reads the trunk TIP on the next push, so anything a skipped run would have folded is',
    '    # still there to find. This job reads only the pushed before..sha RANGE, so a skipped push''s',
    '    # resolves check is gone for good, not merely deferred. BOUNDED rather than open-ended: ship-pr',
    '    # always writes its merge commit as `merge: <branch> (#N)`, and this repo''s own fold commits are',
    '    # always pushed alone -- so the only way to hit this is a directly-pushed, single-commit push',
    '    # from OUTSIDE ship-pr whose subject happens to start with `fold:` (a hand-titled squash merge,',
    '    # say), which would then permanently lose whatever pull request it closed.',
    '    if: ${{ !(startsWith(github.event.head_commit.message, ''fold:'') && github.event.commits[0].id == github.event.head_commit.id) }}',
    '    # 10 minutes, same reasoning as the fold runner (issue #2296) -- and this one holds issues:',
    '    # write, so the six-hour default would be six hours of an unattended job carrying a write scope.',
    '    timeout-minutes: 10',
    '    steps:',
    '      # persist-credentials: false -- this job reads and calls the API, and never pushes. Nothing',
    '      # here needs a git credential left in the workspace.',
    ('      - uses: ' + $checkoutPin),
    '        with:',
    '          persist-credentials: false',
    ''
    ) + $writeRunnerPinComment + @(
    '      - name: Fetch the shared workflow scripts',
    ('        uses: ' + $checkoutPin),
    '        with:',
    ('          repository: ' + $sharedRepo),
    ('          ref: ' + $writeRunnerRef),
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

# A THIRD RUNNER, NOT ABOUT AN UNOBSERVED MERGE AT ALL (issue #1843): does a GitHub-side repo setting
# still match what scripts/repo-config.ps1 declares? It rides along in this same command because this
# is already the one place a consumer builds their CI floor, and it needs no queue and no merge to be
# worth having -- it runs on a schedule, not on a push.
$repoSettingsRunner = @(
    '# Checks whether GitHub-side repo settings still match what this tree declares -- scheduled, not',
    '# merge-triggered, because its subject is a repo setting drifting on its own rather than a PR (issue',
    '# #1843, derived from the source repo''s own .github/workflows/repo-settings.yml, issue #1726).',
    '#',
    '# WHAT THIS CLOSES. A ruleset and a repo''s merge switches are GitHub-side state: nothing in this',
    '# tree changes when they change -- no commit, no gate, no session. Yet scripts/repo-config.ps1''s',
    '# Get-ExpectedRepoSettings is load-bearing for whatever this repo''s own constitution rests on it --',
    '# a direct-on-trunk exception, a fold, a staleness guard -- so the record and the live state could',
    '# disagree indefinitely with nothing saying so. The source repo measured three such drifts in eight',
    '# days before building this: bypass_actors emptied by an org transfer, a merge_queue rule added and',
    '# removed with no trace, and allow_auto_merge left on against its own tree''s record.',
    '#',
    '# A SCHEDULE, NOT A SessionStart HOOK: a hook only reaches whoever happens to open a session, and if',
    '# nobody does, nothing is written down. A scheduled run leaves a DATED record -- every future answer',
    '# is bounded to how long ago this last ran, whether or not anyone was looking.',
    '#',
    '# NOT A REQUIRED CHECK, deliberately. Its subject IS the ruleset, so requiring it would be',
    '# self-referential, and it would stop merges on a switch only the repo owner can flip. A red run plus',
    '# GitHub''s failure e-mail is the signal -- the same non-membership this floor''s other two runners and',
    '# the plugin''s branch-entry gate all keep, each for their own reason.',
    '#',
    '# workflow_dispatch IS NOT DECORATION -- it is how the answer is obtained the day a setting changes on',
    '# purpose, without waiting for the next cron.',
    '#',
    '# THE CHECK NEVER WRITES TO GITHUB. Repo settings are the owner''s surface; this script reads and',
    '# reports, exactly as adopt-ci-floor.ps1''s own required-check ruleset instruction composes a call',
    '# and stops rather than applying it (#1972). The queue instruction stays a UI pointer instead: that',
    '# switch carries policy nobody here has chosen.',
    '#',
    '# ONE FIELD (bypass_actors) IS ADMIN-ONLY AND READS AS UNREADABLE, NOT AS GREEN -- the check''s own',
    '# third verdict. -RequireRead is the floor under that: without it, a token that cannot reach the two',
    '# non-admin endpoints would report every field as not-read and still exit 0 -- a detector reporting',
    '# success while checking nothing.',
    '#',
    '# LEAST PRIVILEGE, AND READ-ONLY: contents: read is the whole permission. The checkout is UNPINNED --',
    '# this job never holds a credential worth pinning against. Contrast the source repo''s OWN tree:',
    '# fold-on-merge.yml and verify-resolved.yml (write-capable) are pinned; repo-settings.yml itself,',
    '# branch-entry.yml and unfolded-entry.yml (read-only, like this job) are not. persist-credentials:',
    '# false because this job never pushes.',
    '#',
    '# The write runners adopt-ci-floor.ps1 places beside this one (fold, resolves, merge-on-green) pin',
    '# both the action (#1904) and the shared scripts they fetch (#2333); this one pins neither, and',
    '# tracks the scripts at main on the #1805 argument, because it holds nothing worth pinning against.',
    '#',
    '# THE SECOND CHECKOUT reaches the check through the plugin''s own tree rather than a copy kept here,',
    '# so this repo shares one definition of "what GitHub-side drift looks like" with the workflow''s',
    '# source instead of holding a second copy free to drift from it -- same reasoning, same shape, as the',
    '# other two runners this command places.',
    '#',
    '# THE TRUNK IS BAKED IN AT SCAFFOLD TIME, from the same Get-TrunkBranchName seam this whole command',
    '# already reads for the other two runners'' triggers. The check ALSO resolves that seam itself at run',
    '# time (given CLAUDE_PROJECT_DIR), so passing it here is not a requirement -- an explicit -Trunk',
    '# always wins over the seam, and the two cannot disagree because they read the same function.',
    '#',
    '# CLAUDE_PROJECT_DIR IS NOT OPTIONAL, on the other two runners'' own reasoning: a mirrored script',
    '# resolves the tree it judges from that variable first, and without it a workspace holding two',
    '# checkouts (this one, and the plugin''s under the path above) leaves which root it reads to chance',
    '# rather than to the consumer''s repo by construction.',
    '#',
    '# WINDOWS: the shared script targets Windows PowerShell 5.1, which is what ''shell: powershell'' is.',
    'name: Repo settings',
    '',
    'permissions:',
    '  contents: read',
    '',
    'on:',
    '  schedule:',
    '    - cron: ''30 6 * * *''',
    '  workflow_dispatch:',
    '',
    'concurrency:',
    '  group: repo-settings',
    '  cancel-in-progress: true',
    '',
    'jobs:',
    '  repo-settings:',
    '    runs-on: windows-latest',
    '    # 10 minutes (issue #2296). This one runs on a SCHEDULE, so a wedge has nobody waiting on it at',
    '    # all -- it simply spends the six-hour default and is found, if ever, in the Actions list.',
    '    timeout-minutes: 10',
    '    steps:',
    '      - uses: actions/checkout@v5',
    '        with:',
    '          persist-credentials: false',
    '',
    '      - name: Fetch the shared workflow scripts',
    '        uses: actions/checkout@v5',
    '        with:',
    ('          repository: ' + $sharedRepo),
    ('          ref: ' + $sharedRef),
    ('          path: ' + $sharedPath),
    '',
    '      - name: GitHub-side settings still match what the tree declares',
    '        shell: powershell',
    '        env:',
    '          GH_TOKEN: ${{ github.token }}',
    '          CLAUDE_PROJECT_DIR: ${{ github.workspace }}',
    '        run: |',
    ('          powershell -NoProfile -ExecutionPolicy Bypass -File ' + $pluginDir + '/lint/check-repo-settings.ps1 -RequireRead -Trunk ' + $trunk),
    '          exit $LASTEXITCODE'
)

# A FOURTH RUNNER, AND THE ONE WHOSE OTHER HALF ALREADY TRAVELS (issue #2329). ship-pr.ps1 is a shared
# script, so its CI-refusal arm reaches every consumer with the plugin: it labels the pull request
# merge-when-green and prints that a sweep will finish the merge. Without this file nothing reads that
# label, so in a consumer the sentence is false and the merge stays owed to a session. Derived from the
# source repo's own .github/workflows/merge-on-green.yml (#2319), in the shape the fold and resolves
# runners above already take.
#
# WHICH WORKFLOWS WAKE IT IS READ OFF THIS TREE, NOT ASSUMED. The source's copy names [CI] because that
# is its own ci.yml's name; a consumer's CI is called whatever they called it. workflow_run matches a
# workflow's top-level name:, so every pull_request workflow declaring one is listed -- plus 'CI' when
# the skeleton above is about to be placed with exactly that name. Each is refused unless
# Test-QuotedScalarSafe vouches for it, because it lands inside a double-quoted YAML scalar. Where none
# survives, the workflow_run trigger is left out rather than guessed, and the schedule carries the sweep
# on its own -- at most three hours later here (#2487; the source repo's own copy stays half-hourly,
# where that latency costs nothing), which is the backstop's whole job anyway.
$mogWakeNames = @($workflows | Where-Object { $_.OnPullRequest -and $_.WorkflowName } | ForEach-Object { $_.WorkflowName })
if ($ciSkeletonOffered) { $mogWakeNames += 'CI' }
$mogWakeNames = @($mogWakeNames | Where-Object { Test-QuotedScalarSafe -Value $_ } | Sort-Object -Unique)
$mogWakeLines = @()
if ($mogWakeNames.Count -gt 0) {
    $mogWakeLines = @(
        '  workflow_run:',
        ('    workflows: [' + ((@($mogWakeNames | ForEach-Object { '"' + $_ + '"' })) -join ', ') + ']'),
        '    types: [completed]'
    )
}

$mergeOnGreenRunner = @(
    '# Finishes a ship whose session is gone: merges a pull request ship-pr armed with merge-when-green',
    '# once its required check turns green (issue #2329, derived from the source repo''s own',
    '# .github/workflows/merge-on-green.yml, issue #2319).',
    '#',
    '# WHAT THIS CLOSES. ship-pr.ps1 refuses to merge on a red or pending required check. When that check',
    '# later turns green -- a re-run, a flaky leg retried -- nothing merged the pull request: the merge was',
    '# owed to a session that had already exited. ship-pr now ARMS such a pull request with the',
    '# merge-when-green label at that refusal, and this job is the sweep that reads the label.',
    '#',
    '# IT ADDS NO GATE OF ITS OWN. The plugin''s pick-merge-on-green.ps1 only asks the tracker which armed',
    '# pull request is owed a merge; the ship is the plugin''s own ship-pr.ps1, so the staleness guard, the',
    '# step-list gate and the DEPLOY lock are the same implementation a live session runs, and it folds and',
    '# verifies the resolves exactly as that session would. Both are reached through a checkout of the',
    '# plugin''s tree rather than copied here.',
    '#',
    '# THE SHIP RUNS IN THIS REPO''S TREE, NOT IN THE CHECKED-OUT PLUGIN TREE. CLAUDE_PROJECT_DIR points',
    '# both scripts at the workspace root, so they read THIS repo''s scripts/repo-config.ps1, its branch',
    '# document and its trunk -- the plugin checkout is only where the code comes from.',
    '#',
    '# THREE TRIGGERS FOR ONE SWEEP, AND THE SWEEP IGNORES WHICH OF THEM WOKE IT. workflow_run gives',
    '# immediacy; the schedule is what makes it durable (whether a partial re-run re-emits workflow_run is',
    '# not a contract worth resting this on); workflow_dispatch is the hand valve. workflow_run RUNS THE',
    '# VERSION OF THIS FILE ON THE DEFAULT BRANCH, so a change here is inert until it is merged.',
    '#',
    '# workflow_run RUNS WITH SECRETS EVEN FOR A PULL REQUEST FROM A FORK, which is why this job reads',
    '# NOTHING out of the event. Everything it acts on comes from the tracker: an open pull request',
    '# carrying a label only ship-pr writes, whose head is a branch of THIS repository -- the picker',
    '# refuses a cross-repository one outright. Neither guard is load-bearing alone.',
    '#',
    '# THE SHIP NEEDS FOLD_PUSH_TOKEN, AND THAT TOKEN NEEDS ONE MORE SCOPE THAN THE FOLD RUNNER''S:',
    '# Pull requests: Read and write, beside Contents: Read and write. A merge made with the job-scoped',
    '# GITHUB_TOKEN starts no workflow runs, so it would land the pull request and silence this repo''s',
    '# CI on the trunk, fold-on-merge.yml and verify-resolved.yml all at once -- the unobserved-merge state',
    '# those runners exist to close. Without the scope the merge fails with a 403, loudly; it can never',
    '# merge without folding.',
    '#',
    '# ONE SWEEP AT A TIME, REPO-WIDE, AND NOT CANCELLED: this job merges and folds, and two concurrent',
    '# sweeps would race to ship the SAME pull request. A sweep re-reads the tracker when it starts, so a',
    '# dropped duplicate pending run costs nothing.',
    '#',
    '# WINDOWS: the shared scripts target Windows PowerShell 5.1, which is what ''shell: powershell'' is.',
    'name: Merge on green',
    '',
    '# The job token only reads; the write half arrives as FOLD_PUSH_TOKEN on the one step that needs it.',
    'permissions:',
    '  contents: read',
    '  pull-requests: read',
    '',
    'on:'
) + $mogWakeLines + @(
    '  schedule:',
    '    # Every 3 hours: a backstop for what workflow_run misses, not the ordinary path -- sparser than',
    '    # the source repo''s own half-hourly sweep (issue #2487). workflow_run wakes this the moment CI',
    '    # finishes, which is the ordinary path here too; the schedule only has to catch what that',
    '    # trigger misses. The source repo is public, so a windows-latest job costs it nothing on a',
    '    # standard runner and 30 minutes buys latency for free; a private repo is billed per scheduled',
    '    # job START, rounded up to a whole minute, whether or not anything is owed a merge. Half-hourly',
    '    # there is 48 jobs/day, roughly 1,440 billed minutes/month; every 3 hours is 8/day, roughly',
    '    # 240/month.',
    '    - cron: ''0 */3 * * *''',
    '  workflow_dispatch:',
    '',
    'concurrency:',
    '  group: merge-on-green',
    '  cancel-in-progress: false',
    '',
    'jobs:',
    '  merge-on-green:',
    '    runs-on: windows-latest',
    '    # 45 minutes, longer than the other runners because this one waits on CI on purpose: ship-pr may',
    '    # bring a stale branch forward and re-certify it, and each lap is a full CI cycle. Re-size it to',
    '    # this repo''s own CI duration; the cap is a wedge detector, against GitHub''s six-hour default.',
    '    timeout-minutes: 45',
    '    steps:',
    '      # The trunk, not the event''s head: the sweep asks the tracker which pull request is owed a merge,',
    '      # and on a scheduled run there is no head at all. Shallow here, deepened only when there is',
    '      # something to ship. FOLD_PUSH_TOKEN is persisted into the workspace git config, which is what',
    '      # lets ship-pr''s own fold commit push past the trunk ruleset -- the fold runner''s reasoning.',
    ('      - uses: ' + $checkoutPin),
    '        with:',
    ('          ref: ' + $trunk),
    '          token: ${{ secrets.FOLD_PUSH_TOKEN }}',
    ''
    ) + $writeRunnerPinComment + @(
    '      - name: Fetch the shared workflow scripts',
    ('        uses: ' + $checkoutPin),
    '        with:',
    ('          repository: ' + $sharedRepo),
    ('          ref: ' + $writeRunnerRef),
    ('          path: ' + $sharedPath),
    '          persist-credentials: false',
    '',
    '      # The picker reads with the job-scoped token, not the PAT: it only lists pull requests and',
    '      # their checks, and the standing credential stays out of every step that does not need it.',
    '      - name: Is any armed pull request owed a merge?',
    '        id: pick',
    '        shell: powershell',
    '        env:',
    '          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}',
    '          GH_REPO: ${{ github.repository }}',
    '          CLAUDE_PROJECT_DIR: ${{ github.workspace }}',
    '        run: |',
    ('          powershell -NoProfile -ExecutionPolicy Bypass -File ' + $pluginDir + '/ci/pick-merge-on-green.ps1'),
    '          exit $LASTEXITCODE',
    '',
    '      # THE BRANCH ARRIVES THROUGH env:, NOT THROUGH ${{ }} INSIDE run:. A head ref is chosen by',
    '      # whoever opened the pull request; the picker has already refused any name outside a plain',
    '      # charset, and this is the second half of that same guard.',
    '      - name: Ship it',
    '        if: ${{ steps.pick.outputs.picked == ''true'' }}',
    '        shell: powershell',
    '        env:',
    '          GH_TOKEN: ${{ secrets.FOLD_PUSH_TOKEN }}',
    '          GH_REPO: ${{ github.repository }}',
    '          CLAUDE_PROJECT_DIR: ${{ github.workspace }}',
    '          SHIP_BRANCH: ${{ steps.pick.outputs.branch }}',
    '          SHIP_PR: ${{ steps.pick.outputs.pr }}',
    '          SHIP_SHA: ${{ steps.pick.outputs.sha }}',
    '        run: |',
    '          git config user.name "github-actions[bot]"',
    '          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"',
    '',
    '          # THE PLUGIN CHECKOUT SITS INSIDE THIS WORKSPACE, AND ship-pr READS THE TREE AS DIRTY BECAUSE',
    '          # OF IT. Excluded locally, so the fold runs in place on the trunk as it would in a session',
    '          # rather than detouring through a temporary worktree. .git/info/exclude is never committed.',
    ('          Add-Content -LiteralPath .git/info/exclude -Value ''/' + $sharedPath + '/'''),
    '',
    '          # Widen the refspec before deepening: a checkout with ref: narrows remote.origin.fetch to',
    '          # the trunk, so an --unshallow alone would not know the branch this job is here to ship.',
    '          # The full history is what ship-pr''s staleness walk needs to be sound.',
    '          git remote set-branches origin ''*''',
    '          git fetch --unshallow --quiet origin',
    '          if ($LASTEXITCODE -ne 0) {',
    '            Write-Error "could not deepen this shallow clone -- ship-pr''s staleness walk would be unsound, so nothing was merged."',
    '            exit 1',
    '          }',
    '',
    '          git checkout --quiet $env:SHIP_BRANCH',
    '          if ($LASTEXITCODE -ne 0) {',
    '            Write-Error "could not check out the head branch of PR #$($env:SHIP_PR) -- nothing was merged."',
    '            exit 1',
    '          }',
    '',
    '          # ship-pr dot-sources THIS checkout''s scripts/repo-config.ps1, so it has to be the commit the',
    '          # picker judged -- and the picker refused any diff touching scripts/, .github/ or the plugin',
    '          # checkout path (#2338). A push after the pick stops the job; the next sweep judges it.',
    '          $head = (git rev-parse HEAD).Trim()',
    '          if ($head -ne $env:SHIP_SHA) {',
    '            Write-Error "PR #$($env:SHIP_PR)''s head moved after the pick ($($env:SHIP_SHA) -> $head) -- nothing was run or merged."',
    '            exit 1',
    '          }',
    '',
    '          # -SkipLint -SkipTests, and this job must not omit them: the sweep picked this pull request',
    '          # BECAUSE its required check is green on this exact head, and that certificate is what the',
    '          # merge is allowed on. Re-running the local gates here would prove nothing it does not carry.',
    '          Write-Host "merge-on-green: running ship-pr.ps1 on ''$env:SHIP_BRANCH'' for PR #$env:SHIP_PR"',
    ('          powershell -NoProfile -ExecutionPolicy Bypass -File ' + $pluginDir + '/release/ship-pr.ps1 -SkipLint -SkipTests'),
    '          exit $LASTEXITCODE'
)

# QueueRelated MARKS THE TWO TARGETS AN ACTIVE QUEUE MAKES URGENT (fold, resolves-verification) AGAINST
# THE ONE THAT ISN'T (repo-settings). Without this flag, a missing repo-settings.yml would be reported
# as a live defect purely because a queue happens to be active elsewhere in the same repo -- a setting
# drifting has nothing to do with whether this repo runs a merge queue.
$targets = @(
    @{ Rel = '.github/workflows/fold-on-merge.yml';   Content = (($foldRunner -join $nl) + $nl);     What = 'the fold, which the queue takes away from the shipping session'; QueueRelated = $true },
    @{ Rel = '.github/workflows/verify-resolved.yml'; Content = (($resolvesRunner -join $nl) + $nl); What = 'the resolves verification, which the queue takes away too'; QueueRelated = $true },
    @{ Rel = '.github/workflows/repo-settings.yml';   Content = (($repoSettingsRunner -join $nl) + $nl); What = 'does a GitHub-side repo setting still match what the tree declares'; QueueRelated = $false },
    # NOT QUEUE-RELATED: under a queue ship-pr enqueues rather than refusing on CI, so nothing is armed.
    @{ Rel = '.github/workflows/merge-on-green.yml';  Content = (($mergeOnGreenRunner -join $nl) + $nl); What = 'the sweep that merges a pull request ship-pr armed with merge-when-green once its check turns green'; QueueRelated = $false }
)
# THE FOURTH TARGET IS CONDITIONAL, UNLIKE THE OTHER THREE (issue #1843): it is offered only when
# nothing in the tree triggers on pull_request at all, never merely because this one file is absent --
# a consumer running CI under a different file name must not be handed a second, empty workflow beside
# their real one. Appended rather than folded into the literal above, so that condition stays readable
# beside the flag it reads instead of buried inside a one-line hashtable.
if ($ciSkeletonOffered) {
    $targets += @{ Rel = $ciSkeletonRel; Content = (($ciSkeletonRunner -join $nl) + $nl); What = 'a minimal CI workflow to require, for a repo with no pull_request check at all'; QueueRelated = $false }
}

# THE ONLY TARGET THAT NEEDS FOLD_PUSH_TOKEN. Tracked by name rather than by "was anything created this
# run", because with three targets that counter no longer says which file is missing: a repo that is
# only missing repo-settings.yml (no secret involved at all) would otherwise be told to go create one.
$foldRunnerRel = '.github/workflows/fold-on-merge.yml'
# THE SECOND TARGET THAT NEEDS IT, AND THE ONE THAT NEEDS IT WIDER (#2329): merging needs Pull requests:
# write on top of the fold's Contents: write. Tracked by name for the same reason as the fold runner.
$mergeOnGreenRunnerRel = '.github/workflows/merge-on-green.yml'
# THE THREE THAT HOLD A WRITE CREDENTIAL, and therefore the three whose shared scripts are pinned (#2333).
$writeRunnerRels = @($foldRunnerRel, '.github/workflows/verify-resolved.yml', $mergeOnGreenRunnerRel)

function Write-WriteRunnerPinVerdict {
    <#
        One line about the ref an EXISTING write runner fetches the shared scripts at (#2333): on main,
        pinned behind the release this run came from, pinned at a SHA it cannot date, or unreadable.
        Silent where the pin is at or ahead of this release -- that is the ordinary state.

        READ IN THE SHAPE THIS SCAFFOLDER WRITES, AND NO FURTHER: the `ref:` of the same ten-space
        `with:` block as a `repository:` naming this repo under either name it has carried (a runner
        scaffolded before the #1769 rename still names the old one). A hand-edited file this cannot
        read is said to be unread, never judged clean.
    #>
    param([string]$Rel, [string]$Text)

    $m = [regex]::Match($Text, '(?m)^ {10}repository:\s*\S*/(?:dkj-claude-plugins|claude-code-specialists)\s*$(?:\n {10}[^\n]*)*?\n {10}ref:[ \t]*(?<ref>[^\s#]+)[ \t]*(?:#[ \t]*(?<tag>\S+))?[ \t]*$')
    if (-not $m.Success) {
        Write-Host "            its shared-scripts ref could not be read, so whether it is pinned was NOT established." -ForegroundColor DarkGray
        return
    }
    $ref = $m.Groups['ref'].Value
    $tag = if ($m.Groups['tag'].Success) { $m.Groups['tag'].Value } else { $ref }
    $bump = if ($writeRunnerPinState -eq 'unpinned') { 'a release commit of the dkj-policy plugin' } else { Get-DisplayRef -Ref $writeRunnerRef }

    $vm = [regex]::Match($tag, '^v?(?<v>\d+\.\d+\.\d+)$')
    if (-not $vm.Success) {
        if ($ref -match '^[0-9a-f]{40}$') {
            Write-Host '            [pin] it fetches the shared scripts at a SHA with no version beside it, so whether that is' -ForegroundColor DarkGray
            Write-Host '            behind this release could not be told.' -ForegroundColor DarkGray
        } else {
            Write-Host "            [pin] it fetches the shared scripts at '$(Get-DisplayRef -Ref $ref)' -- a moving ref, beside a write credential" -ForegroundColor Yellow
            Write-Host "            (#2333). Change that ref: line to $bump." -ForegroundColor Yellow
        }
        return
    }
    if (-not $writeRunnerVersion) { return }
    if ([version]$vm.Groups['v'].Value -lt [version]$writeRunnerVersion) {
        Write-Host "            [pin] it fetches the shared scripts at $(Get-DisplayRef -Ref $tag), behind v$writeRunnerVersion which this run came from." -ForegroundColor Yellow
        Write-Host "            Move that ref: line to $bump." -ForegroundColor Yellow
    }
}

# --- Report ------------------------------------------------------------------------------------------
Write-Host "== adopt-ci-floor -- $repoRoot ==" -ForegroundColor Cyan
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
        # #2248: $w.Rel is a filename read off THIS CONSUMER's own directory -- foreign text.
        Write-Host "            $(Get-DisplayPath -Path $w.Rel) -- $mark" -ForegroundColor DarkGray
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
    Write-Host '' -ForegroundColor Yellow

    if ($ciSkeletonOffered) {
        Write-Host '            NOTHING IN THIS TREE TRIGGERS ON pull_request AT ALL, so section 2 below will' -ForegroundColor Yellow
        Write-Host "            offer to scaffold $ciSkeletonRel -- a minimal, empty CI workflow to require." -ForegroundColor Yellow
        Write-Host "            Its one job is named '$ciSkeletonCheckName'; replace its placeholder step with" -ForegroundColor Yellow
        Write-Host '            whatever this repo wants a merge to prove before making it required (issue #1843).' -ForegroundColor Yellow
        Write-Host '' -ForegroundColor Yellow
    }

    # THE PASTE-READY CALL (#1972). This is the one place in this script that composes a `gh api` call
    # rather than merely pointing at a UI -- see the reasoning at the top of this file for why this arm
    # earns that and the queue (section 3) does not: the payload below has exactly one free choice
    # (which check), and the tree this script is standing in can usually answer that itself.
    #
    # THE CONTEXT IS A JOB, NOT A GUESS. Collected the same way Get-WorkflowFacts already collects a
    # required check's owner above: every job key or job name declared by a workflow that triggers on
    # pull_request. Exactly one such id across the whole tree, AND SAFE TO PASTE, is filled in directly;
    # everything else -- more than one candidate, none at all, or a lone candidate this script will not
    # vouch for -- is left as an obvious placeholder, and every candidate is printed (as prose, so a
    # foreign one cannot repaint the console) so picking one is a copy from a list rather than a hunt
    # through .github/workflows/.
    #
    # REFUSE, DO NOT ESCAPE (security review on #1972). A job CONTEXT can come off a workflow's `name:`
    # VALUE, which Get-WorkflowFacts reads as arbitrary text off a line of the CONSUMER'S OWN YAML --
    # not the restricted job-key charset. Hand-quoting that into the JSON template below would mean this
    # script inventing a fourth copy of the escape ref-print-lib.ps1 already owns (pr-issues.tests.ps1
    # pins the three files allowed to carry that pattern), and getting it wrong in the one place a wrong
    # answer is a payload that widens conditions.ref_name, flips enforcement, or reshapes the ruleset
    # while the surrounding prose still says "paste it as-is".
    #
    # NOT Test-RefPasteSafe (second security review on #1972). That predicate is right for what it was
    # built for -- a REF interpolated into a SHELL command line -- and wrong for this value, which is
    # neither: it lands inside a JSON STRING LITERAL, inside a PowerShell here-string, and never touches
    # a shell word. Its allowlist has no space, but a GitHub Actions job `name:` routinely has one
    # ('Lint and tests', 'build (ubuntu-latest)') and the check context GitHub reports for such a job
    # IS that name, spaces included -- so judging it against the ref allowlist refused the common case
    # outright and printed a FALSE reason for doing so ("not safe to paste") about a value a JSON string
    # swallows without complaint. Test-QuotedScalarSafe (defined once, at script scope, above -- shared
    # with the CI skeleton's own job-name check, issue #1843) is the narrower, correct predicate: it does
    # NOT widen $script:RefPasteSafePattern to admit a space (that lib's own header already names that
    # repair wrong for the neighbouring case, #1762 -- a wider ref allowlist would also admit a space into
    # a value that DOES reach a shell line elsewhere in this workflow) and it does not retype
    # '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]' as a fourth copy of that pattern (Get-DisplayRef already
    # owns the one definition; pr-issues.tests.ps1 pins the three files allowed to carry it as literal
    # text). A NEWLINE NEVER REACHES IT HERE: Get-WorkflowFacts' own capture for a job `name:` is
    # anchored on '[^\r\n]*$', so a job id or name is already single-line by construction before it ever
    # reaches this predicate -- which is what keeps it from closing the surrounding here-string early
    # (that closes only on a line that STARTS with `'@`).

    $prJobIds = @($workflows | Where-Object { $_.OnPullRequest } | ForEach-Object { $_.JobIds } | Sort-Object -Unique)
    $autoFillContext = $null
    if ($prJobIds.Count -eq 1 -and (Test-QuotedScalarSafe -Value $prJobIds[0])) { $autoFillContext = $prJobIds[0] }
    # NO REAL CANDIDATE, BUT THE SKELETON ABOUT TO BE PLACED HAS ONE (issue #1843): its check name was
    # already proven safe above via the same Test-QuotedScalarSafe call the CI skeleton's own job name
    # uses, so it needs no second proof here. This is the one case where the auto-fill answers for a
    # file that does not exist on disk yet -- correct, because section 2 below
    # places it with exactly this name, in the same run that printed this advice.
    $autoFillFromSkeleton = $false
    if (-not $autoFillContext -and $ciSkeletonOffered) { $autoFillContext = $ciSkeletonCheckName; $autoFillFromSkeleton = $true }
    $rulesetContext = if ($autoFillContext) { $autoFillContext } else { 'REPLACE-WITH-A-JOB-ID-BELOW' }

    # $trunk AND $repoSlug ARE LOWER-RISK -- $trunk off this repo's own Get-TrunkBranchName seam,
    # $repoSlug off GitHub's own owner/repo charset -- but neither is refused a defence this cheap.
    # Same gate, same reasoning, and both fall back to an already-existing placeholder rather than a
    # new one: a repo whose OWN config fails this allowlist is not a case worth a bespoke message.
    $rulesetTrunk = if (Test-RefPasteSafe -Ref $trunk) { $trunk } else { '<trunk>' }
    $repoSlugPasteSafe = [bool]($repoSlug -and (Test-RefPasteSafe -Ref $repoSlug))
    $rulesetSlug = if ($repoSlugPasteSafe) { $repoSlug } else { '<owner>/<repo>' }

    Write-Host '            THIS CREATES A NEW RULESET REQUIRING THAT CHECK ON THE TRUNK -- paste it as-is' -ForegroundColor Yellow
    if ($autoFillFromSkeleton) {
        Write-Host "            (the check the skeleton below will carry, '$autoFillContext', is already filled in --" -ForegroundColor Yellow
        Write-Host '            apply and push it before pasting this, or the ruleset requires a check that does not exist yet):' -ForegroundColor Yellow
    } elseif ($autoFillContext) {
        Write-Host "            (the one candidate job, '$autoFillContext', is already filled in):" -ForegroundColor Yellow
    } else {
        Write-Host '            once you have replaced REPLACE-WITH-A-JOB-ID-BELOW with your own choice:' -ForegroundColor Yellow
        if ($prJobIds.Count -eq 1) {
            Write-Host "            (the one candidate, '$(Get-DisplayRef -Ref $prJobIds[0])', is not safe to paste as-is --" -ForegroundColor Yellow
            Write-Host '            it carries characters this print will not put in a command unescaped. Pick it up' -ForegroundColor Yellow
            Write-Host '            from the list below and quote it yourself for the shell you are in.)' -ForegroundColor Yellow
        }
    }
    if (-not $repoSlug) {
        Write-Host '            THE REPO SLUG COULD NOT BE RESOLVED -- replace <owner>/<repo> yourself.' -ForegroundColor Yellow
    } elseif (-not $repoSlugPasteSafe) {
        Write-Host "            THE REPO SLUG ('$(Get-DisplayRef -Ref $repoSlug)') IS NOT SAFE TO PASTE --" -ForegroundColor Yellow
        Write-Host '            replace <owner>/<repo> with it yourself, quoted for your shell.' -ForegroundColor Yellow
    }
    Write-Host '' -ForegroundColor Yellow
    $rulesetLines = @(
        '$json = @''',
        '{',
        "  ""name"": ""require $rulesetContext on $rulesetTrunk"",",
        '  "target": "branch",',
        '  "enforcement": "active",',
        "  ""conditions"": { ""ref_name"": { ""include"": [""refs/heads/$rulesetTrunk""], ""exclude"": [] } },",
        '  "rules": [',
        '    {',
        '      "type": "required_status_checks",',
        '      "parameters": {',
        "        ""required_status_checks"": [ { ""context"": ""$rulesetContext"" } ],",
        '        "strict_required_status_checks_policy": false',
        '      }',
        '    }',
        '  ]',
        '}',
        "'@",
        "`$json | gh api --method POST repos/$rulesetSlug/rulesets --input -"
    )
    foreach ($ln in $rulesetLines) { Write-Host $ln -ForegroundColor DarkGray }
    Write-Host '' -ForegroundColor Yellow
    # STRICT MODE, NAMED (Sebastian's non-blocking note on #1972). Off is the same choice ship-pr's own
    # staleness guard already rests on: catching a branch up with the trunk is detect-and-rebase's job,
    # not the ruleset's, so a stale-but-green branch is still allowed to merge. Flip it to true instead
    # if you want GitHub itself, rather than ship-pr, to refuse a merge whose branch is behind the trunk.
    Write-Host '            STRICT MODE IS OFF ABOVE, ON PURPOSE: this workflow leaves "is my branch caught up"' -ForegroundColor Yellow
    Write-Host '            to ship-pr''s own detect-and-rebase rather than to GitHub. Set it to true instead if' -ForegroundColor Yellow
    Write-Host '            you want the ruleset itself to refuse a merge whose branch is behind the trunk.' -ForegroundColor Yellow
    Write-Host '' -ForegroundColor Yellow
    if (-not $autoFillContext) {
        Write-Host '            CANDIDATE CHECKS (job id -- from workflow), since more than one exists (or none' -ForegroundColor Yellow
        Write-Host '            does, or the one candidate was not safe to paste): pick the one your merge should' -ForegroundColor Yellow
        Write-Host '            actually wait on.' -ForegroundColor Yellow
        $prWorkflows = @($workflows | Where-Object { $_.OnPullRequest })
        if ($prWorkflows.Count -eq 0) {
            Write-Host '              (no workflow here triggers on pull_request at all)' -ForegroundColor DarkGray
        }
        foreach ($w in $prWorkflows) {
            foreach ($jid in $w.JobIds) {
                # #2248: $w.Rel beside it is the same foreign-filename class $jid was already guarded for.
                Write-Host "              $(Get-DisplayRef -Ref $jid) -- from $(Get-DisplayPath -Path $w.Rel)" -ForegroundColor DarkGray
            }
        }
        Write-Host '' -ForegroundColor Yellow
    }
    Write-Host '            THIS POSTS A NEW RULESET, AND RULESETS LAYER: a trunk already protected by one' -ForegroundColor Yellow
    Write-Host '            gets a second, additive ruleset rather than an edit to the first -- which is' -ForegroundColor Yellow
    Write-Host '            harmless but not always what you want. To fold this rule into an existing' -ForegroundColor Yellow
    Write-Host '            ruleset instead, list them first and edit that one in the UI or via its own id:' -ForegroundColor Yellow
    Write-Host "              gh api repos/$rulesetSlug/rulesets" -ForegroundColor DarkGray
} else {
    foreach ($ctx in $requiredContexts) {
        # #2248: $ctx is the ruleset's required-check CONTEXT NAME off the repo's own ruleset JSON --
        # foreign text, same class Test-CiSuiteCertified already sends through Get-DisplayRef.
        $ctxDisplay = Get-DisplayRef -Ref $ctx
        $owner = @($workflows | Where-Object { $_.JobIds -contains $ctx })
        if ($owner.Count -eq 0) {
            Write-Host "  [note]    required check '$ctxDisplay' matches no job in .github/workflows/ -- it comes from" -ForegroundColor Yellow
            Write-Host '            somewhere else (another app, or a job name this reader cannot see). If it IS an' -ForegroundColor Yellow
            Write-Host '            Actions job, that workflow needs the merge_group trigger too.' -ForegroundColor Yellow
            continue
        }
        foreach ($w in $owner) {
            # #2248: $w.Rel is the consumer's own workflow filename, guarded the same way as $w.Rel above.
            $wRelDisplay = Get-DisplayPath -Path $w.Rel
            if ($w.HasMergeGroup) {
                Write-Host "  [ok]      required check '$ctxDisplay' -> $wRelDisplay, which triggers on merge_group." -ForegroundColor Green
            } elseif ($queueActive) {
                $liveDefects++
                Write-Host "  [ERROR]   required check '$ctxDisplay' -> $wRelDisplay, which does NOT trigger on merge_group," -ForegroundColor Red
                Write-Host "            and a queue is ACTIVE on '$trunk'. That check never reports for a queue entry," -ForegroundColor Red
                Write-Host '            so every merge fails. Add to its on: block, at two spaces of indent:' -ForegroundColor Red
                Write-Host '              merge_group:' -ForegroundColor Red
            } else {
                Write-Host "  [gap]     required check '$ctxDisplay' -> $wRelDisplay, which does NOT trigger on merge_group." -ForegroundColor Yellow
                Write-Host '            Inert today; a TOTAL MERGE OUTAGE the moment a queue is switched on. Add to its' -ForegroundColor Yellow
                Write-Host '            on: block, at two spaces of indent:' -ForegroundColor Yellow
                Write-Host '              merge_group:' -ForegroundColor Yellow
            }
        }
    }
}
Write-Host ''

# 2. THE RUNNERS THIS COMMAND CAN PLACE: new files beside yours, not edits to one of them, which is the
#    same line adopt-workflow-folder draws. Two answer an unobserved merge; the third (repo-settings)
#    answers a GitHub-side setting drifting on its own, and needs neither a queue nor a merge to matter;
#    the fourth (ci.yml, issue #1843) appears only on a trunk with nothing to require at all.
Write-Host '-- 2. the runners this floor places (an unobserved merge; on a schedule, GitHub-side drift; and, if nothing else exists, something to require) --' -ForegroundColor Cyan
$created = 0
$kept = 0
$foldRunnerCreated = $false
$mergeOnGreenRunnerCreated = $false
$writeRunnerCreated = $false
$refused = 0
foreach ($t in $targets) {
    $abs = Join-Path $repoRoot ($t.Rel -replace '/', '\')
    # BEFORE the existence test, as in adopt-workflow-folder (#2540): Test-Path follows a reparse point, so
    # a dangling symlink reads as absent and a junctioned .github/ takes the write outside the repo.
    $reparse = Get-WriteTargetReparsePoint -Path $abs -Root $repoRoot
    if ($reparse) {
        $refused++
        # A refused queue runner is as absent as a missing one, under -Apply too since nothing places it --
        # so it counts toward the live-defect exit code rather than turning an incomplete floor into exit 0.
        if ($queueActive -and $t.QueueRelated) { $liveDefects++ }
        Write-Host "  [refused] $($t.Rel) -- reached through a symlink or junction ($reparse), so writing it would land outside the repo; place it by hand" -ForegroundColor Yellow
        continue
    }
    if (Test-Path -LiteralPath $abs) {
        $kept++
        Write-Host "  [exists]  $($t.Rel) -- left as it is" -ForegroundColor DarkGray
        # AN EXISTING WRITE RUNNER IS READ FOR ITS PIN (#2333), because this is the only moment anything
        # looks at it again: the file is never rewritten, so a floor adopted on ref: main, or pinned at
        # an older release, stays there until somebody is told. Advisory -- the file stays untouched.
        if ($writeRunnerRels -contains $t.Rel) {
            $existing = ([System.IO.File]::ReadAllText($abs)) -replace "`r`n", "`n"
            Write-WriteRunnerPinVerdict -Rel $t.Rel -Text $existing
        }
        continue
    }
    if ($writeRunnerRels -contains $t.Rel) { $writeRunnerCreated = $true }
    # QUEUE-RELATED ONLY: repo-settings.yml missing is an ordinary to-do regardless of queue state, so
    # it must never count toward the ACTIVE-QUEUE-AND-INCOMPLETE-FLOOR exit code below.
    if ($queueActive -and -not $Apply -and $t.QueueRelated) { $liveDefects++ }
    $created++
    if ($t.Rel -eq $foldRunnerRel) { $foldRunnerCreated = $true }
    if ($t.Rel -eq $mergeOnGreenRunnerRel) { $mergeOnGreenRunnerCreated = $true }
    if ($Apply) {
        $dir = Split-Path -Parent $abs
        if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
        [System.IO.File]::WriteAllText($abs, $t.Content, $Utf8NoBom)
        Write-Host "  [created] $($t.Rel) -- $($t.What)" -ForegroundColor Green
    } else {
        $marker = if ($queueActive -and $t.QueueRelated) { '[MISSING]' } else { '[create] ' }
        $colour = if ($queueActive -and $t.QueueRelated) { 'Red' } else { 'Green' }
        Write-Host "  $marker $($t.Rel) -- $($t.What)" -ForegroundColor $colour
    }
}
if ($writeRunnerCreated) {
    switch ($writeRunnerPinState) {
        'sha'      { Write-Host "  [pin]     the write runners fetch the shared scripts at $writeRunnerRef -- this plugin's own release." -ForegroundColor DarkGray }
        'override' { Write-Host "  [pin]     the write runners fetch the shared scripts at $(Get-DisplayRef -Ref $writeRunnerRef) (-SharedRefOverride)." -ForegroundColor DarkGray }
        'tag'      {
            Write-Host "  [pin]     the write runners fetch the shared scripts at the TAG ${writeRunnerRef}: its commit SHA could" -ForegroundColor Yellow
            Write-Host '            not be resolved (git ls-remote did not answer). A tag can be moved and a SHA cannot --' -ForegroundColor Yellow
            Write-Host '            re-run this with a network to write the SHA, or replace the ref: lines by hand.' -ForegroundColor Yellow
        }
        default    {
            Write-Host '  [pin]     this plugin''s version could not be read, so the write runners fetch the shared scripts' -ForegroundColor Yellow
            Write-Host '            at main -- the tip, beside a write credential (#2333). Replace their ref: lines with a' -ForegroundColor Yellow
            Write-Host '            release commit of the dkj-policy plugin before you store FOLD_PUSH_TOKEN.' -ForegroundColor Yellow
        }
    }
}
Write-Host '  [note]    repo-settings.yml runs on a SCHEDULE, not per merge -- it answers a different' -ForegroundColor DarkGray
Write-Host '            question (has a GitHub-side setting drifted since it was declared) and reports' -ForegroundColor DarkGray
Write-Host '            nothing unless scripts/repo-config.ps1 declares Get-ExpectedRepoSettings; an' -ForegroundColor DarkGray
Write-Host '            empty or absent declaration is the default and is a [SKIP] there, not a gap here.' -ForegroundColor DarkGray
# THE SECRET REMINDER NAMES THE FOLD RUNNER SPECIFICALLY, and only fires when THAT target is the one
# missing -- not on the generic $created count, which with three targets no longer says which file that
# was. A repo missing only repo-settings.yml (no secret involved at all) must never be told to go create
# a FOLD_PUSH_TOKEN it does not need.
if ($foldRunnerCreated) {
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
if ($mergeOnGreenRunnerCreated) {
    Write-Host ''
    Write-Host '  THE MERGE-ON-GREEN RUNNER USES THAT SAME FOLD_PUSH_TOKEN, AND NEEDS ONE MORE SCOPE ON IT:' -ForegroundColor Yellow
    Write-Host '  Pull requests: Read and write, beside Contents: Read and write. A merge made with the' -ForegroundColor Yellow
    Write-Host '  job-scoped GITHUB_TOKEN starts no workflow runs, so it would silence this repo''s CI on the' -ForegroundColor Yellow
    Write-Host '  trunk and the fold and resolves runners in one go. Without the scope the merge fails with a' -ForegroundColor Yellow
    Write-Host '  403, loudly, and nothing is merged. Its workflow_run trigger names these workflows:' -ForegroundColor Yellow
    if ($mogWakeNames.Count -gt 0) {
        foreach ($n in $mogWakeNames) { Write-Host "    $(Get-DisplayRef -Ref $n)" -ForegroundColor DarkGray }
    } else {
        Write-Host '    (none -- no pull_request workflow here declares a usable top-level name:, so only the' -ForegroundColor DarkGray
        Write-Host '    every-3-hours schedule wakes it; add a workflow_run trigger by hand if you want it sooner)' -ForegroundColor DarkGray
    }
}
Write-Host ''

# 3. WHAT THIS FLOOR COSTS ON A METERED (PRIVATE) REPO (issue #2487). PURE STATIC TEXT -- no repo-
# visibility check and no network call: this script already refuses to guess at anything it cannot
# read from the tree or a token, and "is this repo private" is exactly that kind of guess. A follow-up
# (#2488) considers ubuntu-latest + pwsh for the runners whose scripts allow it, which would lower the
# per-minute rate further; that migration is out of this script's scope.
Write-Host '-- 3. what this floor costs on a metered (private) repo --' -ForegroundColor Cyan
Write-Host '  Actions minutes are FREE and unlimited on a PUBLIC repo''s standard runners. On a PRIVATE' -ForegroundColor DarkGray
Write-Host '  repo they are METERED against your plan''s included allowance and billed past it: every job' -ForegroundColor DarkGray
Write-Host '  is billed rounded UP to a whole minute even where it runs in seconds, and a Windows minute' -ForegroundColor DarkGray
Write-Host '  costs more than a Linux one -- every runner this floor places is windows-latest.' -ForegroundColor DarkGray
Write-Host '  What starts a billed job, per runner:' -ForegroundColor DarkGray
Write-Host '    fold-on-merge.yml + verify-resolved.yml -- one job EACH per trunk push that is not a lone' -ForegroundColor DarkGray
Write-Host '      fold: commit (skipped at the job level on that push, unbilled -- see section 2 above).' -ForegroundColor DarkGray
Write-Host '    repo-settings.yml -- 1 scheduled job/day, about 30/month.' -ForegroundColor DarkGray
Write-Host '    merge-on-green.yml -- 8 scheduled jobs/day, about 240/month, PLUS one per completed run' -ForegroundColor DarkGray
Write-Host '      of every workflow named in its workflow_run trigger, above.' -ForegroundColor DarkGray
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
Write-Host '-- 4. the queue (optional -- not this workflow''s policy) --' -ForegroundColor Cyan
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
if ($refused -gt 0) {
    Write-Host "$refused runner(s) refused -- reached through a symlink or junction; see the [refused] lines above." -ForegroundColor Yellow
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
