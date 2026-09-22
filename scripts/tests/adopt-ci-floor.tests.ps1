<#
.SYNOPSIS
    Tests for scripts/task/adopt-ci-floor.ps1 -- the CI floor a consuming repo adopts (issues
    #1516, #1546).

.DESCRIPTION
    WHY THIS SUITE EXISTS. Every property below fails SILENTLY, which is the same reason
    merge-queue-prereq.tests.ps1 exists one file over: a merge queue changes what a merge DOES, and a
    repo standing on an incomplete floor looks exactly like one standing on a complete one until the
    first merge afterwards. What is covered, and why these eight:

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
      6. the switch is never flipped -- RESHAPED FOR #1972. The subject is now whether this script
         INVOKES a write, not whether the characters '--method POST' appear anywhere in the file:
         section 1's [gap] arm now legitimately PRINTS exactly that as advice text, without ever
         running it, which is exactly what turned this assert's old shape red. The two real invocation
         sites (Invoke-NativeCapture) are held to the no-write rule, and the printed advice block is
         separately proven to be consumed only by Write-Host, never executed -- so a hypothetical real
         write anywhere else in the file, printed advice included, still trips it;
      7. a repo that publishes this workflow is refused -- the source arranges its own runners by hand,
         and they are the originals these are derived from;
      8. THE COMPOSED RULESET CALL ITSELF (#1972), since a docstring promising it for months had
         nothing measuring it before now: it is actually printed on a no-required-check trunk, the JSON
         it prints parses and targets refs/heads/<the trunk this run was told about> rather than a
         placeholder like ~DEFAULT_BRANCH, the one free choice (which check) is filled in automatically
         when exactly one pull_request job exists in the tree and left as a placeholder plus a
         candidate list otherwise, and the additive-ruleset caveat is present so a reader is not
         surprised into pasting this over an existing ruleset;
      9. THE CI SKELETON (#1843), the fourth thing this script can place and the only one that is
         conditional on more than its own file's absence: offered only when NOTHING in the tree
         triggers on pull_request at all, never merely because .github/workflows/ci.yml itself is
         missing -- a repo running CI under any other name must not be handed a second, empty
         workflow. Covered: it is offered and named in the dry-run report (and the ruleset advice
         auto-fills from it instead of the usual placeholder); -Apply places it with both triggers, a
         placeholder step, no credential and an unpinned checkout; a re-run never overwrites a
         consumer's edit; a repo that already runs CI under any name is never offered or given one;
         its job's check name follows the Get-CiTestCheckName seam when declared; and an unsafe
         declared name is refused rather than interpolated into the YAML as-is.
      10. #2248: THE REQUIRED-CHECK CONTEXT NAME IS GUARDED WHEN NOBODY OWNS IT (section 5b). $ctx is
          read off the repo's OWN ruleset JSON -- unlike a job id, GitHub's schema does not constrain
          its characters -- and df25f9f6 sent it through Get-DisplayRef before either report branch.
          This is a behavioural pin, not a spelling one: it crafts a context whose embedded newline
          would forge a second console line if the guard were dropped, and asserts on the actual
          rendered shape (one line, the control character collapsed to a space) rather than on the
          presence of 'Get-DisplayRef' in the source. It does not cover $w.Rel (the consumer's own
          workflow FILENAME, also guarded by that commit) -- see check-consumer-siblings.tests.ps1's
          own docstring for why a filename-carried deceptive character is a worse test subject than a
          JSON-carried one (console code-page decoding of a filename is not this suite's concern, but
          reaching it needs a real file on disk with a name no #2248 fixture here builds), and
          Tycho's closing report for that gap named plainly.

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
# ISSUE #2248's REGRESSION PIN. A required-check CONTEXT NAME is read off the repo's own ruleset JSON
# (Get-DirectPushBlockingRules), not off this tree, so nothing constrains its characters -- unlike a job
# id, which GitHub Actions' own schema already restricts to [a-zA-Z0-9_-]. This payload's context names
# no job in ANY fixture consumer (deliberately: "weird-check" -> `n -> "INJECTED-marker" cannot be a
# real Actions job id), so it always lands in the '[note] ... matches no job' arm -- the one where
# $ctxDisplay = Get-DisplayRef -Ref $ctx is computed before either report branch. Get-DisplayRef replaces a
# control character with a SPACE and collapses runs of spaces (unlike Format-SafePathToken, which
# deletes and welds -- see check-consumer-siblings.tests.ps1), so the embedded newline below is expected
# to survive as one joining space, not as a line break and not as nothing.
$RulesQueueOffDeceptiveContext = '[{"type":"required_status_checks","ruleset_id":7,"parameters":{"required_status_checks":[{"context":"weird-check' + "`n" + 'INJECTED-marker"}]}}]'
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
        [string]$Trunk = '',
        [string]$RepoSlug = ''
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

    if ($Trunk -or $RepoSlug) {
        New-Item -ItemType Directory -Path (Join-Path $root 'scripts') -Force | Out-Null
        $seamLines = @()
        if ($Trunk) { $seamLines += "function Get-TrunkBranchName { '$Trunk' }" }
        if ($RepoSlug) { $seamLines += "function Get-RepoName { '$RepoSlug' }" }
        [System.IO.File]::WriteAllText((Join-Path $root 'scripts\repo-config.ps1'), (($seamLines -join "`n") + "`n"))
    }
    if ($AsWorkflowSource) {
        $manifest = '{ "name": "fixture", "plugins": [ { "name": "dkj-policy", "source": "./x" } ] }'
        New-Item -ItemType Directory -Path (Join-Path $root '.claude-plugin') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $root '.claude-plugin\marketplace.json'), $manifest)
    }
    return $root
}

function New-FixtureConsumerNoCI {
    <#
        A consumer with NO workflow at all -- the state the CI skeleton (issue #1843) exists for: an
        empty .github/workflows, nothing triggering on pull_request. -CiTestCheckName declares the
        Get-CiTestCheckName seam, so the skeleton's own job name can be proven to read it rather than
        always falling back to the bare job key.
    #>
    param(
        [string]$Label,
        [string]$Trunk = '',
        [string]$CiTestCheckName = ''
    )
    $root = Join-Path $Fixture "consumer-noci-$Label"
    if (Test-Path -LiteralPath $root) { Remove-Item -Recurse -Force -LiteralPath $root }
    New-Item -ItemType Directory -Path (Join-Path $root '.github\workflows') -Force | Out-Null

    if ($Trunk -or $CiTestCheckName) {
        New-Item -ItemType Directory -Path (Join-Path $root 'scripts') -Force | Out-Null
        $seamLines = @()
        if ($Trunk) { $seamLines += "function Get-TrunkBranchName { '$Trunk' }" }
        if ($CiTestCheckName) { $seamLines += "function Get-CiTestCheckName { '$CiTestCheckName' }" }
        [System.IO.File]::WriteAllText((Join-Path $root 'scripts\repo-config.ps1'), (($seamLines -join "`n") + "`n"))
    }
    return $root
}

function Test-NoLeakedCredential {
    <#
        True when neither the FOLD_PUSH_TOKEN secret nor an issues: write grant appears on a CODE line --
        i.e. any line whose trimmed text does not start with '#'. A comment is free to name either word in
        prose (this template's own comments do, to explain why this runner needs neither); only a line that
        could actually take effect at runtime counts as the leak this exists to catch.
    #>
    param([string]$Text)
    $codeLines = ($Text -split "`r?`n") | Where-Object { $_.Trim() -notmatch '^#' }
    $code = $codeLines -join "`n"
    return (-not ($code -match '(?m)^\s*issues:\s*write\s*$')) -and (-not ($code -match 'secrets\.FOLD_PUSH_TOKEN'))
}

function Get-ComposedRulesetPayload {
    <#
        Extracts the JSON body of the paste-ready ruleset call section 1's [gap] arm prints (#1972),
        from the child's own LINE-PRESERVING output ($r.Out -- not $r.Flat, which drops every real
        newline along with the console's wrap-induced ones; JSON parses fine either way, but Out is
        what actually varies per invocation, so it is what a reader would paste too). Bounded by the
        two markers the template itself prints around the payload -- "$json = @'" and the closing
        "'@" -- so this reads what the template actually emitted rather than reconstructing it by hand.
        Returns $null when the marker pair is not found, which a caller turns into its own failed
        assert rather than an uncaught ConvertFrom-Json crashing the whole suite.
    #>
    param([string]$Out)
    $m = [regex]::Match($Out, "(?s)\`$json = @'(.*?)'@")
    if (-not $m.Success) { return $null }
    return $m.Groups[1].Value
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

# Every runner -Apply must place. Read from one list rather than restated per assert, so a target added
# to the script fails ONE list here instead of passing unexamined.
$ExpectedRunners = @(
    '.github\workflows\fold-on-merge.yml',
    '.github\workflows\verify-resolved.yml',
    '.github\workflows\repo-settings.yml'
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

    # --- 2. -Apply places every runner, pointing at the PLUGIN tree --------------------------------
    Write-Host '-- 2. -Apply places every runner, reaching their scripts through the plugin tree --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'apply'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff, '-Apply')
    foreach ($f in $ExpectedRunners) {
        Assert-True (Test-Path -LiteralPath (Join-Path $dir $f)) "-Apply placed $f"
    }
    $fold = [System.IO.File]::ReadAllText((Join-Path $dir '.github\workflows\fold-on-merge.yml'))
    $verify = [System.IO.File]::ReadAllText((Join-Path $dir '.github\workflows\verify-resolved.yml'))
    $repoSettings = [System.IO.File]::ReadAllText((Join-Path $dir '.github\workflows\repo-settings.yml'))

    # THE PATH IS THE WHOLE POINT OF THE SCAFFOLD. A runner calling 'scripts/release/...' would be the
    # SOURCE's path -- correct there, absent in every consumer -- and it would fail at the one moment
    # nobody is watching: on a push to the trunk, after a merge has already landed.
    Assert-True ($fold -like '*.workflow-scripts/plugins/dkj-policy/scripts/lint/check-unfolded-entry.ps1*') `
        'the fold runner calls the plugin mirror of check-unfolded-entry, not an in-repo path'
    Assert-True ($fold -like '*.workflow-scripts/plugins/dkj-policy/scripts/release/fold-changelog-entry.ps1*') `
        'and the plugin mirror of fold-changelog-entry'
    Assert-True ($verify -like '*.workflow-scripts/plugins/dkj-policy/scripts/release/verify-pushed-merges.ps1*') `
        'the resolves runner calls the plugin mirror of verify-pushed-merges'
    Assert-True ($repoSettings -like '*.workflow-scripts/plugins/dkj-policy/scripts/lint/check-repo-settings.ps1*') `
        'the repo-settings runner calls the plugin mirror of check-repo-settings, not an in-repo path'

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
        @{ Name = 'fold-on-merge.yml';    Text = $fold;         Expect = 2 },
        @{ Name = 'verify-resolved.yml';  Text = $verify;       Expect = 1 },
        @{ Name = 'repo-settings.yml';    Text = $repoSettings; Expect = 1 }
    )) {
        $refs = @(Get-SharedScriptReference -WorkflowText $runner.Text -RepositoryName 'dkj-claude-plugins')
        Assert-Equal $runner.Expect $refs.Count "$($runner.Name): reaches $($runner.Expect) script(s) out of a checkout of this repo"
        foreach ($judged in @(Test-SharedScriptReference -Reference $refs -SourceRoot $RepoRoot)) {
            Assert-True $judged.Exists "$($runner.Name): runs '$($judged.Path)', and that path EXISTS in this tree"
        }
    }

    # CLAUDE_PROJECT_DIR IS NOT OPTIONAL IN ANY OF THE THREE. A mirrored script resolves the tree it
    # judges from that variable first; without it a check would read whatever `git rev-parse` answered
    # in a workspace holding two checkouts, which is a coin toss rather than a bug that shows up.
    Assert-True ($fold -like '*CLAUDE_PROJECT_DIR: ${{ github.workspace }}*') `
        'the fold runner points the mirrored scripts at the consumer tree via CLAUDE_PROJECT_DIR'
    Assert-True ($verify -like '*CLAUDE_PROJECT_DIR: ${{ github.workspace }}*') `
        'and so does the resolves runner'
    Assert-True ($repoSettings -like '*CLAUDE_PROJECT_DIR: ${{ github.workspace }}*') `
        'and so does the repo-settings runner'

    # --- 2c. The repo-settings runner (issue #1843) -- a schedule, not a merge, and no secret at all ---
    Assert-True ($repoSettings -match '(?m)^\s+-\s+cron:') `
        'the repo-settings runner is scheduled -- the dated record is the whole reason it is CI and not a hook'
    Assert-True ($repoSettings -like '*workflow_dispatch*') 'and dispatchable, for the day a setting is changed on purpose'
    Assert-True ($repoSettings -match '(?m)^\s*contents:\s*read\s*$') 'least privilege: it only reads'
    # THE MATCH IS OVER CODE LINES ONLY, NOT THE WHOLE FILE. A plain substring match over the generated
    # text also fires on a COMMENT naming these words in prose -- and this template's own comments do,
    # deliberately: they explain why THIS runner, unlike the other two, needs neither credential. That
    # is accurate prose describing a fact, not a leak, and a maintainer must be free to write it without
    # tripping a red assert (measured: editing that comment forced a reword to dodge this exact line).
    # Excluding comment lines costs nothing against the real defect this assert exists to catch, because
    # a leaked permission or token has an operational effect only on a CODE line -- a `permissions:` grant
    # or a `${{ secrets.* }}` reference -- never on a `#`-prefixed one. Proven below against a
    # deliberately broken fixture rather than by inspection, per Tycho's brief.
    Assert-True (Test-NoLeakedCredential $repoSettings) `
        'it borrows no standing credential and no write scope -- unlike the other two runners (comment lines excluded)'
    # THE TIGHTENED MATCH IS PROVEN, NOT INSPECTED: run it against fixtures nothing above ever produces,
    # so passing here says something about the FUNCTION rather than about the one real template.
    Assert-True (Test-NoLeakedCredential "# mentions FOLD_PUSH_TOKEN and issues: write in prose only`npermissions:`n  contents: read`n") `
        'the tightened match ignores a comment naming both words in prose'
    Assert-True (-not (Test-NoLeakedCredential "permissions:`n  issues: write`n")) `
        'and still catches a real issues: write permission line'
    Assert-True (-not (Test-NoLeakedCredential 'token: ${{ secrets.FOLD_PUSH_TOKEN }}')) `
        'and a real FOLD_PUSH_TOKEN reference outside a comment'
    Assert-True ($repoSettings -like '*-RequireRead*') `
        'and it runs with -RequireRead, so a token that cannot read reports a failure instead of a green nothing'
    Assert-True ($repoSettings -match '(?m)^\s*persist-credentials:\s*false\s*$') `
        'its own checkout keeps no credential in the workspace -- this job never pushes'

    # THE CREDENTIAL SPLIT, which is the security decision this scaffold inherits: the standing PAT and
    # `issues: write` must never sit in one job.
    Assert-True ($fold -like '*secrets.FOLD_PUSH_TOKEN*') 'the fold runner checks out with FOLD_PUSH_TOKEN -- the default token cannot push past a merge_queue rule'
    Assert-True ($fold -notlike '*issues: write*') 'and never holds issues: write beside that standing credential'
    Assert-True ($verify -like '*issues: write*') 'the resolves runner holds issues: write, which is what makes it repair rather than report'
    Assert-True ($verify -notlike '*FOLD_PUSH_TOKEN*') 'and never touches the standing credential'
    Assert-True ($r.Flat -like '*FOLD_PUSH_TOKEN*') 'and the run TELLS you to create that secret'
    Assert-True ($r.Flat -like '*actions/checkout FAILS*') 'and says an absent/under-scoped token fails the checkout, not the push (inbound #1539)'
    Assert-True ($r.Flat -like '*every later step*skipped*') 'naming the tell -- every later step skipped -- so the checkout is ruled out first'

    # --- 2d. The reminder's NEGATIVE twin: silent when the fold runner is not the one created --------
    # Section 2 above proves the reminder FIRES when the fold runner is created (all three files fresh
    # together). That alone is only half the property this flag exists for (the fix behind #1904's
    # sibling bug: a generic "anything was created" counter would fire this reminder even when the ONLY
    # gap is repo-settings.yml, which needs no secret at all). This fixture is that other half: fold and
    # verify-resolved already exist, only repo-settings.yml is missing, and the reminder must stay silent.
    Write-Host '-- 2d. the FOLD_PUSH_TOKEN reminder stays silent when repo-settings.yml is the only gap --' -ForegroundColor Cyan
    # A DEDICATED VARIABLE, NOT $dir -- section 3 below reuses $dir from section 2's own 'apply'
    # consumer, and clobbering it here would silently redirect that later section at this fixture.
    $onlySettingsDir = New-FixtureConsumer -Label 'onlysettings'
    $foldSentinel = '# pre-existing fold runner -- not written by this run'
    $verifySentinel = '# pre-existing resolves runner -- not written by this run'
    [System.IO.File]::WriteAllText((Join-Path $onlySettingsDir '.github\workflows\fold-on-merge.yml'), $foldSentinel)
    [System.IO.File]::WriteAllText((Join-Path $onlySettingsDir '.github\workflows\verify-resolved.yml'), $verifySentinel)
    $r = Invoke-Adopt -Dir $onlySettingsDir -ScriptArgs @('-RulesJsonOverride', $rulesOff, '-Apply')
    Assert-True (Test-Path -LiteralPath (Join-Path $onlySettingsDir '.github\workflows\repo-settings.yml')) `
        'repo-settings.yml is created when it is the only one of the three missing'
    # CONTENT, NOT JUST PRESENCE OR MTIME -- the additive property (section 3) is that an edited file is
    # left BYTE-FOR-BYTE as it was, and that is what a sentinel unrelated to the real template proves.
    Assert-Equal $foldSentinel ([System.IO.File]::ReadAllText((Join-Path $onlySettingsDir '.github\workflows\fold-on-merge.yml'))) `
        'the pre-existing fold runner is untouched'
    Assert-Equal $verifySentinel ([System.IO.File]::ReadAllText((Join-Path $onlySettingsDir '.github\workflows\verify-resolved.yml'))) `
        'and so is the pre-existing resolves runner'
    Assert-True ($r.Out -match '(?m)\[exists\]\s+\.github/workflows/fold-on-merge\.yml') 'the fold runner is reported as already there, not recreated'
    Assert-True ($r.Out -match '(?m)\[exists\]\s+\.github/workflows/verify-resolved\.yml') 'and so is the resolves runner'
    Assert-True ($r.Out -match '(?m)\[created\]\s+\.github/workflows/repo-settings\.yml') 'only the actually-missing repo-settings runner is created'
    Assert-True ($r.Flat -notlike '*FOLD_PUSH_TOKEN*') `
        'and the FOLD_PUSH_TOKEN reminder does NOT fire -- the fold runner itself was not the one created, this run''s (#1843) own fix'

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
    # The checkout ref is matched as a SHA rather than as @v5 (issue #1904): this line is pinned now, and
    # an assert naming the old tag would fail for the right change. WHAT the pin must be is asserted in
    # pin-parity.tests.ps1 -- against this repo's own fold runner -- so this one only reads the ORDERING
    # it was written for, and stays out of the business of choosing a SHA.
    Assert-True ($fold -match '(?ms)uses:\s*actions/checkout@[0-9a-f]{40}[^\r\n]*\n\s*with:\s*\n\s*ref:\s*main\s*\n\s*token:\s*\$\{\{\s*secrets\.FOLD_PUSH_TOKEN') `
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
    $editedSettings = '# my own repo-settings runner'
    [System.IO.File]::WriteAllText((Join-Path $dir '.github\workflows\repo-settings.yml'), $editedSettings)
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff, '-Apply')
    Assert-Equal $editedSettings ([System.IO.File]::ReadAllText((Join-Path $dir '.github\workflows\repo-settings.yml'))) `
        'and the repo-settings runner is additive too -- an edited copy is left exactly as it is'
    Assert-True ($r.Out -match '(?m)\[exists\]\s+\.github/workflows/repo-settings\.yml') 'and reported as already there rather than silently skipped'

    # --- 4. The two vocabularies, and the exit code --------------------------------------------------
    Write-Host '-- 4. a gap on a queueless trunk is a to-do; the same gap under a live queue is a defect --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'live'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOn)
    Assert-Equal 1 $r.Code 'a queue ACTIVE with no runners in the tree exits 1'
    Assert-True ($r.Flat -like '*live defect*') 'and says why in those words'
    Assert-True ($r.Out -match '(?m)\[MISSING\]\s+\.github/workflows/fold-on-merge\.yml') 'the missing fold runner is marked MISSING rather than as a suggestion'
    # A MISSING repo-settings.yml is NOT a live defect just because a queue happens to be active
    # elsewhere in the repo -- its subject (a GitHub-side setting drifting) has nothing to do with the
    # queue, unlike the fold and the resolves verification a queue genuinely takes away.
    Assert-True ($r.Out -match '(?m)\[create\]\s+\.github/workflows/repo-settings\.yml') `
        'the missing repo-settings runner is offered as an ordinary [create], not marked MISSING, even with a queue active'

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

    # --- 5b. #2248's regression pin: a required-check context name this repo does not own is guarded --
    Write-Host '-- 5b. #2248: a deceptive required-check context name is guarded, not printed raw --' -ForegroundColor Cyan
    $rulesDeceptiveContext = New-RulesFile -Label 'deceptive-context' -Json $RulesQueueOffDeceptiveContext
    $dir = New-FixtureConsumer -Label 'deceptive-context'
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesDeceptiveContext)
    Assert-True ($r.Flat -like '*matches no job*') 'the fixture reaches the no-owner arm at all, so the asserts below are testing something'
    # $r.Out keeps real line breaks (see Invoke-Adopt's own docstring) -- the property under test is
    # exactly whether the embedded newline in $ctx survives as ANOTHER one, so Out is read, not Flat.
    # '[note]' ALSO PRINTS FOR repo-settings.yml's own schedule note AND FOR "no merge_queue rule" IN
    # AN ORDINARY DRY RUN -- neither carries a manifest- or ruleset-supplied value, so both are filtered
    # out here rather than counted; the subject is the ONE line this fixture's deceptive context produces.
    $noteLines = @($r.Out -split "`n" | Where-Object { $_ -match "\[note\].*required check" })
    Assert-True ($noteLines.Count -eq 1) `
        'the deceptive context name produces exactly ONE required-check [note] line -- its embedded newline did not forge a second'
    Assert-True ($noteLines.Count -gt 0 -and $noteLines[0] -match 'weird-check INJECTED-marker') `
        "and that one line reads the context as Get-DisplayRef renders it -- the control character replaced by a SPACE, collapsed, not deleted and not left as a literal newline"
    Assert-True (-not ($r.Flat -match 'weird-checkINJECTED')) `
        "the raw, unguarded context value never appears WELDED in the flattened report -- that shape is what a leaked newline would produce (Out split into two array elements, joined by Flat with no separator)"

    # --- 6. The trunk is read, never assumed ---------------------------------------------------------
    Write-Host '-- 6. the placed runners follow this repo trunk --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'trunk' -Trunk 'trunk'
    $null = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff, '-Apply')
    $fold = [System.IO.File]::ReadAllText((Join-Path $dir '.github\workflows\fold-on-merge.yml'))
    Assert-True ($fold.Contains('branches: [trunk]')) 'the fold runner triggers on the trunk Get-TrunkBranchName names, not on a hardcoded main'
    Assert-True ($fold -like '*-Branch trunk*') 'and passes that same trunk to the check it runs'
    Assert-True ($fold -match '(?m)^\s*ref:\s*trunk\s*$') 'and its first checkout pins ref to that same trunk, not a hardcoded main (#1543)'
    Assert-True ($fold -match '(?m)^\s*group:\s*fold-on-merge-\$\{\{\s*github\.ref\s*\}\}\s*$') 'the concurrency group is still github.ref-keyed on a non-main trunk (#1544)'
    $repoSettings = [System.IO.File]::ReadAllText((Join-Path $dir '.github\workflows\repo-settings.yml'))
    Assert-True ($repoSettings -like '*-Trunk trunk*') `
        'the repo-settings runner is baked with the same non-main trunk (issue #1843), not a hardcoded main'

    # --- 7. The switch is composed, never pulled -----------------------------------------------------
    Write-Host '-- 7. the setting itself is the owner act, and this script does not make it --' -ForegroundColor Cyan
    $src = [System.IO.File]::ReadAllText($Script)

    # RESHAPED FOR #1972. The subject is now "does this script INVOKE a write", not "do these characters
    # appear anywhere in the file" -- because section 1's [gap] arm now legitimately PRINTS a
    # '--method POST' ruleset call as advice text (issue #1972), without ever running it. The naive
    # substring form of this guard went red on exactly that the day it landed: it could not tell a
    # printed literal from an invocation, and the finding was real -- see the CLOSE below for why it is
    # not simply loosened.
    #
    # THE ADVICE BLOCK ($rulesetLines) IS CARVED OUT ONLY AFTER IT IS PROVEN INERT, not merely assumed
    # so -- the two asserts right after the carve-out show every reference to that array is a
    # Write-Host, so the carve-out cannot hide a real invocation lurking under the same variable name.
    $rulesetLinesBlock = [regex]::Match($src, '(?ms)^\s*\$rulesetLines\s*=\s*@\(.*?^\s*\)\s*$')
    Assert-True $rulesetLinesBlock.Success `
        'the printed ruleset advice block ($rulesetLines) is found at all -- so the carve-out below has something to carve out'
    $srcOutsideAdvice = $src.Remove($rulesetLinesBlock.Index, $rulesetLinesBlock.Length)

    # PROVING THE CARVE-OUT IS SAFE. $rulesetLines is referenced exactly twice in the whole script: its
    # own assignment (just matched above) and the foreach loop that Write-Hosts it. A THIRD reference --
    # a pipe to gh, an Invoke-Expression, anything that would EXECUTE the block instead of merely
    # printing it -- would show up as a third match and fail this count. That is deliberately not "and
    # no Invoke-Expression exists anywhere", which would only be as strong as the list of banned verbs
    # this suite happened to think of; counting references to the one variable the advice text lives in
    # does not depend on guessing every way PowerShell can run a command.
    $rulesetLinesRefs = [regex]::Matches($src, '\$rulesetLines\b')
    Assert-Equal 2 $rulesetLinesRefs.Count `
        '$rulesetLines is referenced exactly twice -- its assignment and the loop that prints it; a third reference would mean something besides Write-Host consumes it'

    # THE SECOND REFERENCE MUST BE THE *WHOLE* STATEMENT, ANCHORED, NOT A PREFIX (review finding, Victor
    # #19). A PREFIX match -- '...\{\s*Write-Host \$ln', with nothing requiring the brace to close right
    # there -- still matches after 'foreach ($ln in $rulesetLines) { Write-Host $ln -ForegroundColor
    # DarkGray; Invoke-Expression $ln }': the appended call sits AFTER the substring the old regex
    # looked for, so it read as a pass while quietly executing every printed line. Proven below against
    # exactly that mutation, both ways.
    $foreachExpected = 'Write-Host $ln -ForegroundColor DarkGray'
    function Test-ForeachIsExactlyOneWriteHost {
        # The WHOLE foreach line, brace to brace: the body is captured with a character class that
        # excludes braces, so a line ending in an unbalanced '{' inside the appended text (rather than a
        # bare statement) makes the match fail outright instead of silently swallowing it -- either way
        # the tamper is caught, by one assert or the other.
        param([string]$Text)
        $m = [regex]::Match($Text, '(?m)^\s*foreach\s*\(\$ln in \$rulesetLines\)\s*\{(?<body>[^{}]*)\}\s*$')
        if (-not $m.Success) { return $false }
        return ($m.Groups['body'].Value.Trim() -eq $foreachExpected)
    }
    Assert-True (Test-ForeachIsExactlyOneWriteHost $src) `
        'and that second reference is EXACTLY one Write-Host statement, brace to brace -- nothing appended after it on the same line'

    # THE OLD REGEX'S OWN BLIND SPOT, DEMONSTRATED RATHER THAN ASSERTED AWAY: append a real invocation to
    # the same line and confirm the unanchored prefix form still matches it, before checking the anchored
    # form no longer does.
    $foreachHostileLine = 'foreach ($ln in $rulesetLines) { Write-Host $ln -ForegroundColor DarkGray; Invoke-Expression $ln }'
    $foreachLineMatch = [regex]::Match($src, '(?m)^\s*(foreach\s*\(\$ln in \$rulesetLines\)[^\r\n]*)$')
    Assert-True $foreachLineMatch.Success 'the foreach line is found at all, so the hostile-mutation proof below has something to mutate'
    $srcForeachHostile = $src
    if ($foreachLineMatch.Success) {
        $srcForeachHostile = $src.Remove($foreachLineMatch.Groups[1].Index, $foreachLineMatch.Groups[1].Length).Insert(
            $foreachLineMatch.Groups[1].Index, $foreachHostileLine)
    }
    Assert-True ($srcForeachHostile -match '(?m)foreach\s*\(\$ln in \$rulesetLines\)\s*\{\s*Write-Host \$ln') `
        'PROOF: the OLD unanchored prefix regex still matches the hostile line (Invoke-Expression appended) -- this is the gap Victor found'
    Assert-True (-not (Test-ForeachIsExactlyOneWriteHost $srcForeachHostile)) `
        'PROOF: the NEW anchored assert catches that same hostile line -- the body is no longer exactly one Write-Host statement'

    # --- Sebastian's finding: the carve-out proves nothing about what runs when the array is BUILT -----
    # @( ... ) is a real PowerShell expression: an element written as $(Invoke-NativeCapture ...), or a
    # $(...) subexpression embedded INSIDE an interpolated string element, executes the moment the array
    # is BUILT -- regardless of whether the value is ever printed -- and adds no textual reference to
    # $rulesetLines, so the reference-count proof above cannot see it either way. Proven with the actual
    # PowerShell parser (not a regex), because this is exactly the syntax question the parser exists to
    # answer and a regex can only approximate: every element must be a string literal (plain or
    # interpolated), and an interpolated element's own nested pieces must be plain variable reads, never
    # a subexpression.
    $adviceTokens = $null
    $adviceParseErrors = $null
    $adviceAst = [System.Management.Automation.Language.Parser]::ParseInput(
        $rulesetLinesBlock.Value, [ref]$adviceTokens, [ref]$adviceParseErrors)
    Assert-Equal 0 $adviceParseErrors.Count 'the carved-out advice block parses as valid, self-contained PowerShell (a prerequisite for inspecting what is inside it)'
    $adviceArrayAst = $adviceAst.Find({ param($n) $n -is [System.Management.Automation.Language.ArrayLiteralAst] }, $true)
    Assert-True ($null -ne $adviceArrayAst) 'the array literal inside the advice block is found by the parser'
    if ($adviceArrayAst) {
        $adviceElements = @($adviceArrayAst.Elements)
        Assert-True ($adviceElements.Count -gt 0) 'and it has elements to check'

        function Test-RulesetLinesElementsAreLiteral {
            # The property Sebastian named: "these elements are literals", checked structurally rather
            # than by pattern -- a StringConstantExpressionAst (a plain '...' string) or an
            # ExpandableStringExpressionAst (a "..." string) whose OWN NestedExpressions are nothing but
            # VariableExpressionAst (a bare $var read, which only substitutes an already-computed value
            # and cannot execute anything new). Anything else -- a bare command, a $(...) subexpression
            # as a top-level element, or one embedded inside a string -- fails this.
            param([System.Management.Automation.Language.ArrayLiteralAst]$ArrayAst)
            $elements = @($ArrayAst.Elements)
            $nonLiteral = @($elements | Where-Object {
                $_ -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -and
                $_ -isnot [System.Management.Automation.Language.ExpandableStringExpressionAst]
            })
            if ($nonLiteral.Count -gt 0) { return $false }
            $badNested = @($elements | Where-Object { $_ -is [System.Management.Automation.Language.ExpandableStringExpressionAst] } |
                ForEach-Object { $_.NestedExpressions } |
                Where-Object { $_ -isnot [System.Management.Automation.Language.VariableExpressionAst] })
            return ($badNested.Count -eq 0)
        }
        Assert-True (Test-RulesetLinesElementsAreLiteral $adviceArrayAst) `
            'every element of the advice array is a string literal (plain or interpolated by bare variable read) -- never a bare command, and never a $(...) subexpression'

        # PROOF, HOSTILE EDIT 1: a bare $(...) subexpression as a top-level array element (Sebastian's
        # own example). The reference-count proof above cannot see this at all -- it adds no textual
        # '$rulesetLines' anywhere -- which is exactly the blind spot being closed here.
        $hostileElementText = $rulesetLinesBlock.Value.Replace(
            "'{',",
            "'{', `$(Invoke-NativeCapture -FilePath 'gh' -Arguments @('api','--method','POST')),")
        Assert-True ($hostileElementText -ne $rulesetLinesBlock.Value) 'PROOF SETUP: hostile-edit-1 text actually differs from the original (the anchor text was found)'
        $hostileAst1 = [System.Management.Automation.Language.Parser]::ParseInput($hostileElementText, [ref]$null, [ref]$null)
        $hostileArrayAst1 = $hostileAst1.Find({ param($n) $n -is [System.Management.Automation.Language.ArrayLiteralAst] }, $true)
        Assert-True ($hostileArrayAst1 -and (@([regex]::Matches($hostileElementText, '\$rulesetLines\b')).Count -eq 1)) `
            'PROOF: hostile-edit-1 leaves the $rulesetLines reference count at its ORIGINAL value (1, inside this isolated block) -- a pure reference count cannot see this mutation at all'
        Assert-True (-not (Test-RulesetLinesElementsAreLiteral $hostileArrayAst1)) `
            'PROOF: the NEW literal-elements assert catches hostile-edit-1 -- a bare command/subexpression element is not a string literal'

        # PROOF, HOSTILE EDIT 2: the same subexpression, embedded INSIDE a double-quoted string element
        # rather than as a bare element. This is the harder case: PowerShell's own legacy tokenizer
        # (PSParser) reads the WHOLE interpolated string as one opaque token here and does not surface
        # the embedded command at all -- only the full AST parser's NestedExpressions breaks it back
        # apart, which is why this assert is built on the AST and not on tokens or on a regex.
        $hostileElementText2 = $rulesetLinesBlock.Value.Replace(
            '"  ""name"": ""require $rulesetContext on $rulesetTrunk"",",',
            '"  ""name"": ""require $(Invoke-NativeCapture -FilePath ''gh'' -Arguments @(''api'')) on $rulesetTrunk"",",')
        Assert-True ($hostileElementText2 -ne $rulesetLinesBlock.Value) 'PROOF SETUP: hostile-edit-2 text actually differs from the original (the anchor text was found)'
        $hostileAst2 = [System.Management.Automation.Language.Parser]::ParseInput($hostileElementText2, [ref]$null, [ref]$null)
        $hostileArrayAst2 = $hostileAst2.Find({ param($n) $n -is [System.Management.Automation.Language.ArrayLiteralAst] }, $true)
        Assert-True ($null -ne $hostileArrayAst2) 'PROOF SETUP: hostile-edit-2 still parses as an array literal (the mutation is syntactically legal PowerShell, which is the whole danger)'
        if ($hostileArrayAst2) {
            Assert-True (-not (Test-RulesetLinesElementsAreLiteral $hostileArrayAst2)) `
                'PROOF: the NEW literal-elements assert catches hostile-edit-2 -- a $(...) subexpression embedded inside an interpolated string is not a plain variable read'
        }
    }

    # THE ACTUAL GUARD, NOW OVER PROVEN-EXECUTABLE TEXT ONLY. A hypothetical real write --
    # Invoke-NativeCapture -FilePath 'gh' -Arguments @('api', '--method', 'POST', ...), or a
    # 'gh api --method POST' typed anywhere outside the proven-inert advice block above -- still trips
    # every one of these three, exactly as before #1972.
    Assert-True ($srcOutsideAdvice -notmatch "'-X'\s*,\s*'(PUT|POST|PATCH|DELETE)'") 'no gh api call in this script carries a write method'
    Assert-True ($srcOutsideAdvice -notmatch "--method\s+(PUT|POST|PATCH|DELETE)") `
        'and none carries one in the long spelling either, outside the proven-inert printed advice text'
    Assert-True ($srcOutsideAdvice -notmatch "'api'[^\r\n]*rulesets") 'and it never addresses the rulesets collection directly, which is the endpoint that creates one'

    # THE TWO REAL INVOCATION SITES IN THIS SCRIPT, NAMED RATHER THAN LEFT TO THE GUARD ABOVE TO FIND BY
    # ACCIDENT: both calls this script actually makes are Invoke-NativeCapture, and both are reads (a
    # repo lookup, and a GET of the trunk's rules). If either ever grows a write, it fails the assert
    # above (it is not inside the carved-out advice block) -- this pair just makes the claim legible
    # rather than only provable.
    $nativeCalls = @([regex]::Matches($srcOutsideAdvice, '(?m)^.*Invoke-NativeCapture\b.*$') | ForEach-Object { $_.Value })
    Assert-Equal 2 $nativeCalls.Count 'this script makes exactly two native calls (a repo lookup and a rules GET), both outside the advice block'
    foreach ($call in $nativeCalls) {
        Assert-True ($call -notmatch '(PUT|POST|PATCH|DELETE)') "native call carries no write method: $call"
    }

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

    # --- 7c. The composed ruleset call itself (#1972) -------------------------------------------------
    # The docstring promised this call for months (issues #1516/#1546) before #1972 made section 1's
    # [gap] arm actually print it -- and nothing measured that it did. These asserts are the regression:
    # what #1972 bought is exactly what would silently stop being true if a later edit turned the arm
    # back into a bare pointer.
    Write-Host '-- 7c. the composed ruleset call itself (#1972) --' -ForegroundColor Cyan
    Assert-True ($r.Flat -like '*gh api --method POST*') `
        'the composed call is actually PRINTED on a no-required-check trunk -- the regression this section exists to catch'
    Assert-True ($r.Flat -like '*<owner>/<repo>*') 'with no Get-RepoName seam answered in this fixture, the slug prints as the honest placeholder'
    Assert-True ($r.Flat -like '*COULD NOT BE RESOLVED*') 'and says so explicitly, rather than silently guessing a slug'
    Assert-True ($r.Flat -like "*the one candidate job, 'lint-en-tests', is already filled in*") `
        'the single pull_request job in this fixture''s tree is filled in automatically, not left as a placeholder'
    Assert-True ($r.Flat -notlike '*REPLACE-WITH-A-JOB-ID-BELOW*') 'so the placeholder text never appears when exactly one candidate exists'
    Assert-True ($r.Flat -notlike '*CANDIDATE CHECKS*') 'and the candidate list is not printed either -- there is nothing to choose between'
    Assert-True ($r.Flat -like '*RULESETS LAYER*') 'the additive-ruleset caveat is present -- a second ruleset layers rather than silently replacing an existing one'

    # THE PAYLOAD ITSELF: valid JSON, targeting refs/heads/<the trunk this run was told about>, not a
    # placeholder like ~DEFAULT_BRANCH.
    $rulesetJsonText = Get-ComposedRulesetPayload -Out $r.Out
    Assert-True ($null -ne $rulesetJsonText) 'the printed advice carries a JSON payload marked off by @''...''@ at all'
    $rulesetJsonParsed = $null
    if ($rulesetJsonText) {
        try { $rulesetJsonParsed = $rulesetJsonText | ConvertFrom-Json } catch { $rulesetJsonParsed = $null }
    }
    Assert-True ($null -ne $rulesetJsonParsed) 'and that payload is valid JSON'
    if ($rulesetJsonParsed) {
        Assert-True (@($rulesetJsonParsed.conditions.ref_name.include) -contains 'refs/heads/main') `
            'and it targets refs/heads/main -- the trunk THIS run was told about (via the default seam), not a hardcoded value'
        Assert-True ($rulesetJsonText -notlike '*~DEFAULT_BRANCH*') 'and never falls back to the ~DEFAULT_BRANCH placeholder'
        Assert-Equal 'lint-en-tests' $rulesetJsonParsed.rules[0].parameters.required_status_checks[0].context `
            'and names the one candidate job as the required check context'
    }

    # THE TRUNK IS READ, NOT HARDCODED (same property as section 6, applied to the payload): a fixture
    # naming a non-main trunk must produce refs/heads/<that trunk>, never refs/heads/main.
    $trunkDir = New-FixtureConsumer -Label 'gap-trunk' -Trunk 'develop'
    $rTrunk = Invoke-Adopt -Dir $trunkDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks)
    $trunkJsonText = Get-ComposedRulesetPayload -Out $rTrunk.Out
    $trunkJsonParsed = $null
    if ($trunkJsonText) {
        try { $trunkJsonParsed = $trunkJsonText | ConvertFrom-Json } catch { $trunkJsonParsed = $null }
    }
    Assert-True ($null -ne $trunkJsonParsed) 'on a non-main trunk the printed payload is still valid JSON'
    if ($trunkJsonParsed) {
        Assert-True (@($trunkJsonParsed.conditions.ref_name.include) -contains 'refs/heads/develop') `
            'and targets refs/heads/develop -- the Get-TrunkBranchName seam''s answer, not a hardcoded main'
        Assert-True (-not (@($trunkJsonParsed.conditions.ref_name.include) -contains 'refs/heads/main')) `
            'and does not fall back to refs/heads/main on a repo that renamed its trunk'
    }

    # THE REPO SLUG, WHEN THE SEAM ANSWERS IT: no placeholder, no "could not be resolved" line, and the
    # actual slug appears in the composed call.
    $slugDir = New-FixtureConsumer -Label 'gap-slug' -RepoSlug 'acme-corp/example-repo'
    $rSlug = Invoke-Adopt -Dir $slugDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks)
    Assert-True ($rSlug.Flat -like '*acme-corp/example-repo*') 'with Get-RepoName answered, the resolved slug appears in the composed call'
    Assert-True ($rSlug.Flat -notlike '*<owner>/<repo>*') 'and the placeholder is not printed instead'
    Assert-True ($rSlug.Flat -notlike '*COULD NOT BE RESOLVED*') 'nor the could-not-be-resolved line'

    # THE AMBIGUOUS CASE: two candidate jobs in the tree leave the context an explicit placeholder and
    # print every candidate, rather than guessing which one the merge should wait on.
    $ambiguousDir = New-FixtureConsumer -Label 'gap-ambiguous'
    $extraWorkflow = @(
        'name: Extra',
        'on:',
        '  pull_request:',
        '    branches: [main]',
        'jobs:',
        '  extra-check:',
        '    runs-on: ubuntu-latest',
        '    steps:',
        '      - run: echo hi'
    ) -join "`n"
    [System.IO.File]::WriteAllText((Join-Path $ambiguousDir '.github\workflows\extra.yml'), $extraWorkflow + "`n")
    $rAmbiguous = Invoke-Adopt -Dir $ambiguousDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks)
    Assert-True ($rAmbiguous.Flat -like '*REPLACE-WITH-A-JOB-ID-BELOW*') `
        'two candidate jobs in the tree: the context is left as an explicit placeholder, not guessed'
    Assert-True ($rAmbiguous.Flat -like '*CANDIDATE CHECKS*') 'and the candidate list header is printed'
    Assert-True ($rAmbiguous.Flat -like '*extra-check -- from*') 'naming the second candidate job and the workflow it comes from'
    Assert-True ($rAmbiguous.Flat -like '*lint-en-tests -- from*') `
        'and the first, so picking one is a copy from the list rather than a hunt through .github/workflows/'

    # --- 8. The source repo is refused ----------------------------------------------------------------
    Write-Host '-- 8. the repo that publishes this workflow is refused --' -ForegroundColor Cyan
    $dir = New-FixtureConsumer -Label 'source' -AsWorkflowSource
    $r = Invoke-Adopt -Dir $dir -ScriptArgs @('-RulesJsonOverride', $rulesOff, '-Apply')
    Assert-Equal 1 $r.Code 'a repo publishing this workflow is refused'
    Assert-True ($r.Flat -like '*REFUSED*') 'and told why'
    foreach ($f in $ExpectedRunners) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $dir $f))) "and nothing was written ($f)"
    }

    # --- 9. The CI skeleton, for a consumer with no pull_request workflow at all (issue #1843) --------
    Write-Host '-- 9. the CI skeleton: offered only when nothing triggers on pull_request at all --' -ForegroundColor Cyan

    # 9a. Dry run: reported, nothing written, and the ruleset advice auto-fills from the skeleton's own
    #     (not-yet-existing) check name rather than leaving the usual placeholder.
    $noCiDir = New-FixtureConsumerNoCI -Label 'dry'
    $rNoCi = Invoke-Adopt -Dir $noCiDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks)
    Assert-True ($rNoCi.Flat -like '*NOTHING IN THIS TREE TRIGGERS ON pull_request AT ALL*') `
        'a repo with no PR-triggering workflow at all is told the skeleton will be offered'
    Assert-True ($rNoCi.Flat -like '*ci.yml*') 'and named by its path'
    Assert-True (-not ($rNoCi.Flat -like '*REPLACE-WITH-A-JOB-ID-BELOW*')) `
        'the ruleset advice auto-fills from the skeleton instead of falling back to the placeholder'
    Assert-True ($rNoCi.Flat -like "*'ci'*") "and names the skeleton's default job key 'ci' as the check"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $noCiDir '.github\workflows\ci.yml'))) `
        'the dry run still writes nothing'

    # 9b. -Apply places it: pull_request AND merge_group, contents: read only, an unpinned checkout, and
    #     no credential -- the same hygiene the repo-settings runner is held to.
    $noCiApplyDir = New-FixtureConsumerNoCI -Label 'apply'
    Invoke-Adopt -Dir $noCiApplyDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks, '-Apply') | Out-Null
    $ciSkeletonPath = Join-Path $noCiApplyDir '.github\workflows\ci.yml'
    Assert-True (Test-Path -LiteralPath $ciSkeletonPath) '-Apply placed .github/workflows/ci.yml'
    $ciSkeleton = [System.IO.File]::ReadAllText($ciSkeletonPath)
    Assert-True ($ciSkeleton -match '(?m)^\s+pull_request:\s*$') 'it triggers on pull_request'
    Assert-True ($ciSkeleton -match '(?m)^\s+merge_group:\s*$') `
        'and on merge_group too, even with no queue -- inert today, an outage to add later otherwise (#1325)'
    Assert-True ($ciSkeleton -match '(?m)^\s*contents:\s*read\s*$') 'least privilege: it only reads'
    Assert-True (Test-NoLeakedCredential $ciSkeleton) 'it borrows no standing credential and no write scope'
    Assert-True ($ciSkeleton -match '(?m)^\s+-\s+uses:\s+actions/checkout@v5\s*$') `
        'its checkout is unpinned, like repo-settings.yml -- this job never holds a credential worth pinning'
    Assert-True ($ciSkeleton -match '(?m)^\s+name:\s+"ci"\s*$') `
        "with no Get-CiTestCheckName seam declared, the job's check name falls back to the bare key 'ci'"
    Assert-True ($ciSkeleton -like '*TODO*') 'the one step is a clearly marked placeholder, not a real check'

    # 9c. Left exactly as it is on a re-run -- strictly additive, same as every other target here.
    [System.IO.File]::WriteAllText($ciSkeletonPath, "# edited by the consumer`n" + $ciSkeleton)
    Invoke-Adopt -Dir $noCiApplyDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks, '-Apply') | Out-Null
    Assert-True (([System.IO.File]::ReadAllText($ciSkeletonPath)) -like '*edited by the consumer*') `
        're-running -Apply never overwrites a ci.yml the consumer has already edited'

    # 9d. Never offered when the tree already has a real pull_request workflow, whatever it is named --
    #     the fixture every other section in this suite already uses (New-FixtureConsumer's own ci.yml,
    #     job 'lint-en-tests') is exactly that case, and its ci.yml is left untouched by -Apply --
    #     proving this isn't merely "the file already exists" but "something already triggers".
    $hasCiDir = New-FixtureConsumer -Label 'has-ci-already'
    $rHasCi = Invoke-Adopt -Dir $hasCiDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks)
    Assert-True (-not ($rHasCi.Flat -like '*NOTHING IN THIS TREE TRIGGERS ON pull_request AT ALL*')) `
        'a repo that already runs a pull_request workflow under any name is never offered a second, empty one'
    Invoke-Adopt -Dir $hasCiDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks, '-Apply') | Out-Null
    $untouchedCi = [System.IO.File]::ReadAllText((Join-Path $hasCiDir '.github\workflows\ci.yml'))
    Assert-True ($untouchedCi -like '*lint-en-tests*') 'its existing ci.yml is left exactly as it was'
    Assert-True (-not ($untouchedCi -like '*TODO (issue #1843 template)*')) `
        'and -Apply never overwrites it with the skeleton'

    # 9e. The job's check name follows the Get-CiTestCheckName seam when the repo has declared one --
    #     the same seam open-pr's own local-gate-skip logic reads (#1715) -- so the two never need
    #     reconciling by hand.
    $namedDir = New-FixtureConsumerNoCI -Label 'named' -CiTestCheckName 'build-and-test'
    Invoke-Adopt -Dir $namedDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks, '-Apply') | Out-Null
    $namedSkeleton = [System.IO.File]::ReadAllText((Join-Path $namedDir '.github\workflows\ci.yml'))
    Assert-True ($namedSkeleton -match '(?m)^\s+name:\s+"build-and-test"\s*$') `
        'a declared Get-CiTestCheckName names the skeleton''s job, rather than the bare key'

    # 9f. An unsafe declared name (would break the YAML double-quoted scalar) falls back to the bare key
    #     rather than being interpolated as-is -- refuse, do not escape, the same posture #1972 already
    #     settled for the JSON case.
    $unsafeDir = New-FixtureConsumerNoCI -Label 'unsafe-name' -CiTestCheckName 'build "release"'
    Invoke-Adopt -Dir $unsafeDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks, '-Apply') | Out-Null
    $unsafeSkeleton = [System.IO.File]::ReadAllText((Join-Path $unsafeDir '.github\workflows\ci.yml'))
    Assert-True ($unsafeSkeleton -match '(?m)^\s+name:\s+"ci"\s*$') `
        'an unsafe declared check name (a literal double quote) is refused rather than interpolated, falling back to ''ci'''

    # 9g. A literal backslash is refused the same way (Sebastian's security review on #1843: 9f alone
    #     only proved the '"' half of Test-QuotedScalarSafe's two-character check).
    $backslashDir = New-FixtureConsumerNoCI -Label 'unsafe-backslash' -CiTestCheckName 'build\release'
    Invoke-Adopt -Dir $backslashDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks, '-Apply') | Out-Null
    $backslashSkeleton = [System.IO.File]::ReadAllText((Join-Path $backslashDir '.github\workflows\ci.yml'))
    Assert-True ($backslashSkeleton -match '(?m)^\s+name:\s+"ci"\s*$') `
        'an unsafe declared check name (a literal backslash) is refused too, falling back to ''ci'''

    # 9h. An embedded control character (here, a bare newline) is refused via the Get-DisplayRef
    #     round-trip -- the half of Test-QuotedScalarSafe that would otherwise let a declared name inject
    #     an extra line into the generated YAML rather than merely widen one quoted scalar.
    $controlDir = New-FixtureConsumerNoCI -Label 'unsafe-control' -CiTestCheckName "build`nrelease"
    Invoke-Adopt -Dir $controlDir -ScriptArgs @('-RulesJsonOverride', $rulesOffNoChecks, '-Apply') | Out-Null
    $controlSkeleton = [System.IO.File]::ReadAllText((Join-Path $controlDir '.github\workflows\ci.yml'))
    Assert-True ($controlSkeleton -match '(?m)^\s+name:\s+"ci"\s*$') `
        'an unsafe declared check name (an embedded newline) is refused too, falling back to ''ci'''
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "adopt-ci-floor.tests: $script:pass passed, $script:fail failed." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
