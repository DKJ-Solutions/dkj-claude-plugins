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

# UNATTENDED, THE MERGE ROUTE IS REFUSED -- issue #2343. It would write the live remote head, whatever was
# pushed during the wait, into the tree the merge-on-green runner runs scripts from with FOLD_PUSH_TOKEN.
Assert-Equal 'refuse' (Get-LocalRefForwardPlan -Head 'fix/x' -Branch 'fix/x' -Unattended) 'unattended on the shipping branch, the merge route is refused'
Assert-Equal 'fetch-refspec' (Get-LocalRefForwardPlan -Head 'main' -Branch 'fix/x' -Unattended) '...while on the trunk the ref-only route stays open'
Assert-Equal 'fetch-refspec' (Get-LocalRefForwardPlan -Head '' -Branch 'fix/x' -Unattended) '...and an unreadable HEAD still takes the route that touches no tree'

Write-Host ''
Write-Host 'Get-UnattendedTrunkReturnRefusal -- an unattended ship stops off the trunk (#2343)' -ForegroundColor Cyan

Assert-Equal '' (Get-UnattendedTrunkReturnRefusal -TreeOnTrunk $true -Unattended $true) 'unattended and back on the trunk: it goes on'
Assert-Equal '' (Get-UnattendedTrunkReturnRefusal -TreeOnTrunk $false -Unattended $false) 'attended and still on the branch: it goes on, as it always has'
$offTrunk = Get-UnattendedTrunkReturnRefusal -TreeOnTrunk $false -Unattended $true
Assert-True ([bool]$offTrunk) 'unattended and still on the branch: it stops'
Assert-True ($offTrunk -match 'before the CI wait' -and $offTrunk -match '#2343') '...and says where, and why'

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
Write-Host 'Get-CancelledCheckRunIds -- a cancelled duplicate run is not the certificate (#3331)' -ForegroundColor Cyan

$link = { param($id) "https://github.com/o/r/actions/runs/$id/job/9" }
$cancelledPayload = @(
    [pscustomobject]@{ name = 'lint-en-tests'; bucket = 'cancel'; state = 'CANCELLED'; link = (& $link '39937451203') },
    [pscustomobject]@{ name = 'claude-review'; bucket = 'cancel'; state = 'CANCELLED'; link = (& $link '555') }
) | ConvertTo-Json
Assert-Equal '39937451203' ((Get-CancelledCheckRunIds -ChecksJson $cancelledPayload -Names @('lint-en-tests')) -join ',') 'the measured case: a cancelled required run is returned'
Assert-Equal '' ((Get-CancelledCheckRunIds -ChecksJson $cancelledPayload -Names @('other')) -join ',') '...and a cancelled check that is not named is not'

# A FAILURE IS AN ANSWER, and it must still reach the caller as RED -- the half of the gate this repair
# must not soften.
$failedPayload = ConvertTo-Json -InputObject @([pscustomobject]@{ name = 'lint-en-tests'; bucket = 'fail'; state = 'FAILURE'; link = (& $link '777') })
Assert-Equal '' ((Get-CancelledCheckRunIds -ChecksJson $failedPayload -Names @('lint-en-tests')) -join ',') 'a failed run is not read as cancelled'
$passPayload = ConvertTo-Json -InputObject @([pscustomobject]@{ name = 'lint-en-tests'; bucket = 'pass'; state = 'SUCCESS'; link = (& $link '888') })
Assert-Equal '' ((Get-CancelledCheckRunIds -ChecksJson $passPayload -Names @('lint-en-tests')) -join ',') '...nor is a green one'

# BUCKET FIRST, STATE AS THE FALLBACK -- Get-CheckOutcome's order.
$stateOnly = ConvertTo-Json -InputObject @([pscustomobject]@{ name = 'lint-en-tests'; state = 'CANCELLED'; link = (& $link '999') })
Assert-Equal '999' ((Get-CancelledCheckRunIds -ChecksJson $stateOnly -Names @('lint-en-tests')) -join ',') 'state CANCELLED is read when no bucket was asked for'
$noLink = ConvertTo-Json -InputObject @([pscustomobject]@{ name = 'lint-en-tests'; bucket = 'cancel'; link = 'https://ci.example/x' })
Assert-Equal '' ((Get-CancelledCheckRunIds -ChecksJson $noLink -Names @('lint-en-tests')) -join ',') 'a link naming no Actions run yields no id'
Assert-Equal '' ((Get-CancelledCheckRunIds -ChecksJson 'not json' -Names @('lint-en-tests')) -join ',') 'an unparseable payload yields nothing rather than throwing'
Assert-Equal '' ((Get-CancelledCheckRunIds -ChecksJson '' -Names @('lint-en-tests')) -join ',') '...and so does an empty one'

