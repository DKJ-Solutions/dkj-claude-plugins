<#
.SYNOPSIS
    Read `git worktree list --porcelain` -- who holds which branch, and which tree is the primary one.

.DESCRIPTION
    Dot-source this file from a script in scripts/release/ or scripts/task/:

        . (Join-Path $PSScriptRoot '..\lib\worktree-lib.ps1')

    Supplies the eight pure functions below. None of them runs git -- the caller passes the lines
    `git worktree list --porcelain` produced, so every one of them is testable, which is the whole
    reason this file exists rather than a fourth inline parse.

    WHY IT EXISTS AT ALL (issue #1069, August 29, 2026). git allows exactly ONE worktree per branch, so
    a tree standing on `main` takes a lock that is global to the clone: from that moment no other
    worktree can check `main` out. ship-pr.ps1's step 5 checks `main` out in whatever tree it runs in --
    correct, that is where it folds -- and then leaves it there. In the primary checkout that is
    harmless and deliberate, because the trunk is where a finished chain belongs. In a LANE it means the
    lane holds the trunk hostage for every later chain on the machine, and the cost is paid by an
    unrelated branch, later, AFTER its merge has already landed: the PR is merged, CHANGELOG.md is
    unfolded and the development document is still on the trunk. That is the one silent half-state
    fold-changelog-entry.ps1's own -Push comment exists to prevent.

    THE PARSE WAS ALREADY WRITTEN TWICE BEFORE THIS FILE, which is the second reason. worktree-lane.ps1
    reads the porcelain to find the primary checkout, ship-pr.ps1's Remove-ShipFoldWorktree reads it to
    ask whether a worktree it just tried to remove is still registered -- and both had to solve the same
    path-comparison problem separately (see Get-WorktreePathKey). A third copy was owed by this repair;
    a lib is what it got instead.

    AND ship-pr.ps1's OWN HEADER ASKED FOR THIS: "anything in here that is a pure function of text
    belongs in a lib, precisely because this file cannot be tested". ship-pr drives live git and gh
    against a real remote and carries no suite; the decision this repair turns on -- does another tree
    hold the trunk? -- is a pure function of the porcelain, so it is tested in
    scripts/tests/worktree-lib.tests.ps1 rather than only exercised by a full live ship.

    Pure ASCII (repo convention for .ps1).

    ONE DEPENDENCY: Get-DisplayRef (ref-print-lib.ps1), loaded below, which the two functions that
    COMPOSE A SENTENCE need -- Get-FoldTreeDecision and Get-TrunkReturnGoAheadLine. The six readers stay
    pure functions of the porcelain text.
#>

# THE PROSE SANITISER, loaded rather than copied (issue #1623) -- see Get-TrunkReturnGoAheadLine at the
# foot of this file, and Get-FoldTreeDecision (#1753), for what needs it. $PSScriptRoot-relative so it
# resolves in the plugin mirror as well as here, and unconditional because the functions that call it
# have no fallback wording; ref-print-lib.ps1 is a leaf with no dependencies of its own.
. (Join-Path $PSScriptRoot 'ref-print-lib.ps1')

# THE COMPARISON KEY, and it is not decoration. Three things make two spellings of the same directory
# compare unequal on Windows, and all three have been measured in this repo:
#   - the separator: git reports forward slashes on Windows, PowerShell composes back slashes;
#   - case: NTFS is case-insensitive, so 'C:\Users' and 'c:\users' are the same directory;
#   - a trailing separator, which Join-Path and a hand-typed path disagree about.
# The 8.3-short-name problem is NOT solved here and cannot be: only the filesystem knows that
# C:\Users\DAVEKO~1 and C:\Users\davekokbwj are one directory, and this function takes a string. A
# caller that composes a path itself resolves it while the directory certainly exists (ship-pr does
# exactly that for its throwaway worktree) and passes the resolved spelling in.
function Get-WorktreePathKey {
    param([string]$Path)
    if (-not $Path) { return '' }
    return $Path.Trim().Replace('/', '\').TrimEnd('\').ToLowerInvariant()
}

# THE PORCELAIN, AS RECORDS. Its shape is a stanza per worktree, blank-line separated:
#
#     worktree C:/repo
#     HEAD 926bd0ca...
#     branch refs/heads/main
#
#     worktree C:/repo-lanes/feat--x
#     HEAD 979f2daa...
#     detached
#
# A stanza carries EITHER `branch` or `detached`, never both, and a bare repository carries `bare`
# instead of a HEAD at all. The `worktree` line is what opens a stanza, so it is what closes the
# previous one -- the blank line is not relied on, because a caller that trims its captured output (and
# Invoke-NativeCapture's callers do) can lose it.
#
# ORDER IS PRESERVED AND IT CARRIES MEANING: git lists the MAIN worktree first, which is the only thing
# in the output that identifies it. Get-PrimaryWorktreePath below is that fact, named.
function Get-WorktreeRecords {
    param([string[]]$PorcelainLines)
    $records = @()
    $current = $null
    foreach ($line in @($PorcelainLines)) {
        $text = "$line".Trim()
        if ($text -match '^worktree\s+(.+)$') {
            if ($current) { $records += $current }
            $current = [pscustomobject]@{
                Path     = $Matches[1].Trim()
                Branch   = ''
                Detached = $false
                Bare     = $false
            }
            continue
        }
        if (-not $current) { continue }
        if ($text -match '^branch\s+(.+)$') {
            # Stored SHORT ('main'), not as refs/heads/main: every caller here asks about a branch by the
            # name a person types. The full ref is what git prints and the only place the distinction
            # matters, so it is stripped once, here.
            $current.Branch = ($Matches[1].Trim() -replace '^refs/heads/', '')
            continue
        }
        if ($text -eq 'detached') { $current.Detached = $true; continue }
        if ($text -eq 'bare')     { $current.Bare = $true; continue }
    }
    if ($current) { $records += $current }
    return @($records)
}

# git lists the main worktree first. That is the whole definition -- there is no flag on the stanza
# saying so, and no other way to tell from the porcelain alone.
function Get-PrimaryWorktreePath {
    param([string[]]$PorcelainLines)
    $records = Get-WorktreeRecords -PorcelainLines $PorcelainLines
    if ($records.Count -eq 0) { return '' }
    return $records[0].Path
}

# THE QUESTION THAT MATTERS: is $Branch checked out somewhere OTHER than the tree I am standing in?
# Returns that worktree's path as git spells it (so a message can name a directory the reader can
# paste), or '' when the answer is no.
#
# -SelfPath IS NOT OPTIONAL IN PRACTICE and the reason is worth stating: the tree asking the question is
# itself in the list, so without excluding it a checkout ALREADY standing on main would report itself as
# the blocker and refuse a run that was never in danger. It is compared through Get-WorktreePathKey
# above rather than with -eq, for the three reasons stated there.
function Get-WorktreeHoldingBranch {
    param(
        [string[]]$PorcelainLines,
        [Parameter(Mandatory = $true)][string]$Branch,
        [string]$SelfPath
    )
    $selfKey = Get-WorktreePathKey $SelfPath
    foreach ($record in (Get-WorktreeRecords -PorcelainLines $PorcelainLines)) {
        if ($record.Branch -ne $Branch) { continue }
        if ($selfKey -and (Get-WorktreePathKey $record.Path) -eq $selfKey) { continue }
        return $record.Path
    }
    return ''
}

# MAY THIS TREE GO BACK TO THE TRUNK NOW, WHILE THE SHIP STILL RUNS? (issue #1073, August 29, 2026.)
#
# THE CONTRADICTION IT SETTLES IS IN THE ORCHESTRATOR'S OWN BODY, not in a script. Chris says both
# "parking is a state, not a promise to come back within the turn" -- so a backgrounded ship is a
# FINISHED assignment -- and "it ends on the trunk, which is what makes the session safe to clear".
# For a parked branch those compose: push, check the trunk out, stop. For a BACKGROUNDED ship they
# could not, because ship-pr.ps1 did not move HEAD until step 5, after the CI wait. At the moment the
# close-out was written the checkout was necessarily still on the branch, so obeying the first rule
# broke the second. Dave, the day it cost him three exchanges: "ik wil pas een sessie sluiten als ik
# terug op de main branch ben."
#
# AND THE ANSWER IS AVAILABLE ONLY BECAUSE TWO EARLIER REPAIRS LANDED. Since #970 both merge gates read
# `refs/heads/<branch>` rather than the working copy, and since #972 step 5 reads HEAD before it moves
# anything. Together they mean NOTHING AFTER STEP 2 READS THE CONTENT OF THE WORKING TREE -- step 3 is
# network, step 4 is the ref plus gh, and step 5 folds wherever HEAD already is. So the trunk can be
# handed back the moment the PR exists, and step 5 then finds HEAD -eq 'main' and folds in place: the
# arm it has had all along, taken deliberately instead of by accident.
#
# THREE CONDITIONS, AND EACH ONE IS A MEASURED DEFECT IF SKIPPED:
#
#   - THE PRIMARY CHECKOUT ONLY. A lane that took the trunk here would take the clone-wide lock #1069
#     exists to prevent, and would do it for the whole CI wait rather than for the length of a fold.
#     A lane belongs on its own branch; step 5b is what puts it back there.
#   - NOBODY ELSE HOLDS THE TRUNK. git allows one worktree per branch, so `git checkout main` would
#     simply fail -- and failing HERE is free (nothing is merged yet), which is why it is asked rather
#     than attempted. Step 0 has usually already refused this case; this is not a second gate but the
#     same question asked of a tree that may have changed hands since.
#   - A CLEAN TREE. This is #972's two outcomes, met one step earlier: an uncommitted edit that
#     collides makes the checkout exit 1, and one that does not collide TRAVELS TO THE TRUNK with the
#     session none the wiser. The branch's own work is committed and pushed by step 1, so a dirty tree
#     here is something else -- and something else is exactly what must not ride along.
#
# IT REPORTS A REASON RATHER THAN A BARE $false, because the caller has to say what the reader is
# looking at either way: a session told "the tree stays on the branch" needs to know which of the three
# it was, or it will read a deliberate decision as a failure.
#
# StatusLines is `git status --porcelain` as the caller captured it. EMPTY MEANS CLEAN, and untracked
# files count as dirty on purpose: `git checkout main` carries them across too.
function Get-TrunkReturnDecision {
    param(
        [string[]]$PorcelainLines,
        # ALLOWEMPTYSTRING IS NOT A LOOSENING, IT IS WHAT MAKES THE FIRST GUARD BELOW REACHABLE.
        # Mandatory on a [string] rejects '' at the binder, so a caller handing over an unreadable path
        # got a terminating parameter-binding error inside a step whose whole posture is "never a
        # refusal". Found by the suite the moment the guard was asserted. Still Mandatory: the argument
        # must be PASSED, it just may be empty, and the function answers instead of throwing.
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$SelfPath,
        [Parameter(Mandatory = $true)][string]$TrunkBranch,
        [string[]]$StatusLines
    )
    $primary = Get-PrimaryWorktreePath -PorcelainLines $PorcelainLines
    $selfKey = Get-WorktreePathKey $SelfPath
    if (-not $selfKey) {
        return [pscustomobject]@{ Return = $false; Reason = "this tree's own path could not be read" }
    }
    if (-not $primary) {
        return [pscustomobject]@{ Return = $false; Reason = "'git worktree list' named no primary checkout" }
    }
    if ((Get-WorktreePathKey $primary) -ne $selfKey) {
        return [pscustomobject]@{
            Return = $false
            Reason = "this is a lane, not the primary checkout ($primary) -- a lane keeps its own branch, and step 5b puts it back"
        }
    }
    $holder = Get-WorktreeHoldingBranch -PorcelainLines $PorcelainLines -Branch $TrunkBranch -SelfPath $SelfPath
    if ($holder) {
        return [pscustomobject]@{
            Return = $false
            Reason = "'$TrunkBranch' is held by another worktree at $holder"
        }
    }
    $dirty = @(@($StatusLines) | Where-Object { $_ -and "$_".Trim() })
    if ($dirty.Count -gt 0) {
        return [pscustomobject]@{
            Return = $false
            Reason = "the working tree is not clean ($($dirty.Count) path(s)) -- a checkout would take them to the trunk or fail on them"
        }
    }
    return [pscustomobject]@{ Return = $true; Reason = '' }
}

# WHICH TREE DOES THE FOLD RUN IN? (issue #1753, September 9, 2026.)
#
# THE INCONSISTENCY THIS CLOSES SITS INSIDE ONE SCRIPT, and both halves are above. Get-TrunkReturnDecision
# declines the trunk return on an unclean tree for a stated reason -- "a checkout would take them to the
# trunk or fail on them" -- and ship-pr.ps1's step 5 then ran `git checkout main` UNCONDITIONALLY, which
# is that same checkout, performed after the merge instead of refused before it. Measured shipping PR
# #1752: one unrelated uncommitted path (.claude/settings.json) made step 2b stay on the branch, and step
# 5 checked the trunk out over it anyway, dragged it there, and lost the fold to `git merge --ff-only`
# ("Your local changes to the following files would be overwritten by merge"). Merged, not folded -- the
# one state nothing reports until a release trips over it.
#
# THE ANSWER IS NOT A REFUSAL, AND THAT IS A DELIBERATE DEPARTURE FROM WHAT THE REPORT ASKED FOR. Its
# suggested shape was a step-0 refusal on the same reading, on this tree's "a refusal costs nothing
# before the irreversible act" posture (#1405, #1417). But step 5 ALREADY has an arm that does not touch
# this checkout at all -- the throwaway worktree #1069 added for a HEAD that moved -- and it is available
# in exactly the failing case: an unclean tree means step 2b declined, which means HEAD is still on the
# shipping branch, which means the trunk is free (step 0a refused otherwise) and `git worktree add` can
# have it. So the fold completes rather than being refused, the uncommitted path stays where its author
# left it, and the condition the report itself named -- "the fold would have to ff-only past it" -- is
# false instead of guarded. A refusal would have stopped a ship this repairs.
#
# THE TRUNK ARM IS EXEMPT FROM THE DIRT TEST, and it has to be: git refuses `worktree add <path> main`
# once the primary holds main, so a tree already standing there has no second route and folds in place as
# it always did. That state is reachable -- step 2b returns a CLEAN tree to the trunk, and the CI wait
# after it is long enough for something else to write into it -- so the residual is real, narrow, and
# unpreventable at step 0, which is the second reason a step-0 refusal would have been aimed wrong. What
# it gets instead is ship-pr's post-merge failures naming the merged-but-unfolded state.
#
# THE STATUS LINES ARE READ AT STEP 5, NOT REUSED FROM STEP 2B, for the same reason: the CI wait sits
# between them, and a decision about the tree as it is now cannot be made from a reading taken before the
# longest step in the run.
#
# PURE, LIKE EVERY OTHER FUNCTION HERE. It takes the two strings git printed and the porcelain status
# lines, and answers which arm to take plus the sentence that arm prints -- so the branch that only a
# full live ship could otherwise exercise is asserted in worktree-lib.tests.ps1 instead.
function Get-FoldTreeDecision {
    param(
        # HEAD as `git rev-parse --abbrev-ref HEAD` printed it, or '' when that read failed.
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Head,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$ShipBranch,
        [Parameter(Mandatory = $true)][string]$TrunkBranch,
        [string[]]$StatusLines
    )
    # THE TRUNK FIRST, so the dirt test below cannot send a tree holding the trunk to a worktree add that
    # git will refuse. Order is load-bearing here, not stylistic.
    if ($Head -and $Head -eq $TrunkBranch) {
        return [pscustomobject]@{ InPlace = $true; Reason = '' }
    }
    if (-not $Head) {
        # AN UNREADABLE HEAD TAKES THE WORKTREE ROUTE, unchanged from #1069: it is the arm that leaves
        # somebody else's checkout alone, so being wrong about it costs a temporary directory.
        return [pscustomobject]@{
            InPlace = $false
            Reason  = "HEAD could not be read, so this checkout may be standing anywhere."
        }
    }
    if ($Head -ne $ShipBranch) {
        $shownHead = Get-DisplayRef -Ref $Head
        $shownShip = Get-DisplayRef -Ref $ShipBranch
        return [pscustomobject]@{
            InPlace = $false
            Reason  = "HEAD is on '$shownHead', not '$shownShip' -- this checkout moved while CI ran."
        }
    }
    # SAME COUNT, SAME FILTER as Get-TrunkReturnDecision's: a porcelain line that is blank or whitespace
    # is not a path, and both decisions have to agree about what "unclean" means or step 2b and step 5
    # go back to contradicting each other, which is the whole defect.
    $dirty = @(@($StatusLines) | Where-Object { $_ -and "$_".Trim() })
    if ($dirty.Count -gt 0) {
        return [pscustomobject]@{
            InPlace = $false
            Reason  = "the working tree is not clean ($($dirty.Count) path(s)) -- a checkout would take them to the trunk, and the fold's ff-only merge would fail on them (#1753)."
        }
    }
    return [pscustomobject]@{ InPlace = $true; Reason = '' }
}
# IS ANY WORKTREE STANDING INSIDE THE ONE WE ARE ABOUT TO WALK? (issue #1673, September 8, 2026.)
#
# THE HARNESS PLACES ITS OWN WORKTREE INSIDE THE REPO, at .claude/worktrees/agent-<id>, and nothing
# ignores that path. worktree-lane.ps1's own header already states the alternative this repo takes for
# ITS worktrees -- a lane sits in a SIBLING '<repo>-lanes/' directory, outside the tree, and its own
# header says why: "a worktree inside the tree would be walked by the lint gate's link scan and by the
# test suites, which would report a second copy of the whole repo as findings." The
# harness does not get that choice, so the tree-walking checks have to be told rather than left to find
# out the hard way: every count check-plugin-integrity.ps1 and its test suites take by walking
# $RepoRoot -Recurse doubles while a nested worktree stands, because it is a second, complete copy of
# the tree it is standing inside -- measured (issue #1673): plugin.json 6->12, *-subagent.md 26->52,
# SKILL.md 27->54, *.ps1 236->472, and the specialist-id check then reports 26 duplicate-id findings,
# one per agent def, each accusing the REAL file and naming the worktree's copy as the claimant.
#
# A PURE FUNCTION OF THE SAME PORCELAIN THE REST OF THIS FILE READS, deliberately, rather than a
# git-invoking check of its own: the caller (check-plugin-integrity.ps1) already has to read
# 'git worktree list --porcelain' to ask this, and Get-WorktreePathKey already carries the separator/
# case/trailing-slash normalisation this comparison needs -- re-deriving it here would be the third
# copy of that problem the header above already refused to write once more.
#
# -PrimaryRoot IS THE CALLER'S OWN $RepoRoot, NOT DERIVED FROM THE PORCELAIN. The caller already knows
# which tree it is (it is running from inside it), so asking Get-PrimaryWorktreePath to tell it back
# would trust the porcelain's own ORDER for a fact the caller can state directly -- and would answer
# nothing at all for a caller invoked from a tree git does not consider the main worktree.
#
# THE PREFIX TRAP, AND WHY A TRAILING SEPARATOR IS WHAT AVOIDS IT: 'C:\repo-lanes\x' shares the text
# prefix 'C:\repo' with 'C:\repo' but sits BESIDE it, not inside it -- exactly the trap
# Get-WorktreePathKey's own callers have hit before. Comparing against the key PLUS a trailing
# separator ('c:\repo\') means 'c:\repo-lanes\x' fails the test on the character right after the
# shared prefix ('-' is not '\'), while 'c:\repo\.claude\worktrees\agent-1' passes on the same
# character. The primary root itself is excluded explicitly rather than relying on the prefix test to
# reject it (a root's key trivially fails a STARTSWITH-ITS-OWN-PREFIX+SEPARATOR test already, but the
# exclusion is stated rather than left to be an accident of string comparison).
#
# AN UNREADABLE PrimaryRoot ANSWERS EMPTY RATHER THAN MATCHING EVERYTHING: an empty key would otherwise
# make an empty prefix ('\'), which a UNC worktree path ('\\server\share\...') satisfies trivially --
# reporting every worktree as nested inside a root the caller could not even name.
#
# ORDINAL, STATED RATHER THAN DEFAULTED: String.StartsWith(string) is CULTURE-SENSITIVE in .NET, which
# on a path comparison is a correctness question rather than a style one -- a culture-aware compare can
# treat ignorable characters (a soft hyphen, a zero-width joiner) as equal to nothing at all, so a
# crafted path could satisfy a prefix it does not actually sit under. Every other path StartsWith in
# this repo already passes one explicitly (worktree-lane.ps1, plugin-tree-lib.ps1, measure-context-lib.ps1);
# Ordinal rather than OrdinalIgnoreCase because Get-WorktreePathKey has already lowercased both sides.
function Get-NestedWorktreePath {
    param(
        [string[]]$PorcelainLines,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$PrimaryRoot
    )
    $primaryKey = Get-WorktreePathKey $PrimaryRoot
    if (-not $primaryKey) { return @() }
    $prefix = $primaryKey + '\'
    $nested = @()
    foreach ($record in (Get-WorktreeRecords -PorcelainLines $PorcelainLines)) {
        $key = Get-WorktreePathKey $record.Path
        if (-not $key -or $key -eq $primaryKey) { continue }
        if ($key.StartsWith($prefix, [System.StringComparison]::Ordinal)) { $nested += $record.Path }
    }
    return @($nested)
}

# THE SENTENCE THAT DESCRIBES THE DECISION ABOVE, and it is here because the one that used to describe it
# was a literal (issue #1616). ship-pr.ps1's step-3 preamble printed "step 2b already put it back on the
# trunk (#1073)" with no condition on it and no reference to what step 2b decided -- so on every run where
# the decision above declined, the line four rows under it asserted the opposite. Measured on PR #1615,
# September 8, 2026: step 2b printed "staying on 'fix/...' -- the working tree is not clean (1 path(s))",
# and the go-ahead then said the tree was back on the trunk.
#
# WHY IT MATTERS MORE THAN AN ORDINARY WRONG LINE: that line is explicitly framed as THE GO-AHEAD, printed
# so a reader can act on it. Believing the primary checkout is home while it is standing on the shipping
# branch is exactly the state #1073 and the orchestrator's "it ends on the trunk" rule exist to prevent --
# reported, there, as already handled.
#
# THE TRUNK CLAUSE IS THE ONLY HALF THAT WAS WRONG, so the other two are unconditional here as they were
# in the literal. Step 1 is the only step that reads the working tree, so "step 1 is over, the tree is
# free (#1145)" is true at that point on every path through the script.
#
# AND THE FALSE ARM POINTS AT THE LANE RATHER THAN ONLY WITHDRAWING THE CLAIM. A reader who has just been
# told the trunk clause does not hold needs the next move, not a gap: a lane is detached at origin/<trunk>,
# so it is unaffected by where the primary happens to stand (#1069), which is what keeps the invitation
# whole in both arms. Naming only what is unsafe was the defect #1428 repaired one line up; this must not
# reintroduce it one line down.
#
# THE BRANCH NAME IS OPTIONAL because it is the caller's variable rather than something this function can
# read, and a go-ahead that cannot be worded is worse than one that names the branch less precisely. Empty
# gives "on its branch", which is still true and still points at the lane.
#
# AND IT WAS INTERPOLATED RAW UNTIL #1623, on a reasoning this comment already flagged as unsettled: that
# #1594 had scoped display out because git rejects the characters that make prose deceptive. It rejects
# \p{Cc} and ACCEPTS \p{Cf} (measured, exit 0 on U+202E and U+200D), so the residual this note handed to
# #1617 turned out to be the whole of it. What has NOT changed is the reason not to treat this line
# specially: it is stripped exactly as the other prose sites are, through the one definition in
# ref-print-lib.ps1, rather than refused the way a paste site is.
#
# THE STRIP LIVES HERE RATHER THAN AT THE CALLER, which is the next question. ship-pr.ps1 could hand in a
# stripped label and this function stay pure -- and then the guarantee would sit one file away from the
# sentence it protects, free to drift the moment a second caller appears. It is the same argument
# ship-pr.ps1 makes for judging the paste verdict once beside the read that produced it, applied the other
# way round: the composer owns what its own output may contain, so this function's suite can assert it.
#
# THIS IS THE GO-AHEAD LINE (#1616) -- the one line the ship documents as safe to act on -- which is why a
# name that prints as something other than what it is costs more here than anywhere else in the script.
function Get-TrunkReturnGoAheadLine {
    param(
        [Parameter(Mandatory = $true)][bool]$Returned,
        [AllowEmptyString()][string]$Branch = ''
    )
    $lead = 'This line is the go-ahead: step 1 is over, the tree is free (#1145)'
    if ($Returned) {
        return "$lead, and step 2b already put it back on the trunk (#1073)."
    }
    $shownBranch = Get-DisplayRef -Ref $Branch
    $where = if ($shownBranch) { "on '$shownBranch'" } else { 'on its branch' }
    return "$lead -- but step 2b left this checkout $where (its line above says why), so take the lane below rather than a second terminal in this checkout (#1073)."
}
