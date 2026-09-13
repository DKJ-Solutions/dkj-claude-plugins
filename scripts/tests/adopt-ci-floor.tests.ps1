<#
.SYNOPSIS
    Tests for scripts/task/adopt-ci-floor.ps1 -- the CI floor a consuming repo adopts (issues
    #1516, #1546).

.DESCRIPTION
    WHY THIS SUITE EXISTS. Every property below fails SILENTLY, which is the same reason
    merge-queue-prereq.tests.ps1 exists one file over: a merge queue changes what a merge DOES, and a
    repo standing on an incomplete floor looks exactly like one standing on a complete one until the
    first merge afterwards. What is covered, and why these seven:

      1. the DRY RUN default writes nothing -- the contract adopt-config and adopt-workflow-folder are
         both trusted on, and this command writes into .github/, which is not a folder to surprise
         somebody with;
      2. -Apply places both runners, and each reaches its script through the PLUGIN tree rather than
         through an in-repo path. A runner that called `scripts/release/fold-changelog-entry.ps1` would
         be green here and dead in every consumer, because that path is the SOURCE's;
      3. a re-run is additive -- a runner somebody edited is never overwritten, whatever it says;
      4. the two vocabularies and the exit code. A '[gap]' on a trunk with no queue is a to-do and
         exits 0; the same gap with a queue ACTIVE is a live defect and exits 1. Collapsing the two is
         how an honest report earns being ignored, and it is the one judgement this script makes;
      4b. AND A MISSING QUEUE IS NEITHER (#1540, #1546). It printed as a closable '[gap]' until
         September 7, 2026, while GitHub offers merge queue on a private repo only under Enterprise
         Cloud -- so for most consumers that gap named a checkbox their ruleset UI does not render.
         It is a '[note]' now. What survives as a gap is the REQUIRED CHECK, whose reason changed with
         the policy: with none named ship-pr has no certificate to date and the staleness guard is off;
      5. the merge_group prerequisite is read as a KEY of the on: block, so a workflow that merely
         mentions the trigger in a comment is not reported as ready. This is the assert that would go
         green on a substring match while the outage it prevents is live;
      6. the switch is never flipped. The run composes a ruleset instruction and stops -- no call that
         WRITES a ruleset may appear in this script at all, because a repo-settings change is the
         owner's act;
      7. a repo that publishes this workflow is refused -- the source arranges its own runners by hand,
         and they are the originals these are derived from.

    THE RULES PAYLOAD ARRIVES FROM A FIXTURE FILE, via -RulesJsonOverride. It is the only way to reach
    the queue-is-active arm at all: a test tree is not a checkout, has no remote, and CI has no token
    that can read somebody's ruleset. The payload shape is the real one -- the same
    `gh api repos/<repo>/rules/branches/<trunk>` records Get-MergeQueueVerdict and
    Get-DirectPushBlockingRules parse in production, so the fixture cannot drift into a shape only this
    suite understands.

    The repo root is pinned per child run via CLAUDE_PROJECT_DIR, the same dual-context branch every
    mirrored script resolves first, so the fixtures need no git of their own.

    Dependency-free: no Pester, only PowerShell. Exit 0 if everything passes, 1 on a failure.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\task\adopt-ci-floor.ps1'
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "adopt-ci-floor-test-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

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
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

# THE TWO PAYLOADS, in the shape gh actually returns. `merge_queue` is a bare record with a type and no
# parameters, which is exactly what Get-MergeQueueVerdict looks for; the required check carries its
# context inside parameters.required_status_checks, which is where Get-DirectPushBlockingRules reads it.
$RulesQueueOn = '[{"type":"deletion"},{"type":"required_status_checks","ruleset_id":7,"parameters":{"required_status_checks":[{"context":"lint-en-tests"}]}},{"type":"merge_queue"}]'
$RulesQueueOff = '[{"type":"required_status_checks","ruleset_id":7,"parameters":{"required_status_checks":[{"context":"lint-en-tests"}]}}]'
# NO QUEUE AND NOTHING REQUIRED -- the shape that leaves the staleness guard with no certificate to
# date, which is the one gap this command still reports after the queue stopped being policy (#1546).
$RulesQueueOffNoChecks = '[{"type":"deletion"},{"type":"non_fast_forward"}]'

function New-FixtureConsumer {
    <#
        -WithMergeGroup gives the required check's workflow the trigger; without it the workflow is the
        outage case. -AsWorkflowSource writes a marketplace publishing THIS workflow, which is the one
        tree the command refuses. -Trunk answers the Get-TrunkBranchName seam, so the placed runners can
        be read for whether they followed it.

        THE JOB KEY IS THE CHECK CONTEXT and the fixture says so deliberately: GitHub names an Actions
        check after the job's `name:` where it has one and after its key otherwise, and 'lint-en-tests'
        is the key here exactly as it is in the source repo's own ci.yml.
    #>
    param(
        [string]$Label,
        [switch]$WithMergeGroup,
        [switch]$AsWorkflowSource,
        [string]$Trunk = ''
    )
    $root = Join-Path $Fixture "consumer-$Label"
    if (Test-Path -LiteralPath $root) { Remove-Item -Recurse -Force -LiteralPath $root }
    New-Item -ItemType Directory -Path (Join-Path $root '.github\workflows') -Force | Out-Null

    $trigger = if ($WithMergeGroup) { "  merge_group:`n" } else { '' }
    # THE COMMENT IS THE POINT OF THIS FIXTURE, not decoration: it names merge_group in prose in every
    # variant, so an implementation matching the word anywhere in the file reports the outage case as
    # ready. That is assert 5, and it is the shape check-plugin-integrity's own trigger assert takes.
    $ci = @(
        '# CI. This workflow does not yet think about merge_group at all.',
        'name: CI',
        'on:',
        '  pull_request:',
        '    branches: [main]',
        ($trigger + 'jobs:'),
        '  lint-en-tests:',
        '    runs-on: ubuntu-latest',
        '    steps:',
        '      - run: echo hi'
    ) -join "`n"
    [System.IO.File]::WriteAllText((Join-Path $root '.github\workflows\ci.yml'), $ci + "`n")

    if ($Trunk) {
        New-Item -ItemType Directory -Path (Join-Path $root 'scripts') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $root 'scripts\repo-config.ps1'), "function Get-TrunkBranchName { '$Trunk' }`n")
    }
    if ($AsWorkflowSource) {
        $manifest = '{ "name": "fixture", "plugins": [ { "name": "dkj-policy", "source": "./x" } ] }'
        New-Item -ItemType Directory -Path (Join-Path $root '.claude-plugin') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $root '.claude-plugin\marketplace.json'), $manifest)
    }
    return $root
}