Write-Host ''
Write-Host 'Get-UnfinishedRequiredCount -- a required aggregator that has not registered is unfinished' -ForegroundColor Cyan

# THE CASE THE FUNCTION EXISTS FOR. `lint-en-tests` has no record until the jobs it needs are done, and
# the `--required` payload says nothing about it -- so counting from that payload would end step 3a three
# minutes into an eight-minute CI. Counted against the ruleset's names, an absent record is unfinished.
$midRun = '[{"name":"lint","bucket":"pending"},{"name":"suites (1)","bucket":"pending"},{"name":"branch-entry","bucket":"pass"}]'
Assert-Equal 1 (Get-UnfinishedRequiredCount -ChecksJson $midRun -RequiredNames @('lint-en-tests')) 'a required check with no record yet counts as unfinished'
Assert-Equal 1 (Get-UnfinishedRequiredCount -ChecksJson '[{"name":"lint-en-tests","bucket":"pending"}]' -RequiredNames @('lint-en-tests')) 'a pending one does too'
Assert-Equal 0 (Get-UnfinishedRequiredCount -ChecksJson '[{"name":"lint-en-tests","bucket":"pass"}]' -RequiredNames @('lint-en-tests')) 'a passed one does not'
# FAIL AND CANCEL ARE CONCLUDED. Step 3a hands over on them; the watch and its verdict say what they mean.
Assert-Equal 0 (Get-UnfinishedRequiredCount -ChecksJson '[{"name":"lint-en-tests","bucket":"fail"}]' -RequiredNames @('lint-en-tests')) 'a failed one is concluded, not unfinished'
Assert-Equal 0 (Get-UnfinishedRequiredCount -ChecksJson '[{"name":"lint-en-tests","bucket":"cancel"}]' -RequiredNames @('lint-en-tests')) '...and so is a cancelled one'
Assert-Equal 2 (Get-UnfinishedRequiredCount -ChecksJson '[{"name":"a","bucket":"pass"}]' -RequiredNames @('a', 'b', 'c', 'c')) 'each required name is counted once'
# SEVERAL RECORDS, the shape every real payload has -- and the one Windows PowerShell 5.1 collapses into a
# single object when ConvertFrom-Json is wrapped inline, so every name read as all of them joined and this
# never reached 0 (Victor, on the branch that added it). Every single-record case above passes either way.
Assert-Equal 0 (Get-UnfinishedRequiredCount -ChecksJson '[{"name":"a","bucket":"pass"},{"name":"b","bucket":"fail"}]' -RequiredNames @('a', 'b')) 'several concluded records read as concluded'
Assert-Equal 2 (Get-UnfinishedRequiredCount -ChecksJson '[{"name":"a","bucket":"pass"},{"name":"b","bucket":"pending"}]' -RequiredNames @('a', 'b', 'c')) '...and a pending one among them still counts, with the absent one'
Assert-Equal -1 (Get-UnfinishedRequiredCount -ChecksJson '' -RequiredNames @('lint-en-tests')) 'an empty payload is unreadable, not "nothing unfinished"'
Assert-Equal -1 (Get-UnfinishedRequiredCount -ChecksJson 'not json' -RequiredNames @('lint-en-tests')) '...and so is one that does not parse'

Write-Host ''
Write-Host 'Get-EarlyForwardAction -- every answer but poll and forward hands over to the watch' -ForegroundColor Cyan

