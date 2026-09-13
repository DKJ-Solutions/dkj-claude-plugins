<#
.SYNOPSIS
    Ship the current branch in one command: open the PR -> wait for the CI check -> merge -> fold --
    or, on a trunk behind a merge queue, open -> wait -> ENQUEUE, with the merge and the fold left to
    the queue and to fold-on-merge.yml (issue #1506).

.DESCRIPTION
    Orchestrates the whole PR chain that is otherwise run by hand
    (open-pr.ps1 -> watch CI -> gh pr merge -> checkout main -> fold-changelog-entry.ps1), so the
    five-step sequence becomes one call. WHEN it may run is governance, not script logic (see
    CLAUDE.md): by default a finished branch ships without asking, but work with a visible result --
    or work that is irreversible/outward-facing -- waits for Dave's explicit word first.

    SHARED SINCE ISSUE #411 -- mirrored into the plugin like open-pr/fold/new-branch, and no longer
    workshop-local. It was excluded on the reasoning that "merge policy and the CI check name are
    repo-specific", and only half of that held up when it was checked. The CI check name is not used by
    this script at all: step 3 watches whatever checks the PR has and reads the exit code, so the name
    only ever appeared in a progress message. The merge method IS a real per-repo policy -- this
    workshop merges, the repo that filed #411 squashes -- so it moved into the seam as the OPTIONAL
    Get-PrMergeMethod rather than staying hardcoded. Note that the issue predicted no new contract
    function would be needed; that prediction is the one part of it that did not survive reading both
    files, and building on it would have shipped one repo's merge policy to the other.

    Everything else it needs was already repo-owned: Get-RepoName for the `gh --repo` target. That
    sentence used to name Get-ChangelogHeading beside it, "which it never reads itself --
    fold-changelog-entry.ps1 does". Neither reads it: the seam was retired on August 5, 2026 with the
    flat changelog (#178), and the fold derives the intro/list boundary from the first entry heading.

    Steps, stopping on the first failure (nothing is forced):
      0. IS 'main' FREE FOR STEP 5 TO CHECK OUT? (issue #1069) git allows one worktree per branch, so a
         second checkout standing on the trunk locks it for the whole clone -- and step 5 checks it out
         HERE in order to fold. Until this step existed that lock was met AFTER the merge, which is the
         worst place in the run to stop: merged, unfolded, and every gate green until a release trips
         over it (measured on PR #1068). Asked before step 1, the last moment at which refusing is free.
         It takes the trunk away from nobody -- it names the directory and the two commands that release
         it -- and an unreadable worktree list warns rather than refuses.
     0b. CAN THIS ACCOUNT PUSH THE FOLD AT ALL? (issue #1278) Its sibling, and the same half-state by a
         different route: step 0 asks whether step 5 can CHECK OUT the trunk, this asks whether it can
         PUSH to it. A required status check on 'main' cannot be satisfied by a direct push -- the
         pushed commit carries no checks -- and the fold IS a direct push, so an account without bypass
         merges and then cannot fold. Measured on PR #1271: merged, folded, committed, GH013 on the
         push. Two gh reads decide it (the trunk's rules, then this account's bypass on the ruleset
         carrying them); it cannot be read off the merge, which the PR's own check satisfies. Asked in
         the same place and for the same reason, and an unreadable ruleset warns rather than refuses.
         AND THE SAME PAYLOAD ANSWERS A SECOND QUESTION FOR FREE (issue #1506): whether the trunk is
         behind a MERGE QUEUE. If it is, this run will not push the fold at all -- the queue merges the
         PR and fold-on-merge.yml folds off that push (#1493) -- so the refusal above is skipped rather
         than stopping every ship on a push it was never going to make. Read before Active: an
         unreadable payload is not "no queue", and keeps the old behaviour on both questions.
      1. open-pr.ps1 [-SkipLint] [-SkipTests] [-MaxParallel <n>] -- runs the local lint + test gate,
         pushes, and opens the PR. If a gate fails, nothing is pushed and this stops here.

         AND IT IS THE ONE STEP THAT READS THE WORKING TREE, so it is the one window in which THIS
         CHECKOUT IS SINGLE-OCCUPANCY (issue #1145). Everything from step 2b down reads refs and the
         PR instead, deliberately, which is what lets the tree go home before the CI wait. Step 1
         does not: the lint gate walks the tree and the suites walk it for a minute or more. A second
         command in the same checkout during that minute -- new-branch.ps1 cutting a branch,
         worktree-lane.ps1 moving the tree -- makes files vanish and reappear under a running suite.
         Measured on PR #1144: one suite of 55 red inside the gate, green standalone on the same
         commit seconds later, with prune-merged.ps1 holding the trunk beside it; that one stopped
         taking the checkout in #1147, and the window it exposed is still open to the rest.
         Nothing enforces this: open-pr now SAYS when the tree moved under a
         gate, so the red is legible rather than mysterious, and the remedy is to re-run. Build the
         next piece of work in a lane (worktree-lane.ps1) rather than here -- which is what step 3
         already advises for its own reason.

         RESUMES A BRANCH WHOSE PR IS ALREADY OPEN. open-pr.ps1 skips only the `gh pr create` in that
         case and still runs the gates and the push, so this orchestrator carries straight on to
         step 2. Until August 4, 2026 it could not: `gh pr create` was unconditional, a duplicate
         returned non-zero, and step 1's failure meant steps 2-6 never ran -- so a branch whose PR had
         been opened in an earlier session had to be merged and folded BY HAND, which is the five-step
         sequence this script exists to remove. Measured on PR #457 and repaired in open-pr.ps1 rather
         than here: putting the check in the orchestrator would have skipped the gates and the push
         along with the create, and made `open-pr.ps1` on its own still fail on the same branch.

         An existing PR keeps its title -- as every PR now does, the title being composed from the entry
         at creation and never rewritten afterwards (#506) -- and -Resolves is still honoured: the
         closing keywords are appended to the existing body, because step 6 below verifies exactly what
         the merged body declared. Pass -RefreshBody to also rewrite the PR's description from the
         changelog entry -- worth it whenever the entry was extended after the PR was opened, which is
         the normal case on a branch that keeps growing. Both body edits go out as ONE `gh pr edit`.
      2. Look up the PR number for the current branch (gh pr list --head <branch> --base main),
         parsed by Get-ExistingPrRecord. Both details are repairs, measured August 4, 2026: without
         --base a consumer's STACKED PR could be the one merged, and the previous inline parse hit the
         5.1 array-flattening pitfall -- its "no open PR" guard was dead code and a missing PR became
         the empty string, so the script would have run `gh pr merge ''`. See the comment at step 2.
     2b. GIVE THE TRUNK BACK, BEFORE THE WAIT RATHER THAN AFTER IT (issue #1073). Chris's persona says
         both "parking is a state, not a promise to come back within the turn" -- an in-flight ship is a
         finished assignment -- and "it ends on the trunk, which is what makes the session safe to
         clear". A backgrounded ship could not satisfy both, because HEAD did not move until step 5.
         It can now: since #970 the step-4 gates read refs/heads/<branch> and since #972 step 5 reads
         HEAD before it moves anything, so NOTHING BELOW THIS POINT READS THE WORKING TREE'S CONTENT.
         Three conditions, in Get-TrunkReturnDecision and tested there: the primary checkout only, the
         trunk held by nobody else, and a clean tree. Never a refusal -- a tree that cannot go home
         stays where it is and says which of the three it was.
      3. Wait for every check the ruleset REQUIRES to finish (gh pr checks <pr> --watch --required),
         then judge the merge on those same checks. A failing required check stops the run WITHOUT
         merging; a failing check the ruleset does not require prints a loud warning and does not
         (issue #943 -- the exit code of --watch says "something failed", never "the merge is blocked",
         and reading it as the second let one broken advisory workflow block every chain). Print WHICH
         check governed the wait and for how long (#831) -- whichever finished last, labelled against
         the repo's own ruleset. Best-effort: unreadable, and the run says only how long it waited --
         except for the required list, where unreadable means REFUSE, since a ruleset that requires
         nothing and one whose required checks have not reported look identical from here.

         `--required` SINCE ISSUE #1602, and WHICH checks those are is read from the trunk's BRANCH
         RULES -- the payload step 0b already fetched -- rather than from `gh pr checks --required`,
         which reports only what has registered and so answered nothing on this change's own first
         ship (PR #1614), leaving it inert. That probe survives as the fall-back for a token that
         cannot read the rules. With no required check known this waits on EVERY check
         exactly as it did before, so a repo with no ruleset is untouched. The non-required checks are
         still waited for and still reported -- at step 8, after the fold. What that buys is the LAP,
         not the clock: the trunk goes on moving while this step waits, and a commit landing between
         the last required check and the last check of any kind voids the certificate step 3b then
         correctly refuses on. Measured over 99 laps: 5.1% of them, and 62.5% of the tail-governed laps
         on the busiest day of the sample. #831's wait and #831's report both survive it, because a red
         non-required check has never blocked this merge (#943) -- so waiting for one before the merge
         only decided when a sentence was printed. Full argument and figures at the step.

         AND RE-ENTER THE WATCH WHEN IT IS THE CONNECTION THAT DROPPED, NOT A CHECK (issue #1219).
         `--watch` is one long-lived GraphQL call and it can die mid-wait on a transient socket error
         while every check is still pending -- read from its exit code alone that is indistinguishable
         from a failure, and the operator was told to "fix CI and re-run" about a run that goes green
         on its own. Up to three attempts, decided from the check payload (nothing failed and something
         is still running) rather than from gh's error text; a real red check breaks out on the first
         pass, and so does a payload that cannot be read. If the attempts run out the merge is still
         refused, in a sentence that says CI is still RUNNING -- the verdict does not move.

         AND RE-ENTER IT WHEN THE WATCH WENT GREEN OFF A CHECK THE RULESET DOES NOT REQUIRE (inbound
         #1549). `--watch` watches whatever was registered when it STARTED, so a required workflow that
         has not created its check run yet is absent from that set rather than pending in it: a
         non-required check passing in 1s exits the watch 0 with the required one still to come, and the
         merge is then refused by the base-branch policy -- past the gates, past the PR, with the merge
         and the fold still owed to a process that is about to die. So the green exit is held against
         `gh pr checks --required` before it is believed, and a required check that has not concluded
         sends the run back to the wait rather than to the merge. Fail-open by construction: an
         unreadable required list spins on nothing, which is what keeps a repo with no ruleset out of
         this branch and keeps an unreadable payload from ever turning a green run red.

         AND SAY, BEFORE THE WATCH BEGINS, THAT NOBODY HAS TO SIT THROUGH IT (issue #985). Backgrounding
         this run is the default: the merge cannot move before the check is green either way, so the only
         thing the wait buys in the foreground is a second look at a result the local gate already gave.
         The lane is printed with it, and it is advice rather than the condition it once was: step 2b has
         already moved this tree to the trunk, so the next branch belongs in a lane because that is where
         you build, not because staying here would cost you your checkout.
     3b. HAS 'main' MOVED SINCE THE RUN THAT CERTIFIED THIS PR? (issue #1292) A required check tests
         GitHub's merge ref roughly as it stood when the run was CREATED and is never refreshed if 'main'
         moves afterward, so a green check can go STALE between the run and the merge -- measured at
         31.1% of recent merges (14/45), median staleness 16.1 minutes, max 146.6 (PR #1268 itself).
         Refuses (with -SkipStaleCheck as the valve) when 'main' gained a first-parent commit since the
         earliest certifying run's own `created_at` -- NOT a check's `startedAt`, which under-refuses:
         a red-team caught that the first build anchored on the later, wrong-direction timestamp.
         With no required check named at all this step WARNS and does nothing, matching how the rest of
         this script already treats "no ruleset" versus "unreadable"; once one IS named, every read from
         there on (the run, its `created_at`, the fetch, the log) FAILS CLOSED, because at that point
         there is something specific to verify and not verifying it must never read as sound. See the
         comment at the step for the full corrected mechanism and why "the branch is behind" (#1292's own
         filed predicate) is the wrong, wider question.
      4. TWO GATES, THEN MERGE. The step-list gate refuses while the branch's development document has an unresolved
         step above DEPLOY, and the DEPLOY LOCK (issue #884) refuses when that section no longer matches
         what PR #NN published -- the section is fixed at the moment the PR opens, because it is what the
         review approved and what step 5 folds into CHANGELOG.md. Both are checked here rather than
         inherited from step 1: open-pr has a -Force and a PR opened on github.com ran neither. Neither
         has a -Force of its own. A PR body that cannot be READ is not a finding -- that says something
         about the token, not about the section.
         BOTH JUDGE refs/heads/<branch>, NOT THE WORKING TREE (issue #970): this script waits on CI, and a
         session that backgrounds the ship and starts the next piece of work has moved the checkout by the
         time the gates look. The branch's own commit is what the merge merges.
         Then: gh pr merge <pr> --<method>, from Get-PrMergeMethod ('merge' by default), with the
         merge commit's subject set to 'merge: <branch> (#NN)' so every line in the graph starts with
         a type. No --admin: the CI gate is never bypassed.

         AND WITH A MERGE QUEUE ON THE TRUNK THAT CALL ENQUEUES RATHER THAN MERGES (issue #1506).
         `gh pr merge --help`: "When targeting a branch that requires a merge queue ... the pull request
         will be added to the merge queue." ADDED, exit 0, not merged -- and gh says so on stderr with
         `! The merge strategy for main is set by the merge queue`, which is a NOTICE, not a failure.
         Nothing had to change for that line: Invoke-NativeCapture judges $LASTEXITCODE and merges
         stderr into the printed output, so the notice is shown and the exit code decides (#96/#107).
         Whether a queue is there is read once at step 0b, off the payload that step already fetches.
         When it is, this run ends HERE, at step 4: the PR is enqueued, and steps 5-7 belong to the
         merge this session will never see. Step 3b (staleness) stays and becomes belt-and-braces --
         the queue builds each entry against its real base by construction.
      5. Check out main, fast-forward, and hand the fold to fold-changelog-entry.ps1 -Push, which folds
         the entry AND makes the commit itself -- naming CHANGELOG.md and the entry file as the
         commit's pathspec.

         THAT DELEGATION IS THE POINT, not a tidy-up. This step used to run its own `git add -A` +
         `git commit`, which is an unscoped commit landing directly on main under one of the two named
         exceptions to "never commit directly" -- so anything else modified or already staged in the
         tree rode along with it. CLAUDE.md has stated since August 2, 2026 that the fold commit "names
         its paths, so nothing else in the tree can ride along"; that was true of the fold script and
         false of this orchestrator, which is the more commonly used route of the two. An exception is
         only safe while it stays the size it was granted at, and here it was not.

         AND IT GIVES THE TRUNK BACK WHEN THIS IS NOT THE PRIMARY CHECKOUT (step 5b, issue #1069). In
         the primary, ending on the trunk is deliberate -- it is what makes the session safe to clear.
         In a worktree lane the identical line takes the clone-wide lock step 0 above exists to report,
         so a non-primary tree returns to its own branch once the fold has SUCCEEDED. Only on success: a
         failed fold leaves this tree on main mid-repair, which is where whoever finishes it by hand
         needs to be standing. It never fails the ship.

         AND A FOLD LOST TO fold-on-merge.yml IS A SUCCESS, NOT A FAILED SHIP (step 5c, issue #1792).
         Both fold on the ordinary path now that the merge queue is retired (#1720), so the merge one
         step above triggers the job this step is racing. Losing that race means the entry is already
         upstream: the fold script says so with exit code 3, this run carries on, and step 5c prints the
         two commands (preserve, then realign) that bring THIS checkout's own trunk back into line --
         the only thing the race actually costs.
      6. Verify the issues the PR declared it closes are actually CLOSED, and close any that are not
         (verify-resolved-issues.ps1 -- its own script, and tested there).
      7. Say so when the repo does not delete head branches on merge, so the merged branch is not left
         standing on the remote unnoticed (inbound #815). A read, never a flag: the repo setting covers
         every merge route while --delete-branch covers only this one. Silent when the answer is yes.
      8. Wait for the NOT-required checks and report what they said (issue #1602) -- #831's report, at
         the one moment it can be complete, since step 3 no longer waits for them. It runs LAST because
         it waits on somebody else's CI and everything owed to the trunk is already done: the merge, the
         fold, its push and the hand-back. It can therefore stall or be abandoned without leaving a
         half-state, and it never fails the ship. Skipped entirely where step 3 watched every check.

    Steps 7 and 8 were added to this list on September 8, 2026; step 7 had been documented only at the
    step since #815, which is the same undercount this file's own conventions call a gap to close on
    discovery rather than a quiet exception.

    Step 6 is the second half of the resolves gate (a lesson from PRs #341-#343, where eight repaired
    findings stayed open because the bodies carried plain mentions instead of closing keywords).
    open-pr.ps1 writes the `Closes #<n>` lines; GitHub honours them on merge into the default branch.
    Step 6 then checks the outcome. A belt on top of a brace: if it never fires, the keyword did its
    job. It cannot fail the ship -- the merge has already happened by then.

    -NoMerge stops after step 1 (open the PR only) -- the same as calling open-pr.ps1 directly, but
    handy when scripting. The native git/gh calls run through Invoke-NativeCapture (the #107 stderr
    guard). Pure ASCII (repo convention for .ps1).

    NOTE (test gap): like open-pr.ps1 this orchestrator drives live git/gh against a real remote and
    is not covered by an automated suite -- the sub-steps it calls (open-pr, fold,
    verify-resolved-issues, the helpers) are tested on their own. Step 6 was deliberately extracted
    into its own script for exactly that reason: it is the one step here that MUTATES state outside
    this repo (it posts comments and closes issues), so leaving it inline would have meant untestable
    write access. What remains untested here is only the orchestration order.

    That gap is not free, and step 2 is the proof: the bug it carried was in an inline PARSE, not in
    the orchestration, and it survived because it sat in the one file no suite reads. Moving the parse
    into pr-issues-lib.ps1 (Get-ExistingPrRecord) is why the same mistake is now a failing assert. The
    lesson generalises: anything in here that is a pure function of text belongs in a lib, precisely
    because this file cannot be tested.

    Repo root: dual-context (CLAUDE_PROJECT_DIR for a consumer running the plugin mirror, otherwise the
    git root), so the root copy and the mirror stay byte-identical -- guarded by the shared-scripts
    drift lint.

.PARAMETER Title
    ACCEPTED AND IGNORED since #506 (August 7, 2026), for the reason open-pr.ps1's own parameter states:
    the PR title is composed from the branch prefix and the entry's 'Branch title' section, so there is
    nothing to pass. Kept as a parameter, and passed through, so that a caller who still supplies one gets
    open-pr's single warning instead of a hard "A parameter cannot be found" at the end of a finished branch
    -- and so the two scripts say the same thing in one place rather than two.

.PARAMETER SkipLint
    Passed through to open-pr.ps1 (skip the lint gate -- escape valve).

.PARAMETER SkipTests
    Passed through to open-pr.ps1 (skip the test gate -- escape valve).

.PARAMETER MaxParallel
    Passed through to open-pr.ps1: how many test suites its test gate runs at once. 0 (the default)
    is not forwarded at all, so an ordinary run is byte-identical to before.

    THE PAIR MATTERS MORE HERE THAN ANYWHERE (issue #1443). This is the script a session reaches for,
    and the one whose gate runs unattended while the session does something else -- so it is the one
    where a gate that will not finish used to leave -SkipTests as the only way forward. Running the
    suites SMALLER and running them NOT AT ALL are the two answers, and only one of them measures.
    open-pr.ps1's own .PARAMETER MaxParallel carries the numbers behind that.

.PARAMETER Force
    Passed through to open-pr.ps1: ship an entry that still carries its scaffold wording (the scaffold
    gate's escape valve).

.PARAMETER NoMerge
    Open the PR and stop (do not wait for CI, merge, or fold).

.PARAMETER SkipStaleCheck
    Escape valve for the step-3b certificate-staleness check (issue #1292): merge even though 'main'
    has gained a commit since the run that certified this PR was created, OR that check could not be
    completed at all (the run behind a required check, its 'created_at', the fetch, or the log). Use it
    only when the situation is known-harmless (e.g. the gained commits are docs-only, or you have
    confirmed by hand that the certificate is sound) -- the ordinary remedy (bring the branch up to date
    and let CI re-run) is cheap and this valve skips it.

.PARAMETER PollSeconds
    Poll interval (seconds) for the CI watch. Default 15.

.PARAMETER Resolves
    Passed through to open-pr.ps1: the issue numbers this PR resolves, as a string ('331,332').
    Step 6 verifies them. A string and not an [int[]] for the reason documented on open-pr.ps1's own
    parameter: across `powershell -File` a comma list is cast to one number via the thousands
    separator ('332,340' -> 332340), silently and without an error. Quote it when calling this script
    directly, too -- see the same note there for why an unquoted comma list cannot bind at all.

.PARAMETER NoResolves
    Passed through to open-pr.ps1: declare that this PR closes no issue.

.PARAMETER RefreshBody
    Passed through to open-pr.ps1: on a branch whose PR is already open, rewrite that PR's description
    from the current changelog entry. Opt-in, so a body edited on github.com is never overwritten unasked.
    No effect when the PR is being created in this run.

.EXAMPLE
    ./scripts/release/ship-pr.ps1

.EXAMPLE
    ./scripts/release/ship-pr.ps1 -Resolves '331,332'
#>
[CmdletBinding()]
param(
    [string]$Title = '',
    [switch]$SkipLint,
    [switch]$SkipTests,
    [switch]$Force,
    [switch]$NoMerge,
    [switch]$SkipStaleCheck,
    [int]$PollSeconds = 15,
    [string]$Resolves = '',
    [switch]$NoResolves,
    [switch]$RefreshBody,
    # Lanes for open-pr's test gate; 0 forwards nothing. See .PARAMETER MaxParallel.
    [int]$MaxParallel = 0
)
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Repo root -- dual context: a consumer running the shared plugin mirror gets its repo root from
# CLAUDE_PROJECT_DIR; in the workshop root (or outside a session) it falls back to the git root. Same
# resolution as every other mirrored script, and the reason this file can be byte-identical in both
# places.
$repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (git rev-parse --show-toplevel).Trim() }
Set-Location $repoRoot

# Pre-flight (#86): this script hard-requires the consumer's repo-config (unlike new-branch,
# which treats it as optional) -- Get-RepoName has no sane default, and without it every gh call below
# would target the wrong repo or none at all. Stop with a pointer instead of a raw dot-source error.
$configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Error "ship-pr cannot run -- missing repo-owned file: $configPath (Get-RepoName). This file is repo-specific and belongs in the consumer's repo root. Create it (the specialists-init bootstrap lays down a VUL-IN scaffold, or take an existing consumer / the source repo as a model) and run again afterward."
    exit 1
}

# Repo name from the local repo-config (single source), and the shared native-capture helper (#114) --
# which also carries Get-GitFileTextAtRef, the read the two step-4 gates judge the branch's commit with.
. $configPath
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
# For Get-ExistingPrRecord in step 2. $PSScriptRoot-relative, not $repoRoot: like native-capture-lib
# this one is not repo-owned -- it travels with the same plugin/mirror payload as this script.
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
# For the step-list gate before the merge in step 4 (Resolve-BranchFilePath, which the gate hands its own
# -Reader, and Get-BranchProgressFindings). Same plugin-payload sibling, same reasoning as the two above.
. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
# For the DEPLOY lock before the merge in step 4 (Test-DeployLock, and the Get-PrDescription it calls).
# Loaded AFTER entry-scaffold-lib on purpose: Get-PrDescription probes for the section-heading seams with
# Get-Command and falls back to English defaults when they are absent, so a repo that renamed a heading is
# read by its own names only while that lib is already in the session. Same plugin-payload sibling.
. (Join-Path $PSScriptRoot '..\lib\pr-body-lib.ps1')
# For the trunk-lock pre-flight below and the hand-back at the end of step 5 (issue #1069). Same
# plugin-payload sibling as the four above, and pure text functions for the reason its own header gives:
# the decision they carry -- does another worktree hold the trunk? -- is the one part of this repair that
# CAN be tested, and this file cannot be.
. (Join-Path $PSScriptRoot '..\lib\worktree-lib.ps1')
# For step 3b's fold exemption (#1592): Get-SeamValue + Get-DefaultChangelogPath answer where THIS repo's
# changelog is, which is half of the two-path bound a fold commit has to fit inside. Same plugin-payload
# sibling and the same unguarded dot-source open-pr.ps1 and fold-changelog-entry.ps1 already use for it.
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
# For every printed remedy below that puts the branch name into a command the reader runs verbatim
# (issue #1594): Get-PasteableRef decides whether the name may go in at all, and supplies the placeholder
# plus the explaining line when it may not. Same plugin-payload sibling and the same unguarded
# dot-source as the six above -- a payload missing this file must fail at load rather than print an
# unguarded command.
. (Join-Path $PSScriptRoot '..\lib\ref-print-lib.ps1')

# THE CLOSE-OUT RECEIPT SHAPE (issue #1884), printed as this run's last line -- see closeout-lib.ps1
# for why step 6 of the ritual got a mechanism after losing four times in prose. Guarded on
# git-porcelain-lib's grounds: a consumer whose mirror predates this lib must not crash on load, and
# the call site tests for the function rather than assuming the dot-source took.
$shipCloseoutLib = Join-Path $PSScriptRoot '..\lib\closeout-lib.ps1'
if (Test-Path -LiteralPath $shipCloseoutLib -PathType Leaf) { . $shipCloseoutLib }

$repo = Get-RepoName

# The merge method is repo POLICY, not script logic (issue #411): this workshop merges, another repo
# squashes. OPTIONAL and Get-Command-guarded like the other seam reads, so a consumer that never
# thought about it gets 'merge'. Validated rather than passed straight through -- an unexpected value
# would otherwise reach `gh pr merge` as an unknown flag at the one moment this script is about to
# write to main, which is the worst place to discover a typo in a config file.
$mergeMethod = 'merge'
if (Test-FunctionDefined 'Get-PrMergeMethod') {
    $configuredMethod = Get-PrMergeMethod
    if ($configuredMethod) {
        if (@('merge', 'squash', 'rebase') -notcontains $configuredMethod) {
            Write-Error "Get-PrMergeMethod in scripts\repo-config.ps1 returned '$configuredMethod'; it must be 'merge', 'squash' or 'rebase'. Nothing was pushed or merged."
            exit 1
        }
        $mergeMethod = $configuredMethod
    }
}

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -eq 'main') {
    # THE REFUSAL DIAGNOSES INSTEAD OF ONLY RESTATING THE RULE (issue #1620). Standing on the trunk is
    # usually a plain mistake -- and it is ALSO the state this script's own step 2b creates: the trunk is
    # handed back the moment the PR exists (#1073), so for the whole CI wait, the longest step in the run,
    # HEAD says 'main' while a merge and a fold are still owed. A run that does not survive that wait
    # leaves exactly this checkout, and the operator re-running ship-pr met a message about the wrong
    # problem. Measured on PR #1618, September 8, 2026: the backgrounded process was killed by the host
    # for low memory, and `git checkout <branch>` plus the same command resumed correctly.
    #
    # #1588's REPAIR CANNOT REACH THIS. It put the checkout at the head of the stale-CI refusal's printed
    # remedy, which helps a run that gets as far as printing one; an interrupted process prints nothing at
    # all, and the kill takes the scrollback with it. The sentence the operator needs was in this file the
    # whole time -- the dropped-watch retry block's comment says resuming a ship that died there means
    # checking the branch out again -- which is a comment nobody is reading at that moment.
    #
    # BEST-EFFORT, AND THE REFUSAL IS UNCHANGED WHERE IT CANNOT READ. Two reads, neither of them load-
    # bearing: an unreadable one yields no candidates and the message is the line it has always been.
    # Same posture and same reason as Get-MissingCheckSuiteRefusalNote below -- a diagnostic must never be
    # why a refusal cannot be printed. It costs two commands on a path that is already refusing.
    $resumeNote = ''
    $openPrList = Invoke-NativeCapture -FilePath 'gh' -Arguments @('pr', 'list', '--state', 'open', '--json', 'number,headRefName', '--limit', '100', '--repo', $repo) -DiscardStderr
    $localHeads = Invoke-NativeCapture -FilePath 'git' -Arguments @('for-each-ref', '--format=%(refname:short)', 'refs/heads') -DiscardStderr
    if ($openPrList.ExitCode -eq 0 -and $localHeads.ExitCode -eq 0) {
        # THE PASTE VERDICT IS RESOLVED HERE rather than in the lib, because ref-print-lib.ps1 owns that
        # judgement (#1594) and these names are the least trustworthy refs this script prints: a head ref
        # is chosen by whoever opened the PR, not by this operator's own checkout.
        $resumeCandidates = @(Get-InterruptedShipCandidates -Json ($openPrList.Output -join "`n") -LocalBranches @($localHeads.Output) -TrunkBranch 'main' | ForEach-Object {
            $candidatePaste = Get-PasteableRef -Ref $_.Branch
            [pscustomobject]@{ Number = $_.Number; Branch = $_.Branch; Token = $candidatePaste.Token; Note = $candidatePaste.Note }
        })
        $resumeNote = Get-InterruptedShipResumeNote -Candidates $resumeCandidates -TrunkBranch 'main'
    }
    Write-Error "You are on main; ship-pr runs from a branch.$resumeNote"
    exit 1
}

# JUDGED ONCE, HERE, RATHER THAN AT EACH OF THE FIVE PRINT SITES (issue #1594). Every remedy this
# script prints puts the SAME name into a command, so one verdict beside the read that produced it
# cannot drift from a second one further down -- and it is computed unconditionally because four of the
# five sites are refusal paths that must not do work of their own on the way out. $branch here is the
# branch this run is shipping, read off HEAD, so a hostile name is one somebody pushed and this operator
# then checked out; the reachability argument is in the issue, and the repair does not depend on it.
$branchPaste = Get-PasteableRef -Ref $branch
# THE SAME NOTE WITH ITS OWN LEADING BLANK LINE, for the three here-strings that append it to a command
# line rather than printing it through Write-Host. A branch name safe to paste is the overwhelmingly
# common case, and an interpolated '' sitting on its own line would add a stray blank line to every one
# of those refusals as they have always printed -- so the safe path stays byte-identical and only the
# refused path grows. One definition rather than three locals: the three sites want the identical string.
$branchPasteNoteBlock = if ($branchPaste.Note) { "`n" + $branchPaste.Note } else { '' }
# AND THE DISPLAY NAME, judged in the same place for the same reason (issue #1623). The paste verdict
# above covers the lines a reader is invited to RUN; this covers the eleven lines that merely quote the
# branch in a sentence, which #1594 scoped out on the ground that git rejects the characters that would
# make prose deceptive. It rejects \p{Cc} and accepts \p{Cf}: a branch carrying U+202E, U+200B, U+200D or
# U+2066 is creatable, checkout-able and returned verbatim by the `git rev-parse` above, so those
# sentences could print a name that reads as a different branch than the one being shipped. Not a
# placeholder, unlike the paste axis -- a sentence has to keep naming the branch to be worth printing --
# so the characters go and the words stay. Every prose site below uses this; $branch itself stays raw and
# is what every git and gh argument in this script still receives.
$branchShown = Get-DisplayRef -Ref $branch

# --- Step 0: is 'main' free for step 5 to check out? (issue #1069) --------------------------------
# THE ORDERING IS THE WHOLE POINT. git allows one worktree per branch, so a tree standing on 'main'
# locks it for the entire clone -- and step 5 checks 'main' out HERE in order to fold. Until this check
# existed, that lock was met at step 5: after the merge. The PR was then merged and NOT folded, which is
# the one state nothing reports (CHANGELOG.md unfolded, the development document still on the trunk,
# every gate green until a release trips over it). Measured on PR #1068, August 29, 2026.
#
# Asked HERE, before step 1, because this is the last moment at which refusing costs nothing: no gate has
# run, nothing is pushed, no PR exists and nothing is merged. The check itself proves nothing about the
# CI wait that follows -- another session can take 'main' while step 3 watches -- which is why step 5's
# in-place arm now carries the full hand-fold instruction as well. This one turns the common case from a
# half-state into a refusal; that one keeps the rare case readable.
#
# NEITHER ARM TAKES 'main' AWAY FROM ANYBODY, and that restraint is deliberate: the holder may be a lane
# with work in it, and this script does not know what. It names the directory and the two commands that
# release it.
#
# IT ALSO ANSWERS THE SECOND HALF OF #1069, at the end of step 5: whether THIS tree is the primary
# checkout. Read here rather than there because it is the same porcelain, and because an unreadable list
# has to fall back to "primary" -- which is the behaviour every run had before this change.
#
# THE REFUSAL ITSELF IS DEFERRED PAST THE QUEUE VERDICT (issue #1572). Its whole ground is "step 5 could
# not fold after the merge" -- and under a merge queue step 5 folds nothing: the queue's own push to main
# runs fold-on-merge.yml (#1493), so this session opens, waits, enqueues and exits without touching the
# trunk. Refusing here would block the exact workflow the lane exists for -- the primary standing on the
# trunk is where step 2b (#1073) deliberately puts it, and `ship-pr` itself tells you to open a lane in a
# second terminal. So $trunkHolder is only READ here; the refusal fires below, gated on -not $queueActive,
# the same shape and the same one-line justification #1506 already established for the fold-push verdict.
$shipTreeIsPrimary = $true
$trunkHolder = $null
$wtList = Invoke-NativeCapture -FilePath 'git' -Arguments @('worktree', 'list', '--porcelain')
if ($wtList.ExitCode -eq 0) {
    $primaryRoot = Get-PrimaryWorktreePath -PorcelainLines $wtList.Output
    if ($primaryRoot) {
        $shipTreeIsPrimary = (Get-WorktreePathKey $primaryRoot) -eq (Get-WorktreePathKey $repoRoot)
    }
    $trunkHolder = Get-WorktreeHoldingBranch -PorcelainLines $wtList.Output -Branch 'main' -SelfPath $repoRoot
} else {
    # BEST-EFFORT, never a refusal: an unreadable worktree list says something about git, not about the
    # trunk, and this script has to keep working in a clone that has never had a second worktree.
    Write-Warning "could not read 'git worktree list' -- shipping anyway; step 5 will report it if 'main' turns out to be held elsewhere."
}

# --- Step 0b: CAN THIS ACCOUNT PUSH THE FOLD AT ALL? (issue #1278) -------------------------------
# THE SIBLING OF THE CHECK ABOVE, and the same half-state by a different route. Step 0a asks whether
# step 5 can CHECK OUT the trunk; this asks whether step 5 can PUSH to it. Measured on PR #1271,
# September 3, 2026: ship-pr merged, checked out main, folded, committed -- and the push was refused
# with GH013 ("Required status check 'lint-en-tests' is expected"). The run ended merged-but-unfolded,
# which is the one state nothing reports until a release trips over it.
#
# WHY IT CANNOT BE READ OFF THE MERGE. The merge satisfies a required status check (the PR's own check
# ran); the fold cannot (a pushed commit has no checks). So an account can be fully entitled to merge
# and not entitled to fold, and step 3's CI verdict says nothing at all about step 5. The two facts
# that decide it are readable here for two gh calls: which rules apply to the trunk, and this account's
# bypass on the ruleset carrying them.
#
# ASKED HERE FOR STEP 0a'S REASON, in the same words: this is the last moment at which refusing costs
# nothing -- no gate has run, nothing is pushed, no PR exists and nothing is merged. Local first,
# network second, so the free check still runs even when this one cannot.
#
# AND IT REFUSES ONLY ON A READ IT ACTUALLY MADE. An unreadable ruleset warns and ships, exactly as the
# unreadable worktree list above does: the fold is redoable by hand or from an account with bypass,
# while refusing on an unread ruleset would take ship-pr away from every consumer whose token cannot
# read one. The verdict itself is Get-FoldPushVerdict's, and tested there.
$foldRulesJson = ''
$foldBypass = @{}
$foldNames = @{}
try {
    # -DiscardStderr because this output is PARSED: a gh warning merged into it would break the
    # ConvertFrom-Json and cost the check. Same reasoning as the run-facts read at step 3.
    $rulesRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @(
        'api', "repos/$repo/rules/branches/main")
    if ($rulesRead.ExitCode -eq 0) {
        $foldRulesJson = $rulesRead.Output -join "`n"
        # One detail read per ruleset that carries a blocking rule -- normally one, and none at all in a
        # repo whose trunk has no such rule. `current_user_can_bypass` lives ONLY on the detail endpoint:
        # the list endpoint returns it as null, so it cannot be had in a single call.
        foreach ($rec in (Get-DirectPushBlockingRules -BranchRulesJson $foldRulesJson).Blocking) {
            if (-not $rec.RulesetId) { continue }
            # An ORGANIZATION ruleset is not under repos/<repo>/rulesets, and asking for it there 404s.
            # Both endpoints answer with the same two fields, so only the path differs.
            $rulesetPath = if ($rec.SourceType -eq 'Organization' -and $rec.Source) {
                "orgs/$($rec.Source)/rulesets/$($rec.RulesetId)"
            } else {
                "repos/$repo/rulesets/$($rec.RulesetId)"
            }
            $detail = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @('api', $rulesetPath)
            if ($detail.ExitCode -ne 0) { continue }
            try {
                $parsedDetail = ($detail.Output -join "`n") | ConvertFrom-Json
                if ($parsedDetail.PSObject.Properties['current_user_can_bypass']) {
                    $foldBypass[$rec.RulesetId] = [string]$parsedDetail.current_user_can_bypass
                }
                if ($parsedDetail.PSObject.Properties['name']) {
                    $foldNames[$rec.RulesetId] = [string]$parsedDetail.name
                }
            } catch {
                # Left out of the map on purpose: an unparseable detail is the UNKNOWN case for that
                # ruleset alone, and the verdict warns on it rather than guessing either way.
            }
        }
    }
} catch {
    $foldRulesJson = ''
}

# IS THE TRUNK BEHIND A MERGE QUEUE? (issue #1506) -- READ HERE, BECAUSE IT DECIDES WHO FOLDS.
# It costs no extra gh call: the payload is the one step 0b just fetched. Under a queue `gh pr merge`
# ENQUEUES and exits 0, GitHub merges the PR minutes later on a gh-readonly-queue/** branch, and the
# push that merge produces is what runs fold-on-merge.yml (#1493). So this session never folds, and the
# two questions below turn on that: step 0b must not refuse a fold this run will not push, and step 4
# must read "not MERGED" as success rather than as the #1325 half-state.
#
# READABLE BEFORE ACTIVE, deliberately. An unreadable payload is not "no queue" -- collapsing the two
# would send a run down the direct-merge path on a trunk that has one, which is exactly the fold-ahead-
# of-its-own-merge state #1325 exists to prevent. Unreadable therefore keeps the OLD behaviour in full:
# step 0b still asks its question and step 4 still refuses, which is the safe direction on both.
$queueVerdict = Get-MergeQueueVerdict -BranchRulesJson $foldRulesJson
$queueActive = ($queueVerdict.Readable -and $queueVerdict.Active)
if ($queueActive) {
    Write-Host "ship-pr: 'main' is behind a merge queue -- this run will ENQUEUE the PR, and the queue merges it." -ForegroundColor Cyan
    Write-Host "  The fold is not this session's to push: fold-on-merge.yml folds off the queue's own push to main (#1493)." -ForegroundColor DarkGray
}

# --- Step 0a's refusal, deferred to here (issue #1572) ------------------------------------------
# Step 0a above only READ whether another worktree holds 'main'. The refusal belongs after the queue
# verdict, because its whole ground -- "step 5 could not fold after the merge" -- does not hold under a
# queue: this session never folds there, so a primary standing on the trunk (where step 2b put it,
# #1073) blocks nothing. Where no queue is read, $queueActive is $false and the guard fires exactly as
# it always did -- unreadable keeps meaning "assume the session folds", the safe direction #1506 insists
# on. The two remedies below cost something a queue makes unnecessary, which is the point of the gate.
if ($trunkHolder -and -not $queueActive) {
    Write-Error @"
'main' is checked out in ANOTHER worktree, so step 5 could not fold after the merge:

  $trunkHolder

Nothing has been pushed or merged -- this is the cheap place to stop. Release the trunk there first,
then run ship-pr again. If that worktree is a finished lane, hand it back:

  powershell -NoProfile -File "scripts\task\worktree-lane.ps1" -HandBack -Lane "$trunkHolder"

If it is a checkout you still want, move it off the trunk yourself (git -C "$trunkHolder" checkout <its branch>).
"@
    exit 1
}
if ($trunkHolder -and $queueActive) {
    Write-Host "  Another worktree holds 'main' ($trunkHolder) -- not a blocker under a queue: step 5 folds nothing here (#1572)." -ForegroundColor DarkGray
}

# AND UNDER A QUEUE THE FOLD-PUSH VERDICT IS NOT THIS RUN'S QUESTION (issue #1506). Step 0b asks whether
# THIS ACCOUNT can push the fold; with a queue the pusher is the GitHub Actions app running
# fold-on-merge.yml, whose entitlement is a different actor's and cannot be read from `gh api user`.
# Refusing here on this account's bypass would stop a ship that was never going to make that push --
# and it would refuse EVERY ship, since a merge_queue rule blocks direct pushes by definition. The
# verdict is still computed rather than skipped, so it stays a pure function of the payload and the
# tests below can read it either way; only its two consequences are gated.

$foldVerdict = Get-FoldPushVerdict -BranchRulesJson $foldRulesJson -BypassByRulesetId $foldBypass -NameByRulesetId $foldNames
if (-not $queueActive -and $foldVerdict.Blocked) {
    # WHOSE ACCOUNT, said out loud. The verdict knows only "this account", and the whole repair is that
    # a run from the wrong account stops here -- so naming it is what turns the refusal into an action.
    # Best-effort, like every diagnostic on a refusal path: a read that fails costs the name, not the
    # refusal.
    $who = ''
    try {
        $me = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @('api', 'user', '--jq', '.login')
        if ($me.ExitCode -eq 0) { $who = ($me.Output -join '').Trim() }
    } catch { $who = '' }
    $whoLine = if ($who) { " The account is '$who'." } else { '' }

    Write-Error @"
The FOLD could not be pushed to 'main' after the merge, so ship-pr stops BEFORE merging (issue #1278):

  $($foldVerdict.Reason)$whoLine

The fold is a direct push by design -- one of the three named exceptions to "never commit directly on
main" -- and a rule like this one cannot be satisfied by a direct push: the pushed commit carries no
checks, so GitHub refuses the ref update before any workflow could run. Merging first would leave the
trunk merged-but-unfolded, which is the state nothing reports until a release trips over it.

Nothing has been pushed, opened or merged -- this is the cheap place to stop.

Two remedies, and this script takes neither:
  - give this account bypass on that ruleset (repo settings, so it is the repo owner's call), or
  - ship this branch from an account that already has it.
"@
    exit 1
}
if (-not $queueActive -and $foldVerdict.Unknown) {
    Write-Warning "could not decide whether the fold can be pushed to 'main' -- $($foldVerdict.Reason)"
}

# --- Step 1: open the PR (open-pr.ps1 runs the lint + test gate, pushes, opens) ------------------
# -Title is forwarded ONLY when one was given (#506): passing an empty string would make open-pr warn
# about an ignored title on every ordinary run, which is how a warning stops being read.
$openArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'open-pr.ps1'))
if ($Title) { $openArgs += @('-Title', $Title) }
if ($SkipLint)    { $openArgs += '-SkipLint' }
if ($SkipTests)   { $openArgs += '-SkipTests' }
# FORWARDED ONLY WHEN NON-ZERO, for the same reason -Title is (#506, and now #1443): open-pr's own
# default IS 0, so passing it explicitly would be a no-op that puts a lane count on the command line of
# every ordinary run -- and a reader of that line would take it for a deliberate choice.
if ($MaxParallel -gt 0) { $openArgs += @('-MaxParallel', "$MaxParallel") }
if ($Force)       { $openArgs += '-Force' }
if ($RefreshBody) { $openArgs += '-RefreshBody' }
# Handed over as the raw string. open-pr.ps1 parses it itself precisely BECAUSE this hop goes through
# `powershell -File`, where an [int[]] parameter would silently collapse '331,332' into 331332.
if ($Resolves) { $openArgs += @('-Resolves', $Resolves) }
if ($NoResolves) { $openArgs += '-NoResolves' }
Write-Host "ship-pr: opening the PR..." -ForegroundColor Cyan
# ONE CHAIN, ONE RECEIPT (issue #1884). open-pr.ps1 is a chain ENDING when somebody runs it, and a link
# in the middle when this script runs it -- so the conductor claims the receipt and the child says
# nothing. Without this an ordinary ship printed the reminder here, before CI had even started.
if (Test-FunctionDefined 'Push-CloseOutSuppression') { Push-CloseOutSuppression }
try { & powershell @openArgs } finally { if (Test-FunctionDefined 'Pop-CloseOutSuppression') { Pop-CloseOutSuppression } }
if ($LASTEXITCODE -ne 0) { Write-Error "open-pr failed -- ship-pr stops (nothing merged)."; exit 1 }

if ($NoMerge) {
    Write-Host "ship-pr: -NoMerge set -- PR opened, stopping before the CI wait/merge/fold." -ForegroundColor Green
    exit 0
}

# --- Step 2: find the PR number for this branch --------------------------------------------------
# Parsed by Get-ExistingPrRecord (pr-issues-lib), the same tested function step 1 uses, because THIS
# STEP WAS IN THE 5.1 PITFALL ITSELF -- measured August 4, 2026 while making step 1 resumable:
#
#   $prs = @($prList.Output | ConvertFrom-Json)   # $prs.Count is ALWAYS 1, even for '[]'
#   $pr  = $prs[0].number                         # $prs[0] is the whole Object[], not a record
#
# `@(<text> | ConvertFrom-Json)` collects the parsed array as ONE pipeline element, so the count guard
# below could never fire -- it was dead code -- and `.number` on that element worked only by member
# enumeration. With no open PR that yields the EMPTY STRING rather than nothing, and the script then
# ran `gh pr checks ''` and `gh pr merge ''`. Nothing in the output would have said which PR was being
# merged, in the one script that writes to main. Now: $null means no PR, and the guard is real.
#
# --base main for the reason spelled out in open-pr.ps1's lookup: without it a consumer's stacked PR
# (branch -> branch) could be the one that gets merged, into its intermediate base.
$prList = Invoke-NativeCapture -FilePath 'gh' -Arguments @('pr', 'list', '--head', $branch, '--base', 'main', '--state', 'open', '--json', 'number', '--limit', '1', '--repo', $repo) -DiscardStderr
if ($prList.ExitCode -ne 0) { Write-Error "Could not list the PR for '$branchShown' (is gh logged in?)."; exit 1 }
$prRecord = Get-ExistingPrRecord -Json ($prList.Output -join "`n")
if ($null -eq $prRecord) {
    # NO OPEN PR IS TWO DIFFERENT ANSWERS, and until inbound #1077 this line gave the alarming one to
    # both. A branch whose PR is MERGED reaches here as "none" -- open-pr says so and exits 0 -- and
    # stopping on it is right, while reporting it as a failure is not: nothing is wrong, the work has
    # landed, and the run's only news is good. Asked here as well as in open-pr because both scripts are
    # runnable on their own; a query that fails leaves the old message, which is then the true one.
    $mergedList = Invoke-NativeCapture -FilePath 'gh' -Arguments @('pr', 'list', '--head', $branch, '--base', 'main', '--state', 'merged', '--json', 'number,url', '--limit', '1', '--repo', $repo) -DiscardStderr
    $mergedRecord = if ($mergedList.ExitCode -eq 0) { Get-ExistingPrRecord -Json ($mergedList.Output -join "`n") } else { $null }
    if ($mergedRecord) {
        Write-Host "ship-pr: PR #$($mergedRecord.number) for '$branchShown' is already merged -- nothing to ship. $($mergedRecord.url)" -ForegroundColor Green
        Write-Host "ship-pr: this checkout is still on '$branchShown' -- the merge deleted the remote branch, not the local one. 'git checkout main' (or prune-merged) clears it up." -ForegroundColor DarkGray
        exit 0
    }
    Write-Error "No open PR to main found for '$branchShown' after open-pr -- stopping."
    exit 1
}
$pr = $prRecord.number
Write-Host "ship-pr: PR #$pr opened for '$branchShown'." -ForegroundColor Green

# --- Step 2b: give the trunk back BEFORE the wait (issue #1073) -----------------------------------
# THE RULE THIS EXISTS FOR IS NOT IN A SCRIPT, IT IS IN THE ORCHESTRATOR'S BODY, and it said two things
# that a backgrounded ship could not both satisfy. "Parking is a state, not a promise to come back
# within the turn" makes an in-flight ship a FINISHED assignment; "it ends on the trunk, which is what
# makes the session safe to clear" makes a checkout still standing on the branch an unfinished one. A
# parked branch composes them (push, checkout, stop). A backgrounded ship could not: HEAD did not move
# until step 5, after the CI wait, so at the moment the close-out was written the tree was necessarily
# still on the branch. Dave, August 29, 2026, after being handed a session he could not act on: "ik wil
# pas een sessie sluiten als ik terug op de main branch ben."
#
# THE FIX IS THREE LINES BECAUSE TWO EARLIER ONES DID THE WORK. Since #970 both merge gates read
# refs/heads/<branch> instead of the working copy, and since #972 step 5 reads HEAD before it moves
# anything. Read together they say something neither one set out to: NOTHING BELOW THIS POINT READS THE
# CONTENT OF THE WORKING TREE. Step 3 is gh over the network, step 4 is the ref plus gh, step 5 folds
# wherever HEAD already is -- and 'main' is one of the two arms it has always had. So the trunk can be
# handed back here, and step 5 then takes that arm on purpose rather than by luck.
#
# WHY HERE AND NOT ONE LINE EARLIER: the PR must exist first. If step 1 or step 2 fails, the session is
# left on its branch with the work in front of it, which is where a repair happens. Moving HEAD before
# there is anything to come back to would be trading a real state for a tidy one.
#
# THE THREE CONDITIONS ARE IN Get-TrunkReturnDecision, tested, and its header carries what each one
# costs if skipped. What is decided HERE is only what to do with the answer, and the answer is never a
# refusal: no gate has been failed, and a tree that cannot go home is a tree that stays where it is.
# THE REASON IS PRINTED EITHER WAY -- a session told "still on the branch" has to know whether that was
# a decision or a failure, and the difference is exactly what the reader cannot see from HEAD alone.
$statusRead = Invoke-NativeCapture -FilePath 'git' -Arguments @('status', '--porcelain')
$statusLines = if ($statusRead.ExitCode -eq 0) { @($statusRead.Output) } else { @('?? <unreadable>') }
$wtNow = Invoke-NativeCapture -FilePath 'git' -Arguments @('worktree', 'list', '--porcelain')
$trunkReturn = if ($wtNow.ExitCode -eq 0) {
    Get-TrunkReturnDecision -PorcelainLines $wtNow.Output -SelfPath $repoRoot -TrunkBranch 'main' -StatusLines $statusLines
} else {
    # SAME BEST-EFFORT POSTURE AS STEP 0, and for the same reason: an unreadable worktree list says
    # something about git, not about the trunk. The safe default here is the behaviour every run had
    # before this step existed -- stay on the branch and let step 5 decide.
    [pscustomobject]@{ Return = $false; Reason = "'git worktree list' could not be read" }
}
# WHAT STEP 2B ACTUALLY DID, recorded rather than assumed (issue #1616). Step 3's go-ahead line used to
# assert this outcome as a literal, which made it false on every run where either arm below declined --
# and that line is the one a reader acts on. The answer is only knowable HERE, so it is kept HERE: the
# checkout is the last thing in the run that moves HEAD before the wait.
$treeOnTrunk = $false
if ($trunkReturn.Return) {
    $back = Invoke-NativeCapture -FilePath 'git' -Arguments @('checkout', 'main')
    if ($back.ExitCode -eq 0) {
        # NOT FAST-FORWARDED HERE, DELIBERATELY. Step 5 fetches and does an explicit ff-only merge of
        # origin/main after the merge lands, which is when there is something to fast-forward TO. Doing
        # it twice would only widen the window in which this tree is ahead of what the PR merged into.
        $treeOnTrunk = $true
        Write-Host "ship-pr: this checkout is back on 'main' -- the ship runs on PR #$pr from here." -ForegroundColor Green
    } else {
        # NOT FATAL: nothing is merged, the branch is pushed, and step 5 reads HEAD for itself. The one
        # thing that would be wrong is stopping a ship over a checkout that was a convenience.
        $back.Output | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
        Write-Host "ship-pr: could not check out 'main' -- staying on '$branchShown'; step 5 will fold from here as before." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "ship-pr: staying on '$branchShown' -- $($trunkReturn.Reason)." -ForegroundColor DarkGray
}

function Get-MissingCheckSuiteRefusalNote {
    <#
    .SYNOPSIS
        The best-effort #1234 / #1247 diagnostic sentence for a PR whose CI check never registered --
        '' when nothing can be read, so a diagnostic is never the reason a refusal cannot be printed.

    .DESCRIPTION
        Lifted out of Wait-CheckRegistration's post-timeout branch (issue #1584) so the early
        CONFLICTING short-circuit can word its refusal from the SAME builder rather than reimplement
        the sha + check-suites + mergeable reads. Every read is guarded; any failure degrades to ''
        and the caller falls back to the wording that was already there.

        THE SHA IS READ LOCALLY, for the reason step 4's DEPLOY lock gives for the same read: step 1's
        open-pr.ps1 pushed $Branch before this point on every path through here, so refs/heads/<branch>
        IS the PR's head commit, and a gh headRefOid read would say the same thing over the network in
        a diagnostic that must not need a live token to word a refusal.

    .PARAMETER Mergeable
        Passed straight to Get-MissingCheckSuiteNote when the caller has already read GitHub's
        mergeable state (the early exit has); '' means read it here, which is the post-timeout path.
    #>
    param(
        [Parameter(Mandatory)][string]$Pr,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Branch,
        [string]$Mergeable = ''
    )
    try {
        $shaRead = Invoke-NativeCapture -FilePath 'git' -DiscardStderr -Arguments @('rev-parse', "refs/heads/$Branch")
        $sha = if ($shaRead.ExitCode -eq 0) { ($shaRead.Output -join '').Trim() } else { '' }
        if (-not $sha) { return '' }
        # -DiscardStderr because this output is PARSED: a gh warning merged into it would break the
        # parse and cost the note. Nothing here reads anything but an app slug, all ASCII, so the
        # console code page cannot change the answer and -Utf8 would buy nothing.
        $suiteFacts = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @(
            'api', "repos/$Repo/commits/$sha/check-suites")
        if ($suiteFacts.ExitCode -ne 0) { return '' }
        # THE ONE CAUSE THAT IS CHECKABLE RATHER THAN GUESSED (#1247). A conflicting PR has no
        # refs/pull/<n>/merge for a pull_request workflow to run against, so GitHub creates no suite
        # for it -- ever, and neither a reopen nor a fresh head changes that. Read here only when the
        # caller has not already; guarded on its own so a failure still leaves the #1234 wording intact.
        $mergeable = $Mergeable
        if (-not $mergeable) {
            try {
                $mergeRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @(
                    'pr', 'view', "$Pr", '--repo', $Repo, '--json', 'mergeable', '--jq', '.mergeable')
                if ($mergeRead.ExitCode -eq 0) { $mergeable = ($mergeRead.Output -join '').Trim() }
            } catch {
                $mergeable = ''
            }
        }
        return Get-MissingCheckSuiteNote -SuitesJson ($suiteFacts.Output -join "`n") -PrNumber "$Pr" -Mergeable $mergeable
    } catch {
        return ''
    }
}

function Test-BranchEntryAlreadyFolded {
    <#
    .SYNOPSIS
        $true when 'main' carries a commit that DELETED this branch's own dkj-policy/<slug>.md -- the
        signature of an entry that has already folded (issue #1584). $false on any doubt.

    .DESCRIPTION
        A second PR on a branch whose entry has folded is a permanent delete/modify conflict against
        the trunk: the fold's own deletion on one side, the branch's still-modified document on the
        other. Reachable with no concurrency at all -- a UI or queue merge the shipping session never
        observed, then one more commit on the branch.

        Local reads only, and the safe direction is the only direction: a stale origin/main simply has
        not seen the fold yet, so the delete-search comes back empty and the caller falls back to the
        generic conflict wording. It never reports a fold that did not happen. The plain "file on HEAD
        but not on main" test is NOT usable here -- new-branch writes the document on the branch and
        never on main, so that test is true for every healthy first PR too; only a DELETE commit in
        the trunk's history distinguishes a folded branch from a fresh one.
    #>
    param([Parameter(Mandatory)][string]$Branch)
    try {
        $doc = "dkj-policy/$($Branch -replace '/', '-').md"
        $onHead = (Invoke-NativeCapture -FilePath 'git' -DiscardStderr -Arguments @('cat-file', '-e', "HEAD:$doc")).ExitCode -eq 0
        if (-not $onHead) { return $false }
        $delLog = Invoke-NativeCapture -FilePath 'git' -DiscardStderr -Arguments @(
            'log', 'refs/remotes/origin/main', '--diff-filter=D', '--format=%H', '-n', '1', '--', $doc)
        return ($delLog.ExitCode -eq 0) -and [bool](($delLog.Output -join '').Trim())
    } catch {
        return $false
    }
}

function Write-FailedCheckReasons {
    <#
    .SYNOPSIS
        Print what each FAILING check said about ITSELF -- the #1103 relay -- for a `gh pr checks
        --json ... link` payload. Prints nothing when nothing failed, nothing carries a job, or no
        annotation was authored.

    .DESCRIPTION
        ONE COPY, TWO CALLERS, SHARED AT ISSUE #1602. This loop was written once at step 3, for the
        path where the merge proceeds past a red check the ruleset does not require. #1602 gave that
        same path a second home at step 8 -- the non-required checks are now reported after the fold
        -- and a second copy of a loop that makes network calls and swallows its own exceptions is
        the kind of duplication that drifts silently: the two would diverge on the next measurement
        and nothing would say which one a given ship had used.

        WHY IT IS SCRIPT-LOCAL AND NOT IN THE LIB. It makes gh calls, so no suite can reach it --
        the same line every verdict in pr-issues-lib.ps1 is drawn on, from the other side. What IS
        testable already lives there: Get-FailedCheckRunRefs selects the records, and
        Get-AuthoredFailureNote words the sentence. Only the calling around them is here, beside
        Wait-CheckRegistration, which is script-local for the identical reason.

        BEST-EFFORT BY CONSTRUCTION. Every read is guarded and a failure costs these lines and
        nothing else. A check whose link names no job is skipped: there is nothing to ask
        annotations of. A diagnostic must never be the reason the sentence beside it cannot print.

    .PARAMETER ChecksJson
        `gh pr checks <pr> --json name,bucket,state,link` output. Empty or unparseable prints nothing.

    .PARAMETER Repo
        owner/name, for the annotations endpoint.

    .PARAMETER OnlyNames
        Restrict the relay to these check names. EMPTY MEANS NO FILTER, and the two callers differ
        here on purpose. Step 3 passes the verdict's FailedOther, because a red REQUIRED check there
        is a refusal whose reason the operator has already met first-hand from the local gate -- and
        relaying it would explain a failure the run is not proceeding past. Step 8 runs after the
        merge, where every required check has already concluded green, so there is nothing for a
        filter to exclude and it passes what the verdict gives it or nothing at all.
    #>
    param(
        [string]$ChecksJson,
        [string]$Repo,
        [string[]]$OnlyNames = @()
    )

    $spoken = @()
    try {
        $filter = @($OnlyNames | Where-Object { $_ -and ([string]$_).Trim() })
        foreach ($ref in @(Get-FailedCheckRunRefs -ChecksJson $ChecksJson)) {
            if (-not $ref.JobId) { continue }
            if ($filter.Count -gt 0 -and $filter -notcontains $ref.Name) { continue }
            # -DiscardStderr because this output is PARSED, the same reason every other parsed read
            # in this file carries it.
            $ann = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @(
                'api', "repos/$Repo/check-runs/$($ref.JobId)/annotations")
            if ($ann.ExitCode -ne 0) { continue }
            $note = Get-AuthoredFailureNote -AnnotationsJson ($ann.Output -join "`n") -CheckName $ref.Name
            if ($note) { $spoken += $note }
        }
    } catch {
        $spoken = @()
    }
    foreach ($note in $spoken) { Write-Host "  $note" -ForegroundColor Yellow }
}

function Wait-CheckRegistration {
    <#
    .SYNOPSIS
        Poll `gh pr checks <pr>` until at least one check is registered, then return the seconds
        waited. Refuse (exit 1) if none registers within the budget.

    .DESCRIPTION
        Step 3's registration wait, lifted into a function so the watch loop below can RE-ENTER it
        (issue #1350). `gh pr checks --watch` can start before GitHub has created the Actions check
        suite: it then prints `no checks reported` in its own output and exits non-zero -- an exit
        that CLAIMS a check failed when none has. Observed on PR #1348 (September 3, 2026), seconds
        after open-pr pushed a new head onto a busy Actions queue: the plain probe here had just
        broken out on the pushed-over head's stale suites, and the watch, the next call in the file,
        found the new head bare. `no checks reported` means the same thing from either call -- nothing
        is registered -- so both go through this one wait, and the #1234 / #1247 timeout diagnostic
        is written once rather than duplicated at the watch site.

        THE MERGE DECISION IS UNTOUCHED, for the same reason every sibling of this note gives: this
        cannot let a merge through, it only decides that "nothing has registered yet" is answered by
        the wait and not by the merge verdict further down the file.

    .PARAMETER AlreadyWaited
        Seconds a previous call (the initial probe) has already spent, so the 180s budget is shared
        across the probe and any watch fallback rather than restarting from zero on the fallback.
    .PARAMETER RequiredNames
        The checks the ruleset requires, when step 3's watch is narrowed to them (issue #1602). Given
        any, this waits for a REQUIRED check to register rather than for any check at all -- and that
        distinction is the whole reason the parameter exists.

        MEASURED ON PR #1614, the second live ship of #1602's own change. This wait polls
        `gh pr checks`, which is satisfied by ANY registered check -- and `branch-entry` and
        `claude-review` are separate workflows that register before ci.yml's jobs do. So it returned
        happy, and the narrowed watch that followed found no required check to watch:

            gh pr checks 1614 --watch --required
            no required checks reported on the '...' branch      <- exit non-zero, immediately

        `--watch --required` does NOT wait for a required check to appear. It reports that none is
        registered and exits, which the loop below then had to classify -- and its #1350 branch matched
        only the wording `no checks reported`, so this arrived as a DROPPED WATCH instead: three
        attempts, then a refusal saying CI was still running. Nothing was wrong with CI, and nothing
        was wrong with the branch.

        So the two halves are repaired together: this waits for the right thing, and the loop's #1350
        match now reads both of gh's wordings. Empty (the fall-back and the no-ruleset cases) leaves
        this byte-for-byte the wait every ship made before #1602.
    #>
    param(
        [Parameter(Mandatory)][string]$Pr,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Branch,
        [int]$PollSeconds = 15,
        [int]$MaxWaitSec = 180,
        [int]$AlreadyWaited = 0,
        [string[]]$RequiredNames = @()
    )
    $waited = $AlreadyWaited

    # EARLY EXIT ON A CONFLICTING PR -- issue #1584. #1247 taught the timeout refusal below that a
    # CONFLICTING PR has no refs/pull/<n>/merge for a pull_request workflow to run against, so GitHub
    # creates no check suite for it -- ever. That branch was only ever reached AFTER the full 180s
    # wait, so every conflicting ship still paid 180s for a state GitHub reports the instant the PR
    # exists (measured on PR #1582: 180s waited, then #1234's remedy, which cannot work here). Read it
    # up front: a definitive CONFLICTING refuses now, with the same wording the timeout would have
    # used. Anything else -- MERGEABLE, or UNKNOWN while GitHub is still computing -- falls through to
    # the ordinary wait, which still catches a conflict that only resolves later. Best-effort: a gh
    # read that fails leaves $mergeNow empty and changes nothing.
    $mergeNow = ''
    try {
        $mergeNowRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @(
            'pr', 'view', "$Pr", '--repo', $Repo, '--json', 'mergeable', '--jq', '.mergeable')
        if ($mergeNowRead.ExitCode -eq 0) { $mergeNow = ($mergeNowRead.Output -join '').Trim() }
    } catch {
        $mergeNow = ''
    }
    if ($mergeNow.ToUpperInvariant() -eq 'CONFLICTING') {
        $conflictNote = Get-MissingCheckSuiteRefusalNote -Pr "$Pr" -Repo $Repo -Branch $Branch -Mergeable 'CONFLICTING'
        if (-not $conflictNote) {
            # The suite-list read failed, so the shared builder returned nothing -- but CONFLICTING is
            # already known, so the mechanism half of its sentence can still be stated on its own.
            $conflictNote = "GitHub reports this PR as CONFLICTING, and a pull_request workflow runs against the merge commit (refs/pull/<n>/merge) that a conflicting PR has none of -- so no check suite can be created for it at all. Resolve the conflict (merge 'main' in, or rebase) and the ordinary push creates it. A close/reopen does NOT repair this and was measured doing nothing (#1247)."
        }
        if (Test-BranchEntryAlreadyFolded -Branch $Branch) {
            # THE PATH IS BUILT FROM THE BRANCH, so it is prose carrying a ref name and is stripped like
            # any other (issue #1623). Test-BranchEntryAlreadyFolded above composes the same path to READ
            # the file and is deliberately left raw: a strip there would look for a file that does not
            # exist. The two spellings differ only for a name no repo should have, and only in the
            # direction that makes the printed one readable.
            $conflictNote += " AND THIS BRANCH IS SPENT: its changelog entry ($(Get-DisplayRef -Ref ("dkj-policy/$($Branch -replace '/', '-').md"))) has already folded on 'main', so the conflict is the fold's deletion against this branch's own copy -- resolving it just re-adds a folded entry. Put the follow-up work on a fresh branch off 'main' (#1584)."
        }
        Write-Error "No CI check will register for PR #$Pr -- NOT merged (CONFLICTING). $conflictNote"
        exit 1
    }

    # WAIT FOR THE THING THE WATCH WILL WATCH, not for anything at all (issue #1602). With names given
    # this waits until every REQUIRED check has registered, because that is what the narrowed watch
    # will block on -- a repo whose fast advisory workflows register first no longer satisfies it.
    $waitNarrowed = @($RequiredNames | Where-Object { $_ -and ([string]$_).Trim() }).Count -gt 0
    $wanted = @($RequiredNames | Where-Object { $_ -and ([string]$_).Trim() } | ForEach-Object { ([string]$_).Trim() })
    $subject = if ($waitNarrowed) { 'required check' } else { 'check' }

    # THE NARROWED PROBE READS THE FULL PAYLOAD, NOT `--required`, AND THAT IS ABOUT LEGIBILITY RATHER
    # THAN CORRECTNESS. `--required` answers the question in one flag, and the first build used it --
    # but a required aggregator registers only once the jobs it needs have finished, so on this repo
    # that is a SEVEN MINUTE wait during which `--required` can say nothing except "not yet". gh's live
    # table used to run underneath the old watch, and replacing it with a blind counter would
    # re-create the exact defect #831 was filed about: an invisible wait, which is how two anecdotes
    # became a policy question nobody could check. So the probe asks for every check and decides the
    # narrowed question itself, at the same one call per poll, and can then say what IS happening.
    $probeArgs = @('pr', 'checks', "$Pr", '--repo', $Repo)
    if ($waitNarrowed) { $probeArgs += @('--json', 'name,bucket,state') }
    while ($true) {
        $probe = Invoke-NativeCapture -FilePath 'gh' -Arguments $probeArgs

        if ($waitNarrowed) {
            # PRESENCE, NOT OUTCOME. A registered required check is enough for the watch to block on;
            # whether it passed is the watch's question and then the verdict's, not this wait's. ALL of
            # them rather than any: with two required checks, watching while one is still unregistered
            # is the #1549 hole this wait exists to keep the watch out of.
            $seen = @()
            $reported = 0
            try {
                # Assign first, wrap second -- the 5.1 rule every parse in this tree follows.
                $probeParsed = ($probe.Output -join "`n") | ConvertFrom-Json
                $probeRecords = @(@($probeParsed) | Where-Object { $_ -and $_.name })
                $reported = $probeRecords.Count
                $seen = @($probeRecords | ForEach-Object { ([string]$_.name).Trim() })
            } catch {
                # An unparseable payload is "not yet", never "registered". gh prints
                # `no checks reported` as TEXT even under --json, so this arm is the ordinary early
                # state rather than an error, and treating it as registered would hand the watch
                # nothing to block on -- the failure this wait exists to prevent.
                $seen = @()
                $reported = 0
            }
            $missing = @($wanted | Where-Object { $seen -notcontains $_ })
            if ($missing.Count -eq 0) { return $waited }
        } elseif (($probe.Output | Out-String) -notmatch 'no (required )?checks reported') {
            # BOTH OF GH'S WORDINGS. `--required` says `no required checks reported`, the plain call
            # says `no checks reported`, and matching only the second is what cost PR #1614 three watch
            # attempts and a refusal about a CI run that was perfectly healthy. Kept on this arm even
            # though the narrowed one no longer passes `--required`, because the re-entry from the watch
            # loop reaches here with whatever the watch itself printed.
            return $waited
        }
        if ($waited -ge $MaxWaitSec) {
            # WHICH REFUSAL THIS IS -- issue #1234, and the same move #1044 and #1219 made one step later in
            # this file. The refusal is unchanged and cannot let a merge through; only the sentence beside it
            # moves. "Check the workflow" claims the repo's YAML is wrong, and the state that most often
            # produces this has healthy workflows -- GitHub simply created no Actions check suite for the
            # commit. Reading the suite list separates the two, and only the second is about the workflow.
            # The read itself is Get-MissingCheckSuiteRefusalNote (above), shared with #1584's early exit;
            # best-effort by construction, so any failure degrades to the wording that was already here.
            # AND THE NARROWED TIMEOUT IS A DIFFERENT DIAGNOSIS (issue #1602). Reaching this with names
            # given means SOME check registered -- the caller's first wait proved that -- and the
            # required one still has not. "Check the workflow" is then the wrong sentence: the likely
            # causes are a required context the ruleset names but no workflow produces (a rename, a
            # typo), or a job whose own dependencies never completed. Get-MissingCheckSuiteRefusalNote
            # is not asked either, since its subject is "no check suite at all", which is already
            # ruled out here.
            if ($waitNarrowed) {
                Write-Error @"
The required check $(Format-CheckNameList -Names $RequiredNames) never registered on PR #$Pr within
${MaxWaitSec}s -- NOT merged (issue #1602).

Other checks DID register, so CI is running: what has not appeared is the check the ruleset requires.
Either the ruleset names a context no workflow of this repo produces (a rename or a typo in the
required-check name), or the job that produces it is still waiting on dependencies that have not
finished. Compare the two:

  gh api repos/$Repo/rules/branches/main --jq '[.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context]'
  gh pr checks $Pr --repo $Repo
"@
                exit 1
            }
            $suiteNote = Get-MissingCheckSuiteRefusalNote -Pr "$Pr" -Repo $Repo -Branch $Branch
            if ($suiteNote) {
                Write-Error "No CI $subject registered for PR #$Pr after ${MaxWaitSec}s -- NOT merged. $suiteNote"
            } else {
                Write-Error "No CI $subject registered for PR #$Pr after ${MaxWaitSec}s -- NOT merged. Check the workflow, or merge manually once it is green."
            }
            exit 1
        }
        # SAY WHAT IS HAPPENING, not merely that nothing is. On the narrowed arm the payload just read
        # names every check that HAS reported, so the line can carry the two facts a reader waiting
        # seven minutes actually wants: which required check is still absent, and that the rest of CI
        # is moving. That is #831's finding applied to this wait rather than only to the watch below.
        if ($waitNarrowed) {
            Write-Host "  (waiting for $(Format-CheckNameList -Names $missing) to register -- $reported check(s) have reported so far; ${waited}s/${MaxWaitSec}s)" -ForegroundColor DarkYellow
        } else {
            Write-Host "  (no $subject registered yet -- waited ${waited}s/${MaxWaitSec}s)" -ForegroundColor DarkYellow
        }
        Start-Sleep -Seconds $PollSeconds
        $waited += $PollSeconds
    }
}

# --- Step 3: wait for the required CI check ------------------------------------------------------
# The CI checks can lag a few seconds behind the push: `gh pr checks` prints "no checks reported"
# and exits 0 while none are registered yet -- indistinguishable by exit code from "all passed", so
# a bare --watch could return immediately and let the merge below run straight into a BLOCKED wall.
# First poll (on the TEXT, not the exit code) until at least one check is registered, then --watch it.
# That poll is Wait-CheckRegistration, a function so the watch loop can RE-ENTER it: `--watch` can win
# the race the poll just lost and come back saying `no checks reported` itself (#1350), and the answer
# to that is this same wait, not the merge verdict.
# Deliberately does NOT name a check: this step watches whichever checks the repo's own ruleset
# requires, so naming one here would be a claim about the consumer's CI that this script cannot keep.
# What it asks the ruleset, since inbound #1549, is whether the checks it just watched INCLUDE every
# required one -- a green `--watch` exit alone does not say so, because the watch only ever sees what
# was registered when it started. That reads the repo's own answer via `gh pr checks --required`.
#
# WHAT IT DOES SAY, once the watch is over, is which check actually held it up (#831). The wait used to
# be invisible -- the run printed gh's own table and nothing about the ordering, so learning which check
# governed meant opening the Actions page afterwards. That invisibility is how two observations, both
# out of the tail, became a policy question about whether to wait on non-required checks at all.
# Measured over n=100 paired runs in this repo, the non-required check governs 23% of the time at a
# median cost of 0s, so THE WAIT WAS LEFT EXACTLY AS IT WAS and made legible instead (Dave,
# August 24, 2026). The report still names no check of its own: the governing one is whichever finished
# last, and 'required' comes from the repo's own ruleset via `gh pr checks --required`.
#
# THAT WAIT MOVED ON SEPTEMBER 8, 2026, AND #831's FINDING IS WHY IT COULD (Dave, issue #1602). The
# merge is no longer behind the non-required checks; they are watched and reported at step 8, after
# the fold. What #831 measured is untouched and is now measured a third time -- 21.2% of 99 laps, the
# same answer -- and what #831 DECIDED is untouched too, because it decided the wait should stay
# VISIBLE, and it still is. The reason the merge could move out from behind it is that the merge was
# never behind it in the sense that matters: a red non-required check does not block this merge and
# never has (#943), so the pre-merge wait on one decided when a sentence was printed. The full
# argument, the 5.1% it buys, and why that number is 62.5% on a busy day are at the probe below.
#
# AND WHAT IT SAYS BEFORE THE WATCH IS THAT NOBODY HAS TO SIT HERE (Dave, issue #985, August 27, 2026).
# The wait is real -- 11m48s of `lint-en-tests` on PR #980, against a local run of the same suites minutes
# earlier at 292s -- and it is not buying a first look at the result, it is buying a second one. The merge
# still cannot move before the check is green, so what changes is who holds the session open, not the wait:
# background this run and the ~12 minutes cost nothing.
#
# THE LANE IS PRINTED BESIDE THE INVITATION, AND IT IS NOW ADVICE RATHER THAN A CONDITION. It was a
# condition when this was written: step 5 ran `git checkout main` in THIS tree, so a session that
# backgrounded the ship and then started the next piece of work in the same checkout had HEAD pulled out
# from under it mid-branch. Issue #972 measured that and step 5 now reads HEAD before it moves anything, so
# the hazard is gone -- what is left is the reason the lane was the right answer anyway, measured on
# August 23, 2026: the worktree is where you build, the primary checkout is where you ship. Named here
# rather than left to the docs, because this is the one moment the reader is about to need it.
#
# AND SINCE #1073 THE SECOND LINE SAYS WHERE THE TREE ALREADY IS RATHER THAN THAT IT WILL BE LEFT ALONE.
# Step 2b has just put the primary checkout back on the trunk, which is the state the orchestrator calls
# safe to clear -- so the reader who backgrounds this run is not being asked to accept a tree standing
# mid-flight, and the close-out that follows can say both things at once. Where step 2b declined, it said
# why on the line above this one; the invitation is the same either way, because the wait is somebody
# else's clock whichever branch this tree is on.
#
# A LINE AND NOT A MECHANISM, deliberately. Three shapes were on the table and this is the smallest: a
# green-and-unmerged reporter would re-add half of what #984 had deliberately removed five minutes before
# #985 was filed, and a detached watcher would merge and fold onto the trunk with nobody reading the output.
# The gates at step 4 already read refs/heads/<branch> for exactly this shape (#970), so the hand-off needed
# permission and a reminder rather than machinery -- and #972 then closed the one place that still wrote.
#
# AND IT SAYS "YOU" RATHER THAN "THE SESSION", BECAUSE THE SESSION IS EXACTLY WHAT IT DOES NEED (issue
# #1428, September 5, 2026). The line read "Nothing here needs the session" for nine days, and the
# paragraph above is why that was false the whole time: the detached watcher was DECLINED, so nothing here
# outlives the harness. Measured ancestry of a backgrounded run, Windows 11, Claude Code in a VS Code
# terminal:
#     powershell.exe <- bash.exe <- bash.exe <- bash.exe <- claude.exe <- powershell.exe <- Code.exe
# A descendant of claude.exe, killed with it. So backgrounding buys that nobody has to WATCH -- not that
# the run has been handed to something that survives you.
#
# WHICH MAKES THE FOLD THE PART WORTH NAMING, and the second line names it. A merge that never happens
# leaves the PR open and visible, so it announces itself. A merge that happens WITHOUT its fold leaves the
# branch's document stranded on the trunk with nothing saying so -- #1270's defect, reached by a route
# #1270 did not consider: not "merged from the GitHub UI" but "merged by a ship whose process was killed".
# check-unfolded-entry.ps1 reports it at the NEXT session start, so it is caught rather than silent; it is
# still a repair after the fact, which is why the invitation names the two commits instead of relying on it.
#
# WHAT IS DELIBERATELY NOT CLAIMED HERE is that clearing the context is safe while quitting is not. It
# follows from the ancestry -- the process hangs off claude.exe, not off the conversation -- but it was not
# measured, and a line telling a reader which of two things they may do has to be right about both.
#
# AND THE INVITATION NO LONGER NEEDS THAT MEASUREMENT, because the reader's real question was never "may I
# clear?" but "how do I get on with the next thing?" (Dave, September 5, 2026, on #1428). A SECOND TERMINAL
# answers it without asking anything of this process: this one stays alive, so the merge and the fold
# complete AND the completion lands in a conversation that still exists -- the vanished-notification half
# of #1428, solved rather than mitigated. Naming only what is unsafe was itself the defect: a line that
# withholds a clearance and offers nothing in its place cancels backgrounding at the one place the reader
# actually reads it, which is how "nothing here needs the session" came to BLOCK the very workflow it was
# written to enable.
#
# THE TIMING RULE IS WHY THIS LINE CARRIES IT, and it is the whole rule. Step 1 is the one step that reads
# the WORKING TREE, so this checkout is single-occupancy for its minute or more (#1145; measured on PR
# #1144, one suite of 55 red inside the gate and green standalone on the same commit seconds later).
# Everything from step 2b down reads refs and the PR instead, deliberately. So THIS line -- printed the
# moment step 1 is over, read by the reader who is about to act on it -- is the go-ahead, and no separate
# instruction has to be remembered. The lane keeps the two sessions off one HEAD entirely and is detached
# at origin/<trunk> rather than standing on it, so it does not take the trunk away from step 5's fold
# either (#1069).
#
# AND THE GO-AHEAD'S TRUNK CLAUSE IS READ FROM STEP 2B RATHER THAN ASSERTED (#1616). It was a literal for
# three days (#1428, September 5, 2026), so it was false on every run where step 2b declined to move the
# tree -- in a line whose whole job is to be acted on. Get-TrunkReturnGoAheadLine words both arms, and
# $treeOnTrunk is set where the answer is actually known.
$waitBegan = Get-Date
Write-Host "ship-pr: waiting for the CI check(s) on PR #$pr..." -ForegroundColor Cyan
Write-Host "  Nothing here needs YOU -- background this run and the wait costs nothing." -ForegroundColor DarkGray
Write-Host "  It does need this session's process: the merge and the fold are still owed, and both run from here (#1428)." -ForegroundColor DarkGray
Write-Host "  So leave this one running and carry on in a SECOND terminal -- do not quit the harness." -ForegroundColor DarkGray
Write-Host "  $(Get-TrunkReturnGoAheadLine -Returned $treeOnTrunk -Branch $branchShown)" -ForegroundColor DarkGray
Write-Host "  Open that second terminal in a lane: scripts\task\worktree-lane.ps1 -Name <name>" -ForegroundColor DarkGray
# --- THE WATCH BLOCKS ON THE REQUIRED CHECKS ONLY (issue #1602) ----------------------------------
# WHAT THIS CHANGES, AND WHAT IT DELIBERATELY DOES NOT. The merge below is allowed to go as soon as
# every check the ruleset REQUIRES is green; the non-required ones are still waited for and still
# reported, at step 8, after the fold. So #831 keeps its wait and its report and #1549 keeps its
# guard -- what moves is the moment the report is PRINTED, not whether one happens.
#
# WHY THAT IS WORTH A CHANGE AT ALL. Step 3b below refuses the merge when 'main' gained a commit
# after the certifying run was created, and the trunk goes on moving while this step waits. A commit
# that lands in the stretch between the last REQUIRED check and the last check of any kind voids a
# certificate that was valid the moment before -- and it costs a whole further CI lap on a refusal
# that is, on the gate's own terms, correct. Measured on 99 ci.yml pull_request laps,
# 2026-09-05 17:58Z .. 2026-09-08 10:51Z (issue #1602, refused laps included, which is why it is
# per-lap and not per merged PR -- a merged PR's `gh pr checks` reports only its final head):
#
#   a non-required check governed the wait                 21 of 99 (21.2%)   median tail 191s, max 753s
#   certificate voided, after #1592's fold discount        25 of 99 (25.3%)
#   voided ONLY inside that non-required tail               5 of 99  (5.1%)  <- what this removes
#   voided inside the tail AND before it                    0 of 99
#
# THE PREDICATE, BESIDE THE NUMBER (issue #1750). A rate whose window and population are unstated
# cannot be re-measured, only argued with. Population: every `ci.yml` `pull_request` run in that
# range, one row per LAP. Window per lap: [run.created_at, last_check.completed_at] -- it ends at the
# LAST CHECK OF ANY KIND, not at the required one's conclusion and not at the run's own `updated_at`,
# which is what makes the two 'tail' rows above meaningful at all. Voided = 'main' gained a
# first-parent commit inside that window; the discount is Test-IsFoldOnlyCommit itself, re-run over
# the same 99 laps with this repo's own seams and reported identical (#1602's second comment).
#
# AND THE VOIDING ROW IS UNRECONCILED, which is why the predicate is written down here rather than
# left in the thread (issue #1750). A re-measurement over the same four days scored 3 of 193 laps
# (1.6%) against this row's 25.3%. The window is the obvious suspect -- that pass ended its own at
# `run.updated_at`, inside the tail -- but THE ROWS ABOVE BOUND THE WINDOW'S SHARE AT 5: tail-only is
# 5 and tail-and-before is 0, so narrowing this window to the required check's conclusion moves 25.3%
# to 20.2% and no further. The residual sits in the DISCOUNT: this sample discounted 12 of its 37 raw
# voidings (32%), the re-measurement 39 of 42 (93%), against a trunk that ran 114 folds in 255
# first-parent commits (44.7%) over those same four days by the real classifier. Neither pass has been
# shown wrong, and the direction is identical in both -- which is all #1602's decision rests on. But a
# decision SIZED off 25.3% is being sized off the half that is still open.
#
# WHAT #1715 DID AND DID NOT MOVE, since the inference is easy and wrong. Dropping ship-pr's third
# local gate run shortens the stretch between a green certificate and the merge attempt, so it lowers
# how often this gate ACTUALLY refuses. It does not touch the rows above: those count commits inside a
# window bounded by CI's own check timestamps, and the run #1715 removed ran after the last of them.
#
# 21.2% reconfirms #831's own n=100 finding of 23% for a third time. The 5.1% is the whole benefit
# and it is small -- but all five sit on ONE day, the busiest in the sample: 5 of the 8 tail-governed
# laps that day (62.5%) lost a lap, against 0 of 13 across the three quieter days. The governing
# share and the tail length are flat across all four, so what moves is the trunk's own rate, which
# is exactly #1592's title -- two sound decisions that do not converge ON A BUSY TRUNK.
#
# AND WHAT DRIVES THE RATE IS CONCURRENCY, NOT THE TRUNK'S RATE -- which is where the paragraph above
# stops one step short (issue #1719, closed 2026-09-10 with no converger built). Re-measured over the
# 24 successful laps after #1715: 2 voided (8.3%). Neither sits in a busy stretch. They sit at 12.5
# and 28.3 minutes since the previous trunk move, while laps cut 1.6 minutes after one came through
# clean -- so "a busy trunk" predicts the wrong laps. What the two share is that ANOTHER PR WAS OPEN
# AT THE SAME TIME:
#
#   tight concurrent pairs that lost a lap        2 of 5 (#1740+#1741, #1751+#1752)
#   PRs not in such a pair that lost a lap        0 of 10
#
# The three surviving pairs were saved by ordering alone, not by margin: the second branch's
# certifying run started 7, 3 and 1.7 minutes AFTER the first branch's merge landed. With two
# branches in flight this is a coin flip decided by seconds; with one it is zero.
#
# AND MERE OVERLAP IS NOT THE PREDICATE EITHER, which is worth stating because it is the reading a
# `gh pr list` would suggest. #1733 sat open for 285 minutes and overlapped 14 of the other 19 PRs
# in the sample without voiding any of them -- it was parked, waiting for a person. What collides is
# two branches both ACTIVELY CERTIFYING, so the population to count is concurrent CI laps and not
# concurrent open PRs.
#
# SO THE CHEAP MITIGATION IS A SEQUENCING HABIT AND NOT A MECHANISM, and that is what closed #1719
# against its own ranked options (Mergify, an Actions merge train, a Cloudflare Worker broker). Ship
# one branch at a time and this gate has nothing to refuse; detect-and-rebase (#1546) handles the
# residue correctly at one extra CI lap. What would reopen it is parallel shipping becoming the norm
# -- several branches routinely in flight, or a second person shipping into this trunk -- and the
# figure to re-measure then is the CONCURRENT-PAIR rate, not the flat per-lap one.
#
# PREDICATE, since the row above insists on one: population as recorded above, one row per successful
# `ci.yml` `pull_request` lap, 2026-09-09 16:00:35Z .. 2026-09-10 07:15Z. Window per lap
# [run.created_at, run.updated_at] -- the NARROWER end, not the last check of any kind, so on the
# window this block records the rate can only be >= 8.3%. Discount: `^fold:` on the subject, which is
# coarser than Test-IsFoldOnlyCommit and is the open half of the residual noted above. n=5 pairs, so
# read the 2-of-5 as an order of magnitude rather than as 40%.
#
# THE OBJECTION THAT MADE THIS EXPENSIVE DOES NOT HOLD, and that is the finding that decided it.
# #1602 priced this as reversing #831, on the ground that #831 wants the wait to SEE a red
# non-required check. It does, and it still does -- but a red non-required check has never gated the
# merge here: the verdict below returns Blocked = $false for it and prints "a check FAILED but the
# merge is not blocked ... Continuing to step 4". So the pre-merge wait on a non-required check
# decided WHEN that sentence was printed and nothing else. Under this change the operator reads the
# same sentence at step 8 and their options are identical, because the merge was never theirs to
# stop at that point. The one thing genuinely lost is a Ctrl+C window -- and the invitation printed
# five lines above is an instruction not to be sitting in it.
#
# FAIL-OPEN, ON THE REPO'S OWN ANSWER. `gh pr checks --required` exits non-zero on a ruleset that
# requires nothing, and that is indistinguishable from "the required checks have not registered
# yet". Either way this reads an EMPTY list and watches every check, which is exactly the behaviour
# of every ship before this change -- so a consumer with no ruleset is not affected by any of it.
# The list is re-read per watch attempt below for the same reason: the required check may simply not
# have created its check run yet when this first asks, and a re-entry then finds it.
#
# WHAT IS NOT CLAIMED: that the run gets shorter. It does not -- step 8 spends the same seconds this
# step used to. What is bought is the LAP, by putting the merge on a certificate that is still
# current, and nothing here shortens CI's own 310-461s window.
# THE SOURCE IS THE RULESET, NOT THE PR'S CHECK LIST -- AND THAT WAS MEASURED ON THIS CHANGE'S OWN
# FIRST SHIP RATHER THAN REASONED ABOUT (PR #1614, September 8, 2026). This block first asked
# `gh pr checks --required`, which reports the required checks THAT HAVE REGISTERED. Seconds after
# open-pr's push it answered nothing -- `branch-entry` and `claude-review` are separate workflows and
# register faster than ci.yml's jobs -- so the run fell back to watching every check, which is the
# correct fail-open. But `--watch` picks up checks that register after it starts, so that full watch
# ran to completion, the #1549 re-entry was never reached, and the narrowing never happened at all.
#
# THE CHANGE WAS INERT ON THE FIRST LAP IT RAN, AND SAID OTHERWISE. Every later line still read
# $requiredWaitNames, which the in-loop refresh had by then filled in from the concluded checks -- so
# the run printed "every REQUIRED check is green. The rest are still watched" about a wait that had
# just watched everything. True of the ruleset, false of the wait, and that is the shape a claim takes
# when it is read off the wrong variable. $watchNarrowed below exists so nothing downstream can make
# that mistake again: it records what the watch DID, not what the ruleset says.
#
# The branch-rules payload has no such race -- it states the required contexts whether or not anything
# has registered -- and $foldRulesJson is already in hand from step 0b, so this costs no network call.
# Get-RequiredCheckContexts keeps Readable separate from empty, the same line Get-MergeQueueVerdict
# draws on the same payload: unreadable falls back to the old probe, while readable-and-empty is a
# positive answer (GitHub Free requires nothing) and watches everything.
$requiredWaitNames = @()
$requiredContexts = Get-RequiredCheckContexts -BranchRulesJson $foldRulesJson
if ($requiredContexts.Readable) {
    $requiredWaitNames = @($requiredContexts.Names)
} else {
    # THE PROBE IS THE FALL-BACK NOW, not the source. It still answers on a checkout whose token
    # cannot read the trunk's rules, and it still cannot tell "requires nothing" from "not registered
    # yet" -- which is exactly why it is second and no longer first.
    $requiredWaitJson = ''
    try {
        $requiredWaitProbe = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
            'pr', 'checks', "$pr", '--required', '--json', 'name,bucket,state', '--repo', $repo)
        if ($requiredWaitProbe.ExitCode -eq 0) { $requiredWaitJson = $requiredWaitProbe.Output -join "`n" }
    } catch {
        $requiredWaitJson = ''
    }
    $requiredWaitNames = @(Get-RequiredCheckNames -RequiredChecksJson $requiredWaitJson)
}
# WHAT THE WATCH ACTUALLY DID, set per attempt inside the loop below and read by everything after it.
# $requiredWaitNames answers "what does the ruleset require"; this answers "did the watch that
# produced $checks leave the non-required checks running". They are different questions and PR #1614
# is what happens when one variable is asked both.
$watchNarrowed = $false
if ($requiredWaitNames.Count -gt 0) {
    Write-Host "  Blocking on the REQUIRED check(s) only: $(Format-CheckNameList -Names $requiredWaitNames). The rest are waited for and reported after the fold (#1602)." -ForegroundColor DarkGray
} elseif ($requiredContexts.Readable) {
    Write-Host "  This trunk's ruleset requires no check, so this waits on EVERY check, exactly as before (this is not a finding)." -ForegroundColor DarkGray
} else {
    Write-Host "  The trunk's rules could not be read, so this waits on EVERY check, exactly as before (this is not a finding)." -ForegroundColor DarkGray
}

# THE REGISTRATION WAIT COMES AFTER THE MODE, and the order is the repair rather than tidiness
# (issue #1602, measured on PR #1614). It ran FIRST, so it waited for any check at all -- satisfied
# by `branch-entry` and `claude-review`, which are separate workflows and register before ci.yml's
# jobs -- and the narrowed watch that followed found no required check to watch, said so, and exited
# non-zero. Asked in this order the wait knows what the watch will block on and waits for THAT.
# The wait itself is Wait-CheckRegistration (defined above), so the watch loop below can re-enter the
# SAME wait when `--watch` starts before the checks register (#1350). $maxWaitSec stays a script
# variable because that re-entry passes it, and $waited carries the seconds already spent so the 180s
# budget is shared across the probe and any fallback rather than restarting.
$maxWaitSec = 180
$waited = Wait-CheckRegistration -Pr "$pr" -Repo $repo -Branch $branch `
    -PollSeconds $PollSeconds -MaxWaitSec $maxWaitSec

# TWO WAITS, AND THE SECOND ONE NEEDS A BUDGET OF ITS OWN (issue #1602, measured on PR #1614's THIRD
# ship). The wait above asks "is there any CI at all" and refuses at 180s with #1234's diagnostics --
# that is the right question and the right budget, because "no check suite was created" is answered in
# seconds and a repo that cannot answer it should not be kept waiting.
#
# THE REQUIRED CHECK IS A DIFFERENT QUESTION AND CAN LEGITIMATELY BE MINUTES AWAY. In this repo
# `lint-en-tests` is an AGGREGATOR -- `needs: [lint, suites]` in ci.yml -- so GitHub does not create
# its check run until the jobs it waits on have finished. Asked with the 180s budget it timed out
# twelve polls in a row and refused with "Check the workflow", about a workflow that was running
# perfectly and would register the check about five minutes later. A required check that gates a merge
# is very often exactly this shape, so the budget has to fit CI rather than fit a registration race.
#
# WHICH IS WHY IT IS A SECOND CALL AND NOT A BIGGER NUMBER ON THE FIRST. Raising the 180s would cost a
# repo with genuinely no check suite half an hour before it heard about it, and #1234's whole point is
# that it hears in seconds. Split, each wait keeps the budget its own question deserves.
#
# AND THIS DOES NOT LENGTHEN THE SHIP. The aggregator cannot conclude before the jobs it needs, so
# waiting for it to register is waiting for CI itself -- which the merge must do anyway. What the
# narrowing drops is the wait on the SEPARATE workflows (`branch-entry`, `claude-review`), which is
# exactly the tail #1602 measured and nothing else.
$maxRequiredWaitSec = 1800
# THE #1350 RE-ENTRY BELOW INHERITS WHICHEVER BUDGET ITS QUESTION DESERVES. Narrowed, it is asking the
# aggregator question again and must not be handed the 180s that has just been proven too small;
# unnarrowed it is #1350's original spin and keeps #1350's budget exactly.
$reentryMaxWaitSec = if ($requiredWaitNames.Count -gt 0) { $maxRequiredWaitSec } else { $maxWaitSec }
if ($requiredWaitNames.Count -gt 0) {
    # NO BACKTICKS IN THIS STRING. A backtick is PowerShell's escape character inside double quotes,
    # so a literal 'needs:' written as a code span would have made the 'n' a NEWLINE mid-sentence --
    # written and caught here, which is the same class as the ASCII rule this repo's script layer
    # already carries.
    Write-Host "  Now waiting for $(Format-CheckNameList -Names $requiredWaitNames) to register. A required check is often an aggregator job that waits on the others, so this can take as long as CI does -- it is not a stall (#1602)." -ForegroundColor DarkGray
    $waited = Wait-CheckRegistration -Pr "$pr" -Repo $repo -Branch $branch `
        -PollSeconds $PollSeconds -MaxWaitSec $maxRequiredWaitSec -AlreadyWaited $waited `
        -RequiredNames $requiredWaitNames
}
# --watch now blocks until the registered check finishes; exit 0 = all passed, non-zero = SOMETHING
# failed. WHICH something is the whole question, and the answer is NOT in that exit code (#943). This
# line used to read "branch protection blocks the merge until green, so a non-zero here means we must
# NOT merge" -- true only of a check the ruleset REQUIRES. `gh pr checks --watch` exits non-zero when
# ANY check fails, so the script inferred "the merge is blocked" from a signal that does not say so,
# and on August 26, 2026 that inference was the whole chain: `claude-review` red on every PR (#942),
# `lint-en-tests` -- the only check the `main` ruleset requires -- green, GitHub itself reporting those
# PRs as MERGEABLE / UNSTABLE, and this script reporting BLOCKED. The wait is untouched (#831 measured
# it and Dave kept it); only the verdict below moved.
#
# AND THE WATCH IS RE-ENTERED WHEN THE CONNECTION DROPS RATHER THAN THE CHECK (#1219). `--watch` is
# one long-lived GraphQL call, and on PR #1218 (September 2, 2026) it died mid-wait on `wsarecv: An
# existing connection was forcibly closed by the remote host` after nine clean poll cycles, while
# every check was still running. Its exit code says "something failed", the verdict below acted on
# that, and the operator read "CI did not pass ... Fix CI and re-run" about a run that went green on
# its own a few minutes later. Nothing about CI had failed; the socket had.
#
# WHY THIS IS A RETRY AND NOT ONLY A SENTENCE. Step 1 is the only step that reads the working tree
# and step 2b has already sent this checkout home (#1073), so resuming a ship that died HERE means
# checking the branch out again and re-running the whole local gate against a commit CI is already
# testing. The recovery costs more than the failure did, and a multi-minute wait dropping a
# connection is not exotic. The deadline is the operator's, not the socket's.
#
# BOUNDED, AND READ FROM THE PAYLOAD RATHER THAN THE ERROR TEXT. Get-LostWatchNote re-reads the
# checks and calls it a dropped watch only where nothing has reported a failure and something is
# still running -- so a red check breaks out on the first pass with the wording that is correct for
# it, and an UNREADABLE payload is not that case either, which is what keeps a gh that cannot answer
# at all from spinning here. Three attempts with one poll interval between them: a watch that dies
# instantly three times costs seconds instead of hammering the API.
$maxWatchAttempts = 3
$watchAttempt = 0
$lostWatchNote = ''
while ($true) {
    $watchAttempt++
    # `--required` WHEN THE RULESET NAMES ONE, AND EVERY CHECK WHEN IT DOES NOT (issue #1602; the
    # argument and the measurement are at the probe above). Built per attempt rather than once,
    # because $requiredWaitNames is refreshed from the in-loop read below: a required workflow that
    # had not registered its check run when the probe asked is found on the next attempt, and the
    # watch narrows then instead of staying wide for the rest of the run.
    $watchArgs = @('pr', 'checks', "$pr", '--watch', '--interval', "$PollSeconds", '--repo', $repo)
    $watchNarrowed = ($requiredWaitNames.Count -gt 0)
    if ($watchNarrowed) { $watchArgs += '--required' }
    $checks = Invoke-NativeCapture -FilePath 'gh' -Arguments $watchArgs
    $checks.Output | ForEach-Object { Write-Host $_ }

    # THE WATCH STARTED BEFORE THE CHECKS REGISTERED -- issue #1350, PR #1348 (September 3, 2026). A
    # non-zero `--watch` exit whose own output still says `no checks reported` is not a verdict:
    # nothing is registered to have failed. The probe above broke out of its wait -- it saw the head
    # open-pr had just pushed over (its stale suites), or a gh error it could not tell from a table --
    # and this call, moments later, found the new head had no suites yet. `no checks reported` means
    # the same thing here as it does in the probe, so the answer is the SAME registration wait, not
    # Get-MergeBlockVerdict: the verdict would read the empty payload as an unreadable required-check
    # list and print "Fix CI and re-run" about the one thing that had not happened.
    #
    # THE SAME SHAPE AS #1219's DROPPED SOCKET, with a different cause -- a watch that started too
    # early rather than one that died mid-run -- and bounded the same way. $waited carries the 180s
    # budget across, this spin costs at least one poll interval, and Wait-CheckRegistration owns the
    # timeout refusal (#1234 / #1247), so a race that will not settle ends in that refusal rather than
    # in this loop. Placed BEFORE the fact-pair reads below because with no checks there is nothing for
    # them to read -- two gh calls saved on every fallback spin.
    # BOTH OF GH'S WORDINGS SINCE #1602. A narrowed watch reports `no required checks reported` and
    # exits non-zero the moment it finds none registered -- `--watch --required` does NOT wait for one
    # to appear. Matching only `no checks reported` sent that straight past this branch and into
    # Get-LostWatchNote, which classified it as a dropped socket: three attempts, then a refusal saying
    # CI was still running. Measured on PR #1614, the second live ship of this very change; nothing was
    # wrong with CI and nothing was wrong with the branch.
    if ($checks.ExitCode -ne 0 -and (($checks.Output | Out-String) -match 'no (required )?checks reported')) {
        Write-Host "ship-pr: the watch started before the checks registered -- back to the registration wait (#1350)." -ForegroundColor DarkYellow
        Start-Sleep -Seconds $PollSeconds
        $waited += $PollSeconds
        $waited = Wait-CheckRegistration -Pr "$pr" -Repo $repo -Branch $branch `
            -PollSeconds $PollSeconds -MaxWaitSec $reentryMaxWaitSec -AlreadyWaited $waited `
            -RequiredNames $requiredWaitNames
        continue
    }

    # ONE pair of reads, serving both remaining questions: which check governed the wait (#831, the
    # line printed further down) and, on a failure, whether what failed is a check the ruleset
    # requires (#943, the merge decision). Measured while writing this: `gh pr checks --json` returns
    # exit 0 while reporting a failing check in its payload, so the STATE has to be read from the
    # records -- which is why both reads ask for `bucket,state` and neither trusts its own exit code
    # for the outcome.
    #
    # Still best-effort, and the invariant that mattered survives: an unreadable payload cannot turn a
    # GREEN run red, because a green watch never consults the verdict at all. What it can do is leave a
    # failing run refusing exactly as it did before this change -- Get-MergeBlockVerdict blocks on an
    # unreadable required-check list rather than guessing, which is the conservative half of the fix.
    # They no longer sit after the decision, because they are now part of it: a failing run that spends
    # two gh calls is spending them on the verdict, not on a line nobody will read.
    #
    # INSIDE THE LOOP SINCE #1219, and that is where they were already going to be needed: the retry
    # decision is made from this same payload, so reading it per attempt costs a dropped watch two gh
    # calls and costs the ordinary run -- one attempt -- exactly what it cost before.
    $checkFactsJson = ''
    $requiredFactsJson = ''
    try {
        # `link` rides along for inbound #1044: it is the only field in this payload that names the
        # Actions RUN behind a check, and the fact separating "the job never started" from "a check went
        # red" lives on the run rather than on the check. It costs nothing on a green run -- the block
        # that reads it is inside the refusal below.
        $checkFacts = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
            'pr', 'checks', "$pr", '--json', 'name,bucket,state,startedAt,completedAt,link', '--repo', $repo)
        if ($checkFacts.ExitCode -eq 0) { $checkFactsJson = $checkFacts.Output -join "`n" }
        # `--required` exits non-zero on a repo whose ruleset requires nothing, which is a legitimate state
        # and not an error. For the wait report the label is then simply omitted rather than guessed; for
        # the verdict it is the case that keeps refusing, since "requires nothing" and "the required checks
        # have not reported" are indistinguishable from here.
        $requiredFacts = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
            'pr', 'checks', "$pr", '--required', '--json', 'name,bucket,state,startedAt,completedAt', '--repo', $repo)
        if ($requiredFacts.ExitCode -eq 0) { $requiredFactsJson = $requiredFacts.Output -join "`n" }
    } catch {
        $checkFactsJson = ''
        $requiredFactsJson = ''
    }

    # THE WATCH MODE FOLLOWS THE FRESHEST READING (issue #1602). The probe above ran before the first
    # watch, when a required workflow may not have created its check run yet; this read is one watch
    # later. Refreshing here rather than re-asking gh costs nothing -- the call has just been made for
    # the verdict -- and it is only ever allowed to NARROW the watch: an empty reading leaves the
    # earlier names standing, because "the list did not read this time" is not evidence that the
    # ruleset requires nothing, and dropping back to watching everything on it would undo the fix
    # mid-run for no reason anybody could see in the output.
    $requiredWaitRefresh = @(Get-RequiredCheckNames -RequiredChecksJson $requiredFactsJson)
    if ($requiredWaitRefresh.Count -gt 0) { $requiredWaitNames = $requiredWaitRefresh }

    # A GREEN WATCH IS NOT THE SAME CLAIM AS "EVERY REQUIRED CHECK CONCLUDED" -- inbound #1549. This line
    # used to break straight out of the loop, past the two fact reads directly above it, and the wait
    # report printed two lines later already knew the difference: it annotates the governing check
    # `NOT required`. So the required/not-required distinction was in hand at the moment of the verdict,
    # was PRINTED, and was not acted on -- and the two readings that line supports are opposite. "The
    # check that governed the merge was not a required one" is a reason to keep waiting, not a certificate.
    #
    # WHY THE EXIT CODE CANNOT CARRY IT. `gh pr checks --watch` watches the checks registered at the
    # moment it STARTS. A required workflow that has not yet created its check run is absent from that
    # set rather than pending in it, so a fast non-required check reporting first satisfies the watch
    # and it exits 0 with the required one still to come. Measured September 7, 2026 in a consumer
    # (`dkj-policy` 4.31.0, BWJ-Development/smartwatchbanden PR #529): `.github/dependabot.yml` passed in
    # 1s, this step said "CI green" after 5s, and the merge came back `the base branch policy prohibits
    # the merge` while required `Shopify theme check` (2m1s) and `branch-entry` (31s) were both pending.
    # A plain `gh pr merge --merge` succeeded on the first try once they finished -- nothing was broken
    # except when this step asked.
    #
    # AND THE FAILURE DIRECTION IS THE EXPENSIVE ONE, which is why this is a wait and not a diagnostic.
    # The refusal at the merge is loud and safe; WHERE it leaves the work is not. It lands past the local
    # gates, past the PR, with the merge and the fold still owed -- and step 5 owes those to THIS
    # process, so the session holding the context is the one that dies. A later session finds an open PR
    # with a green tick and no visible reason it did not land. On a repo whose required check takes two
    # minutes, that fired on every ship where a fast non-required check reported first.
    #
    # SO THE ANSWER IS THE WAIT, THE SAME ONE #1350 AND #1219 REACH FOR. Nothing has failed here: a
    # pending check is pending. Re-entering `--watch` costs one call and now finds the required check
    # registered, so it blocks on it properly -- one extra iteration in the ordinary case. The wait
    # itself is still untouched in the sense #831 fixed it (Dave kept waiting on non-required checks);
    # what changes is that a non-required check can no longer END the wait on the required one's behalf.
    #
    # FAIL-OPEN ON AN UNREADABLE PAYLOAD, and that is deliberate rather than an oversight.
    # Get-MergeBlockVerdict returns an EMPTY UnfinishedRequired when the required-check list could not be
    # read, so this spins only on a payload that positively names a required check as unfinished. That
    # keeps the invariant the verdict was built under -- an unreadable payload can never turn a GREEN run
    # red -- and it keeps a repo with no ruleset at all (GitHub Free, no required check) out of this
    # branch entirely, the same line step 3b draws for the same reason.
    #
    # BOUNDED BY THE WATCH-ATTEMPT COUNTER RATHER THAN A SECOND ONE. What is being limited is the number
    # of `--watch` calls, which is exactly what $watchAttempt counts, so a run that drops its socket
    # twice and then meets a pending required check has still made three watch calls and stops. On
    # exhaustion this REFUSES instead of merging: the merge would be refused by GitHub anyway, and
    # refusing here says which required check is still pending, locally, in a run the operator can
    # simply re-enter.
    if ($checks.ExitCode -eq 0) {
        $pendingRequired = @()
        # Best-effort like every other read in this loop: a throw costs the wait, never the ship.
        try {
            $pendingRequired = @((Get-MergeBlockVerdict -RequiredChecksJson $requiredFactsJson `
                -ChecksJson $checkFactsJson).UnfinishedRequired)
        } catch {
            $pendingRequired = @()
        }
        if ($pendingRequired.Count -eq 0) { $lostWatchNote = ''; break }

        if ($watchAttempt -ge $maxWatchAttempts) {
            $has = if ($pendingRequired.Count -eq 1) { 'has' } else { 'have' }
            Write-Error @"
The required check $(Format-CheckNameList -Names $pendingRequired) $has still not finished after
$maxWatchAttempts watch attempts -- NOT merged (inbound #1549).

The watch kept returning green off a check the ruleset does not require, so it never blocked on this
one. Nothing has failed: re-run ship-pr once the required check is green, or merge manually.
"@
            exit 1
        }

        $has = if ($pendingRequired.Count -eq 1) { 'has' } else { 'have' }
        Write-Host "ship-pr: the watch went green off a NOT-required check while the required check $(Format-CheckNameList -Names $pendingRequired) $has not finished -- back to the wait (attempt $($watchAttempt + 1) of $maxWatchAttempts, inbound #1549)." -ForegroundColor DarkYellow
        Start-Sleep -Seconds $PollSeconds
        continue
    }

    # Best-effort, like every diagnostic on the refusal path below: a read that throws costs the retry
    # and the sentence, never the refusal itself.
    $lostWatchNote = ''
    try { $lostWatchNote = Get-LostWatchNote -ChecksJson $checkFactsJson -PrNumber "$pr" } catch { $lostWatchNote = '' }
    # Not a dropped watch: something really did fail, and the verdict below is about to say what.
    if (-not $lostWatchNote) { break }
    # It IS a dropped watch and there are no attempts left. The note survives the loop and the refusal
    # prints it, so the operator still reads the right sentence instead of "Fix CI and re-run".
    if ($watchAttempt -ge $maxWatchAttempts) { break }

    Write-Host "ship-pr: the WATCH dropped, not the run -- re-entering the wait (attempt $($watchAttempt + 1) of $maxWatchAttempts)." -ForegroundColor DarkYellow
    Write-Host "  $lostWatchNote" -ForegroundColor DarkGray
    Start-Sleep -Seconds $PollSeconds
}
$waitedSec = [int][math]::Round(((Get-Date) - $waitBegan).TotalSeconds)

if ($checks.ExitCode -ne 0) {
    $verdict = Get-MergeBlockVerdict -RequiredChecksJson $requiredFactsJson -ChecksJson $checkFactsJson
    if ($verdict.Blocked) {
        # WHICH REFUSAL THIS IS -- inbound #1044. The verdict is unchanged and stays unchanged: this
        # cannot let a merge through, it only decides which sentence the operator reads. A run that
        # never STARTED (an account payment failed, a spending limit reached, no runner available)
        # reports as a plain check failure through `gh pr checks`, and "Fix CI and re-run" then sends
        # the reader into their own code for a state no branch can repair. Measured August 28, 2026 in
        # a consumer repo, where it cost a hand-merge.
        #
        # Best-effort by construction. Every read is guarded and every failure degrades to the wording
        # that was already there -- a diagnostic must never be the reason a refusal cannot be printed.
        $stalled = @()
        try {
            foreach ($runId in @(Get-FailedCheckRunIds -ChecksJson $checkFactsJson)) {
                # -DiscardStderr because this output is PARSED: a gh warning merged into it would
                # break the parse and cost the note. Nothing here reads a job NAME, only counts and
                # the run's own URL, so the console code page cannot change the answer and -Utf8
                # would buy nothing.
                $runFacts = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @(
                    'run', 'view', "$runId", '--json', 'conclusion,status,url,jobs', '--repo', $repo)
                if ($runFacts.ExitCode -ne 0) { continue }
                $note = Get-StalledRunNote -RunJson ($runFacts.Output -join "`n") -RunId $runId
                if ($note) { $stalled += $note }
            }
        } catch {
            $stalled = @()
        }

        # THREE WORDINGS, ONE VERDICT. The two below are #1044's; the middle one is #1219's, and the
        # ordering is by construction rather than by preference -- a lost watch means nothing failed, so
        # Get-FailedCheckRunIds found no run to ask about and $stalled is necessarily empty there. Any
        # of the three can be reached with the merge still refused, which is the invariant all three
        # were built under.
        if ($stalled.Count -gt 0) {
            Write-Error "CI never RAN for PR #$pr -- NOT merged: $($verdict.Reason). $($stalled -join ' ')"
        } elseif ($lostWatchNote) {
            Write-Error "CI is still RUNNING for PR #$pr -- NOT merged after $maxWatchAttempts watch attempts: $($verdict.Reason). $lostWatchNote"
        } else {
            Write-Error "CI did not pass for PR #$pr (exit $($checks.ExitCode)) -- NOT merged: $($verdict.Reason). Fix CI and re-run, or merge manually once green."
        }
        exit 1
    }
    # Loud, and deliberately not reassuring. The merge is allowed to proceed because the ruleset says
    # so, and that is the only claim being made here -- the red mark is still red and still worth
    # chasing. Printed as a warning rather than swallowed, so a run that merged past a failing check
    # says which check, in the transcript, where the next reader looks.
    Write-Host "ship-pr: a check FAILED but the merge is not blocked -- $($verdict.Reason)." -ForegroundColor Yellow
    # AND IT SAYS WHY, WHERE THE OPERATOR IS ALREADY LOOKING -- issue #1103. The line above tells a
    # reader that a check went red and that chasing it is theirs to do; what it does not carry is the
    # reason, which sits three levels down -- a step, of a job, of a run. Eight issues have now been
    # filed in this repo against a red `claude-review` whose own diagnostic step had already printed
    # the cause (`api_error_status: 429`, the account behind the token out of quota, resetting on the
    # clock), and one of them concluded that a secret needed rotating. So the sentence the workflow
    # wrote about itself is fetched and printed beside the warning.
    #
    # ONLY THE NOT-REQUIRED FAILURES ARE ASKED ABOUT. A red REQUIRED check is a refusal, and its gate
    # runs locally before the push -- that reader meets the reason first-hand and does not need it
    # relayed. This is the path where the merge proceeds and the red mark is left behind, which is
    # exactly the one nobody was going to read.
    #
    # Best-effort by construction, like the stalled-run note on the refusal path above: every read is
    # guarded and a failure costs this line and nothing else. Shared with step 8 since #1602 --
    # Write-FailedCheckReasons, above, which carries the argument for the filter this call passes.
    Write-FailedCheckReasons -ChecksJson $checkFactsJson -Repo $repo -OnlyNames $verdict.FailedOther
    Write-Host "  Continuing to step 4. The failing check is still failing; nothing here fixes it." -ForegroundColor Yellow
} elseif ($watchNarrowed) {
    # NOT "CI green" -- SAY WHAT IS ACTUALLY GREEN (issue #1602). The watch blocked on the required
    # checks only, so at this moment the non-required ones may be running, or red. "CI green" would be
    # the exact overclaim this step was careful to avoid everywhere else, and it would be read by the
    # one reader who then meets a red check at step 8 and has to reconcile the two lines.
    Write-Host "ship-pr: every REQUIRED check is green. The rest are still watched, and reported at step 8." -ForegroundColor Green
} else {
    Write-Host "ship-pr: CI green." -ForegroundColor Green
}

$waitReport = $null
# THE REPORT IS ABOUT THE WAIT THAT ACTUALLY HAPPENED (issue #1602). Where the watch blocked on the
# required checks only, the full payload still holds non-required checks that have NOT concluded --
# so handing it here would name whichever check happened to finish last AMONG THOSE DONE and call it
# "governed the merge", which is now simply false: more checks are still to come and none of them
# governed anything. The required payload is the honest subject for this line, and #831's own
# question -- which check governed, and what the non-required tail cost -- is answered in full at
# step 8, once every check has actually reported.
if ($watchNarrowed -and $requiredFactsJson) {
    $waitReport = Get-CheckWaitReport -ChecksJson $requiredFactsJson `
        -RequiredNamesJson $requiredFactsJson -WaitedSeconds $waitedSec
} elseif ($checkFactsJson) {
    $waitReport = Get-CheckWaitReport -ChecksJson $checkFactsJson `
        -RequiredNamesJson $requiredFactsJson -WaitedSeconds $waitedSec
}
if ($waitReport) {
    Write-Host "  $waitReport" -ForegroundColor DarkGray
} else {
    # WHAT THIS LINE ACTUALLY MEANS, said plainly since inbound #1083. It fires only when the CHECK FACTS
    # could not be read -- gh answered nothing, or no check in the payload carries a readable completedAt.
    # It does NOT mean the repo requires no check: Get-CheckWaitReport omits the required/not-required
    # label in that case and still renders the line, which is why the report is not the place to learn
    # whether a ruleset exists. Worth stating because the old wording ("which check governed could not be
    # read") reads as a fault on a fresh repo whose owner has no prior for which parts of this toolchain
    # to trust -- and the reporter of #1083 read it as the no-ruleset case, which it is not.
    Write-Host "  waited $(Format-CheckDuration -Seconds $waitedSec) -- no readable check facts, so nothing to report about the wait" -ForegroundColor DarkGray
}

# --- Step 3b: has 'main' moved since the run that certified this PR? (issue #1292) ----------------
# THE FILED REASON DID NOT HOLD, AND THIS FOLLOWS THE CORRECTED ONE, NOT THE ORIGINAL. #1292 reported
# "the required check runs on the branch head", which is wrong: ci.yml triggers on 'pull_request', so
# the check tests GitHub's MERGE REF -- the branch already merged into the base tip -- and the merge
# result genuinely is tested. What #1292's own verification comment found instead is a green check
# going STALE: GitHub fixes that merge ref roughly at the moment the run is CREATED and never refreshes
# it when the base moves afterward ('pull_request' does not re-fire on that), and this repo's ruleset
# has `strict_required_status_checks_policy: false`, so a stale green check still satisfies the gate.
# Measured on PR #1268 (the instance): the test block PR #1268's own branch predated reached 'main' 45s
# before #1268's own CI run finished and 14m45s after that run started, and #1268 then merged on that
# same certificate 2h11m later.
#
# WHY THIS IS "HAS main MOVED SINCE THE RUN", NOT "IS THE BRANCH BEHIND main" -- #1292's own filed
# option 2. Behind-ness at merge is the ordinary case and is harmless whenever 'main' advanced BEFORE
# the certifying run started: the run then tested a merge ref that already held everything it needed
# to, and refusing on it is pure friction. Measured on the last 45 merged PRs into this repo's 'main':
# 20 (44.4%) were behind-at-merge, but only 14 (31.1%) actually had 'main' gain a first-parent commit
# AFTER their certifying run began -- the narrower predicate that voids a certificate, and the one this
# gate uses. Median staleness among those 14 was 16.1 minutes, max 146.6 (PR #1268 itself). Of the 14,
# 2 carried a scripts/**/scripts/tests/** change in the window -- the subset that can actually turn the
# trunk red -- but this gate does NOT filter on that: predicting which file a future test depends on is
# not this script's to do, and the predicate below is already cheap enough (one fetch, one first-parent
# log, and now one extra gh call per certifying run) that narrowing it further would trade a real safety
# margin for a rarer refusal on no measured benefit. Repo-settings option 1 from the same issue
# (`strict_required_status_checks_policy: true`) remains available and closes the gap completely -- it
# is Dave's call, not this script's, and is not made here.
#
# ONE EXEMPTION SINCE #1592, AND IT IS NOT THAT DECLINED PATH FILTER. The paragraph above declines to ask
# which files an ARBITRARY gained commit touched, and that stands. A FOLD commit is not arbitrary: this
# workflow writes it, straight onto the trunk, under an exception bounded to two paths and enforced by git
# ('git commit -- <paths>'), so its diff is the changelog plus the removal of a branch document and nothing
# else. Test-IsFoldOnlyCommit re-derives that bound from the commit's own diff -- never from its subject --
# and such a commit carries no script, no test, no manifest and no agent def, so it cannot be the case #1292
# was filed on. Measured on the two refusals #1592 reported: all three voiding commits were folds, and both
# refusals would have passed. Folds were 10 of the trunk's 19 first-parent commits in that window, and 71
# of 169 (42%) over the four days to that morning, so the
# exemption roughly halves the rate at which the trunk voids a certificate -- which is what decides whether
# detect-and-rebase converges, the window being about as long as CI itself takes (5-7 min here).
#
# AND #1592's OWN REASON DID NOT HOLD, which is why nothing at step 3's wait changed. It read
# 'lint-en-tests finished in 2s' off the check table and concluded the window was the non-required
# 'claude-review' wait; that 2s is the AGGREGATOR job's elapsed (ci.yml: needs: [lint, suites], two string
# compares on ubuntu), so the required check cannot conclude before the two windows-latest legs it waits
# on. Over the last 40 paired pull_request runs CI itself takes 310-461s (median 374s) and the non-required
# check governs 8 of them -- 20%, median excess 0s across all 40 and about 6 minutes in the 8 where it does
# govern -- which reconfirms #831's n=100 finding of 23% rather than overturning it.
#
# THE ANCHOR IS THE CERTIFYING RUN'S OWN created_at, NOT A CHECK'S startedAt -- RE-ANCHORED AFTER A
# RED-TEAM CAUGHT THE FIRST VERSION'S BIAS THE WRONG WAY ROUND (September 3, 2026). The first build read
# a required check's own `startedAt`, reasoned as "conservative because queueing only pushes it LATER
# than the true ref-fix moment, so a commit landing in that gap is rarely missed". That sentence had the
# DIRECTION right and the CHOICE backwards: a LATER anchor makes the `git log --since=<anchor>` below
# MISS commits that landed in the gap -- a genuinely stale certificate then reads as SOUND, which is the
# one failure this gate exists to prevent. The gap is far larger than "sub-minute" here for two reasons
# the original 45-PR sample could not see (it measured staleness AFTER anchoring on startedAt, so it was
# silent on the size of the startedAt-vs-ref-fix gap itself): `windows-latest` provisioning, which every
# run here pays, routinely costs over a minute; and "re-run failed jobs" against a flaky suite (ordinary
# practice in this repo) re-runs the SAME commit while `startedAt` jumps forward by however long the
# operator waited -- the gap can go from seconds to hours. Verified on a genuine re-run in this repo's
# own history (run 33652133970): the RUN object's `created_at` stayed at 2026-09-02T15:59:52Z across a
# re-run whose `run_started_at` moved to 21:15:50Z, over five hours later -- while the PER-ATTEMPT
# sub-resource (`.../attempts/2`) reports ITS OWN `created_at` matching that late start, which is the
# value that would have reintroduced the identical bias. So Get-CertifyingRunCreatedAt is fed the RUN
# object's `created_at` (what the runs LIST/GET endpoint returns), never a per-attempt one. See its own
# header for the full argument, including why this now favours OVER-refusing rather than under-refusing
# -- the safe direction for a gate whose only job is catching "green PR, red trunk".
#
# TWO THINGS THIS DOES NOT CLAIM. A `pull_request` run exists at all only for a MERGEABLE PR -- GitHub
# creates none for one with a merge conflict, which is harmless here: an unmergeable PR cannot be
# shipped by this script either way, whichever gate refuses it first. And "GitHub fixes THE merge ref"
# is this repo's own practical experience with a single-job workflow, not a documented contract --
# different jobs of one triggering event have been observed resolving different merge commits in the
# wild (actions/checkout#27) -- so this reasons from "a run's created_at cannot postdate its own
# ref-fix moment", which holds regardless, rather than from a guarantee GitHub does not make.
#
# THE RUN ID COMES FROM DATA ALREADY IN MEMORY. $checkFactsJson's `link` field (already fetched for the
# wait above) names the Actions run behind each check, so Get-RequiredCheckRunIds reads it rather than
# this step searching for the run fresh -- the one NEW network call per certifying run is the `gh api
# .../actions/runs/<id>` for its `created_at`.
#
# THE FAIL-CLOSED LINE MOVED WITH THE BIAS, AND IT IS DRAWN IN TWO PLACES ON PURPOSE. Not knowing which
# check (if any) is required is a state this script already tolerates elsewhere -- Get-MergeBlockVerdict
# itself cannot tell "this ruleset requires nothing" from "the required-check list did not read", and a
# repo on the GitHub Free plan (documented below, "A repo with no required check at all") has NO required
# check to protect in the first place. So $staleCheckNames.Count -eq 0 WARNS and this step is skipped --
# refusing here would permanently block ship-pr on every repo without a ruleset, for a predicate that has
# nothing to check in that repo. But once a required check IS named, this step knows exactly what it is
# protecting, and every read from there on (the run id, the run's created_at, the fetch, the log) FAILS
# CLOSED: an unresolved read at that point is not "nothing to verify", it is "something to verify that
# could not be verified", and treating that as sound is the exact bias this whole re-anchor exists to
# close. -SkipStaleCheck is the valve for all of it, named in every refusal below.
if ($SkipStaleCheck) {
    Write-Host "ship-pr: -SkipStaleCheck set -- not checking whether 'main' moved since the certifying run." -ForegroundColor DarkYellow
} else {
    # THE SAME WALK AS THE WAIT'S, SHARED SINCE #1602 rather than written out a third time. It was
    # inline here and inline at the probe above, and the 5.1 collapse this parse guards against is
    # invisible in a repo whose ruleset requires exactly ONE check -- which is this one, so a local
    # copy is a defect nothing here can measure. Get-RequiredCheckNames is tested; the tie-break on an
    # empty answer stays local, and below it is a warning rather than a refusal.
    $staleCheckNames = @(Get-RequiredCheckNames -RequiredChecksJson $requiredFactsJson)

    if ($staleCheckNames.Count -eq 0) {
        # NO RULESET, OR AN UNREADABLE ONE -- INDISTINGUISHABLE HERE, AND NEITHER REFUSES. See the
        # comment above the block: with no required check named there is nothing this predicate can
        # protect, so warning rather than refusing matches how the rest of this script already treats
        # that exact ambiguity.
        Write-Host "  stale-CI check: no required check name is known -- not checked (no ruleset, or unreadable; this is not a finding)." -ForegroundColor DarkGray
    } else {
        $staleRunIds = @(Get-RequiredCheckRunIds -ChecksJson $checkFactsJson -Names $staleCheckNames)
        if ($staleRunIds.Count -eq 0) {
            Write-Error @"
stale-CI check: no GitHub Actions run could be found behind the required check(s)
($(Format-CheckNameList -Names $staleCheckNames)) -- NOT merged (issue #1292).

A required check is named, so this predicate has something to protect, but its 'link' does not name a
resolvable Actions run (an external CI service posting its own status has no run to date-check this
way). -SkipStaleCheck ships anyway once you have confirmed by hand that 'main' has not moved in a way
that matters, or that the check in question is not subject to this staleness mechanism.
"@
            exit 1
        }

        $createdAtValues = @()
        $createdAtReadFailed = $false
        foreach ($runId in $staleRunIds) {
            $runRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @('api', "repos/$repo/actions/runs/$runId", '--jq', '.created_at')
            if ($runRead.ExitCode -eq 0) {
                $createdAtValues += (($runRead.Output -join '').Trim())
            } else {
                $createdAtReadFailed = $true
            }
        }
        if ($createdAtReadFailed) {
            Write-Error @"
stale-CI check: could not read 'created_at' for at least one run behind PR #$pr's required check(s) --
NOT merged (issue #1292).

Run id(s) asked: $($staleRunIds -join ', '). -SkipStaleCheck ships on the old certificate anyway.
"@
            exit 1
        }

        $certifiedSince = Get-CertifyingRunCreatedAt -CreatedAtValues $createdAtValues
        if ($null -eq $certifiedSince) {
            Write-Error @"
stale-CI check: the run(s) behind PR #$pr's required check(s) reported no readable 'created_at' -- NOT
merged (issue #1292). Run id(s) asked: $($staleRunIds -join ', '). -SkipStaleCheck ships on the old
certificate anyway.
"@
            exit 1
        }

        # NO -DiscardStderr ON THE FETCH, AND THE REASON IT ONCE CARRIED IS THE POINT (issue #1334).
        # This line shipped with a security justification -- "a failing git fetch echoes the remote URL,
        # which in a repo cloned over HTTPS with a credential in the URL is a secret" -- cited from
        # new-branch.ps1's base-freshness fetch. That reason is WRONG, measured on git 2.55.0.windows.5
        # (issues #1313, #1330): git anonymizes the URL itself through transport_anonymize_url, so
        # `user:token@host`, `token@host` and an unresolvable host all come back as a bare
        # `https://host/o/r.git`. None of the three leaked.
        #
        # THE MEASUREMENT LIVES AT ONE SEAM, and this comment points at it rather than restating it:
        # scripts/lib/native-capture-lib.ps1, under "-DiscardStderr IS NOT A CREDENTIAL GUARD". Read it
        # before reaching for this flag on any call that talks to a remote -- the same measurement is
        # why #1313's proposal to add it to three other fetches was DECLINED, for removing git's own
        # diagnosis from three failure paths in exchange for nothing.
        #
        # SO GIT'S WORDS STAY, AND THE REFUSAL PRINTS THEM. 'fetch failed' on its own leaves an operator
        # with no auth error, no host and no git reason. This is the cheaper end of that loss -- step 3b
        # runs BEFORE the merge, so a reader can retry, where at the fold step the PR is already merged
        # and git's reason is all they have -- but it is the same loss for the same nothing.
        $fetchMain = Invoke-NativeCapture -FilePath 'git' -Arguments @('fetch', 'origin', 'main', '--quiet')
        if ($fetchMain.ExitCode -ne 0) {
            $fetchMain.Output | Where-Object { $_ -and "$_".Trim() } | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
            Write-Error "stale-CI check: 'git fetch origin main' failed -- NOT merged (issue #1292). -SkipStaleCheck ships on the old certificate anyway."
            exit 1
        }
        $sinceStr = $certifiedSince.ToString('yyyy-MM-ddTHH:mm:ssZ')
        # -DiscardStderr for the same reason the gh api call above carries it, and NOT for the reason the
        # fetch above deliberately does without: this output is PARSED (it becomes $newMainCommits below),
        # so a git warning merged into it would break the parse.
        $mainLog = Invoke-NativeCapture -FilePath 'git' -DiscardStderr -Arguments @('log', 'origin/main', '--first-parent', '--since', $sinceStr, '--pretty=format:%H')
        if ($mainLog.ExitCode -ne 0) {
            Write-Error "stale-CI check: could not read the history of 'origin/main' -- NOT merged (issue #1292). -SkipStaleCheck ships on the old certificate anyway."
            exit 1
        }

        $newMainCommits = @($mainLog.Output | Where-Object { $_ -and "$_".Trim() })

        # THE FOLD IS DISCOUNTED, AND ONLY THE FOLD (issue #1592, September 8, 2026). A commit whose whole
        # diff is the changelog plus the removal of a branch document is written by fold-changelog-entry.ps1
        # under a named exception bounded to exactly those two paths -- it carries no script, no test, no
        # manifest and no agent def, so it cannot be the "test block on the trunk that this branch's CI never
        # ran" that #1292 exists to catch. Test-IsFoldOnlyCommit decides that from the commit's OWN diff, not
        # from its subject line, and its header carries the measurement: of the three commits that voided PR
        # #1571's two refused certificates, all three were folds, and folds were 10 of the trunk's 19
        # first-parent commits in that window.
        #
        # ONE LOCAL git show PER GAINED COMMIT, and the count is what makes that cheap: this block only runs
        # when 'main' has moved at all, and it had moved by 1 or 2 commits in the measured refusals. No
        # network, and nothing is read when the trunk has not moved.
        #
        # FAILS CLOSED, LIKE EVERY OTHER READ IN THIS STEP. A diff that will not read, or a seam that does
        # not resolve, leaves the commit counted exactly as it was before this exemption existed -- the
        # refusal below is then the same refusal it always was, which is the safe direction for a gate whose
        # only job is catching "green PR, red trunk".
        $foldExemptCommits = @()
        if ($newMainCommits.Count -gt 0) {
            $changelogForFold = ''
            $entryDirForFold = ''
            # Read once and held: Get-BranchFilePaths is pure and static, so two calls could never answer
            # differently -- but a reader has to establish that before they can be sure, and one variable
            # says it instead.
            $reservedForFold = @()
            try {
                $changelogForFold = Get-SeamValue -Name 'Get-ChangelogPath' -Default (Get-DefaultChangelogPath -RepoRoot $repoRoot)
                $branchPathsForFold = Get-BranchFilePaths
                $entryDirForFold = $branchPathsForFold.Directory
                $reservedForFold = @($branchPathsForFold.ReservedNames)
            } catch {
                $changelogForFold = ''
                $entryDirForFold = ''
            }
            if ($changelogForFold -and $entryDirForFold) {
                foreach ($gained in $newMainCommits) {
                    $sha = "$gained".Trim()
                    # --format= empties the header so only the name-status body comes back; -DiscardStderr
                    # because this output is PARSED, the same reason the first-parent log above carries it.
                    #
                    # AND -Utf8, BECAUSE THESE PATHS ARE DATA (issue #907). Branch names here are ASCII by
                    # this repo's own naming rule, so the console code page cannot change today's answer --
                    # but this call compares its output against two seam-supplied paths, which is exactly the
                    # class the lib's own header says must not be decoded with the console's code page. It
                    # fails in the safe direction either way (a mis-decoded path matches nothing and the
                    # commit stays counted), so this is the convention being followed rather than a bug being
                    # fixed; the alternative was a comment explaining why this one call is the odd one out.
                    $diffRead = Invoke-NativeCapture -Utf8 -FilePath 'git' -DiscardStderr -Arguments @('show', '--name-status', '--format=', $sha)
                    if ($diffRead.ExitCode -ne 0) { continue }
                    # NO ShortRead BRANCH HERE, AND THAT IS A MEASUREMENT RATHER THAN AN OMISSION
                    # (issue #1679). This call was listed with the five sites that read an empty capture
                    # on exit 0 as a substantive answer -- "this commit changed no files" -- and it does.
                    # But Test-IsFoldOnlyCommit FAILS CLOSED on exactly that: an unreadable diff returns
                    # $false, the commit is not exempted, and it stays counted in the staleness verdict.
                    # A ShortRead guard would `continue`, which leaves it counted too, so the two are
                    # behaviourally identical and the guard would be a no-op wearing a citation. What a
                    # short read costs here is one spurious stale-CI refusal, never a merge that should
                    # have been refused -- and an empty capture is LEGITIMATE at this call anyway (`git
                    # show --name-status --format=` on a commit that changed no files: measured, 0 bytes
                    # at exit 0), which is the other reason not to treat empty as failure.
                    if (Test-IsFoldOnlyCommit -NameStatusLines @($diffRead.Output) -ChangelogPath $changelogForFold `
                            -EntryDirectory $entryDirForFold -ReservedNames $reservedForFold) {
                        $foldExemptCommits += $sha
                    }
                }
            }
        }

        $staleVerdict = Get-StaleCertificateVerdict -NewMainCommits $newMainCommits -ExemptCommits $foldExemptCommits
        if ($staleVerdict.ExemptCount -gt 0) {
            Write-Host "  stale-CI check: $($staleVerdict.ExemptCount) of $($newMainCommits.Count) commit(s) 'main' gained are fold commits (changelog + branch document only) -- discounted (issue #1592)." -ForegroundColor DarkGray
        }
        if ($staleVerdict.Stale) {
            # SUBSTRING GUARDED BY LENGTH, not assumed. -DiscardStderr above makes a non-SHA line in
            # $newMainCommits unlikely, not impossible, and this refusal is the one place in the whole
            # gate where a short string would otherwise turn a careful message into a raw .NET
            # exception (Substring throwing "length must refer to a location within the string") --
            # right before the sentence that tells the operator what to do. A short entry is shown
            # whole rather than dropped, so the count and the list still agree.
            $shownShas = ($staleVerdict.Commits | Select-Object -First 5 | ForEach-Object {
                if ($_.Length -gt 8) { $_.Substring(0, 8) } else { $_ }
            }) -join ', '
            # The discounted folds are named in the refusal too, because the operator's next move is to look
            # at the trunk -- and a count that is smaller than what 'git log' shows them reads as a bug in
            # this gate unless the difference is stated here.
            $exemptClause = if ($staleVerdict.ExemptCount -gt 0) {
                "`n($($staleVerdict.ExemptCount) further commit(s) landed in the same window and were discounted as folds -- changelog plus a branch document, issue #1592.)"
            } else { '' }
            # THE REMEDY LEADS WITH A CHECKOUT, BECAUSE THIS RUN HAS ALREADY MOVED THE TREE (#1588).
            # Step 2b hands the primary checkout back to the trunk the moment the PR exists (#1073), and
            # this gate fires long after that -- past the whole CI wait. So the operator reading the
            # refusal is standing on 'main', not on the branch the two git commands are about. WHAT THAT
            # COSTS IS A SILENT NO-OP, NOT AN ERROR, which is why nothing caught it for five days: on a
            # trunk behind origin/main, `git merge origin/main` fast-forwards local 'main' and prints a
            # full diffstat -- reading exactly like the branch being brought forward -- and the push after
            # it is `Everything up-to-date`. The first thing to say anything is the re-run of ship-pr, one
            # full CI cycle later, and what it says is `You are on main` -- a message about the wrong
            # problem. Measured twice: PR #1583 (issue #1579) on September 8, 2026, and PR #1316 on
            # September 3, recorded as a parenthetical in #1325 and never repaired because that issue
            # closed on a different axis (CI sharding). THE OPERATOR CANNOT BE THE GUARD HERE: the branch
            # check fires at the start of an assignment, and this is the middle of one -- re-reading `git
            # branch` between a refusal and its own prescribed remedy is not a step anything asks for.
            #
            # $branch IS THE GATE'S OWN READING rather than a guess -- captured at line 357 before step 2b
            # ran, so it still names the branch even though HEAD no longer does. It is printed
            # UNCONDITIONALLY, not gated on the trunk-return decision: where step 2b declined to move (a
            # dirty tree, another worktree on the trunk) the line is a harmless no-op, and a remedy that
            # is sometimes missing a step is worse than one that sometimes repeats a checkout you have.
            # AND THE CHECKOUT NAMES A PASTE-SAFE TOKEN, not the raw ref (issue #1594): this remedy is the
            # first of the seven sites that issue measured, and the one whose reader is most often an
            # agent session pasting it back verbatim. $branchPasteNoteBlock explains a refused name and is
            # '' for every name this workflow creates, so the line above is unchanged in the common case.
            Write-Error @"
stale-CI certificate: 'main' gained $($staleVerdict.Count) commit(s) after the run that certified PR #$pr
started (issue #1292) -- NOT merged.$exemptClause

The required check(s) ($(Format-CheckNameList -Names $staleCheckNames)) tested GitHub's merge ref as it
stood when that run was created; anything landed on 'main' since is untested against this branch. Newest
first: $shownShas

Bring the branch up to date so CI re-runs against the current 'main', then re-run ship-pr. THE
CHECKOUT IS THE FIRST STEP -- this run already handed the tree back to the trunk (issue #1073), so
without it the merge below fast-forwards 'main' and leaves the branch untouched, silently (#1588):

  git checkout $($branchPaste.Token)
  git fetch origin main
  git merge origin/main
  <push, wait for CI to go green again, re-run ship-pr>$branchPasteNoteBlock

-SkipStaleCheck ships on the old certificate anyway -- use it only when the window is known-harmless
(e.g. the gained commits are docs-only). There is no re-run of the wait for this gate: fixing it means
bringing the branch forward, not retrying the same read.
"@
            exit 1
        }
        Write-Host "  stale-CI check: 'main' has not moved since the certifying run -- certificate still holds." -ForegroundColor DarkGray
    }
}

# --- Step 4: merge (no --admin: never bypass the CI gate) ----------------------------------------
#
# THE STEP-LIST GATE FIRES AGAIN HERE, and that is not belt-and-braces. Dave's requirement is about the
# MERGE -- "pas als alle punten zijn afgevinkt kan de branch met een PR gemergd worden" -- while step 1's
# copy of it runs in open-pr.ps1, which has a -Force. A PR opened through that escape valve, or opened by
# hand on github.com, or opened days ago and resumed by this script, would otherwise land with an
# unfinished plan: exactly what the requirement asks to be impossible. Checked here rather than passed
# down from step 1, because the working copy may have changed since.
#
# READ FROM THE SHIPPING BRANCH'S OWN COMMIT, NOT FROM THE WORKING TREE (issue #970, August 27, 2026).
# Both gates below used to read $repoRoot's copy, on the reasoning that "HEAD is still on the branch at this
# point -- step 5 is what moves to main". That holds for a foreground run and fails for the shape this
# script invites: it waits on CI -- 10m57s on the run that produced the report -- and a session that
# backgrounds the ship and starts the next piece of work has moved the checkout while it waits. Measured
# then: this gate refused PR #969 over "- [ ] TODO: the first step of this branch", the verbatim scaffold
# TODO of a branch created during the wait, while PR #969's own document had no open step at all.
#
# THAT INSTANCE FAILED SAFE AND THE INVERSE IS WHY IT IS REPAIRED. Reverse the two documents -- the shipping
# PR carries an unresolved step, the checkout has since moved to a branch whose steps are all ticked -- and
# the gate PASSES on someone else's document and merges. A gate with no -Force satisfied by a file the PR
# does not contain is worse than no gate: it reports the requirement as met while nothing checked it.
#
# refs/heads/$branch, AND IT IS PROVABLY WHAT THE MERGE MERGES. $branch is HEAD as read at the top of this
# run, and step 1's open-pr.ps1 pushes that branch before this point on every path through here -- a fresh
# PR and a resumed one alike -- so the local tip and the PR's head commit are the same commit. A gh read of
# headRefOid would say the same thing over the network, in a gate that must not refuse because a token
# expired. The full ref name rather than the bare branch: `git show` resolves its left half as a rev, and a
# name that also names a directory is otherwise ambiguous.
#
# NOT "REFUSE WHEN HEAD HAS MOVED", the other shape on the table. The report names a backgrounded ship
# beside the next piece of work as the ordinary shape of that window, so refusing on it would break the
# ordinary case in order to protect it. Nothing downstream needs the checkout to have stayed put either:
# step 5 checks out main and folds from there, whichever branch it was standing on.
#
# THE READ ALSO CLOSES A SECOND HOLE, unreported and smaller: a step ticked in the editor and never
# committed used to satisfy this gate while the PR still carried it unresolved. Both messages below already
# say "commit, and re-run", so this is the gate catching up with what it asks for.
#
# THE PATH IS RESOLVED THROUGH THE SAME READER, which is the half that is easy to get wrong.
# Resolve-BranchFilePath chooses between seven candidate names by READING each one, so resolving against the
# working tree and then reading the answer out of the commit would keep the very mismatch this repairs --
# and it would fail silently: the resolver names a path this branch does not carry, the read comes back
# $null, and the gate reads that as "no document". An absent document is still no finding, the same
# tolerance open-pr.ps1 applies and for the same reason.
#
# AND THE READER'S OWN VARIABLES CARRY THIS SCRIPT'S PREFIX, WHICH IS NOT COSMETIC. A plain scriptblock
# resolves its variables DYNAMICALLY at the point it is invoked -- inside Resolve-BranchFilePath -- so any
# name it uses that the resolver also has as a local resolves to the RESOLVER's, and PowerShell names are
# case-insensitive. `$repoRoot` inside this block would therefore be the resolver's own unbound $RepoRoot
# parameter: empty, silently, on the very arm that does not take it. $shipCycleRoot collides with nothing.
$shipCycleRef  = "refs/heads/$branch"
$shipCycleRoot = $repoRoot
$shipCycleRead = {
    param([string]$Rel)
    Get-GitFileTextAtRef -Ref $shipCycleRef -Path $Rel -RepoRoot $shipCycleRoot
}
# -Branch IS MANDATORY ON THIS ARM IN PRACTICE (#1255). The Reader arm deliberately does NOT default to
# HEAD -- it resolves against a tree this script is not standing in -- so without the branch the resolver
# would look for the pre-#1255 shared name and miss this branch's own document entirely. The failure would
# be the silent one the paragraph above describes: no path, no text, and a gate reading "no document".
$shipProgressRel  = Resolve-BranchFilePath -Kind Cycle -Reader $shipCycleRead -Branch $branch
# BOTH OF THESE ARE PRINTED IN THE TWO REFUSALS BELOW, and both are built from the branch name, so both
# get the prose strip (issue #1623). The raw pair above stays raw: one is a git ref this script resolves
# a file at, the other is the path it reads -- a stripped spelling would look for something that is not
# there. The refusals print the readable spelling of the same two things.
$shipCycleRefShown    = Get-DisplayRef -Ref $shipCycleRef
$shipProgressRelShown = Get-DisplayRef -Ref $shipProgressRel
$shipCycleText    = & $shipCycleRead $shipProgressRel
if ($null -ne $shipCycleText) {
    $shipSteps = @(Get-BranchProgressFindings -Text $shipCycleText)
    if ($shipSteps.Count -gt 0) {
        # THE REMEDY COMES WITH THE FINDING, same as open-pr's copy of this gate and for the same measured
        # reason (inbound #1081): the marks resolve an OPEN step and resolve nothing at all for a line that
        # still carries the scaffolder's text, so offering them to both labels sent an author round the
        # same refusal twice.
        $shipDetail = ($shipSteps | ForEach-Object { "  - $($_.Label): $($_.Line)`n      $($_.Remedy)" }) -join "`n"
        Write-Error @"
step-list gate: $shipProgressRelShown at $shipCycleRefShown still has unresolved steps - PR #$pr is NOT merged.

$shipDetail

Each finding above says what resolves it. Commit, and re-run. CI has already passed, so a re-run picks
up from here. There is no -Force for this gate.
"@
        exit 1
    }
}

# THE DEPLOY LOCK FIRES HERE, BESIDE THE STEP-LIST GATE AND FOR THE SAME REASON (Dave, issue #884,
# August 25, 2026). The section is fixed at the moment the PR opens: after that the document may not
# diverge from what the PR published, because the PR body is what reviewers approved and the fold in step 5
# is what turns the document into CHANGELOG.md. Without this, an edit made after the review lands in the
# changelog and the release notes having been seen by nobody -- and it lands SILENTLY, because the fold
# removes the document at the merge, so the place a reviewer would compare is the one place it no longer is.
#
# THE MERGE IS THE RIGHT PLACE, not the push. open-pr writes the section into the body, so at push time
# there is nothing to have diverged yet; the window this closes opens the instant the PR exists and shuts
# here. It is also the only point both escape routes pass through -- open-pr has a -Force, and a PR opened
# by hand on github.com never ran it at all.
#
# READ FROM THE SHIPPING BRANCH'S OWN COMMIT -- the same $shipCycleText the step-list gate above judged,
# for the reasons written out there (issue #970). This side of the comparison matters even more than that
# one: the document is what step 5 folds verbatim into CHANGELOG.md, so a lock satisfied by a stray
# checkout's document would be approving the fold of a section it never read.
# An unreadable body is NOT a finding: gh failing here says something about the network or the token, not
# about the section, and a gate that refuses a merge over that would be refusing on no evidence. The
# comparison itself is Test-DeployLock in pr-body-lib, the same function the CI gate calls, so "diverged"
# has one definition rather than two.
if ($null -ne $shipCycleText) {
    # -Utf8 IS LOAD-BEARING HERE (issue #907): the other side of this comparison is read with an
    # explicit UTF-8 decode one line below, and without it this side would be decoded with the console
    # code page instead -- so on cp850 an em-dash in the section came back as three characters and the
    # lock refused a PR whose body was intact.
    $lockView = Invoke-NativeCapture -Utf8 -FilePath 'gh' -Arguments @(
        'pr', 'view', "$pr", '--json', 'body', '--repo', $repo)
    # A SHORT READ IS NOT AN ANSWER EITHER (issue #1679), and this is the sharpest site in that class.
    # The -Utf8 arm can return an EMPTY Output with ExitCode 0 -- see the lib's ShortRead field for what
    # produces it -- and until now that fell straight through here: ConvertFrom-Json throws on '', the
    # catch below sets $lockBody = '', and Test-DeployLock against an empty body reports drift. So on a
    # loaded machine this refused a merge naming a section that had not changed, in a gate with no
    # -Force -- the same failure #1446 was filed for, arriving through the read instead of the decode.
    #
    # THE TWO REASONS ARE NAMED SEPARATELY, because the reader's next move differs: a non-zero gh is a
    # network or token problem, while a short read is this run's own read and resolves on a re-run. Same
    # shape as remote-ahead-lib.ps1's three reasons (#1676). Both land in the branch the comment above
    # already settled -- an unreadable body is NOT a finding -- so this widens what counts as
    # unreadable rather than adding a verdict.
    $lockUnread = ''
    $lockShortRead = $false
    if ($lockView.ExitCode -ne 0) {
        $lockUnread = "gh exited $($lockView.ExitCode)"
    } elseif ($lockView.ShortRead) {
        $lockUnread = 'gh exited 0 but its capture was still being written when it was read, so the body this run holds may be truncated'
        $lockShortRead = $true
    }
    if (-not $lockUnread) {
        $lockBody = ''
        try {
            $lockBody = [string](($lockView.Output -join "`n") | ConvertFrom-Json).body
        } catch {
            $lockBody = ''
        }
        $lockEntry = Get-DevelopmentEntryText -Text $shipCycleText
        $lock = Test-DeployLock -EntryText $lockEntry -PrBody $lockBody
        if ($lock.Applicable -and -not $lock.Locked) {
            $lockDrift = if ($lock.FirstDrift -eq $lock.Heading) {
                "the body does not carry the section at all -- its heading '$($lock.Heading)' is not in it"
            } else {
                "the first line the body does not have is:`n    $($lock.FirstDrift)"
            }
            Write-Error @"
DEPLOY lock: $shipProgressRelShown at $shipCycleRefShown has changed since PR #$pr was opened - it is NOT merged.

$lockDrift

The DEPLOY section is fixed when the PR opens: it is what the review approved, and step 5 folds it
verbatim into CHANGELOG.md and from there into the release notes. Choose one:

  - put the section back to what PR #$pr published, commit, and re-run; or
  - deliberately republish it -- open-pr.ps1 -RefreshBody rewrites the PR body from the document, so
    the change is reviewable where the review happens, and then re-run.

CI has already passed, so a re-run picks up from here. There is no -Force for this gate.
"@
            exit 1
        }
    } elseif ($lockShortRead) {
        # LOUDER THAN THE NEIGHBOURING LINE, ON PURPOSE. Both reasons end in the same place -- the
        # section was not compared -- but only this one is fixable by the person reading it, and a
        # skipped check in a gate with no -Force does not belong in a dim grey line. Raised on
        # Sebastian's review of this branch: widening "unreadable" to cover a short read trades a
        # FALSE REFUSAL for a check that did not run, and the second is only defensible while it is
        # visible.
        #
        # AND REFUSING IS DELIBERATELY NOT THE ALTERNATIVE. A short read means this run does not hold
        # the body, so there is no evidence in either direction -- and the comment above this block
        # already settles what such a gate does with that: it does not refuse on no evidence. The old
        # behaviour was not the safe version of this, it was #1446 -- Test-DeployLock against an empty
        # body reports drift, so every short read produced a refusal naming a section that had not
        # changed. What is genuinely given up is the rare coincidence of real drift AND a lost read on
        # one run; what is bought is that the common case stops accusing the document.
        #
        # A LONGER SETTLE BUDGET WOULD NOT CHANGE THIS, which is why the answer is a louder line rather
        # than a bigger number. A capture that is merely being flushed settles on the first probe
        # (measured: 2-8 ms over five gh calls), and one held by a grandchild that is still RUNNING
        # never releases inside any budget worth waiting for -- so raising it buys stalls, not reads.
        Write-Warning "DEPLOY lock: PR #$pr's body could not be read ($lockUnread) -- the section was NOT compared against what the PR published, and the merge is proceeding without that check. This is this run's own read rather than a fact about the PR, so a re-run normally settles it."
    } else {
        Write-Host "  DEPLOY lock: PR #$pr's body could not be read ($lockUnread) -- not checked (this is not a finding)." -ForegroundColor DarkGray
    }
}

# THE MERGE COMMIT GETS A TYPED SUBJECT (Dave, August 7, 2026). GitHub's default is
# "Merge pull request #504 from Owner/feat/x", which is the one line in the graph that does not start with
# a type. Everything else does -- feat:, fix:, docs:, fold:, release: -- so scanning the history means
# reading one shape for every commit except the merges, which are half of them.
#
# 'merge: <branch> (#NN)' is the shape, and it matches the fold's own subject one commit later
# ("fold: <branch> changelog (#NN)") field for field -- type, subject, PR number in brackets. A merge
# and its fold read as a pair. That pairing is why the fold kept its PR number when it was renamed from
# 'chore:' to 'fold:' on August 10, 2026, over the shorter form that dropped it.
#
# THE FORMAT WAS INVENTED TWICE ON THE SAME DAY, WHICH IS WHY IT IS WRITTEN DOWN HERE. Derek's lens has
# prescribed 'merge: <branch> (#<PR-number>)' since ba7081e; the first version of this line shipped
# 'merge: PR #NN <branch>' instead, because the lens was not checked before the shape was chosen. Two
# formats for one line is the exact defect this repo spent August 7 removing elsewhere, introduced here by
# the change that removed it there. The older, already-documented one wins -- it is the one that matches
# its neighbour.
#
# SAFE TO CHANGE, CHECKED RATHER THAN ASSUMED: nothing in this repo parses the merge subject -- not a
# script, not a gate, not a document. The PR number stays in the line for anyone who greps for it.
#
# -t is the short form of --subject. This line used to add "and applies to the merge-commit method only;
# a repo configured for squash or rebase has no merge commit for it to name, and gh ignores it there" --
# and that second half was never checked. `gh pr merge --help` documents -t as "Subject text for the merge
# commit" with NO method restriction, and GitHub's merge endpoint takes commit_title for a squash as well,
# so the likelier behaviour is that a squash consumer's squashed commit gets titled 'merge: <branch> (#NN)'
# -- a type label that is wrong for a commit which is the change rather than a merge of it.
#
# NOT REPAIRED HERE, DELIBERATELY. It cannot be reproduced from this repo, which merges, so a fix would be
# built on the same unverified reading that produced the retired sentence. What is corrected is the claim:
# the flag's scope is unknown for squash, and known-harmless for merge. Measure it in a squash-configured
# repo before changing anything.
$mergeSubject = "merge: $branch (#$pr)"
$merge = Invoke-NativeCapture -FilePath 'gh' -Arguments @('pr', 'merge', "$pr", "--$mergeMethod", '--subject', $mergeSubject, '--repo', $repo)
$merge.Output | ForEach-Object { Write-Host $_ }
if ($merge.ExitCode -ne 0) { Write-Error "Merge of PR #$pr failed."; exit 1 }

# EXIT 0 FROM `gh pr merge` IS NOT PROOF THAT THE PR MERGED -- issue #1325, the second merge-queue
# prerequisite and a correctness gap in its own right. `gh pr merge --help` says it in so many words:
# "When targeting a branch that requires a merge queue ... If required checks have passed, the pull
# request will be added to the merge queue." ADDED, not merged -- and the command returns 0 having
# enqueued. Step 5 is a few lines below and folds the entry onto 'main' on the strength of that exit
# code, so the moment a queue is switched on an ordinary ship would write a fold commit for a PR that
# has not landed. Nothing in the run would say so: the merge arrives minutes later, out of order with
# the fold that describes it.
#
# SO THE STATE IS READ RATHER THAN INFERRED. It costs one `gh pr view` on a path that already makes
# several, and it is right TODAY as well as under a queue: 'merged' has until now been an inference from
# an exit code, on the one script that writes to the trunk.
#
# A FAILED READ IS NOT A FINDING, deliberately, and this matches the DEPLOY lock a few lines up: only a
# state that is positively read and is not MERGED refuses. A network blip, an expired token or an
# unknown field leaves the run exactly as it was before this block existed -- turning a read failure
# into a refusal between the merge and the fold would manufacture the trapped-entry state (#1270) that
# the fold exists to prevent.
#
# THE RETRY IS FOR PROPAGATION, NOT FOR THE QUEUE. With no queue the merge is synchronous and the first
# read says MERGED; the two further attempts absorb a lagging read rather than waiting a queue out,
# which is why the budget is seconds and not minutes. Waiting a queue out is a different decision and it
# is not taken here -- the refusal hands it back instead of guessing at a timeout.
$mergedState = ''
for ($mergeReadAttempt = 1; $mergeReadAttempt -le 3; $mergeReadAttempt++) {
    try {
        $stateRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @(
            'pr', 'view', "$pr", '--repo', $repo, '--json', 'state', '--jq', '.state')
        if ($stateRead.ExitCode -eq 0) { $mergedState = ($stateRead.Output -join '').Trim() }
    } catch {
        $mergedState = ''
    }
    # AND UNDER A QUEUE THERE IS NOTHING TO WAIT FOR (issue #1506). The retry's own reason, one comment
    # up, is PROPAGATION: with no queue the merge is synchronous and the two further attempts absorb a
    # lagging read. With a queue the expected state is not-MERGED and stays that way for minutes, so the
    # spin buys nothing and costs 10 seconds on every ship this repo makes. One read, then out.
    if ($mergedState -eq 'MERGED' -or $queueActive -or $mergeReadAttempt -eq 3) { break }
    Start-Sleep -Seconds 5
}
# UNDER A QUEUE THIS SESSION NEVER FOLDS -- WHATEVER THE STATE READS (issue #1506). The three outcomes
# of the read above collapse to one answer here, and that is deliberate:
#
#   - 'OPEN'  -- the ordinary case. gh enqueued the PR and exited 0; GitHub merges it minutes later on a
#     gh-readonly-queue/** branch, in a process this session never observes.
#   - 'MERGED' -- the queue was empty and fast enough to land it before the read. The merge still arrived
#     as a push to main, so fold-on-merge.yml has already been triggered by it. Folding here as well
#     would put two runs on the same entry seconds apart, for no gain.
#   - UNREADABLE -- and this is the one that decides the shape. Not folding is recoverable: the entry
#     stays on the trunk and check-unfolded-entry.ps1 reports it, from a CI push check and from a
#     SessionStart hook in every consumer (#1270). Folding a PR that has not landed is not: it writes
#     the changelog entry onto the trunk ahead of the merge it describes, out of order, with nothing in
#     the run saying so (#1325). So an unreadable state takes the same exit as the other two rather than
#     falling through to step 5 on a guess.
#
# THE #1325 REFUSAL BELOW IS THEREFORE NOT RETIRED, ONLY NARROWED. It still fires on the case it was
# built for -- a non-MERGED state with NO queue read on the trunk -- which is the state that has no
# explanation and must not fold. What changed is that the explained case now has a name.
if ($queueActive) {
    $how = if ($mergedState -eq 'MERGED') {
        "already MERGED -- the queue was empty and landed it immediately"
    } elseif ($mergedState) {
        "ENQUEUED (state reads '$mergedState')"
    } else {
        "ENQUEUED -- its state could not be read back, which changes nothing here"
    }
    Write-Host "ship-pr: PR #$pr $how." -ForegroundColor Green
    Write-Host ""
    Write-Host "Done: PR #$pr shipped -- opened, CI green, handed to the merge queue on 'main'." -ForegroundColor Green
    Write-Host "  The queue merges it against its real base and pushes that merge to 'main'." -ForegroundColor DarkGray

    # THE PROMISE IS CHECKED BEFORE IT IS MADE (issue #1516). This line used to name fold-on-merge.yml
    # flatly, and in the source repo that is true. It is not true in a consumer: that workflow is not
    # plugin payload -- a plugin install writes nothing into a repo -- so a consumer running this script
    # under a queue reads "the entry will be folded" at the exact moment nothing is going to fold it. The
    # entry then sits on their trunk until check-unfolded-entry.ps1 reports it after the fact, with the
    # one line that could have said so having said the opposite.
    #
    # A FILE TEST, NOT A WORKFLOW-RUN QUERY, deliberately. The question is whether this repo has put
    # SOMETHING in the fold's place, and the tree answers that for free; asking the API which workflows
    # exist would cost a call per ship to be marginally more literal about a file the repo owns. A repo
    # that folds by some other route renames nothing and simply sees the second arm, which names the
    # command rather than refusing -- the enqueue itself is not in doubt either way.
    $foldRunner = Join-Path $repoRoot '.github\workflows\fold-on-merge.yml'
    if (Test-Path -LiteralPath $foldRunner -PathType Leaf) {
        Write-Host "  fold-on-merge.yml folds the entry off that push (#1493) -- not this session (#1506)." -ForegroundColor DarkGray
    } else {
        Write-Host "  NOTHING HERE FOLDS THAT ENTRY. This repo has no .github/workflows/fold-on-merge.yml," -ForegroundColor Yellow
        Write-Host "  and under a queue the fold is not this session's to make (#1506): the merge lands in a" -ForegroundColor Yellow
        Write-Host "  process this run never observes. The branch document will sit on 'main' unfolded, so the" -ForegroundColor Yellow
        Write-Host '  changelog never receives the entry and a release cut in that window misses the change.' -ForegroundColor Yellow
        Write-Host '  Fold it by hand once the merge has landed:' -ForegroundColor Yellow
        Write-Host "    fold-changelog-entry.ps1 -Branch $($branchPaste.Token) -Commit -Push" -ForegroundColor Yellow
        if ($branchPaste.Note) { Write-Host $branchPaste.Note -ForegroundColor Yellow }
        Write-Host '  And put the runner in place so the next ship does not need this -- run the adopt-dkj-policy' -ForegroundColor Yellow
        Write-Host '  skill (Part 3, adopt-ci-floor.ps1), which places it and the rest of the CI floor.' -ForegroundColor Yellow
    }
    Write-Host "  Watch it land:  gh pr view $pr --repo $repo" -ForegroundColor DarkGray
    # STEP 6 HAS NO HOME IN THIS SCRIPT ONCE THE MERGE IS THE QUEUE'S, so it is named rather than
    # silently dropped. GitHub honours the body's closing keywords on the queue's merge exactly as on
    # any other, so the issues do close; what is lost is the VERIFICATION that they did, plus its
    # repair when a keyword missed. That check is its own script and runs standalone against a merged
    # PR.
    #
    # IT NEED NOT BE A MANUAL STEP, and this line stops short of saying it is (issue #1511). A repo
    # can run the same check off the MERGE instead of off the shipping session -- a push to the trunk
    # is the one event that always sees a queue merge, the same property fold-on-merge.yml relies on
    # -- and where that is in place nobody types anything here. The source repo does exactly that in
    # .github/workflows/verify-resolved.yml; a consuming repo may not, which is why the command below
    # stays printed. Running it after the workflow already has is harmless: it re-reads the same body
    # and reports every declared issue already closed.
    Write-Host "  Not run here (the PR has not merged yet). Unless this repo verifies on the merge itself," -ForegroundColor DarkGray
    Write-Host "  check what it declared it closes once it has landed:" -ForegroundColor DarkGray
    Write-Host "    scripts\release\verify-resolved-issues.ps1 -Pr $pr" -ForegroundColor DarkGray
    # STEP 8 HAS NO HOME HERE EITHER, AND FOR THE SAME REASON -- it is named rather than dropped
    # (issue #1602). Where the watch above blocked on the required checks only, the non-required ones
    # were left running deliberately, to be reported after the fold; under a queue there is no fold
    # here and no merge to report against, so nothing prints them. The checks themselves are
    # unaffected -- they run, and they are on the PR -- so this is a lost REPORT, not a lost check,
    # which is why one line naming where to read them is the whole repair.
    if ($watchNarrowed) {
        Write-Host "  The NOT-required checks were not waited for here (#1602). Read them with:" -ForegroundColor DarkGray
        Write-Host "    gh pr checks $pr --repo $repo" -ForegroundColor DarkGray
    }
    # THE RECEIPT SHAPE IS THE LAST THING ON SCREEN (issue #1884), on this ending as much as on the
    # merged one below: a queue ship closes out too, and its receipt is the harder of the two to keep
    # short, because the run has just printed a page about what the queue will do next.
    if (Test-FunctionDefined 'Write-CloseOutReceipt') {
        Write-CloseOutReceipt -Cite "PR #$pr" -Bypass (Get-GateBypassNote -SkipLint:$SkipLint -SkipTests:$SkipTests)
    }
    exit 0
}
if (-not $mergedState) {
    Write-Host "  Merge state: PR #$pr's state could not be read -- not checked (this is not a finding)." -ForegroundColor DarkGray
} elseif ($mergedState -ne 'MERGED') {
    Write-Error @"
gh pr merge returned 0 but PR #$pr reads '$mergedState', not 'MERGED' -- NOT folded (issue #1325).

The likeliest cause is a merge queue on 'main': gh enqueues the PR and exits 0, and the merge lands
minutes later. Folding now would put the changelog entry on the trunk ahead of the merge it describes.

No merge_queue rule was read on 'main' here, though -- so either the trunk's rules could not be read
this run, or something other than a queue is holding the merge. If it IS a queue, ship-pr handles it
without this refusal once the rules read (issue #1506); check with:
  gh api repos/$repo/rules/branches/main --jq '[.[].type]'

Let the merge land, then re-run ship-pr: step 2 finds the merged PR and step 5 folds against a trunk
that actually carries it. Nothing here needs undoing -- the PR is queued, not lost.
"@
    exit 1
}
Write-Host "ship-pr: PR #$pr merged (--$mergeMethod)." -ForegroundColor Green

# --- Step 5: main + fold + commit + push ---------------------------------------------------------
#
# WHERE HEAD IS, READ BEFORE ANYTHING MOVES (Dave, issue #972, August 27, 2026). This step used to run
# `git checkout main` unconditionally one line after the merge, on the reasoning that HEAD is still on the
# shipping branch by now. That holds for a foreground run and fails for the shape this script INVITES:
# step 3 tells the reader to background the wait, and a session that then works in the same checkout has
# moved HEAD while CI ran. Measured on git 2.54.0.windows.1, that unconditional line has exactly two
# outcomes and both are defects:
#
#   - THE SESSION'S UNCOMMITTED EDIT COLLIDES with main -> `git checkout main` exits 1 with "Your local
#     changes to the following files would be overwritten by checkout", HEAD stays put, and this script
#     exits between the merge and the fold. That is precisely the state the comment further down calls
#     the one nothing reports: the PR merged, the branch document still in the tree, every gate green
#     until a release trips over it.
#   - IT DOES NOT COLLIDE -> exit 0, HEAD moves to main, AND THE UNCOMMITTED WORK TRAVELS WITH IT. The
#     session is then editing on the trunk with its own work already sitting there, which is the trap
#     Chris's lens measured on August 10, 2026 with a background task pulling the rug rather than a
#     previous chain having left you there.
#
# SO THE TREE THE FOLD RUNS IN IS CHOSEN RATHER THAN ASSUMED. HEAD still on the shipping branch -- the
# foreground run, and the lane discipline the ship-pr skill page made the default -- or already on main:
# nothing about this step changes, down to the command it runs. HEAD anywhere else (another branch, or
# detached, which reads as 'HEAD'): the session moved, its checkout is not this script's to touch, and
# the fold runs in a throwaway worktree instead.
#
# AND SINCE #1753 IT IS CHOSEN ON THE TREE'S CLEANLINESS AS WELL AS ON HEAD'S LOCATION -- because the two
# outcomes measured above were never conditional on HEAD having MOVED. They are what an unclean tree does
# to `git checkout main`, and the arm that runs it kept running it whenever HEAD was where this script
# left it. Both were still live on the ordinary foreground run, and PR #1752 hit the second one: the edit
# did not collide, the checkout succeeded, the uncommitted path travelled to the trunk -- and the ff-only
# merge one block down then failed on that same path, which is the first outcome arriving one step later.
# Step 2b had already read exactly this and declined the trunk on it; step 5 simply did not ask.
#
# 'ALREADY ON main' IS NOW THE ORDINARY ARM RATHER THAN THE ODD ONE (issue #1073). Step 2b puts the
# primary checkout back on the trunk as soon as the PR exists, so on a normal run this `git checkout
# main` is a no-op that the script takes on purpose. Nothing here needed changing for that -- the arm
# has existed since #972 -- and it is written down because the reverse reads as a defect: a reader who
# meets `-eq 'main'` and knows only the foreground story will think it is unreachable.
#
# THE WORKTREE HAS main CHECKED OUT RATHER THAN BEING DETACHED, AND THAT IS FORCED BY TWO MEASUREMENTS.
# Detached, fold-changelog-entry.ps1's `git push` fails with "fatal: You are not currently on a branch"
# (exit 128) and would need a HEAD:main push written into a script this change has no business touching.
# Attached, git refuses the add outright once the primary holds main -- which is why HEAD -eq 'main' folds
# in place above rather than reaching for a worktree it provably cannot have.
#
# IT IS NOT THE ALTERNATIVE worktree-lane.ps1 DECLINED, and that has to be said here because that script
# says the opposite in as many words. Its declined shape was "fold via whichever worktree HOLDS main", to
# spare a lane its two hand-back commands: a convenience, weighed against "a change to the single line
# that produces the state nothing reports", and rightly declined on that trade. This one adds a tree of
# its own instead of borrowing a lane's, fires only where that single line was ALREADY producing that
# state, and buys correctness rather than two commands. The decline stands; it is about the other thing.
#
# OUTSIDE THE REPO, for worktree-lane.ps1's own measured reason: a worktree inside the tree is walked by
# the lint gate's link scan and by the test suites, which then report a second copy of the whole repo as
# findings. A ship is not linting, but a folder left behind by a crashed run outlives the run, and the
# next gate is what would meet it.
# THE TAKE-DOWN IS A FUNCTION BECAUSE THREE EXIT PATHS OWE IT, not because it reads better. A failed
# fetch, a failed ff-only merge and the fold itself all leave this step, and an `exit 1` that skips the
# removal leaves a worktree holding main -- so the NEXT ship's `git checkout main` fails on a directory
# nobody remembers creating. Declared before the paths that call it, which is what PowerShell requires.
function Remove-ShipFoldWorktree {
    param([string]$Path)
    if (-not $Path) { return }
    $rm = Invoke-NativeCapture -FilePath 'git' -Arguments @('worktree', 'remove', $Path)
    if ($rm.ExitCode -eq 0) { return }
    # A NON-ZERO EXIT HERE DOES NOT MEAN NOTHING HAPPENED -- worktree-lane.ps1 measured that on the
    # Permission-denied case: git had already emptied the tree AND deregistered the worktree, and failed
    # only on deleting the now-empty directory. Reporting "still registered" there would send someone
    # hunting a worktree that is, for every purpose that matters, already gone. So ask git what it thinks
    # now instead of inferring from the exit code.
    $rm.Output | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
    $list = Invoke-NativeCapture -FilePath 'git' -Arguments @('worktree', 'list', '--porcelain')
    $wanted = $Path.Replace('/', '\').TrimEnd('\')
    $stillRegistered = $false
    if ($list.ExitCode -eq 0) {
        $stillRegistered = [bool](@($list.Output |
            Where-Object { $_ -match '^worktree\s+(.+)$' } |
            ForEach-Object { ($_ -replace '^worktree\s+', '').Trim().Replace('/', '\').TrimEnd('\') } |
            Where-Object { $_ -ieq $wanted }))
    }
    if ($stillRegistered) {
        Write-Host "ship-pr: the fold worktree is STILL REGISTERED and still holds main -- the next ship will fail on it." -ForegroundColor Red
        Write-Host "  Remove it: git worktree remove $Path" -ForegroundColor Red
    } else {
        Write-Host "ship-pr: the fold worktree is deregistered; only an empty folder is left behind: $Path" -ForegroundColor DarkYellow
    }
}

# ONE DEFINITION FOR THE THREE REMEDIES BELOW THAT PRINT IT. It was composed separately inside each of
# the two refusal arms, and #1753 would have added a third copy of a line that is the same in all of
# them -- so it is hoisted here, above the first arm that can reach it.
$foldScript = Join-Path $PSScriptRoot 'fold-changelog-entry.ps1'

$foldTree = $null
$headRead = Invoke-NativeCapture -FilePath 'git' -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
$headLine = @($headRead.Output | Where-Object { $_ -and "$_".Trim() }) | Select-Object -First 1
# AN UNREADABLE HEAD TAKES THE WORKTREE ROUTE, deliberately. It is the arm that leaves somebody else's
# checkout alone, so being wrong about it costs a temporary directory, while being wrong the other way
# costs the two outcomes above.
$headNow = if ($headRead.ExitCode -eq 0 -and $headLine) { "$headLine".Trim() } else { '' }

# AND SO DOES AN UNCLEAN TREE (issue #1753). The `git checkout main` below is the SAME checkout step 2b
# declined before the CI wait -- "a checkout would take them to the trunk or fail on them" -- and until
# this read it was made anyway, after the merge instead of before it, which is where that cost stops
# being recoverable. Measured shipping PR #1752: one unrelated uncommitted path, dragged onto the trunk
# by this line, and the ff-only merge below then failed on it. Merged, not folded.
#
# READ HERE RATHER THAN REUSED FROM STEP 2B, and the CI wait is why: that reading was taken before the
# longest step in the run, and this arm turns on what the tree holds NOW. The verdict itself is
# Get-FoldTreeDecision's, and tested there -- including why the trunk arm is exempt from the dirt test.
$statusAtFold = Invoke-NativeCapture -FilePath 'git' -Arguments @('status', '--porcelain')
# AN UNREADABLE STATUS COUNTS AS DIRTY, which is the opposite of step 2b's best-effort posture and is
# deliberate: there, an unreadable answer costs a convenience (the tree stays on its branch); here it
# would cost the fold. The worktree arm is correct whatever the tree holds, so guessing toward it is
# free -- one temporary directory -- while guessing the other way is the half-state above.
$statusAtFoldLines = if ($statusAtFold.ExitCode -eq 0) { @($statusAtFold.Output) } else { @('?? <unreadable>') }
$foldDecision = Get-FoldTreeDecision -Head $headNow -ShipBranch $branch -TrunkBranch 'main' -StatusLines $statusAtFoldLines

if ($foldDecision.InPlace) {
    $co = Invoke-NativeCapture -FilePath 'git' -Arguments @('checkout', 'main')
    $co.Output | ForEach-Object { Write-Host $_ }
    # A BARE "git checkout main failed" USED TO BE THE WHOLE MESSAGE HERE, and this is the exact line the
    # merge has already run past -- so it is the one place in the script where a one-line error is most
    # expensive (issue #1069, measured on PR #1068). Step 0 turns the common cause into a refusal before
    # anything is pushed; what reaches here is the narrow window it cannot cover, where another session
    # took 'main' while step 3 watched CI. So say the same thing the worktree arm below says: the state
    # the repo is actually in, and the two commands that finish the job by hand.
    if ($co.ExitCode -ne 0) {
        Write-Error @"
PR #$pr IS MERGED but NOT folded -- this tree could not check out main.

git's own reason is above. The usual one is that another worktree took main while the CI wait ran
("fatal: 'main' is already used by worktree at ..."), and this script will not take it away from one.

The PR is merged, the branch document is still in the tree, and every gate stays green until a
release trips over it. Fold from the tree that HOLDS main -- fold-changelog-entry.ps1 has carried
-RepoRoot for exactly this since #101:

  git -C <that worktree> fetch --prune origin; git -C <that worktree> merge --ff-only origin/main
  & "$foldScript" -Branch $($branchPaste.Token) -RepoRoot <that worktree> -Push$branchPasteNoteBlock

`git worktree list` names it.
"@
        exit 1
    }
} else {
    $foldTree = New-ScratchPath -Label "ship-pr-fold-$pr"
    # THE SENTENCE COMES FROM THE DECISION, not from this arm (issue #1753). There are three ways to
    # reach it now -- HEAD moved, HEAD unreadable, the tree unclean -- and a hard-coded "this checkout
    # moved while CI ran" is false on two of them. The composer owns its own wording, which is also what
    # keeps #1623's strip on it: $headNow IS a second ref name, read off HEAD exactly as $branch was, so
    # leaving it raw beside a stripped $branchShown would sanitise one half of this sentence and print
    # the other. Get-FoldTreeDecision runs both names through Get-DisplayRef for that reason, and its
    # suite asserts it. The raw $headNow stays raw here: it is compared, not printed.
    Write-Host "ship-pr: $($foldDecision.Reason)" -ForegroundColor Yellow
    Write-Host "  Folding in a throwaway worktree instead, so nothing here is touched: $foldTree" -ForegroundColor Yellow
    $wtAdd = Invoke-NativeCapture -FilePath 'git' -Arguments @('worktree', 'add', $foldTree, 'main')
    $wtAdd.Output | ForEach-Object { Write-Host $_ }
    if ($wtAdd.ExitCode -ne 0) {
        Write-Error @"
PR #$pr IS MERGED but NOT folded -- no worktree on main could be added at $foldTree.

git's own reason is above. The usual one is that another worktree already has main checked out
("fatal: 'main' is already used by worktree at ..."), and this script will not take it away from one.

The PR is merged, the branch document is still in the tree, and every gate stays green until a
release trips over it. Fold by hand from any tree standing on an up-to-date main:

  git checkout main; git fetch --prune origin; git merge --ff-only origin/main
  & "$foldScript" -Branch $($branchPaste.Token) -Push$branchPasteNoteBlock
"@
        exit 1
    }
    # GIT'S OWN SPELLING OF THE PATH, not the one composed above. GetTempPath() can hand back an 8.3 short
    # name (%TEMP% under a service account is what does it) while `git worktree list` reports the long one,
    # and the two would then never compare equal -- so the take-down would report a worktree as still
    # registered when git had in fact removed it. Resolved while the directory certainly exists, which is
    # exactly the moment the take-down no longer can.
    $resolved = Resolve-Path -LiteralPath $foldTree -ErrorAction SilentlyContinue
    if ($resolved) { $foldTree = $resolved.ProviderPath }
}
# The tree the rest of this step works in: this checkout, or the throwaway worktree. `-C` on every call
# rather than two copies of the same three commands -- with $foldRoot equal to $repoRoot, which is where
# this script already stands, it is a no-op and the in-place path runs exactly what it ran before.
$foldRoot = if ($foldTree) { $foldTree } else { $repoRoot }

# Fetch + an EXPLICIT ff-only merge of origin/main, not a bare `git pull --ff-only` (lesson of
# July 29, 2026, PR #257). The bare pull aborted with "Cannot fast-forward to multiple branches" on a
# clean main immediately after a merge + prune -- and it aborts HERE, in the one gap between the merge
# and the fold, which is the state nothing reports: the PR is merged, the entry file is still in the
# root, and every gate stays green until a release trips over it. Git raises that error when handed more
# than one ref to merge; naming origin/main explicitly hands it exactly one, so this step cannot reach
# that failure mode, whereas a bare pull depends on whatever FETCH_HEAD happens to hold. Why the pull
# got more than one ref was deliberately not guessed at -- see Derek's lens for that reasoning.
#
# BOUNDED (inbound #1179), and this is the worse of the two places to hang: the PR is already MERGED by
# the time this line runs, so a stall here parks the tree in the one gap nothing reports -- merged
# upstream, entry file still in the root -- and reports it as a ship still in progress. The lib's
# non-interactive environment closes the measured cause; the bound is what turns any remaining stall
# into a message naming this step.

# THE STATE SENTENCE, WRITTEN ONCE FOR ALL THREE EXITS BELOW THIS LINE (issue #1753). Everything from
# here on runs AFTER the merge, so every failure past it is the merged-but-unfolded half-state -- and
# only one of the three said so. The timed-out fetch carried the full sentence; the plain fetch failure
# said "git fetch of origin failed." and the ff-only failure "git merge --ff-only of origin/main
# failed.", which is the arm that actually fired on PR #1752. Two adjacent arms of one block, and the
# one a reader meets was the quiet one -- so the difference between them is now only the FIRST line,
# which is the half that genuinely differs.
$mergedNotFoldedNote = @"

PR #$pr IS MERGED; only the fold is outstanding. The branch document is still on the trunk and every
gate stays green until a release trips over it.

Deal with what git reported above -- an unclean tree is the common one, and its paths are named in
that output -- then fold by hand from a tree standing on an up-to-date main:

  git checkout main; git fetch --prune origin; git merge --ff-only origin/main
  & "$foldScript" -Branch $($branchPaste.Token) -Push$branchPasteNoteBlock
"@
$fetch = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $foldRoot, 'fetch', '--prune', 'origin') `
                              -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
$fetch.Output | ForEach-Object { Write-Host $_ }
if ($fetch.ExitCode -ne 0) {
    Remove-ShipFoldWorktree -Path $foldTree
    if ($fetch.TimedOut) {
        Write-Error "git fetch of origin did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] lines above. Fix the credential first.$mergedNotFoldedNote"
    } else {
        Write-Error "git fetch of origin failed.$mergedNotFoldedNote"
    }
    exit 1
}

$ff = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $foldRoot, 'merge', '--ff-only', 'origin/main')
$ff.Output | ForEach-Object { Write-Host $_ }
if ($ff.ExitCode -ne 0) { Remove-ShipFoldWorktree -Path $foldTree; Write-Error "git merge --ff-only of origin/main failed.$mergedNotFoldedNote"; exit 1 }

# The fold, its commit AND its push are all fold-changelog-entry.ps1's job (-Push implies -Commit).
# This used to be a fold followed by `git add -A` + commit + push right here, and that was a real
# defect rather than a duplication: `git add -A` stages the WHOLE tree, so anything else modified or
# already staged was swept into a commit that lands directly on main under a named exception to "never
# commit directly". The fold script commits with an explicit pathspec -- CHANGELOG.md plus the entry
# files it actually folded, and nothing else can enter, whatever is lying around. It also knows which
# of those paths git tracks, so an entry that was never committed does not fail the pathspec after the
# fold has already deleted it.
#
# -Push rather than a separate push here, for the reason that flag exists: a fold commit sitting
# unpushed on main is its own silent half-state, and splitting the commit from the push across two
# scripts is how you get one.
#
# THE FOLD STAYS ITS OWN COMMIT, AND THE REASON IS GIT'S RATHER THAN THIS REPO'S (Dave, August 10, 2026;
# inbound #571). The obvious tidy-up is to fold INTO the merge -- `git merge --no-ff --no-commit <branch>`,
# run the fold without -Commit so it writes to disk only, then one `git commit` -- so a PR leaves one
# commit on main instead of a merge with a `fold: ...` sitting on top of it. The request is
# well-founded on its symptom: measured on August 10, 2026 this repo held 398 merge commits (206 typed
# 'merge: ', 192 older 'Merge pull request') against 410 folds, 394 of which sit directly on a merge in
# first-parent order. They really are one movement written as two commits.
#
# IT IS DECLINED, AND THE DECIDING FACT WAS MEASURED RATHER THAN ARGUED. The pathspec above is not merely
# weakened by that flow -- git refuses to express it at all:
#
#     $ git commit -m "merge: feat/x (#1)" -- CHANGELOG.md dkj-policy/feat-x.md
#     fatal: cannot do a partial commit during a merge.
#
# The only commit git will make while MERGE_HEAD exists is a whole-index one, and in the same test it swept
# an unrelated stray.txt straight into the merge commit -- the exact `git add -A` defect the pathspec was
# introduced to remove. So the guarantee could not move, only be downgraded to a pre-flight "was the
# tree clean before the merge?", which is checked earlier and on different state than the commit it
# protects.
#
# TWO FURTHER COSTS, both real and neither decisive on its own. The merge date loses its provenance: a
# local merge leaves the PR open, so mergedAt is empty and Format-EntryFoldFooter falls back to the clock
# -- the source #469 deliberately moved away from. And the merge stops going through the button, so the
# repo ruleset's required check no longer gates it; CLAUDE.md already records the release commit as the
# least-gated commit in this workflow, and this would extend that to every PR.
#
# WHAT A CONSUMER SHOULD DO INSTEAD: nothing. Two commits per PR is the cost of a fold whose scope git
# enforces, and the typed merge subject above already makes the pair scannable. A repo on squash that wants
# the readable arc should switch to merge on its own merits and accept the trailing fold commit.
Write-Host "ship-pr: folding the changelog entry..." -ForegroundColor Cyan
# -RepoRoot ONLY on the worktree arm. The flag has been there since #101 and its own param comment names
# this exact caller -- "a consumer that runs the fold from a temporary/detached worktree (e.g. a
# ship-pr.ps1 that checks out main elsewhere)" -- so the fold script needed no change for this. It is not
# passed on the in-place arm even though it would resolve to the same directory: that arm is meant to run
# what it always ran, and "unchanged behavior below" is what the fold script promises when it is omitted.
$foldArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', (Join-Path $PSScriptRoot 'fold-changelog-entry.ps1'),
    '-Branch', $branch, '-Push')
if ($foldTree) { $foldArgs += @('-RepoRoot', $foldTree) }
# ONE CHAIN, ONE RECEIPT (issue #1884) -- the same reason as the open-pr spawn above.
if (Test-FunctionDefined 'Push-CloseOutSuppression') { Push-CloseOutSuppression }
try { & powershell @foldArgs } finally { if (Test-FunctionDefined 'Pop-CloseOutSuppression') { Pop-CloseOutSuppression } }
$foldExit = $LASTEXITCODE

# AND IT COMES DOWN WHETHER THE FOLD SUCCEEDED OR NOT, before the exit code is judged -- the last of the
# three paths the function above exists for.
Remove-ShipFoldWorktree -Path $foldTree

# --- THE FOLD CAN BE LOST TO A RACE AND HAVE HAPPENED ANYWAY (issue #1792) ------------------------
#
# THE RACE. fold-on-merge.yml runs on EVERY push to main, so the merge one line above triggers it -- and
# with the merge queue retired (#1720) that job and this step both fold on the ordinary path. Whichever
# gets its push in second is refused. When the loser is this session the fold script commits on the LOCAL
# trunk, cannot push, establishes that the entry is already upstream with an identical body, and stops.
#
# EXIT 3 IS THAT VERDICT AND NOTHING ELSE (see the fold script's own EXIT CODES block). It is not "the
# fold failed": it is "the fold happened, somebody else made it". So the SHIP succeeded -- merged, folded,
# pushed -- and this run carries on to step 5b, step 6 and the report, exactly as on a clean fold.
#
# WHY THE OLD `-ne 0` WAS EXPENSIVE OUT OF PROPORTION TO ITS SIZE. Measured shipping PR #1789 on
# 2026-09-10: the two fold commits had IDENTICAL TREES and origin/main was correct, so nothing was at
# stake in the content -- and yet this line reported a hard failure and left the session's own main
# diverged 1/1, a state this repo's rules reserve every obvious way out of (reset --hard, a rebase on a
# shared branch) to Dave. A correct ship must not end by handing the operator a trunk they may not fix.
#
# IT REPORTS THE LEFTOVER RATHER THAN CLEARING IT, and that boundary is the fold script's, kept here for
# the same reason: every route off a trunk is a history operation the constitution reserves to a person.
# What was missing was never the power to rewrite, it was the sentence saying WHICH two commands to run --
# so those are printed, after step 5b, once this tree has finished moving (a lane hands the trunk back
# there, and that changes which of the two realignments is the correct one).
$foldStoodDown = $false
if ($foldExit -eq 3) {
    $foldStoodDown = $true
    Write-Host "ship-pr: this session LOST the fold race -- the entry was already on 'main' when the push went out." -ForegroundColor Yellow
    Write-Host "  Not a failed ship: PR #$pr is merged AND folded (by fold-on-merge.yml, or by another device), and the fold script's" -ForegroundColor DarkGray
    Write-Host "  lines above prove it -- the entry is upstream once, with a body identical to the one this run wrote." -ForegroundColor DarkGray
    Write-Host "  What is left is local only: a redundant fold commit on this checkout's 'main'. Reported at the end of the run." -ForegroundColor DarkGray
} elseif ($foldExit -ne 0) {
    Write-Error "fold-changelog-entry failed -- the fold is NOT committed or NOT pushed. Its own output above says which; do not re-run the fold if it already removed the entry file."
    exit 1
}

# --- Step 5b: give the trunk back, if this is not the primary checkout (issue #1069) ---------------
# THE ROOT CAUSE, AND IT IS ONE LINE ABOVE: the in-place arm leaves this tree standing on 'main'. In the
# primary checkout that is deliberate and documented -- a finished chain ends on the trunk, which is what
# makes the session safe to clear. In a LANE it is a global lock: no other worktree can check 'main' out
# from that moment on, nothing warns, and the bill is paid by an unrelated branch after ITS merge. That is
# how PR #1068 was merged and left unfolded.
#
# SO THE RULE IS NOT "always return", IT IS "return where staying was never the point". Only a
# non-primary tree hands the trunk back, and only after a SUCCESSFUL fold: a failed one leaves this tree
# on main mid-repair, which is exactly where whoever finishes it by hand needs to be standing.
#
# A STOOD-DOWN FOLD (exit 3, issue #1792) REACHES HERE AND SHOULD. It is a successful fold made by
# somebody else, so staying was never the point -- and the local leftover it does owe the operator is a
# branch-pointer move, which is EASIER off the trunk than on it. Step 5c reads HEAD after this block for
# exactly that reason and prints whichever of the two commands the tree it finds can actually run.
#
# BACK TO THE BRANCH RATHER THAN DETACHED, so the lane is where its author left it. Detaching is the
# fallback and not the preference: it always works (nothing can hold a commit) but it hands back a tree
# whose HEAD reads as nothing in particular. Either way the lock is released, which is the part that
# matters to every other worktree on the machine.
if (-not $foldTree -and -not $shipTreeIsPrimary) {
    Write-Host "ship-pr: this is not the primary checkout -- releasing 'main' so other worktrees can use it." -ForegroundColor Cyan
    $back = Invoke-NativeCapture -FilePath 'git' -Arguments @('checkout', $branch)
    if ($back.ExitCode -ne 0) {
        $detach = Invoke-NativeCapture -FilePath 'git' -Arguments @('checkout', '--detach')
        if ($detach.ExitCode -eq 0) {
            Write-Host "  '$branchShown' could not be checked out here, so this tree is detached instead -- 'main' is free." -ForegroundColor Yellow
        } else {
            # NEVER FAILS THE SHIP. Everything this script was asked to do has happened by now: merged,
            # folded, pushed. What is left is a lock on 'main' that the next run's step 0 will report by
            # name anyway -- so this says it once, here, where it is cheapest to act on.
            Write-Warning "this tree is still on 'main' and is not the primary checkout, so it holds the trunk for the whole clone. Move it off: git -C `"$repoRoot`" checkout $($branchPaste.Token)"
            if ($branchPaste.Note) { Write-Warning $branchPaste.Note }
        }
    }
}

# --- Step 5c: the redundant fold commit this run lost the race with (issue #1792) -----------------
#
# BELOW STEP 5b DELIBERATELY. A lane hands the trunk back up there, and whether 'main' is still checked
# out HERE decides which realignment is the correct one: a checked-out branch cannot be moved with
# `git branch -f`, and a branch nothing holds does not need a reset. So HEAD is read now rather than
# assumed from the arm this run took, and exactly one command is printed.
#
# THE BACKUP REF COMES FIRST, and it is what makes the second line safe to hand to somebody: the commit
# is preserved under refs/heads/backup/ before the trunk pointer moves, so a reader who disagrees with
# this run's verdict can still read, diff or cherry-pick it. That is the shape the operator of the
# measured incident arrived at by hand (#1792) -- "works but not something a reader would derive", which
# is the whole reason it is printed here.
#
# AND THERE ARE TWO COMMANDS, NOT THREE: no fetch is printed, because the fold's own diagnosis fetched
# origin/<trunk> in order to reach this verdict at all -- it read the remote changelog out of that ref.
# So origin/main is current by construction here, and a printed fetch would suggest the reader has a
# question to answer that they do not.
#
# NEITHER COMMAND IS RUN. `reset --keep` is not `reset --hard`, but a script that moves a trunk pointer on
# its own has taken a power nobody granted it, and the fold script this step delegates to declines the
# same thing in as many words. The gap #1792 measured was guidance, not authority.
if ($foldStoodDown) {
    # 'HEAD' is what --abbrev-ref answers on a DETACHED tree, and it is not a branch name: nothing holds
    # 'main' there either, so it takes the same arm as a tree standing on its own branch -- it simply must
    # not be printed back as though the tree were on a branch called HEAD.
    $headAfter = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'rev-parse', '--abbrev-ref', 'HEAD') -DiscardStderr
    $headName  = if ($headAfter.ExitCode -eq 0) { (($headAfter.Output -join '') -replace '\s', '') } else { '' }
    $backupRef = Get-PasteableRef -Ref "backup/fold-$($branch -replace '/', '-')" -Placeholder '<backup/fold-your-branch>'

    Write-Host "ship-pr: this checkout's 'main' still carries the redundant fold commit -- origin/main is CORRECT and is not waiting on it." -ForegroundColor Yellow
    Write-Host "  Preserve it, then realign the trunk (nothing in it is missing upstream, so neither command loses work):" -ForegroundColor Yellow
    Write-Host "    git -C `"$repoRoot`" branch $($backupRef.Token) main" -ForegroundColor Yellow
    if ($headName -eq 'main') {
        # --keep rather than --hard: it moves the pointer, updates only the files that differ, and ABORTS
        # on a local change it would overwrite. In the measured case the two trees were identical, so it
        # touches nothing at all -- and where they are not, aborting is the right answer from a script's
        # printed advice.
        Write-Host "    git -C `"$repoRoot`" reset --keep origin/main" -ForegroundColor Yellow
        Write-Host "  ('main' is checked out here, so the pointer moves with reset --keep -- not --hard, which this repo reserves to Dave.)" -ForegroundColor DarkGray
    } else {
        $whereNote = if ($headName -and $headName -ne 'HEAD') { " -- this tree is on '$(Get-DisplayRef -Ref $headName)'" } elseif ($headName -eq 'HEAD') { ' -- this tree is detached' } else { '' }
        Write-Host "    git -C `"$repoRoot`" branch -f main origin/main" -ForegroundColor Yellow
        Write-Host "  (nothing holds 'main' here$whereNote, so the pointer moves without touching a working tree.)" -ForegroundColor DarkGray
    }
    if ($backupRef.Note) { Write-Host "  $($backupRef.Note)" -ForegroundColor DarkGray }
}

# --- Step 6: the issues the PR declared it closes are actually closed -----------------------------
# Its own script, so this state-MUTATING logic (it comments and closes) is testable against a fake gh
# instead of only reachable through a full live ship -- and so the same check is usable on its own to
# repair bookkeeping after the fact. It never fails the ship: the merge already succeeded.
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify-resolved-issues.ps1') -Pr $pr -Repo $repo
if ($LASTEXITCODE -ne 0) { Write-Warning "the issue-closing check reported a problem -- verify by hand with: gh issue list --repo $repo --state open" }

# THE CLOSING LINE SAYS WHO FOLDED (issue #1792). On a stood-down fold the trunk is just as folded and
# the ship is just as complete -- but this checkout is one command short of matching it, and a closing
# line reading "folded on main" would be the last thing the operator sees and would say nothing about
# that. Same sentence, one clause different, so the two runs are told apart at a glance.
if ($foldStoodDown) {
    Write-Host "Done: PR #$pr shipped -- opened, CI green, merged, folded on main by whoever won the fold race (step 5c: two commands realign this checkout)." -ForegroundColor Green
} else {
    Write-Host "Done: PR #$pr shipped -- opened, CI green, merged, folded on main." -ForegroundColor Green
}

# --- Step 7: the remote branch, if nothing on GitHub is reaping it --------------------------------
# WHY THIS IS A READ AND NOT A FLAG (inbound #815, August 21, 2026). The merge above deliberately does
# NOT pass --delete-branch. The repo setting covers EVERY merge route -- this script, the web UI, another
# machine, another tool -- while the flag covers only the path it is passed on, and two mechanisms for one
# job is precisely the shape that let seven merged branches pile up in July 2026: two documents each named
# a different one and neither was in force. The flag also deletes the LOCAL branch, and on July 16, 2026
# it was measured leaving the checkout ON the merged branch, with the fold then running there.
#
# SO WHAT WAS ACTUALLY MISSING WAS REACH, NOT DOCUMENTATION. Measured on pickup: the setting is named in
# three places in the plugins, one with a paste-ready command -- and all three are setup checklists, read
# once at init, with nothing ever asking again. The reporting consumer had both plugins installed, the
# setting off, and 18 merged branches standing. This says it at the one moment it is true and cheap to
# fix: right after a merge that left a branch behind.
#
# NEVER FAILS THE SHIP, and stays quiet when the answer is yes. The merge has already happened; an
# unreachable gh, an older gh without the field, or a token without repo-read scope are all reasons to say
# nothing rather than to raise an alarm about somebody's tidiness.
$dbomRes = Invoke-NativeCapture -FilePath 'gh' -Arguments @('api', "repos/$repo", '--jq', '.delete_branch_on_merge')
if ($dbomRes.ExitCode -eq 0) {
    $dbom = (($dbomRes.Output | Out-String) -replace '\s', '')
    if ($dbom -eq 'false') {
        Write-Host "Note: '$repo' does not delete head branches on merge, so '$branchShown' is still on the remote. Switch it on once with:" -ForegroundColor Yellow
        Write-Host "  gh api -X PATCH repos/$repo -F delete_branch_on_merge=true" -ForegroundColor Yellow
        Write-Host "  (the local clone is a separate half -- scripts\task\prune-merged.ps1 reaps that, and deletes nothing it cannot prove is merged)" -ForegroundColor DarkGray
    }
}

# --- Step 8: what the NOT-required checks said (issue #1602) --------------------------------------
# THIS IS #831's REPORT, MOVED RATHER THAN REMOVED. Step 3 now blocks on the required checks only, so
# the non-required ones are still running when the merge goes -- and the question #831 was filed to
# answer, which check governed and what the tail cost, cannot be answered until they report. This is
# where it is answered. Nothing is skipped and nothing is downgraded to a guess: the same
# Get-CheckWaitReport, over the full payload, once the full payload exists.
#
# IT RUNS LAST, AND THE ORDER IS THE WHOLE SAFETY ARGUMENT. Everything owed to the trunk has already
# happened: the merge, the fold, its push, the trunk hand-back and the resolved-issues check. A merge
# without its fold is #1270's defect -- the branch's document stranded on 'main' with nothing saying
# so -- and this step waits on somebody else's CI, so putting it anywhere above the fold would put a
# multi-minute wait between the merge and the one thing that must follow it. Below the fold it can
# stall, be killed, or be abandoned by an operator who has read enough, and the trunk is already
# whole.
#
# SO IT NEVER FAILS THE SHIP, and that is not politeness -- it is the only correct exit code. The PR
# is merged and folded by the time this line runs; there is no outcome here that a non-zero exit
# would help with, and a red exit on a finished ship is exactly the signal that sends a later reader
# looking for a half-state that does not exist. A red non-required check is reported, in the wording
# it had at step 3, and the ship still reads as done.
#
# SKIPPED ENTIRELY WHERE STEP 3 WATCHED EVERYTHING. With no required check known, step 3 waited on
# every check exactly as it did before #1602 and printed the report there -- so there is nothing left
# to wait for and printing a second report would only claim a tail that never existed. That is the
# same line every other #1602 branch draws, and it keeps a repo with no ruleset out of this step
# completely.
if (-not $watchNarrowed) {
    # Deliberately silent: step 3 already said which check governed, over the same payload this step
    # would re-read. A line here would be noise on every ship in a repo with no ruleset.
} else {
    Write-Host "ship-pr: PR #$pr is merged and folded. Now reporting what the NOT-required check(s) said (#1602)." -ForegroundColor Cyan
    Write-Host "  Nothing below is owed to the trunk -- it is already whole. Ctrl+C here costs the report and nothing else." -ForegroundColor DarkGray

    $tailBegan = Get-Date
    # A WATCH RATHER THAN A READ, because a read would report 'pending' and call it a day -- which
    # loses precisely what #831 asked for. Measured September 8, 2026: `gh pr checks --watch` works
    # on a MERGED PR (exit 0), the checks living on the head commit, which the merge does not remove.
    # Not `--required`, obviously: this is the half step 3 did not watch.
    #
    # BOUNDED, AND THE BOUND IS THIS FILE'S OWN RULE RATHER THAN A NEW ONE (inbound #1179). That rule
    # is drawn for exactly this region: "this is the worse of the two places to hang -- the PR is
    # already MERGED by the time this line runs". Step 3's watch is deliberately unbounded because a
    # stall there blocks a merge that has not happened and is therefore visible in the PR; a stall
    # HERE leaves a finished ship holding a terminal open, with nothing for the operator to read and
    # no prompt to come back to.
    #
    # 1800s, AND IT IS SIZED OFF THE MEASUREMENTS RATHER THAN PICKED. $NativeCaptureNetworkTimeoutSeconds
    # (120) is far too short to reuse here -- it bounds a single git round trip, while this bounds a
    # wait on somebody else's CI. The tail this step exists to watch ran to 753s in #1602's own n=99
    # sample, and #831's n=100 measured `claude-review` at up to 23m 23s (1403s) end to end. 1800s
    # clears both with room and still ends the run, which is the whole requirement: this bound is not
    # a deadline anybody should meet, it is the difference between a report that gave up and a process
    # that never returns.
    $tailMaxWaitSec = 1800
    $tailChecks = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
        'pr', 'checks', "$pr", '--watch', '--interval', "$PollSeconds", '--repo', $repo) `
        -TimeoutSeconds $tailMaxWaitSec
    $tailChecks.Output | ForEach-Object { Write-Host $_ }
    $tailWaitedSec = [int][math]::Round(((Get-Date) - $tailBegan).TotalSeconds)
    # A TIMEOUT HERE IS NOT A FAILURE OF ANYTHING, and it must not read as one. The ship is complete;
    # what ran out is a report. Said before the report below, because the lines after it would
    # otherwise be read as facts about a payload this run never got to see.
    if ($tailChecks.TimedOut) {
        Write-Host "  The NOT-required check(s) had not finished within $(Format-CheckDuration -Seconds $tailMaxWaitSec) -- giving up on the REPORT, not on the ship (#1602)." -ForegroundColor DarkYellow
        Write-Host "  PR #$pr is merged and folded. Read them at your leisure:  gh pr checks $pr --repo $repo" -ForegroundColor DarkYellow
    }

    # Best-effort by construction, like every diagnostic in this file: a read that throws costs this
    # report and never the ship, which has already landed.
    $tailFactsJson = ''
    $tailRequiredJson = ''
    try {
        $tailFacts = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
            'pr', 'checks', "$pr", '--json', 'name,bucket,state,startedAt,completedAt,link', '--repo', $repo)
        if ($tailFacts.ExitCode -eq 0) { $tailFactsJson = $tailFacts.Output -join "`n" }
        $tailRequired = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
            'pr', 'checks', "$pr", '--required', '--json', 'name,bucket,state', '--repo', $repo)
        if ($tailRequired.ExitCode -eq 0) { $tailRequiredJson = $tailRequired.Output -join "`n" }
    } catch {
        $tailFactsJson = ''
        $tailRequiredJson = ''
    }

    # THE WAIT REPORTED IS THIS STEP'S OWN, not step 3's. Handing step 3's seconds here would double
    # count the required wait; handing this step's says what the tail actually cost after the merge,
    # which is the number #1602 was filed about. Get-CheckWaitReport's own 'X after the last required
    # check' clause is unchanged and is where the tail's real size is stated.
    $tailReport = $null
    if ($tailFactsJson) {
        # -PostMerge, BECAUSE THE MERGE HAS HAPPENED AND NOTHING HERE GOVERNED IT. Without it this
        # line reads `'claude-review' finished last and governed the merge (..., NOT required)` about
        # a merge that went minutes earlier precisely because it no longer waits for that check --
        # the opposite of what this step exists to report, in the one place the reader meets it.
        $tailReport = Get-CheckWaitReport -ChecksJson $tailFactsJson `
            -RequiredNamesJson $tailRequiredJson -WaitedSeconds $tailWaitedSec -PostMerge
    }
    if ($tailReport) {
        Write-Host "  $tailReport" -ForegroundColor DarkGray
    } else {
        Write-Host "  waited $(Format-CheckDuration -Seconds $tailWaitedSec) -- no readable check facts, so nothing to report about the tail" -ForegroundColor DarkGray
    }

    # AND THE FAILURE WORDING IS STEP 3's, VERBATIM, because it is the same fact about the same PR --
    # only later. The merge proceeding past a red non-required check is not new behaviour and was not
    # introduced here: Get-MergeBlockVerdict has returned Blocked = $false for it since #943, and
    # step 3 printed this same sentence before continuing. What #1602 changed is when the reader meets
    # it, so the sentence must not change with it.
    # `-and -not $tailChecks.TimedOut` IS LOAD-BEARING, not defensive noise. Invoke-NativeCapture
    # substitutes exit code 124 for a killed child precisely so the number and TimedOut tell the same
    # story -- which means a timeout arrives here as a non-zero exit, and without this clause the run
    # would announce that a check FAILED because a report ran out of time. TimedOut is the field to
    # read when certainty is needed, exactly as native-capture-lib says.
    if ($tailChecks.ExitCode -ne 0 -and -not $tailChecks.TimedOut) {
        $tailVerdict = $null
        try { $tailVerdict = Get-MergeBlockVerdict -RequiredChecksJson $tailRequiredJson -ChecksJson $tailFactsJson } catch { $tailVerdict = $null }
        if ($tailVerdict -and -not $tailVerdict.Blocked) {
            Write-Host "ship-pr: a check FAILED but the merge was not blocked -- $($tailVerdict.Reason)." -ForegroundColor Yellow
        } else {
            Write-Host "ship-pr: a NOT-required check FAILED after the merge -- PR #$pr is merged and folded regardless." -ForegroundColor Yellow
        }
        # THE AUTHORED REASON RIDES ALONG, the same relay #1103 added at step 3 and for the same
        # measured reason: eight issues were filed in this repo against a red `claude-review` whose
        # own diagnostic step had already printed the cause. That relay is worth MORE here, not less
        # -- this is now the only place the reader meets the failure at all. Shared with step 3
        # rather than copied; the filter argument is at the function.
        $tailFailedOther = @()
        if ($tailVerdict) { $tailFailedOther = @($tailVerdict.FailedOther) }
        Write-FailedCheckReasons -ChecksJson $tailFactsJson -Repo $repo -OnlyNames $tailFailedOther
        Write-Host "  Nothing here fixes it, and nothing here needs undoing: the ship is complete." -ForegroundColor Yellow
    } elseif (-not $tailChecks.TimedOut) {
        Write-Host "  Every check on PR #$pr is green." -ForegroundColor Green
    }
    # NO THIRD ARM ON PURPOSE. On a timeout the two lines above the report have already said what
    # happened and what to run; claiming green here would be the same overclaim the TimedOut guard
    # above exists to prevent, and repeating the giving-up sentence would be noise.
}

# THE LAST LINE OF THE MERGED ENDING, and deliberately the last line of the file: step 7's tail-check
# block above is conditional, so anything placed inside it would be absent from exactly the quiet,
# everything-green ship that is most likely to be closed out from memory.
if (Test-FunctionDefined 'Write-CloseOutReceipt') {
    Write-CloseOutReceipt -Cite "PR #$pr" -Bypass (Get-GateBypassNote -SkipLint:$SkipLint -SkipTests:$SkipTests)
}