function New-RulesFile {
    param([string]$Label, [string]$Json)
    $p = Join-Path $Fixture "rules-$Label.json"
    [System.IO.File]::WriteAllText($p, $Json)
    return $p
}

function Invoke-Adopt {
    param([string]$Dir, [string[]]$ScriptArgs = @())
    $prevPd = $env:CLAUDE_PROJECT_DIR
    try {
        $env:CLAUDE_PROJECT_DIR = $Dir
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script @ScriptArgs
        # Flat is FOR PHRASE ASSERTS ONLY: the child wraps its Write-Host lines at its own host width, a
        # point that moves with the console and with the fixture's temp path length, so a phrase sitting
        # mid-line arrives split MID-WORD across two records. Joined with '' rather than a space because
        # the break is hard at a column, so the halves reconstruct exactly -- the same reasoning
        # adopt-workflow-folder.tests.ps1 and prune-merged.tests.ps1 both carry. Out keeps the line
        # structure for the per-line [create]/[exists] asserts.
        return [pscustomobject]@{
            Code = $LASTEXITCODE
            Out  = ($out -join "`n")
            Flat = (($out | ForEach-Object { [string]$_ }) -join '')
        }
    } finally {
        if ($null -eq $prevPd) { Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prevPd }
    }
}

# Both runners -Apply must place. Read from one list rather than restated per assert, so a target added
# to the script fails ONE list here instead of passing unexamined.
$ExpectedRunners = @(
    '.github\workflows\fold-on-merge.yml',
    '.github\workflows\verify-resolved.yml'
)

