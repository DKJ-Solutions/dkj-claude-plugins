<#
.SYNOPSIS
    Creates (or idempotently reuses) a branch and writes the two files it works in: the cycle file and
    the deployment entry, plus the reference templates beside them.

.DESCRIPTION
    ONE SCRIPT PER CONCEPT (Dave, August 7, 2026). This used to be two: new-branch.ps1 made the
    branch and then ran new-changelog-entry.ps1 as a child process to write the files. That second
    name stopped being true on August 6, when the branch/ split gave it a step list to write as well,
    and again on August 7 when it gained the templates -- it described one of four outputs, and it was
    not a documented entry point: no skill named it, and nothing but this script ever called it.

    WHAT THE SPLIT WAS ACTUALLY BUYING, since it was not nothing. The inner script used `exit` as
    control flow -- on the trunk, on a missing branch-info.ps1, and on "the files already exist" --
    and running it as a child process is what kept those exits from killing the caller. Merging meant
    answering each one rather than deleting it:

      * the missing-branch-info pre-flight was ALREADY here, one copy above; the inner one was a
        duplicate and is gone;
      * the trunk refusal MOVED UP, in front of the checkout, which is strictly better: it now
        refuses before touching HEAD instead of after. It looks unreachable -- Test-BranchName
        rejects 'main' -- but that check only knows 'main' while the trunk is configurable, so a
        consumer whose trunk is 'master' can still reach it with -Name master. Deleting it as dead
        code would break exactly that consumer;
      * "the files already exist" was an `exit 0` that this script read as success and carried on
        from. It is a skip now, which is what it always meant.

    The injection-safe environment-variable handoff went with the process boundary: -Title and
    -Intent are parameters again, because there is no argv to requote across.

    Validation runs via the shared SSOT helper Test-BranchName (scripts/lib/branch-info.ps1):
      - Hard reject (exit 1): empty name, name 'main', or a name containing the substring 'final'.
      - Soft warn (proceed): unknown branch prefix -- the entry's type falls back to 'Chore' and
        open-pr later to the 'question' label. Validation is deliberately delegated to the consumer's
        table, so extended prefixes (Shopify's style/, liquid/, ...) simply work.

    THE BASE IS MEASURED, AND A STALE ONE IS REFUSED (inbound #1046, August 28, 2026; issue #1417,
    September 4, 2026). This script cut from whatever HEAD held and never asked. It counts how far the
    base is behind origin/<trunk> and, where a base is actually being CHOSEN, REFUSES rather than cuts
    -- with -SkipStaleBase as the one-flag valve, exactly as the fold carries -SkipTrunkCheck. Where the
    valve is used the count is still WARNED with, twice: before the checkout, and as the last line of the
    run, because everything this script prints in between buries the first copy. A repo with no
    origin/<trunk> ref is not asked, not warned and not refused, which is what keeps the script usable
    offline. It is measured only where a base is being chosen -- see the resume rule below, which settles
    that question first.

    WHY THIS REFUSES NOW, WHERE #1046 DELIBERATELY DID NOT. That report warned as its own first step and
    named the stronger option, holding back because this file reaches consumers by plugin UPDATE rather
    than by choice -- a refusal nobody asked for, on the script they are told to re-run to RESUME a
    parked branch. #1417 read that against the code and the second half does not hold: the whole base
    block is gated on `-not $resuming`, so the resume route never reaches this question and a refusal
    here cannot land on it. What is left is the operator cutting a NEW branch from a base they happened
    to be standing on -- and there the refusal costs nothing, because it fires BEFORE the checkout: no
    branch, no scaffold, no commit, nothing to unwind, and one `git pull --ff-only` resumes it. That is
    the same "a refusal costs nothing" property the fold cites (#1405), reached by a different route.

    AND THE LANE IS NOT THE PRECEDENT IT WAS READ AS. worktree-lane.ps1 does not refuse a stale base; it
    refuses a failed FETCH and then bases its worktree at origin/<trunk> outright, so it has no stale
    base to refuse. Its answer is to remove the choice, which this script cannot copy: it does not move
    HEAD for the operator. So the three scripts were never two answers to one hazard -- the hazard has a
    different shape in each -- and the lane passes -SkipStaleBase when it delegates here, because it has
    already chosen the base itself moments earlier.

    NO THRESHOLD, deliberately. Refusing only above N commits was considered and declined: the incident
    #1046 measured was a duplicate of a PR merged FOUR MINUTES earlier, which is a base one commit
    behind. A threshold reinstates exactly the failure it would be added to soften.

    IT RESUMES A BRANCH THAT EXISTS ONLY ON ORIGIN (issue #1139, August 30, 2026). "Already exists" used
    to mean refs/heads/<name> and nothing else, so on a machine that had not fetched a parked branch into
    a local ref the answer was no and `git checkout -b` forked a second branch of that name at the current
    base -- carrying none of the parked work, printing the same clean run, writing a byte-identical
    scaffold. That is this workflow's own cross-device handoff (#900 pushes by default, cycle-autopark
    keeps it current), so the script documented as idempotent was the one blind to it; worktree-lane.ps1
    inherited it whole through its step-4 delegation. Both namespaces are now read, BEFORE anything is
    said about a base: local -> check out; origin only -> create AT THE REMOTE TIP with tracking, and say
    in so many words that this is a resume of parked work rather than a new branch. The remote-tracking
    ref is read from disk and never fetched for on its own account, so this stays usable offline.

    AND A BRANCH THAT EXISTS IN BOTH PLACES IS COMPARED (issue #1439, September 5, 2026). #1139 covered
    the branch that exists ONLY on origin; the local ref pointing at an OLDER tip than origin's was still
    read as a plain "already existed -- checked out". Two sessions then built the same branch end to end
    from the same parked commit, each running the full gate, and found out at `git push`. Nothing else
    in the workflow reads that ref: the claim rule needs an issue, `git status` is local and prints the
    same line for "in sync" as for "never fetched", and prune-merged -IncludeRemote is for branches you
    are not standing on. So the local route now counts refs/heads/<name>..refs/remotes/origin/<name> off
    the fetch the base measurement has already done, and where origin is ahead it names the count and the
    remote tip's author and subject -- 'park: ... (all outstanding work)' by somebody else being the line
    that separates a collision from a fast-forward of your own autopark. It WARNS, twice like the others,
    and that is not a position waiting to be hardened the way #1046's was: the legitimate divergence sits
    on the intended happy path, so a refusal would land on the route this script exists to serve.

.PARAMETER Name
    The branch name, form <prefix>/<short-name> (e.g. feat/new-plugin).

.PARAMETER Title
    (Optional) the branch title -- the human-readable name of the change, written into the
    entry's 'Branch title' section. That is where the heading's old job went: the entry's H3
    names the BRANCH. Left empty, the section is left empty and open-pr refuses the PR until somebody
    writes it, which is strictly better than a placeholder that can be ticked past.

    AND IT IS THE PR TITLE (#506, August 7, 2026). open-pr.ps1 composes '<type>: <this>' from the entry
    rather than taking a title on the command line, so this is typed once and cannot disagree with
    itself. Write it WITHOUT a 'feat:'/'fix:'/'docs:' prefix -- the branch name already carries the type
    and open-pr puts it in front.

.PARAMETER Intent
    (Optional) the direction of the branch -- what still needs to happen and where you left off.
    Recorded in the branch's development document as the opening paragraph of its FIRST PHASE (PLAN), without a heading
    of its own; typically given together with -Park when parking a branch for later / another device (#162).
    It deliberately does not touch the DEPLOY section: an intent is a status, and that section's text folds
    verbatim into CHANGELOG.md.

    It sat ABOVE the phases until #908 (August 26, 2026), where the document's own guidance says nothing
    branch-specific may go and where the CI gate refused it once the entry was written.

.PARAMETER RepoRoot
    (Optional) the tree to create the branch and its document in, when that is NOT the tree you are
    standing in. Used by worktree-lane.ps1 to open a branch inside a lane worktree. Omitted (the
    normal case): unchanged behaviour -- CLAUDE_PROJECT_DIR, else the git root.

.PARAMETER SkipStaleBase
    (Optional switch) cut the branch anyway from a base that is behind origin/<trunk>, printing the
    warning instead of refusing. The one-flag valve for the refusal above, and the counterpart of the
    fold's -SkipTrunkCheck. Named for this script's own noun rather than for the fold's: everything here
    already says "base" (Base is current, Base not compared, the stale-base warning), and the two
    scripts are asking about different things -- the fold about the trunk it is standing on, this one
    about the base a new branch is being cut from. worktree-lane.ps1 passes it when it delegates here,
    because it has already based its worktree at origin/<trunk> itself.

.PARAMETER NoPush
    (Optional switch) leave the branch purely local: nothing committed, nothing on origin. The escape
    valve for the rare branch that must not be visible yet -- since #900 the creation push is what
    happens by default, and this is the only way to opt out of it.

.PARAMETER Park
    (Optional switch) ACCEPTED AND DOES NOTHING SINCE #900 (August 26, 2026): what it used to ask for is
    now the default, so a run that names it gets exactly what a run that does not get. Kept rather than
    removed because this script is mirrored into every consumer's plugin cache, where a `-Park` typed
    from a doc, a lens or a habit would otherwise fail on a parameter that is no longer there. It prints
    one line saying so, and -NoPush is the switch that now changes something.

.PARAMETER Resolves
    (Optional) the issue number(s) this branch is being cut to fix, as a string: -Resolves '331,332' (a
    leading '#' and whitespace/semicolon separators are also accepted; ConvertTo-IssueNumberList parses
    it). NOT a declaration open-pr.ps1 will read later -- that gate takes its own -Resolves, separately,
    when the PR opens.

    WHAT THIS BUYS (issue #1409, the gap #1282 left open). Get-TargetIssueWarnings already runs at
    open-pr time, which is the LAST step -- a warning there has nothing left to save, because the branch,
    its commits, its reviews and its test runs are already spent. Passed here, the same check runs BEFORE
    the checkout, so a branch cut to fix an issue another PR already closed is caught before any of that
    cost is paid. Same shape as the stale-base check above: it WARNS and does not refuse -- a shared
    number, a reopened issue, or a rival PR abandoned mid-flight must not wedge a real branch -- and it is
    printed twice, here and as the last line of the run, for the same reason the stale-base warning is.

    NARROWS THE WINDOW RATHER THAN CLOSING IT. It only ever sees what -Resolves is given; an issue decided
    later, or only named in -Intent text, is invisible to it -- there is no PR body yet to scan. And it
    needs `gh` and a readable repo name (scripts\repo-config.ps1's Get-RepoName): where either is missing,
    it says so and is skipped, exactly like every other optional gh call in this workflow.

.EXAMPLE
    ./scripts/task/new-branch.ps1 -Name feat/new-plugin -Title "New domain plugin"

.EXAMPLE
    ./scripts/task/new-branch.ps1 -Name feat/spotify-dashboard -Title "Spotify dashboard" -Intent "Skeleton + routing done; next: wire the API client."

.EXAMPLE
    ./scripts/task/new-branch.ps1 -Name fix/1402-something -Title "Fix something" -Resolves 1402
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Title = "",
    [string]$Intent = "",
    [string]$Resolves = "",
    # Explicit override of the repo root, for a caller that creates the branch in a tree OTHER than
    # the one it is standing in -- worktree-lane.ps1 opening a lane is the case this exists for. Same
    # parameter, same reasoning and same name as fold-changelog-entry.ps1 has carried since #101.
    #
    # Deliberately a parameter rather than the caller setting CLAUDE_PROJECT_DIR to the target tree:
    # that was tried first and the source-repo guard refused it, correctly. The guard resolves the repo
    # being operated on from CLAUDE_PROJECT_DIR, so pointing that at the lane made THIS file -- sitting
    # in the primary checkout -- look like a released copy run from outside the repo it maintains. The
    # env var answers "which repo is the session working on"; this parameter answers "which tree does
    # this one call write to", and they are not the same question.
    [string]$RepoRoot,
    # The valve on the stale-base refusal (issue #1417). Deliberately NOT named -SkipTrunkCheck after the
    # fold's: that script asks about the trunk it is standing on, this one about the base a new branch is
    # cut from, and every other line in this file calls that thing the base. A shared name would make two
    # different questions look like one switch.
    [switch]$SkipStaleBase,
    # The escape valve, and its inverse used to be the switch (see .PARAMETER NoPush / Park). Named for
    # what it PREVENTS rather than as -Local or -Offline: the one thing it turns off is the push, and a
    # reader who wants the branch off the remote is looking for that word.
    [switch]$NoPush,
    [switch]$Park
)

$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Repo root -- dual context: if a consumer runs the shared plugin mirror, CLAUDE_PROJECT_DIR
# supplies its repo root; in the workshop root (or outside a session) it falls back to the git
# root. This way the SAME file works in both locations, and the root copy and the plugin mirror
# stay byte-identical (guarded by the shared-scripts drift lint).
# -RepoRoot, when supplied, wins over both -- see the param comment above. Note: PowerShell variable
# names are case-insensitive, so $RepoRoot (the param) and $repoRoot are the same variable, which is
# why it can be passed straight back in as the override. Same shape as fold-changelog-entry.ps1,
# deliberately, so the two read alike.
#
# JUDGED THROUGH THE SHARED SEAM (#1917), AND THIS LINE HAS NOW BEEN REPAIRED TWICE. #1913 judged it
# INLINE here, in this one file, because this is the file that reported the symptom; #1917 then found
# the same unjudged form on 37 call sites and moved the judgement into check-report-lib, beside the
# dual-context resolution that already existed there. Resolve-RepoRootOrFail carries the same
# three-source precedence, so the `if (-not $repoRoot)` guard that used to wrap this is gone --
# passing the param as -Override IS that guard.
#
# WHAT #1913 MEASURED IS WHY THIS MATTERS IN A PLACE NOBODY RUNS BY HAND, and it is kept here rather
# than lost to the merge: a suite exercises this script as a child process dozens of times, sixteen
# lanes at a time under the test gate, and a git that fails to start once under that load lands
# exactly here. That was #1913 -- red under the gate, green standalone, exit 1, no document -- and the
# reason the report could name no cause is that the old line had none to give. Judging it does not
# make git more reliable; it makes the one-in-many failure say which of the two it was.
# THE DOT-SOURCE IS GUARDED HERE AND UNCONDITIONAL EVERYWHERE ELSE (#1913 + #1917), and the asymmetry
# is deliberate rather than untidy. #1913's inline refusal fired BEFORE a single lib was loaded, which
# is a real property: this is the first statement of the script, and a refusal that itself needs a file
# to be present cannot report a tree where that file is missing. Folding the wording into the shared
# seam would have dropped it silently, so it is kept -- for THIS file, which is the one #1913 measured
# and the one whose suite pins it.
#
# The fallback is deliberately NOT a second copy of the seam's judgement: it says the same three things
# in the fewest lines that can be checked, and anything richer belongs in the seam where all 37 callers
# get it.
$crLib = Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1'
if (Test-Path -LiteralPath $crLib -PathType Leaf) {
    . $crLib
    $repoRoot = Resolve-RepoRootOrFail -Override $repoRoot -ScriptName 'new-branch.ps1' `
        -Consequence 'Nothing was created: no branch, no document, nothing on origin.'
} elseif (-not $repoRoot) {
    $prevEapRoot = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $topLevel = & git rev-parse --show-toplevel 2>&1
        $topLevelCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEapRoot }
    $repoRoot = if ($topLevelCode -eq 0) { "$(@($topLevel) | Select-Object -First 1)".Trim() } else { '' }
    if (-not $repoRoot) {
        Write-Host "new-branch cannot run -- it could not work out which repository it is in." -ForegroundColor Red
        Write-Host "  git rev-parse --show-toplevel exited $topLevelCode here and named no repository root." -ForegroundColor Red
        Write-Host "  It said: $((@($topLevel) -join ' ').Trim())" -ForegroundColor Red
        Write-Host "  Nothing was created: no branch, no document, nothing on origin. Run this from inside" -ForegroundColor Red
        Write-Host "  the checkout, or set CLAUDE_PROJECT_DIR to its root, and run again." -ForegroundColor Red
        exit 1
    }
}

# Pre-flight (#86): this script relies ONLY on scripts\lib\branch-info.ps1 in the consumer's repo
# root (no gh, and repo-config is optional below). If that is missing -- typically on a clean
# consumer -- stop with a clear pointer instead of a raw dot-source error.
$branchInfoPath = Join-Path $repoRoot 'scripts\lib\branch-info.ps1'
if (-not (Test-Path -LiteralPath $branchInfoPath)) {
    Write-Error "new-branch cannot run -- missing repo-owned file: $branchInfoPath (Get-BranchInfo / Test-BranchName / the branch prefix table). This file is repo-specific and belongs in the consumer's repo root. Create it (the specialists-init bootstrap lays down a VUL-IN scaffold, or take an existing consumer / the source repo as a model) and run again afterward."
    exit 1
}
. $branchInfoPath
. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
# THE ALREADY-DONE CHECK'S PURE HALF (issue #1409). Shared with the plugin mirror, like the two libs
# beside it -- ConvertTo-IssueNumberList and Get-TargetIssueWarnings are what -Resolves below runs
# against, before anything else in this script has read a single line of it.
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
# AND THE SEAM READER (inbound #967). The guidance this script writes into the document states WHERE a
# relative link in the DEPLOY section has to resolve from, and that is the changelog's directory -- a seam,
# not the repo root, since #914 made it isolate-by-default. Resolved in the script and passed in, the way
# cut-release, fold-changelog-entry and adopt-workflow-folder all read it: the computed
# default needs a repo root, and a lib that goes looking for one can find the wrong tree.
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')

# THE NATIVE-COMMAND CAPTURE HELPER, dot-sourced HERE rather than inside the push block where it sat until
# inbound #1046. Two callers now need it and the first one runs long before the push: the stale-base check
# below, which asks git two questions before HEAD is touched. Not repo-owned and dependency-free, so
# loading it early costs a file read and changes nothing else. Why every git call in this repo goes through
# it: the lib's own header (the #96/#97/#107 stderr-under-EAP=Stop lesson).
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# THE REMOTE-AHEAD NOTE COMPOSER (issue #1450), shared with open-pr.ps1 -- see that lib's own header for
# why this moved out of here rather than being copied a second time.
. (Join-Path $PSScriptRoot '..\lib\remote-ahead-lib.ps1')

# THE COMMIT-ABILITY PROBE (inbound #1867), for the refusal below the branch-name validation. Dot-sourced
# GUARDED, unlike the four above: this file is the workflow's most-mirrored script, and a plugin payload
# built before this lib existed must degrade to the old behaviour rather than fail to load at all. The
# refusal itself is additionally gated on Test-FunctionDefined, which covers the narrower case of a lib
# that is present but predates Test-GitCanCommit.
$identityLib = Join-Path $PSScriptRoot '..\lib\git-identity-lib.ps1'
if (Test-Path -LiteralPath $identityLib -PathType Leaf) { . $identityLib }

# The repo-owned fallback type (#410) -- OPTIONAL, unlike branch-info.ps1 above. repo-config.ps1 may
# be absent (a repo that never needed it) or may fail to load (a syntax error in someone's edit);
# neither is a reason to stop, because every string it supplies has a working default. So: Test-Path,
# then a try/catch that degrades to a warning.
#
# The local name is deliberately $stubFallbackType, NOT $EntryFallbackType: repo-config backs each
# function with a $script: variable of that name, and at script top level the local and script scopes
# are the same -- so a same-named local would overwrite the dot-sourced value before the function is
# ever called, and the configured type would silently read back as the default. That is the collision
# documented on $RepoRoot/$repoRoot in fold-changelog-entry.ps1.
#
# ONLY THE TYPE IS READ HERE. The three prose placeholders moved to entry-scaffold-lib.ps1 when
# open-pr.ps1 gained the gate that refuses an entry still carrying them -- writer and guard must not
# be able to disagree about the wording. The fallback type stays because it is a changelog TYPE rather
# than scaffold prose: 'Chore' is a legitimate final value and can never be evidence of an unedited entry.
$stubFallbackType = 'Chore'

# THE ALREADY-DONE CHECK'S REPO NAME (issue #1409). Deliberately NOT $repoName: repo-config.ps1 backs
# Get-RepoName with $script:RepoName, and at script top level a same-named local IS that script-scope
# variable (PowerShell variable names are case-insensitive) -- exactly the $stubFallbackType /
# $EntryFallbackType collision documented above, one function down. $ghRepoName cannot collide with it.
$ghRepoName = ''

$configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $configPath) {
    try {
        . $configPath
        if (Test-FunctionDefined 'Get-EntryFallbackType') {
            $v = Get-EntryFallbackType; if ($v) { $stubFallbackType = $v }
        }
        if (Test-FunctionDefined 'Get-RepoName') {
            $ghRepoName = Get-RepoName
        }
    } catch {
        Write-Warning "scripts\repo-config.ps1 could not be loaded ($($_.Exception.Message)) -- writing the development document with the built-in default wording."
    }
}

# Validation via the shared SSOT helper -- no inline repetition of the hard-reject rules. It runs on the
# name AS GIVEN: this script does not complete or rewrite the name (see the version-suffix note below), so
# what Test-BranchName sees is exactly what the branch will be called.
$check = Test-BranchName -Branch $Name
if (-not $check.IsValid) {
    Write-Error "new-branch cannot run -- invalid branch name '$Name': $($check.Reason)"
    exit 1
}
if (-not $check.IsKnown) {
    Write-Warning "Unknown branch prefix in '$Name' -- the entry's type falls back to '$stubFallbackType', open-pr later to label 'question'. Classify manually if needed."
}

# THE TRUNK REFUSAL, AND IT RUNS BEFORE THE CHECKOUT. As a separate script this could only fire after
# HEAD had already moved; merged, it fires while nothing has been touched. Test-BranchName already
# rejects the literal 'main', so in a repo whose trunk IS main this is unreachable -- but the trunk is
# configurable (Get-TrunkBranchName) and that check is not, so a consumer on 'master' reaches it with
# -Name master. That is why it is a guard rather than dead code.
$trunk = Get-BranchTrunkName
if ($Name -eq $trunk) {
    Write-Host "'$Name' is the trunk - create a branch instead." -ForegroundColor Red
    exit 1
}

# --- CAN THIS CHECKOUT COMMIT AT ALL? REFUSED BEFORE ANYTHING IS TOUCHED (inbound #1867) ------------
#
# THE FAILURE THIS REPLACES. On a machine with no usable git author identity every commit fails with
# exit 128, and the first one to do so is this script's own park, several hundred lines below -- after
# the branch has been checked out, HEAD has moved and the branch document has been written. The run
# dies mid-way and leaves a local branch with an uncommitted document sitting on it: a half-state a
# later session has to unpick, for a condition that was knowable before a single ref was created.
#
# WHY HERE, beside the trunk refusal, and not at the park. Same reasoning that block gives for itself:
# a guard that can only fire after HEAD has moved is not a guard. This costs one local `git var` and
# runs while nothing has been touched -- no fetch, no checkout, no file.
#
# WHY IT REFUSES WHERE check-git-identity.ps1 ONLY WARNS. That script reports a fact about the machine
# and is invoked by a SessionStart hook, which must never block a session; this one is about to create
# things. The session check speaks first and this is the backstop for a session that never saw it -- a
# consumer whose plugin is not installed, a script run outside a session, a machine repaired halfway.
#
# NOT -SkipStaleBase-style OPTIONAL, deliberately: there is no legitimate run on the far side of it.
# Every path through this script commits, so a valve would only let a caller choose the exit 128.
if (Test-FunctionDefined 'Test-GitCanCommit') {
    if (-not (Test-GitCanCommit -RepoRoot $repoRoot)) {
        # THE NUMBER IN THIS SENTENCE IS THE GUARD'S OWN, READ RATHER THAN RETYPED (issue #1932).
        # Test-GitCanCommit returns a bool, so nothing here sees an exit code -- and this message used to
        # state '128' as a literal, which reads as an assertion about a measurement this block never made.
        # It was not one: since #1920 that function refuses ONLY on git's own 128 and returns $true for
        # every other non-zero, so this branch is unreachable at any other code and the number was sound.
        # What was wrong is WHERE it came from -- a third hand-typed copy of a value the lib names as a
        # constant precisely because two readers already have to agree on it (the function itself, and
        # new-branch.tests.ps1's (y) fixture sanity assert, which pins git's side of the number).
        #
        # WHY NOT THE REPAIR #1932 PROPOSED. Returning the code alongside the verdict is a contract change
        # to a function called from a SessionStart hook, check-git-identity.ps1, its plugin mirror and
        # here -- to obtain a value that is already a named constant one dot-source away. Reading that
        # constant makes all three readers the same number, and costs the contract nothing.
        #
        # AND WHERE THE LIB DOES NOT SUPPLY IT, NO NUMBER IS CLAIMED. The dot-source above is guarded for
        # a mirror built before that lib existed, and one from between inbound #1867 and #1920 carries
        # Test-GitCanCommit WITHOUT the constant -- which is exactly the payload whose refusal fires on any
        # non-zero, and the only one where 'exits 128' would be the unproven claim #1932 was filed about.
        # Get-Variable rather than a bare $script: read, so an absent constant is a $null instead of a
        # throw under a caller that has set StrictMode.
        $identCodeVar = Get-Variable -Name 'GitAuthorIdentityUnknownExitCode' -ErrorAction SilentlyContinue
        $identStateNote = 'did not name an author here'
        if ($identCodeVar -and $null -ne $identCodeVar.Value) { $identStateNote = "exits $($identCodeVar.Value) here" }
        Write-Host 'new-branch: this checkout has no usable git author identity -- it cannot commit.' -ForegroundColor Red
        Write-Host "  ``git var GIT_AUTHOR_IDENT`` $identStateNote, which is exactly the state ``git commit`` refuses" -ForegroundColor Red
        Write-Host '  in. Nothing was created: no branch, no document, nothing on origin. Set both and re-run:' -ForegroundColor Red
        Write-Host '    git config --global user.name  "<your GitHub login>"' -ForegroundColor Red
        Write-Host '    git config --global user.email "<the address on that account>"' -ForegroundColor Red
        Write-Host '  (Drop --global to set it for this checkout only.)' -ForegroundColor Red
        exit 1
    }
}

# --- THE VERSION SUFFIX IS NOT COMPLETED HERE, AND THAT IS DELIBERATE (Dave, September 3, 2026) -----
#
# From August 23, 2026 this script appended '-v1' to any name carrying no '-v<N>' suffix, so a second
# development cycle on the same subject would keep the name and bump the number. In 209 branches that
# reached a merge with the suffix, not one was ever bumped to '-v2': the completion served a case that
# had not occurred while charging every caller for it. It was also the direct cause of inbound #1224 --
# a consumer wrapping this script for a branch whose name it does NOT own (a Dependabot PR branch) had a
# SECOND branch, '<their-name>-v1', created, committed to and pushed, leaving the entry on a branch the
# pull request does not point at.
#
# So the name is used exactly as given. A '-v<N>' suffix is still valid and still the honest way to say
# "another round of this" -- it is what the 'final' refusal in branch-info.ps1 points the caller at -- it
# is simply TYPED now, never added for you. Nothing scans for the lowest free number; nothing rejects
# '-v2'. new-branch stays idempotent: a rerun on the same name RESUMES that branch, which is what the
# new-branch skill and the -Park flow rely on.
#
# DO NOT RESTORE THE COMPLETION. The mirror-image rule -- a written ban on the '-v2' suffix -- was retired
# on August 6, 2026 for its own reasons; this one is retired now for the reasons above. A scaffolder that
# rewrites the name it was handed is exactly the shape that broke #1224.

# --- THE BASE THIS BRANCH IS CUT FROM, MEASURED AND REPORTED (inbound #1046) -----------------------
#
# worktree-lane.ps1 and this script meet the SAME hazard -- a base that is behind origin -- and until now
# they answered it in opposite ways. The lane fetches and bases its worktree on origin/<trunk>, refusing
# outright when the fetch fails: "a lane must not be based on a stale trunk." This script ran
# `git checkout -b` from whatever HEAD happened to be and never looked, in a run that reaches origin
# moments later to push -- so the remote was already in hand when the base was picked.
#
# WHAT THAT COST, measured in a consumer with two sessions on one board: a branch cut from a trunk 17
# commits behind origin/main, to fix an issue the other session had closed by a merged PR FOUR MINUTES
# earlier. The result was a complete duplicate of already-merged work -- branch, commit, PR, every gate
# green on both -- found only when the PR sat without a CI check and the run list was read by hand. The
# claim step does not catch this and it looks like it should: `gh issue edit <n> --add-assignee @me`
# succeeds silently on a CLOSED issue.
#
# THE MEASUREMENT IS Get-TrunkGap's AND IS NOT REPEATED HERE (issue #1416). The ref probe, the fetch, the
# HEAD..origin/<trunk> count and the fresh-versus-last-seen distinction all live in entry-scaffold-lib.ps1,
# where the fold's refusal reads them too -- and the reason for each of those four choices lives there with
# them rather than being restated at every call site. This block WAS that function's first draft: the
# #1405 repair lifted the shape out of here and cited it, which left two copies of one measurement
# standing side by side until this call replaced the inline one. What stays here is the half that is
# genuinely this script's -- what it does with the number.
#
# IT REFUSES SINCE #1417, AND THE REFUSAL IS BELOW rather than here, because what it needs -- whether a
# base is being CHOSEN at all -- is not settled until the resume probe has run. #1046 warned instead and
# named the stronger option; what kept it a warning was that this file is mirrored into every consumer's
# plugin cache and arrives by plugin UPDATE rather than by choice, the same reasoning the version-suffix
# block above gives for keeping its rule out of Test-BranchName. That argument survives as the VALVE
# (-SkipStaleBase) and not as the answer: the sentence it rested on -- "the script they are told to re-run
# to resume" -- is about a route the refusal cannot reach.
#
# AND THE WARNING STILL SAYS IT TWICE where the valve is used -- there, and as the LAST line of the run.
# That repeat is the whole difference between a warning that works in this script and one that does not:
# the scaffold, the commit and the push all print AFTER this point, so a single line at this depth is
# off-screen by the time the run ends. The bottom copy is the one a reader actually sees. Without the
# valve there is no run to bury it, which is the other half of why refusing is the better answer here.
#
# -FetchAllRefs IS LOAD-BEARING HERE, not thoroughness. Get-TrunkGap narrows its fetch to the trunk by
# default, which is right for the fold and wrong for this script: the resume question below reads
# refs/remotes/origin/$Name off the back of THIS fetch, and a narrowed fetch never brings that ref into
# existence -- so a branch parked from another device would go unseen and #1139 would reopen silently, in
# a run where both halves look correct. The suite's parked-branch fixture is what holds this switch here.
#
# THE FETCH IS THE ONE COST ADDED TO A ROUTINE RUN. worktree-lane already pays it on every lane, and
# Get-TrunkGap gates it on a ref that only exists in a repo with a reachable remote in its history, so the
# repos that cannot answer the question pay nothing.
#
# AND IT IS STILL PAID EVEN THOUGH claim-issue.ps1 JUST PAID IT (issue #1860), which is a decision rather
# than an oversight. That script fetches the same remote for its parked-fix scan (#1853) and runs
# immediately before this one by design -- the claim is the OPENING of the work, so new-branch follows in
# the same turn with only the issue read between them. Skipping this fetch on that one would save ~700ms
# and blind the two probes below it: the resume question reads refs/remotes/origin/$Name (#1139) and the
# remote-ahead note reads how far it has moved (#1439), and both exist to see a push made SECONDS ago by
# another session. This suite's own cases (v) and (y1) reproduce exactly that and refuse the trade.
#
# WHAT -RecentFailureSeconds DOES BUY is the half that costs nothing: where the fetch claim-issue just
# made FAILED, this one reports that failure instead of waiting out a second full network bound. A failed
# attempt refreshed no ref, so nothing above is blinded by standing on it -- and a session whose first two
# steps each stall for two minutes has nothing on screen to say why.
#
# THE WINDOW IS THE LIB'S CONSTANT, NOT A NUMBER TYPED HERE. Two hand-typed copies of one policy is what
# #1194 measured drifting inside a day, and the value is a claim about how long an outage may be assumed
# to persist -- which belongs with the mechanism that acts on it.
#
# GIT'S FETCH OUTPUT IS CAPTURED AND DELIBERATELY NOT PRINTED. Get-TrunkGap keeps stderr rather than
# discarding it -- issue #1313 measured that a failing fetch leaks no credential, and its callers need
# git's own diagnosis -- and hands it back in .Output. This caller does not read it: nothing here shows
# git's progress, and the warning below already says the fetch failed and that the real gap may be larger,
# which is everything a reader can act on.
$staleBaseNote = ''
$gap = Get-TrunkGap -RepoRoot $repoRoot -Trunk $trunk -FetchAllRefs -RecentFailureSeconds $RemoteFetchRecentFailureSeconds
# THE CARRIED REASON, PRINTED ONCE (issue #1860). .Fresh already decides which sentence the warnings
# below use, and it cannot say WHY: "a fetch 12s ago failed and was not retried" is exactly the line a
# reader needs to tell a stale reading from a broken credential, and it is the one thing a skip knows
# that this run could not have found out for itself. Git's own lines stay in .Output, unprinted here as
# they always were.
if ("$($gap.FetchNote)") {
    Write-Host "Base: $($gap.FetchNote) -- the refs compared here may be behind origin/$trunk." -ForegroundColor DarkGray
}
# .Measured IS THE GATE FROM HERE ON, where this block used to carry its own rev-parse exit code. It is
# $false for a missing refs/remotes/origin/<trunk> -- the reachable case, and the one this line names --
# and also for the exotic one where that ref exists and `rev-list HEAD..` still cannot answer, on an
# unborn HEAD. Both leave the question unasked, which is what the sentence reports.
if (-not $gap.Measured) {
    Write-Host "Base not compared: this repo has no $($gap.Ref) (no origin, or never fetched)." -ForegroundColor DarkGray
}

# --- RESUME OR CUT? ASKED BEFORE ANYTHING IS SAID ABOUT A BASE (issue #1139) -----------------------
#
# THE BUG THIS ANSWERS. Until August 30, 2026 this script asked ONE ref -- refs/heads/$Name -- and read
# "no" as "create it". refs/heads/ is the LOCAL namespace, so on a machine that had not yet fetched a
# parked branch into a local ref the answer was no, and `git checkout -b` cut a second, unrelated branch
# of the same name at the current base. The parked branch's commits were not in it.
#
# WHY THAT IS WORSE HERE THAN AN ORDINARY LOCAL/REMOTE SLIP. The parked branch IS this workflow's
# cross-device handoff: since #900 this script pushes by default so the branch is reachable from another
# device, and the cycle-autopark Stop hook keeps it current on origin until a PR publishes it. So the
# workflow actively produces branches whose only copy is on the remote -- and the script documented as
# idempotent, the one you are told to re-run to resume, was the one that could not see them.
#
# AND NEITHER HALF OF THE RUN LOOKED WRONG. A clean run is what "idempotent" promises, and the scaffold
# written into the fork is BYTE-IDENTICAL to the one already on the parked branch, because the same
# script wrote both. What is missing is the branch's WORK, and there is nothing on screen about work.
# worktree-lane.ps1 inherited the whole failure: its step 4 delegates here with the lane as -RepoRoot,
# and its step 3 has already added that worktree DETACHED AT origin/<trunk> -- so the fork was based on
# the trunk and the lane reported 'Lane open' exactly as on a genuine new branch.
#
# IT RESUMES AT THE REMOTE TIP AND SAYS SO LOUDLY, rather than refusing and printing the git command.
# Both are honest and the report left the choice open; resuming is what wins here because this script is
# the documented resume tool for a handoff the workflow creates on its own, so a refusal would put a
# hand-typed `git branch --track` on the intended happy path. What the report actually rules out is a
# SILENT adoption -- an assignee is a claim rather than a locked door in this repo, and a script that
# quietly adopts somebody else's remote branch makes that claim unreadable. Naming it is what keeps it
# readable, so the lines below say which of the three things happened and what to type if the operator
# meant a new branch instead.
#
# THE LOCAL QUESTION GATES THE NETWORK ONE, exactly as Get-TrunkGap does above: refs/remotes/origin/
# $Name is a remote-TRACKING ref, read from disk and never fetched for on its own account. It is fresh
# here because the base measurement above has just fetched wherever there was an origin to fetch from --
# and fetched EVERY ref, which is what -FetchAllRefs is for and the whole reason this line can trust what
# it reads; where there was no origin, this reads whatever the last fetch left and the script stays
# usable offline.
$localRef  = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'rev-parse', '--verify', '--quiet', "refs/heads/$Name") -DiscardStderr
$remoteRef = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'rev-parse', '--verify', '--quiet', "refs/remotes/origin/$Name") -DiscardStderr
$branchExists   = ($localRef.ExitCode -eq 0)
$branchOnOrigin = ((-not $branchExists) -and ($remoteRef.ExitCode -eq 0))
$resuming       = ($branchExists -or $branchOnOrigin)

# --- AND IS THE BRANCH YOU ARE RESUMING BEHIND ITS OWN REMOTE HEAD? (issue #1439) ------------------
#
# THE DUPLICATE SIGNAL NOTHING READ. Two sessions built feat/plugin-policy-precedence in full -- both
# from the same parked commit, both running the lint gate and all 69 suites, both committing -- and
# neither learned of the other until `git push` was rejected at the very end. The first session had
# parked its finished work on origin ('park: ... (all outstanding work)', under a different git
# identity); the second stood on a local ref still pointing at the older tip they had both started from.
#
# EVERY EXISTING GUARD LOOKS SOMEWHERE ELSE. The claim rule needs an issue to claim and there was none.
# The branch check at the start of an assignment reads `git status`, which is local: with no fetch it
# printed '## <branch>...origin/<branch>' with no ahead/behind marker, which is the same line as "in
# sync". prune-merged -IncludeRemote, which the orchestrator lens names as the way to find parked
# branches, is for branches you are NOT on. And cycle-autopark makes this MORE likely rather than less,
# because it is the thing that puts the other session's work on the shared ref without anybody asking.
#
# THE MEASUREMENT COSTS NO NETWORK CALL HERE, which is why this is the place rather than the one the
# report inferred. Get-TrunkGap ran with -FetchAllRefs a few lines up -- load-bearing already, for the
# resume probe -- so refs/remotes/origin/$Name is on disk and as fresh as this run can make it. All that
# is added is a rev-list against a ref that has just been refreshed.
#
# ONLY ON THE LOCAL-REF ROUTE. $branchOnOrigin creates the branch AT the remote tip, so its gap is 0 by
# construction, and a fresh cut has no remote head to be behind at all.
#
# IT WARNS RATHER THAN REFUSING, and unlike the stale-base check above that is not a position waiting to
# be hardened: a legitimate divergence exists on the intended happy path -- your OWN autopark from
# another device, which you then fast-forward. This script is the documented resume tool for exactly
# that handoff, so refusing would put a hand-typed `git pull` in the middle of the route it exists to be.
function Write-RemoteAheadRepeat {
    <#
        The second copy of the divergence warning, as a function rather than as a repeated `if`, because
        the run has TWO ends and only one of them was reachable in the case this check exists for.

        THE SUITE IS WHAT FOUND THIS. A resume of a branch whose remote head has moved cannot push: the
        creation push at the foot of this script is a non-fast-forward, Invoke-GitPark returns false and
        the script exits 1 -- which is the measured incident's own ending, `! [rejected] ... (fetch
        first)`. So a repeat sitting only above `exit 0` printed exactly zero times on the one run it was
        written for, and the first copy was buried under the scaffold as designed. Called from both ends
        now, and from the failed-push branch it is not merely a repeat but the DIAGNOSIS: git says the
        push was rejected, and this says why and whose work is on the other side of it.
    #>
    if ($script:remoteAheadNote) {
        Write-Warning "$script:remoteAheadNote Fast-forward it (git pull --ff-only) and read what is there before you build on this branch."
    }
}
$remoteAheadNote = ''
if ($branchExists -and $remoteRef.ExitCode -eq 0) {
    # .Fresh SAYS WHICH REF THE COUNT CAME FROM, the same distinction Get-TrunkGap draws for the trunk and
    # for the same reason: "behind the origin/<branch> this repo last fetched" is a different sentence from
    # "behind origin/<branch>", and a reader who is offline has to be told which one they got. Here it is
    # doubly worth saying, because a failed fetch is the one case where this check can read 0 on a branch
    # that has genuinely moved. The composition itself -- the rev-list count, the tip's subject and author,
    # sanitised and capped -- is Get-RemoteAheadNote's (remote-ahead-lib.ps1), shared with open-pr.ps1's own
    # remote-ahead gate rather than duplicated a second time (issue #1450).
    $staleRemoteLabel = "the origin/$Name this repo last fetched (git fetch failed -- the real gap may be larger)"
    $remoteAheadNote = Get-RemoteAheadNote -RepoRoot $repoRoot -LocalRef "refs/heads/$Name" -RemoteRef "refs/remotes/origin/$Name" -BranchLabel $Name -FreshLabel "origin/$Name" -StaleLabel $staleRemoteLabel -Fresh $gap.Fresh
    if ($remoteAheadNote) {
        Write-Warning "$remoteAheadNote Another session or another device has pushed work to this branch that this checkout does not have -- read it before you build on top of it."
    }
    elseif ($gap.Measured -and -not $gap.Fresh) {
        # A COUNT TAKEN AGAINST A REF NOBODY REFRESHED IS NOT AN ANSWER (issue #1915). Get-RemoteAheadNote
        # returns '' both for "origin has nothing you do not have" and for "the ref I counted against is
        # whatever the last fetch left" -- and this caller printed the second as the first, which is
        # silence. That is the same degradation #1676 repaired one line down for the tip read, arriving
        # through the count instead: the guard reports the shape of a clean branch on the one run where it
        # could not look.
        #
        # AND THE WINDOW IS WIDER THAN A SINGLE FAILED FETCH. Get-TrunkGap is called with
        # -RecentFailureSeconds here (#1860), so ONE transient failure suppresses the retry for the next 90
        # seconds -- which is exactly the interval a session's claim, cut and resume live in. A checkout
        # that fetched badly once then resumes a branch another session has pushed to, and is told nothing.
        #
        # THE TRUNK'S OWN NOTE DOES NOT COVER THIS, which is why a second sentence is worth its noise.
        # `Base: ... the refs compared here may be behind origin/<trunk>` is printed above on a SKIP only,
        # and it speaks about the trunk -- a reader has no way to know the branch-divergence probe, whose
        # whole job is #1439's duplicate-work hazard, went blind on the same reading.
        #
        # GATED ON .Measured, so it cannot land where the question was never asked at all: a repo with no
        # refs/remotes/origin/<trunk> never fetches, and the dim 'Base not compared' line above already
        # says so. What is left is precisely the run that DID fetch and did not come back fresh.
        $pasteName = Get-PasteableRef -Ref $Name
        Write-Warning "'$(Get-DisplayRef -Ref $Name)' was compared against the refs/remotes/origin/$Name this repo last fetched -- this run's fetch did not refresh it. Nothing found here is what this run could not see, not what is on the branch: a push another session made since that fetch is invisible from this checkout."
        Write-Host "  Fetch it yourself and re-read before you build on this branch: git fetch origin $($pasteName.Token)" -ForegroundColor Yellow
        if ($pasteName.Note) { Write-Host "  $($pasteName.Note)" -ForegroundColor Yellow }
    }
}

# --- HOW FAR BEHIND IS THE BASE? REPORTED ONLY WHEN THERE IS A BASE TO CHOOSE ----------------------
#
# SPLIT FROM THE MEASUREMENT ABOVE, AND THE ORDER IS THE POINT. Get-TrunkGap answered "what is this
# checkout missing" up there, before the resume probe read the refs its fetch had just refreshed; what is
# settled HERE is whether that number is worth saying. It is unanswerable -- worse, it is false -- for a
# branch that already exists: the count is HEAD..origin/<trunk>, and on a resume HEAD is whatever the
# operator happened to be standing on, usually the trunk. Attributing the trunk's gap to a branch that was
# cut somewhere else entirely is a sentence nobody can act on. So the resume question is settled first and
# nothing is reported when the answer is yes.
#
# THE GAP IS NOW MEASURED ON A RESUME TOO, and that is the only thing the move to Get-TrunkGap changed
# here. The count is a local rev-list against a ref already on disk, so taking it and then not printing it
# costs one process and buys one definition of the measurement. Nothing a reader sees moves, which is what
# the wording asserts in new-branch.tests.ps1 hold.
if ($gap.Measured -and -not $resuming) {
    if ($gap.Behind -gt 0) {
        $against = if ($gap.Fresh) { "origin/$trunk" } else { "the origin/$trunk this repo last fetched (git fetch failed -- the real gap may be larger)" }
        $staleBaseNote = "'$Name' is based on a commit $($gap.Behind) behind $against."
        Write-Warning $staleBaseNote
        Write-Host "  new-branch does not move HEAD for you, so this branch carries that gap -- work already merged upstream is" -ForegroundColor Yellow
        Write-Host "  invisible from here, including an issue somebody else has just closed. Bring the base up to date first" -ForegroundColor Yellow
        Write-Host "  (git pull --ff-only), or open the work as a lane, which bases it on origin/$trunk itself:" -ForegroundColor Yellow
        Write-Host "  scripts\task\worktree-lane.ps1 -Name <name>" -ForegroundColor Yellow

        # --- AND IT REFUSES (issue #1417, September 4, 2026) -------------------------------------
        #
        # THE POSITION IS THE ARGUMENT. This sits before the checkout, so a refusal here leaves the tree
        # exactly as it found it: no branch, no scaffold, no commit, no push, nothing to unwind -- and
        # one `git pull --ff-only` resumes the same command. That is the property #1405 named as what
        # makes the fold's refusal safe rather than merely strict, and it holds here for its own reason
        # rather than by analogy.
        #
        # WHY #1046 HELD BACK, AND WHICH HALF OF THAT EXPIRED. Its objection was that this file arrives
        # in a consumer by plugin UPDATE rather than by choice, and lands on the script they are told to
        # re-run to RESUME a parked branch. The first half still stands and is why the valve is one flag
        # rather than a hand-typed `git checkout -b`. The second half does not: this whole block is
        # gated on `-not $resuming` a few lines up, so the resume route never reaches the question and
        # a refusal here cannot land on it. What is refused is only an operator cutting a NEW branch
        # from the base they happened to be standing on -- which is the case #1046 measured.
        #
        # NOT GATED ON .Fresh, exactly as the fold is not. A failed fetch counts against the
        # origin/<trunk> last seen, and a HEAD behind THAT is behind whatever origin holds now as well;
        # the warning above already says the real gap may be larger. A repo with no origin/<trunk> ref
        # never gets here at all, so an offline clone is untouched.
        #
        # NO THRESHOLD. Refusing only above N was the third shape #1417 listed and it is declined: the
        # duplicate #1046 measured was of a PR merged four minutes earlier, so the dangerous gap can be
        # one commit. A threshold would let exactly that case through.
        if (-not $SkipStaleBase) {
            Write-Host "Refused: nothing was created, and this checkout is unchanged." -ForegroundColor Red
            Write-Host "  Bring the base up to date and run this command again, or pass -SkipStaleBase to cut from it anyway." -ForegroundColor DarkGray
            exit 1
        }
        Write-Host "  -SkipStaleBase given -- cutting from that base anyway." -ForegroundColor DarkGray
    } elseif ($gap.Fresh) {
        Write-Host "Base is current with origin/$trunk." -ForegroundColor DarkGray
    }
} elseif ($resuming -and $gap.Measured) {
    # GATED ON THE MEASUREMENT AS WELL, so this cannot print a SECOND 'Base not compared' underneath the
    # one the unmeasurable branch above already wrote. Both sentences would be true and neither would be
    # wrong; two of them in a row just read as a script that has lost track of what it is answering.
    Write-Host "Base not compared: '$Name' already exists, so nothing is being cut from a base." -ForegroundColor DarkGray
}

# --- THE ALREADY-DONE CHECK, BEFORE HEAD MOVES (issue #1409, the gap #1282's own check left open) ---
#
# #1282 built Get-TargetIssueWarnings and wired it into open-pr.ps1 -- the LAST step of a branch's life,
# after the checkout, the commits, the reviews and the test runs. #1409 measured what that costs: a
# session claimed #1402 correctly (open, unassigned, claimed by name), cut a branch, wrote two commits, a
# full development document and ran two subagent reviews plus 65 test suites, and only THEN learned from
# open-pr's own warning that PR #1406 had already closed #1402 -- opened and merged in the seven minutes
# after the claim. The claim step could not have caught it either: the other session had never assigned
# itself, so an unassigned issue read as untouched rather than as someone else's live work.
#
# SAME MOVE AS THE STALE-BASE CHECK ABOVE, FOR THE SAME REASON: measure before the checkout, WARN and
# never refuse (#1282's own call -- a shared number, a reopened issue, or an abandoned rival PR must not
# wedge a real branch), and repeat the warning as the LAST line of the run, because the scaffold, the
# commit and the push all print AFTER this point and would otherwise bury it exactly as the base warning
# would have been.
#
# EXPLICIT -RESOLVES ONLY -- this narrows the window rather than closing it, as #1409 says of its own
# proposal. There is no PR body yet to scan for a mention, so an issue only named in -Intent, or decided
# after the branch is cut, is invisible here; that gap is unaddressed and may not be addressable.
#
# GH IS OPTIONAL, AND THIS IS THE ONLY PLACE IN THE SCRIPT THAT ASKS FOR IT. -Resolves is opt-in, so the
# ordinary run -- no issue number given -- still asks nothing of gh and stays exactly as usable offline as
# this script's own docstring promises for scripts\lib\branch-info.ps1.
$alreadyDoneNote = ''
$resolveList = @(ConvertTo-IssueNumberList -Value $Resolves)
if ($resolveList.Count -gt 0) {
    $targetList = ($resolveList | ForEach-Object { "#$_" }) -join ', '
    if (-not $ghRepoName) {
        Write-Warning "already-done check: scripts\repo-config.ps1 supplies no Get-RepoName -- the check for $targetList is skipped."
    } else {
        # OPEN ISSUES: the same query open-pr.ps1's Get-OpenIssueNumbers makes, inlined rather than
        # shared -- that function is a closure over open-pr's own $repo and warning text, and the two
        # callers differ in exactly those two things. --limit 1000, not 200: an issue past the page
        # boundary would read as "not open" and let the check pass in silence, the one outcome this
        # exists to prevent.
        $openAll = $null
        $openQuery = Invoke-NativeCapture -FilePath 'gh' -Arguments @('issue', 'list', '--repo', $ghRepoName, '--state', 'open', '--limit', '1000', '--json', 'number') -DiscardStderr
        if ($openQuery.ExitCode -ne 0) {
            Write-Warning "could not ask gh which issues are open (exit $($openQuery.ExitCode)) -- the already-done check for $targetList cannot check and will not block."
        } else {
            try {
                # ASSIGN FIRST, WRAP SECOND -- Windows PowerShell 5.1 hands a parsed JSON array to the
                # pipeline as ONE object; the same 5.1 trap this file's own header warns every caller of
                # pr-issues-lib.ps1 about.
                $parsedOpen = ($openQuery.Output -join "`n") | ConvertFrom-Json
                $openAll = @(@($parsedOpen) | Where-Object { $_ -and $_.number } | ForEach-Object { [int]$_.number })
            } catch {
                $openAll = $null
            }
        }

        # CLAIMING PRs: the same search open-pr.ps1 makes before the branch's OWN PR exists, so
        # -CurrentBranch is $Name rather than a discovered head -- correct either way, since this branch
        # cannot yet carry a PR of its own to exclude.
        $otherPrsJson = ''
        $searchTerms = (($resolveList | ForEach-Object { "$_" }) -join ' OR ') + ' in:body'
        $prSearch = Invoke-NativeCapture -Utf8 -FilePath 'gh' -Arguments @('pr', 'list', '--repo', $ghRepoName, '--state', 'all', '--search', $searchTerms, '--json', 'number,state,headRefName,body', '--limit', '60') -DiscardStderr
        # A SHORT READ IS NOT AN EMPTY RESULT SET (issue #1679). The -Utf8 arm can return an empty or
        # truncated Output with ExitCode 0, and an empty $otherPrsJson reads downstream as "no rival PR"
        # -- so the already-done warning #1409 exists to raise would silently not fire. Nothing else here
        # could tell the two apart: gh prints '[]' when it finds nothing, so at THIS call an empty capture
        # has no legitimate reading at all. Same repair as open-pr.ps1 makes on the same search.
        $searchUnread = ''
        if ($prSearch.ExitCode -ne 0) {
            $searchUnread = "exit $($prSearch.ExitCode)"
        } elseif ($prSearch.ShortRead) {
            $searchUnread = 'gh exited 0 but its capture was still being written when it was read, so the result may be truncated'
        }
        if (-not $searchUnread) {
            $otherPrsJson = ($prSearch.Output -join "`n")
        } else {
            Write-Warning "could not ask gh whether another PR already resolves $targetList ($searchUnread) -- the already-done check runs on issue state alone."
        }

        $doneWarnings = @(Get-TargetIssueWarnings -TargetIssues $resolveList -OpenIssues $openAll -OtherPrsJson $otherPrsJson -CurrentBranch $Name)
        if ($doneWarnings.Count -gt 0) {
            $parts = @()
            foreach ($w in $doneWarnings) {
                $says = @()
                if ($w.IsClosed) { $says += 'is already CLOSED' }
                foreach ($p in $w.ClaimingPrs) { $says += "is already resolved by PR #$($p.Number) ($($p.State.ToLowerInvariant()))" }
                $parts += "issue #$($w.Issue) " + ($says -join ', and it ')
            }
            $alreadyDoneNote = "already-done check: " + ($parts -join '; ') + " -- this branch may repeat work that is already merged. If that is deliberate (a shared number, the issue reopened, cited only as context), nothing to do."
            Write-Warning $alreadyDoneNote
        }
    }
}

# Note: Test-BranchName above only catches the explicitly named hard rejects (empty/'main'/
# 'final'). Protection against e.g. backslashes, '..', or a leading hyphen in $Name does NOT rely
# on custom code here, but implicitly on git's own `check-ref-format` validation, which `git checkout
# -b` below enforces itself (with exit 128 on an invalid ref name). If you ever change the
# checkout mechanism (e.g. to `git branch` + a separate `checkout`, or to libgit2), check whether
# that implicit gate does not silently disappear.
#
# Idempotent, in three shapes: the branch exists locally -> check it out; it exists only on origin ->
# create it AT THE REMOTE TIP with tracking, which is what a resume means; neither -> create it here.
# Deliberately `git -C $repoRoot` instead of Set-Location -- this script stays composable and does
# not mutate the caller's cwd. git sometimes writes progress/errors to stderr; under
# ErrorActionPreference=Stop, PS 5.1 would promote that to a terminating error before the graceful
# $LASTEXITCODE handling (the #107 pitfall, see also open-pr.ps1) -- so run under Continue, capture
# output, and only then judge. The checkout keeps that hand-written dance rather than moving to
# Invoke-NativeCapture like the reads above: its stderr is git's own progress text, which is PRINTED
# rather than judged, and discarding or swallowing it is what the lib is for.
$prevEap = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    if ($branchExists) {
        $checkoutOutput = & git -C $repoRoot checkout $Name 2>&1
    } elseif ($branchOnOrigin) {
        $checkoutOutput = & git -C $repoRoot checkout -b $Name --track "origin/$Name" 2>&1
    } else {
        $checkoutOutput = & git -C $repoRoot checkout -b $Name 2>&1
    }
    $checkoutCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $prevEap
}
$checkoutOutput | ForEach-Object { Write-Host $_ }
if ($checkoutCode -ne 0) {
    Write-Error "git checkout of '$Name' failed."
    exit 1
}
if ($branchExists) {
    Write-Host "Branch '$Name' already existed -- checked out." -ForegroundColor Yellow
} elseif ($branchOnOrigin) {
    Write-Host "Branch '$Name' existed ONLY on origin -- resumed at the remote tip, tracking origin/$Name." -ForegroundColor Yellow
    Write-Host "  That is a RESUME, not a new branch: it carries work parked from another device or session," -ForegroundColor Yellow
    Write-Host "  and nothing was cut from this checkout's base. If you meant a NEW branch, this name is taken --" -ForegroundColor Yellow
    Write-Host "  bump the version suffix ('-v2') and run again." -ForegroundColor Yellow
} else {
    Write-Host "Branch '$Name' created and checked out." -ForegroundColor Green
}

# --- The two files the branch works in, plus the reference templates ------------------------------

# BOM-less UTF8 -- Set-Content -Encoding UTF8 always adds a BOM in Windows PowerShell 5.1, and the
# rest of the repo has no BOM.
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

# $Name rather than a fresh `git rev-parse HEAD`: the checkout above has just put HEAD there and
# errored out if it could not. Asking git again would be a second answer to a settled question.
$branch = $Name

# -Title IS THE BRANCH TITLE. The entry's H3 names the branch, and the human-readable name of
# the change is a section under it -- the one open-pr.ps1 now composes the PR title from, so what is
# typed here is what the PR is called. Give it WITHOUT a type prefix: the branch already carries the
# type and open-pr puts it in front.
$description = $Title

# THE 'Branch type' SECTION HOLDS THE PREFIX, LOWERCASE, which is what its own hint asks for ("options
# for type are: feat, fix or docs") and what the branch name already says. It used to hold the
# canonical type ('Feat'); Resolve-EntryType canonicalises case-insensitively, so both read back as the
# one type the release documents know -- which keeps the hundreds of entries carrying 'Feat' readable.
$info = Get-BranchInfo -Branch $branch
$branchType = if ($info.IsKnown) { $info.Prefix } else { '' }
if (-not $branchType) {
    $branchType = $stubFallbackType.ToLowerInvariant()
    Write-Host "Unknown branch prefix '$($info.Prefix)' - 'Branch type' set to '$branchType', adjust this by hand if needed." -ForegroundColor Yellow
}

# NO BRANCH ID ANY MORE (Dave, #1335, September 3, 2026). It was a creation timestamp, stamped onto the
# document's own heading, and the heading is the branch name and nothing else now. Nothing ever read it
# back: the changelog orders entries by the MERGE stamp, which the fold writes onto the entry's 'Pull
# Request' heading from the PR's own mergedAt. Gone here rather than computed and dropped at the call, so
# there is no unused local left behind to look like something the writer forgot to pass.

# THE BRANCH'S WORKING DOCUMENT LIVES UNDER dkj-policy/, NAMED FOR THE BRANCH, NOT IN THE
# REPO ROOT UNDER THE BRANCH'S NAME (Dave, August 6, 2026; moved under the workflow's own root folder
# August 14, 2026; merged from two files into one on August 23, 2026).
# ONE NAME PER BRANCH SINCE #1255 (September 3, 2026), where it was one fixed path. The fixed path did not
# collide on CHECKOUT, which is what the old reasoning said; it collided on MERGE, which is what it did not.
# See the block in entry-scaffold-lib.ps1 for the measurement.
$branchFiles    = Get-BranchFilePaths -Branch $branch
$branchDirPath  = Join-Path $repoRoot $branchFiles.Directory

# WHICH NAME THIS RUN WRITES, on a repo that may still hold a pre-August-23-2026 pair. The rule is the
# narrowest one that keeps a branch in flight whole: an old name is used for one reason only -- it already
# declares THIS branch, so somebody is working in it and a new document beside it would split their work in
# half. Every other state writes the current name, including a trunk whose reset files still carry the old
# ones. Resolve-BranchFilePath is deliberately NOT used here: it answers "where is the file", which is the
# readers' question, and answering the writer's question with it would keep an old name alive on every
# branch a consumer creates.
#
# THE LEGACY NAMES ARE THE READER'S, VERBATIM (#1259). This list must reach exactly as far back as
# Resolve-BranchFilePath does, or a branch working in an old name the reader still finds gets a second
# document written beside its work here. The two lists were maintained separately and drifted -- #886
# (the workflow-davekjohn/ folder rename) and #963 (development-cycle.md -> development.md) grew the
# reader and left this at three names -- so it now comes from Get-BranchFileLegacyNames, the one ordered
# source both sides read. The declared-branch test below is still this writer's own and stricter than
# the reader's fallback: it adopts an old name ONLY where that file declares THIS branch.
function Get-BranchFileTargetRel {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Current,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Legacy,
        [Parameter(Mandatory)][string]$Branch
    )
    foreach ($rel in @($Legacy)) {
        if (-not $rel) { continue }
        $path = Join-Path $RepoRoot ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $declared = Get-BranchFileDeclaredBranch -Text ([System.IO.File]::ReadAllText($path))
        if ($declared -eq $Branch) { return $rel }
    }
    return $Current
}

# -Legacy IS Resolve-BranchFilePath's OWN LEGACY LIST (#1259): the pre-#1335 'development-<slug>.md', the
# pre-#1255 shared name, the pre-#963 filename, the branch/ pair, and the pre-#886 workflow-davekjohn/ set
# -- in the reader's order. The newest predecessor leads because on the day of a rename every branch in
# flight is working in it, and a rerun that did not see it would split that work across two documents; the
# names behind it are the earlier renames, each protecting a branch that never moved off its old name.
#
# -Branch IS PASSED SINCE #1335, and it has to be: the newest predecessor is the first legacy name in this
# system's history that is branch-DEPENDENT, so a list built without a branch simply does not contain it.
$cycleRel  = Get-BranchFileTargetRel -RepoRoot $repoRoot -Current $branchFiles.File `
    -Legacy (Get-BranchFileLegacyNames -Kind 'Cycle' -Branch $branch) -Branch $branch
$cyclePath = Join-Path $repoRoot ($cycleRel -replace '/', '\')

if (-not (Test-Path -LiteralPath $branchDirPath)) {
    $null = New-Item -ItemType Directory -Path $branchDirPath -Force
}

# NOTHING WRITES A TEMPLATE ANY MORE (August 23, 2026), and the reason it can stop is that the working
# document carries the guidance itself. branch/templates/ existed because the file a branch got was
# deliberately bare: the comments explaining every field lived in a reference copy beside it, which this
# script had to create and refresh in every consumer. Inbound #810 is what that arrangement cost -- an
# author met the guidance in the neighbouring file or not at all. The comments are in the document now, the
# fold strips them on the way to CHANGELOG.md, and a reference nobody has to keep in sync is one fewer thing
# that can drift.
# IDEMPOTENCY IS ONE QUESTION NOW, and that is the merge's quietest simplification. It used to be two --
# per file, because the entry and the step list could legitimately be out of step, so a rerun on a branch
# whose entry was written still had to leave the step list alone. One document cannot be half-written by
# this script: either it declares this branch or it does not.
#
# THE TEST IS THE DECLARED OWNER MEASURED AGAINST THIS BRANCH (inbound #615, reported from a consumer).
# "Is the entry filled" and "is the owner not the trunk" are BOTH true for any branch stacked on one whose
# entry has not been folded yet -- so the file was skipped, and the skip was printed under the NEW branch's
# name. The branch silently started out claiming the previous branch's work as its own: nothing failed, and
# the one line it printed said the opposite of what had happened.
#
# One comparison answers all three states. The trunk's reset state declares the trunk (write), a rerun on
# this branch declares this branch (keep), and a foreign owner declares somebody else (write, and say whose
# file was replaced). Get-BranchFileDeclaredBranch reads the heading at either level -- '# `main`
# development cycle' on the trunk, '# `feat/x-v1` development cycle' once written, and an old
# '## `feat/x` deployment' on a branch created before the merge -- so the same predicate serves every
# state, and Test-BranchChangelogIsFilled is not the idempotency test. It still owns the question it is
# named for, everywhere else.
$cycleExisting = if (Test-Path -LiteralPath $cyclePath) { [System.IO.File]::ReadAllText($cyclePath) } else { '' }
$cycleOwner    = Get-BranchFileDeclaredBranch -Text $cycleExisting
$cycleTaken    = ($cycleOwner -eq $branch)

# READ THIS BEFORE DELETING THE BLOCK BELOW AS DEAD CODE (#1255, September 3, 2026). Naming the document
# per branch removed almost every way of reaching it. The target is now this branch's own name, and a
# legacy name is chosen for one reason only -- it already declares THIS branch -- so the ordinary route in,
# a branch stacked on an unfolded one, cannot produce a foreign owner any more: the two branches write
# different files. What is left is the odd tree: a branch renamed after its document was written, or a
# document created by hand under a name that does not match it.
#
# IT STAYS, for the reason the block itself gives. What it protects is work that exists in exactly one
# place -- edits carried into a new branch by `git checkout -b` and never committed -- and the cost of
# keeping an unreachable guard is a few lines, while the cost of being wrong about "unreachable" is
# somebody's uncommitted entry. new-branch.tests.ps1 scenario (n2) measures the new guarantee (a foreign
# document is never TARGETED) rather than pretending to reach this; that is deliberate and is written up
# there.
#
# A FOREIGN OWNER IS OVERWRITTEN, EXCEPT WHERE THE OVERWRITE WOULD BE UNRECOVERABLE -- and that
# distinction is measured rather than assumed, because this repair is what creates the destructive
# path. Before it, a foreign file was kept; after it, it is written over. In the ordinary stacked case
# that costs nothing: the other branch's entry is committed on that branch, so git still holds it. What
# git does not hold is an entry edited and never committed -- `git checkout -b` carries those edits
# into the new branch, and there they exist in exactly one place. So a dirty foreign file is left
# alone and said out loud instead, which still repairs the defect that was reported: the failure there
# was the SILENCE and the wrong name, not the keeping.
#
# `git -C $repoRoot` and the EAP dance for the same two reasons every other git call in this script has
# them (see the block at the checkout above): bare `git` would read whatever directory the caller
# happened to be in, and under ErrorActionPreference=Stop PS 5.1 promotes a native command's stderr to
# a terminating error. Untracked counts as dirty, deliberately -- a file git has never seen is the
# case where the working tree is the only copy there is.
function Test-BranchFileIsDirty {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$RelativePath)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $porcelain = & git -C $RepoRoot status --porcelain -- $RelativePath 2>$null
    } finally {
        $ErrorActionPreference = $prevEap
    }
    return [bool]($porcelain | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

# ALREADY WRITTEN IS A SKIP, NOT A STOP, and that is the one exit the merge had to convert. As a child
# process this was `exit 0` and the caller read it as success and carried on to -Park; inline, an exit would
# end the whole run and a park would silently not happen. Saying so and falling through is what it always
# meant.
if ($cycleTaken) {
    Write-Host "Development already written for '$branch' - nothing done." -ForegroundColor Yellow
    $branchFileWritten = $false
} else {
    # -Intent IS THE PARKING NOTE AND IT DOES NOT LAND IN THE ENTRY (Dave, August 6, 2026). It is a status,
    # typically written when parking (#162), and it used to become the entry BODY -- which put a progress
    # note in the text that folds verbatim into CHANGELOG.md, the defect the v3.2.0 measurement found three
    # times. It goes into the document's first phase instead -- as PLAN's opening paragraph since #908, no
    # longer above the phases, where the document's own guidance forbids branch-specific text and the CI
    # gate refuses it; the entry scaffolds with an empty body and the gate keeps refusing that until
    # somebody writes what the change does.
    $body = ''

    # THE SECTION SHAPE IS THE SHAPE, ALWAYS -- the ranking's on/off switch does not change it. An earlier
    # draft wrote the significance sections only where Test-EntrySignificanceActive said the repo ranks.
    # That produced TWO entry shapes in one system, so every reader downstream would have needed both paths
    # forever. Tier 0 unscored is harmless in a repo that never scores it -- nothing asks, nothing refuses --
    # so the switch governs only the GATES, which is the thing a repo was ever opting out of.
    $impactActive = Test-EntrySignificanceActive

    # A FOREIGN OWNER IS OVERWRITTEN, EXCEPT WHERE THE OVERWRITE WOULD BE UNRECOVERABLE -- and that
    # distinction is measured rather than assumed, because this repair is what creates the destructive path.
    # Before it, a foreign file was kept; after it, it is written over. In the ordinary stacked case that
    # costs nothing: the other branch's document is committed on that branch, so git still holds it. What git
    # does not hold is a document edited and never committed -- `git checkout -b` carries those edits into the
    # new branch, and there they exist in exactly one place. So a dirty foreign file is left alone and said
    # out loud instead, which still repairs the defect that was reported: the failure there was the SILENCE
    # and the wrong name, not the keeping.
    $cycleForeign = ($cycleOwner -and $cycleOwner -ne $trunk -and -not $cycleTaken)

    if ($cycleForeign -and (Test-BranchFileIsDirty -RepoRoot $repoRoot -RelativePath $cycleRel)) {
        Write-Warning "Kept: $cycleRel -- it holds UNCOMMITTED work belonging to '$cycleOwner', which exists nowhere else. This branch has no development document of its own yet: commit or discard that work, then rerun this script."
        $branchFileWritten = $false
    } else {
        # NO DATE IN THE ENTRY, DELIBERATELY (Dave, August 5, 2026). This runs when the BRANCH is created, so
        # any date it writes is the branch's birth date -- and the changelog records what LANDED when. The
        # entry's date is the fold's to add, from the PR's own merge timestamp, together with the PR number.
        # SINCE #1335 THAT HOLDS FOR THE DOCUMENT'S HEADING TOO: the creation stamp used to sit there on the
        # reasoning that the document is created with the branch. It is the branch name alone now.
        # THE LINK BASE IS THIS REPO'S OWN (inbound #967), not a constant. In the source repo it resolves to
        # the root and the sentence is word for word what it always said; in a consumer on the shipped
        # defaults it resolves to the workflow folder -- the same directory this document is in -- where the
        # old wording told the author to write the one link form the fold would break.
        $linkDestDirRel = ((Split-Path (Get-SeamValue -Name 'Get-ChangelogPath' `
            -Default (Get-DefaultChangelogPath -RepoRoot $repoRoot)) -Parent) -replace '\\', '/').Trim('/')
        $cycleText = ((Format-Development -Branch $branch -Intent $Intent `
            -Description $description -Type $branchType -Body $body `
            -LinkDestDirRel $linkDestDirRel) -join "`n") + "`n"
        [System.IO.File]::WriteAllText($cyclePath, $cycleText, $Utf8NoBom)
        $branchFileWritten = $true
        # WHOSE FILE THIS WAS IS NAMED IN EVERY OUTCOME, and that is the reported defect's actual repair. A
        # foreign owner is the one state the old test could not distinguish from its own, so it is the one
        # state the output has to say out loud.
        if ($cycleForeign) {
            Write-Host "Replaced: $cycleRel (it held the development document of '$cycleOwner', committed on that branch)" -ForegroundColor Yellow
        } else {
            Write-Host "Created: $cycleRel" -ForegroundColor Green
        }
    }

    # SAID WHERE IT HAPPENS (inbound #817). The line above names the path a session is about to edit and,
    # until now, never mentioned that its own view of it had just been replaced. One line here turns a
    # refused write further on into a known next step, in the one place a reader is already looking at
    # exactly that file. Wording in Get-BranchFilesRereadNote, shared with the fold, which resets the same
    # document at the other end of the cycle.
    if ($branchFileWritten) { Write-Host (Get-BranchFilesRereadNote) -ForegroundColor DarkGray }

    # The rubric, printed at the moment the entry comes into existence. The scores are filled in later, by
    # whoever finishes the branch -- so this is not a prompt to act on now; it is the scale being stated
    # where the author is looking, instead of only inside a refusal further down the line. A gate that first
    # mentions the definitions when it blocks you has already let the guess happen.
    if ($impactActive) {
        $range = Get-EntrySignificanceRange
        Write-Host "  Tier sections written. Answer each tier with a score ($($range.Min)-$($range.Max)) or N/A:" -ForegroundColor Cyan
        Format-EntrySignificanceRubricLines | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
        # WHERE the reason goes, by the same argument as the rubric above it (inbound #596): the file leaves
        # one blank line on each side of the score label, so the two places look identical and only the one
        # above is read. Said here because this is the moment the author is looking and has not written yet
        # -- the gate that names the misplacement runs at the PR, by which time the half hour is spent.
        Write-Host "  Each tier's reason goes ABOVE its $(Get-EntryScoreLabel) line; anything below it is discarded." -ForegroundColor DarkGray
    }
}

