<#
.SYNOPSIS
    Push this branch's development document to origin -- unless a PR has already published it. The
    automatic half of parking: one document, no PR, no live action, and silent when there is nothing
    to do.

.DESCRIPTION
    THE PROBLEM THIS CLOSES (issue #900). A branch that exists only locally is a branch the other
    device cannot see. Measured over the 38 merged branches carrying a readable creation stamp: the
    median branch was invisible on origin for 22 minutes, the mean 35, the worst 365, and nine of the
    38 for over half an hour. new-branch now pushes at creation, which makes the branch's NAME visible
    from minute one -- but a name is not what another device needs. What it needs is the PLAN, which
    phase is running and where the last session stopped, and all three live in this one document.

    So this script exists for the LIFE of the branch, not for its first minute, and by this repo's own
    rule -- what has to happen without anyone asking for it is a hook -- it is invoked by one
    (cycle-autopark.ps1, on Stop). It is an ordinary script all the same, and running it by hand does
    exactly what the hook does. That is deliberate: the measurement that shaped this is that `park` and
    `new-branch -Park` produced SIX commits in the whole history. An opt-in backup is a backup nobody
    takes.

    THE TRAP THAT SHAPES EVERY BOUND BELOW: THE DEPLOY LOCK (#884). ship-pr refuses the merge once
    the branch's development document has diverged from what the PR published. A pusher that kept running after
    open-pr would therefore not be a convenience -- it would block every merge in the repo,
    structurally, and the failure would read as the lock misbehaving rather than as this script. Hence
    the PR check below, and hence its fail-safe direction: when the answer cannot be established, this
    script does NOT push. Being one turn stale is a nuisance; an unmergeable branch is a defect.

    THE FOUR BOUNDS, all of them narrow on purpose:

      1. ONE DOCUMENT. The pathspec is the resolved cycle path and nothing else -- never `git add -A`,
         which is right for a deliberate park (park-branch.ps1) and wrong for an automatic one: it
         would publish work in progress nobody asked to publish.
      2. NOT ON THE TRUNK, where the fold REMOVES this document by design.
      3. NOT ONCE A PR EXISTS -- the lock above, and EXISTS means ever, not just now. Merged and closed
         count (issue #1035): scoped to open PRs this bound lifted at the merge, and the hook then pushed
         the branch back onto origin seconds after deleteBranchOnMerge had removed it, where
         `git ls-remote --heads origin` reports the resurrected head as parked work. Read the bound
         itself for the measurement and for why the other candidate repair was not taken.
      4. NO AMEND, NO FORCE. Keeping the history to one commit would mean `git push --force`, which
         the constitution forbids on any branch without Dave's explicit permission. So this costs a
         handful of small commits per branch, and the recognisable `park:` subject Invoke-GitPark
         already writes is the mitigation.

    AND THE COMMIT SAYS WHAT IS BEHIND THE PLAN (issue #960). Publishing the plan and nothing else is
    what bound 1 is for, and it has one perverse outcome: a branch whose work is uncommitted in another
    device's working copy arrives on origin as a document claiming the work is done, with no commit behind
    a single tick. So every park commit carries a `Backing:` line -- how many steps are resolved, how many
    files are committed on this branch besides this document, how many are uncommitted here -- and, when
    the plan reads as FINISHED with nothing behind it, a paragraph saying so in as many words.
    READ IT WITH 'git log -1 --pretty=%B origin/<branch>'; the reporter that used to print it back for every
    parked branch went with /lock and /handover (#957). COUNTS, NEVER FILENAMES: the uncommitted figure
    describes work nobody asked to publish. It is a note and never a gate -- see the block at the call.

    NO SOURCE-REPO GUARD, and that is the documented precedent rather than an omission. A hook invokes
    this from '${CLAUDE_PLUGIN_ROOT}/scripts/task/', by design, against the current repo -- so a
    refusal would fire on every turn in the repo that maintains it, exactly as source-repo-guard-lib's
    own header records for check-roster-sync.ps1 and check-script-contract.ps1. The staleness that
    guard exists to catch is also absent here: a lagging mirror of this script commits and pushes one
    file, it does not scaffold a retired template.

    Every git call goes through the shared Invoke-NativeCapture (EAP=Continue -> run -> record
    $LASTEXITCODE), because git writes progress to stderr, which under EAP=Stop would become a
    terminating NativeCommandError before the exit code could be judged (the #96/#97/#107 pitfall).

    AND THIS IS THE EARLIEST COLLISION DETECTOR THIS WORKFLOW HAS (issue #1600). Running on every turn
    is what makes it that: from the moment a second session pushes to the same branch, every turn of
    this one can see it. new-branch.ps1's remote-ahead warning (#1439) asks the same question once, at a
    resume that goes through that script; open-pr.ps1's gate asks it at the very end, when the duplicated
    work has already been paid for. So the answer names the other side -- its count, author and subject,
    through the shared Get-RemoteAheadNote -- instead of saying "diverged from origin?" and sending the
    reader for a reason this run already holds. Measured on feat/plugin-version-overview,
    September 8, 2026: two sessions ran the same pre-PR review in full, each finding real defects the
    other missed, and the signal was available for roughly half an hour before open-pr surfaced it.

    IT ASKS AT TWO DOORS, BECAUSE FOR A YEAR IT ONLY ASKED AT ONE (issue #1953). The detection used to
    be a side effect of the push: a refused push, then a fetch to explain it. That makes the claim above
    true only where bound 3 lets the push happen -- and on a branch with an OPEN PR it never does, so
    this script ended at that bound in silence, on exactly the object two sessions are likeliest to
    reach for independently. Measured September 13, 2026: two sessions repaired the same red required
    check on one PR about 90 seconds apart and learned of each other from git's rejection at the push.
    So the bound still refuses the push and no longer refuses to LOOK -- the open-PR arm reads the same
    one ref and prints the same report. The two questions were fused and are now separate: whether this
    script may WRITE is the DEPLOY lock's, whether somebody else is on this branch is nobody's.

    ALWAYS EXITS 0. It runs on a hook, and a hook that fails is a hook that interrupts the work it was
    added to protect. Every refusal above is a normal outcome, not an error.

    Pure ASCII (repo convention for .ps1).

.PARAMETER RepoRoot
    (Optional) the tree to act on, when that is NOT the tree resolved from CLAUDE_PROJECT_DIR or the
    git root. Used by the suite, and by a caller acting on a worktree lane.

.PARAMETER Quiet
    (Optional switch) print nothing when there is nothing to do. What the hook passes: a turn in which
    the document did not change must not add a line to the session. A push still reports itself, and so
    does a COLLISION (#1953) -- a refusal is "nothing to do", another session on this branch is not, and
    under the hook this switch is the only reader there is.

.EXAMPLE
    ./scripts/task/park-cycle.ps1

.EXAMPLE
    ./scripts/task/park-cycle.ps1 -Quiet
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# One reporter, so every "nothing to do" answer obeys -Quiet the same way and a push never does.
function Write-CycleParkNote {
    param([string]$Message, [string]$Colour = 'DarkGray')
    if (-not $Quiet) { Write-Host "park-cycle: $Message" -ForegroundColor $Colour }
}

# THE COLLISION READ, IN ONE PLACE BECAUSE IT NOW HAS TWO CALLERS (issue #1953). Both of them ask the
# same question -- is there a commit on origin/<branch> that this HEAD does not have, and whose is it --
# and the answer is one bounded fetch plus the shared sentence. Written as a function rather than twice
# so the two reports cannot drift on the ref they read: FETCH_HEAD, not refs/remotes/origin/<branch>,
# because `git fetch origin <branch>` writes the fetched tip there in every git version while whether it
# also moves the remote-tracking ref depends on the remote's refspec configuration -- and a ref that did
# not move reads 0 on exactly the branch being asked about.
#
# A FETCH THAT CANNOT ANSWER COSTS THE NOTE AND NEVER THE RUN. This script always exits 0, and both
# callers treat '' as "nothing to say" -- which is the same fail-quiet direction the bounds above take.
function Get-BranchCollisionNote {
    param([Parameter(Mandatory = $true)][string]$RepoRoot, [Parameter(Mandatory = $true)][string]$Branch)
    $fetch = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'fetch', 'origin', $Branch) `
                                  -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    if ($fetch.ExitCode -ne 0) { return '' }
    return Get-RemoteAheadNote -RepoRoot $RepoRoot -LocalRef 'HEAD' -RemoteRef 'FETCH_HEAD' `
                               -BranchLabel $Branch -FreshLabel "origin/$Branch" -StaleLabel "origin/$Branch" -Fresh $true
}

# AND THE INTERPRETATION IS ONE TEXT, for the reason #1600 filed in the first place: what a collision
# report is FOR is the sentence after the facts, and two copies of it are two chances for one of them to
# degrade back into plumbing. The lead differs per caller -- one is a refused push, the other a push that
# was never attempted -- so that half is passed in; what it MEANS and what to do about it is not.
#
# Write-Host, NOT Write-CycleParkNote: -Quiet exists so a turn that did nothing adds no line, and a
# collision is the opposite of that. The push report already bypasses it for the same reason.
function Write-CycleCollisionReport {
    param(
        [Parameter(Mandatory = $true)][string]$Lead,
        [Parameter(Mandatory = $true)][string]$Note,
        [Parameter(Mandatory = $true)][string]$Reassurance
    )
    Write-Host "park-cycle: $Lead -- $Note" -ForegroundColor Yellow
    Write-Host '  ANOTHER SESSION OR DEVICE IS WORKING THIS BRANCH. Read what is there before building further' -ForegroundColor Yellow
    Write-Host '  (git pull --ff-only); if the tip is your own push from another machine, that is the same' -ForegroundColor Yellow
    Write-Host "  command. $Reassurance" -ForegroundColor Yellow
}

# $PSScriptRoot-relative, not $root: these libs are not repo-owned -- they travel with the SAME
# plugin/mirror payload as this script, so they resolve from the source root, a consumer's plugin cache
# and the in-repo mirror alike. LOADED BEFORE THE ROOT IS RESOLVED, because resolving it takes a git
# call and this is the lib that makes one safe -- see the block below.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\park-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
# The divergence sentence, shared with new-branch.ps1's resume warning and open-pr.ps1's remote-ahead
# gate rather than composed a fourth time (issue #1450 extracted it; #1600 added this caller). What it
# strips out of somebody else's %an and %s is the whole reason it is one definition -- see its header.
. (Join-Path $PSScriptRoot '..\lib\remote-ahead-lib.ps1')

# Dual-context repo root: a consumer running the plugin mirror gets it from CLAUDE_PROJECT_DIR, the
# source root copy falls back to the git root. Same resolution as every other mirrored script -- but via
# Invoke-NativeCapture rather than a bare `git ... 2>$null`, which is what this first tried. Two reasons,
# and the second is the one that decides it: a hook fires wherever the session happens to be, so running
# outside a git repo is an ordinary case here rather than an edge one, and git writes that refusal to
# stderr, which under EAP=Stop is terminating before any exit code can be read. The repo-wide guard in
# shared-scripts.tests.ps1 exists for exactly this and caught it on the first run.
$root = if ($RepoRoot) {
    $RepoRoot
} elseif ($env:CLAUDE_PROJECT_DIR) {
    $env:CLAUDE_PROJECT_DIR
} else {
    $topRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('rev-parse', '--show-toplevel') -DiscardStderr
    if ($topRes.ExitCode -eq 0) { (($topRes.Output | Out-String).Trim()) } else { '' }
}
if (-not $root -or -not (Test-Path -LiteralPath $root -PathType Container)) {
    Write-CycleParkNote "no repository resolved -- nothing to do."
    exit 0
}

# repo-config.ps1 optional, exactly as new-branch and check-branch-entry load it: entry-scaffold-lib
# reads the wording and path overrides from it, and a repo that renamed this document is resolved by its
# own names only while that file is already in the session. AFTER the libs, so its overrides win.
$repoConfig = Join-Path $root 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
    try { . $repoConfig } catch { Write-CycleParkNote "scripts/repo-config.ps1 failed to load -- the built-in paths are used." 'DarkYellow' }
}

# branch-info.ps1 IS repo-owned and does not travel with the plugin -- every consumer keeps their own
# prefix table and trunk name -- so it is loaded from the repo being acted on, guarded. All this script
# wants from it is the trunk name, which has a shared fallback, so a repo without the lib degrades to
# that rather than to a failure.
$branchInfoLib = Join-Path $root 'scripts\lib\branch-info.ps1'
if (Test-Path -LiteralPath $branchInfoLib -PathType Leaf) {
    try { . $branchInfoLib } catch { Write-CycleParkNote "scripts/lib/branch-info.ps1 failed to load -- the trunk name falls back." 'DarkYellow' }
}

# Current branch from HEAD. Via Invoke-NativeCapture so a detached or otherwise edge git state cannot
# turn a stderr line into a terminating error before the exit code is judged.
$branchRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $root, 'rev-parse', '--abbrev-ref', 'HEAD')
if ($branchRes.ExitCode -ne 0) {
    Write-CycleParkNote "not a git repository (or no HEAD) -- nothing to do."
    exit 0
}
$branch = ($branchRes.Output | Out-String).Trim()
if (-not $branch -or $branch -eq 'HEAD') {
    # A detached HEAD has no branch to push. Named rather than pushed to whatever it resolves to.
    Write-CycleParkNote "detached HEAD -- no branch to park."
    exit 0
}

# BOUND 2: the trunk, asked of the shared resolver and NOT of the seam directly. Get-BranchTrunkName
# already probes the consumer's optional Get-TrunkBranchName and falls back to 'main', so a second probe
# here would be one more place that has to keep agreeing with it -- exactly the shape park-lib was
# extracted to end. (check-branch-entry.ps1 carries that older two-step; it is not a defect there, it is
# just a layer this one does not need.)
$trunk = if (Test-FunctionDefined 'Get-BranchTrunkName') {
    $t = ([string](Get-BranchTrunkName)).Trim(); if ($t) { $t } else { 'main' }
} else { 'main' }

if ($branch -eq $trunk) {
    Write-CycleParkNote "on the trunk, where the fold removes this document by design."
    exit 0
}

# BOUND 1: the one document, resolved by the shared dual-read rather than by a path typed here -- so a
# branch opened before a rename, and a consumer who answered the folder seam differently, are both found.
$cycleRel = Resolve-BranchFilePath -Kind 'File' -RepoRoot $root
$cyclePath = Join-Path $root ($cycleRel -replace '/', '\')
if (-not (Test-Path -LiteralPath $cyclePath -PathType Leaf)) {
    Write-CycleParkNote "'$cycleRel' does not exist yet -- nothing to park."
    exit 0
}

# AND THE DOCUMENT MUST BE THIS BRANCH'S. Resolve-BranchFilePath falls back to a path that merely
# EXISTS when nothing claims the branch, which on a branch created outside new-branch is the reset
# document. Pushing that would put the trunk's own empty state on the branch under a `park:` subject.
$cycleText = [System.IO.File]::ReadAllText($cyclePath, [System.Text.Encoding]::UTF8)
$declared = Get-BranchFileDeclaredBranch -Text $cycleText
if (-not $declared -or $declared -eq $trunk) {
    Write-CycleParkNote "'$cycleRel' is in its reset state -- it belongs to no branch, so there is nothing to hand over."
    exit 0
}
if ($declared -ne $branch) {
    # Somebody else's document, sitting here uncommitted or committed on another branch. new-branch is
    # the script that decides what happens to it, with the owner named; this one keeps its hands off.
    Write-CycleParkNote "'$cycleRel' declares '$declared', not '$branch' -- left alone." 'DarkYellow'
    exit 0
}

# IS THERE ANYTHING TO DO AT ALL? Two independent reasons to push, and this is the gate that keeps a
# turn which touched nothing free of both a git write and the network call below.
#
#   a. the document differs from HEAD -- staged or not. `git status --porcelain` on the one pathspec.
#   b. HEAD is ahead of the remote branch, or the remote branch does not exist yet. A local commit
#      nobody can see is the same invisibility as an uncommitted edit.
$statusRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $root, 'status', '--porcelain', '--', $cycleRel)
$dirty = $false
if ($statusRes.ExitCode -eq 0) { $dirty = [bool](($statusRes.Output | Out-String).Trim()) }

# DELIBERATELY NO FETCH HERE. The remote-tracking ref is read as it stands: a fetch on every turn costs
# the network call this gate exists to avoid, and a ref that has gone stale because the other device
# pushed is exactly the case the paths below report on.
# TWO PATHS BELOW DO FETCH, and both are this rule rather than exceptions to it: the refused push (#1600)
# and the open-PR arm (#1953). Each sits BEYOND this gate, so a turn that touched nothing still returns
# from here without touching the network -- which is the turn this gate is protecting. What they buy is
# the half a stale ref cannot give: WHOSE work is on the other side, and only a fetch can say.
$aheadOrAbsent = $true
$remoteRef = "refs/remotes/origin/$branch"
$refRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $root, 'rev-parse', '--verify', '--quiet', $remoteRef) -DiscardStderr
if ($refRes.ExitCode -eq 0) {
    $countRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $root, 'rev-list', '--count', "origin/$branch..HEAD")
    $aheadOrAbsent = if ($countRes.ExitCode -eq 0) { (($countRes.Output | Out-String).Trim()) -ne '0' } else { $false }
}

if (-not $dirty -and -not $aheadOrAbsent) {
    Write-CycleParkNote "'$cycleRel' is already on origin -- nothing to do."
    exit 0
}

# NO ORIGIN, NOTHING TO DO -- asked before the gh call below, because a repo with no remote has no PR to
# ask about either. Same question new-branch asks for the same reason; Test-GitOriginConfigured carries it.
if (-not (Test-GitOriginConfigured -RepoRoot $root)) {
    Write-CycleParkNote "no 'origin' remote -- nowhere to park to."
    exit 0
}

# BOUND 3: THE DEPLOY LOCK -- AND THE QUESTION IT IS ACTUALLY ASKING, WHICH IS "HAS THIS BRANCH BEEN
# PUBLISHED?". Any PR with this head means its body has published a DEPLOY section that ship-pr will
# compare this document against, so from here on the document is the PR's to change, not this script's.
# Deliberately NOT filtered by --base: the question is not which PR would be merged but whether one has
# published a body at all, and a stacked PR publishes one just as an ordinary one does.
#
# '--state all', NOT '--state open' (issue #1035). Scoped to open PRs, this bound LIFTED the moment the
# PR merged, and nothing below it asked whether the branch had already shipped. Measured on
# fix/the-hook-rules-follow-their-own-entry-v1 (PR #1027): merged at 12:56:25, deleted by
# deleteBranchOnMerge two seconds later, and RE-CREATED on origin at 13:05:30 by this script's own Stop
# hook -- at the PR's head OID, with nothing on it that main did not already have. Three behaviours line
# up to produce it: this bound lifting; the "anything to do at all" gate above reading a remote-tracking
# ref without fetching, so a pruned origin/<branch> reads as absent and absent reads as "a local commit
# nobody can see"; and Invoke-GitPark pushing even with nothing to commit, which is deliberate (#175).
# Widening the bound is the cheapest of the three and the only one that repairs what the bound is FOR.
#
# WHY NOT "REFUSE WHEN HEAD IS AN ANCESTOR OF THE TRUNK", the other candidate. It answers a different
# question -- "is there anything on this branch?" rather than "has this branch been published?" -- and it
# does not cover the head #992 left behind, whose PR closed unmerged and which sat 96 files divergent
# from main. That head is invisible to prune-merged by design, and an ancestor test would have let this
# script push it back just as happily. Asking about the PR covers both.
#
# THE ESCAPE VALVE IS park-branch.ps1. This bound belongs to the AUTOMATIC park alone; a branch whose PR
# closed and whose work genuinely resumed is parked by hand, deliberately, which is where that judgement
# belongs -- and is why widening this cannot strand anyone.
#
# FAIL-SAFE DIRECTION. gh missing, gh not logged in, no network, an unparseable payload -- every one of
# them means the answer is unknown, and unknown does not push. See the lock paragraph in the header.
$prList = Invoke-NativeCapture -FilePath 'gh' -Arguments @('pr', 'list', '--head', $branch, '--state', 'all', '--json', 'number,state', '--limit', '1') -DiscardStderr
if ($prList.ExitCode -ne 0) {
    Write-CycleParkNote "could not ask gh whether '$branch' has a PR -- not pushing (the DEPLOY lock must not be broken from here)." 'DarkYellow'
    exit 0
}
$prRecord = Get-ExistingPrRecord -Json (($prList.Output | Out-String))
if ($null -ne $prRecord) {
    # THE NOTE SAYS WHICH REFUSAL THIS IS, the way the other bounds do: an open PR owns the document,
    # while a merged or closed one means the branch was already published and a push would put a deleted
    # head back on origin -- where `git ls-remote --heads origin` reports it as parked work, which is the
    # one read that exists to surface a branch with no PR.
    #
    # READ THROUGH PSObject.Properties, not $prRecord.state: Set-StrictMode -Version Latest THROWS on a
    # property gh did not return, and an older gh, a changed --json field or a hand-rolled shim must cost
    # the wording, never the refusal -- this script always exits 0 because a hook that fails interrupts
    # the work it was added to protect. The default arm is the pre-#1035 sentence, so an unknown state
    # degrades to exactly what this bound used to say.
    #
    # AND IT IS TWO STEPS, NOT ONE. Properties['state'] returns $null for an absent field, and
    # $null.Value throws under StrictMode just as $prRecord.state does -- so the guard has to be the
    # $null test, not the indexer. Caught by this suite's own 'pr-nostate' fixture on the first run.
    $stateProp = $prRecord.PSObject.Properties['state']
    $prState = if ($stateProp) { ([string]$stateProp.Value).ToUpperInvariant() } else { '' }
    $why = switch ($prState) {
        'MERGED' { "has already MERGED -- the branch shipped, and pushing it back would resurrect a head that 'git ls-remote' reports as parked work." }
        'CLOSED' { "is CLOSED -- the branch was published and its PR ended; pushing it back would resurrect a head that 'git ls-remote' reports as parked work." }
        default  { "is open -- the document is the PR's from here on." }
    }
    $valve = if ($prState -eq 'MERGED' -or $prState -eq 'CLOSED') {
        " If the work genuinely resumed on this branch, park it by hand with park-branch.ps1 -- that decision is deliberate, and this bound is the automatic park's alone."
    } else { '' }

    # THE BRANCH NAME IS STRIPPED BEFORE IT IS PRINTED, for the reason remote-ahead-lib.ps1 states at the
    # same interpolation one layer down (#1623): `git check-ref-format` accepts \p{Cf}, so a fetched or
    # hand-made branch really can carry U+202E or a zero-width run into a sentence a terminal AND an agent
    # session both read. Until #1953 this line printed it raw while the sentence directly below it -- built
    # from the SAME value -- went through the strip, which is one report with one half hardened.
    # $prRecord.number is a GitHub-assigned integer from `gh pr list --json number` and is not text anybody
    # chose, so it is not a subject.
    $shownBranch = Get-DisplayRef -Ref $branch
    Write-CycleParkNote "PR #$($prRecord.number) for '$shownBranch' $why$valve"

    # --- THE BOUND REFUSES THE PUSH; IT MUST NOT ALSO REFUSE TO LOOK (issue #1953) ------------------
    #
    # WHAT THIS BOUND SILENTLY TOOK WITH IT. The header above calls this script the earliest collision
    # detector in the workflow, and it is -- but only on a branch with no PR, because that claim rests
    # entirely on the push below being ATTEMPTED and REFUSED. From the line above, on every branch that
    # has an open PR, this run ended here: no push, so no refusal, so no fetch, so nothing to interpret.
    # Under -Quiet, which is what the Stop hook passes, it ended here in complete silence.
    #
    # AND THAT IS THE WORST BRANCH TO BE BLIND ON. A branch with an open PR and a red required check is
    # the single most likely object for two sessions to reach for independently: the work is
    # well-defined, visible on the PR list, and obviously owed. Measured September 13, 2026 (#1953): two
    # sessions on one account repaired the same red check on PR #1950 about 90 seconds apart, produced
    # the same three-file change, and learned of each other from git's non-fast-forward refusal at the
    # push -- after the diagnosis, the repair, the suite run and the lint gate had all been paid for
    # twice.
    #
    # THE REPAIR IS TO SEPARATE TWO QUESTIONS THE BOUND HAD FUSED. "May this script push?" is the DEPLOY
    # lock's question and the answer stays no -- nothing below writes, commits or pushes. "Is somebody
    # else on this branch?" is a READ, it owes the lock nothing, and it is the one thing this script is
    # positioned to ask that no other gate asks often enough: new-branch's warning (#1439) fires once at
    # a resume that goes through the script, open-pr's gate (#1446) fires at the end when the duplicated
    # work is already paid for, and neither is reached by a session that steps onto an existing branch by
    # hand -- which is what #1953 was filed for.
    #
    # WHY THE ENTRY MOMENT IS NOT WHAT THIS REPAIRS, stated because the issue proposes it. A check at
    # `git checkout <branch>` would not have caught the measured case: the second session stepped onto
    # the branch BEFORE the first had pushed, so there was nothing on origin to find. Only a check that
    # runs again, every turn, sees the other side arrive mid-work.
    #
    # OPEN PRs ONLY. A merged or closed PR means the branch has shipped or ended; a divergence there is
    # not two sessions building the same repair, and this path runs on every turn that has anything to
    # push, so a network call is bought rather than assumed.
    #
    # IT COSTS ONE ROUND TRIP ON A PATH THAT ALREADY MADE ONE. Reaching this line means the gate above
    # found either a dirty document or a local commit origin does not have, and then means the `gh pr
    # list` directly above answered -- so the ordinary turn the DELIBERATELY-NO-FETCH rule protects, the
    # one where nothing changed, still returns further up without touching the network at all.
    if ($prState -ne 'MERGED' -and $prState -ne 'CLOSED') {
        $openNote = Get-BranchCollisionNote -RepoRoot $root -Branch $branch
        if ($openNote) {
            Write-CycleCollisionReport `
                -Lead "PR #$($prRecord.number) is open for '$shownBranch', so this run pushes nothing" `
                -Note $openNote `
                -Reassurance 'Nothing here is lost -- this run committed nothing and pushed nothing.'
        }
    }
    exit 0
}

# WHAT IS BEHIND THE TICKS (#960), MEASURED HERE BECAUSE NOWHERE ELSE CAN. This script publishes the
# plan and nothing else -- bound 1 -- so on a branch whose work sits uncommitted in ANOTHER device's
# working copy it puts a document reading '[x] done' on origin with no commit behind a single tick. From
# origin those two states are the same document, and the more complete the ticks the more convincing the
# wrong reading: a session picking it up in good faith rebuilds work that already exists, or opens a PR
# that merges the plan alone. This is the device that HOLDS the invisible work, at the one moment it
# becomes invisible, so it is the only place the fact is both known and true.
#
# THE MEASUREMENT DOES NOT GET A VOTE ON THE PUSH. It is a note, not a gate: a park that refused because
# it disliked the shape of the plan would be the one thing worse than the misleading document, since the
# plan would then not reach the other device at all. Hence the try -- an unreadable document or an odd
# git state costs the note, never the park.
$backingNote = ''
try {
    $backingNote = Format-GitParkBacking `
        -Steps (Get-BranchProgressTally -Text $cycleText) `
        -Backing (Get-GitParkBacking -RepoRoot $root -Trunk $trunk -Paths @($cycleRel))
} catch {
    Write-CycleParkNote "could not measure what is behind the plan -- parking without that note." 'DarkYellow'
}

# THE STAGE-COMMIT-PUSH ITSELF LIVES IN park-lib.ps1 (#507), the one implementation the two deliberate
# parking entry points already share. This is the third caller and it adds no steps of its own: the
# scope picks both the pathspec and the words, so the log says `park: <branch> (the branch files only)`
# for this the same as for new-branch's push at creation.
# -NoFailureMessage: this caller reports its own failure below, with more than that sentence can know,
# and cycle-autopark.ps1 now merges the child's stderr into what it prints -- so leaving it in would put
# a PowerShell error banner above the report, in a hook whose contract is that it never fails (#1600).
$ok = Invoke-GitPark -RepoRoot $root -Branch $branch -Scope 'BranchFiles' -Paths @($cycleRel) `
                     -BodyNote $backingNote -NoFailureMessage
if (-not $ok) {
    # --- A FAILED PUSH HERE IS THE COLLISION SIGNAL, SO IT IS NAMED (issue #1600) -----------------
    #
    # WHAT THIS USED TO SAY, and why one line of it was the defect: "could NOT be pushed -- run
    # park-cycle by hand for the reason (diverged from origin?)". Every word of that is true and the
    # question mark is the problem -- it sends the reader for a reason this run already holds, and it
    # hedges the one fact worth stating outright. THIS SCRIPT IS THE EARLIEST DETECTOR IN THE WORKFLOW
    # of two sessions on one branch: it runs on a Stop hook after EVERY turn, so from the moment the
    # other side pushes, every turn of this session ends in a refused push. Nothing else looks that
    # often -- new-branch.ps1's own remote-ahead warning (#1439) fires once, at a resume that goes
    # through it, and open-pr.ps1's gate fires at the very end, after the work is paid for.
    #
    # MEASURED, September 8, 2026 (#1600). Two sessions ran the same pre-PR review on
    # feat/plugin-version-overview in full, from the same handoff note, and found DIFFERENT real
    # defects -- so neither round was redundant and either winning outright would have shipped a bug.
    # They diverged at 11:45, the other side's work reached origin at ~11:51, this side's autopark hit
    # its first refused push at 12:05, and the collision was not learned until open-pr refused the push
    # at ~12:20. The signal existed for half an hour. What the session's own report carried was git's
    # `! [rejected]` plumbing plus five `hint:` lines plus the sentence above; the ONE sentence naming
    # another session -- Get-GitPushFailureMessage's, written by Invoke-GitPark -- goes to stderr in a
    # PowerShell error banner, and cycle-autopark.ps1 captures stdout. So the interpretation was the
    # half that did not arrive.
    #
    # THE AUTHOR AND THE SUBJECT ARE THE POINT, exactly as new-branch.ps1 argues for the same sentence:
    # `park: ... (all outstanding work)` under an identity that is not yours is what separates a
    # collision from a fast-forward of your own autopark from another device. "1 commit behind" reads
    # identically in both, which is why the count alone would not have moved the measured case.
    #
    # THE FETCH IS NOT ON THE ORDINARY TURN, which is what the header's DELIBERATELY-NO-FETCH rule is
    # about: this branch is reached only after a push has already reached the remote and been refused BY
    # it -- the network is up, the turn has already paid for a round trip, and nothing else can say what
    # is on the other side. One ref, bounded by the shared network timeout, and a fetch that fails costs
    # the tip line and never the report. THE SECOND PLACE THAT HOLDS IS THE OPEN-PR ARM ABOVE (#1953),
    # which pays for it on the same terms and for the same question -- hence the shared reader.
    $note = Get-BranchCollisionNote -RepoRoot $root -Branch $branch

    # Reported, never fatal -- see the always-exits-0 paragraph. Write-Host rather than Write-Warning
    # so it lands on the stdout cycle-autopark.ps1 captures and re-prints: a Stop hook's report IS this
    # sentence's delivery route, and the whole finding above is that the interpretation went to the one
    # stream that route does not read.
    if ($note) {
        Write-CycleCollisionReport `
            -Lead "'$cycleRel' could NOT be pushed" `
            -Note $note `
            -Reassurance 'Nothing on this branch is lost -- the push was refused, not overwritten.'
    } else {
        # The push failed for something other than a divergence this run could read: no origin left, a
        # credential refusal, a timeout, a fetch that could not answer either. Git's own output is above.
        Write-Host "park-cycle: '$cycleRel' could NOT be pushed -- see git's output above; run park-cycle by hand for the reason." -ForegroundColor Yellow
    }
    exit 0
}

exit 0