try {
    Write-Host '== adopt-ci-floor.tests: scripts/task/adopt-ci-floor.ps1 ==' -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null
    $rulesOn = New-RulesFile -Label 'on' -Json $RulesQueueOn
    $rulesOff = New-RulesFile -Label 'off' -Json $RulesQueueOff
    $rulesOffNoChecks = New-RulesFile -Label 'off-nochecks' -Json $RulesQueueOffNoChecks

    # --- 1. Dry run (the default): the plan is printed, nothing is written -------------------------
    Write-Host '-- 1. the dry run writes nothing --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'dry'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff)
    Assert-True ($r.Flat -like '*DRY RUN*') 'the default run says it is a dry run'
    foreach ($f in $ExpectedRunners) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $dir $f))) "dry run did not write $f"
    }
    Assert-Equal 0 $r.Code 'and exits 0 -- an unbuilt floor on a queueless trunk is a to-do, not a defect'

    # --- 2. -Apply places both runners, pointing at the PLUGIN tree --------------------------------
    Write-Host '-- 2. -Apply places both runners, reaching their scripts through the plugin tree --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'apply'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff, '-Apply')
    foreach ($f in $ExpectedRunners) {
        Assert-True (Test-Path -LiteralPath (Join-Path $dir $f)) "-Apply placed $f"
    }
    $fold = [System.IO.File]::ReadAllText((Join-Path $dir '.github\workflows\fold-on-merge.yml'))
    $verify = [System.IO.File]::ReadAllText((Join-Path $dir '.github\workflows\verify-resolved.yml'))

    # THE PATH IS THE WHOLE POINT OF THE SCAFFOLD. A runner calling 'scripts/release/...' would be the
    # SOURCE's path -- correct there, absent in every consumer -- and it would fail at the one moment
    # nobody is watching: on a push to the trunk, after a merge has already landed.
    Assert-True ($fold -like '*.workflow-scripts/plugins/dkj-policy/scripts/lint/check-unfolded-entry.ps1*') `
        'the fold runner calls the plugin mirror of check-unfolded-entry, not an in-repo path'
    Assert-True ($fold -like '*.workflow-scripts/plugins/dkj-policy/scripts/release/fold-changelog-entry.ps1*') `
        'and the plugin mirror of fold-changelog-entry'
    Assert-True ($verify -like '*.workflow-scripts/plugins/dkj-policy/scripts/release/verify-pushed-merges.ps1*') `
        'the resolves runner calls the plugin mirror of verify-pushed-merges'

    # AND THE THREE ASSERTS ABOVE CANNOT CATCH A MOVE, which is why the four below exist (#1805). Each
    # of them compares the scaffolder's output against a literal copied out of that same scaffolder --
    # so they answer "does it still emit this string", never "is there a script at the other end". The
    # path DID move here (plugins/workflows/contributing-davekjohn/ -> plugins/dkj-policy/), all three
    # stayed green, and two consumers scaffolded before the move were red on every pull request for
    # five days. They are kept, because what they pin is real -- a runner naming the SOURCE's own
    # scripts/ path would be correct here and absent in every consumer -- and the derived asserts below
    # answer the other question rather than replacing them.
    . (Join-Path $RepoRoot 'scripts\lib\consumer-runner-lib.ps1')
    foreach ($runner in @(
        @{ Name = 'fold-on-merge.yml';   Text = $fold;   Expect = 2 },
        @{ Name = 'verify-resolved.yml'; Text = $verify; Expect = 1 }
    )) {
        $refs = @(Get-SharedScriptReference -WorkflowText $runner.Text -RepositoryName 'dkj-claude-plugins')
        Assert-Equal $runner.Expect $refs.Count "$($runner.Name): reaches $($runner.Expect) script(s) out of a checkout of this repo"
        foreach ($judged in @(Test-SharedScriptReference -Reference $refs -SourceRoot $RepoRoot)) {
            Assert-True $judged.Exists "$($runner.Name): runs '$($judged.Path)', and that path EXISTS in this tree"
        }
    }

    # CLAUDE_PROJECT_DIR IS NOT OPTIONAL IN EITHER. A mirrored script resolves the tree it judges from
    # that variable first; without it the fold would read whatever `git rev-parse` answered in a
    # workspace holding two checkouts, which is a coin toss rather than a bug that shows up.
    Assert-True ($fold -like '*CLAUDE_PROJECT_DIR: ${{ github.workspace }}*') `
        'the fold runner points the mirrored scripts at the consumer tree via CLAUDE_PROJECT_DIR'
    Assert-True ($verify -like '*CLAUDE_PROJECT_DIR: ${{ github.workspace }}*') `
        'and so does the resolves runner'

    # THE CREDENTIAL SPLIT, which is the security decision this scaffold inherits: the standing PAT and
    # `issues: write` must never sit in one job.
    Assert-True ($fold -like '*secrets.FOLD_PUSH_TOKEN*') 'the fold runner checks out with FOLD_PUSH_TOKEN -- the default token cannot push past a merge_queue rule'
    Assert-True ($fold -notlike '*issues: write*') 'and never holds issues: write beside that standing credential'
    Assert-True ($verify -like '*issues: write*') 'the resolves runner holds issues: write, which is what makes it repair rather than report'
    Assert-True ($verify -notlike '*FOLD_PUSH_TOKEN*') 'and never touches the standing credential'
    Assert-True ($r.Flat -like '*FOLD_PUSH_TOKEN*') 'and the run TELLS you to create that secret'
    Assert-True ($r.Flat -like '*actions/checkout FAILS*') 'and says an absent/under-scoped token fails the checkout, not the push (inbound #1539)'
    Assert-True ($r.Flat -like '*every later step*skipped*') 'naming the tell -- every later step skipped -- so the checkout is ruled out first'

    # --- 2b. The three corrections that landed together (inbound #1539/#1543/#1544) -----------------
    # THE CONCURRENCY GROUP IS CONSTANT PER TRUNK, NOT PER COMMIT (#1544). A per-SHA group is its own
    # group every run and serialises nothing, so two trunk pushes race -- and this job pushes.
    Assert-True ($fold -match '(?m)^\s*group:\s*fold-on-merge-\$\{\{\s*github\.ref\s*\}\}\s*$') `
        'the fold runner concurrency group is keyed on github.ref, so two trunk pushes queue rather than race'
    Assert-True ($fold -notmatch '(?m)^\s*group:[^\r\n]*github\.sha') 'and the group line is never keyed on github.sha, which would serialise nothing'
    Assert-True ($verify -match '(?m)^\s*group:\s*verify-resolved-\$\{\{\s*github\.ref\s*\}\}\s*$') `
        'the resolves runner group is keyed on github.ref too'
    Assert-True ($fold -like '*cancel-in-progress: false*') 'and cancellation stays off -- no fold is dropped'

    # THE FOLD CHECKOUT TAKES THE TRUNK TIP, NOT THE EVENT SHA (#1543). On a push event actions/checkout
    # defaults to github.sha; a fold ship-pr already pushed on top of the merge then reads as unfolded
    # and the trunk-gap guard refuses -- a false red on every ship-pr merge.
    Assert-True ($fold -match '(?ms)uses:\s*actions/checkout@v5\s*\n\s*with:\s*\n\s*ref:\s*main\s*\n\s*token:\s*\$\{\{\s*secrets\.FOLD_PUSH_TOKEN') `
        'the fold runner first checkout pins ref to the trunk, ahead of the token line'
    # The resolves runner keeps the event SHA -- it resolves THIS push''s PRs and has no trunk-gap guard.
    Assert-True ($verify -like '*PUSH_SHA: ${{ github.sha }}*') 'the resolves runner still reads the event SHA -- it resolves the PRs that push carried'

    # AND ref: TRUNK DOES NOT PUT THAT GUARD OUT OF REACH (#1586). The ref is read once, at the
    # checkout; the fold measures the same trunk again seconds later, so a second merge landing in that
    # gap still trips it -- and this template said the guard was unreachable until that was measured.
    # The placed runner therefore stands down on the fold's exit code 2, and on that code alone.
    Assert-True ($fold -match '(?m)^\s*if \(\$foldExitCode -eq 2\) \{\s*$') `
        'the placed fold runner branches on the fold exit code 2 (#1586)'
    Assert-True ($fold -match '(?ms)if \(\$foldExitCode -eq 2\) \{.*?exit 0') 'and exits 0 on it -- a stand-down, not a red'
    Assert-True ($fold -match '(?m)^\s*exit \$foldExitCode\s*$') 'while every other non-zero code is still propagated, so a real refusal stays red'
    Assert-True ($fold -notmatch '\$foldExitCode -ne 0') 'and the stand-down is not a blanket "any non-zero is fine"'
    Assert-True ($fold -like '*#1586*') 'and the runner carries the issue that explains why that one code is green'

    # AND ON THE NARROW HALF OF THE SAME RACE (#1796). Exit 2 is the other fold landing BEFORE the
    # pre-pass; exit 3 is it landing between the pre-pass and this runner's own push, which no check at
    # the top of a run can close. The fold earns 3 by measuring that every entry it carried is already
    # upstream, so the trunk holds what this job exists to put there -- and the redundant commit it
    # leaves behind is in a workspace that dies with the run.
    Assert-True ($fold -match '(?m)^\s*if \(\$foldExitCode -eq 3\) \{\s*$') `
        'the placed fold runner branches on the fold exit code 3 too (#1796)'
    Assert-True ($fold -match '(?ms)if \(\$foldExitCode -eq 3\) \{.*?exit 0') 'and exits 0 on that one as well -- the second stand-down'
    Assert-True ($fold -like '*#1796*') 'and carries the issue that explains why the narrow half needs its own code'
    # THE TWO CODES ARE THE WHOLE STAND-DOWN LIST. A third would have to be argued for on its own
    # ground, so this counts rather than merely checking the two are present -- the same property the
    # fold script's own suite asserts at its source.
    Assert-Equal 2 (@([regex]::Matches($fold, '\$foldExitCode -eq \d')).Count) `
        'and exactly TWO exit codes are stood down on -- 2 and 3, and nothing else'

    # --- 3. Additive: a re-run never overwrites -----------------------------------------------------
    Write-Host '-- 3. a re-run is additive --' -ForegroundColor Cyan
    $edited = '# my own fold runner'
    [System.IO.File]::WriteAllText((Join-Path $dir '.github\workflows\fold-on-merge.yml'), $edited)
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff, '-Apply')
    Assert-Equal $edited ([System.IO.File]::ReadAllText((Join-Path $dir '.github\workflows\fold-on-merge.yml'))) `
        'a runner somebody edited is left exactly as it is'
    Assert-True ($r.Out -match '(?m)\[exists\]\s+\.github/workflows/fold-on-merge\.yml') 'and is reported as already there rather than silently skipped'

    # --- 4. The two vocabularies, and the exit code --------------------------------------------------
    Write-Host '-- 4. a gap on a queueless trunk is a to-do; the same gap under a live queue is a defect --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'live'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOn)
    Assert-Equal 1 $r.Code 'a queue ACTIVE with no runners in the tree exits 1'
    Assert-True ($r.Flat -like '*live defect*') 'and says why in those words'
    Assert-True ($r.Out -match '(?m)\[MISSING\]\s+\.github/workflows/fold-on-merge\.yml') 'the missing fold runner is marked MISSING rather than as a suggestion'

    $dir = New-FixtureConsumer -Label 'todo'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff)
    Assert-Equal 0 $r.Code 'the same tree with no queue on the trunk exits 0'
    Assert-True ($r.Out -match '(?m)\[create\]\s+\.github/workflows/fold-on-merge\.yml') 'and the same file is offered rather than reported'

    # AN UNREADABLE PAYLOAD IS NOT "NO QUEUE", and it is not a defect either: the question was not
    # answered. A run that treated it as either would be making up an answer at the one point where
    # ship-pr's own verdict is deliberately careful not to.
    $dir = New-FixtureConsumer -Label 'unreadable'
    $missing = Join-Path $Fixture 'rules-does-not-exist.json'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $missing)
    Assert-Equal 0 $r.Code 'an unreadable rules payload does not fail the run'
    Assert-True ($r.Flat -like '*could not be read*') 'and says the question was not answered, rather than answering it'

    # --- 5. merge_group is read as a KEY, never as the word ------------------------------------------
    Write-Host '-- 5. the merge_group prerequisite --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'notrigger'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOn)
    Assert-True ($r.Flat -like "*required check 'lint-en-tests'*") 'the required context is resolved to the workflow whose job key it is'
    Assert-True ($r.Flat -like '*does NOT trigger on merge_group*') `
        'and a workflow that only MENTIONS merge_group in a comment is not read as carrying the trigger'
    Assert-True ($r.Flat -like '*every merge fails*') 'the consequence is named as an outage, which is what it is'

    $dir = New-FixtureConsumer -Label 'trigger' -WithMergeGroup
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOn)
    Assert-True ($r.Flat -like '*which triggers on merge_group*') 'a workflow that does carry the trigger is reported as ready'
    Assert-True ($r.Flat -notlike '*every merge fails*') 'and the outage is not reported against it'

    # --- 6. The trunk is read, never assumed ---------------------------------------------------------
    Write-Host '-- 6. the placed runners follow this repo trunk --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'trunk' -Trunk 'trunk'
    $null = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff, '-Apply')
    $fold = [System.IO.File]::ReadAllText((Join-Path $dir '.github\workflows\fold-on-merge.yml'))
    Assert-True ($fold.Contains('branches: [trunk]')) 'the fold runner triggers on the trunk Get-TrunkBranchName names, not on a hardcoded main'
    Assert-True ($fold -like '*-Branch trunk*') 'and passes that same trunk to the check it runs'
    Assert-True ($fold -match '(?m)^\s*ref:\s*trunk\s*$') 'and its first checkout pins ref to that same trunk, not a hardcoded main (#1543)'
    Assert-True ($fold -match '(?m)^\s*group:\s*fold-on-merge-\$\{\{\s*github\.ref\s*\}\}\s*$') 'the concurrency group is still github.ref-keyed on a non-main trunk (#1544)'

    # --- 7. The switch is composed, never pulled -----------------------------------------------------
    Write-Host '-- 7. the setting itself is the owner act, and this script does not make it --' -ForegroundColor Cyan
    $src = [System.IO.File]::ReadAllText($Script)
    # The subject is a WRITE, not the word 'ruleset': the script reads a ruleset on every run and must
    # keep doing so. A gh call carrying a write method, or the rulesets collection endpoint, is what
    # would make this a tool that changes repo settings.
    Assert-True ($src -notmatch "'-X'\s*,\s*'(PUT|POST|PATCH|DELETE)'") 'no gh api call in this script carries a write method'
    Assert-True ($src -notmatch "--method\s+(PUT|POST|PATCH|DELETE)") 'and none carries one in the long spelling either'
    Assert-True ($src -notmatch "'api'[^\r\n]*rulesets") 'and it never addresses the rulesets collection, which is the endpoint that creates one'
    $dir = New-FixtureConsumer -Label 'switch'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff)
    Assert-True ($r.Flat -like '*WILL NOT DO IT FOR YOU*') 'and it says so, rather than leaving the reader to notice nothing happened'
    Assert-True ($r.Flat -like '*Require merge queue*') 'while naming the change precisely enough to make it'

    # --- 7b. A MISSING QUEUE IS NOT A GAP (issues #1540, #1546) ---------------------------------------
    # It printed '[gap] no merge_queue rule' until September 7, 2026, on the policy that every repo
    # running this workflow adopts one. GitHub offers merge queue on a PRIVATE repo only under
    # Enterprise Cloud, so for most consumers the instruction named a checkbox their ruleset UI does not
    # render -- an unclosable gap, measured after a consumer had built the entire floor beneath it. The
    # queue is optional now and a trunk without one is in the ORDINARY state.
    Write-Host '-- 7b. a trunk with no queue is the ordinary state, not a gap --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'noqueue-note'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff)
    Assert-True ($r.Out -notmatch "(?m)\[gap\][^\r\n]*merge_queue rule") 'a trunk with no queue is NOT reported as a gap any more'
    Assert-True ($r.Out -match "(?m)\[note\][^\r\n]*no merge_queue rule") 'it is a note instead'
    Assert-True ($r.Flat -like '*ordinary state*') 'and says in those words that this is the ordinary state'
    Assert-True ($r.Flat -like '*Enterprise Cloud*') 'naming the entitlement that makes a queue unavailable to most private repos'
    Assert-True ($r.Flat -like '*detect-and-rebase*') 'and naming what the workflow relies on instead'
    Assert-Equal 0 $r.Code 'and it still exits 0 -- nothing here is a defect'

    # THE ONE GAP THAT SURVIVES, and its reason changed with the policy: with no required check named,
    # ship-pr has no certificate to date, so the staleness guard is off. That is every repo's business
    # now, where it used to read as a precondition for a switch a reader might never be able to flip.
    $dir = New-FixtureConsumer -Label 'noreq'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks)
    Assert-True ($r.Out -match "(?m)\[gap\][^\r\n]*no required status check") 'a trunk with nothing required is still a gap'
    Assert-True ($r.Flat -like '*staleness guard is OFF*') 'and the reason given is the staleness guard, not the queue'
    Assert-True ($r.Flat -like '*branch-entry*') 'it names the gate that CANNOT carry the role (issue #1538)'
    Assert-True ($r.Flat -like '*github.head_ref*') 'and says why -- head_ref is empty outside a pull request'
    Assert-Equal 0 $r.Code 'still a to-do rather than a defect, so the run exits 0'

    # --- 8. The source repo is refused ----------------------------------------------------------------
    Write-Host '-- 8. the repo that publishes this workflow is refused --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'source' -AsWorkflowSource
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff, '-Apply')
    Assert-Equal 1 $r.Code 'a repo publishing this workflow is refused'
    Assert-True ($r.Flat -like '*REFUSED*') 'and told why'
    foreach ($f in $ExpectedRunners) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $dir $f))) "and nothing was written ($f)"
    }
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "adopt-ci-floor.tests: $script:pass passed, $script:fail failed." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
