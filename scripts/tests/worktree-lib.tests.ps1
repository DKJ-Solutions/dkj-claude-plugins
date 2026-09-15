<#
.SYNOPSIS
    Regression tests for scripts/lib/worktree-lib.ps1 -- the porcelain reader behind ship-pr.ps1's
    trunk-lock pre-flight (issue #1069), its trunk hand-back before the CI wait (issue #1073), its
    choice of which tree to fold in after the merge (issue #1753), and prune-merged.ps1's error message.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Every function in the lib is pure -- it takes
    the lines `git worktree list --porcelain` produced and returns strings -- so the whole suite runs
    in-process against dot-sourced fixtures. No git, no repository, no temp directory.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/worktree-lib.tests.ps1

    THAT PURITY IS THE REASON THE LIB EXISTS, and it is worth saying here rather than only in the lib.
    ship-pr.ps1 drives live git and gh against a real remote and carries no suite of its own; its own
    header asks for exactly this ("anything in here that is a pure function of text belongs in a lib,
    precisely because this file cannot be tested"). The decision the #1069 repair turns on -- does
    another worktree hold the trunk? -- is that pure function, so it is asserted here instead of being
    exercised only by a full live ship whose failure mode is a merged-but-unfolded PR.

    What is asserted:
      1. the porcelain parses into one record per stanza, with the branch stored SHORT ('main', not
         'refs/heads/main') and the detached/bare markers read;
      2. a stanza closes on the next `worktree` line rather than on the blank line between stanzas --
         the case that matters because captured output is routinely trimmed;
      3. Get-PrimaryWorktreePath returns the FIRST stanza, which is the only thing in the output that
         identifies the main worktree;
      4. Get-WorktreeHoldingBranch finds another tree holding the trunk, and -- the case that would
         otherwise refuse every ordinary run -- does NOT report the caller's own tree as the holder;
      5. the path comparison survives the three ways two spellings of one Windows directory differ:
         separator, case, and a trailing separator;
      6. the empty and malformed inputs answer rather than throw, since every caller reaches this lib
         with whatever git actually printed;
      7. Get-TrunkReturnDecision answers all three of its conditions (issue #1073): the primary
         checkout only, nobody else holding the trunk, and a clean tree -- and answers rather than
         throwing on everything git might hand over, because step 2b is not a gate and a decision it
         cannot make must leave the ship running;
      8. Get-TrunkReturnGoAheadLine DESCRIBES that decision rather than asserting an outcome (issue
         #1616) -- the no arm never claims the trunk, both arms keep the two clauses that are true
         either way, and a missing branch name still words a printable line;
      9. the branch name that line prints cannot read as a DIFFERENT branch (issue #1623) -- git accepts
         \p{Cf} in a ref, so the composer strips its own input rather than trusting the caller to;
     10. Get-NestedWorktreePath (issue #1673) finds a worktree standing INSIDE the primary root -- the
         shape the harness's own dispatched-agent worktree takes -- while a sibling lane and a directory
         that merely shares a text PREFIX with the primary ('<repo>-lanes/x' against '<repo>') are both
         left unreported, the primary never reports itself, and an empty/malformed/unreadable input
         answers no findings rather than throwing or matching everything;
     11. Get-FoldTreeDecision (issue #1753) sends an UNCLEAN tree to the throwaway worktree instead of
         checking the trunk out over it -- the same reading Get-TrunkReturnDecision already makes at step
         2b, which step 5 made after the merge instead of before it -- while a tree already ON the trunk
         stays exempt (git refuses `worktree add` there), the ordinary clean run still folds in place, and
         the sentence each arm prints says which of the three reasons it was rather than asserting one.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\worktree-lib.ps1')
# FOR SECTION 8's PREMISE CHECK ONLY. `git check-ref-format` writes its refusal to stderr, and a bare
# native call under $ErrorActionPreference = 'Stop' turns that into a NativeCommandError in Windows
# PowerShell 5.1 -- so the premise reads an exit code through the capture lib rather than fighting the
# host. Same reasoning, same call, as ref-print-lib.tests.ps1.
. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

function Assert-Equal {
    param([string]$Expected, [string]$Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        Write-Host "         expected: '$Expected'" -ForegroundColor DarkGray
        Write-Host "         actual:   '$Actual'" -ForegroundColor DarkGray
    }
}

# The real thing, captured on this machine the day #1069 was filed: a primary checkout on a branch, and
# a lane standing on main because its own ship-pr left it there. Forward slashes, because that is how
# git spells a Windows path in this output.
$PorcelainTwoTrees = @(
    'worktree C:/Users/dave/Documents/GitHub/DaveKJohn/claude-code-specialists',
    'HEAD 926bd0cabf0f9d8e4e3f2a1b0c9d8e7f6a5b4c3d',
    'branch refs/heads/fix/a-lane-must-not-hold-the-trunk-hostage-v1',
    '',
    'worktree C:/Users/dave/Documents/GitHub/DaveKJohn/claude-code-specialists-lanes/feat--thumbnail',
    'HEAD 3fd2905a1122334455667788990011aabbccddee',
    'branch refs/heads/main',
    ''
)
$PrimaryPath = 'C:/Users/dave/Documents/GitHub/DaveKJohn/claude-code-specialists'
$LanePath    = 'C:/Users/dave/Documents/GitHub/DaveKJohn/claude-code-specialists-lanes/feat--thumbnail'

Write-Host ""
Write-Host "1. Get-WorktreeRecords -- the stanzas" -ForegroundColor Cyan

$records = Get-WorktreeRecords -PorcelainLines $PorcelainTwoTrees
Assert-Equal '2' "$($records.Count)" 'two stanzas produce two records'
Assert-Equal $PrimaryPath $records[0].Path 'the first record carries the primary path'
Assert-Equal 'fix/a-lane-must-not-hold-the-trunk-hostage-v1' $records[0].Branch `
    "the branch is stored SHORT -- 'refs/heads/' is stripped once, in the parser"
Assert-Equal 'main' $records[1].Branch 'the lane record carries the trunk'
Assert-True (-not $records[0].Detached) 'an attached stanza is not detached'
Assert-True (-not $records[0].Bare) 'an attached stanza is not bare'

# A LANE OPENED BY worktree-lane.ps1 IS DETACHED at origin/<trunk> until its branch is created, so this
# shape is the normal one rather than an edge case -- and a detached stanza must not answer as holding
# any branch at all.
$PorcelainDetached = @(
    'worktree C:/repo',
    'HEAD aaaa',
    'branch refs/heads/main',
    '',
    'worktree C:/repo-lanes/fresh',
    'HEAD bbbb',
    'detached',
    ''
)
$detachedRecords = Get-WorktreeRecords -PorcelainLines $PorcelainDetached
Assert-True $detachedRecords[1].Detached 'a detached stanza is read as detached'
Assert-Equal '' $detachedRecords[1].Branch 'a detached stanza holds no branch'

$bareRecords = Get-WorktreeRecords -PorcelainLines @('worktree C:/repo.git', 'bare')
Assert-True $bareRecords[0].Bare 'a bare stanza is read as bare'

# THE BLANK LINE IS NOT THE DELIMITER, and this assert is why. Invoke-NativeCapture's callers routinely
# trim and filter captured output, so a parser that split on blank lines would fold two worktrees into
# one exactly where the answer matters -- and would report the trunk as unheld.
$noBlanks = @($PorcelainTwoTrees | Where-Object { $_ })
$trimmedRecords = Get-WorktreeRecords -PorcelainLines $noBlanks
Assert-Equal '2' "$($trimmedRecords.Count)" 'stanzas separate on the `worktree` line, not on the blank line'
Assert-Equal 'main' $trimmedRecords[1].Branch 'the second stanza is intact without its blank line'

Write-Host ""
Write-Host "2. Get-PrimaryWorktreePath -- git lists the main worktree first" -ForegroundColor Cyan

Assert-Equal $PrimaryPath (Get-PrimaryWorktreePath -PorcelainLines $PorcelainTwoTrees) `
    'the primary is the FIRST stanza, which is the only thing that identifies it'
Assert-Equal '' (Get-PrimaryWorktreePath -PorcelainLines @()) 'no stanzas answers empty rather than throwing'

Write-Host ""
Write-Host "3. Get-WorktreeHoldingBranch -- the question ship-pr asks before it merges" -ForegroundColor Cyan

Assert-Equal $LanePath (Get-WorktreeHoldingBranch -PorcelainLines $PorcelainTwoTrees -Branch 'main' -SelfPath $PrimaryPath) `
    'a lane standing on the trunk is named, so the refusal can print a directory'
Assert-Equal '' (Get-WorktreeHoldingBranch -PorcelainLines $PorcelainTwoTrees -Branch 'main' -SelfPath $LanePath) `
    'the tree asking the question is never its own blocker'

# THE CASE THAT WOULD BREAK EVERY ORDINARY RUN. A single checkout already standing on main is the state
# ship-pr's step 5 deliberately leaves the primary in, so a pre-flight that reported it as held would
# refuse the next chain in the one repo shape that has no lanes at all.
$PorcelainSingleOnTrunk = @('worktree C:/repo', 'HEAD aaaa', 'branch refs/heads/main', '')
Assert-Equal '' (Get-WorktreeHoldingBranch -PorcelainLines $PorcelainSingleOnTrunk -Branch 'main' -SelfPath 'C:/repo') `
    'a lone checkout on the trunk does not report itself'
Assert-Equal '' (Get-WorktreeHoldingBranch -PorcelainLines $PorcelainTwoTrees -Branch 'docs/nobody' -SelfPath $PrimaryPath) `
    'a branch no worktree holds answers empty'

Write-Host ""
Write-Host "4. Get-WorktreePathKey -- the three ways one Windows directory has two spellings" -ForegroundColor Cyan

Assert-Equal (Get-WorktreePathKey 'C:/repo/lane') (Get-WorktreePathKey 'C:\repo\lane') `
    'separator: git prints forward slashes, PowerShell composes back slashes'
Assert-Equal (Get-WorktreePathKey 'C:\Repo\Lane') (Get-WorktreePathKey 'c:\repo\lane') `
    'case: NTFS is case-insensitive, so two spellings are one directory'
Assert-Equal (Get-WorktreePathKey 'C:\repo\lane\') (Get-WorktreePathKey 'C:\repo\lane') `
    'a trailing separator, which Join-Path and a typed path disagree about'
Assert-Equal '' (Get-WorktreePathKey '') 'an empty path answers empty rather than throwing'

# Proof that the key is actually WIRED INTO the lookup, not merely available beside it: the self-path is
# handed in with every one of the three differences at once, and the tree must still recognise itself.
Assert-Equal '' (Get-WorktreeHoldingBranch -PorcelainLines $PorcelainSingleOnTrunk -Branch 'main' -SelfPath 'c:\REPO\') `
    'the self-comparison goes through the key, not through -eq'
Write-Host ""
Write-Host "5. Input git might actually hand over" -ForegroundColor Cyan

Assert-Equal '0' "$((Get-WorktreeRecords -PorcelainLines @()).Count)" 'no lines produce no records'
Assert-Equal '0' "$((Get-WorktreeRecords -PorcelainLines $null).Count)" 'a null input produces no records'
# A `branch` line before any `worktree` line cannot happen in git's output, which is exactly why it is
# asserted: every caller here reaches this lib with whatever a failing or future git printed, and a
# parser that dereferenced $current would throw at the one moment the caller is trying to report a
# problem.
Assert-Equal '0' "$((Get-WorktreeRecords -PorcelainLines @('branch refs/heads/main', 'HEAD aaaa')).Count)" `
    'lines before the first stanza are ignored rather than throwing'
Assert-Equal '' (Get-WorktreeHoldingBranch -PorcelainLines @('garbage') -Branch 'main' -SelfPath 'C:/repo') `
    'unparseable output answers "nobody holds it" rather than throwing'


Write-Host ""
Write-Host "6. Get-TrunkReturnDecision -- may this tree go home while the ship runs? (issue #1073)" -ForegroundColor Cyan

# THE ORDINARY RUN: the primary checkout stands on its shipping branch, no lane holds the trunk, and the
# tree is clean. This is the case the whole repair exists for -- without it the close-out has to choose
# between "parking is a state" and "it ends on the trunk", and #1073 measured what choosing costs.
$PorcelainPrimaryOnBranch = @(
    'worktree C:/repo',
    'HEAD aaaa',
    'branch refs/heads/fix/something-v1',
    ''
)
Assert-True (Get-TrunkReturnDecision -PorcelainLines $PorcelainPrimaryOnBranch -SelfPath 'C:/repo' -TrunkBranch 'main' -StatusLines @()).Return `
    'the primary checkout on a clean tree goes back to the trunk'
Assert-Equal '' (Get-TrunkReturnDecision -PorcelainLines $PorcelainPrimaryOnBranch -SelfPath 'C:/repo' -TrunkBranch 'main' -StatusLines @()).Reason `
    'a yes carries no reason -- there is nothing for the reader to be told'

# A LANE MUST NOT TAKE THE TRUNK HERE, and this is the assert that keeps #1069 closed. Step 5b hands a
# lane back to its own branch AFTER the fold; a lane taking the trunk at step 2b would hold the
# clone-wide lock for the whole CI wait instead of for the length of a fold -- strictly worse than the
# defect #1069 repaired, introduced by the repair for #1073.
$decLane = Get-TrunkReturnDecision -PorcelainLines $PorcelainTwoTrees -SelfPath $LanePath -TrunkBranch 'main' -StatusLines @()
Assert-True (-not $decLane.Return) 'a lane does not take the trunk at step 2b'
Assert-True ($decLane.Reason -like '*not the primary checkout*') 'and the reason names the primary checkout'
Assert-True ($decLane.Reason -like "*$PrimaryPath*") 'and names the directory, so the reader can go there'

# SOMEBODY ELSE HOLDS THE TRUNK: git would refuse the checkout anyway, so this is asked rather than
# attempted. $PorcelainTwoTrees is the lane-on-main capture, seen from the primary this time.
$decHeld = Get-TrunkReturnDecision -PorcelainLines $PorcelainTwoTrees -SelfPath $PrimaryPath -TrunkBranch 'main' -StatusLines @()
Assert-True (-not $decHeld.Return) 'the trunk held by another worktree is not taken from it'
Assert-True ($decHeld.Reason -like "*$LanePath*") 'and the holder is named'

# A DIRTY TREE IS #972'S TWO OUTCOMES MET ONE STEP EARLIER: a colliding edit makes the checkout exit 1,
# and a non-colliding one TRAVELS TO THE TRUNK. The branch's own work is committed and pushed by step 1,
# so anything here is something else -- and something else is what must not ride along.
$decDirty = Get-TrunkReturnDecision -PorcelainLines $PorcelainPrimaryOnBranch -SelfPath 'C:/repo' -TrunkBranch 'main' -StatusLines @(' M scripts/lib/worktree-lib.ps1')
Assert-True (-not $decDirty.Return) 'a modified file keeps the tree where it is'
Assert-True ($decDirty.Reason -like '*not clean*') 'and the reason says so'
# UNTRACKED COUNTS AS DIRTY ON PURPOSE: `git checkout main` carries an untracked file across too, which
# is the silent half of #972's second outcome.
Assert-True (-not (Get-TrunkReturnDecision -PorcelainLines $PorcelainPrimaryOnBranch -SelfPath 'C:/repo' -TrunkBranch 'main' -StatusLines @('?? notes.txt')).Return) `
    'an untracked file counts as dirty'
# Blank lines are not dirt. Invoke-NativeCapture's callers trim, and an empty capture can arrive as a
# single empty string rather than as no elements at all.
Assert-True (Get-TrunkReturnDecision -PorcelainLines $PorcelainPrimaryOnBranch -SelfPath 'C:/repo' -TrunkBranch 'main' -StatusLines @('', '   ')).Return `
    'blank status lines are not treated as changes'

# ALREADY ON THE TRUNK: the tree is the primary, holds main itself, and Get-WorktreeHoldingBranch
# excludes it -- so the answer is yes and step 2b's checkout is the no-op it should be. Asserted because
# the opposite (a tree reporting itself as its own blocker) is exactly the bug -SelfPath exists for.
Assert-True (Get-TrunkReturnDecision -PorcelainLines $PorcelainSingleOnTrunk -SelfPath 'C:/repo' -TrunkBranch 'main' -StatusLines @()).Return `
    'a tree already on the trunk does not report itself as the blocker'

# WHAT GIT MIGHT ACTUALLY HAND OVER. Every one of these answers instead of throwing, because step 2b is
# not a gate: a decision it cannot make must leave the ship running, never stop it.
$decEmpty = Get-TrunkReturnDecision -PorcelainLines @() -SelfPath 'C:/repo' -TrunkBranch 'main' -StatusLines @()
Assert-True (-not $decEmpty.Return) 'an empty porcelain answers no'
Assert-True ($decEmpty.Reason -like '*no primary checkout*') 'and says the list named no primary checkout'
Assert-True (-not (Get-TrunkReturnDecision -PorcelainLines $PorcelainPrimaryOnBranch -SelfPath '' -TrunkBranch 'main' -StatusLines @()).Return) `
    'an unreadable self path answers no'
Assert-True (-not (Get-TrunkReturnDecision -PorcelainLines @('garbage') -SelfPath 'C:/repo' -TrunkBranch 'main' -StatusLines @()).Return) `
    'unparseable output answers no rather than throwing'
# THE TRUNK IS A PARAMETER, NOT 'main': a consumer whose trunk is 'master' or 'trunk' gets the same
# three conditions. ship-pr passes 'main' because that is this repo's trunk, not because the lib knows it.
$PorcelainMasterLane = @(
    'worktree C:/repo', 'HEAD aaaa', 'branch refs/heads/fix/x', '',
    'worktree C:/lane', 'HEAD bbbb', 'branch refs/heads/master', ''
)
Assert-True (-not (Get-TrunkReturnDecision -PorcelainLines $PorcelainMasterLane -SelfPath 'C:/repo' -TrunkBranch 'master' -StatusLines @()).Return) `
    'the trunk name is the caller''s, not hardcoded'
Assert-True (Get-TrunkReturnDecision -PorcelainLines $PorcelainMasterLane -SelfPath 'C:/repo' -TrunkBranch 'main' -StatusLines @()).Return `
    'and a lane on master does not block a repo whose trunk is main'

Write-Host ""
Write-Host "7. Get-TrunkReturnGoAheadLine -- does the go-ahead say what step 2b actually did? (issue #1616)" -ForegroundColor Cyan

# THE DEFECT THIS SECTION PINS was not a wrong decision but a wrong SENTENCE about it. ship-pr's step-3
# preamble asserted "step 2b already put it back on the trunk" as a literal, so on every run where the
# decision above declined -- the dirty tree, the lane, a held trunk, an unreadable porcelain -- the line
# a reader is told to act on said the opposite of the line four rows above it. Measured on PR #1615,
# September 8, 2026.
$goYes = Get-TrunkReturnGoAheadLine -Returned $true -Branch 'fix/something-v1'
Assert-True ($goYes -like '*put it back on the trunk*') 'the yes arm still says the tree went home'
Assert-True ($goYes -like '*#1073*') 'and still cites the issue that put step 2b there'

$goNo = Get-TrunkReturnGoAheadLine -Returned $false -Branch 'fix/something-v1'
# THE ONE ASSERT THE OLD LITERAL COULD NOT PASS: no arm of this line may claim the trunk when step 2b
# did not take it. Worded as an absence on purpose -- a future rewording is free, claiming the trunk is
# not.
Assert-True ($goNo -notlike '*put it back on the trunk*') 'the no arm does not claim the trunk'
Assert-True ($goNo -like "*'fix/something-v1'*") 'and names the branch the checkout is standing on'
Assert-True ($goNo -like '*lane*') 'and points at the lane, which is unaffected by where the primary stands (#1069)'

# BOTH ARMS KEEP THE TWO TRUE CLAUSES. Step 1 is the only step that reads the working tree, so the tree
# really is free at this point however step 2b answered -- withdrawing that half along with the trunk
# clause would cancel the invitation #1428 exists to make.
foreach ($line in @($goYes, $goNo)) {
    Assert-True ($line -like 'This line is the go-ahead:*') 'the line still announces itself as the go-ahead'
    Assert-True ($line -like '*step 1 is over*') 'and still says step 1 is over'
    Assert-True ($line -like '*the tree is free (#1145)*') 'and still says the tree is free'
}

# NO BRANCH NAME IS A WORDING PROBLEM, NOT A REFUSAL: the name is the caller's variable, and a go-ahead
# that cannot be printed is worse than one that names the branch less precisely.
$goBare = Get-TrunkReturnGoAheadLine -Returned $false
Assert-True ($goBare -like '*on its branch*') 'an unknown branch name still words the no arm'
Assert-True ($goBare -notlike "*''*") 'and never prints an empty pair of quotes'

Write-Host ""
Write-Host "8. ...and the name it prints cannot read as a different branch (issue #1623)" -ForegroundColor Cyan

# THIS IS THE GO-AHEAD LINE, the one line ship-pr documents as safe to act on, and until #1623 it put the
# branch name in raw. The comment above the function said so and handed the residual to #1617, which
# measured it: `git check-ref-format` enforces \p{Cc} and ACCEPTS \p{Cf}, so a branch carrying U+202E or a
# zero-width run is creatable, checkout-able, and returned verbatim by `git rev-parse --abbrev-ref HEAD`.
# The premise is asserted here rather than assumed, exactly as ref-print-lib's suite does it: if a future
# git tightened its ref rules, that assert is the one that should go red.
$evilRef = 'fix/a' + [char]0x202E + 'b'
$fmt = Invoke-NativeCapture -FilePath 'git' -Arguments @('check-ref-format', '--branch', $evilRef) -DiscardStderr
Assert-True ($fmt.ExitCode -eq 0) 'premise: git accepts a branch name carrying U+202E'

$goEvil = Get-TrunkReturnGoAheadLine -Returned $false -Branch $evilRef
Assert-True ($goEvil -notmatch '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]') 'no control, format, line/paragraph separator or combining-mark character survives into the go-ahead line'
Assert-True ($goEvil -like "*'fix/a b'*") 'and the name still reads, stripped, so the operator can recognise the branch'
Assert-True ($goEvil -like '*lane*') 'the no arm keeps pointing at the lane -- the strip is not a refusal to word the line'

# A NAME MADE ENTIRELY OF FORMAT CHARACTERS HAS NO DISPLAY, so it takes the same arm as no name at all
# rather than printing a pair of quotes around blanks.
$goInvisible = Get-TrunkReturnGoAheadLine -Returned $false -Branch ([string]([char]0x200B) + [char]0x200D)
Assert-True ($goInvisible -like '*on its branch*') 'an all-invisible name words the no arm like a missing one'
Assert-True ($goInvisible -notmatch "'\s*'") 'and never prints quotes around nothing'

# THE STRIP IS THE COMPOSER'S, NOT THE CALLER'S. ship-pr could hand in a stripped label and this function
# stay pure -- and the guarantee would then sit one file away from the sentence it protects, free to drift
# the moment a second caller appears. Asserted structurally so a future refactor back to the caller has to
# argue with this line rather than pass quietly.
$libText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\lib\worktree-lib.ps1'))
Assert-True ($libText -match 'ref-print-lib\.ps1') 'worktree-lib dot-sources the lib that owns the one strip definition'
Assert-True ($libText -match [regex]::Escape('$shownBranch = Get-DisplayRef -Ref $Branch')) 'and the go-ahead composer strips its own input'

Write-Host ""
Write-Host "9. Get-NestedWorktreePath -- is a worktree standing INSIDE the one we are about to walk? (issue #1673)" -ForegroundColor Cyan

# THE SHAPE THE HARNESS ACTUALLY PRODUCES: a dispatched agent's worktree lands at
# .claude/worktrees/agent-<id>, INSIDE the primary root rather than beside it like a lane.
$PorcelainAgentWorktree = @(
    'worktree C:/repo',
    'HEAD aaaa',
    'branch refs/heads/fix/1673-ignore-agent-worktrees',
    '',
    'worktree C:/repo/.claude/worktrees/agent-1',
    'HEAD bbbb',
    'detached',
    ''
)
Assert-Equal 'C:/repo/.claude/worktrees/agent-1' `
    "$((Get-NestedWorktreePath -PorcelainLines $PorcelainAgentWorktree -PrimaryRoot 'C:/repo'))" `
    'a worktree standing inside the primary root is reported'

# A SIBLING LANE IS NOT NESTED -- worktree-lane.ps1 places it OUTSIDE the tree on purpose (its own header
# says why), and this function must not report the very thing that repair exists to keep clear of a walk.
Assert-Equal '0' "$((Get-NestedWorktreePath -PorcelainLines $PorcelainTwoTrees -PrimaryRoot $PrimaryPath).Count)" `
    'a sibling lane (<repo>-lanes/...) is not reported as nested'

# THE PREFIX TRAP: 'C:/repo-lanes/x' shares the TEXT prefix 'C:/repo' with 'C:/repo' but sits beside it,
# not inside it -- the same trap Get-WorktreePathKey's own callers have hit before. A prefix test with no
# trailing separator would wrongly report this one.
$PorcelainPrefixTrap = @(
    'worktree C:/repo',
    'HEAD aaaa',
    'branch refs/heads/main',
    '',
    'worktree C:/repo-lanes/x',
    'HEAD bbbb',
    'branch refs/heads/feat/x',
    ''
)
Assert-Equal '0' "$((Get-NestedWorktreePath -PorcelainLines $PorcelainPrefixTrap -PrimaryRoot 'C:/repo').Count)" `
    'a directory merely sharing a text prefix with the primary root is not reported as nested'

# PROOF THAT Get-WorktreePathKey IS ACTUALLY WIRED IN, not merely available beside it: the primary root is
# handed in with all three of its differences at once (separator, case, trailing separator), and the
# nested worktree must still be recognised as nested rather than as a false stranger.
Assert-Equal 'C:/repo/.claude/worktrees/agent-1' `
    "$((Get-NestedWorktreePath -PorcelainLines $PorcelainAgentWorktree -PrimaryRoot 'c:\REPO\'))" `
    'the primary-root comparison goes through the key, not through -eq'

# THE PRIMARY ITSELF IS NEVER ITS OWN FINDING, exactly as Get-WorktreeHoldingBranch must never report the
# tree asking the question as its own blocker.
$soloRecords = @('worktree C:/repo', 'HEAD aaaa', 'branch refs/heads/main', '')
Assert-Equal '0' "$((Get-NestedWorktreePath -PorcelainLines $soloRecords -PrimaryRoot 'C:/repo').Count)" `
    'a lone checkout does not report itself as nested inside itself'

# WHAT GIT (OR THE CALLER) MIGHT ACTUALLY HAND OVER: every one of these answers empty rather than
# throwing, since this is read alongside a lint gate that must degrade quietly when git is unavailable.
Assert-Equal '0' "$((Get-NestedWorktreePath -PorcelainLines @() -PrimaryRoot 'C:/repo').Count)" `
    'empty porcelain answers no findings rather than throwing'
Assert-Equal '0' "$((Get-NestedWorktreePath -PorcelainLines @('garbage') -PrimaryRoot 'C:/repo').Count)" `
    'unparseable porcelain answers no findings rather than throwing'
# AN UNREADABLE PRIMARY ROOT MUST NOT MATCH EVERYTHING: an empty key would otherwise build an empty
# prefix, which a UNC worktree path ('\\server\share\...') would satisfy trivially.
Assert-Equal '0' "$((Get-NestedWorktreePath -PorcelainLines $PorcelainAgentWorktree -PrimaryRoot '').Count)" `
    'an unreadable primary root answers no findings rather than matching every worktree'

# TWO NESTED WORKTREES AT ONCE, because the caller loops over whatever this returns and the harness has no
# rule against a second dispatch while a first is standing. The implementation accumulates rather than
# returning on the first hit, and this is what holds it to that -- a single-finding regression would still
# pass every assert above, since each of those has exactly one nested tree to find.
$PorcelainTwoNested = @(
    'worktree C:/repo',
    'HEAD aaaa',
    'branch refs/heads/main',
    '',
    'worktree C:/repo/.claude/worktrees/agent-1',
    'HEAD bbbb',
    'detached',
    '',
    'worktree C:/repo/.claude/worktrees/agent-2',
    'HEAD cccc',
    'detached',
    ''
)
Assert-Equal '2' "$((Get-NestedWorktreePath -PorcelainLines $PorcelainTwoNested -PrimaryRoot 'C:/repo').Count)" `
    'two worktrees standing inside the primary root are both reported, not just the first'

Write-Host ""
Write-Host "10. Get-FoldTreeDecision -- which tree does step 5 fold in? (issue #1753)" -ForegroundColor Cyan

# THE DEFECT: step 5 chose its arm on HEAD'S LOCATION ALONE, so a tree standing where this script left
# it got `git checkout main` run over it however unclean it was -- the same checkout Get-TrunkReturnDecision
# above had already declined, made after the merge instead of before it. Measured shipping PR #1752: one
# unrelated uncommitted path, carried onto the trunk by that checkout, and `git merge --ff-only` then
# failed on it. Merged, not folded.
$Ship = 'fix/1753-example'

# THE ORDINARY FOREGROUND RUN: HEAD is still on the shipping branch and nothing is uncommitted, so the
# in-place arm runs exactly what it always ran. This is the assert that keeps the repair from becoming a
# worktree on every ship.
$fdClean = Get-FoldTreeDecision -Head $Ship -ShipBranch $Ship -TrunkBranch 'main' -StatusLines @()
Assert-True $fdClean.InPlace 'a clean tree on the shipping branch folds in place'
Assert-Equal '' $fdClean.Reason 'and an in-place answer carries no sentence -- nothing is being explained'

# THE REPAIR ITSELF. The worktree arm is correct whatever this checkout holds, so the fold completes
# instead of being refused -- which is why #1753 was NOT answered with a step-0 refusal.
$fdDirty = Get-FoldTreeDecision -Head $Ship -ShipBranch $Ship -TrunkBranch 'main' -StatusLines @(' M .claude/settings.json')
Assert-True (-not $fdDirty.InPlace) 'an unclean tree on the shipping branch folds in a worktree instead'
Assert-True ($fdDirty.Reason -like '*not clean*') 'and the sentence says why'
Assert-True ($fdDirty.Reason -like '*1 path*') 'and counts the paths, so the reader knows how much is in the way'
Assert-True ($fdDirty.Reason -notlike '*moved while CI ran*') 'and does NOT claim the checkout moved -- it did not'
# UNTRACKED COUNTS TOO, for the reason section 6 gives: `git checkout main` carries an untracked file
# across as well, and the ff-only merge fails on it just the same.
Assert-True (-not (Get-FoldTreeDecision -Head $Ship -ShipBranch $Ship -TrunkBranch 'main' -StatusLines @('?? notes.txt')).InPlace) `
    'an untracked file counts as unclean here too'
# AND THE TWO DECISIONS AGREE ABOUT WHAT DIRT IS. Step 2b and step 5 contradicting each other about the
# same tree is the whole defect, so a blank capture line is not dirt in either of them.
Assert-True (Get-FoldTreeDecision -Head $Ship -ShipBranch $Ship -TrunkBranch 'main' -StatusLines @('', '   ')).InPlace `
    'blank status lines are not treated as changes, exactly as at step 2b'

# THE TRUNK ARM IS EXEMPT, AND THIS IS THE ASSERT THAT KEEPS IT SO. git refuses `worktree add <path> main`
# once the primary holds main, so sending a tree already standing there to the worktree arm would turn a
# fold that mostly works into one that provably cannot. The state is reachable: step 2b returns a CLEAN
# tree to the trunk, and something can write into it during the CI wait.
$fdTrunkDirty = Get-FoldTreeDecision -Head 'main' -ShipBranch $Ship -TrunkBranch 'main' -StatusLines @(' M .claude/settings.json')
Assert-True $fdTrunkDirty.InPlace 'a tree already on the trunk folds in place even when unclean -- git would refuse the worktree'
Assert-True (Get-FoldTreeDecision -Head 'main' -ShipBranch $Ship -TrunkBranch 'main' -StatusLines @()).InPlace `
    'and a clean one does too, which is the ordinary run since #1073'

# HEAD MOVED: unchanged from #1069/#972, and asserted here because the sentence moved into this function.
$fdMoved = Get-FoldTreeDecision -Head 'docs/other-work' -ShipBranch $Ship -TrunkBranch 'main' -StatusLines @()
Assert-True (-not $fdMoved.InPlace) 'a checkout that moved to another branch is left alone'
Assert-True ($fdMoved.Reason -like '*moved while CI ran*') 'and the sentence still says the session moved'
Assert-True ($fdMoved.Reason -like "*'docs/other-work'*") 'and names where HEAD actually is'
Assert-True ($fdMoved.Reason -like "*'$Ship'*") 'and what it was expected to be'
Assert-True (-not (Get-FoldTreeDecision -Head 'HEAD' -ShipBranch $Ship -TrunkBranch 'main' -StatusLines @()).InPlace) `
    'a detached HEAD (which rev-parse prints as ''HEAD'') takes the worktree arm too'

# AN UNREADABLE HEAD TAKES THE WORKTREE ARM, deliberately: being wrong that way costs a temporary
# directory, being wrong the other way costs the merged-but-unfolded half-state.
$fdNoHead = Get-FoldTreeDecision -Head '' -ShipBranch $Ship -TrunkBranch 'main' -StatusLines @()
Assert-True (-not $fdNoHead.InPlace) 'an unreadable HEAD takes the worktree arm'
Assert-True ($fdNoHead.Reason -like '*could not be read*') 'and says so rather than inventing a branch name'
Assert-True ($fdNoHead.Reason -notlike '*moved while CI ran*') 'and does not claim the checkout moved'

# THE TRUNK IS THE CALLER'S PARAMETER HERE TOO: a consumer whose trunk is 'master' gets the same exemption.
Assert-True (Get-FoldTreeDecision -Head 'master' -ShipBranch $Ship -TrunkBranch 'master' -StatusLines @(' M x')).InPlace `
    'the trunk name is the caller''s, not hardcoded'
Assert-True (-not (Get-FoldTreeDecision -Head 'master' -ShipBranch $Ship -TrunkBranch 'main' -StatusLines @()).InPlace) `
    'and a tree on master is just another branch to a repo whose trunk is main'

# THE STRIP IS THIS COMPOSER'S TOO (issue #1623). Both names in the moved-HEAD sentence are refs read off
# git, so leaving either raw would sanitise one half of the line and print the other -- the exact defect
# section 8 pins for the go-ahead line.
$evilHead = 'docs/a' + [char]0x202E + 'b'
$fdEvil = Get-FoldTreeDecision -Head $evilHead -ShipBranch 'docs/plain' -TrunkBranch 'main' -StatusLines @()
Assert-True ($fdEvil.Reason -notmatch '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]') 'no control, format, line/paragraph separator or combining-mark character survives into the worktree-arm sentence'
Assert-True ($fdEvil.Reason -like "*'docs/a b'*") 'and the name still reads, stripped, so the operator can recognise it'

# WHAT GIT MIGHT ACTUALLY HAND OVER: every one of these answers instead of throwing. This decision runs
# AFTER the merge, so a function that throws here produces the very half-state it exists to prevent.
Assert-True (-not (Get-FoldTreeDecision -Head '' -ShipBranch '' -TrunkBranch 'main' -StatusLines @()).InPlace) `
    'an empty HEAD and an empty branch name answer rather than throwing'
Assert-True (Get-FoldTreeDecision -Head $Ship -ShipBranch $Ship -TrunkBranch 'main').InPlace `
    'omitting -StatusLines entirely is a clean tree, not an exception'

# AND ship-pr ACTUALLY ASKS. The whole repair is one call site; a refactor that reinstated the old
# `-eq $branch -or -eq 'main'` test would pass every assert above while restoring the defect.
$shipText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'scripts\release\ship-pr.ps1'))
Assert-True ($shipText -match 'Get-FoldTreeDecision') 'ship-pr chooses its fold tree through this function'
Assert-True ($shipText -match [regex]::Escape('if ($foldDecision.InPlace) {')) 'and branches on its answer rather than on HEAD alone'

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