$stale = [pscustomobject]@{ Stale = $true; Count = 1 }
$fresh = [pscustomobject]@{ Stale = $false; Count = 0 }
Assert-Equal 'forward' (Get-EarlyForwardAction -ChecksReadable $true -UnfinishedRequired 1 -StaleVerdict $stale -LapsUsed 0 -MaxLaps 2) 'a stale reading mid-run with budget left forwards now'
Assert-Equal 'poll' (Get-EarlyForwardAction -ChecksReadable $true -UnfinishedRequired 1 -StaleVerdict $fresh -LapsUsed 0 -MaxLaps 2) 'a sound reading keeps polling'
# NO READING IS NOT A SOUND READING, BUT IT IS NOT A STALE ONE EITHER: this phase only shortcuts the
# remedy, so it waits for a reading rather than forwarding on a guess.
Assert-Equal 'poll' (Get-EarlyForwardAction -ChecksReadable $true -UnfinishedRequired 1 -StaleVerdict $null -LapsUsed 0 -MaxLaps 2) 'no reading this poll keeps polling'
Assert-Equal 'watch' (Get-EarlyForwardAction -ChecksReadable $true -UnfinishedRequired 0 -StaleVerdict $stale -LapsUsed 0 -MaxLaps 2) 'a finished certificate is step 3b''s to read, stale or not'
Assert-Equal 'watch' (Get-EarlyForwardAction -ChecksReadable $false -UnfinishedRequired 1 -StaleVerdict $stale -LapsUsed 0 -MaxLaps 2) 'an unreadable payload hands over rather than refusing'
# THE BUDGET IS SHARED, so a spent one hands over and step 3b prints #2087's note -- no second sentence here.
Assert-Equal 'watch' (Get-EarlyForwardAction -ChecksReadable $true -UnfinishedRequired 1 -StaleVerdict $stale -LapsUsed 2 -MaxLaps 2) 'a spent lap budget hands over'
Assert-Equal 'watch' (Get-EarlyForwardAction -ChecksReadable $true -UnfinishedRequired 1 -StaleVerdict $stale -LapsUsed 0 -MaxLaps 0) '...and so does -MaxForwardLaps 0'

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
Assert-True ($ship -match 'Get-LocalRefForwardPlan -Head \$headAtForward -Branch \$Branch -Unattended:\$Unattended') '...passing whether the run is unattended (#2343)'
Assert-Equal 2 ([regex]::Matches($ship, 'Sync-ForwardedBranchRef -Branch \$branch -BranchShown \$branchShown -Unattended \$unattendedShip').Count) '...which both callers of Sync-ForwardedBranchRef hand in'
Assert-True ($ship -match "if \(\`$forwardPlan -eq 'refuse'\) \{") '...and a refused plan ends the run rather than falling through to a fetch'
# THE STOP SITS BETWEEN STEP 2B AND THE CI WAIT, reading what step 2b actually did.
Assert-True ($ship -match "\`$unattendedShip = \(\`$env:GITHUB_ACTIONS -eq 'true'\)") 'unattended means running inside GitHub Actions'
$stopAt = $ship.IndexOf('Get-UnattendedTrunkReturnRefusal -TreeOnTrunk $treeOnTrunk')
$backAt = $ship.IndexOf("@('checkout', 'main')")
$waitAt = $ship.IndexOf('waiting for the CI check(s) on PR')
Assert-True ($stopAt -gt $backAt -and $backAt -ge 0) 'the unattended stop reads step 2b''s outcome, after the checkout attempt'
Assert-True ($stopAt -ge 0 -and $stopAt -lt $waitAt) '...and comes before the CI wait'

