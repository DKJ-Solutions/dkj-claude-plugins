<#
.SYNOPSIS
    Tests for scripts/lib/ci-fold-lib.ps1 -- whether a CI runner folds off a push to the trunk
    (issue #2087), plus the structural half: that ship-pr.ps1 actually acts on the verdict.

.DESCRIPTION
    THE ASYMMETRY IS WHAT THIS SUITE IS BUILT AROUND. A false negative costs one refusal that was
    already being paid; a false positive costs a merged-and-unfolded trunk, which is the half-state
    nothing reports until a release trips over it. So the negative cases below outnumber the positive
    ones on purpose, and every ambiguous shape -- a glob, a branches-ignore filter, an unreadable file
    -- is asserted to answer NO rather than being left untested on the grounds that it is unusual.

    THE POSITIVE CASE IS PINNED AGAINST THIS REPO'S OWN RUNNER, not only against a fixture. A
    recogniser that agrees with its own test fixtures and not with the real fold-on-merge.yml is the
    failure mode a hand-written YAML scan is most likely to have, and it would be invisible in a suite
    that only ever fed itself.

    THE STRUCTURAL HALF IS THE POINT, as in closeout-lib.tests.ps1. A verdict that is computed and not
    ACTED ON leaves step 0a refusing exactly as before, which is the defect with extra steps -- so the
    asserts read ship-pr.ps1's source and hold it to the three sites the repair needs: the read at
    step 0a, the deferred arm on the refusal, and the guard around step 5's fold body.

    IT SPAWNS NOTHING AND WRITES NOTHING outside a temp directory it creates and removes. No fixture
    repo, no git, no gh.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\ci-fold-lib.ps1'
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

Assert-True (Test-Path -LiteralPath $LibPath) 'ci-fold-lib.ps1 exists at its registered source path'
. $LibPath

function New-Record {
    param([string]$Name, $Text)
    return [pscustomobject]@{ Name = $Name; Text = $Text }
}

Write-Host ''
Write-Host 'Test-PushTriggerOnBranch -- the four shapes that answer yes' -ForegroundColor Cyan

# The block-sequence form, which is what this repo's own runners are written in.
$blockSeq = @"
name: fold
on:
  push:
    branches:
      - main
jobs:
  x:
    runs-on: ubuntu-latest
"@
Assert-True (Test-PushTriggerOnBranch -WorkflowText $blockSeq -Branch 'main') 'block-sequence branches list naming the trunk'
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText $blockSeq -Branch 'trunk')) '...and not for a trunk it does not name'

$flowSeq = @"
on:
  push:
    branches: [main, release]
"@
Assert-True (Test-PushTriggerOnBranch -WorkflowText $flowSeq -Branch 'main') 'flow-sequence branches list naming the trunk'
Assert-True (Test-PushTriggerOnBranch -WorkflowText $flowSeq -Branch 'release') '...and a second entry in the same list'
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText $flowSeq -Branch 'mai')) '...and not a prefix of an entry'

# NO FILTER AT ALL RUNS ON EVERY BRANCH, which is GitHub's documented default and the shape a minimal
# fold runner is most likely to be written in.
$noFilter = @"
on:
  push:
jobs:
  x: {}
"@
Assert-True (Test-PushTriggerOnBranch -WorkflowText $noFilter -Branch 'main') 'push with no branches filter covers the trunk'

Assert-True (Test-PushTriggerOnBranch -WorkflowText "on: push`njobs: {}" -Branch 'main') 'inline scalar form (on: push)'
Assert-True (Test-PushTriggerOnBranch -WorkflowText "on: [push, pull_request]`njobs: {}" -Branch 'main') 'inline flow form naming push'
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText "on: [pull_request]`njobs: {}" -Branch 'main')) '...and not one that does not'

# THE QUOTED KEY IS NOT A CURIOSITY: bare `on` is a BOOLEAN in YAML 1.1, so an author who knows that
# writes it quoted, and matching only the bare spelling would read a correct file as having no triggers.
$quotedKey = @"
"on":
  push:
    branches: [main]
