<#
.SYNOPSIS
    Regression tests for the concurrency blocks in .github/workflows/*.yml.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Reads the workflow files as text and runs a
    series of asserts. Exit code 0 if everything passes, 1 on a failure -- so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/workflow-concurrency.tests.ps1

    WHY THIS SUITE EXISTS, AND WHY A COMMENT WAS NOT ENOUGH. ci.yml carried a concurrency block whose
    comment named the hazard (the fold commit displacing the merge commit's run), named the stake (a
    cancelled check is not a passing one) and chose a guard -- a conditional cancel-in-progress -- that
    does not cover the path the cancellation actually takes. `cancel-in-progress` governs the
    IN-PROGRESS run; a concurrency group ALSO drops a PENDING run when a third arrival queues into it,
    and that path consults the field not at all. Measured September 3, 2026 (issue #1294) over the 28
    most recent 'merge:' commits on the trunk's first-parent line: 14 success, 14 cancelled, the
    cancelled ones with ZERO jobs allocated. Half the trunk had never been gated.

    So this is the exact class Sylvester's manual says to assert rather than comment: nothing errors,
    no check goes red, and the most convincing thing in the file is the reasoning that is wrong. The
    property is only observable by reading the run history afterwards, which no gate does -- so the
    grouping KEY is what gets pinned here.

    THE ASSERTS ARE ABOUT THE KEY, NOT ABOUT THE VALUE. A future reader repairing this class will reach
    for cancel-in-progress first, because that is the field named in every article about it. What has to
    survive is that a push to `main` shares its group with NO other push. Asserted in both directions:
    the push half must be keyed on the commit, and the PR half must NOT be -- keying a PR per commit
    would silently reopen the ~7m40s reruns PR #933 measured, which is the cost the block was written
    for in the first place.

    unfolded-entry.yml is asserted for the OPPOSITE arrangement, deliberately. There a shared trunk
    group and cancel-in-progress: true are correct: the check is required by nothing, and superseding
    the run is how the ship window (main genuinely carrying an unfolded entry for ~6s) stops reading as
    a stale red. An assert on each keeps a later sweep from "harmonising" the two.

    THE FOLD COMMIT'S SUITES ARE SKIPPED (#1300), and that lives here because it is the other half of
    the #1294 trade-off the concurrency block above is about: per-commit keying gated every trunk
    commit and doubled the runner minutes, and the fold commit's suite run is the part of that which
    tests nothing new. The condition is COMMIT-KIND (head_commit.message starts with 'fold:') and not
    a path filter, because paths-ignore would also skip a merge commit whose branch touched only the
    two paths a fold touches. The asserts pin: the suite step carries that `if:`, it is gated on the
    push event so a PR is untouched, and the lint step above it is NOT gated -- the fold commit still
    carries a green `lint-en-tests` of its own.

    THE FOLD RUNNER'S STAND-DOWN (#1586) IS HERE FOR THE SAME REASON, and it is the concurrency block's
    own consequence rather than a separate subject: the stand-down is only lossless because a push to
    the trunk queues another run of that workflow behind this one, which is the arrangement asserted
    above. A later reader who "harmonises" that group, or who widens the exit-2 branch into an
    `-ne 0` test, breaks the stand-down and the three-way red diagnosis in one edit -- so both
    directions are pinned: exit 2 exits 0, and every other code still propagates.

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

$wfDir = Join-Path $PSScriptRoot '..\..\.github\workflows'

# Read as one string per file. These blocks are a handful of lines and the asserts are substring
# questions, so a YAML parser would add a dependency to answer nothing extra.
$ci = Get-Content -LiteralPath (Join-Path $wfDir 'ci.yml') -Raw
$ue = Get-Content -LiteralPath (Join-Path $wfDir 'unfolded-entry.yml') -Raw
$fom = Get-Content -LiteralPath (Join-Path $wfDir 'fold-on-merge.yml') -Raw
$vr = Get-Content -LiteralPath (Join-Path $wfDir 'verify-resolved.yml') -Raw

Write-Host "== ci.yml: a push to main is its own concurrency group (#1294) ==" -ForegroundColor Cyan

# The load-bearing property. github.sha is the commit under test, so every push to `main` lands in a
# group of one and nothing can displace it -- pending or in progress.
Assert-True ($ci -match 'concurrency:') 'ci.yml still declares a concurrency block at all'
Assert-True ($ci -match 'group:[^\r\n]*github\.sha') 'the group key uses github.sha, so a push to main shares its group with no other push'
Assert-True ($ci -match "group:[^\r\n]*github\.event_name == 'pull_request'") 'the key branches on the event, which is what keeps the two halves apart'
Assert-True ($ci -match 'group:[^\r\n]*github\.ref') 'and the PR half is still keyed on the ref, not on the commit -- otherwise PR #933 reruns come back'

# The negative direction. Before #1294 this WAS the whole guard, and it was green while half the trunk
# went ungated -- so an assert that only checked this field would have proved nothing.
Assert-True ($ci -match "cancel-in-progress:[^\r\n]*github\.event_name == 'pull_request'") 'cancel-in-progress stays conditional -- but it is no longer what protects the push half'
Assert-True ($ci -notmatch 'cancel-in-progress:\s*true\s*$') 'and it is not a plain true, which would cancel a running trunk gate'

# The reasoning has to travel with the block, because the previous comment is what made the wrong guard
# look considered. Naming the issue is what lets a reader find the 14/14 measurement.
Assert-True ($ci -like '*#1294*') 'the block cites the issue whose measurement explains the key'
Assert-True ($ci -like '*PENDING*') 'and states the mechanism (a pending run is dropped), which is the part cancel-in-progress does not cover'

Write-Host "== ci.yml: the fold commit runs lint only, not the suites (#1300) ==" -ForegroundColor Cyan

# The suite step is the expensive half, and it is the one skipped on a fold commit. Match the step by
# its name so the assert points at the right block, then check the condition sits on it.
$suiteStep = [regex]::Match($ci, '(?ms)- name: Test suites.*?shell: powershell')
Assert-True ($suiteStep.Success) 'the Test suites step is still in ci.yml'
Assert-True ($suiteStep.Success -and $suiteStep.Value -match "if:[^\r\n]*startsWith\(github\.event\.head_commit\.message,\s*'fold:'\)") `
    'the Test suites step is skipped when the head commit is a fold: commit'
Assert-True ($suiteStep.Success -and $suiteStep.Value -match "if:[^\r\n]*github\.event_name == 'push'") `
    "and that skip is gated on the push event, so a PR still runs the suites (the required check is untouched)"

# The lint step must NOT carry the condition -- it is what keeps a green lint-en-tests on the fold
# commit, the trunk tip after a ship, and re-scans CHANGELOG.md's links once the entry has landed.
$lintStep = [regex]::Match($ci, '(?ms)- name: Lint gate.*?exit \$LASTEXITCODE')
Assert-True ($lintStep.Success) 'the Lint gate step is still in ci.yml'
Assert-True ($lintStep.Success -and $lintStep.Value -notmatch "startsWith\(github\.event\.head_commit\.message") `
    'the Lint gate step is NOT skipped on a fold commit -- the fold still carries a green check of its own'

# paths-ignore is the mechanism a later reader reaches for first, and it is the wrong one here: it
# would also skip a merge commit whose branch touched only the two paths a fold touches.
Assert-True ($ci -notmatch '(?m)^\s*paths-ignore:') 'the fold skip is not expressed as a path filter'
Assert-True ($ci -like '*#1300*') 'ci.yml cites the issue that sized the fold-commit trade-off'

Write-Host "== unfolded-entry.yml: the OPPOSITE arrangement, and correct there ==" -ForegroundColor Cyan

Assert-True ($ue -match 'group:[^\r\n]*github\.ref') 'its group is shared across the trunk, deliberately'
Assert-True ($ue -notmatch 'group:[^\r\n]*github\.sha') 'and is NOT keyed per commit -- superseding the ship window is the wanted behaviour here'
Assert-True ($ue -match 'cancel-in-progress:\s*true') 'cancel-in-progress: true, so a ~6s ship window does not leave a stale red'
Assert-True ($ue -like '*ci.yml*') 'and it says why it is the opposite of ci.yml, so neither gets harmonised into the other'

Write-Host "== fold-on-merge.yml + verify-resolved.yml: a THIRD arrangement -- shared group, no cancel (#1544) ==" -ForegroundColor Cyan

# These jobs WRITE and push to the trunk. Shared trunk group like unfolded-entry.yml (two trunk pushes
# must not run their folds concurrently), but cancel-in-progress: false unlike it (a superseded fold is
# the silent skip #1493 exists to close). A per-SHA group -- what these carried until #1544 -- is its own
# group every run and serialises nothing, so two pushes minutes apart raced for the trunk.
# A FOLD-ONLY PUSH GETS A GROUP OF ITS OWN (#2813). cancel-in-progress: false guards only the running
# job; a third arrival cancels the PENDING one regardless, and a skipped fold-only run surviving it
# dropped a merge's fold and its resolves check (October 5, 2026). So the group is the shared
# github.ref one for every push the job RUNS on, and per-commit for exactly the push its if: skips.
# The two conditions must be the same text: drift either way puts a skipped run back in the shared
# group (the bug) or a running one outside it (unserialised).
function Get-FoldOnlyGroupShape([string]$Yaml, [string]$Prefix) {
    $p = [regex]::Escape($Prefix)
    $g = [regex]::Match($Yaml, "(?m)^\s*group:\s*\$\{\{\s*\((?<cond>[^\r\n]+?)\)\s*&&\s*format\('$p-fold-only-\{0\}',\s*github\.sha\)\s*\|\|\s*format\('$p-\{0\}',\s*github\.ref\)\s*\}\}\s*$")
    $i = [regex]::Match($Yaml, '(?m)^\s*if:\s*\$\{\{\s*!\((?<cond>[^\r\n]+)\)\s*\}\}\s*$')
    [pscustomobject]@{ Group = $g.Success; JobIf = $i.Success; Same = ($g.Success -and $i.Success -and $g.Groups['cond'].Value -eq $i.Groups['cond'].Value) }
}
$fomShape = Get-FoldOnlyGroupShape $fom 'fold-on-merge'
$vrShape = Get-FoldOnlyGroupShape $vr 'verify-resolved'
Assert-True $fomShape.Group 'fold-on-merge.yml groups on github.ref, and a fold-only push on its own github.sha (#1544, #2813)'
Assert-True $fomShape.Same 'and the group''s fold-only condition is the job''s if: verbatim'
Assert-True ($fom -like '*#2813*') 'fold-on-merge.yml cites the issue behind the fold-only group'
Assert-True ($fom -match '(?m)^\s*cancel-in-progress:\s*false\s*$') 'cancel-in-progress: false -- a superseded fold is a dropped fold'
Assert-True $vrShape.Group 'verify-resolved.yml groups on github.ref too, with the same fold-only split'
Assert-True $vrShape.Same 'and its fold-only condition is its job''s if: verbatim'
Assert-True ($vr -match '(?m)^\s*cancel-in-progress:\s*false\s*$') 'cancel-in-progress: false -- a superseded verification is a dropped one'
Assert-True ($fom -like '*#1544*') 'fold-on-merge.yml cites the issue behind the constant group'

Write-Host "== fold-on-merge.yml: the fold checkout takes the trunk tip, not the event SHA (#1543) ==" -ForegroundColor Cyan

# On a push event actions/checkout defaults to github.sha. This job asks "does the trunk carry a
# leftover NOW", so a fold already pushed on top of the merge commit must not read as still-unfolded.
Assert-True ($fom -match '(?ms)-\s*uses:\s*actions/checkout@[0-9a-f]{40}[^\n]*\n\s*with:\s*\n\s*ref:\s*main\s*\n\s*token:\s*\$\{\{\s*secrets\.FOLD_PUSH_TOKEN') `
    'the first checkout pins ref: main ahead of the FOLD_PUSH_TOKEN line'
Assert-True ($fom -like '*#1543*') 'and cites the issue that explains why the event SHA is the wrong ref here'
# verify-resolved.yml deliberately does NOT pin ref -- it reads the pushed range from PUSH_SHA and must
# see the commits that push actually carried.
Assert-True ($vr -match 'PUSH_SHA:\s*\$\{\{\s*github\.sha\s*\}\}') 'verify-resolved.yml still resolves the PRs from the event SHA -- pinning its checkout would break that'

Write-Host "== fold-on-merge.yml: a trunk that moved under the run is a stand-down, not a red (#1586) ==" -ForegroundColor Cyan

# ref: main above is read ONCE, at the checkout; the fold measures the same trunk again ~11s later, so a
# second merge landing in that gap still trips the fold's trunk-gap guard (#1405) -- which is what the
# file claimed it could not until #1586. The repair is keyed on the fold's exit code 2, pinned in
# fold-changelog.tests.ps1 as the only place that returns it.
Assert-True ($fom -match '(?m)^\s*if \(\$foldExitCode -eq 2\) \{\s*$') 'the fold step branches on exit code 2 specifically'
Assert-True ($fom -match '(?ms)if \(\$foldExitCode -eq 2\) \{.*?exit 0') 'and exits 0 on it -- the job stands down rather than going red'

# THE OTHER HALF, and the one a later sweep is most likely to break: every other non-zero code must
# still fail. A blanket `exit 0` after the fold, or an `-ne 0`-shaped rewrite of the branch above, would
# turn a real refusal and a ruleset-rejected push (modes 2 and 3 in this file's header) green too.
Assert-True ($fom -match '(?m)^\s*exit \$foldExitCode\s*$') 'the step still ends by propagating the fold exit code, so modes 2 and 3 stay red'
Assert-True ($fom -notmatch '\$foldExitCode -ne 0') 'the stand-down is not expressed as a blanket "any non-zero is fine"'

# The stand-down is only safe because the guard fires before anything is folded AND because a successor
# run is queued by the same push -- which is a property of THIS file's concurrency block above, not of
# the script. Both halves of that argument have to travel with the block.
Assert-True ($fom -like '*#1586*') 'the file cites the issue whose run measured the red'
Assert-True ($fom -match '34206684361') 'and names the run, so the eleven-second window is checkable rather than asserted'
Assert-True ($fom -like '*pre-pass*') 'and states why nothing is lost: the guard refuses before a single entry is folded'

if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
