<#
.SYNOPSIS
    PostToolUse hook: publish a progress record for a BACKGROUNDED shell call, so the statusline shows a
    run this session cannot see -- issue #2104.

.DESCRIPTION
    WHAT #2101 LEFT OPEN. The bar covers the two long runs this workflow OWNS -- the test gate's lane
    events and ship-pr's CI wait -- because each publishes to run-progress-lib from inside its own
    process. A backgrounded `npm test`, a `gh run watch`, a long clone: nobody publishes, so the
    statusline stays on its context line while the session is in fact busy. #2101 asked for a bar for
    ANYTHING running out of sight; this is the rest of that.

    THE THREE THINGS #2104 ASKED TO HAVE MEASURED FIRST, measured on Claude Code 2.1.276 with a probe
    hook and a foreground control call (18 September 2026):

      1. PostToolUse fires at CALL-RETURN for a backgrounded call -- 363 ms after PreToolUse, with 24.6 s
         of a `sleep 25` still to run, and the payload's own duration_ms is 13. So this hook cannot
         bracket the run: it is told the run STARTED and is never told it ended.
      2. NOTHING tells it the run ended. TaskCreated and TaskCompleted are real hook events -- the
         binary carries executeTaskCreatedHooks and executeTaskCompletedHooks, and both sit in its
         event enum -- but neither fired once across two backgrounded runs; they belong to the
         agent/teammate task surface. Nor is there state to poll: the session's tasks/ directory holds
         <backgroundTaskId>.output and nothing else, no status or metadata file.
      3. The cost objection in #2104 is weaker than filed. The matcher already carries TWO hooks
         (guard-working-copy here, guard-live-theme in the shopify plugin), so this is a third rather
         than a second; and hooks on one event run in PARALLEL, so the marginal wall-clock is roughly
         zero rather than a doubling. That also removes most of the argument for folding this into
         guard-working-copy.ps1, which would have made one hook do two jobs.

    SO THE RECORD IS ATTRIBUTED TO THE SHELL, NOT TO THIS HOOK, and that is the whole design. The
    liveness test in run-progress-lib is the WRITER'S PROCESS -- pid plus that process's start time --
    and this hook lives about 400 ms. A record under its own pid would be reaped by the next statusline
    read two seconds later, so the hook cannot be the writer. Measured: the backgrounded command's own
    shell IS visible at PostToolUse time -- a bash.exe parented by the Claude Code process, 829 ms old,
    found by one Win32_Process query. Naming THAT pid as the writer makes the existing liveness test do
    the entire job: the bar shows while the shell lives and disappears within two seconds of it exiting.

    WHICH IS WHY THERE IS NO Complete-RunProgress ANYWHERE IN THIS FILE. There is no event at which to
    call it, and there does not need to be -- the reaper already removes a record whose writer is gone.
    A hook that cannot see the end of the run it describes is exactly the case run-progress-lib's
    liveness test was built for.

    THE QUERY IS PAID ONLY ON A BACKGROUNDED CALL. The pre-gate below is a raw-string test, asked
    before any JSON parse and before the lib is loaded -- guard-working-copy.ps1's own shape and for its
    own measured reason: this fires on EVERY Bash and PowerShell call, and the overwhelming majority are
    not backgrounded. Those pay the bare `powershell` launch and nothing else.

    GUARDED, SO IT IS INERT IN A CONSUMER. run-progress-lib.ps1 is source-repo only today (#2103): the
    lib, the statusline command and the settings key are all unmirrored, and #2103 still has an open
    judgement about what to do where a consumer already has a statusLine of its own. So this resolves
    the lib from the repo root and publishes nothing when it is not there -- the same shape
    native-capture-lib already uses to stay byte-identical to its two plugin mirrors. When #2103 mirrors
    the lib this hook starts working in a consumer with no change here, which is the point of resolving
    rather than hard-coding.

    ALWAYS EXITS 0, and never 2. Exit 2 on PostToolUse feeds stderr back to Claude; there is nothing
    here worth saying to it, and a hook that fails a tool call in order to draw a progress bar has its
    priorities backwards. Every failure path is silent.

    Pure ASCII (repo convention for .ps1, check 27). Tested by
    scripts/tests/publish-background-run.tests.ps1 in the source repo -- change one, run the other.
#>
$ErrorActionPreference = 'SilentlyContinue'

# THE CHEAP PRE-GATE, a raw string test before anything is parsed or loaded. A payload for a
# backgrounded call always carries this key literally; a command whose own text happens to contain the
# string merely costs a JSON parse that is then thrown away. The direction of the imprecision is the
# safe one -- it can only make this hook do MORE work, never less.
$raw = ''
try { if ([Console]::IsInputRedirected) { $raw = [Console]::In.ReadToEnd() } } catch { exit 0 }
if ($raw -notmatch '"run_in_background"\s*:\s*true') { exit 0 }

try {
    # $PSScriptRoot-relative, so it resolves the same in the source tree and in the plugin mirror --
    # guard-working-copy.ps1's own spelling, and the reason this lib is a mirrored pair.
    . (Join-Path $PSScriptRoot '..\scripts\lib\background-run-lib.ps1')

    $plan = Get-BackgroundRunPublishPlan -Payload $raw
    if (-not $plan.ShouldPublish) { exit 0 }

    $lib = Join-Path $plan.RepoRoot 'scripts\lib\run-progress-lib.ps1'
    if (-not (Test-Path -LiteralPath $lib -PathType Leaf)) { exit 0 }
    . $lib

    # THE SHELL, not this hook. Resolved here rather than in the lib because it is the one step that
    # touches the live machine; everything the lib does is a pure function of the payload, which is what
    # lets the suite drive this whole decision without a process or a CIM query.
    $shellPid = Get-BackgroundShellProcessId -CommandText $plan.Command -SelfPid $PID
    # NO SHELL FOUND MEANS NO RECORD, deliberately. A bar attributed to a process that is not the run
    # either vanishes at the next read or outlives the run entirely, and both are worse than the absence
    # of a bar -- which is this mechanism's own documented degradation everywhere else.
    if ($shellPid -le 0) { exit 0 }

    [void](Write-RunProgress -Id (Get-RunProgressId -Name $plan.Name -ProcessId $shellPid) `
        -Label $plan.Label -Note $plan.Note -WriterPid $shellPid)
} catch { }

exit 0