# THE CREATION PUSH: make the freshly created branch reachable from another device by committing its
# development document (the plan, the intent and the entry, in one file) and pushing it -- NO PR. Push != PR:
# the PR rule stays intact and separate. git writes progress to stderr,
# which under EAP=Stop would die as a terminating NativeCommandError before the exit-code check even on
# exit 0 (the #107 pitfall) -- so every git call goes through the shared Invoke-NativeCapture
# (EAP=Continue -> run -> record $LASTEXITCODE), the same helper open-pr.ps1 uses for its push.
#
# THE DEFAULT SINCE #900 (August 26, 2026), AND IT WAS A DEFAULT QUESTION RATHER THAN A BUILD. This exact
# block ran behind -Park for nineteen days and the switch was typed SIX times in the whole history, while
# the window it exists to close was measured over the 38 merged branches carrying a readable creation
# stamp: median 22 minutes invisible on origin, mean 35, max 365, nine of them over half an hour. An
# opt-in backup is a backup nobody takes -- which is what those two figures are, side by side. Dave works
# from more than one device, so a branch that exists only locally is a branch the other device cannot see
# and will collide with.
#
# -NoPush IS THE ONLY WAY OUT, and it is deliberately not gated on anything else. A branch nobody may see
# yet is a real case; a branch nobody CAN see is the defect.
#
# UNCONDITIONAL SINCE THE MERGE. It used to be gated on the child's exit code, with a warning
# branch for "the entry step failed, so nothing was parked". There is no child any more: a failure above
# either exits or throws under EAP=Stop, so reaching this line means the files are there.
if ($Park) {
    # ACCEPTED, ANNOUNCED, IGNORED -- see .PARAMETER Park. Said out loud rather than swallowed, because a
    # consumer whose doc still names the switch should learn that it is the default now, not wonder
    # whether their run behaved differently from the one beside it.
    Write-Host "new-branch: -Park is the default since #900 -- the switch is accepted and changes nothing." -ForegroundColor DarkGray
}
if ($NoPush) {
    Write-Host "new-branch: -NoPush -- branch and document are local only, nothing is on origin." -ForegroundColor Yellow
} else {
    # ONE IMPLEMENTATION SINCE #507 (August 7, 2026). These four steps used to be written out here as
    # well as in park-branch.ps1, and the copies had drifted where it hurts a reader rather than a
    # script: both wrote `park: <branch> (work parked for later)` while committing different things, so
    # the log could not say which half of the work was safely on origin. The scope now picks the words
    # too, and the shared function owns both.
    . (Join-Path $PSScriptRoot '..\lib\park-lib.ps1')

    # NO ORIGIN, NO PUSH -- AND CREATING THE BRANCH STILL SUCCEEDS. A repo with no remote is a legitimate
    # repo, and until the push became the default nobody met this: you had asked for it, so the failure was
    # the right answer. Unasked, that same exit 1 would come out of branch CREATION. Test-GitOriginConfigured
    # carries the full reasoning; park-branch.ps1 deliberately does NOT ask this question.
    if (-not (Test-GitOriginConfigured -RepoRoot $repoRoot)) {
        Write-Host "new-branch: no 'origin' remote -- the branch and its document stay local." -ForegroundColor Yellow
    } else {
    # THE ONE DOCUMENT, since the merge (Dave, August 23, 2026). Parking exists to make work reachable from
    # another device, and both halves of what a reader needs -- the plan still in flight and the claim being
    # made -- are sections of this file now, so the pair that used to be listed here is one path. Named
    # explicitly rather than swept up, so the commit stays exactly as narrow as it was: this pushes to a
    # branch, but the pathspec discipline is the same everywhere.
        $ok = Invoke-GitPark -RepoRoot $repoRoot -Branch $Name -Scope 'BranchFiles' `
            -Paths @($cycleRel)
        if (-not $ok) {
            # THE PUSH REJECTION IS THIS CHECK'S OWN SYMPTOM (#1439), so the note is emitted here rather
            # than left to the tail of a run that never reaches it. git has just printed its own
            # "! [rejected] ... (fetch first)"; this says which session is on the other side of it.
            Write-RemoteAheadRepeat
            exit 1
        }
    }
}

# THE REPEAT, and it is the half of the stale-base check that a reader actually reads (inbound #1046). See
# the block above the checkout for the measurement; this exists because everything between there and here
# -- the scaffold, its tier rubric, the commit, the push -- prints in between, so the warning that fired
# before HEAD moved is well off-screen by now. Last line of the run, or nothing at all.
#
# REACHABLE ONLY UNDER -SkipStaleBase SINCE #1417: a stale base now refuses up there, so the only run that
# gets this far with a note to repeat is one that was told to cut anyway. That makes the repeat MORE
# load-bearing rather than less -- it is the whole record that the valve was used, on a run that otherwise
# ends on a green 'created and checked out'.
if ($staleBaseNote) {
    Write-Warning "$staleBaseNote Bring the base up to date (git pull --ff-only) or reopen this as a lane before you build on it."
}

# THE REPEAT, same reason and same shape as the stale-base repeat above (issue #1409): the already-done
# check fires before HEAD moves, and everything since then -- the checkout, the scaffold, the commit, the
# push -- prints in between and buries the first copy.
if ($alreadyDoneNote) {
    Write-Warning $alreadyDoneNote
}

# THE REPEAT, same reason and same shape as the two above (issue #1439), and DELIBERATELY THE LAST OF
# THE THREE. The other two are backed by something else -- the stale-base note is only reachable when a
# refusal was overridden on purpose, and the already-done note names an issue somebody can go and read.
# This one never refuses and has no issue behind it, so these two lines are the entire record that the
# branch under your feet carries work you have not seen. Everything since the first copy -- the
# checkout, the scaffold, the tier rubric, the commit, the push -- prints in between and buries it.
Write-RemoteAheadRepeat

exit 0
