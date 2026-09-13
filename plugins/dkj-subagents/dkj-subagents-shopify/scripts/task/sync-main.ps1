<#
.SYNOPSIS
    Pre-task sync for a Shopify consumer: mirror the live theme into the trunk WITHOUT letting live
    overwrite the trunk's own work (inbound #787, rewritten on inbound #807).

.DESCRIPTION
    A live theme has no locking, no merge and no conflict detection. Third parties edit it through the
    theme editor and the last write wins, silently -- so work in a Shopify repo starts by mirroring live
    into the trunk. A WHOLESALE pull, which is the obvious implementation, knows nothing about what the
    trunk has done since and therefore overwrites it.

    WHY IT SHIPS RATHER THAN BEING WRITTEN PER REPO. Two Shopify consumers wrote this script
    independently, and the first version of it DESTROYED WORK -- one of them recorded the same wholesale
    procedure reverting merged work three times in one week. The exposed party is the next consumer, who
    has no sibling repo to copy from and no reason to suspect that the obvious implementation of "mirror
    live" is the one that eats their unpushed work. The guard got its floor in 4.16.0
    (adopt-shopify-floor); this is the higher-risk half of the same problem.

    THE RULE CHANGED ON AUGUST 21, 2026 (inbound #807), AND THE OLD ONE WAS THE WRONG MEASUREMENT RATHER
    THAN A BUGGY ONE. It read: "has the trunk touched this file since the last sync? then the trunk
    wins". Two failures, and only the first is repairable:

      1. The floor was read with 'git log --grep', which matches ANY LINE of a message. A merge commit
         for a sync branch carries the sync commit's subject in its BODY, so the pattern matched the
         MERGE and the floor landed on HEAD. With the floor at HEAD nothing counts as touched-since and
         the rule passed every file straight through -- the exact no-floor failure it exists to prevent,
         arriving as a GREEN run. Repaired in Get-SyncReferencePoint in two steps: '--no-merges' first
         (inbound #801), and then -- because that removes only the MERGE commits, while any ordinary
         commit whose body opens a line with 'sync' still won -- by matching the pattern against the
         commit SUBJECT rather than through '--grep' at all (inbound #819).
      2. Deeper, and not fixable by repairing the floor: nothing pushes the trunk TO live except the
         per-file release step, and a deletion cannot be pushed that way at all -- so the trunk's changes
         are permanently invisible to live and sink below the floor as soon as one more sync commit
         lands. After that every future sync tries to overwrite them again, forever. In a repo that has
         adopted the changelog model this is not an edge case: "merged but not live yet" is a DESIGNED
         state, and every pending entry names work a wholesale sync would revert.

    SO CONTENT DECIDES NOW, NOT TIME:

        Has this path ever held live's content in the trunk's history? Then the trunk wins. Otherwise
        live wins -- and if the trunk also changed it, nobody wins and a human looks.

    Measured both ways in a consumer before it was built; the numbers are in Test-LiveContentIsOurs. The
    floor survives, demoted: its only remaining job is to notice that live's content is foreign AND the
    trunk changed the same path recently -- both sides moved -- and refuse. A wrong floor now costs an
    extra conflict report, never silent data loss.

    THREE STRUCTURAL CHANGES MAKE IT UNABLE TO DESTROY WORK RATHER THAN MERELY UNLIKELY TO:

      * LIVE IS PULLED INTO A MIRROR OUTSIDE THE REPO, not over the working tree, and the tree is written
        only for the files whose verdict is take-live. The wholesale version pulled over the tree first
        and then restored what it should not have taken -- so every bug in the rule was a bug that had
        ALREADY overwritten the file, and any failure between the pull and the restore left the damage
        standing. Not theoretical: the run that found the floor bug died at 'git checkout -b' with 31
        files staged.
      * IT NEVER DELETES. A path the trunk has and live does not is either a file the trunk added and
        never pushed, or one a third party deleted on live -- indistinguishable, and deleting is the
        irreversible option. It is reported, not acted on.
      * THE BRANCH NAME IS DECIDED BEFORE THE PULL. A name that cannot be created is a reason to stop
        while the tree is still clean, not after several hundred files have been written.

    -DryRun does everything except write: the full verdict table, nothing touched, and it is safe on a
    dirty tree because it writes nothing at all. Run it first.

    Steps:
      1. Refuse unless the working tree is clean (-DryRun is exempt: it writes nothing).
      2. Switch to the trunk and fast-forward from origin.
      3. Read the conflict-check reference point -- BEFORE the pull, on the state the pull is about to
         change.
      4. Decide the sync branch's name, before anything is pulled.
      5. Pull the live theme into a mirror outside the repo, then decide a verdict per differing path.
      6. Write, commit and push ONLY the paths whose verdict is take-live. Whether it then merges is a
         seam answer, and the default is NO.

    IT STOPS BEFORE THE MERGE BY DEFAULT, and that is a decision rather than caution. The whole point of
    the step is a moment where somebody LOOKS at what third parties changed on live before it becomes
    the base of new branches; auto-merging removes exactly the review the step exists to add. The two
    consumers this came from answer it differently, which is why it is a seam
    (Get-ShopifySyncMerges) instead of a hardcoded choice.

    THE PR BODY IS THE RECORD, AND IN SOME REPOS IT IS THE ONLY ONE (inbound #1000). Where a consumer has
    ruled that the sync PR does not wait for a review -- provided it states plainly what a third party
    did -- nobody reads the diff by design, so the body is the whole audit trail. The default body
    therefore names BOTH halves, every path with its kind in words: 'changed on live', 'new on live',
    'gone from live'. A flat file list is the shape that has already failed: in a consumer's sync PR #350
    nothing in the body recorded that live had made a template DISAPPEAR. Whatever else a repo needs
    around that -- its own template, a checkbox, its own wording -- is Get-ShopifySyncPrBody's answer,
    which receives the same rows and the default body to build on.

    AND THE PR ROUTE IS A SEAM FOR THE SAME REASON THE BODY IS (inbound #1023). A repo may require every
    PR to carry a label -- a guardrail workflow that fails an unlabelled one is the measured case -- and
    a sync PR opened without one goes red on CI and cannot merge. So Get-ShopifySyncPrLabels answers what
    to put on it, and the labels go on BOTH paths for the reason the body does: the printed line is what
    the operator pastes, and a line missing --label lands the same red CI a moment later. Answering the
    seam is what let that consumer delete its own wrapper around this script.

    WHY A LABEL SEAM RATHER THAN ROUTING THROUGH THE WORKFLOW PLUGIN'S open-pr.ps1, which would bring the
    lint and test gates along with it: that would couple dkj-subagents-shopify to dkj-policy, and the
    merging path below deliberately uses nothing but 'gh' so a consumer on either workflow plugin, or on
    neither, gets the same behaviour. A seam keeps that property; a cross-plugin call does not. The gates
    are the cost of that choice and they are named here rather than quietly dropped: a repo that wants
    them runs the sync with the merge seam off and opens the PR through its own route.

    THE STANDING-PREDECESSOR GUARD (inbound #1021), AND IT IS THE ONE CHECK THAT IS NOT ABOUT THE TRUNK.
    Stopping before the merge only works while somebody then merges. A sync branch pushed and never
    merged leaves the trunk unchanged, so the NEXT run re-measures against the same trunk, re-captures the
    same drift onto a new branch, and so does the one after that -- and each of those runs succeeds and
    looks like it. Measured in a consumer: four branches in seven days, the newest a strict superset of
    all three, two of them byte-identical duplicates, and a dry run naming the fifth. So step [3/6] asks
    'git ls-remote' whether a branch under the prefix is still standing, and refuses if one is. 'Merged'
    is proven PER REF -- its ancestry, or its current tip against the tip a merged PR carried -- never by
    its name alone: these names are date-stamped, so the same one comes round again (inbound #1190).

    REFUSING RATHER THAN WARNING, BECAUSE REFUSING COSTS NOTHING. The drift a refused run would have
    captured is already sitting on the predecessor; the trunk lacks it either way. All the push adds is a
    second candidate for one set of edits -- which is the failure, not the symptom of it: the entire
    justification for stopping before the merge is a moment where somebody LOOKS, and four competing
    candidates is not that moment. -AllowStacking overrides it for the case named on that parameter.

    AND THE REFUSAL SITS BEFORE THE THEME PULL, WHICH IS WHY THE DETECTION IS AT THE NAMING STEP rather
    than beside the verdict it produces. A refused run then costs no pull and no network. The verdict --
    which of the predecessor's paths this run covers -- needs the take set and therefore runs later, at
    both places the take set is complete: the dry-run report and the pre-push report. A DRY RUN IS EXEMPT
    from the refusal for the reason it is exempt from the clean-tree check: it writes nothing, and asking
    "what would this do, and does it supersede the pile?" is exactly what somebody staring at four open
    sync PRs needs, so the answer must not be a refusal. That exemption reaches the step's own NETWORK
    FAILURE too (inbound #1373): where 'git ls-remote' cannot list origin at all, a dry run reports that
    the check could not run and carries on to the verdict -- which is the offline -MirrorPath rehearsal
    .PARAMETER MirrorPath promises -- while a real run still refuses there, because only a real run can
    push a branch onto the pile.

    WHAT IT NEVER DOES: it does not push to live, publish a theme, or delete one. It reads from live and
    writes to git. dkj-subagents-shopify's PreToolUse guard covers those three acts independently and is not
    weakened here.

    SEAM ANSWERS IT READS, all from the consumer's own scripts/repo-config.ps1 and all read defensively
    -- an absent function falls back to the default named beside it:

      Get-ShopifyLiveThemeId          which theme is live. REQUIRED; the script refuses to guess.
      Get-ShopifyStoreDomain          the store the pull reads from. REQUIRED for the same reason.
      Get-ShopifySyncReferencePattern the pattern that recognises a sync commit, matched against the
                                      commit SUBJECT rather than through '--grep' (inbound #819), so
                                      it is a .NET regex and not git's basic one.
                                      Default: the union of the two spellings in use ('^[Ss]ync').
      Get-ShopifySyncBranchPrefix     the drift branch's prefix. Default: 'sync/live-'.
      Get-ShopifySyncMerges           $true to open the PR and merge it once CI is green.
                                      Default: $false -- push, then stop.
      Get-ShopifySyncPrBody           the PR body. Called with -Take, -Keep (the classified rows, each
                                      carrying Status/Path/Reason) and -Default (the body the script
                                      composed), and it returns the body to use -- so a consumer whose
                                      review policy IS the PR body can put its own template, its own
                                      checkboxes or its own wording around it. Default: what
                                      New-SyncPrBody composes, which names both halves and every path
                                      with its kind.
      Get-ShopifySyncLogPath          where this repo keeps its durable sync record, repo-root-relative
                                      (e.g. 'dkj-policy-bwj/SYNC-LOG.md'). Answered: every sync prepends an
                                      entry there and it rides in the branch's own commit. Default:
                                      unanswered, and then nothing is written -- keeping a log is the
                                      repo's policy, not a Shopify fact (inbound #1382).
      Get-ShopifySyncPrLabels         the label(s) the sync PR carries. Returns a string or an array of
                                      them; empty and absent both mean no label, which is the default
                                      and was the only behaviour before inbound #1023.
      Get-TrunkBranchName             the trunk. Default: 'main'.
      Get-PrMergeMethod               only read when Get-ShopifySyncMerges is true. Default: 'merge'.

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER Store
    Store domain to pull from, overriding Get-ShopifyStoreDomain. For a repo whose seam is not answered
    yet, or a one-off against a second store.

.PARAMETER DryRun
    Report the verdict for every differing path and write nothing at all: no branch, no commit, no push,
    and the working tree is not touched. Safe on a dirty tree, deliberately -- a dirty tree is exactly
    when somebody wants to ask "what would the sync do to this?", and refusing there would make the
    check unavailable at the one moment it is worth running.

.PARAMETER MirrorPath
    Use an existing live mirror instead of pulling one, for rehearsing the rule offline and for the test
    suite. The mirror is read and never modified.

.PARAMETER KeepMirror
    Do not delete the pulled mirror afterwards. A refused run keeps it regardless, because the conflict
    report names files inside it.

.PARAMETER StopBeforeMerge
    Push the sync branch and stop, even where Get-ShopifySyncMerges says to merge. The escape valve only
    runs in the safe direction: there is no switch that forces a merge the seam has not asked for.

.PARAMETER AllowStacking
    Run even though a previous sync branch is still standing. Without it such a run is refused before the
    theme pull -- see THE STANDING-PREDECESSOR GUARD above. What it is FOR is the one case where the two
    branches are genuinely independent: a path a third party reverted on live between the runs is no
    longer drift, so this run never captures it, and the predecessor holds the only copy. The run then
    still prints the per-branch verdict, so the second candidate is a decision rather than an accident.

.PARAMETER ChecksTimeoutMinutes
    How long to wait for CI on the sync PR before giving up and leaving it unmerged. Only used when the
    seam says to merge. Default: 15.

.EXAMPLE
    powershell -NoProfile -File scripts/task/sync-main.ps1 -DryRun

.EXAMPLE
    powershell -NoProfile -File scripts/task/sync-main.ps1
#>
[CmdletBinding()]
param(
    [string]$Store = '',
    [switch]$DryRun,
    [string]$MirrorPath = '',
    [switch]$KeepMirror,
    [switch]$StopBeforeMerge,
    [switch]$AllowStacking,
    [int]$ChecksTimeoutMinutes = 15,
    [string]$RootOverride = '',
    # RETIRED, AND ACCEPTED ONLY TO REFUSE IT BY NAME. -SkipPull meant "run the rule over whatever is
    # already in the working tree", which cannot mean anything now that the pull goes to a mirror and the
    # tree is written only for take-live paths. Left in the signature because PowerShell's own error for
    # an unknown parameter names the parameter and nothing else, and a consumer whose notes still carry
    # the old flag deserves to be told what replaced it.
    [switch]$SkipPull
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($SkipPull) {
    Write-Host '-SkipPull was retired when the pull moved into a mirror outside the repo (inbound #807).' -ForegroundColor Red
    Write-Host '  It meant "run the rule over the working tree", and the rule no longer reads the tree.'
    Write-Host '  Use -DryRun to see every verdict without writing anything, or -MirrorPath <dir> to run'
    Write-Host '  against a mirror you already have. Nothing was changed.'
    exit 1
}

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

. (Join-Path $PSScriptRoot '..\lib\sync-rules.ps1')

# THE MERGED-PR PROOF, SHARED WITH prune-merged.ps1 (issue #1194). Not in sync-rules.ps1, which is this
# plugin's alone: the same mechanism repaired here as inbound #1190 was repaired in the workflow plugin's
# prune-merged.ps1 as #1191 -- on the same day, independently, and the two copies diverged over the
# comparer their map is keyed with while both were one day old. One file, mirrored into BOTH plugins
# rather than reached across from one to the other: they are separately versioned and separately
# installed, so a cross-plugin path is a dependency a version mismatch breaks silently.
#
# UNGUARDED, for the reason the native-capture dot-source below states: a payload missing this file must
# fail at LOAD, not fall through to a guard that then quietly reports nothing standing.
. (Join-Path $PSScriptRoot '..\lib\merged-pr-lib.ps1')

# THE QUOTED-PATH DECODER, MOVED OUT OF sync-rules.ps1 (issue #1689, September 9, 2026). Convert-GitQuotedPath
# is called at three sites below and was DEFINED in sync-rules.ps1, which never used it -- while a second,
# poorer handling of the same quoting had grown up in git-porcelain-lib.ps1 for #1682. One owner now, and it
# is the file that already owns core.quotePath.
#
# NOT BY HAVING sync-rules.ps1 DOT-SOURCE IT, which was #1689's own first proposal and is refused by that
# file: it is dependency-free on purpose, because the live-theme guard dot-sources it on every command inside
# a catch that returns no live theme id -- so anything it pulls in is a way to silently disarm a guard over a
# revenue-serving theme. It never called the function, so it could simply lose it, and the dot-source lands
# here instead.
#
# UNGUARDED, and mirrored into THIS plugin as well as dkj-policy -- both for the reasons the merged-pr block
# above states in full: a payload missing this file must fail at LOAD rather than fall through to a path that
# is silently mis-decoded, which is inbound #821's failure exactly; and one file mirrored into both plugins
# beats a cross-plugin path that a version mismatch breaks without a word.
. (Join-Path $PSScriptRoot '..\lib\git-porcelain-lib.ps1')

# THE NETWORK GUARD (inbound #1181, #1184 and #1187, September 1, 2026). Every git AND gh call in this
# script that reaches the network goes through Invoke-NativeCapture, which runs its child with
# GIT_TERMINAL_PROMPT=0 and GCM_INTERACTIVE=never and -- where the call is given -TimeoutSeconds --
# kills the process tree and reports exit 124 rather than sitting there. Inbound #1179 closed that class
# at the choke point the release scripts share; this script was not a caller, so ten network calls sat
# outside it: five git (#1181), four gh (#1184) and the 'gh pr checks' poll (#1187). Three branches, in
# that order, each one scoping the next out and filing it rather than riding it along.
#
# gh IS IN SCOPE EVEN THOUGH THE MEASURED HANG DID NOT REACH IT, and that is the whole of #1184's
# question. #1179 measured gh as unaffected throughout -- it carries its own token instead of going
# through a credential helper, and every gh call in that session worked while git push was blocked. Two
# things settle it the other way anyway. The lib's own docstring states the non-interactive guard is
# applied to every child rather than only to git, because gh shells out to git in places; leaving four
# gh calls outside made that sentence false in this tree, and a load-bearing claim nobody can trust is
# worse than the gap it describes. And 'gh pr create' sits directly after the push, where a stall leaves
# the branch on origin with NO PR -- a state nothing here reports.
#
# THE 'gh pr checks' POLL WAS THE LAST ONE OUTSIDE, and #1184 left it there for a reason that did not
# survive being checked (inbound #1187). Two claims were made for the exclusion and both were wrong.
# "It is bounded already" was true of the LOOP and not of the call: -ChecksTimeoutMinutes is re-read
# only at the top of the while, so a poll that never returns never reaches it -- the deadline bounds
# iterations, not any one call, which is the same shape #1179 and #1181 were filed about. And "a bound
# per call is the mistake the lib warns about by name" pointed at the wrong call: that warning is about
# 'gh pr checks --watch' (ship-pr.ps1), which blocks for as long as CI takes by design. A poll that
# answers in seconds is not that.
#
# What WAS true is that its hand-rolled bracket was load-bearing -- it had to swallow the stderr a
# pending run writes while still reading states off stdout -- and -DiscardStderr does exactly that half.
# The call site says how a timeout is judged, which is the part that needed the care.
#
# UNGUARDED DOT-SOURCE, unlike the source-repo guard above, and that is deliberate: that guard is
# optional behaviour a tree may not have, while this lib is load-bearing here. A copy of this script
# without it must fail at load rather than silently push unbounded. It travels in dkj-subagents-shopify's own
# payload for exactly that reason -- see its second entry in scripts/lib/shared-scripts-lib.ps1.
#
# NOT INTO sync-rules.ps1, WHICH IS THE OTHER PLACE IT COULD HAVE GONE. Two of the five git calls ran
# through Invoke-SyncGitQuiet, so routing that wrapper looked like the smaller change. It is the wrong
# one twice over: the wrapper's other eight callers are LOCAL queries that must not carry a network
# bound, and two of them read $LASTEXITCODE as the answer rather than the output -- which the
# Start-Process arm a bound implies does not set. sync-rules.ps1 also declares itself dependency-free
# on purpose (its header), and it is the only file here the test suite loads without a sync.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# THE SHOPIFY CLI WRAPPER (inbound #1183, September 1, 2026). The one pull below is the only Shopify
# call in this script, and it was bare -- so a single stderr line from the CLI killed the run on the
# line AFTER it, skipping the exit-code check that deletes the mirror and reports the failure. On
# Windows the CLI is a PowerShell shim that inherits this script's 'Stop', so the wrapper's lowered
# preference is what reaches the frame that raises the ErrorRecord. Its header has the measurement.
#
# UNGUARDED, for the reason the dot-source above it gives: a payload without the lib must fail at load
# rather than run a pull whose failure path cannot be reached. It travels in dkj-subagents-shopify's own payload,
# registered in scripts/lib/shared-scripts-lib.ps1.
. (Join-Path $PSScriptRoot '..\lib\shopify-cli-lib.ps1')

# THE PASTE-SAFETY VERDICT on the branch name this script prints into two commands (issue #1594): the
# by-hand push in the failed-push path, and the 'gh pr create' line the default non-merging path prints.
# Neither is attacker-reachable the way ship-pr's five sites are -- the name is composed here, from a
# date stamp and Get-ShopifySyncBranchPrefix's answer -- but that prefix is a string a CONSUMER authors
# in its own repo-config, so it is not a constant either, and a prefix carrying a shell metacharacter
# would reach both printed lines. One definition rather than a local rule: see the lib's header for why
# quoting is not the alternative. Unguarded, for the reason the two dot-sources above give.
. (Join-Path $PSScriptRoot '..\lib\ref-print-lib.ps1')

# Dual-context repo root: a consumer running the plugin mirror gets it from CLAUDE_PROJECT_DIR, the
# source root copy falls back to the git root. Same resolution as every other mirrored script, which is
# what lets both copies stay byte-identical.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'sync-main.ps1' -OverrideName '-RootOverride'

# A repo that publishes plugins is this script's SOURCE, not a Shopify store: there is no live theme
# here to mirror. Same one-file test adopt-shopify-floor uses for the same distinction.
if (-not $RootOverride -and (Test-Path -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json') -PathType Leaf)) {
    Write-Host 'REFUSED: this repo publishes plugins, so it is this script''s source rather than a Shopify consumer.' -ForegroundColor Red
    Write-Host 'There is no live theme here to mirror. Nothing was changed.'
    exit 1
}

Set-Location -LiteralPath $repoRoot

# THE DIRECTORIES A SHOPIFY PULL WRITES, and this is a constant rather than a seam on purpose: the set is
# defined by the platform, not by the repo. Naming them explicitly is what keeps anything else in the
# mirror -- and everything of the repo's own (scripts/, CLAUDE.md, the workflow folder) -- out of the
# comparison and therefore out of any commit. A repo whose theme does not sit at the root is out of
# scope for this script rather than a knob nobody has asked for.
$ThemeDirs = @('assets', 'blocks', 'config', 'layout', 'locales', 'sections', 'snippets', 'templates')

# --- The seam answers ------------------------------------------------------------------------------
# Read in a child scope with StrictMode OFF and inside a try, exactly as dkj-subagents-shopify's live-theme guard
# reads the same file. The reason is the same: repo-config.ps1 belongs to the consumer, so a fault in it
# must degrade to defaults rather than take this script down with it.
$seam = & {
    Set-StrictMode -Off
    $answers = @{
        LiveThemeId = ''; StoreDomain = ''; Pattern = ''; BranchPrefix = ''
        Merges = $false; Trunk = ''; MergeMethod = ''; Labels = @(); SyncLogPath = ''
    }
    $configPath = Join-Path $args[0] 'scripts\repo-config.ps1'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { return $answers }
    try { . $configPath } catch { return $answers }
    if (Test-FunctionDefined 'Get-ShopifyLiveThemeId') { $answers.LiveThemeId  = [string](Get-ShopifyLiveThemeId) }
    if (Test-FunctionDefined 'Get-ShopifyStoreDomain') { $answers.StoreDomain  = [string](Get-ShopifyStoreDomain) }
    if (Test-FunctionDefined 'Get-ShopifySyncReferencePattern') { $answers.Pattern      = [string](Get-ShopifySyncReferencePattern) }
    if (Test-FunctionDefined 'Get-ShopifySyncBranchPrefix') { $answers.BranchPrefix = [string](Get-ShopifySyncBranchPrefix) }
    if (Test-FunctionDefined 'Get-ShopifySyncMerges') { $answers.Merges       = [bool](Get-ShopifySyncMerges) }
    if (Test-FunctionDefined 'Get-TrunkBranchName') { $answers.Trunk        = [string](Get-TrunkBranchName) }
    if (Test-FunctionDefined 'Get-PrMergeMethod') { $answers.MergeMethod  = [string](Get-PrMergeMethod) }
    # UNANSWERED MEANS NO LOG, and that is why this seam is not required (inbound #1382). Keeping a sync
    # log is a repo's POLICY -- dkj-policy-bwj's, for the two BWJ store repos -- while the machinery here is
    # generic and reaches every Shopify consumer through a plugin update. A repo that never asked for the
    # record must not find a new file in its tree because it updated a plugin, so the default is silence.
    if (Test-FunctionDefined 'Get-ShopifySyncLogPath') { $answers.SyncLogPath  = [string](Get-ShopifySyncLogPath) }
    # THE ONE ANSWER IN THIS BLOCK WHOSE FAULT IS REPORTED, and it is the body seam's reason below applied
    # to the PR route (inbound #1023). Every other default here is a CORRECT answer, so falling back to one
    # is silent by design. No label is different: in a repo whose guardrail requires one, the fallback
    # opens a PR that goes red on CI and cannot merge, which is the failure the seam exists to prevent --
    # so it must not happen quietly. Its own try/catch rather than the block-wide one above, because that
    # one returns the whole hashtable of defaults and would cost the store and the theme id too.
    #
    # AN ARRAY OR A BARE STRING, both accepted: 'return "sync"' is what a consumer writes first, and
    # demanding @('sync') would make the seam wrong in the way that is hardest to see in a config file.
    # @() around the pipeline keeps one label an array rather than a string PowerShell then iterates by
    # character. Blank entries are dropped, so a 'VUL-IN' cleared to '' reads as unanswered.
    if (Test-FunctionDefined 'Get-ShopifySyncPrLabels') {
        try {
            $answers.Labels = @(Get-ShopifySyncPrLabels | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
        } catch {
            Write-Host "Get-ShopifySyncPrLabels threw, so the sync PR gets no label: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    return $answers
} $repoRoot

$liveId = ([string]$seam.LiveThemeId).Trim()
# A NON-NUMERIC ANSWER COUNTS AS NO ANSWER -- the same rule the guard applies, and for the same reason: a
# 'VUL-IN' left behind in the seam block reads as answered to anything testing for emptiness.
if ($liveId -notmatch '^\d+$') {
    Write-Host 'Get-ShopifyLiveThemeId does not answer with a theme id -- refusing to guess which theme is live.' -ForegroundColor Red
    Write-Host "  Run 'shopify theme list' and answer it in scripts/repo-config.ps1 (see the adopt-shopify-floor skill)."
    exit 1
}

$store = if ($Store) { $Store } else { ([string]$seam.StoreDomain).Trim() }
if (-not $store -or $store -match 'VUL-IN') {
    Write-Host 'No store domain: Get-ShopifyStoreDomain is unanswered and -Store was not given.' -ForegroundColor Red
    Write-Host '  Answering the seam is the durable fix; -Store gets you through this run.'
    exit 1
}

# --- The body seam, read at the moment it is needed -------------------------------------------------
# ONE SEAM, DELIBERATELY NOT READ WITH THE OTHERS ABOVE. Every answer in that block is a scalar known
# before the work starts; this one is a FUNCTION OF THE VERDICT, so it can only be called once the rows
# exist. Capturing its ScriptBlock in the block above and invoking it here was the first shape and it is
# the wrong one: the consumer's function may call anything else its repo-config.ps1 defines, and by then
# that child scope -- the only place those definitions ever lived -- is gone. So the file is dot-sourced
# again, here, with the same StrictMode-off try/catch for the same reason: repo-config.ps1 belongs to the
# consumer, and a fault in it must cost the custom body, never the sync.
#
# AND A FAULT IS REPORTED RATHER THAN SWALLOWED. The default answers above are correct answers, so
# falling back to one is silent by design. A body seam that exists and throws is different: the consumer
# asked for a specific record and got the generic one, which is precisely the failure inbound #1000 was
# filed about. It says so on the run.
function Get-SyncPrBodySeamAnswer {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [object[]]$Take = @(),
        [object[]]$Keep = @(),
        [Parameter(Mandatory = $true)][string]$Default
    )

    return & {
        Set-StrictMode -Off
        $root = $args[0]; $take = $args[1]; $keep = $args[2]; $default = $args[3]
        $configPath = Join-Path $root 'scripts\repo-config.ps1'
        if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { return '' }
        try { . $configPath } catch { return '' }
        if (-not (Test-FunctionDefined 'Get-ShopifySyncPrBody')) { return '' }
        try {
            $answer = [string](Get-ShopifySyncPrBody -Take $take -Keep $keep -Default $default)
        } catch {
            Write-Host "Get-ShopifySyncPrBody threw, so the PR body is the default one: $($_.Exception.Message)" -ForegroundColor Yellow
            return ''
        }
        if (-not $answer.Trim()) {
            Write-Host 'Get-ShopifySyncPrBody answered with nothing, so the PR body is the default one.' -ForegroundColor Yellow
            return ''
        }
        return $answer
    } $RepoRoot $Take $Keep $Default
}

# --- The sync log, written on the branch ------------------------------------------------------------
# WHY A RECORD IN THE TREE AND NOT JUST THE PR (inbound #1382). The PR body says everything this entry
# says, once, on GitHub. It is not a record: nothing in the repo indexes it, nothing greps it, and a repo
# whose standing rule is that a sync PR does NOT wait for review has spent its whole review moment on a
# page nobody re-reads. So a sync branch, which owes no changelog entry by design, owes this instead --
# and the symmetry is the point rather than the file.
#
# THE MASTHEAD IS EVERYTHING ABOVE THE FIRST '## ' LINE, and the new entry goes immediately before it.
# That rule is deterministic and survives a hand-edited masthead: the log is newest-first, so a repo can
# put whatever title and pointer it likes at the top without this function needing to recognise them.
# A file with no '## ' line yet is a fresh one, and the entry is appended after whatever is there.
function Write-SyncLogEntry {
    <#
    .SYNOPSIS
        Prepend this run's entry to the repo's sync log. Returns the repo-relative path it wrote, or ''
        when there is nothing to write.

    .DESCRIPTION
        UNANSWERED SEAM RETURNS '' AND WRITES NOTHING -- that is the default and the common case. Only a
        repo that has stated where its log lives gets one.

        A FAULT COSTS THE LOG, NEVER THE SYNC. By the time this runs, the branch holds a third party's
        in-flight edits to a live theme and the only copy is local. A path the consumer's seam answered
        badly must not take that down, so the failure is reported and the run continues -- the same
        bargain the PR-body seam strikes one screen up, and for the same reason.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$RelativePath = '',
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][string]$Date,
        [object[]]$Take = @(),
        [object[]]$Keep = @()
    )

    $rel = ([string]$RelativePath).Trim()
    if (-not $rel) { return '' }
    # A 'VUL-IN' left standing in the seam block reads as answered to anything testing for emptiness --
    # the same rule the theme-id check applies above, for the same reason.
    if ($rel -match 'VUL-IN') {
        Write-Host "Get-ShopifySyncLogPath still answers with a scaffold marker ('$rel'), so no sync-log entry was written." -ForegroundColor Yellow
        return ''
    }

    try {
        $rel      = $rel -replace '\\', '/'
        $full     = Join-Path $RepoRoot ($rel -replace '/', '\')
        $entry    = New-SyncLogEntry -Branch $Branch -Date $Date -Take $Take -Keep $Keep
        $existing = if (Test-Path -LiteralPath $full -PathType Leaf) {
            [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
        } else {
            $dir = Split-Path -Parent $full
            if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            ''
        }

        # WHERE the entry goes is Add-SyncLogEntry's, in the lib, because that decision is pure and fails
        # silently; what is left here is the disk.
        $text = Add-SyncLogEntry -Existing $existing -Entry $entry

        [System.IO.File]::WriteAllText($full, $text, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Sync log: entry for $(Get-DisplayRef -Ref $Branch) written to $rel." -ForegroundColor DarkGray
        return $rel
    } catch {
        Write-Host "Could not write the sync-log entry to '$rel', so this sync leaves no record in the tree: $($_.Exception.Message)" -ForegroundColor Yellow
        return ''
    }
}

function Write-SyncPredecessorVerdict {
    <#
    .SYNOPSIS
        Print, per standing sync branch, whether this run's take set covers what that branch captured.

    .DESCRIPTION
        Called at BOTH points where the take set is complete -- the dry-run report and the pre-push
        report -- which is why it is a function rather than two copies of the same eleven lines. The two
        rows it can print are the two the operator acts on differently, so each one names the action
        rather than leaving it to be worked out:

          all of them in this run     this run supersedes that branch. Close its PR, re-run, merge this.
          M NOT in this run           neither supersedes the other, and the uncovered paths are named.

        THE SECOND ROW IS WHY -AllowStacking EXISTS, and the uncovered paths are printed rather than
        counted because they are the whole decision: a path a third party reverted on live between the two
        runs is no longer drift, so this run never captures it, and that branch holds the only copy.
    #>
    param(
        [object[]]$Standing = @(),
        [string[]]$TakePaths = @()
    )

    if (@($Standing).Count -eq 0) { return }

    $report = @(Get-SyncPredecessorReport -Predecessors $Standing -TakePaths $TakePaths)
    Write-Host ''
    Write-Host 'Standing sync branches, measured against what this run takes:' -ForegroundColor Yellow
    foreach ($r in $report) {
        # THE MOST EXTERNALLY-AUTHORED REF NAME IN THIS SCRIPT (issue #1623). These names are not composed
        # here and were never validated here: they come off `git ls-remote`, so whoever pushed a branch
        # matching the prefix chose them. `git check-ref-format` accepts \p{Cf}, so U+202E or a zero-width
        # run reaches this loop intact -- and the whole point of these rows is that the operator reads a
        # branch name and decides which PR to close, which is the decision a name printing as a DIFFERENT
        # branch corrupts. Stripped once per row rather than at each of the three arms.
        $branchRow = Get-DisplayRef -Ref ([string]$r.Branch)
        if ($r.Captured -eq 0) {
            Write-Host "  $branchRow -- its file set could not be read, so nothing is claimed about it." -ForegroundColor Yellow
        } elseif ($r.Superseded) {
            Write-Host "  $branchRow -- $($r.Captured) file(s), all of them in this run." -ForegroundColor Green
            Write-Host '      This run supersedes it: close that PR, then merge this one.' -ForegroundColor DarkGray
        } else {
            # AND THE PATHS UNDER THAT ROW, for the reason the row above them was stripped (issue #1629).
            # #1623 stripped the branch name and scoped these out; #1637/#1638 then closed the same class
            # at this script's other three path lists and its paste-ready remedy. These are the ones left,
            # and they carry MORE of the decision than any of those: the operator answers "does today's
            # drift supersede that standing PR?" from exactly this list, which is why it is printed rather
            # than counted.
            #
            # THE READ ABOVE IS WHY THIS IS LOAD-BEARING NOW, not tidiness. Measured, git 2.55:
            # `diff --name-only` C-quotes \p{Cc} in EVERY core.quotePath setting -- an ESC arrived as the
            # four characters '\033' with the flag on, off, and set false in the repo's own config -- so
            # git was closing the control half by accident, while \p{Cf} was quoted only with the flag on
            # and U+202E reached this loop intact whenever a consumer had turned it off. Now that the read
            # forces the flag and Convert-GitQuotedPath unpacks it, '\033' becomes a live ESC byte:
            # correct for comparing, an ANSI/OSC repaint surface if printed raw.
            #
            # Get-DisplayPath, NOT Get-DisplayRef, and the difference is the point (#1638). It neither
            # collapses runs nor trims, because git, NTFS and Shopify's asset names all accept a space --
            # a doubled or trailing one included -- and these rows are what a reader compares against live
            # before merging by hand. A collapsed path names a different file. #1629 proposed Get-DisplayRef
            # as the one definition if stripping turned out right here; it was, and by the time this landed
            # the tree had the path-shaped answer that question was really asking for.
            $u = @($r.Uncovered)
            Write-Host "  $branchRow -- $($r.Captured) file(s), $($u.Count) NOT in this run:" -ForegroundColor Red
            foreach ($p in $u) { Write-Host "      $(Get-DisplayPath -Path $p)" -ForegroundColor Red }
            Write-Host '      Neither supersedes the other. Those paths exist only on that branch.' -ForegroundColor DarkGray
        }
    }
}

$trunk        = if (([string]$seam.Trunk).Trim())        { ([string]$seam.Trunk).Trim() }        else { 'main' }
# THE TRUNK IS A REF NAME FROM THE SAME SEAM, and it is printed in nine sentences of this run's own
# progress report (issue #1623). #1623 counted the branch's six and not these, because it read the script
# for `$branch`; the mechanism is identical and the source is more exposed, not less -- $trunk is whatever
# Get-TrunkBranchName in the consumer's repo-config.ps1 returns, and nothing between there and the first
# `Write-Host` asks git whether it is a legal ref. The raw $trunk stays raw for `git checkout`, which
# hands it to git as one argument with no shell in between.
#
# BUT NOT FOR THE PRINTED `gh pr create --base` (issue #1627), which is what the sentence here used to
# say. That line is not a call -- it is a command the reader is invited to copy and run, so it is the
# PASTE axis and needs #1594's remedy rather than #1623's. It already routed `--head` through
# Get-PasteableRef and left `--base` raw beside it, so one printed command was visibly half-guarded.
# Its own placeholder, because that command can now print two: '<branch>' twice would leave the reader
# unable to tell which note belonged to which half.
$trunkShown   = Get-DisplayRef -Ref $trunk
$trunkPaste   = Get-PasteableRef -Ref $trunk -Placeholder '<trunk>'
$pattern      = if (([string]$seam.Pattern).Trim())      { ([string]$seam.Pattern).Trim() }      else { Get-SyncDefaultReferencePattern }
$branchPrefix = if (([string]$seam.BranchPrefix).Trim()) { ([string]$seam.BranchPrefix).Trim() } else { 'sync/live-' }
$mergeMethod  = if (([string]$seam.MergeMethod).Trim())  { ([string]$seam.MergeMethod).Trim() }  else { 'merge' }
$merges       = ([bool]$seam.Merges) -and (-not $StopBeforeMerge) -and (-not $DryRun)
$prLabels     = @($seam.Labels)

Write-Host ''
Write-Host "=== pre-task sync  |  store: $store  theme: $liveId ===" -ForegroundColor Cyan
if ($DryRun) { Write-Host 'DRY RUN -- nothing will be written.' -ForegroundColor Magenta }

# --- 1. clean tree ---------------------------------------------------------------------------------
# A DRY RUN IS EXEMPT, AND THAT IS THE POINT OF IT. It writes nothing, checks nothing out and pulls into
# a mirror, so it is safe on a dirty tree -- and a dirty tree is exactly when somebody wants to ask what
# the sync would do to it. Refusing there would make the safety check unavailable at the one moment it is
# worth running, which is how safety checks stop being run.
if (-not $DryRun) {
    $dirty = @(& git status --porcelain | Where-Object { $_ })
    if ($dirty.Count -gt 0) {
        Write-Host 'Working tree is not clean. Commit or stash first -- a sync must not carry your work into it:' -ForegroundColor Red
        $dirty | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        Write-Host '(-DryRun works on a dirty tree: it writes nothing.)' -ForegroundColor Yellow
        exit 1
    }
}

# --- 2. the trunk, fast-forwarded ------------------------------------------------------------------
if ($DryRun) {
    $onBranch = ([string](& git rev-parse --abbrev-ref HEAD)).Trim()
    Write-Host ''
    Write-Host "[1/6] dry run -- staying on $onBranch, checking out and pulling nothing." -ForegroundColor Yellow
} else {
    Write-Host ''
    Write-Host "[1/6] $trunkShown, fast-forward from origin ..." -ForegroundColor Yellow
    & git checkout $trunk | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host "Could not switch to $trunkShown." -ForegroundColor Red; exit 1 }
    # BOUNDED (inbound #1181). The cheapest of the five to stall in -- nothing has been written yet --
    # and it is still bounded rather than left alone: a run that hangs here hangs before it has said
    # anything, which reads as the script being slow to start rather than as a credential to fix.
    $pull = Invoke-NativeCapture -FilePath 'git' -Arguments @('pull', '--ff-only') `
                                 -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    $pull.Output | ForEach-Object { Write-Host $_ }
    if ($pull.ExitCode -ne 0) {
        Write-Host "Could not fast-forward $trunkShown from origin." -ForegroundColor Red
        if ($pull.TimedOut) {
            Write-Host "  'git pull' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] lines above." -ForegroundColor Red
        }
        exit 1
    }
}

# --- 3. the reference point, read before the pull --------------------------------------------------
# Reading it afterwards would be reading it off a tree that already contains live's version of
# everything, which is the one ordering mistake that makes the check useless while looking fine.
Write-Host ''
Write-Host '[2/6] the conflict-check reference point ...' -ForegroundColor Yellow
$ref = Get-SyncReferencePoint -Ref 'HEAD' -Pattern $pattern
if (-not $ref) {
    Write-Host "No reference point found: no commit matching $pattern and no tag." -ForegroundColor Red
    Write-Host '  This repo has no sync history at all, so no path has an agreement point with live and' -ForegroundColor Red
    Write-Host '  nothing here can tell third-party drift from work the trunk simply has not pushed yet.' -ForegroundColor Red
    Write-Host '  Tag the current state, or sync by hand this once.' -ForegroundColor Red
    exit 1
}
# THE REASON FOR THIS REFUSAL CHANGED WITH THE PER-PATH BASE (inbound #1535), and the old one is worth
# recording because it was the more alarming of the two. It read: "without it such a conflict would be
# taken silently" -- true while the base was global and an absent one meant every M+foreign path took
# live. It is no longer: Get-SyncFileVerdict now REPORTS a path with no agreement point, so a run with no
# reference point anywhere would conflict on everything foreign rather than take it.
#
# SO THIS IS KEPT AS DELIBERATE CONSERVATISM RATHER THAN AS A GUARD AGAINST DATA LOSS. A first-ever sync
# in a repo with no history to measure from is a reconciliation a person should do once, with their eyes
# on it, rather than a hundred-path conflict report. Removing it would now be safe and is a separate
# decision from this repair, which is why it was not taken here.
$since = $ref.Ref
if ($ref.Kind -eq 'tag') {
    Write-Host "      $since (a TAG -- no sync commit found, so the window is wider and more is flagged)."
} else {
    Write-Host "      $since (the previous sync commit)."
}
# SAID HERE BECAUSE THIS LINE USED TO BE THE WHOLE ANSWER, and reading it as such is what inbound #1535
# was. The commit above is the repo's most recent sync; the base each path is actually judged against is
# the most recent sync that took THAT path, asked per path in step 6. They are the same commit only for
# the paths the last sync happened to take.
Write-Host '      Each path is judged against its OWN base -- the last sync that took that path.' -ForegroundColor DarkGray
Write-Host '      A path no sync has ever taken has no agreement point, and is reported rather than taken.' -ForegroundColor DarkGray

# --- 4. the branch name, decided BEFORE anything is pulled -----------------------------------------
# Before, not after: the wholesale version worked this out at the very end and died on a collision with
# 31 files already staged. The stamp comes from the clock rather than from the trunk's last commit, which
# is a repair of its own -- on a day after the last commit the old stamp produced a name that already
# existed. Remote refs are checked too, because a sync branch that is pushed but not merged is the
# ordinary state of this workflow.
Write-Host ''
Write-Host '[3/6] naming the sync branch ...' -ForegroundColor Yellow
$stamp  = (Get-Date -Format 'yyyy-MM-dd')
$branch = "$branchPrefix$stamp"
$n = 1
while (
    @(Invoke-SyncGitQuiet @('rev-parse', '--verify', '--quiet', "refs/heads/$branch")).Where({ $_ }).Count -gt 0 -or
    @(Invoke-SyncGitQuiet @('rev-parse', '--verify', '--quiet', "refs/remotes/origin/$branch")).Where({ $_ }).Count -gt 0
) {
    $n++
    $branch = "$branchPrefix$stamp-$n"
    if ($n -gt 20) { Write-Host "Twenty sync branches already exist for $stamp. Something is wrong; stopping." -ForegroundColor Red; exit 1 }
}
# BOTH VERDICTS ARE TAKEN HERE, ABOVE THE FIRST LINE THAT PRINTS THE NAME. The paste verdict is for the
# two printed commands further down (issue #1594); the display name is for the six sentences that merely
# QUOTE the branch (issue #1623), and the very first of those is the line below. Neither is gated on
# anything: their readers are failure or hand-over paths that must not do work of their own on the way
# out. Under Set-StrictMode -Version Latest an assignment that sat below its first use would not print
# an empty name, it would THROW -- which is how the display name arrived one line too late and cost 50
# asserts in this script's own suite before it left the branch.
#
# #1594 scoped prose out on the ground that git rejects the characters that make it deceptive.
# `git check-ref-format` rejects \p{Cc} and ACCEPTS \p{Cf} -- and this name never met git at all before
# it is printed: it is $branchPrefix, a seam answer a consumer wrote, plus a date. So the strip is
# load-bearing here rather than belt-and-braces. $branch itself stays raw and is what `git checkout -b`,
# `git push` and `gh pr create` still receive.
$branchPaste = Get-PasteableRef -Ref $branch
$branchShown = Get-DisplayRef -Ref $branch

Write-Host "      $branchShown"

# --- 4b. is a PREVIOUS run's branch still standing? ------------------------------------------------
# Inbound #1021, and it belongs here rather than beside the verdict it produces: a refusal at this point
# costs no theme pull and no network beyond two read-only queries. See THE STANDING-PREDECESSOR GUARD in
# the header for why the answer is a refusal rather than a warning.
#
# 'ls-remote' IS ASKED FOR EVERY HEAD AND FILTERED LOCALLY, not narrowed with a server-side pattern.
# ls-remote's pattern matching is tail-based, and a pattern that under-matches would drop a predecessor
# silently -- which is the failure being repaired. Get-SyncBranchNamesFromRefs anchors on
# 'refs/heads/<prefix>' and is the authoritative filter; the extra heads cost one line each to skip.
Write-Host ''
Write-Host '[3b/6] previous sync branches ...' -ForegroundColor Yellow
$standing   = @()
#
# BOUNDED, AND ITS FAILURE IS A REFUSAL ON A RUN THAT PUSHES (inbound #1181; DryRun carve-out #1373).
# It used to run through Invoke-SyncGitQuiet, which swallows stderr by design -- so a credential prompt,
# a dead remote or a stall produced NO lines, and no lines is indistinguishable from "no sync branch on
# origin". That is the silent miss this guard exists to end, arriving through the guard's own query, and
# on a real run the direction the banner above already chose holds: a run that cannot be proven safe is
# refused, loudly.
#
# A DRY RUN IS THE ONE EXCEPTION, for the reason it is exempt from the refusal below. It writes nothing
# and pushes nothing, so a standing predecessor it fails to notice stacks nothing -- and refusing here
# withholds the verdict the dry run exists to produce, which is exactly what the documented offline
# -MirrorPath rehearsal needs. So a dry run reports that the check could not run and carries on; it does
# NOT read the failure as "none on origin", which is the false negative #1181 closed.
$lsRemote = Invoke-NativeCapture -FilePath 'git' -Arguments @('ls-remote', '--heads', 'origin') `
                                 -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
$lsRemoteUnknown = $false
if ($lsRemote.ExitCode -ne 0) {
    if ($DryRun) {
        $why = if ($lsRemote.TimedOut) {
            "'git ls-remote' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds"
        } else {
            "'git ls-remote --heads origin' exited $($lsRemote.ExitCode)"
        }
        Write-Host "      origin could not be listed ($why) -- the standing-predecessor check is skipped for this dry run." -ForegroundColor Yellow
        Write-Host '      A real run refuses here; a dry run writes nothing, so it continues to the verdict below.' -ForegroundColor DarkGray
        $lsRemoteUnknown = $true
    } else {
        Write-Host 'Could not list the heads on origin, so whether a previous run''s branch is still standing is UNKNOWN.' -ForegroundColor Red
        if ($lsRemote.TimedOut) {
            Write-Host "  'git ls-remote' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] lines above." -ForegroundColor Red
        } else {
            Write-Host "  'git ls-remote --heads origin' exited $($lsRemote.ExitCode)." -ForegroundColor Red
        }
        Write-Host '  Nothing was changed. Fix the remote or the credential and run again.' -ForegroundColor Red
        exit 1
    }
}
$candidates = @()
if (-not $lsRemoteUnknown) {
    $candidates = @(Get-SyncBranchNamesFromRefs -Prefix $branchPrefix -Lines @($lsRemote.Output))
}

if ($lsRemoteUnknown) {
    # No ls-remote answer: there is no candidate set to prove merged or standing, and $standing stays
    # empty -- so Write-SyncPredecessorVerdict below prints nothing, which is the honest report here.
}
elseif ($candidates.Count -eq 0) {
    Write-Host '      none on origin.'
} else {
    # THE FETCH RUNS IN A DRY RUN TOO, and that is not a breach of "nothing will be written": it updates
    # remote-tracking refs and touches no file the operator has. The alternative is answering from refs as
    # old as the last fetch -- and a predecessor pushed from another machine has no local ref at all,
    # which is precisely the branch that stacks. The trunk is in the same refspec because a dry run does
    # not pull, and a stale base would be read as the diff base below.
    #
    # BOUNDED, AND ITS FAILURE IS A REFUSAL TOO (inbound #1181), for the reason the paragraph above
    # gives: the whole point of this fetch is that answering from refs as old as the last one is the
    # failure. A fetch that quietly did nothing leaves every test below reading exactly those stale
    # refs, and the trunk is in the same refspec, so the diff base goes stale with them.
    $fetch = Invoke-NativeCapture -FilePath 'git' -Arguments @('fetch', '--quiet', 'origin',
        "+refs/heads/${trunk}:refs/remotes/origin/$trunk",
        "+refs/heads/$branchPrefix*:refs/remotes/origin/$branchPrefix*") `
        -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    if ($fetch.ExitCode -ne 0) {
        Write-Host 'Could not fetch origin, so the refs the standing-predecessor test reads are as old as the last fetch.' -ForegroundColor Red
        if ($fetch.TimedOut) {
            Write-Host "  'git fetch' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] lines above." -ForegroundColor Red
        } else {
            Write-Host "  'git fetch --quiet origin' exited $($fetch.ExitCode)." -ForegroundColor Red
        }
        Write-Host '  Nothing was changed. Fix the remote or the credential and run again.' -ForegroundColor Red
        exit 1
    }

    # THE MERGED TEST IS TWO-PART, and both parts are needed here rather than one. On a repo with
    # delete_branch_on_merge a merged branch's ref is gone from origin, so ls-remote never lists it and
    # ancestry alone would do -- but that setting is the CONSUMER's, not this script's, and a repo without
    # it keeps the ref of every squash-merged branch forever. Reading the setting would be one more thing
    # to get wrong; doing both halves is what prune-merged settled on for the same question.
    #
    # ITS SECOND PART PROVES THE REF, NOT ITS NAME, and until inbound #1190 it proved the name. So did
    # prune-merged.ps1, where the same miss hands over a DELETE command instead of a refusal; it was
    # tracked as #1191 rather than swept along here, repaired the same day, and the two repairs are now
    # ONE -- merged-pr-lib.ps1, which both scripts call (issue #1194). What is left here is the transport
    # and the direction to err in, both of which are genuinely this script's.
    # These names are date-stamped, so a day whose branch has already merged AND been
    # deleted hands the next run the same name -- and a name-match then vouches for a brand-new, unmerged
    # predecessor. The guard reported 'all merged', found nothing standing, and pushed a '-2' branch onto
    # the pile it exists to prevent: the failure arriving through the guard's own answer. Measured in a
    # consumer on September 1, 2026 -- 'sync/live-2026-09-01' merged as PR #141 and deleted, re-created
    # the same day with open PR #159, and 4.27.0 reported '1 found on origin, all merged'. So the tip is
    # asked for too; Get-MergedPrTips carries the rest, including why the merge commit the report
    # proposed instead would never have matched a single branch.
    #
    # AND WHERE gh CANNOT ANSWER, THE BRANCH READS AS STANDING. That is the opposite of prune-merged's
    # fallback and the same principle: each errs toward doing nothing. There, a branch that cannot be
    # proven merged is KEPT; here, a run that cannot be proven safe is REFUSED -- loudly, naming
    # -AllowStacking. A refusal costs nothing, so it is the cheap side to be wrong on.
    # BOUNDED, AND THROUGH THE LIB (inbound #1184). This was the ONE gh call of the four that already
    # carried the save-EAP -> Continue -> restore dance by hand -- which is the half Invoke-NativeCapture
    # exists to own, so the bracket is gone rather than left standing beside it. The report expected to
    # find that dance at all four sites; measured, the other three had no bracket at all.
    #
    # -DiscardStderr BECAUSE THE OUTPUT IS DATA the loop below compares refs against, not progress: a gh
    # status line merged into it becomes a row that matches nothing, and -- worse -- one that matched a
    # real branch would read as merged. The '<name> TAB <sha>' shape is a stronger filter than the
    # name-only parse it replaces, where any stray word was a candidate row.
    #
    # A STALL HERE READS AS 'NO MERGED PRS', which is the expensive direction, and the existing shape
    # already handles it. $ghKnown stays $false on a timeout exactly as on any other non-zero exit, so
    # the guard falls through to its own refusal -- loudly, naming -AllowStacking -- rather than letting
    # a branch it could not judge pass as merged. The Yellow line says which of the two happened.
    $mergedTips = $null
    $ghKnown    = $false
    if (Get-Command 'gh' -ErrorAction SilentlyContinue) {
        $prList  = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr `
                                        -Arguments @('pr', 'list', '--state', 'merged', '--limit', '200',
                                                     '--json', 'headRefName,headRefOid',
                                                     '--jq', '.[] | [.headRefName, .headRefOid] | @tsv') `
                                        -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
        $ghKnown = ($prList.ExitCode -eq 0)
        if ($ghKnown) {
            $mergedTips = Get-MergedPrTipsFromTsv -Lines @($prList.Output)
        } elseif ($prList.TimedOut) {
            Write-Host "  'gh pr list' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- the merged set reads as unknown." -ForegroundColor Yellow
        }
    }

    foreach ($name in $candidates) {
        Invoke-SyncGitQuiet @('merge-base', '--is-ancestor',
            "refs/remotes/origin/$name", "refs/remotes/origin/$trunk") | Out-Null
        if ($LASTEXITCODE -eq 0) { continue }

        # THE TIP IS READ OFF THE SAME REF THE ANCESTRY TEST JUST USED, deliberately: two proofs reading
        # two different objects can disagree about which branch they are judging, and the fetch above has
        # already made this one current. An unreadable ref leaves it empty, which Test-RefMergedByPr
        # reads as 'not merged' -- the refusal direction, as everywhere else in this step.
        $tip = ([string](@(Invoke-SyncGitQuiet @('rev-parse', '--verify', '--quiet',
            "refs/remotes/origin/$name")) | Select-Object -First 1)).Trim()
        if (Test-RefMergedByPr -Name $name -Tip $tip -MergedTips $mergedTips) { continue }

        # What that branch captured. Three dots: the branch side of the merge base, which for a sync
        # branch is exactly the file set the run behind it decided to take. An unreadable diff leaves
        # Paths empty, and Get-SyncPredecessorReport reads that as "not superseded" rather than as "no
        # paths, therefore covered".
        # 'core.quotePath=true' PLUS THE UNPACKER, the same pair as the 'ls-tree' and 'check-ignore'
        # reads further down, and for the same reason (inbound #821, issue #1629). This read was the one
        # that never got it. These paths are not display-only: Get-SyncPredecessorReport compares them
        # against this run's take set, whose paths come off the mirror WALK as real .NET strings. So a
        # path with a byte above 0x7F has to arrive decoded or the comparison is wrong -- and left to
        # git's default a repo may set 'core.quotepath' in its own config, which puts the console code
        # page back in charge of the answer. Measured, git 2.55: with the flag off, 'assets/cafe.js'
        # with an accent comes out as raw UTF-8 bytes; with it on, '"assets/caf\303\251.js"', which is
        # pure ASCII on the wire and decoded here once.
        #
        # THE WRONG ANSWER IT WOULD PRODUCE IS THE ONE THAT MATTERS: an uncovered path is what tells the
        # operator this run does NOT supersede that branch, so a path that fails to match its own twin
        # in the take set reports a predecessor as independent when it is not.
        $predPaths = @(Invoke-SyncGitQuiet @('-c', 'core.quotePath=true', 'diff', '--name-only',
            "refs/remotes/origin/$trunk...refs/remotes/origin/$name") |
            ForEach-Object { Convert-GitQuotedPath -Path (([string]$_).Trim()) } | Where-Object { $_ })
        $standing += [pscustomobject]@{ Branch = $name; Paths = @($predPaths) }
    }

    if ($standing.Count -eq 0) {
        Write-Host "      $($candidates.Count) found on origin, all merged."
    } else {
        foreach ($s in $standing) {
            $n    = @($s.Paths).Count
            $what = if ($n -gt 0) { "$n file(s)" } else { 'file set unreadable' }
            # SAME ls-remote NAME AS THE PREDECESSOR ROWS BELOW, and stripped for the same reason
            # (issue #1623): whoever pushed a branch matching the prefix chose this text, and this is
            # the line the operator reads it from first.
            Write-Host "      STILL STANDING: $(Get-DisplayRef -Ref ([string]$s.Branch)) -- $what" -ForegroundColor Yellow
        }
        if (-not $ghKnown) {
            Write-Host '      (gh could not list merged PRs, so a squash-merged branch reads as standing.)' -ForegroundColor DarkGray
        }
        if (-not $DryRun -and -not $AllowStacking) {
            Write-Host ''
            Write-Host "Refusing: $($standing.Count) sync branch(es) from a previous run are still standing." -ForegroundColor Red
            Write-Host '  Stopping before the merge only works while somebody then merges. Until one of these' -ForegroundColor Red
            Write-Host '  lands, this run would re-capture the same drift onto a second branch and the trunk' -ForegroundColor Red
            Write-Host '  would still lack it -- so nothing is gained and there is one more thing to read.' -ForegroundColor Red
            Write-Host '  Nothing was pulled and nothing was written.' -ForegroundColor Red
            Write-Host ''
            Write-Host '  Look at what those branches hold, merge or close them, then run this again:' -ForegroundColor Yellow
            # JUDGED PER BRANCH, not once (issue #1627). #1623 stripped these same names for the rows it
            # prints as prose, on the ground that `git ls-remote` is where they come from and nothing here
            # validated them; this is that same reach on the PASTE axis, where the remedy is a placeholder
            # rather than a strip. A stripped name in a command would hand the reader a line that runs with
            # a DIFFERENT value than the one on screen, which is worse than refusing to print it.
            # `git check-ref-format` is no help either: it exits 0 on 'fix/evil;touch', 'fix/evil$(touch)'
            # and 'fix/evil`touch`' alike (#1594's own measurement). Each line carries its own note beneath
            # it, so two unsafe predecessors stay tellable apart.
            foreach ($s in $standing) {
                $sPaste = Get-PasteableRef -Ref ([string]$s.Branch)
                Write-Host "    gh pr list --head $($sPaste.Token) --state open" -ForegroundColor Cyan
                if ($sPaste.Note) { Write-Host $sPaste.Note -ForegroundColor Cyan }
            }
            Write-Host '  Or ask whether THIS run supersedes them, without writing anything:' -ForegroundColor Yellow
            Write-Host '    -DryRun         reports the per-branch verdict and stops' -ForegroundColor Cyan
            Write-Host '  Or, where a predecessor is genuinely independent -- a path reverted on live since:' -ForegroundColor Yellow
            Write-Host '    -AllowStacking' -ForegroundColor Cyan
            exit 1
        }
        if ($AllowStacking -and -not $DryRun) {
            Write-Host '      -AllowStacking: continuing anyway; the verdict per branch follows below.' -ForegroundColor Magenta
        }
    }
}

# --- 5. live, into a MIRROR outside the repo --------------------------------------------------------
Write-Host ''
Write-Host '[4/6] mirroring live ...' -ForegroundColor Yellow
$mirror = $MirrorPath
$pulledMirror = $false
if (-not $mirror) {
    $mirror = Join-Path ([System.IO.Path]::GetTempPath()) ('live-mirror-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
    New-Item -ItemType Directory -Path $mirror -Force | Out-Null
    $pulledMirror = $true
    # STREAMED, NOT CAPTURED, and that is the one thing this wrapper is asked for beyond the exit code.
    # A theme pull runs for minutes on a real theme and the CLI can stop to ask for authentication; a
    # captured call would show the operator nothing until it was over, which turns a prompt into a hang.
    $pull = Invoke-ShopifyCli -Arguments @('theme', 'pull', '--store', $store, '--theme', $liveId, '--path', $mirror)
    if ($pull.ExitCode -ne 0) {
        Write-Host 'The Shopify pull failed. Nothing was touched.' -ForegroundColor Red
        if (-not $KeepMirror) { Remove-Item -LiteralPath $mirror -Recurse -Force -ErrorAction SilentlyContinue }
        exit 1
    }
} else {
    if (-not (Test-Path -LiteralPath $mirror)) { Write-Host "MirrorPath does not exist: $mirror" -ForegroundColor Red; exit 1 }
    Write-Host "      using the mirror given: $mirror"
}

try {
    # --- which paths differ at all ------------------------------------------------------------------
    # Two stages, for process count rather than correctness -- see Get-GitRawBlobId. Stage one is pure
    # .NET against 'git ls-tree'; only what survives it pays for a git call.
    #
    # 'ls-tree -r HEAD' IS READ IN ITS DEFAULT FORMAT, not through '--format'. The format option arrived
    # in git 2.36 and this script has no reason to require it: the default line is
    # '<mode> SP <type> SP <oid> TAB <path>', and the tab is what makes a path with spaces safe to split.
    #
    # A PATH WITH A HIGH BYTE FAILS IN THE LOSING DIRECTION, so how it is read off git matters. git's
    # default is to quote any path with a byte above 0x7F -- 'assets/cafe.js' with an accent comes out as
    # '"assets/caf\303\251.js"', measured against git 2.54 -- and that string matches no key the mirror
    # walk produces. The trunk's copy then reads as a path live does not have (kept, correctly) while
    # live's identical file reads as one the trunk has never held: foreign, taken, and the trunk's version
    # overwritten.
    #
    # 'core.quotePath=false' WAS THE FIRST REPAIR AND IT WAS HALF OF ONE (inbound #821, August 21, 2026).
    # It makes git emit the raw UTF-8 bytes instead -- and PowerShell decodes those with
    # [Console]::OutputEncoding, i.e. with whatever console code page the run inherited. On cp850, the
    # default OEM console here, they decode to two wrong characters and the comparison lands in exactly
    # the failure above. The flag fixed the quoting and moved the same bug into the decoder, where it is
    # invisible: the answer depended on who launched the run.
    #
    # SO QUOTING IS FORCED **ON** AND THE ESCAPES ARE UNPACKED HERE. Quoted, the wire is pure ASCII, where
    # every candidate code page agrees -- Convert-GitQuotedPath (sync-rules.ps1) turns the escapes back
    # into bytes and reads them as UTF-8 once, so no environment can reach the answer. 'true' rather than
    # git's default, because a repo may set core.quotepath in its own config and would otherwise put the
    # decoder back in charge. The same treatment goes on 'check-ignore', whose output is a path for the
    # same reason.
    Write-Host ''
    Write-Host "[5/6] comparing live against $trunkShown ..." -ForegroundColor Yellow

    $headBlobs = @{}
    foreach ($line in (& git -c core.quotePath=true ls-tree -r HEAD)) {
        if (-not $line) { continue }
        $tab = $line.IndexOf("`t")
        if ($tab -lt 0) { continue }
        $meta = ($line.Substring(0, $tab) -split '\s+')
        if ($meta.Count -lt 3) { continue }
        $headBlobs[(Convert-GitQuotedPath -Path $line.Substring($tab + 1))] = $meta[2]
    }

    $mirrorPaths = @{}
    foreach ($d in $ThemeDirs) {
        $dir = Join-Path $mirror $d
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($f in (Get-ChildItem -LiteralPath $dir -Recurse -File)) {
            $rel = $f.FullName.Substring($mirror.Length).TrimStart('\', '/') -replace '\\', '/'
            $mirrorPaths[$rel] = $f.FullName
        }
    }
    Write-Host "      live: $($mirrorPaths.Count) file(s) across the theme director(ies) present"

    # GITIGNORED PATHS ARE NOT THE SYNC'S BUSINESS. config/settings_data.json is the obvious one: a repo
    # that ignores the live theme's settings would otherwise see it arrive as a brand-new foreign file on
    # every single run and capture it forever.
    #
    # THE PATHS GO IN AS ARGUMENTS, NOT THROUGH '--stdin', AND THAT IS MEASURED. 'git check-ignore
    # --stdin <paths>' answers 'fatal: cannot specify pathnames with --stdin' and exits 128, which this
    # wrapper swallows -- so the whole filter silently reports nothing ignored. Feeding real stdin is not
    # available either: Windows PowerShell 5.1 does not connect a pipeline to a native executable's stdin
    # here, and it has no '<' redirect ("The '<' operator is reserved for future use"). Both forms were
    # tried against git 2.54 before this loop was written. Batched because a whole theme's worth of paths
    # would otherwise approach the command-line length limit.
    $ignored = @{}
    $allPaths = @($mirrorPaths.Keys)
    for ($i = 0; $i -lt $allPaths.Count; $i += 200) {
        $batch = @($allPaths[$i..([Math]::Min($i + 199, $allPaths.Count - 1))])
        if ($batch.Count -eq 0) { continue }
        # Quoted on the wire and unpacked here, the same way ls-tree is read above and for the same
        # reason -- a raw high byte would be decoded by the inherited console code page (inbound #821).
        foreach ($hit in @(Invoke-SyncGitQuiet @(@('-c', 'core.quotePath=true', 'check-ignore', '--') + $batch))) {
            if ($hit) { $ignored[(Convert-GitQuotedPath -Path ([string]$hit).Trim())] = $true }
        }
    }
    if ($ignored.Count -gt 0) { Write-Host "      $($ignored.Count) of them are gitignored here and are left alone" }

    $differing = @()
    foreach ($rel in ($mirrorPaths.Keys | Sort-Object)) {
        if ($ignored.ContainsKey($rel)) { continue }
        $bytes = [System.IO.File]::ReadAllBytes($mirrorPaths[$rel])
        if ($headBlobs.ContainsKey($rel)) {
            # Stage one: byte-identical to what the trunk stores.
            if ($headBlobs[$rel] -eq (Get-GitRawBlobId -Bytes $bytes)) { continue }
            # Stage two: identical once CR bytes are ignored -- the line-ending case, measured at 37 of
            # 712 files in one consumer. Compared against the trunk's STORED id, never against bytes read
            # back through the PowerShell pipeline; that read is what corrupted the first version of this.
            if ($headBlobs[$rel] -eq (Get-GitRawBlobId -Bytes (Get-CrStrippedBytes -Bytes $bytes))) { continue }
            $differing += [pscustomobject]@{ Status = 'M'; Path = $rel; Bytes = $bytes; Source = $mirrorPaths[$rel] }
        } else {
            $differing += [pscustomobject]@{ Status = 'A'; Path = $rel; Bytes = $bytes; Source = $mirrorPaths[$rel] }
        }
    }
    # Paths the trunk has under a theme directory that live does not.
    foreach ($rel in ($headBlobs.Keys | Sort-Object)) {
        $top = ($rel -split '/')[0]
        if ($ThemeDirs -notcontains $top) { continue }
        if ($mirrorPaths.ContainsKey($rel)) { continue }
        if ($ignored.ContainsKey($rel)) { continue }
        $differing += [pscustomobject]@{ Status = 'D'; Path = $rel; Bytes = (New-Object byte[] 0); Source = '' }
    }

    if ($differing.Count -eq 0) {
        Write-Host ''
        Write-Host "No differences at all -- $trunkShown already matches live." -ForegroundColor Green
        exit 0
    }
    Write-Host "      $($differing.Count) path(s) differ (line-ending-only differences already excluded)"

    # --- the verdict per path -----------------------------------------------------------------------
    Write-Host ''
    Write-Host '[6/6] applying the rule ...' -ForegroundColor Yellow
    $take = @(); $keep = @(); $conflict = @()
    foreach ($f in $differing) {
        if ($f.Status -eq 'D') {
            $v = Get-SyncFileVerdict -Status 'D' -LiveContentIsOurs $false
        } else {
            $ours = Test-LiveContentIsOurs -Path $f.Path -LiveBytes $f.Bytes -Ref 'HEAD'
            # THE BASE IS THIS PATH'S OWN, NOT THE RUN'S (inbound #1535). $since above is the previous
            # sync commit for the REPO, and a sync commit only establishes agreement with live for the
            # paths it actually took -- so for any other path it is a base newer than the trunk's own
            # work there, from which the trunk reads as stationary and live is taken silently. The base
            # asked for here is the most recent sync commit that touched THIS path, and $null means no
            # such moment exists, which Get-SyncFileVerdict reports rather than decides.
            #
            # Still only where it can change the answer: live's content has to be foreign first, which is
            # also what keeps the extra 'git log' off every path that is already settled by provenance.
            $pathBase = $null
            $touched  = $false
            if (-not $ours) {
                $pathBase = Get-SyncPathReferencePoint -Path $f.Path -Ref 'HEAD' -Pattern $pattern
                if ($pathBase) { $touched = Test-MainTouchedSince -Since $pathBase -Path $f.Path }
            }
            $v = Get-SyncFileVerdict -Status $f.Status -LiveContentIsOurs $ours `
                    -MainTouchedSinceFloor $touched -PathAgreementKnown ([bool]$pathBase)
        }
        $row = [pscustomobject]@{ Status = $f.Status; Path = $f.Path; Source = $f.Source; Reason = $v.Reason }
        switch ($v.Action) {
            'take-live' { $take     += $row }
            'conflict'  { $conflict += $row }
            default     { $keep     += $row }
        }
    }

    Write-Host ''
    # THE PRIMARY REPORT GOES THROUGH THE DISPLAY STRIP, LIKE EVERY REF ON THIS PAGE (issue #1638). The
    # paths reaching these three lines are real .NET strings by the time they arrive -- Convert-GitQuotedPath
    # has already decoded $headBlobs' keys, so a \p{Cc} in this repo's own tree is a live escape byte
    # here rather than git's C-quoted rendering of one, and $mirrorPaths came off Get-ChildItem where no
    # quoting was ever involved. These lines are printed in a loop, so one ESC[2K in a path repaints the
    # rows above it.
    #
    # AND Get-DisplayPath RATHER THAN Get-DisplayRef, which is the whole reason that function exists.
    # The '{1,-46}' padding is the second half of the defect: a zero-width \p{Cf} run spends format
    # width without spending display columns, so the row slides against its neighbours in a list a
    # reader scans by column. Replacing each removed character with one space puts the two widths back
    # in step -- and collapsing the runs, which the ref strip does, would undo exactly that.
    Write-Host "  held back ($trunkShown wins): $($keep.Count)" -ForegroundColor Green
    foreach ($r in $keep) { Write-Host ("    [{0}] {1,-46} {2}" -f $r.Status, (Get-DisplayPath -Path $r.Path), $r.Reason) -ForegroundColor DarkGray }
    Write-Host "  to take from live:       $($take.Count)" -ForegroundColor Cyan
    foreach ($r in $take) { Write-Host ("    [{0}] {1,-46} {2}" -f $r.Status, (Get-DisplayPath -Path $r.Path), $r.Reason) -ForegroundColor Cyan }
    if ($conflict.Count -gt 0) {
        Write-Host "  CONFLICTS:               $($conflict.Count)" -ForegroundColor Red
        foreach ($r in $conflict) { Write-Host ("    [{0}] {1,-46} {2}" -f $r.Status, (Get-DisplayPath -Path $r.Path), $r.Reason) -ForegroundColor Red }
    }

    if ($conflict.Count -gt 0) {
        Write-Host ''
        Write-Host 'REFUSING TO SYNC. Both sides changed the paths above, so taking either would lose the' -ForegroundColor Red
        Write-Host 'other. Nothing has been written. Compare them by hand and merge deliberately:' -ForegroundColor Red
        foreach ($r in $conflict) {
            # THE PASTE AXIS, AND THE UNTRUSTED VALUE APPEARS TWICE IN ONE LINE (issue #1637). This is a
            # command a reader is invited to copy and run, and $mirrorFile is DERIVED from $r.Path, so a
            # single hostile path used to poison both operands. It is judged once and answered as a
            # pair: either both halves carry the real path or both read '<path>', never one of each,
            # which would print a `git diff` whose two operands are different files.
            #
            # THE DOUBLE QUOTES THAT USED TO BE HERE WERE THE DEFECT, NOT THE GUARD. ref-print-lib is
            # explicit that command substitution runs inside double quotes in bash and in PowerShell
            # alike, so quoting a hostile value closes nothing -- and it reads as protection, which is
            # worse than a bare interpolation because the next reader stops looking.
            $pathPaste = Get-PasteableRef -Ref $r.Path -Placeholder '<path>' -Kind Path
            $mirrorFile = if ($pathPaste.IsSafe) {
                Join-Path $mirror ($r.Path -replace '/', '\')
            } else {
                # The placeholder is joined the same way, so the mirror operand shows where that path
                # goes: 'C:\...\mirror\<path>'. The pair is visibly one substitution, which is what tells
                # the reader the two holes take the same value.
                Join-Path $mirror $pathPaste.Token
            }
            # THE MIRROR OPERAND IS STILL QUOTED, AND THAT IS NOT THE SPELLING REJECTED ABOVE. What sits
            # inside these quotes is $mirror -- built by this run from its own seam answer and the
            # machine's profile path -- plus a half that has either passed the allowlist or been replaced
            # by the placeholder. The quotes are here for a SPACE in that profile path
            # ('C:\Users\Ada Lovelace\...'), the one thing an allowlist over the theme path cannot speak
            # to because it never saw the prefix. They are not standing in for the refusal; the refusal
            # above is. The repo operand needs none for the same reason it is safe at all.
            Write-Host "  git diff --no-index -- $($pathPaste.Token) `"$mirrorFile`"" -ForegroundColor Yellow
            if (-not $pathPaste.IsSafe) { Write-Host $pathPaste.Note -ForegroundColor DarkYellow }
        }
        # The mirror is what those commands read, so a refused run keeps it whatever the switch says.
        $KeepMirror = $true
        exit 1
    }

    if ($take.Count -eq 0) {
        Write-Host ''
        Write-Host "No third-party drift. Everything live holds differently is a version this repo has had" -ForegroundColor Green
        Write-Host "before -- $trunkShown has simply moved on. Nothing to sync, nothing written." -ForegroundColor Green
        # AND THIS IS THE MOST MISLEADING PLACE TO STOP WITHOUT SAYING IT. "Nothing to sync" is true of
        # live and false of the repo while a predecessor stands: that branch holds drift the trunk still
        # lacks, and an empty take set makes every one of its paths uncovered -- correctly. Without this
        # line the run reads as "all clear" to the one operator who most needs to go and merge something.
        Write-SyncPredecessorVerdict -Standing $standing -TakePaths @()
        exit 0
    }

    if ($DryRun) {
        Write-Host ''
        Write-Host "DRY RUN -- would put the $($take.Count) file(s) above on $branchShown. Nothing written." -ForegroundColor Magenta
        # THE DRY RUN IS THE ONE PLACE THIS VERDICT IS THE WHOLE POINT OF THE RUN. A dry run is exempt from
        # the refusal at [3b/6] precisely so somebody staring at open sync PRs can ask "does today's drift
        # supersede that pile?" -- and this is the answer to that question.
        Write-SyncPredecessorVerdict -Standing $standing -TakePaths @($take | ForEach-Object { $_.Path })
        exit 0
    }

    # --- the sync branch: write ONLY what was decided, commit, push ---------------------------------
    # REACHABLE WITH A PREDECESSOR STANDING ONLY UNDER -AllowStacking, so the verdict is printed BEFORE
    # anything is written rather than after the push. The operator asked for a second candidate; what they
    # get is a second candidate whose relationship to the first is on the screen.
    Write-SyncPredecessorVerdict -Standing $standing -TakePaths @($take | ForEach-Object { $_.Path })

    Write-Host ''
    Write-Host "Third-party drift on $($take.Count) file(s); putting it on $branchShown." -ForegroundColor Cyan
    & git checkout -b $branch | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host "Could not create $branchShown. Nothing written." -ForegroundColor Red; exit 1 }

    foreach ($r in $take) {
        $dest = Join-Path $repoRoot ($r.Path -replace '/', '\')
        $destDir = Split-Path -Parent $dest
        if ($destDir -and -not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -LiteralPath $r.Source -Destination $dest -Force
    }

    $paths = @($take | ForEach-Object { $_.Path })

    # THE SYNC LOG RIDES IN THIS COMMIT, and that is the whole reason it needs no gate (inbound #1382).
    # The script that creates the branch writes the record in the same breath -- the shape new-branch.ps1
    # uses for a changelog entry -- so a sync branch cannot be record-less and there is nothing left for a
    # check to catch after the fact. Written here, BEFORE the add, because the add is path-bounded: a file
    # produced after it would sit untracked in the working copy and the run would report a clean success.
    $logRel = Write-SyncLogEntry -RepoRoot $repoRoot -RelativePath $seam.SyncLogPath `
                                 -Branch $branch -Date $stamp -Take $take -Keep $keep
    if ($logRel) { $paths = @($paths) + $logRel }

    Invoke-SyncGitQuiet @(@('add', '--') + $paths) | Out-Null

    $msg = "sync: mirror in-flight third-party edits from live ($($take.Count) file(s))"
    & git commit --quiet -m $msg -- @paths
    if ($LASTEXITCODE -ne 0) { Write-Host 'Commit failed.' -ForegroundColor Red; exit 1 }

    # BOUNDED, AND THIS IS THE WORST OF THE FIVE TO STALL IN (inbound #1181). The commit above holds a
    # third party's in-flight edits to the live theme, taken out of a mirror the finally block then
    # deletes -- so until this push lands, the only copy of that work is a local branch nobody is looking
    # at, and a hang presents it as a push still in progress. The bound is what turns that into the
    # message below, which already says the right thing.
    $push = Invoke-NativeCapture -FilePath 'git' -Arguments @('push', '-u', 'origin', $branch) `
                                 -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    $push.Output | ForEach-Object { Write-Host $_ }
    if ($push.ExitCode -ne 0) {
        Write-Host "Push failed. The commit is local on $branchShown." -ForegroundColor Red
        if ($push.TimedOut) {
            Write-Host "  'git push' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] lines above." -ForegroundColor Red
            Write-Host "  The branch is NOT on origin. Fix the credential and push it by hand: git push -u origin $($branchPaste.Token)" -ForegroundColor Red
            if ($branchPaste.Note) { Write-Host $branchPaste.Note -ForegroundColor Red }
        }
        exit 1
    }

    # --- the PR body, composed ONCE for both paths --------------------------------------------------
    # BOTH PATHS, AND THAT IS THE HALF INBOUND #1000 MADE THE CASE FOR. The merging path used to compose
    # a body naming only what was held back, and the non-merging path composed none at all -- it printed
    # a 'gh pr create' line with no --body and told the operator to copy the exclusions in by hand. The
    # default path is the one most consumers run, so the path with no body was the common one.
    #
    # THE FILE RATHER THAN AN INLINE --body ON THE PRINTED LINE. A body is multi-line markdown, and a
    # command line an operator pastes cannot carry it: quoted newlines survive neither a copy out of a
    # console nor a paste into a different shell. --body-file is what gh has for this, so the run writes
    # the body and hands over the path. It is left behind on purpose -- the operator needs it AFTER this
    # process is gone, which is also why it does not go in the mirror the finally block removes.
    $defaultBody = New-SyncPrBody -Take $take -Keep $keep
    $seamBody    = Get-SyncPrBodySeamAnswer -RepoRoot $repoRoot -Take $take -Keep $keep -Default $defaultBody
    $body        = if ($seamBody) { $seamBody } else { $defaultBody }
    if ($seamBody) { Write-Host 'PR body: composed by Get-ShopifySyncPrBody.' -ForegroundColor DarkGray }

    # --- the labels, composed ONCE for both paths too ------------------------------------------------
    # '--label' REPEATED RATHER THAN ONE COMMA-SEPARATED VALUE: gh accepts both, and repeating it is the
    # form that cannot be broken by a label whose own name contains a comma. As arguments for the create
    # below and as text for the line the operator pastes, from the same list, so the two cannot disagree.
    $labelArgs = @(); foreach ($l in $prLabels) { $labelArgs += @('--label', $l) }
    $labelText = ($prLabels | ForEach-Object { " --label `"$_`"" }) -join ''
    if ($prLabels.Count -gt 0) {
        Write-Host "PR label(s) from Get-ShopifySyncPrLabels: $($prLabels -join ', ')" -ForegroundColor DarkGray
    }

    if (-not $merges) {
        $bodyFile = New-ScratchPath -Label ("sync-pr-body-" + ($branch -replace '[^A-Za-z0-9]', '-')) -Extension '.md'
        [System.IO.File]::WriteAllText($bodyFile, $body, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host ''
        Write-Host 'Done -- and deliberately NOT merged.' -ForegroundColor Green
        Write-Host 'Open the PR, look at what the third parties changed, and merge it yourself:' -ForegroundColor Green
        Write-Host "  gh pr create --base $($trunkPaste.Token) --head $($branchPaste.Token) --title `"$msg`" --body-file `"$bodyFile`"$labelText" -ForegroundColor Cyan
        if ($branchPaste.Note) { Write-Host $branchPaste.Note -ForegroundColor Cyan }
        if ($trunkPaste.Note)  { Write-Host $trunkPaste.Note  -ForegroundColor Cyan }
        Write-Host ''
        if ($prLabels.Count -gt 0) {
            # WHY THE PRINTED LINE CARRIES THEM AND THE NOTE SAYS SO. This path is the default one, so it is
            # the common one -- and a repo that answered the label seam did so because an unlabelled PR fails
            # its guardrail. Printing a line without them would hand the operator the exact failure the seam
            # was answered to prevent, one paste later.
            Write-Host '  The --label flag(s) are Get-ShopifySyncPrLabels'' answer; keep them on the line.' -ForegroundColor DarkGray
        }
        if ($seamBody) {
            # The claim below is about the DEFAULT body's shape, and a seam is free to drop either half.
            # Printing it over somebody else's body would be this script vouching for a record it did not
            # write -- the one thing the whole change is about.
            Write-Host '  The body is Get-ShopifySyncPrBody''s; read it before you open the PR.' -ForegroundColor DarkGray
        } else {
            Write-Host "  The body names all $($take.Count) taken and $($keep.Count) held-back path(s) with their kind." -ForegroundColor DarkGray
            Write-Host '  The diff shows what came in, never what was held back or what live no longer has.' -ForegroundColor DarkGray
        }
        exit 0
    }

    # --- the merging variant ------------------------------------------------------------------------
    # Only reached where Get-ShopifySyncMerges says so. It uses nothing but 'gh': a consumer on either
    # workflow plugin, or on neither, gets the same behaviour, and Get-PrMergeMethod is read defensively
    # above rather than required. Get-ShopifySyncPrLabels is read the same way and adds no dependency --
    # '--label' is gh's own flag, which is what kept the label answer on this side of that line.
    #
    # ON THE CREATE RATHER THAN A 'gh pr edit --add-label' AFTER IT, deliberately: the guardrail that made
    # this necessary reads the labels when it RUNS, and a PR opened bare starts its first check run bare.
    # Labelling a moment later leaves a red run to re-trigger, which is most of the failure still standing.
    # The cost is that a label the repo does not have fails the create outright instead of degrading -- gh
    # validates before opening -- and that is the better end to fail at: the branch is pushed, nothing is
    # lost, and the message below says what to do.
    #
    # '+ $labelArgs' AND NOT '@labelArgs', since the call became an -Arguments list (inbound #1184).
    # The trap the splat form was chosen to avoid is the same one and it is still live: measured against
    # Windows PowerShell 5.1, a bare '$labelArgs' on the '&' path passed an EMPTY STRING argument that gh
    # reads as a positional and rejects, and no label is the default -- the path nearly every consumer
    # takes. Array concatenation is the form that cannot reach it: '@(...) + @()' is the base array,
    # contributing no element at all, which is what the splat did. Same shape as open-pr.ps1's create.
    #
    # AND THE MULTI-LINE BODY SURVIVES THE BOUNDED ARM, which is worth stating because a bound implies
    # Start-Process and therefore this lib's own argument quoter rather than PowerShell's. Measured
    # through a round-trip echo: the body arrives as ONE argument with its blank lines, its embedded
    # double quotes and a trailing backslash intact. So '--body' stays inline here and does not need the
    # '--body-file' the printed path uses -- that file exists because a console PASTE cannot carry
    # newlines, which is a different problem from CreateProcess's.
    # BOUNDED, AND THIS IS THE ONE THE REPORT ARGUED FROM (inbound #1184). It runs directly after the
    # push, so a stall here leaves the branch on origin with NO PR -- a state nothing in this family
    # reports and no later step goes looking for. The bound turns it into the message below, which
    # already says the right thing: the branch is pushed, open it by hand.
    #
    # STDERR MERGED, unlike the two --json reads, because this output is PROGRESS: gh writes the PR URL
    # there and that URL is the one thing the operator wants off this line. It is echoed rather than
    # printed by gh directly, which is what routing through the lib costs and all it costs.
    $create = Invoke-NativeCapture -FilePath 'gh' `
                                   -Arguments (@('pr', 'create', '--base', $trunk, '--head', $branch,
                                                 '--title', $msg, '--body', $body) + $labelArgs) `
                                   -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    $create.Output | ForEach-Object { Write-Host $_ }
    if ($create.ExitCode -ne 0) {
        Write-Host 'Could not open the PR. The branch is pushed; open it by hand.' -ForegroundColor Red
        if ($create.TimedOut) {
            Write-Host "  'gh pr create' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] lines above." -ForegroundColor Red
            Write-Host '  The branch IS on origin. Check whether the PR exists before opening a second one.' -ForegroundColor Red
        }
        if ($prLabels.Count -gt 0) {
            Write-Host "  If it named a label: gh refuses a label this repo does not have. Answered: $($prLabels -join ', ')" -ForegroundColor Red
            Write-Host '  Create the label, or correct Get-ShopifySyncPrLabels in scripts/repo-config.ps1.' -ForegroundColor Red
        }
        exit 1
    }

    # BOUNDED, AND IT HAD NO EXIT-CODE CHECK AT ALL, which the report did not name (inbound #1184). The
    # output went straight into .Trim(), so a failed read produced an EMPTY $pr rather than a message --
    # and then 'gh pr checks' below was called with no PR number, found no states, and slept its way
    # through the whole of -ChecksTimeoutMinutes before printing 'gh pr merge  --squash' for the operator
    # to run. The PR was open and green the entire time. That is the same shape #1181 named on the trunk
    # pull: the one failure nobody would go looking for.
    #
    # -DiscardStderr BECAUSE THE OUTPUT IS DATA -- a PR number that a stderr line would corrupt into
    # something .Trim() still returns happily. First non-empty line rather than the whole capture, since
    # the bounded arm returns an ARRAY of lines (the [timeout] note is appended to it on a stall).
    $prView = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr `
                                   -Arguments @('pr', 'view', $branch, '--json', 'number', '--jq', '.number') `
                                   -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    $pr = ([string](@($prView.Output | Where-Object { ([string]$_).Trim() }) | Select-Object -First 1)).Trim()
    if ($prView.ExitCode -ne 0 -or -not $pr) {
        Write-Host 'The PR was opened, but its number could not be read -- so CI is NOT being waited on.' -ForegroundColor Red
        if ($prView.TimedOut) {
            Write-Host "  'gh pr view' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] lines above." -ForegroundColor Red
        }
        Write-Host "  Nothing is lost; the PR is open on $branchShown. Merge it yourself once CI is green." -ForegroundColor Red
        exit 1
    }
    Write-Host "Sync PR #$pr opened; waiting up to $ChecksTimeoutMinutes min for CI." -ForegroundColor Cyan

    $deadline = (Get-Date).AddMinutes($ChecksTimeoutMinutes)
    while ((Get-Date) -lt $deadline) {
        # BOUNDED PER CALL, WHICH IS NOT THE BOUND THE LOOP ALREADY HAD (inbound #1187).
        # -ChecksTimeoutMinutes is re-read only at the top of this while, so it bounds the number of
        # ITERATIONS over wall clock and not any single call: one 'gh pr checks' that never returns
        # never reaches the condition again, and the deadline below is never evaluated. That is the
        # class #1179 and #1181 named, arriving through the one call that looked already bounded.
        #
        # -DiscardStderr IS THE HAND-ROLLED EAP BRACKET THIS REPLACES, and it does both halves of what
        # that bracket did. 'gh pr checks' writes to stderr while a run is still pending -- exactly the
        # state this loop exists to sit through -- so the noise must be SWALLOWED while states are still
        # read off stdout. The flag drops stderr at the capture rather than merging it, and the child
        # runs under EAP=Continue inside the lib's own scope, which is the other half.
        #
        # NOT THE 'gh pr checks --watch' CASE the lib's docstring warns about, which is why a bound is
        # right here. That call blocks for as long as CI takes BY DESIGN (ship-pr.ps1); this one is a
        # poll that answers in seconds and sleeps 15 between tries. The loop's deadline and the call's
        # bound answer different questions, and both are wanted.
        $poll = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr `
                                     -Arguments @('pr', 'checks', $pr, '--json', 'state', '--jq', '.[].state') `
                                     -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
        # A TIMEOUT IS 'THIS POLL DID NOT ANSWER', NOT A RED CHECK, so the run keeps polling until the
        # deadline: a slow answer is not a verdict. Its Output is discarded rather than parsed, and that
        # is load-bearing -- the bounded arm APPENDS two '[timeout]' lines to Output, which would arrive
        # here as two states matching nothing and be reported as CI failure on the next line.
        #
        # A NON-ZERO EXIT IS NOT A VERDICT EITHER, which is why only TimedOut is judged. 'gh pr checks'
        # exits 8 while checks are pending and 1 when one has failed, and this loop has always read the
        # STATES rather than the code. Gating on ExitCode -eq 0 would throw away a real failure's states
        # and sit out the whole of -ChecksTimeoutMinutes before reporting 'not green' for a PR that is red.
        if ($poll.TimedOut) {
            Write-Host "  'gh pr checks' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- polling again until the $ChecksTimeoutMinutes min deadline." -ForegroundColor Yellow
            $states = @()
        } else {
            $states = @($poll.Output | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
        }
        if ($states.Count -eq 0) { Start-Sleep -Seconds 15; continue }
        $bad = @($states | Where-Object { $_ -notin @('SUCCESS', 'NEUTRAL', 'SKIPPED', 'PENDING', 'QUEUED', 'IN_PROGRESS') })
        if ($bad.Count -gt 0) {
            Write-Host "CI failed on sync PR #$pr ($($bad -join ', ')) -- NOT merged." -ForegroundColor Red
            Write-Host '  In a Shopify repo this is usually theme-check over a third party''s edit. Fix it as its own' -ForegroundColor Red
            Write-Host "  named change, then: gh pr merge $pr --$mergeMethod" -ForegroundColor Red
            exit 1
        }
        if (@($states | Where-Object { $_ -in @('PENDING', 'QUEUED', 'IN_PROGRESS') }).Count -eq 0) { break }
        Start-Sleep -Seconds 15
    }

    if ((Get-Date) -ge $deadline) {
        Write-Host "CI on sync PR #$pr was not green within $ChecksTimeoutMinutes min -- NOT merged." -ForegroundColor Red
        Write-Host "  Merge it yourself once it is: gh pr merge $pr --$mergeMethod" -ForegroundColor Red
        exit 1
    }

    # --subject gives the merge commit the same shape as every other line in the graph. On a squash or
    # rebase method gh has no merge commit to name and ignores the flag.
    #
    # BOUNDED, AND THROUGH THE LIB (inbound #1184). Stderr stays merged because this output is progress,
    # and it is echoed for the same reason the push above is. A stall here is the one place in this
    # script where the operator cannot tell from the message alone whether the work landed -- gh may have
    # merged and then failed to report -- so the timeout line says to LOOK rather than to retry, which
    # is the opposite of what the unbounded shape's silence invited.
    $merge = Invoke-NativeCapture -FilePath 'gh' `
                                  -Arguments @('pr', 'merge', "$pr", "--$mergeMethod",
                                               '--subject', "merge: $branch (#$pr)") `
                                  -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    $merge.Output | ForEach-Object { Write-Host $_ }
    if ($merge.ExitCode -ne 0) {
        Write-Host "The merge failed. PR #$pr is open and green; merge it by hand." -ForegroundColor Red
        if ($merge.TimedOut) {
            Write-Host "  'gh pr merge' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] lines above." -ForegroundColor Red
            Write-Host "  Check whether it landed before retrying: gh pr view $pr --json state" -ForegroundColor Red
        }
        exit 1
    }

    # BOUNDED, AND JUDGED, WHICH IT WAS NOT BEFORE (inbound #1181). The PR is already merged by the time
    # this line runs, so this pull is all that stands between the operator and a trunk that does not
    # contain the sync they were just told landed. It had no exit-code check at all: the 'Done' line
    # below printed whether or not the pull worked, which is the one shape of this failure nobody would
    # go looking for.
    & git checkout $trunk | Out-Null
    $post = Invoke-NativeCapture -FilePath 'git' -Arguments @('pull', '--ff-only') `
                                 -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    $post.Output | ForEach-Object { Write-Host $_ }
    if ($post.ExitCode -ne 0) {
        Write-Host "Sync PR #$pr IS MERGED, but $trunkShown could not be fast-forwarded, so this checkout does not have it yet." -ForegroundColor Red
        if ($post.TimedOut) {
            Write-Host "  'git pull' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] lines above." -ForegroundColor Red
        }
        Write-Host '  Nothing is lost; pull by hand: git pull --ff-only' -ForegroundColor Red
        exit 1
    }
    Write-Host "Done -- sync PR #$pr merged into $trunkShown." -ForegroundColor Green
    exit 0
}
finally {
    if ($pulledMirror -and -not $KeepMirror -and (Test-Path -LiteralPath $mirror)) {
        Remove-Item -LiteralPath $mirror -Recurse -Force -ErrorAction SilentlyContinue
    } elseif ($pulledMirror -and $KeepMirror) {
        Write-Host ''
        Write-Host "Mirror kept at: $mirror" -ForegroundColor Yellow
    }
}
