<#
.SYNOPSIS
    Regression tests for the merge queue on 'main': the two prerequisites that had to be true before it
    could be switched on (issue #1325), the enqueue path ship-pr takes now that it is (issue #1506), and
    the half of that arrangement a CONSUMER receives once the queue became a policy rather than a
    setting on one trunk (issue #1516).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Reads the workflow and the script as text and
    runs a series of asserts. Exit code 0 if everything passes, 1 on a failure -- so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/merge-queue-prereq.tests.ps1

    WHY THIS SUITE EXISTS. A GitHub merge queue is the only remedy for the staleness race that actually
    converges (#1292 measured the race; #1325 measured every non-queue repo-settings remedy and rejected
    them -- `strict_required_status_checks_policy` + `allow_auto_merge` + `allow_update_branch` were all
    turned on and reverted the same day, because GitHub performs NO server-side base-sync of a PR branch
    outside a queue). Enabling one is a repo-settings change and Dave's. What is NOT his, and what this
    suite guards, is the two things that must already be true in the tree before that switch is flipped.

    THE ANSWER WAS NO ON SEPTEMBER 3, 2026 (#1355) AND YES ON SEPTEMBER 6 (#1492) -- THE QUEUE IS LIVE.
    That "no" was priced against a 12.3%/~5min problem and was never a never; the reopen condition in
    Sylvester's lens is what it was reopened on. So the two guards below have stopped being insurance
    against a switch nobody had flipped and are now load-bearing on every merge this repo makes: guard 1
    is the difference between a queue entry being certified and a TOTAL MERGE OUTAGE, and guard 2 is what
    kept an ordinary ship from folding a PR the queue had not landed yet. Do not remove either as unused.

    AND THE THIRD SECTION IS WHAT THAT "YES" COST. Guard 2 made a non-MERGED state a REFUSAL, which is
    right with no queue and wrong with one -- the enqueue IS the outcome now. #1506 narrowed it to the
    case that has no explanation and gave the explained case an arm of its own, which is what the
    "#1506" sections pin: ship-pr ends successfully at step 4 with the PR enqueued, folds nothing, and
    fold-on-merge.yml folds off the queue's own push to the trunk (#1493). The fourth section is that
    workflow's push credential, which belongs here because a fold that commits and cannot push is the
    same merged-but-unfolded state the guards exist to prevent, reached by a third route.

    AND THE FIFTH IS WHAT TRAVELS. #1516 made the queue this workflow's policy for every repo running
    it, and a queue reaches a consumer as a policy rather than as a release: the setting is theirs to
    flip, the two runners are not plugin payload, and a plugin install writes nothing into a repo. So
    exactly three things about a consumer are this repo's to guarantee, and that section is those three
    -- ship-pr not promising a fold runner it cannot see, and both scripts a consumer's own runners call
    being registered mirrors rather than files only this tree has. The adoption command itself is
    covered by adopt-ci-floor.tests.ps1.

    BOTH FAIL SILENTLY AND BOTH FAIL BADLY, which is why they are pinned rather than commented:

      1. `.github/workflows/ci.yml` must carry the `merge_group` trigger. A required workflow without it
         never runs for a queue entry, so `lint-en-tests` never reports -- and GitHub's own warning is
         that the merge then fails. That is a TOTAL MERGE OUTAGE on the trunk, not a degradation. The
         trigger is inert until a queue exists, so nothing about the repo today would notice it being
         removed; the notice would arrive as the first merge after a queue is switched on.

      2. `scripts/release/ship-pr.ps1` must read the PR's state after `gh pr merge` rather than trusting
         its exit code. `gh pr merge --help`: "When targeting a branch that requires a merge queue ... If
         required checks have passed, the pull request will be added to the merge queue." ADDED, exit 0,
         not merged. Step 5 folds the entry onto the trunk on the strength of that exit code, so under a
         queue an ordinary ship would write a fold commit for a PR that has not landed -- the changelog
         entry on the trunk ahead of its own merge, with nothing in the run saying so.

    THE SECOND ONE IS ALSO RIGHT TODAY, with no queue anywhere: 'merged' had been an inference from an
    exit code, on the one script that writes to the trunk. That is why its assert does not wait for a
    queue to exist either.

    THE ASSERTS ARE ABOUT THE PROPERTY, NOT THE SPELLING, as far as text asserts allow: the trigger is
    matched as a top-level key of the `on:` block (not merely as the substring, which every comment on
    this page also contains), and the readback is matched by what it reads and by its refusal, not by the
    variable name it happens to use.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

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

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$ciPath = Join-Path $repoRoot '.github\workflows\ci.yml'
$shipPath = Join-Path $repoRoot 'scripts\release\ship-pr.ps1'
$shipMirror = Join-Path $repoRoot 'plugins\dkj-policy\scripts\release\ship-pr.ps1'

$ci = Get-Content -LiteralPath $ciPath -Raw
$ship = Get-Content -LiteralPath $shipPath -Raw

Write-Host "== prerequisite 1: ci.yml triggers on merge_group (#1325) ==" -ForegroundColor Cyan

# THE TRIGGER, matched as a key rather than as a word. Every paragraph of reasoning on that page names
# `merge_group` too, so a substring match would stay green with the trigger itself deleted -- which is
# exactly the silent state this assert exists to catch.
$onBlock = [regex]::Match($ci, '(?ms)^on:\r?\n(?<body>(?:[ \t]+\S[^\r\n]*\r?\n)+)')
Assert-True ($onBlock.Success) 'ci.yml still declares a top-level on: block'
Assert-True ($onBlock.Success -and $onBlock.Groups['body'].Value -match '(?m)^\s{2}merge_group:') `
    'ci.yml triggers on merge_group -- without it a required check never reports in a queue and merges fail outright'

# The two triggers that were there first must survive the addition: a queue does not replace either.
Assert-True ($onBlock.Success -and $onBlock.Groups['body'].Value -match '(?m)^\s{2}pull_request:') `
    'and the pull_request trigger is untouched -- the PR gate is what a queue entry is promoted from'
Assert-True ($onBlock.Success -and $onBlock.Groups['body'].Value -match '(?m)^\s{2}push:') `
    'and the push trigger is untouched -- the trunk tip still carries a check of its own'

# A queue entry must run the SUITES, not just lint: it is the projected merge being certified before it
# lands, so the #1300 fold-commit shortcut must not reach it. That shortcut is gated on the push event,
# which is what keeps merge_group out of it -- assert the gate rather than the absence of a mention.
$suiteStep = [regex]::Match($ci, '(?ms)- name: Test suites.*?shell: powershell')
Assert-True ($suiteStep.Success) 'the Test suites step is still in ci.yml'
Assert-True ($suiteStep.Success -and $suiteStep.Value -match "if:[^\r\n]*github\.event_name == 'push'") `
    'and its skip is gated on the push event, so a merge_group run still runs the suites in full'

# The reasoning has to travel with the trigger: an inert line with no cited issue is the first thing a
# later sweep removes as dead configuration.
Assert-True ($ci -like '*#1325*') 'ci.yml cites the issue that explains why an inert trigger is there at all'

Write-Host "== prerequisite 2: ship-pr reads the merge state before folding (#1325) ==" -ForegroundColor Cyan

# The readback itself. Matched on WHAT IT READS -- the PR's state field -- so renaming the variable or
# restructuring the retry keeps this green while deleting the read does not.
Assert-True ($ship -match "'pr',\s*'view'[^\r\n]*'state'") `
    'ship-pr reads the PR state from gh after the merge'
Assert-True ($ship -match "(?m)^\s*\}\s*elseif\s*\(\s*\`$mergedState -ne 'MERGED'\s*\)") `
    'and refuses when that state is positively read as something other than MERGED'

# THE ORDER IS THE WHOLE POINT. The read has to sit between the merge and the fold; a read placed after
# step 5 would pass a substring assert and prevent nothing.
$mergeIdx = $ship.IndexOf("'pr', 'merge'")
$stateIdx = [regex]::Match($ship, "'pr',\s*'view'[^\r\n]*'state'").Index
$foldIdx = $ship.IndexOf('--- Step 5:')
Assert-True ($mergeIdx -gt 0 -and $stateIdx -gt $mergeIdx) 'the state read comes after the gh pr merge call'
Assert-True ($foldIdx -gt 0 -and $stateIdx -lt $foldIdx) 'and before step 5, which is the step that folds onto the trunk'

# A FAILED READ IS NOT A FINDING, deliberately: turning a network blip into a refusal between the merge
# and the fold would manufacture the trapped-entry state (#1270) that the fold exists to prevent. This
# assert is the one that stops a later "tighten the gate" sweep from inverting it.
Assert-True ($ship -match 'not checked \(this is not a finding\)[^\r\n]*"\s*-ForegroundColor DarkGray') `
    'an unreadable state does NOT refuse -- only a state read as non-MERGED does'

Write-Host "== the queue is now the intended path, not a refusal (#1506) ==" -ForegroundColor Cyan

# THE SHIFT THIS SUITE HAS TO RECORD. Guard 2 above was built when a queue did not exist here: it made
# `gh pr merge` returning 0 on an unmerged PR a REFUSAL, so a queue could not be switched on without
# every ship stopping at step 4. With the queue live on main-ci-gate (#1492), the enqueue is the normal
# outcome and the refusal belongs only to the case that has no explanation. Both asserts below are
# about that narrowing, and both would go green again if somebody widened the refusal back.
$queueRead = [regex]::Match($ship, 'Get-MergeQueueVerdict -BranchRulesJson')
Assert-True ($queueRead.Success) 'ship-pr asks whether the trunk is behind a merge queue (#1506)'

# READ OFF THE PAYLOAD STEP 0b ALREADY FETCHED, which is what makes it free. An implementation that
# made its own gh call would pass the assert above and cost a network round trip on every ship.
Assert-True ($ship -match '(?s)rules/branches/main.*Get-MergeQueueVerdict') `
    'and reads it off the trunk-rules payload step 0b already fetched, rather than making a second call'

# BEFORE THE MERGE, because both consequences are decisions made before `gh pr merge` runs: whether to
# refuse on this account's fold-push entitlement, and how to read the state afterwards.
$idxQueue = $ship.IndexOf('Get-MergeQueueVerdict -BranchRulesJson')
$idxMerge = $ship.IndexOf("'pr', 'merge'")
$idxStep5 = $ship.IndexOf('--- Step 5:')
Assert-True ($idxQueue -gt 0 -and $idxMerge -gt $idxQueue) 'and asks BEFORE the merge, which is what the answer decides'

# THE ENQUEUE ARM ITSELF: it ends the run, and it ends it SUCCESSFULLY. `exit 0` is the whole assert --
# an arm that fell through would fold a PR that has not landed, which is the #1325 state this file's
# guard 2 exists to prevent, and an arm that exited non-zero would make every ordinary ship red.
# TAKEN FROM AFTER THE MERGE, NOT FROM THE TOP OF THE FILE. $queueActive is read TWICE by design -- once
# at step 0b, where it skips the fold-push refusal, and once here, where it ends the run -- so a match
# anchored at the top of the script finds the step-0b arm and asserts the wrong block. Slicing at the
# merge call is what names WHICH arm this section is about, without tying the assert to a variable name.
$enqueueArm = [regex]::Match($ship.Substring($idxMerge), '(?s)if \(\$queueActive\) \{.*?\r?\n\}')
Assert-True ($enqueueArm.Success) 'ship-pr has an arm for the queue being active'
Assert-True ($enqueueArm.Success -and $enqueueArm.Value -match '(?m)^\s*exit 0\s*$') `
    'and it ENDS THE RUN SUCCESSFULLY -- enqueued is a shipped branch, not a failure'
Assert-True ($idxStep5 -gt 0 -and $ship.IndexOf('if ($queueActive) {', $idxMerge) -lt $idxStep5) `
    'and that arm sits between the merge and step 5, so nothing folds a PR the queue has not landed'

# NOT FOLDING IS THE POINT, so the arm has to say who does. Without this the operator is left with a
# green run, an unfolded entry on the trunk and no idea that either is expected.
Assert-True ($enqueueArm.Success -and $enqueueArm.Value -like '*fold-on-merge*') `
    'and it names fold-on-merge.yml as what folds instead (#1493)'
Assert-True ($enqueueArm.Success -and $enqueueArm.Value -like '*verify-resolved-issues*') `
    'and names step 6, the one thing that has no other home, rather than dropping it silently'

# UNREADABLE IS NOT "NO QUEUE" -- the property the whole narrowing rests on. $queueActive must require
# BOTH fields; a `$queueVerdict.Active` alone would send a run down the direct-merge path on a trunk
# whose rules simply could not be read this time.
Assert-True ($ship -match '\$queueActive = \(\$queueVerdict\.Readable -and \$queueVerdict\.Active\)') `
    'the queue is only "active" when the payload was actually READ -- an unreadable one keeps the old behaviour'

# AND THE FOLD-PUSH REFUSAL (#1278) IS GATED ON IT. Under a queue a merge_queue rule blocks every direct
# push by definition, so an ungated step 0b would refuse EVERY ship on a push this run never makes.
Assert-True ($ship -match 'if \(-not \$queueActive -and \$foldVerdict\.Blocked\)') `
    'the #1278 fold-push refusal is skipped under a queue -- the fold is not this session s push to make'
Assert-True ($ship -match 'if \(-not \$queueActive -and \$foldVerdict\.Unknown\)') `
    'and so is its warning, for the same reason'

Write-Host "== fold-on-merge.yml can actually push what it folds (#1493) ==" -ForegroundColor Cyan

# WHY THIS SECTION SITS IN THIS SUITE. Handing the fold to CI is what makes the enqueue above safe: a
# fold that commits and cannot push is the same merged-but-unfolded state guard 2 exists to prevent,
# reached by a third route. The wiring itself landed in #1507 with no test of its own, which is what
# these asserts close -- every one of them is about a property that fails SILENTLY, in a workflow whose
# red runs already have three causes that look alike (#1499, #1539).
$foldWf = Join-Path $repoRoot '.github\workflows\fold-on-merge.yml'
Assert-True (Test-Path -LiteralPath $foldWf) 'fold-on-merge.yml is still where the fold runs from'
if (Test-Path -LiteralPath $foldWf) {
    $fom = Get-Content -LiteralPath $foldWf -Raw

    # THE CHECKOUT TOKEN IS THE PUSH CREDENTIAL. actions/checkout persists whatever it authenticated
    # with, and the fold's own `git push` reuses it -- so this line, and not the permissions block,
    # decides which actor GitHub judges against main-ci-gate. The default GITHUB_TOKEN pushes as the
    # GitHub Actions app, which is not on that bypass list and cannot be added to it. The `ref: main`
    # line between `with:` and `token:` is #1543's -- the checkout reads the trunk tip, not the event SHA.
    Assert-True ($fom -match '(?s)uses: actions/checkout@[^\r\n]*\r?\n\s*with:\s*\r?\n(\s*ref: main\r?\n)?\s*token: \$\{\{ secrets\.FOLD_PUSH_TOKEN \}\}') `
        'checkout authenticates with FOLD_PUSH_TOKEN, which is what the fold s push then reuses'

    # AND IT IS PINNED TO A COMMIT SHA, which is this file's own stated reasoning rather than a general
    # policy: a mutable tag on a step that handles a 366-day standing write token can be retagged into
    # exfiltrating it. The assert is the SHA, not the version comment beside it.
    Assert-True ($fom -match 'uses: actions/checkout@[0-9a-f]{40}') `
        'and that checkout is pinned to a commit SHA -- a mutable tag here handles a standing write token'

    # THE READ PATH DELIBERATELY DOES NOT GET THE PAT. The fold script's own `gh pr list` runs on the
    # job-scoped GITHUB_TOKEN, which expires in about an hour and is useless outside this run. Handing
    # it the standing token instead would widen the blast radius for nothing -- the push is the only
    # thing that needs bypass, and it takes its credential from checkout above, not from here.
    Assert-True ($fom -match 'GH_TOKEN: \$\{\{ secrets\.GITHUB_TOKEN \}\}') `
        'the fold step READS with the job-scoped GITHUB_TOKEN -- only the push needs the standing token'

    # AND THE DEFAULT TOKEN NO LONGER ASKS FOR WRITE. Once the PAT does the pushing, contents: write on
    # GITHUB_TOKEN grants a capability nothing in the job uses. A later "restore the permissions" sweep
    # reading this as an oversight is exactly what this assert stops.
    Assert-True ($fom -match '(?ms)^permissions:\r?\n\s+contents: read\r?\n') `
        'and the default GITHUB_TOKEN is down to contents: read, because it is no longer the pusher'

    # The reasoning has to travel with the wiring: without it the next reader tries the ruleset bypass
    # again and spends the round trip discovering it cannot be granted.
    Assert-True ($fom -match '(?i)cannot be added to it|cannot be a ruleset bypass actor') `
        'the header says the Actions app cannot be a bypass actor, so nobody retries that route'
}

Write-Host "== the policy travels: what a CONSUMER under a queue needs (#1516) ==" -ForegroundColor Cyan

# WHY THIS SECTION IS HERE AND NOT ONLY IN adopt-ci-floor.tests.ps1. That suite proves the adoption
# command works; these three asserts are about the half a consumer gets whether they run it or not, and
# each closes a route by which the queue policy silently does not travel. The queue is a repo setting
# per repo, so it reaches a consumer as a POLICY rather than as a release -- which means the only things
# this repo can actually guarantee are the ones below.

# 1. THE ENQUEUE ARM MUST NOT PROMISE A RUNNER THAT IS NOT THERE. In the source repo fold-on-merge.yml
#    exists, so a flat sentence naming it is true; in a consumer it is not plugin payload -- a plugin
#    install writes nothing into a repo -- and the sentence is then a lie told at the exact moment the
#    entry is being stranded. Matched on the FILE TEST rather than on the wording, so rephrasing the
#    message keeps this green and deleting the condition does not.
$idxMergeCall = $ship.IndexOf("'pr', 'merge'")
$tail = if ($idxMergeCall -gt 0) { $ship.Substring($idxMergeCall) } else { $ship }
Assert-True ($tail -match "Test-Path -LiteralPath \`$foldRunner") `
    'the enqueue arm TESTS for .github/workflows/fold-on-merge.yml before promising it folds anything'
Assert-True ($tail -match 'NOTHING HERE FOLDS THAT ENTRY') `
    'and where there is none it says so, instead of naming a workflow this repo does not have'
# THE TOKEN, NOT THE RAW REF (issue #1594). The handed-over command prints $branchPaste.Token so a
# branch name carrying a shell metacharacter cannot enter a line the reader pastes; what this assert
# exists to pin -- that the enqueue arm hands over a repair at all -- is unchanged.
Assert-True ($tail -match 'fold-changelog-entry\.ps1 -Branch \$\(\$branchPaste\.Token\) -Commit -Push') `
    'and hands over the command that repairs it by hand, since nothing else will'

# 2. THE ADOPTION COMMAND IS SHARED, or it exists only for the repo that does not need it. Read from
#    the registry rather than from the filesystem: the mirror is BUILT from that registration, so a
#    file present in plugins/ with no row behind it is one build away from disappearing.
. (Join-Path $repoRoot 'scripts\lib\shared-scripts-lib.ps1')
$pairNames = @((Get-SharedScriptPairs -RepoRoot $repoRoot) | ForEach-Object { $_.Name })
Assert-True ($pairNames -contains 'adopt-ci-floor') `
    'adopt-ci-floor is a registered shared pair -- a floor only the source can build is not a policy'

# 3. AND SO IS WHAT THE PLACED RUNNER CALLS. verify-resolved.yml runs verify-pushed-merges.ps1 out of
#    the plugin tree; unregistered, that scaffolded workflow points at a path no consumer has, and it
#    fails on a push to the trunk after a merge has already landed -- the quietest place to fail.
Assert-True ($pairNames -contains 'verify-pushed-merges') `
    'verify-pushed-merges is registered too, so the resolves runner a consumer places can reach it'

Write-Host "== the plugin mirror carries the same script ==" -ForegroundColor Cyan

# ship-pr.ps1 is plugin payload: consumers get this guard by plugin update, and a repo-settings change
# never reaches them at all. The shared-scripts drift lint covers the pair in general; this assert is
# here so the merge-queue guard specifically cannot land in the root copy alone.
Assert-True (Test-Path -LiteralPath $shipMirror) 'the plugin mirror of ship-pr.ps1 still exists'
if (Test-Path -LiteralPath $shipMirror) {
    $mirror = Get-Content -LiteralPath $shipMirror -Raw
    Assert-True ($mirror -match "'pr',\s*'view'[^\r\n]*'state'") `
        'and it carries the merge-state readback too -- consumers get this by plugin update, not by settings'
}

if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
