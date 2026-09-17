<#
.SYNOPSIS
    Tests for scripts/lib/forward-lane-lib.ps1 -- the decisions behind ship-pr's forward lap
    (issue #2087), plus the structural half: that ship-pr.ps1 laps on them.

.DESCRIPTION
    WHAT THIS SUITE IS ACTUALLY GUARDING. The lap makes the one thing this script must never do
    casually -- it pushes a merge onto a branch and then merges that branch -- so each of the four
    decisions is a place where being wrong costs something real:

      Get-UpdateBranchOutcome    reads an outcome as a failure    -> a ship refused that was fine
                                 reads a failure as an outcome    -> a lap waiting on a run that never
                                                                     starts, until the budget is gone
      Get-LocalRefForwardPlan    picks the wrong command          -> step 4 gates the merge on a
                                                                     document the PR does not contain
      Get-ForwardLapDecision     laps when it cannot help         -> the budget spent learning nothing
      Test-CertificateRenewed    believes the old run             -> the whole budget spent in seconds,
                                                                     re-reading one stale verdict

    THE LAST ONE IS THE SUBTLEST AND HAS THE MOST CASES BELOW. For a few seconds after a forward the
    check API still answers with the PREVIOUS run -- completed, green, and certifying a head that no
    longer exists -- so "has anything changed" has to distinguish three states that all look like an
    answer: a new run, the same run, and no run at all.

    IT SPAWNS NOTHING AND WRITES NOTHING. Every function here is pure, which is why they are in a lib
    at all: the gh call, the fetch and the ff-only merge stay in ship-pr.ps1, and this suite asserts
    the judgements those calls hang on.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\forward-lane-lib.ps1'
$ShipPath = Join-Path $RepoRoot 'scripts\release\ship-pr.ps1'

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

Assert-True (Test-Path -LiteralPath $LibPath) 'forward-lane-lib.ps1 exists at its registered source path'
. $LibPath

Write-Host ''
Write-Host 'Get-UpdateBranchOutcome -- four outcomes, and only one of them is a failure' -ForegroundColor Cyan

$ok = Get-UpdateBranchOutcome -ExitCode 0 -OutputLines @('{"message":"Updating pull request branch.","url":"..."}')
Assert-Equal 'forwarded' $ok.Outcome 'exit 0 is a forward'
Assert-True ($ok.Message -match 'Updating pull request branch') '...and the raw answer comes back with it'

# THE CONFLICT IS TESTED FIRST, because GitHub's not-behind message and its conflict message can both
# mention the base branch and only one of them says 'conflict'.
$conflict = Get-UpdateBranchOutcome -ExitCode 1 -OutputLines @(
    'gh: merge conflict between base and head: unable to update branch (HTTP 422)')
Assert-Equal 'conflict' $conflict.Outcome 'a 422 naming a merge conflict is a conflict'

$current = Get-UpdateBranchOutcome -ExitCode 1 -OutputLines @(
    'gh: This branch is already up to date with the base branch (HTTP 422)')
Assert-Equal 'already-current' $current.Outcome 'a 422 saying the branch is already up to date is not a failure'

Assert-Equal 'already-current' (Get-UpdateBranchOutcome -ExitCode 1 -OutputLines @('the head is not behind the base')).Outcome '...nor is "not behind"'
Assert-Equal 'already-current' (Get-UpdateBranchOutcome -ExitCode 1 -OutputLines @('there are no new commits on the base branch')).Outcome '...nor is "no new commits"'

# CASE IS NOT LOAD-BEARING: gh and the API have both changed the capitalisation of these sentences.
Assert-Equal 'conflict' (Get-UpdateBranchOutcome -ExitCode 1 -OutputLines @('MERGE CONFLICT')).Outcome 'the match ignores case'
Assert-Equal 'already-current' (Get-UpdateBranchOutcome -ExitCode 1 -OutputLines @('Already Up-To-Date')).Outcome '...on both spellings of the hyphenated form'

# ANYTHING ELSE FALLS THROUGH TO 'failed', WHICH REFUSES. That is the safe direction and it is why
# 'failed' is the fall-through rather than a sentinel nobody reaches: a wording change upstream lands
# here, prints what GitHub said, and leaves the operator where the gate already put them.
$auth = Get-UpdateBranchOutcome -ExitCode 1 -OutputLines @('gh: Resource not accessible by integration (HTTP 403)')
Assert-Equal 'failed' $auth.Outcome 'a permission error is a failure'
Assert-True ($auth.Message -match '403') '...and its text is preserved for the refusal to print'
Assert-Equal 'failed' (Get-UpdateBranchOutcome -ExitCode 1 -OutputLines @()).Outcome 'a non-zero exit with no output at all is a failure'
Assert-Equal 'failed' (Get-UpdateBranchOutcome -ExitCode 1 -OutputLines $null).Outcome '...and so is a null output array'

# A CONFLICT MENTIONED ON A SUCCESSFUL CALL IS STILL A FORWARD. The exit code decides success; the text
# only separates the failures from each other.
Assert-Equal 'forwarded' (Get-UpdateBranchOutcome -ExitCode 0 -OutputLines @('no merge conflict found')).Outcome 'exit 0 is a forward whatever the text says'

Write-Host ''
Write-Host 'Get-LocalRefForwardPlan -- which command restores step 4 invariant' -ForegroundColor Cyan

# THE ORDINARY CASE IS HEAD ON THE TRUNK, because step 2b hands the primary checkout back as soon as
# the PR exists (#1073). git will not update a checked-out branch through a fetch refspec, and cannot
# merge into one that is not checked out, so the two arms are not interchangeable.
Assert-Equal 'fetch-refspec' (Get-LocalRefForwardPlan -Head 'main' -Branch 'fix/x') 'HEAD on the trunk takes the refspec route'
Assert-Equal 'merge-ff-only' (Get-LocalRefForwardPlan -Head 'fix/x' -Branch 'fix/x') 'HEAD on the shipping branch takes the merge route'
Assert-Equal 'fetch-refspec' (Get-LocalRefForwardPlan -Head 'feat/other' -Branch 'fix/x') 'HEAD on some third branch takes the refspec route'

# AN EMPTY OR UNREADABLE HEAD TAKES THE REFSPEC ROUTE, which touches no working tree -- so being wrong
# about it costs a refused fetch and a clear message, rather than a merge in a tree nobody established.
Assert-Equal 'fetch-refspec' (Get-LocalRefForwardPlan -Head '' -Branch 'fix/x') 'an unreadable HEAD takes the route that touches no tree'
Assert-Equal 'fetch-refspec' (Get-LocalRefForwardPlan -Head 'HEAD' -Branch 'fix/x') 'a detached HEAD does too'

# NAME EQUALITY IS EXACT: a branch whose name merely contains the other is a different branch.
Assert-Equal 'fetch-refspec' (Get-LocalRefForwardPlan -Head 'fix/x-v2' -Branch 'fix/x') 'a longer name is not the same branch'

Write-Host ''
Write-Host 'Get-ForwardLapDecision -- three ways to refuse, and each says which one it is' -ForegroundColor Cyan

$first = Get-ForwardLapDecision -LapsUsed 0 -MaxLaps 2
Assert-Equal $true $first.Forward 'the first stale reading with laps available forwards'
Assert-Equal '' $first.Note '...and has nothing to add to a refusal it is not making'

Assert-Equal $true (Get-ForwardLapDecision -LapsUsed 1 -MaxLaps 2).Forward 'the second one does too'

$spent = Get-ForwardLapDecision -LapsUsed 2 -MaxLaps 2
Assert-Equal $false $spent.Forward 'the budget being spent refuses'
Assert-True ($spent.Note -match 'already spent its 2 forward laps') '...naming the laps it spent'
Assert-True ($spent.Note -match 'MaxForwardLaps') '...and the way to raise them'

# THE ZERO CASE IS A SEPARATE SENTENCE BECAUSE IT IS A SEPARATE SITUATION. An operator who set
# -MaxForwardLaps 0 is owed a refusal saying so, not one implying the laps ran out.
$zero = Get-ForwardLapDecision -LapsUsed 0 -MaxLaps 0
Assert-Equal $false $zero.Forward '-MaxForwardLaps 0 refuses on the first stale reading'
Assert-True ($zero.Note -match 'No forward lap was attempted') '...and says no lap was attempted'
Assert-True ($zero.Note -notmatch 'already spent') '...rather than implying a budget ran out'

# SINGULAR AND PLURAL, because a refusal that says "its 1 forward laps" reads as a bug in the gate and
# invites the reader to distrust the number beside it.
Assert-True ((Get-ForwardLapDecision -LapsUsed 1 -MaxLaps 1).Note -match 'its 1 forward lap\b') 'one lap is reported in the singular'

# 'already-current' STOPS THE LAPPING WHATEVER THE BUDGET SAYS. GitHub reports nothing to bring across,
# so a further lap would wait on a run that never starts -- the budget would go in one poll timeout.
$nothingToDo = Get-ForwardLapDecision -LapsUsed 0 -MaxLaps 5 -Situation 'already-current'
Assert-Equal $false $nothingToDo.Forward 'a branch that is not behind its base does not lap again'
Assert-True ($nothingToDo.Note -match 'not behind its base') '...and the note says why'
Assert-True ($nothingToDo.Note -match 'race') '...and names the race, so the reader does not read it as a broken branch'

Write-Host ''
Write-Host 'Test-CertificateRenewed -- the old, green, completed run must not satisfy the wait' -ForegroundColor Cyan

Assert-Equal $false (Test-CertificateRenewed -Before @('111') -After @('111')) 'the same run is not a renewal'
Assert-Equal $true (Test-CertificateRenewed -Before @('111') -After @('222')) 'a different run is'
Assert-Equal $true (Test-CertificateRenewed -Before @('111') -After @('111', '222')) 'a new run beside the old one is'
Assert-Equal $false (Test-CertificateRenewed -Before @('111', '222') -After @('222')) 'a SUBSET of the old set is not -- nothing new has appeared'

# AN EMPTY CURRENT SET IS NOT A RENEWAL, and this is the case the poll depends on: it is the window
# where GitHub has torn the old run down and not yet created the new one, which is exactly when the
# caller must keep waiting rather than conclude anything.
Assert-Equal $false (Test-CertificateRenewed -Before @('111') -After @()) 'no run at all is not a renewal'
Assert-Equal $false (Test-CertificateRenewed -Before @('111') -After $null) '...nor is a null answer'
Assert-Equal $false (Test-CertificateRenewed -Before @('111') -After @('', '   ')) '...nor are blank entries'

# NO PRIOR SET MEANS ANY RUN IS NEW. The caller only reaches this with a before-set it read for the
# verdict, so this is the defensive arm -- but answering $false would wait forever on a comparison that
# can never change.
Assert-Equal $true (Test-CertificateRenewed -Before @() -After @('111')) 'with no prior run, any run is new'
Assert-Equal $false (Test-CertificateRenewed -Before @() -After @()) '...but nothing is still nothing'

# WHITESPACE IS NOT AN IDENTITY DIFFERENCE. The ids come out of a JSON payload through a link parse, so
# a stray space must not read as a fresh certificate.
Assert-Equal $false (Test-CertificateRenewed -Before @('111') -After @(' 111 ')) 'a padded id is the same id'

Write-Host ''
Write-Host 'The structural half -- ship-pr.ps1 laps on these decisions' -ForegroundColor Cyan

$ship = Get-Content -LiteralPath $ShipPath -Raw

Assert-True ($ship -match 'lib\\forward-lane-lib\.ps1') 'ship-pr.ps1 dot-sources forward-lane-lib.ps1'
Assert-True ($ship -match '\[int\]\$MaxForwardLaps = 2') 'the lap budget is a parameter defaulting to 2'
Assert-True ($ship -match 'ValidateRange\(0, 10\)') '...bounded, so a typo cannot ask for an unbounded loop'
Assert-True ($ship -match '(?s)\.PARAMETER MaxForwardLaps.*0 RESTORES THE OLD BEHAVIOUR') '...and documented, including what 0 means'

# THE MEASUREMENT IS INSIDE THE LOOP. Every input to it goes stale with the certificate -- the run ids
# come off a payload the forward replaces, the anchor is that run's own created_at, and the trunk has
# moved since -- so a reading that reused any of them would be measuring the previous lap.
Assert-True ($ship -match '(?s)\$forwardLapsUsed = 0.*?while \(\$true\) \{.*?Get-RequiredCheckRunIds') 'the whole staleness measurement sits inside the lap loop'
Assert-True ($ship -match 'Get-ForwardLapDecision -LapsUsed \$forwardLapsUsed -MaxLaps \$MaxForwardLaps') 'the lap decision is taken from the lib, not inline'
Assert-True ($ship -match "pulls/\`$pr/update-branch") 'the forward is GitHub-side update-branch, not a local checkout-and-merge'
Assert-True ($ship -match 'Get-UpdateBranchOutcome -ExitCode') '...and its answer is classified by the lib'
Assert-True ($ship -match 'Wait-ForwardedCertificate -Pr') 'the run waits for a NEW certifying run before measuring again'
Assert-True ($ship -match 'Get-LocalRefForwardPlan -Head \$headAtForward -Branch \$branch') 'the local ref is brought up to the forwarded head'

# THE REFUSAL #1292 ALWAYS PRINTED IS STILL THERE, with the lap note appended rather than woven in. The
# whole point of this change is that the PREDICATE is untouched; a suite that let the refusal be
# rewritten would be guarding the wrong half.
Assert-True ($ship -match "stale-CI certificate: 'main' gained ") "the #1292 refusal wording survives"
Assert-True ($ship -match '(?s)bringing the branch forward, not retrying the same read\..*\$\(\$lap\.Note\)') '...with the lap note appended to it'

# A RED CHECK ON THE FORWARDED HEAD ENDS THE RUN. This is the case the gate exists to catch, arriving
# the way it was always meant to -- lapping there would re-run a suite that has just answered.
Assert-True ($ship -match 'The required check went RED on the forwarded head') 'a red check after the forward refuses rather than lapping'

# AND SO DOES A FAILED CATCH-UP OF THE LOCAL REF. Merging while refs/heads/<branch> and the PR head
# disagree would gate the merge on a document the PR does not contain, which nothing downstream reports.
Assert-True ($ship -match "could not be fast-forwarded") 'a local ref that will not fast-forward refuses'

Write-Host ''
Write-Host 'The lib is ASCII and mirrored' -ForegroundColor Cyan

$raw = Get-Content -LiteralPath $LibPath -Raw
Assert-True (-not ($raw -cmatch '[^\x00-\x7F]')) 'forward-lane-lib.ps1 is pure ASCII'

# Mirrored, so a consumer meets the same shape this repo does. shared-scripts.tests.ps1 owns the
# byte-identity assert; this one is only that the registration exists at all.
Assert-True ((Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1') -Raw) -match 'forward-lane-lib') 'forward-lane-lib is registered as a shared script'
Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy\scripts\lib\forward-lane-lib.ps1')) '...and its plugin mirror is present'

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
