<#
.SYNOPSIS
    Tidy the local clone after merges: fast-forward the trunk, drop stale remote-tracking refs, and
    delete the local branches that are PROVABLY merged. A branch without that proof is left alone.

.DESCRIPTION
    The other half of branch cleanup. The REMOTE half is GitHub's own -- the repo setting
    "Automatically delete head branches" (`deleteBranchOnMerge`) removes the head branch on every
    merge route there is: the script path, the web UI, another machine, another tool. This script
    never touches a remote branch, and that is deliberate rather than an omission (see the block
    under "What this script does NOT do" below).

    WHY IT SHIPS CENTRALLY (inbound #815, August 21, 2026). It existed as a hand-written copy in two
    consumers and nowhere in the plugin -- which is the `new-branch.ps1` argument of issue #81
    exactly: a mechanism several repos all need, living as a copy in each, is a mechanism that will
    drift. The requester's own words when he noticed the accumulation: "waarom worden branches niet
    automatisch verwijderd na een merge? Dit zou de plugin moeten vertellen". Measured on the repo he
    was looking at: 20 remote heads, 18 of them belonging to already-merged PRs, five days into using
    this workflow.

    THE STEPS, IN ORDER:

      1. Refuse on a dirty tree WHERE THE STEP-OFF IS REACHABLE -- that is, where HEAD is on a branch
         this run could reap (4c below), because doing that with uncommitted work either fails halfway
         or drags the work across; both are worse than stopping with a sentence. Standing on the trunk,
         on a detached HEAD, or under -DryRun, 4c cannot be reached at all, so a dirty tree is reported
         and the run proceeds (issue #1575 -- see "THE GUARD IS ABOUT THE STEP-OFF" below).
      2. Fast-forward the trunk WITHOUT CHECKING IT OUT -- `git fetch <remote> <trunk>:<trunk>`,
         which advances a local branch ref that HEAD is not on and moves no working tree at all.
         Fast-forward ONLY: git refuses a non-ff into a local branch ref unless the refspec carries a
         leading `+`, so this script is allowed to advance the trunk and cannot merge anything into
         it. A run that already stands on the trunk cannot fetch into its own checked-out ref and
         uses `git pull --ff-only` instead -- same guarantee, and nothing there moves either.
      3. `git fetch --prune` -- drop remote-tracking refs whose remote branch is gone. This matters
         even when the remote branch was auto-deleted at the merge: the stale `origin/<branch>` refs
         otherwise pile up in the clone until pruned, and a clean local branch list is then no
         evidence whatsoever that the remote is clean.
      4. Delete each local branch for which a merge can be PROVEN, and only those:

           a. an ancestor of the trunk -- `git branch -d`, which refuses an unmerged branch on its
              own, so the proof is checked twice;
           b. otherwise, a branch whose tip IS THE HEAD COMMIT of a merged PR -- `git branch -D`. This
              is the squash case: the branch's own tip is deliberately not in the trunk's history, so
              (a) can never see it and `-d` would refuse a branch that is genuinely finished. The
              merged PR is the proof that replaces ancestry, which is why the forced delete is safe
              HERE and nowhere else.

              AND IT IS THE PR'S HEAD COMMIT, NOT ITS BRANCH NAME (inbound #1191). A name is not a
              proof of anything: `deleteBranchOnMerge` frees it at the merge, so a name generated from
              a template comes back around, and the second branch under it used to inherit the first
              one's merge and be force-deleted. The name-and-tip pair is what makes proof (b) belong
              to the branch in front of you. A name whose merged PR ended on a DIFFERENT commit is
              kept and says so in those words, because "no merged PR" would describe a lookup that
              came up empty when this one came up full.

           c. and where that branch is the one YOU ARE STANDING ON, step off it onto the trunk first
              -- `git branch -d` can never delete the branch HEAD is on. This is the only thing in
              this script that moves a working tree, it happens at most once per run, and it happens
              only on a branch that has just been PROVEN merged. The run then ends on the trunk,
              because there is no longer a branch to end on, and says so.

            d. and where ANOTHER worktree is standing on that branch, it is kept instead of deleted
              (issue #1760). git allows one worktree per branch and refuses to delete a branch that is
              checked out anywhere in the clone -- a refusal that takes precedence over -d's own
              unmerged check, so it lands only on branches the two proofs have just cleared. No tree
              may move another one, so the answer is this script's own sentence plus the hand-back
              command, not git's message relayed. Asked before the -DryRun branch, so a look-first run
              stops promising a delete the real run cannot perform.

        A branch with neither proof is KEPT and reported with the reason. That is the whole safety
         property: a parked branch (`park-branch.ps1`), unfinished work, or a branch pushed from
         another machine is never lost, because none of them has either proof.

      AND THE CLOSING LINE SAYS WHERE THE CHECKOUT ENDED (issue #1071), on every path out of this
      script from the step-3 marker onward. Deliberately not a numbered step: it is the exit contract
      rather than a stage, and the reasoning is under "IT NO LONGER BORROWS THE CHECKOUT" below.

    THE REMOTE PASS (`-IncludeRemote`, issue #1042) READS AND CLASSIFIES; IT STILL DELETES NOTHING.
    `git ls-remote --heads` is the only read that surfaces a parked branch, and this script named that
    command in its closing line while interpreting none of its output -- so every head that was not the
    trunk had the same classification re-derived BY HAND: ancestry, a merged PR, a diff against the
    trunk, the park commit. Measured three times in two days on three separate threads (#992, #1035,
    #1039), and twice the session also had to hand-write a don't-sweep-this-one warning about a live
    head belonging to somebody else's open PR. The switch is opt-in because the pass costs a network
    round trip and one merge-base per head, and the local tidy-up is what most runs are for.

    IT DOES NOT WEAKEN THE DECLINED PERMISSION, and it was built not to. What Dave declined on
    July 27, 2026 was EXECUTING a remote delete; what the decision says should happen instead is
    exactly this pass's output -- the command handed over paste-ready. A head is only ever reported
    deletable on the SAME two proofs the local pass uses, so the set this can name is the set the
    permission could not have reached safely; a head with neither proof is reported KEPT with its
    reason, which is the half that stops live parked work being re-investigated per session.

    IT NO LONGER BORROWS THE CHECKOUT (issue #1147, August 30, 2026). Step 2 used to check the trunk
    out, fast-forward it, and hand the checkout back (issue #1071's exit contract) -- and a borrow, even
    one returned within the second, is a tree that moves under whatever else is running in the same
    checkout. That is the cause measured in #1145: a file present on the branch and absent on the trunk
    vanished and reappeared under a running test suite, turning a green gate red. #1145 was repaired by
    DETECTION, which is right for the class (any tree-mover can collide), and this removes the collision
    for the one script a session is INSTRUCTED to run mid-assignment. Three things went with the borrow:
    #1069's clone-wide refusal when a second worktree held the trunk (a refspec fetch does not need the
    trunk checked out anywhere, so that is a WARNING now and the run continues), the hand-back itself,
    and the pair of starts that could not be returned to.

    THE ONE MOVE THAT SURVIVES, AND WHY IT CANNOT COLLIDE. Step 4c steps off a start branch that has
    just been proven merged, because `git branch -d` cannot delete the branch HEAD is on. It is not a
    borrow -- there is nothing to return to -- so the run ends on the trunk and names the sha it left,
    which is the whole of what makes that position recoverable. A branch under a running gate is
    UNMERGED by definition, so it never reaches that line; the move can only happen on work that is
    already finished.

    THE GUARD IS ABOUT THE STEP-OFF, SO IT ASKS WHETHER THE STEP-OFF IS REACHABLE (issue #1575,
    September 8, 2026). Step 1's dirty-tree refusal was unconditional, and its own sentence named a
    state that on most runs cannot occur: run from a clean trunk checkout holding one unrelated
    uncommitted file, it refused on the grounds of "reaping the branch you are standing on" -- while
    standing on the trunk, which is never a reap candidate. The rest of the run had been read-only
    since #1147, so the refusal was the only thing left that behaved as though the tree were at risk.

    THAT MATTERED BECAUSE OF WHERE THIS SCRIPT IS PRESCRIBED. The orchestrator's lens tells a session to
    run `-IncludeRemote` MID-ASSIGNMENT rather than classify `git ls-remote` output by hand, on the
    stated ground that it touches nothing -- and mid-assignment is precisely when a checkout has
    uncommitted work in it. The lens sentence and the refusal could not both be right about one run: one
    said the tree is never moved, the other refused on the possibility that it is. The ways out the
    refusal offered were the wrong price for a REPORT -- parking commits to a branch, stashing touches a
    file the session was told to leave alone.

    SO THE CONDITION IS NOW EXACTLY 4c's OWN REACHABILITY: not -DryRun (which `continue`s above 4c on
    every candidate), and HEAD on a branch that is a reap candidate -- neither the trunk, which the
    candidate list excludes, nor a detached HEAD, which reads as the literal 'HEAD' and is a name git
    refuses. Everything the guard protected it still protects: a dirty checkout standing on a non-trunk
    branch refuses exactly as before, because that branch can be squash-merged while the work is
    uncommitted, and that is the case where the step-off drags it onto the trunk. What changed is only
    that the other runs stopped paying for it -- and a dirty tree they proceed through is REPORTED, with
    which of the three reasons made it harmless, so an absent refusal is never read as an absent guard.

    THE EXIT CONTRACT IS STILL DELIBERATELY NOT ship-pr's. That script ends on the trunk on purpose --
    it closes a FINISHED assignment, and ending there is what makes the session safe to clear. This one
    closes nothing: it is a maintenance command run mid-assignment, and the branch you were standing on
    is still there when the run ends. What #1071 measured on the author of that report -- a run that
    left the session on `main`, silently, with a clean tree, and whose next commit landed directly on
    the trunk -- is now structurally impossible rather than repaired after the fact: nothing moves HEAD
    unless the branch it is on has been deleted.

    WHAT THIS SCRIPT DOES NOT DO, and why each is a decision:

      - IT DELETES NOTHING ON THE REMOTE. `git push origin --delete` is a manual action in this
         house: with `deleteBranchOnMerge` on, merged branches disappear by themselves, so a remote
         delete would only ever reach branches that are NOT merged -- exactly the ones whose loss is
         unrecoverable. All of the risk, almost none of the benefit. `-IncludeRemote` prints that
         command for a head it can prove is merged; it never runs one, and the suite asserts that
         structurally (no git call in this file carries a `--delete` argument, in quotes of either
         kind).
      - IT IS NOT PART OF THE MERGE. Reaping is a separate command so that a session cannot delete a
         branch as a side effect of shipping a PR. `ship-pr.ps1` reports the remote setting when it is
         off and stops there.
      - IT DOES NOT PASS `--delete-branch` FOR ANYONE. Beyond covering only the script path, that flag
         also deletes the LOCAL branch, and it was measured on July 16, 2026 leaving the checkout ON
         the merged branch -- with the fold running there and having to be undone by hand.

    Every git call goes through the shared Invoke-NativeCapture (EAP=Continue -> run -> record
    $LASTEXITCODE), because git writes progress to stderr, which under EAP=Stop becomes a terminating
    NativeCommandError before the exit code can be judged (the #96/#97/#107 pitfall).

    Pure ASCII (repo convention for .ps1).

.PARAMETER DryRun
    (Optional switch) report what would be deleted and delete nothing. Steps 2 and 3 -- the
    fast-forward and the prune of remote-tracking refs -- still run: neither loses anything, neither
    touches a working tree, and without them the branch list this reports on is the stale one. Step 4c
    does NOT run: a look-first run deletes nothing, so it never has to step off anything -- which is
    also why a dirty tree never refuses a dry run (issue #1575).

.PARAMETER IncludeRemote
    (Optional switch) additionally read `git ls-remote --heads <remote>` and classify every head that
    is not the trunk with the same two proofs the local pass uses. REPORT-ONLY: a head that is provably
    merged is handed over as a paste-ready `git push <remote> --delete <branch>` line, a head with
    neither proof is reported kept with its reason. Nothing on the remote is touched, with or without
    this switch. Combines with -DryRun, which only ever concerned the LOCAL deletions.

.PARAMETER Remote
    (Optional) the remote to fetch and prune, default 'origin'. -IncludeRemote reads its heads.

.EXAMPLE
    ./scripts/task/prune-merged.ps1 -DryRun

.EXAMPLE
    ./scripts/task/prune-merged.ps1

.EXAMPLE
    ./scripts/task/prune-merged.ps1 -IncludeRemote
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$IncludeRemote,
    [string]$Remote = 'origin'
)

$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Repo root -- dual context: if a consumer runs the shared plugin mirror, CLAUDE_PROJECT_DIR supplies
# its repo root; in the source root (or outside a session) it falls back to the git root. This way the
# SAME file works in both locations, and the root copy and the plugin mirror stay byte-identical
# (guarded by the shared-scripts drift lint).
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'prune-merged.ps1'

# Shared native-capture helper. $PSScriptRoot-relative, not $repoRoot: this lib is not repo-owned --
# it travels with the SAME plugin/mirror payload as this script.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# THE TRUNK COMES FROM THE SEAM, NOT FROM A LITERAL, and the two dot-sources below are what it costs.
# A repo on 'master' that this script assumed was on 'main' would fail its rev-parse and refuse, which
# is the safe direction -- but refusing a correctly-configured consumer is still a defect, and the one
# thing this script must never do is reason about ancestry against the wrong branch.
#
# repo-config.ps1 is OPTIONAL (a repo that never needed it, or one whose edit does not parse); it backs
# the seam function Get-TrunkBranchName, and every value it supplies has a working default. So:
# Test-Path, then try/catch that degrades to a warning. entry-scaffold-lib.ps1 owns Get-BranchTrunkName
# itself and travels with this script.
$repoConfigPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfigPath -PathType Leaf) {
    try { . $repoConfigPath } catch {
        Write-Warning "scripts\repo-config.ps1 could not be loaded ($($_.Exception.Message)); falling back to the default trunk name."
    }
}
. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
# For naming the worktree that holds the trunk when the fast-forward is refused (issue #1069). Same
# plugin-payload sibling, same reasoning as native-capture-lib above.
. (Join-Path $PSScriptRoot '..\lib\worktree-lib.ps1')
# THE MERGED-PR PROOF, SHARED WITH dkj-subagents-shopify's sync-main.ps1 (issue #1194). This script's proof (b)
# was repaired as inbound #1191 on the same day the identical mechanism was repaired in that script as
# #1190 -- neither branch knew about the other, and by the evening the mechanism existed twice and the
# copies had already diverged: the map here was a bare '@{}', whose comparer is case-insensitive, where
# the other keyed its map ordinally and said why. It is one file now, mirrored into both plugins. Same
# plugin-payload sibling as the three above.
. (Join-Path $PSScriptRoot '..\lib\merged-pr-lib.ps1')
$trunk = Get-BranchTrunkName

function Invoke-Git {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    return Invoke-NativeCapture -FilePath 'git' -Arguments (@('-C', $repoRoot) + $Arguments)
}

# THE WORKTREE LIST, READ AT MOST ONCE PER RUN. Two places need it and neither is on every path: the
# fast-forward failure below names the tree holding the trunk (#1069), and step 4 asks the same question
# of every reap candidate (#1760). Reading it lazily keeps a run that needs neither free of the call,
# and reading it ONCE keeps the two answers from being taken at different moments -- git allows one
# worktree per branch, so a second read could disagree with the first about who holds what.
#
# BEST-EFFORT IN BOTH CALLERS: an unreadable list answers "nobody else holds it", which for the
# fast-forward means falling back to git's own message, and for step 4 means attempting the delete
# exactly as before. Neither is a new failure -- both are the behaviour that stood before this cache.
$worktreeLines     = @()
$worktreeLinesRead = $false
function Get-WorktreePorcelain {
    if (-not $script:worktreeLinesRead) {
        $script:worktreeLinesRead = $true
        $res = Invoke-NativeCapture -FilePath 'git' -Arguments @('worktree', 'list', '--porcelain')
        if ($res.ExitCode -eq 0) { $script:worktreeLines = @($res.Output) }
    }
    return @($script:worktreeLines)
}

# DID THIS RUN MOVE HEAD AT ALL? Since #1147 the answer is no on every run but one, and this flag is
# the whole of the bookkeeping. It is set in exactly one place -- step 4c, stepping off a start branch
# that has just been proven merged -- because that is the only remaining reason this script has to
# touch a working tree.
$steppedOff = $false

# WHERE THE RUN ENDS, AND WHY IT IS ALMOST ALWAYS WHERE IT STARTED (issues #1071, #1147). The original
# defect was step 2 checking out the trunk and never giving it back: a session that ran this while
# standing on a branch was left on `main`, with a clean tree and nothing in `git status` to say so, and
# its next commit landed directly on the trunk. #1071 repaired that with a hand-back; #1147 removed the
# checkout that needed one, so on a run that reaps nothing underneath itself this function has nothing
# to report and says nothing.
#
# TWO STARTS THAT USED TO NEED A SENTENCE NO LONGER DO. A DETACHED start is simply never moved, so
# there is nothing to name; a run started ON THE TRUNK never moved either. What remains is the single
# case below, and it is a state this script deliberately creates.
function Restore-StartCheckout {
    if (-not $steppedOff) { return }

    # ONE REASON TO BE HERE: step 4c stepped off '$startBranch' in order to delete it. Two outcomes,
    # and the difference is whether the delete that justified the move actually happened.
    $existsRes = Invoke-Git -Arguments @('rev-parse', '--verify', '--quiet', "refs/heads/$startBranch")
    if ($existsRes.ExitCode -ne 0) {
        Write-Host "Ending on '$trunk' -- '$startBranch' was reaped by this run (it was at $startSha)." -ForegroundColor DarkGray
        return
    }

    $backRes = Invoke-Git -Arguments @('checkout', $startBranch)
    if ($backRes.ExitCode -eq 0) {
        Write-Host "Back on '$startBranch' -- the delete it was stepped off for did not happen." -ForegroundColor Green
    } else {
        # A FAILED HAND-BACK IS LOUD, because this is the one outcome with no signal of its own: the
        # tree is clean and the checkout is on the trunk, which is exactly the state #1071's report
        # measured a commit being lost to.
        Write-Warning "prune-merged could not put this checkout back on '$startBranch' -- it is standing on '$trunk'. Switch back by hand BEFORE you commit. ($(($backRes.Output | Out-String).Trim()))"
    }
}

function Complete-Run {
    <#
        THE ONLY WAY OUT from the step-3 marker onward, so a path added later cannot forget the
        closing line -- the suite asserts that structurally (no bare `exit` below that marker). Step 1
        keeps its own bare exits: nothing has moved yet there, and a refusal must leave the caller
        exactly where it found them. Step 2 no longer has any, which is #1147: a fast-forward that
        cannot happen is now a warning rather than a refusal, because it costs the run nothing but a
        staler trunk to judge ancestry against.
    #>
    param([int]$Code = 0, [string]$ErrorMessage)
    Restore-StartCheckout
    if ($ErrorMessage) { Write-Error $ErrorMessage }
    exit $Code
}

# --- 1. Pre-flight: a git repo, a known trunk, and a clean tree ------------------------------------
$headRes = Invoke-Git -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
if ($headRes.ExitCode -ne 0) {
    Write-Error "prune-merged cannot run -- not a git repository (or no HEAD): $repoRoot"
    exit 1
}

$trunkRes = Invoke-Git -Arguments @('rev-parse', '--verify', '--quiet', "refs/heads/$trunk")
if ($trunkRes.ExitCode -ne 0) {
    Write-Error "prune-merged cannot run -- this clone has no local branch '$trunk'. That is the trunk this repo declares (Get-TrunkBranchName in scripts\repo-config.ps1, default 'main'); check it out once, or correct the seam."
    exit 1
}

# READ BEFORE THE DIRTY GUARD, BECAUSE THE GUARD IS ABOUT WHERE YOU ARE STANDING (issue #1575). It is
# used from step 2 onward for the fast-forward route and the step-off; the guard below is simply the
# first reader of it now.
$startBranch = ($headRes.Output | Out-String).Trim()

# CAN THIS RUN STEP OFF AT ALL? That is the whole question the dirty guard asks, and step 4c is the one
# place that answers it -- `if ($branch -eq $startBranch)`, reached only for a branch that IS a reap
# candidate. Two states put it out of reach for the entire run, and both are decided here:
#
#   - HEAD IS THE TRUNK, or detached. The candidate list is `refs/heads` minus the trunk, so the trunk
#     is never in it; a detached HEAD reads as the literal 'HEAD', which git refuses as a branch name,
#     so it is never in it either. 4c cannot match, and nothing in the run moves a tree.
#   - -DryRun. The loop `continue`s above 4c on every candidate: a look-first run deletes nothing, so
#     the one reason to move HEAD never arises.
$couldStepOff = (-not $DryRun) -and $startBranch -and $startBranch -ne $trunk -and $startBranch -ne 'HEAD'

# A dirty tree is refused BEFORE anything is touched, not discovered by a failing step-off halfway
# through: at that point the fetch and some of the deletions have already run, and the reader has to
# work out what did and did not happen.
#
# AND IT IS REFUSED ONLY WHERE THE STEP-OFF IS REACHABLE (issue #1575, September 8, 2026). The guard
# used to be unconditional, so it refused the state it names in the same breath as describing it: run
# from a clean trunk checkout with one unrelated uncommitted file, it declined on the grounds of
# "reaping the branch you are standing on" -- which, standing on the trunk, this run can never do. That
# is not a cosmetic over-refusal. This is the command the orchestrator's lens instructs a session to run
# MID-ASSIGNMENT, in place of classifying `git ls-remote` output by hand, and mid-assignment is exactly
# when a checkout has uncommitted work in it: the guard blocked the report in the state the advice was
# written for. The two ways out it offers are the wrong price for a read -- parking commits to a branch,
# and stashing touches a file the session was told to leave alone.
#
# WHAT IS NOT NARROWED: standing on a non-trunk branch with uncommitted work still refuses, and must.
# Whether that branch is reapable cannot be known here -- the ancestry and the merged-PR proof are both
# steps away -- and a branch CAN be squash-merged while its checkout still holds uncommitted work, which
# is the case where the step-off drags that work onto the trunk. The guard keeps exactly that case; it
# simply no longer charges every other run for it.
$statusRes = Invoke-Git -Arguments @('status', '--porcelain')
if ($statusRes.ExitCode -ne 0) {
    Write-Error "prune-merged cannot read the working tree state in $repoRoot."
    exit 1
}
$dirty = @(($statusRes.Output | Out-String) -split '\r?\n' | Where-Object { $_.Trim() })
if ($dirty.Count -gt 0 -and $couldStepOff) {
    Write-Error "prune-merged refuses on a dirty working tree ($($dirty.Count) change(s)) while you are standing on '$startBranch'. Reaping that branch means stepping off it onto '$trunk', which would either fail halfway or drag the work across. Commit, park (scripts\task\park-branch.ps1) or stash first -- or rerun with -DryRun, which deletes nothing and therefore never steps off."
    exit 1
}
if ($dirty.Count -gt 0) {
    # SAID OUT LOUD RATHER THAN PASSED OVER IN SILENCE. A dirty tree is still worth a reader knowing
    # about -- it is simply not this run's business, and the line says which of the two reasons made it
    # harmless so nobody reads the absent refusal as the guard having been removed.
    $why = if ($DryRun) { '-DryRun deletes nothing' } elseif ($startBranch -eq 'HEAD') { 'HEAD is detached' } else { "you are standing on '$trunk'" }
    Write-Host "Working tree has $($dirty.Count) uncommitted change(s) -- untouched: $why, so this run has no branch to step off." -ForegroundColor DarkGray
}

# --- 2. The trunk, fast-forwarded WITHOUT being checked out (issue #1147) ---------------------------

# THE SHA AS WELL AS THE NAME, read before anything can move. It is the whole answer in the one case
# the hand-back cannot serve -- a start branch this run reaps -- and it costs one rev-parse.
$shaRes   = Invoke-Git -Arguments @('rev-parse', '--short', 'HEAD')
$startSha = if ($shaRes.ExitCode -eq 0) { ($shaRes.Output | Out-String).Trim() } else { 'an unknown commit' }

# FAST-FORWARD ONLY, AND WITHOUT MOVING A WORKING TREE. `git fetch <remote> <trunk>:<trunk>` writes a
# local branch ref that HEAD is not on: no checkout, no tree, nothing for a concurrent gate or suite in
# this checkout to trip over (#1145). The fast-forward guarantee is the refspec's own -- git refuses a
# non-ff update into refs/heads/ unless the refspec carries a leading `+`, and this one deliberately
# does not -- so the old `--ff-only` promise is kept by git rather than by a flag. A merge commit made
# here would be a change on the trunk that no PR ever carried, and this form cannot produce one.
#
# A RUN THAT ALREADY STANDS ON THE TRUNK TAKES THE OTHER BRANCH, because git refuses to fetch into the
# ref that is checked out here -- and there `git pull --ff-only` moves nothing either: it advances the
# branch you are already on to a commit the remote has already published.
if ($startBranch -eq $trunk) {
    $ffRes = Invoke-Git -Arguments @('pull', '--ff-only', $Remote, $trunk)
} else {
    $ffRes = Invoke-Git -Arguments @('fetch', $Remote, "$($trunk):$($trunk)")
}

# A FAILED FAST-FORWARD IS A WARNING, NEVER A REFUSAL. The ancestry the deletions are judged on is then
# simply the older trunk, which errs towards KEEPING branches -- so there is nothing here worth
# stopping a whole run for. That is what #1147 changed about the #1069 case below: when a second
# worktree held the trunk, the checkout was impossible clone-wide and this script REFUSED, which made
# it unavailable in exactly the situation that produces stray branches. A refspec fetch is refused in
# that state too (git will not write a ref that is checked out anywhere), but only the fast-forward is
# lost, not the run.
if ($ffRes.ExitCode -ne 0) {
    $reason = ($ffRes.Output | Out-String).Trim()
    # WHY THIS NAMES A DIRECTORY (issue #1069). git's own message says the ref is taken and, at best,
    # where -- never what to do about it. Best-effort: an unreadable worktree list falls back to git's
    # own message. Only asked on the fetch path; a run standing on the trunk itself holds it.
    $holder = ''
    if ($startBranch -ne $trunk) {
        $holder = Get-WorktreeHoldingBranch -PorcelainLines (Get-WorktreePorcelain) -Branch $trunk -SelfPath $repoRoot
    }
    if ($holder) {
        Write-Warning "'$trunk' could not be fast-forwarded -- another worktree holds it: $holder, and git will not write a ref that is checked out. Continuing against the local '$trunk'; fewer branches will look merged, never more. Move that tree off the trunk (git -C `"$holder`" checkout <its branch>), or hand it back if it is a finished lane (scripts\task\worktree-lane.ps1 -HandBack -Lane `"$holder`")."
    } else {
        Write-Warning "'$trunk' could not be fast-forwarded from $Remote -- continuing against the local '$trunk'. Fewer branches will look merged, never more. ($reason)"
    }
} else {
    $how = if ($startBranch -eq $trunk) { '' } else { ' -- without checking it out' }
    Write-Host "Fast-forwarded '$trunk' from $Remote$how." -ForegroundColor Green
}

# --- 3. Drop stale remote-tracking refs ------------------------------------------------------------
# Worth doing even when the remote deletes its own merged branches: those refs stay in the clone until
# pruned, which is why a clean local list proves nothing about the remote (verify that with
# `git ls-remote --heads <remote>`).
$fetchRes = Invoke-Git -Arguments @('fetch', '--prune', $Remote)
if ($fetchRes.ExitCode -ne 0) {
    Write-Warning "could not fetch --prune from $Remote -- stale remote-tracking refs may remain. ($(($fetchRes.Output | Out-String).Trim()))"
} else {
    Write-Host "Pruned stale remote-tracking refs for $Remote." -ForegroundColor Green
}

# --- 4. The branches, and the proof for each -------------------------------------------------------
$listRes = Invoke-Git -Arguments @('for-each-ref', '--format=%(refname:short)', 'refs/heads')
if ($listRes.ExitCode -ne 0) {
    Complete-Run -Code 1 -ErrorMessage "prune-merged could not list the local branches."
}
$branches = @(($listRes.Output | Out-String) -split '\r?\n' |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and $_ -ne $trunk })

# A CLEAN LOCAL LIST NO LONGER ENDS THE RUN, and that is the #1042 half of this script that is easiest
# to miss. It proves nothing whatsoever about the remote -- the reason the remote pass exists at all --
# so a clone that has just been tidied is exactly the state in which the remote question is worth
# asking, and the closing line saying so was the one thing the old early exit skipped. Everything below
# is now guarded on the count instead: the merged-PR lookup, the per-branch loop and the local report
# all no-op on an empty list, and the run still ends in a line about the remote.
if ($branches.Count -eq 0) {
    Write-Host "Nothing to reap: '$trunk' is the only local branch." -ForegroundColor Green
}

# THE MERGED-PR LOOKUP IS ONE CALL, NOT ONE PER BRANCH. A repo five days into this workflow already
# has dozens of merged PRs and this command is a tidy-up, not a report -- so the whole merged set is
# read once and matched locally. gh may be absent or unauthenticated: that is not an error here, it
# only means proof (b) cannot be established, so a squash-merged branch is KEPT and says why.
# ONE CALL SERVES BOTH PASSES, and it is skipped entirely when neither has anything to ask it: an
# empty local list with no -IncludeRemote is a run with nothing left to classify, and a gh call there
# would only be able to produce a warning.
#
# IT ASKS FOR THE HEAD COMMIT AS WELL AS THE NAME (inbound #1191, September 1, 2026), and the pair is
# what the proof is made of. A branch NAME says nothing about which commits were merged under it, and
# `deleteBranchOnMerge` -- the very setting this script's header leans on for the remote half -- is
# what frees a name for reuse the moment the PR lands. So a workflow that generates branch names from
# a template recycles them by design rather than by accident. Measured in a consumer whose pre-task
# sync names its branches `sync/live-<date>`: a second sync on the same day recreated
# `sync/live-2026-09-01`, and this script force-deleted it on PR #141's merge while the commit it was
# standing on belonged to #159, still OPEN. The name matched; the proof belonged to a different
# branch -- and the run printed `merged PR` while it did it, so the output actively reassured.
#
# SO THE MAP IS name -> the head commits merged under it, and a name may hold SEVERAL: a recycled name
# merged twice has two, and each is a real proof for the branch that ended on it. The test below is
# name AND tip, which is what makes the local pass resolve its own tip to compare.
#
# THE MAP AND THE TEST COME FROM merged-pr-lib.ps1 (issue #1194), and only the transport below is this
# script's. That split is what the lib's header argues for: the normalising, the sha-shape validation
# and -- the one that had already gone wrong -- the ORDINAL comparer the map is keyed with are decided
# in one place for both callers, so the second copy cannot quietly be the one without the guard.
#
# NO --jq, AND THAT IS THE CHEAP HALF. Two fields want a jq expression carrying an interpolation and a
# separator, quoted through PowerShell into gh on Windows; ConvertFrom-Json is already in this shell
# and needs no quoting at all. A body that will not parse is treated exactly as a non-zero exit --
# unknown, warn, keep -- because the one thing this lookup must never do is half-answer.
$mergedTips = Get-MergedPrTips
$ghKnown = $false
if ($branches.Count -gt 0 -or $IncludeRemote) {
    $ghCmd = Get-Command 'gh' -ErrorAction SilentlyContinue
    if ($ghCmd) {
        $prRes = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
            'pr', 'list', '--state', 'merged', '--limit', '200', '--json', 'headRefName,headRefOid')
        if ($prRes.ExitCode -eq 0) {
            $body = ($prRes.Output | Out-String).Trim()
            try {
                # AN EMPTY ANSWER IS STILL AN ANSWER. gh prints '[]' for a repo with no merged PRs, and a
                # gh that printed nothing at all told us the same thing: there is no merged PR to match
                # against. Both land on an empty map with $ghKnown TRUE, so the kept reason says "no
                # merged PR" rather than "could not be checked" -- which is the difference between a
                # fact and a gap.
                $rows = if ($body) { @($body | ConvertFrom-Json) } else { @() }
                # gh's field names in, the lib's shape out. Everything the rows still need doing to them
                # -- trimming, dropping a null name or oid, refusing an oid that is not an object name,
                # de-duplicating -- happens once inside Get-MergedPrTips, for this transport and
                # sync-main's TSV one alike.
                $mergedTips = Get-MergedPrTips -Pairs @($rows | ForEach-Object {
                    [pscustomobject]@{ Name = $_.headRefName; Tip = $_.headRefOid }
                })
                $ghKnown = $true
            } catch {
                Write-Warning "gh's merged-PR list could not be read as JSON -- a squash-merged branch cannot be proven merged and will be kept. ($($_.Exception.Message))"
            }
        } else {
            Write-Warning "gh could not list merged PRs -- a squash-merged branch cannot be proven merged and will be kept. ($(($prRes.Output | Out-String).Trim()))"
        }
    } else {
        Write-Warning "gh is not available -- a squash-merged branch cannot be proven merged and will be kept."
    }
}

function Get-MergedProof {
    <#
        BOTH PASSES ASK THE SAME QUESTION OF DIFFERENT TIPS, so they ask it through one function -- the
        local pass resolves its tip with rev-parse, the remote pass already holds the sha ls-remote
        reported. Three answers, and the middle one is the whole of inbound #1191:

          'merged PR'  -- this exact commit is the head of a merged PR under this name: proof (b);
          'recycled'   -- the name HAS a merged PR, but this commit is not one it merged: no proof, and
                          a different sentence, because "no merged PR" would read as a lookup coming up
                          empty when it came up FULL -- the name matched, the commit did not. The token
                          is 'recycled' (inbound #1191), but the state is wider than a reused name: a
                          tip this run could not read resolves here too, and so does a branch that took
                          a commit after its own PR merged. The printed sentence names that
                          measurement rather than picking one of the causes (issue #1296);
          $null        -- no merged PR under this name at all.

        An empty $Tip resolves to 'recycled' where the name is known, which is the safe direction: a
        tip this run could not read is a tip it cannot match.

        THE TWO QUESTIONS ARE THE LIB'S, THE THREE SENTENCES ARE THIS SCRIPT'S (issue #1194).
        Test-RefMergedByPr is the proof and Test-MergedPrNameKnown is the middle answer; deciding which
        of the two failures the caller is looking at, and what to print for it, stays here because only
        this script has an output. Asking the proof FIRST is deliberate: a name-known check that ran
        first and short-circuited would be a name-only proof again, which is the whole of #1191.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Branch,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Tip
    )
    if (-not $Branch) { return $null }
    if (Test-RefMergedByPr -Name $Branch -Tip $Tip -MergedTips $mergedTips) { return 'merged PR' }
    if (Test-MergedPrNameKnown -Name $Branch -MergedTips $mergedTips) { return 'recycled' }
    return $null
}

$deleted = @()
$kept    = @()

foreach ($branch in $branches) {
    $ancestor = (Invoke-Git -Arguments @('merge-base', '--is-ancestor', $branch, $trunk)).ExitCode -eq 0

    # THE TIP THE MERGED-PR PROOF IS MEASURED AGAINST, resolved once per branch. `^{commit}` so a tag
    # sharing the branch's name cannot answer instead of the branch, and --quiet so a ref that has gone
    # missing between the for-each-ref above and here is a non-zero exit rather than noise on stderr.
    # An unreadable tip leaves this empty, which Get-MergedProof reads as "not this commit" -- the safe
    # direction, and the only one: a tip this run could not read must never look like a match.
    $tipRes = Invoke-Git -Arguments @('rev-parse', '--verify', '--quiet', "refs/heads/$branch^{commit}")
    $tip    = if ($tipRes.ExitCode -eq 0) {
        (($tipRes.Output | Out-String) -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -First 1)
    } else { '' }

    $prProof  = Get-MergedProof -Branch $branch -Tip $tip
    $mergedPr = ($prProof -eq 'merged PR')

    if (-not ($ancestor -or $mergedPr)) {
        # THE ONE BRANCH THIS SCRIPT PROTECTS. No ancestry and no merged PR means unfinished work, a
        # parked branch, or a branch pushed from another machine -- and its reason is printed rather
        # than left to be inferred from the absence of a delete line.
        #
        # THIS CASE GETS ITS OWN SENTENCE (inbound #1191). "No merged PR" would be a true statement
        # that reads as a lookup coming up empty, when the lookup came up FULL -- the name matched, this
        # commit did not. A recycled name whose predecessor merged is what #1191 was filed for and the
        # loss this script used to cause; a tip that could not be read, or a commit added after the PR
        # merged, lands here as well -- so the sentence states what was measured, not which cause it is
        # (issue #1296).
        $why = if ($prProof -eq 'recycled') {
            'a merged PR used this name, but not this commit -- no proof for this tip (a recycled name, or a commit added to this branch after that PR merged)'
        } elseif ($ghKnown) {
            'not an ancestor of the trunk and no merged PR'
        } else {
            'not an ancestor of the trunk, and no merged PR could be checked'
        }
        $kept += [pscustomobject]@{ Branch = $branch; Why = $why }
        continue
    }

    # -d WHERE ANCESTRY PROVES IT, -D ONLY WHERE A MERGED PR DOES. -d refuses an unmerged branch by
    # itself, so the ancestry case is checked twice; -D skips that check, and the merged PR is what
    # replaces it. Choosing -D on ancestry as well would throw the second check away for nothing.
    $flag   = if ($ancestor) { '-d' } else { '-D' }
    $proof  = if ($ancestor) { 'ancestor of ' + $trunk } else { 'merged PR' }

    # --- 4d. A BRANCH ANOTHER WORKTREE IS STANDING ON (issue #1760) -------------------------------
    # NUMBERED AFTER 4c AND ASKED BEFORE IT, which is not a contradiction: 4c is about the one tree
    # this run is allowed to move -- its own -- and a branch HEAD is on here can never be the branch
    # another worktree holds, so the two cases are disjoint and neither can shadow the other. The
    # label follows the header's list; the position follows the DryRun argument below.
    #
    # git allows one worktree per branch and refuses to delete a branch that is checked out anywhere
    # in the clone -- and that refusal takes precedence over -d's own unmerged check, so it lands on
    # exactly the branches the two proofs above have just cleared. Step 4c handles the one tree this
    # run can move (its own HEAD); no tree may move another one, so for a LANE the only answer is a
    # sentence.
    #
    # IT IS ASKED HERE, AFTER THE PROOFS AND BEFORE THE DryRun BRANCH, and both halves of that
    # position are deliberate:
    #
    #   - AFTER the proofs, because a lane holding UNFINISHED work is the ordinary state this script
    #     exists to leave alone. That branch is already kept for a reason of its own ("not an ancestor
    #     of the trunk and no merged PR"), which is the reason a reader needs; adding a worktree note
    #     to it would report the lane as an obstacle when nothing was going to touch it.
    #   - BEFORE the DryRun branch, because the look-first run has to answer the same question the
    #     real one will. Asked any later, -DryRun printed "Would delete <branch>" for a delete the
    #     next run cannot perform -- a promise from the one mode whose whole purpose is to tell you
    #     what will happen.
    #
    # AND IT SAYS WHAT #1069's SENTENCE SAYS, for the same reason. git's message names a worktree and
    # stops there; relaying it would hand a reader this script's word "Kept" wrapped around git's
    # vocabulary, with no way out in it. Before this the delete was attempted and its refusal reported
    # as `git branch -D refused: <git's text>` -- true, and not actionable. The seam between the two
    # scripts is where this defect lived: worktree-lane.ps1's header says it "removes no branch,
    # locally or on the remote -- branch cleanup is prune-merged.ps1's", so a lane whose work has
    # landed was owned by neither, and the hand-back is a manual act nothing prompted for.
    $heldBy = Get-WorktreeHoldingBranch -PorcelainLines (Get-WorktreePorcelain) -Branch $branch -SelfPath $repoRoot
    if ($heldBy) {
        $kept += [pscustomobject]@{
            Branch = $branch
            Why    = "proven merged ($proof), but another worktree is standing on it: $heldBy, and git will not delete a branch that is checked out. Hand that lane back (scripts\task\worktree-lane.ps1 -HandBack -Lane `"$heldBy`"), or move it off (git -C `"$heldBy`" checkout <another branch>), then rerun."
        }
        continue
    }

    if ($DryRun) {
        # A LOOK-FIRST RUN NEVER STEPS OFF ANYTHING. It deletes nothing, so the one reason to move HEAD
        # does not arise -- and a dry run that moved the caller would be the #1071 defect wearing a
        # safer name.
        $deleted += [pscustomobject]@{ Branch = $branch; Proof = $proof; Flag = $flag }
        continue
    }

    # --- 4c. Stepping off the branch you are standing on ------------------------------------------
    # THE ONLY LINE IN THIS SCRIPT THAT MOVES A WORKING TREE, and it is reached only for a branch that
    # the two lines above have just PROVEN merged. `git branch -d` can never delete the branch HEAD is
    # on, so without this a merged start branch would be reported kept for a reason the caller cannot
    # act on without a second command. It is not a borrow: there is nothing to return to once the
    # branch is gone, so the run ends on the trunk and Restore-StartCheckout names the sha it left.
    #
    # WHY IT CANNOT COLLIDE WITH A GATE (issue #1147). The borrow this replaced ran on EVERY run, which
    # is what made a concurrent suite in the same checkout see the tree move (#1145). A branch under a
    # running gate is unmerged by definition -- that is what the gate is for -- so it can never reach
    # this line. What is left moves the tree only on work that is already finished.
    if ($branch -eq $startBranch) {
        $offRes = Invoke-Git -Arguments @('checkout', $trunk)
        if ($offRes.ExitCode -ne 0) {
            $kept += [pscustomobject]@{ Branch = $branch; Why = "you are standing on it and this run could not step off onto '$trunk': $(($offRes.Output | Out-String).Trim())" }
            continue
        }
        $steppedOff = $true
        Write-Host "Stepped off '$branch' onto '$trunk' -- a branch cannot be deleted from underneath HEAD." -ForegroundColor Green
    }

    $delRes = Invoke-Git -Arguments @('branch', $flag, $branch)
    if ($delRes.ExitCode -eq 0) {
        $deleted += [pscustomobject]@{ Branch = $branch; Proof = $proof; Flag = $flag }
    } else {
        # A REFUSED DELETE IS REPORTED AS KEPT, not as a failure of the run. `git branch -d` declining
        # is the safety check doing its job on a branch whose ancestry looked right a moment ago, and
        # the run has other branches to finish.
        $kept += [pscustomobject]@{ Branch = $branch; Why = "git branch $flag refused: $(($delRes.Output | Out-String).Trim())" }
    }
}

# --- The local report --------------------------------------------------------------------------------
if ($branches.Count -gt 0) {
    $verb = if ($DryRun) { 'Would delete' } else { 'Deleted' }
    foreach ($d in $deleted) {
        Write-Host "  $verb $($d.Branch) (git branch $($d.Flag) -- $($d.Proof))" -ForegroundColor Green
    }
    foreach ($k in $kept) {
        Write-Host "  Kept $($k.Branch) -- $($k.Why)" -ForegroundColor Yellow
    }

    $summary = "$($deleted.Count) $(if ($DryRun) { 'reapable' } else { 'deleted' }), $($kept.Count) kept, of $($branches.Count) local branch$(if ($branches.Count -eq 1) { '' } else { 'es' }) beside '$trunk'."
    Write-Host $summary -ForegroundColor Cyan
    if ($DryRun -and $deleted.Count -gt 0) {
        Write-Host "Nothing was deleted -- rerun without -DryRun to reap them." -ForegroundColor DarkGray
    }
}

# --- 5. The remote heads, classified and handed over -- never touched (issue #1042) -----------------
# The reasoning is in the header: this is the read that surfaces a parked branch, and until this pass
# existed the script named the command and interpreted none of it, so the same per-head triage was
# re-derived by hand. It stays report-only, which is what keeps it inside the declined permission
# rather than around it.
if (-not $IncludeRemote) {
    # THE REMOTE IS NOT THIS SCRIPT'S BUSINESS BY DEFAULT, and saying so is what stops the next reader
    # concluding that a clean local list means a clean remote. One line, naming the command that
    # actually answers it -- and now also the switch that answers it here.
    Write-Host "The remote is untouched by design -- verify it with: git ls-remote --heads $Remote (or rerun with -IncludeRemote to have those heads classified here)." -ForegroundColor DarkGray
    Complete-Run
}

$lsRes = Invoke-Git -Arguments @('ls-remote', '--heads', $Remote)
if ($lsRes.ExitCode -ne 0) {
    Write-Warning "could not read the heads on $Remote -- the remote pass is skipped, and nothing above it is affected. ($(($lsRes.Output | Out-String).Trim()))"
    Complete-Run
}

# ls-remote prints '<sha>\t refs/heads/<name>'. Split on the FIRST run of whitespace only: a branch
# name may not contain whitespace, but a tab-vs-spaces assumption about git's output format is a
# needless one to make.
$heads = @(($lsRes.Output | Out-String) -split '\r?\n' |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ } |
    ForEach-Object {
        $parts = $_ -split '\s+', 2
        if ($parts.Count -eq 2 -and $parts[1].StartsWith('refs/heads/')) {
            [pscustomobject]@{ Sha = $parts[0]; Branch = $parts[1].Substring('refs/heads/'.Length) }
        }
    } |
    Where-Object { $_ -and $_.Branch -ne $trunk })

if ($heads.Count -eq 0) {
    Write-Host "Nothing standing on $Remote beside '$trunk'." -ForegroundColor Green
    Complete-Run
}

$remoteReapable = @()
$remoteKept     = @()

foreach ($h in $heads) {
    # ANCESTRY IS JUDGED ON THE SHA ls-remote REPORTED, against the local trunk step 2 fast-forwarded.
    # The object is present because step 3 fetched this remote; where it is NOT -- a fetch that failed,
    # or a head pushed between the fetch and this read -- merge-base exits non-zero and the head is
    # KEPT. That is the safe direction, and the only one: this pass hands over a delete command, so an
    # unprovable head must never look provable.
    $ancestor = (Invoke-Git -Arguments @('merge-base', '--is-ancestor', $h.Sha, $trunk)).ExitCode -eq 0
    # THE SAME name+tip PROOF, and this pass is the one place it costs nothing: ls-remote has already
    # reported the sha, so there is no rev-parse to do. It also matters MOST here -- the local pass
    # deletes a branch whose commits `origin` usually still holds, while this pass hands over a
    # `git push --delete` line for the copy of last resort (inbound #1191).
    $prProof  = Get-MergedProof -Branch $h.Branch -Tip $h.Sha
    $mergedPr = ($prProof -eq 'merged PR')

    if ($ancestor -or $mergedPr) {
        $remoteReapable += [pscustomobject]@{
            Branch = $h.Branch
            Proof  = if ($ancestor) { 'ancestor of ' + $trunk } else { 'merged PR' }
        }
        continue
    }

    # THE HEAD THIS PASS EXISTS TO LABEL. No usable proof, so no delete line is handed over -- and
    # naming the reason here is what replaces the hand-written don't-sweep-this-one warning that two of
    # the three measured triages had to add by hand. Usually that means live work (unfinished, parked,
    # somebody else's open PR); a recycled name or a commit added after the PR merged lands here too,
    # which is why the recycled branch below states the measurement rather than calling the head live
    # (issue #1296).
    $why = if ($prProof -eq 'recycled') {
        'a merged PR used this name, but not this commit -- no proof for this tip (a recycled name, or a commit added to this head after that PR merged)'
    } elseif ($ghKnown) {
        'not an ancestor of the trunk and no merged PR -- live work (unfinished, parked, or another open PR)'
    } else {
        'not an ancestor of the trunk, and no merged PR could be checked -- treat as live'
    }
    $remoteKept += [pscustomobject]@{ Branch = $h.Branch; Why = $why }
}

foreach ($k in $remoteKept) {
    Write-Host "  Kept $Remote/$($k.Branch) -- $($k.Why)" -ForegroundColor Yellow
}

# THE COMMANDS COME LAST so they are the block a reader copies from, and they are printed rather than
# run: deleting a remote branch is a manual act in this house.
if ($remoteReapable.Count -gt 0) {
    Write-Host "Merged heads still standing on $Remote -- deleting a remote branch is a manual act here, so the commands are handed over rather than run:" -ForegroundColor Cyan
    foreach ($r in $remoteReapable) {
        Write-Host "  git push $Remote --delete $($r.Branch)   # $($r.Proof)" -ForegroundColor Green
    }
}

$remoteSummary = "$($remoteReapable.Count) deletable, $($remoteKept.Count) kept, of $($heads.Count) head$(if ($heads.Count -eq 1) { '' } else { 's' }) on $Remote beside '$trunk'. Nothing on the remote was touched."
Write-Host $remoteSummary -ForegroundColor Cyan
Complete-Run