"@
Assert-True (Test-PushTriggerOnBranch -WorkflowText $quotedKey -Branch 'main') 'the quoted "on" key is recognised'

Write-Host ''
Write-Host 'Test-PushTriggerOnBranch -- every ambiguity answers no' -ForegroundColor Cyan

$globbed = @"
on:
  push:
    branches: ['*']
"@
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText $globbed -Branch 'main')) 'a glob that could match is NOT accepted'

$ignored = @"
on:
  push:
    branches-ignore:
      - gh-readonly-queue/**
"@
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText $ignored -Branch 'main')) 'branches-ignore answers no without being evaluated'

# A TAG FILTER WITH NO BRANCH FILTER FIRES ON TAG PUSHES AND NOT ON BRANCH PUSHES AT ALL. Reading
# "no branches: key" as "every branch" is the false positive this case exists to pin -- and it needs
# no unusual workflow to hit: a release runner is written exactly this way.
$tagsOnly = @"
on:
  push:
    tags: ['v*']
"@
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText $tagsOnly -Branch 'main')) 'a tags-only push trigger does not fire on the trunk'
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText "on:`n  push:`n    tags-ignore: ['v*']" -Branch 'main')) '...and neither does a tags-ignore-only one'

# BUT A TAG FILTER BESIDE A BRANCH FILTER STILL FIRES ON THE NAMED BRANCH.
$tagsAndBranches = @"
on:
  push:
    branches: [main]
    tags: ['v*']
"@
Assert-True (Test-PushTriggerOnBranch -WorkflowText $tagsAndBranches -Branch 'main') 'a tag filter beside a branch filter does not cancel the branch'

# A LIST ENTRY BELONGS TO THE KEY ABOVE IT. A paths: entry spelled exactly like the trunk must not
# answer for branches:, which is what reading every dash-item in the push block did.
$pathsNamedLikeTrunk = @"
on:
  push:
    branches: [release]
    paths:
      - main
"@
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText $pathsNamedLikeTrunk -Branch 'main')) "a paths: entry spelled like the trunk does not answer for branches:"

# AND THE MIRROR CASE: the branch list is read, and a later key does not end it early.
$branchesThenPaths = @"
on:
  push:
    branches:
      - release
      - main
    paths:
      - scripts/**
"@
Assert-True (Test-PushTriggerOnBranch -WorkflowText $branchesThenPaths -Branch 'main') 'a block branch list is read to its end, past a sibling key'
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText $branchesThenPaths -Branch 'scripts/**')) '...and a sibling key entry is not read as a branch'

# THE WORD 'push' IN A COMMENT OR A PATH MUST NOT READ AS A TRIGGER. This is why the key is matched by
# indentation rather than by a bare search for the word.
$mentionOnly = @"
# this workflow does not run on push
on:
  pull_request:
    paths:
      - 'scripts/push/**'
"@
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText $mentionOnly -Branch 'main')) "the word 'push' in a comment and a path is not a trigger"

$otherTrigger = @"
on:
  workflow_dispatch:
  schedule:
    - cron: '0 3 * * *'
"@
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText $otherTrigger -Branch 'main')) 'a workflow with no push trigger at all'

Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText '' -Branch 'main')) 'empty text answers no'
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText "name: x`njobs: {}" -Branch 'main')) 'a file with no on: key at all answers no'

# THE BLOCK ENDS AT THE NEXT TOP-LEVEL KEY, so a `push:` belonging to something else -- a job step, a
# `concurrency` group -- must not be read as a trigger.
$pushBelowJobs = @"
on:
  pull_request:
jobs:
  push:
    runs-on: ubuntu-latest
"@
Assert-True (-not (Test-PushTriggerOnBranch -WorkflowText $pushBelowJobs -Branch 'main')) "a job named 'push' below the on: block is not a trigger"

Write-Host ''
Write-Host 'Test-WorkflowRunsScript -- a mention is not an invocation' -ForegroundColor Cyan

# THE CASE THAT WAS LIVE IN THIS REPO. unfolded-entry.yml triggers on a push to the trunk and names the
# fold script in a COMMENT on line 3, while running only the detector -- and the first build of this lib,
# which asked the whole file text, qualified it. It was masked by alphabetical order: fold-on-merge.yml
# is read first and the verdict stops at the first match. This assert is the recogniser being asked the
# question directly, so the ordering cannot answer it.
$commentOnly = @"
# WHAT IT CATCHES. The fold (fold-changelog-entry.ps1) runs from exactly one place -- ship-pr.ps1.
on:
  push:
    branches: [main]
jobs:
  detect:
    steps:
      - run: pwsh -File dkj/scripts/lint/check-unfolded-entry.ps1 -Branch main
"@
Assert-True (-not (Test-WorkflowRunsScript -WorkflowText $commentOnly -ScriptName 'fold-changelog-entry.ps1')) 'a mention in a header comment is NOT an invocation'
$commentOnlyVerdict = Get-CiFoldRecoveryVerdict -Workflow @(New-Record 'unfolded-entry.yml' $commentOnly) -TrunkBranch 'main'
Assert-Equal $false $commentOnlyVerdict.Recovered '...so the verdict does not read it as recovery'

# AND THE SAME SHAPE THE ORDERING WAS HIDING: the commented one read FIRST, with no real runner behind it.
$orderingTrap = Get-CiFoldRecoveryVerdict -Workflow @(
    New-Record 'aaa-unfolded-entry.yml' $commentOnly
    New-Record 'zzz-ci.yml' $pushNoFold
) -TrunkBranch 'main'
Assert-Equal $false $orderingTrap.Recovered 'a repo whose only mention is a comment has no recovery, whatever the file order'

Assert-True (Test-WorkflowRunsScript -WorkflowText "jobs:`n  x:`n    steps:`n      - run: pwsh -File a/fold-changelog-entry.ps1 -Push" -ScriptName 'fold-changelog-entry.ps1') 'an inline run: naming the script IS an invocation'

# THE BLOCK SCALAR FORM, which is how a multi-line step is written.
$blockRun = @"
jobs:
  fold:
    steps:
      - name: fold
        run: |
          pwsh -NoProfile -File dkj/scripts/release/fold-changelog-entry.ps1 -Commit -Push
      - run: echo done
"@
Assert-True (Test-WorkflowRunsScript -WorkflowText $blockRun -ScriptName 'fold-changelog-entry.ps1') 'a run: block scalar naming the script is an invocation'

# A COMMENTED-OUT CALL INSIDE A RUN BLOCK IS NOT ONE. The language there is a shell, where '#' opens a
# comment in both sh and PowerShell -- so this is the shape a disabled step actually takes.
$commentedOutCall = @"
jobs:
  fold:
    steps:
      - run: |
          # pwsh -File dkj/scripts/release/fold-changelog-entry.ps1 -Push
          echo 'not folding today'
"@
Assert-True (-not (Test-WorkflowRunsScript -WorkflowText $commentedOutCall -ScriptName 'fold-changelog-entry.ps1')) 'a commented-out call inside a run: block is not an invocation'
Assert-True (-not (Test-WorkflowRunsScript -WorkflowText "jobs:`n  x:`n    steps:`n      - run: echo hi  # fold-changelog-entry.ps1 used to run here" -ScriptName 'fold-changelog-entry.ps1')) '...nor is a comment tail on a run: line'

# THE BLOCK ENDS AT THE KEY'S OWN DEPTH. A mention in a LATER key of the same step -- 'with:', 'env:',
# 'if:' -- is not the command.
$afterBlock = @"
jobs:
  fold:
    steps:
      - run: |
          echo hello
        env:
          NOTE: fold-changelog-entry.ps1
"@
Assert-True (-not (Test-WorkflowRunsScript -WorkflowText $afterBlock -ScriptName 'fold-changelog-entry.ps1')) 'a mention in a sibling key after the run: block is not an invocation'

# 'uses:' IS DELIBERATELY NOT ACCEPTED -- it names an action, not a script. A consumer folding through a
# composite action reads as no recovery, which costs them the refusal they already had.
Assert-True (-not (Test-WorkflowRunsScript -WorkflowText "jobs:`n  x:`n    steps:`n      - uses: ./.github/actions/fold-changelog-entry.ps1" -ScriptName 'fold-changelog-entry.ps1')) 'a uses: step is not read as running the script'

Assert-True (-not (Test-WorkflowRunsScript -WorkflowText '' -ScriptName 'fold-changelog-entry.ps1')) 'empty text runs nothing'

Write-Host ''
Write-Host 'Get-CiFoldRecoveryVerdict -- both conditions are required' -ForegroundColor Cyan

$foldRunner = @"
on:
  push:
    branches: [main]
jobs:
  fold:
    steps:
      - run: pwsh -File dkj/scripts/release/fold-changelog-entry.ps1 -Commit -Push
"@
$v = Get-CiFoldRecoveryVerdict -Workflow @(New-Record 'fold-on-merge.yml' $foldRunner) -TrunkBranch 'main'
Assert-Equal $true $v.Recovered 'a push-to-trunk workflow naming the fold script recovers the fold'
Assert-Equal 'fold-on-merge.yml' $v.Workflow '...and the verdict names it'
Assert-Equal '' $v.Reason '...and states no reason, because there is nothing to explain'

# THE NAME OF THE FILE IS NOT A CONDITION. A consumer may rename the runner; adopt-dkj-policy places it
# under a name it does not promise forever. What cannot be renamed is the script it has to call.
$renamed = Get-CiFoldRecoveryVerdict -Workflow @(New-Record 'trunk-housekeeping.yml' $foldRunner) -TrunkBranch 'main'
Assert-Equal $true $renamed.Recovered 'a renamed runner still recovers the fold'
Assert-Equal 'trunk-housekeeping.yml' $renamed.Workflow '...and is named by whatever it is called'

# CONDITION ONE ALONE IS NOT ENOUGH: a push-to-trunk workflow that folds nothing.
$pushNoFold = @"
on:
  push:
    branches: [main]
jobs:
  x:
    steps:
      - run: pwsh -File dkj/scripts/lint/check-unfolded-entry.ps1
"@
$v2 = Get-CiFoldRecoveryVerdict -Workflow @(New-Record 'unfolded-entry.yml' $pushNoFold) -TrunkBranch 'main'
Assert-Equal $false $v2.Recovered 'a push-to-trunk workflow that does not fold is not recovery'

# CONDITION TWO ALONE IS NOT ENOUGH EITHER: the fold script, on the wrong trigger.
$foldWrongTrigger = @"
on:
  workflow_dispatch:
jobs:
  fold:
    steps:
      - run: pwsh -File dkj/scripts/release/fold-changelog-entry.ps1
"@
$v3 = Get-CiFoldRecoveryVerdict -Workflow @(New-Record 'manual-fold.yml' $foldWrongTrigger) -TrunkBranch 'main'
Assert-Equal $false $v3.Recovered 'the fold script behind a manual trigger is not recovery'

# THE TRUNK IS THE ONE THE CALLER NAMES, not a hard-coded 'main'.
$v4 = Get-CiFoldRecoveryVerdict -Workflow @(New-Record 'fold-on-merge.yml' $foldRunner) -TrunkBranch 'trunk'
Assert-Equal $false $v4.Recovered "a runner on 'main' is not recovery for a repo whose trunk is 'trunk'"

Write-Host ''
Write-Host 'Get-CiFoldRecoveryVerdict -- the three ways of having no recovery are different sentences' -ForegroundColor Cyan

$none = Get-CiFoldRecoveryVerdict -Workflow @() -TrunkBranch 'main'
Assert-Equal $false $none.Recovered 'no workflow files at all: no recovery'
Assert-Equal 0 $none.Files '...counted as zero files'
Assert-True ($none.Reason -match 'no workflow files') '...and says so, rather than reporting a judgement'

# AN UNREADABLE FILE IS COUNTED, NOT DROPPED. "I read four and none folds" and "I could read none of the
# four" are different sentences, and only the first is a verdict about this repo.
$unread = Get-CiFoldRecoveryVerdict -Workflow @(New-Record 'a.yml' $null; New-Record 'b.yml' $null) -TrunkBranch 'main'
Assert-Equal $false $unread.Recovered 'two unreadable files: no recovery'
Assert-Equal 2 $unread.Files '...both counted as files'
Assert-Equal 0 $unread.Readable '...and neither as readable'
Assert-True ($unread.Reason -match 'could be read') '...with a reason that says the read failed, not that nothing folds'

$readNoFold = Get-CiFoldRecoveryVerdict -Workflow @(New-Record 'ci.yml' $pushNoFold) -TrunkBranch 'main'
Assert-Equal 1 $readNoFold.Readable 'a readable file that does not fold is counted as read'
Assert-True ($readNoFold.Reason -match "push to 'main'") '...and the reason names what was looked for'

# A MIXED SET STILL FINDS THE ONE THAT QUALIFIES, and an unreadable neighbour does not hide it.
$mixed = Get-CiFoldRecoveryVerdict -Workflow @(
    New-Record 'broken.yml' $null
    New-Record 'ci.yml' $pushNoFold
    New-Record 'fold-on-merge.yml' $foldRunner
) -TrunkBranch 'main'
Assert-Equal $true $mixed.Recovered 'a qualifying runner is found beside unreadable and non-folding ones'
Assert-Equal 'fold-on-merge.yml' $mixed.Workflow '...and is the one named'
Assert-Equal 3 $mixed.Files '...with every file counted'
Assert-Equal 2 $mixed.Readable '...and only the readable ones counted as read'

# A HASHTABLE RECORD READS THE SAME AS AN OBJECT ONE. A hashtable's PSObject.Properties are
# Keys/Values/Count, so reading only one shape is a silent miss rather than an error -- the exact trap
# Test-ConsumerRunnerAdoption's own header records having hit against the real register.
$asHash = Get-CiFoldRecoveryVerdict -Workflow @(@{ Name = 'fold-on-merge.yml'; Text = $foldRunner }) -TrunkBranch 'main'
Assert-Equal $true $asHash.Recovered 'a hashtable record is read exactly like an object one'

Write-Host ''
Write-Host "Against this repo's own runner, not only against fixtures" -ForegroundColor Cyan

# THE RECOGNISER IS PINNED AGAINST REALITY. A YAML scan that agrees with its own fixtures and not with
# the real fold-on-merge.yml is the failure a hand-written one is most likely to have, and a suite that
# only ever fed itself could not see it.
$real = Get-CiFoldRecoveryVerdict -Workflow @(Get-RepoWorkflowRecord -RepoRoot $RepoRoot) -TrunkBranch 'main'
Assert-Equal $true $real.Recovered "this repo's own .github/workflows is read as folding on a push to main"
Assert-Equal 'fold-on-merge.yml' $real.Workflow '...by fold-on-merge.yml specifically'
Assert-True ($real.Readable -ge 5) '...having actually read the workflow files rather than none of them'

# AND THE NEGATIVE CONTROL ON THE SAME REAL FILES: change only what the fold script is called, and the
# same directory answers no. Without this the positive above could pass on any workflow at all.
$realNeg = Get-CiFoldRecoveryVerdict -Workflow @(Get-RepoWorkflowRecord -RepoRoot $RepoRoot) `
    -TrunkBranch 'main' -FoldScriptName 'a-script-no-workflow-names.ps1'
Assert-Equal $false $realNeg.Recovered '...and answers no when the script it must name is absent'

Write-Host ''
Write-Host 'Get-RepoWorkflowRecord -- the disk read' -ForegroundColor Cyan

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ci-fold-lib-tests-" + [guid]::NewGuid().ToString('N'))
try {
    $null = New-Item -ItemType Directory -Path (Join-Path $tmp '.github/workflows') -Force
    Set-Content -LiteralPath (Join-Path $tmp '.github/workflows/one.yml') -Value $foldRunner -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $tmp '.github/workflows/two.yaml') -Value $pushNoFold -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $tmp '.github/workflows/notes.md') -Value 'not a workflow' -Encoding UTF8

    $records = @(Get-RepoWorkflowRecord -RepoRoot $tmp)
    Assert-Equal 2 $records.Count 'both .yml and .yaml are read, and nothing else is'
    Assert-True (@($records | ForEach-Object { $_.Name }) -contains 'two.yaml') '...the .yaml extension included, because GitHub accepts both'

    $fromDisk = Get-CiFoldRecoveryVerdict -Workflow $records -TrunkBranch 'main'
    Assert-Equal $true $fromDisk.Recovered 'the disk read feeds the verdict unchanged'

    # A REPO WITH NO WORKFLOW DIRECTORY IS NOT AN ERROR. It is a consumer that never adopted the CI
    # floor, which is the state this whole file is required to leave untouched.
    $bare = Join-Path $tmp 'bare'
    $null = New-Item -ItemType Directory -Path $bare -Force
    Assert-Equal 0 @(Get-RepoWorkflowRecord -RepoRoot $bare).Count 'a repo with no .github/workflows reads as zero records'
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'The structural half -- ship-pr.ps1 acts on the verdict' -ForegroundColor Cyan

$ship = Get-Content -LiteralPath $ShipPath -Raw

# SINGLE-QUOTED, AND THAT IS THE POINT RATHER THAN A STYLE CHOICE. PowerShell's double-quoted string
# does NOT treat a backslash as an escape (the backtick is its escape character), so a doubled
# backslash written for the regex arrives at the regex engine doubled and matches two literal
# backslashes -- a path no source file carries. This suite's first run failed on exactly that, which is
# the assert reporting its own spelling rather than the file's content.
Assert-True ($ship -match 'lib\\ci-fold-lib\.ps1') 'ship-pr.ps1 dot-sources ci-fold-lib.ps1'
Assert-True ($ship -match 'Get-CiFoldRecoveryVerdict') '...and computes the verdict'

# THE REFUSAL IS CONDITIONED ON THE RUNNER, NOT ONLY ON THE QUEUE. This is the whole repair: a verdict
# that is computed and not acted on leaves step 0a refusing exactly as before.
Assert-True ($ship -match 'if \(\$trunkHolder -and -not \$queueActive -and \$ciFold\.Recovered\)') 'step 0a has a deferred arm when a runner folds'
Assert-True ($ship -match 'if \(\$trunkHolder -and -not \$queueActive -and -not \$ciFold\.Recovered\)') '...and refuses only when none does'

# AND STEP 5 MUST ACTUALLY SKIP THE FOLD. Merging with the flag set and then folding anyway would take
# a trunk this clone cannot give, after the irreversible half of the run.
Assert-True ($ship -match 'if \(-not \$foldDeferredToCi\) \{') "step 5's fold body is guarded by the deferred flag"
Assert-True ($ship -match 'if \(-not \$foldDeferredToCi -and -not \$foldTree -and -not \$shipTreeIsPrimary\)') 'step 5b does not hand back a trunk it never took'

# $foldStoodDown IS INITIALISED OUTSIDE THE GUARD, because step 5c reads it on the deferred path and an
# undefined variable there would read as $false by accident rather than by decision.
Assert-True ($ship -match '(?m)^\$foldStoodDown = \$false') '$foldStoodDown is initialised above the guard, for step 5c'

# THE QUEUE PATH ASKS THE SAME QUESTION RATHER THAN ITS OWN NARROWER ONE (#1516 consolidated into
# #2087): the literal filename test there answered "nothing folds here" on a repo that had simply
# renamed its runner.
Assert-True ($ship -notmatch 'workflows\\fold-on-merge\.yml') 'the queue path no longer tests for a literal fold-on-merge.yml path'

Write-Host ''
Write-Host 'The lib is ASCII and mirrored' -ForegroundColor Cyan

$raw = Get-Content -LiteralPath $LibPath -Raw
Assert-True (-not ($raw -cmatch '[^\x00-\x7F]')) 'ci-fold-lib.ps1 is pure ASCII'

# Mirrored, so a consumer meets the same shape this repo does. shared-scripts.tests.ps1 owns the
# byte-identity assert; this one is only that the registration exists at all.
Assert-True ((Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1') -Raw) -match 'ci-fold-lib') 'ci-fold-lib is registered as a shared script'
Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy\scripts\lib\ci-fold-lib.ps1')) '...and its plugin mirror is present'

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