# STEP 3A: THE EARLY FORWARD. Its place is the whole fix -- after the wait on the required check it would
# start with CI already over (an aggregator registers last) -- and its budget is step 3b's.
$firstWaitAt = $ship.IndexOf('-PollSeconds $PollSeconds -MaxWaitSec $maxWaitSec')
$earlyAt = $ship.IndexOf('Get-EarlyForwardAction -ChecksReadable')
$requiredWaitAt = $ship.IndexOf('-PollSeconds $PollSeconds -MaxWaitSec $maxRequiredWaitSec -AlreadyWaited $waited')
$step3bAt = $ship.IndexOf('# --- Step 3b:')
Assert-True ($firstWaitAt -ge 0 -and $earlyAt -gt $firstWaitAt) 'step 3a runs after the first check has registered'
Assert-True ($requiredWaitAt -gt $earlyAt) '...and BEFORE the wait on the required check, which ends only when CI is nearly over'
Assert-True ($ship -match 'Get-UnfinishedRequiredCount -ChecksJson \$earlyFacts\.Checks -RequiredNames \$requiredWaitNames') '...counting unfinished from the ruleset names, not the --required payload'
Assert-True ($ship -match "if \(-not \`$SkipStaleCheck -and \`$MaxForwardLaps -gt 0 -and \`$requiredWaitNames\.Count -gt 0\)") '...and only where step 3b would read a certificate at all'
$lapsInitAt = $ship.IndexOf('$forwardLapsUsed = 0')
Assert-True ($lapsInitAt -ge 0 -and $lapsInitAt -lt $earlyAt) 'the lap counter is set before step 3a'
Assert-Equal 1 ([regex]::Matches($ship, '(?m)^\s*\$forwardLapsUsed = 0').Count) '...exactly once, so step 3b does not reset a lap 3a spent'
Assert-True ($ship -match '(?s)Get-EarlyForwardAction -ChecksReadable.*?\$forwardLapsUsed\+\+.*?Complete-ForwardLap.*?Sync-ForwardedBranchRef') 'an early forward spends a lap and completes it the way step 3b does'
# STEP 3B KEEPS ITS ORDER: wait, red verdict, then the ref -- so a red run is reported as red.
$redAt = $ship.IndexOf('The required check went RED on the forwarded head')
$syncIn3bAt = $ship.IndexOf('Sync-ForwardedBranchRef -Branch', $step3bAt)
Assert-True ($redAt -gt $step3bAt -and $syncIn3bAt -gt $redAt) 'step 3b reads the red verdict before the local ref catches up'
# BOUNDED: an absent record counts as unfinished, so a name that never registers must not poll forever.
Assert-True ($ship -match '(?s)\$earlyBegan = Get-Date.*?TotalSeconds -ge \$earlyMaxSec\) \{ break \}') 'step 3a hands over to the waits after a bound'
Assert-True ($ship -match '\$earlyUnfinished -lt 0 -and \$earlyBlips -lt \$earlyMaxBlips') '...and retries an unreadable payload before handing over'
Assert-Equal 2 ([regex]::Matches($ship, 'Complete-ForwardLap -Pr').Count) 'Complete-ForwardLap is the one way a forward finishes, from 3a and from 3b'
Assert-True ($ship.IndexOf('Get-FoldExemptCommits -Commits $newMainCommits') -gt $step3bAt) 'step 3b discounts folds through Get-FoldExemptCommits'
Assert-True ($ship -match 'Get-StaleCertificateVerdict -NewMainCommits \$gained -ExemptCommits @\(Get-FoldExemptCommits -Commits \$gained\)') '...and so does the early reading, so the two cannot disagree'

# THE REFUSAL #1292 ALWAYS PRINTED IS STILL THERE, with the lap note appended rather than woven in. The
# whole point of this change is that the PREDICATE is untouched; a suite that let the refusal be
# rewritten would be guarding the wrong half.
Assert-True ($ship -match "stale-CI certificate: 'main' gained ") "the #1292 refusal wording survives"
Assert-True ($ship -match '(?s)bringing the branch forward, not retrying the same read\..*\$\(\$lap\.Note\)') '...with the lap note appended to it'

# A RED CHECK ON THE FORWARDED HEAD ENDS THE RUN. This is the case the gate exists to catch, arriving
# the way it was always meant to -- lapping there would re-run a suite that has just answered.
Assert-True ($ship -match 'The required check went RED on the forwarded head') 'a red check after the forward refuses rather than lapping'
# ...but a CANCELLED one is not red: the forward wait skips it and waits for the run that superseded it.
Assert-True ($ship -match '(?s)function Wait-ForwardedCertificate.*?Get-CancelledCheckRunIds -ChecksJson \$facts\.Checks.*?if \(\$cancelledIds\.Count -eq 0\) \{ return \$facts \}') 'the forward wait returns only once no required record reads cancelled (#3331)'

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
