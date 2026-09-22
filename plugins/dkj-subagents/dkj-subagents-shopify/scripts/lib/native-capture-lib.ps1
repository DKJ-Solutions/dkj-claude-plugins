<#
.SYNOPSIS
    Shared helper to run a native command safely and capture its output + exit code (single source
    of truth, issue #114 item 1).

.DESCRIPTION
    Dot-source this file from a sibling of the script that needs it, relative to $PSScriptRoot (NOT
    $repoRoot) -- like scripts/lib/check-report-lib.ps1 and unlike scripts/repo-config.ps1 /
    scripts/lib/branch-info.ps1, this lib is not repo-owned, so it does not need a consumer-side
    scaffold. It travels as part of the SAME plugin/mirror payload as its callers (registered in
    scripts/lib/shared-scripts-lib.ps1), so a $PSScriptRoot-relative path resolves correctly whether
    the caller runs from the workshop root, a consumer's plugin cache, or the plugin mirror tree:

        . (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')   -- from scripts/release/*

    Why this exists (the #96/#97/#107 lesson, in one place):
      Windows PowerShell 5.1 promotes a native command's stderr lines to a TERMINATING
      NativeCommandError when $ErrorActionPreference is 'Stop'. A command that writes progress to
      stderr -- git push's 'remote:' lines, gh's status/URL lines -- would then kill the script
      BEFORE its $LASTEXITCODE could be judged, even when the command itself returned exit 0. The
      lesson: never rely on stderr-as-error, always on $LASTEXITCODE. This helper centralizes the
      save-EAP -> Continue -> run -> record $LASTEXITCODE -> restore dance so that reasoning lives
      in exactly one tested place instead of being re-derived at every call site.

    The native command runs INSIDE this function's own scope, where EAP is set to 'Continue'. That
    is deliberate: a scriptblock passed in by the caller would keep the caller's script scope (where
    EAP is usually 'Stop') as its resolution scope, so an EAP override here would not reach it --
    passing FilePath/Arguments and invoking here is what makes the guard actually take effect.

    THE SECOND GUARD, AND WHY IT BELONGS HERE TOO: THE CHILD RUNS NON-INTERACTIVELY (inbound #1179,
    September 1, 2026). Every git and gh call the workflow scripts make comes through this one
    function, and not one of them runs anywhere a human can answer a prompt. Measured on
    DAVE-KOK-BWJ: a `git push -u origin <branch>` spawned `git credential-manager get`, that child
    opened a prompt nothing was listening to, and fifteen minutes later both were still running. The
    ship reported the hang as still shipping, and a lint + 13-suite gate that had already passed was
    thrown away with the kill.

    So Push-NativeNonInteractiveEnv brackets every child with GIT_TERMINAL_PROMPT=0 and
    GCM_INTERACTIVE=never. BOTH ARE NEEDED, AND THEY STOP DIFFERENT THINGS: GIT_TERMINAL_PROMPT is
    git's OWN terminal prompt and says nothing about a credential helper git hands off to -- the Git
    Credential Manager window is GCM's, and GCM_INTERACTIVE=never is what makes GCM fail instead of
    drawing it. Setting only the first leaves exactly the measured hang in place. Environment is the
    only scope a child inherits, so the set is process-wide, saved and restored in the same finally
    the EAP dance uses, and a variable that was ABSENT is restored to absent rather than to ''.

    It is applied to every child rather than only to git: gh shells out to git in places, and there
    is no call in this family for which an interactive credential prompt is ever the right answer.

    -TimeoutSeconds: BOUND THE WAIT, for a hang whose cause is NOT a credential prompt. The guard
    above closes the measured cause and cannot close the class -- the same report carries a second
    stall that no environment variable would have named. A bounded call kills the process TREE (see
    Stop-NativeProcessTree; the blocker was the child, not the parent), reports exit 124 and
    TimedOut = $true, and appends a line saying so to Output -- so a caller that already prints
    Output and judges ExitCode diagnoses the hang without changing a line.

    IT IS OPT-IN, AND THAT IS NOT TIMIDITY. `gh pr checks --watch` (ship-pr.ps1) blocks for as long
    as CI takes, by design; a default bound would turn the longest CORRECT call in the workflow into
    a failure. The bound belongs on the calls that reach the network and should answer in seconds --
    a push, a fetch, an ls-remote, and every `gh` call that is not that one deliberate watch -- and
    $NativeCaptureNetworkTimeoutSeconds is the shared number they all pass. NAMING BOTH COMMANDS HERE
    IS THE POINT (issue #1639): this said "push, fetch", so a script whose every network call is a `gh`
    call could read the whole policy and reasonably conclude it was about somebody else.

    Usage:
        $r = Invoke-NativeCapture -FilePath 'git' -Arguments @('push', '-u', 'origin', $branch)
        $r.Output | ForEach-Object { Write-Host $_ }
        if ($r.ExitCode -ne 0) { Write-Error 'git push failed.'; exit 1 }

        # -DiscardStderr keeps stderr out of the captured output (e.g. so it cannot pollute JSON):
        $r = Invoke-NativeCapture -FilePath 'gh' -Arguments @('pr', 'list', '--json', 'number') -DiscardStderr

        # -TimeoutSeconds bounds a call that reaches the network, so a stall fails loudly (#1179):
        $r = Invoke-NativeCapture -FilePath 'git' -Arguments @('push') -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
        if ($r.TimedOut) { Write-Error 'git push never answered -- see the [timeout] line above.' }

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# THE FUNCTION-TABLE PROBE (issue #1729), for the Get-TestCommands seam below. Unconditional and
# $PSScriptRoot-relative so it resolves in both plugin mirrors of this file as well as here; it is a
# leaf with no dependencies of its own, so loading it first is safe.
. (Join-Path $PSScriptRoot 'command-probe-lib.ps1')

$script:NativeCaptureInvariant = [System.Globalization.CultureInfo]::InvariantCulture

# THE NON-INTERACTIVE ENVIRONMENT every child is bracketed with (inbound #1179). See
# Invoke-NativeCapture's docstring for why both names are here and why neither is sufficient alone.
# A hashtable rather than two literals at the call site: the pair is one policy, and the next name
# that has to join it (an askpass, another helper's switch) belongs beside these two.
$script:NativeCaptureNonInteractiveEnv = @{
    GIT_TERMINAL_PROMPT = '0'
    GCM_INTERACTIVE     = 'never'
}

# THE BOUND A NETWORK CALL PASSES -- git OR gh -- in one place so the sites that reach the network
# cannot drift apart. Read it as $NativeCaptureNetworkTimeoutSeconds from a script that dot-sources this
# lib: dot-sourcing runs the file in the CALLER's script scope, which is what makes $script: here
# readable there.
#
# DELIBERATELY NO LIST OF SITES ANY MORE, AND THE STALE ONE HAD A COST (issue #1639, September 8, 2026).
# This comment used to open "THE BOUND A GIT NETWORK CALL PASSES" and name three sites -- open-pr's
# push, ship-pr's fetch, the fold's push. By the time anybody read it back, six files were passing this
# value and two of them were passing it to `gh`. Both halves misled in the same direction: a reader
# comes HERE to learn the policy, found it described as git-only, and a script whose every network call
# is a `gh` call therefore had no reason to think the policy was about it. That is the measured reason
# claim-issue.ps1 shipped with three unbounded `gh` calls while every sibling bounded its own. So the
# tree is the register rather than this paragraph:
#   grep -rl NativeCaptureNetworkTimeoutSeconds scripts/
#
# TWO MINUTES, AND WHAT THAT NUMBER IS AND IS NOT SIZED OFF. It is roughly twenty times the slowest
# honest push measured in this repo, and a fraction of the fifteen minutes the reported hang sat for --
# generous enough that a slow network is not mistaken for a stall, short enough that a stall is
# reported inside one attention span. THAT IS A git-push ARGUMENT, and it is REUSED for a `gh` API call
# rather than re-derived (#1639). The reuse is sound in the only direction that matters: a
# `gh issue view` that has not answered in two minutes is not slow, it is stalled, so the bound sits
# far past anything honest at either end. Read it as an upper bound on patience, not as a model of
# either command -- a caller that needs a tight bound on a fast call wants its own number, and should
# say why beside it.
$script:NativeCaptureNetworkTimeoutSeconds = 120

# THE TOTAL A HOOK-INVOKED RUN MAY SPEND ON THE NETWORK (issue #1958, September 13, 2026). The bound
# above is PER CALL, and per-call bounds DO NOT COMPOSE: a script making three of them in sequence may
# legitimately spend 360 seconds, which is fine in a script somebody typed and fatal in one a hook
# invoked. A hook has a CEILING -- cycle-autopark.ps1 is registered at 60 seconds in
# plugins/dkj-policy/hooks/hooks.json -- and past it the harness kills the process FROM OUTSIDE.
#
# THAT IS THE WORST WAY FOR THESE SCRIPTS TO END, and it is why this is a defect rather than a slow run.
# park-cycle.ps1's header promises it ALWAYS EXITS 0, because a hook that fails interrupts the work it
# was added to protect, and every refusal in it is written to fail safe. NOT ONE of those arms runs when
# the kill comes from outside: the DEPLOY-lock refusal is not printed, the failed-push diagnosis is not
# composed, and the collision report -- the one urgent thing this workflow's earliest detector exists to
# say -- is lost. The script cannot report the single state it is least able to reason about.
#
# SO A HOOK PASSES A DEADLINE FOR THE WHOLE RUN, not a smaller number per call. Get-NativeCaptureBudgetBound
# hands each call what is LEFT, so the first call may still take the lot and three of them together
# cannot exceed the budget. A smaller per-call number was the obvious repair and is worse in both
# directions: it caps an honest lone fetch for no reason, and it still does not compose once a fourth
# call is added. THE OTHER CANDIDATE -- raise the hook's timeout -- moves the ceiling without ever making
# it reachable, because the number the script may spend would still be nowhere stated.
#
# 45 SECONDS AGAINST A 60-SECOND CEILING, AND THE 15 IS NOT PADDING. The run has to survive its own
# bound, and everything that makes a bounded call SAFE happens after it expires: Stop-NativeProcessTree
# is best-effort and is deliberately given time, the fail-safe arm then runs, and its report has to be
# printed and relayed by cycle-autopark.ps1. A budget equal to the ceiling would hand the harness exactly
# the kill this constant exists to prevent, one layer further in.
#
# IT IS A SHARED CONSTANT AND THE HOOK IS WHAT PASSES IT, because the ceiling lives beside the hook in
# hooks.json and JSON cannot carry a comment saying what it implies. cycle-autopark.tests.ps1 pins the
# two together, so raising one without the other fails a suite instead of waiting for a slow network.
$script:NativeCaptureHookNetworkBudgetSeconds = 45

# THE FLOOR BELOW WHICH A REMAINING BUDGET BUYS NOTHING. This is the half of the repair the issue warned
# about -- "a fetch cut off at 20s reports nothing either" -- and it is answered rather than dismissed: a
# call given two seconds reports no more than a call never made, AND it spends the margin the paragraph
# above is about. So a budget with less than this left is SPENT. Test-NativeCaptureBudgetHasRoom says so,
# and the caller names the call it skipped instead of making one it cannot finish.
#
# THE COMPARISON THAT SETTLES THE ISSUE'S DOUBT is not "short bound versus generous bound" but "short
# bound versus the harness's kill". Both lose the answer to that one call; only the kill also loses the
# rest of the run and everything already printed. There is no third option in which the call gets its
# full two minutes AND the hook reports anything.
$script:NativeCaptureHookNetworkFloorSeconds = 5

# 124 is `timeout(1)`'s conventional "the command timed out" code, borrowed rather than invented so a
# reader who greps it lands on an answer. Neither git nor gh uses it, so it cannot be confused with a
# real verdict -- but a caller who needs certainty reads TimedOut instead of the number.
$script:NativeCaptureTimeoutExitCode = 124

# THE BUDGET Invoke-NativeCaptureUtf8 SPENDS WAITING FOR A CAPTURE FILE TO SETTLE, on a clean exit only
# (issue #1679). Short on purpose. It buys exactly one thing -- a grandchild being REAPED releases the
# inherited stdout handle in milliseconds, and waiting for that turns a short read into a complete one.
# A grandchild still RUNNING never releases inside any budget worth having, and there a reported short
# read is the correct verdict rather than a longer stall. Measured September 9, 2026: five consecutive
# `gh issue view --json body` captures settled on the first probe (2-8 ms), so in the normal case this
# is not spent at all.
$script:NativeCaptureSettleMilliseconds = 1000

# THE LINE ABOVE WHICH Invoke-TestSuiteGate WARNS ABOUT RESIDENT powershell.exe PROCESSES (issue #1464,
# September 5, 2026). A harness-killed gate run does not reap the Start-Process children it already
# started, so they outlive it -- and an immediate retry can be OOM-killed too, even with -MaxParallel
# set correctly, because the retry's own budget assumed memory a prior run's orphans were still
# holding. Measured on one machine: 5 processes at rest, 28 orphaned after one kill.
# THE NUMBER IS A HEURISTIC, NOT A DIAGNOSIS, and it is picked to sit between two measured bands rather
# than at either one: this file's own SHARDING notes put a legitimately busy run at 16-18 concurrent
# lanes, and the orphan count above put a fouled one at 28+. 20 clears the first with margin and sits
# under the second, but a false positive on an unusually wide dev box costs one line of noise -- this
# is Write-Warning, never a gate failure -- and a false negative just misses one chance to explain a
# kill that would otherwise look like "the machine is slow today".
$script:ResidentPowerShellWarnThreshold = 20

# THE MEMORY A SINGLE LANE IS BUDGETED, in MB, and the second half of Invoke-TestSuiteGate's automatic
# lane count (issue #2121, September 18, 2026). The formula reserved two CORES and reasoned about nothing
# else, while what a lane actually exhausts is MEMORY: every lane is a powershell child that spawns
# children of its own, and powershell.exe is expensive to start and cheap to compute with.
#
# WHY A DEFAULT THAT ONLY COUNTED CORES WAS NOT MERELY SUBOPTIMAL. #1443 measured it killing a run
# outright -- 16 lanes on an 18-core machine, OOM-killed twice where -MaxParallel 4 finished -- and
# #2121 measured the quieter half on a wider box: at 30 lanes the gate reported 44 of 116 suites red,
# then 43, on a tree where six of those suites were spot-checked green standalone minutes later and a
# 6-lane run of the same tree found the two real failures. The two red runs did not even name the same
# suites (37 shared, 7 and 6 unique), which is what tells load from logic. A verdict a session cannot
# trust is worse than a slow one: that session paid three full gate runs to tell one real failure from
# forty false ones, and the summary line gave it no reason to suspect the lane count at all.
#
# 512 MB, AND WHAT THE NUMBER IS SIZED OFF. Measured on DAVE-KOK-BWJ (18 logical processors, 16 GB),
# shard 1 of 4 at 8 lanes over this repo's own 116 suites, sampling every 1.5s for the whole 401s run:
# peak 26 resident powershell.exe (~3.25 per lane), peak 1,922 MB private bytes and 2,280 MB working set
# across them -- so a lane's own peak is about 240 MB private / 285 MB working set. 512 is roughly 1.8x
# that, and the margin is deliberate rather than rounding: the figure above is THIS repo's suite mix on
# ONE machine, and a consumer's suites are not bound by it.
#
# AND THE MARGIN IS WHAT THE SAME RUN SURVIVED ON, which is the check worth doing before trusting the
# 1.8x. That run started with 3,063 MB free and dipped to 1,686 MB while 8 lanes were open -- so it was
# BUDGETED 383 MB of the starting figure per lane and still finished, where this constant would have
# budgeted 512 and opened 5. The dip is the separate fact that says how little was left over: 1,686 MB
# across 8 lanes is 211 MB each, under the 240 MB private a lane peaked at, which is how close to the
# wall a core-only formula had already brought a machine it thought had room for 16.
#
# BEING TOO CONSERVATIVE IS CHEAP, WHICH IS THE WHOLE ARGUMENT FOR THE MARGIN. Lanes have heavily
# diminishing returns here because the suites spend their time waiting on children rather than
# computing: open-pr.ps1's own .PARAMETER MaxParallel records 4 lanes finishing the same 68 suites in
# 888s against 16 lanes' 716s -- 24% slower, and it finishes. So the worst case of a low number is a
# quarter more wall clock, and the worst case of a high one is a verdict nobody can trust.
#
# IT DOES NOT REACH CI. ci.yml passes -MaxParallel ([Environment]::ProcessorCount) explicitly, for the
# reason written there, so a hosted runner's four lanes are unchanged by anything here.
$script:TestSuiteGateLaneMemoryMB = 512

# THE DEADLINE A SINGLE SUITE RUNS UNDER inside Invoke-TestSuiteGate's pool (issue #1941,
# September 13, 2026). Until this existed the reap loop had NO deadline of any kind -- it slept 100 ms
# and looped for as long as a lane took, whatever had stopped that lane progressing -- so one wedged
# suite wedged the whole gate. Measured on DAVE-KOK-BWJ: a 30-lane run sat for 141 minutes with 61
# powershell.exe and 29 git.exe alive and 0.23 s of CPU between all 29, printing nothing, because this
# function buffers a suite's output until that suite exits and a suite that never exits never prints.
# No output, no error, no red, and a later gate on the same machine starts its own 30 lanes on top.
#
# IT IS ON BY DEFAULT, AND THE ASYMMETRY WITH $NativeCaptureNetworkTimeoutSeconds IS THE ARGUMENT.
# That bound is opt-in because `gh pr checks --watch` is legitimately unbounded and a default would turn
# the longest CORRECT call in the workflow into a failure. There is no such call here: NO TEST SUITE IS
# EVER LEGITIMATELY INFINITE, so the safe default is the bounded one and the escape valve is the flag.
#
# 1800 SECONDS, AND WHAT THAT NUMBER IS SIZED OFF. It is an upper bound on PATIENCE, not a model of any
# suite, and two readings bracket it. On a four-lane hosted runner the slowest row in
# scripts/tests/suite-durations.json is new-branch.tests.ps1 at 290.2s, so CI runs at ~6x headroom. On a
# workstation the dominant file is a different one and far slower: #2232's closing measurement recorded
# check-plugin-integrity-docs.tests.ps1 at 415.5s inside a 22-lane pool on 24 idle cores (~4.3x), and
# #2255 recorded that same file at 851s run STANDALONE on the machine that then hit this bound (~2.1x).
# It is also a fraction of the 141 minutes the measured wedge sat for, and well inside a hosted runner's
# own job timeout, so the gate reports WHICH suite wedged instead of the job being killed with no
# per-suite attribution at all -- which is precisely the residual #1704 was left with.
#
# A SUITE *CAN* REACH THIS BOUND BY BEING SLOW, AND THIS COMMENT CLAIMED THE OPPOSITE UNTIL #2255. It
# read "no suite can reach it by being slow", sized off the 290.2s CI row alone and off nothing else. A
# 9-lane run of this repo's own 121 suites then timed out check-plugin-integrity-docs.tests.ps1 at 1,800s
# after 1,890s of wall clock, and that suite passed all 188 of its asserts standalone on the same
# checkout minutes later. So a timeout here does NOT by itself prove a wedge.
#
# THE FALSE SENTENCE WAS EXPENSIVE RATHER THAN UNTIDY, WHICH IS WHY THE CORRECTION IS PRINTED AND NOT
# ONLY WRITTEN HERE. "A timeout means a wedge" is the reading that made #2233 diagnosable; believed
# unconditionally, it costs a second full gate run before anything else is suspected, and it lands
# hardest on the slowest machines -- the ones least able to afford a 31-minute run that ends red over a
# green suite. So the verdict line names the ambiguity where a reader actually meets it, and names the
# one measurement that resolves it: re-run the suite STANDALONE, which separates "never answered" from
# "answered late" without any further reasoning about load.
#
# WHY IT IS STILL A FIXED CONSTANT AND NOT DERIVED PER SUITE. #2255's second suggestion was to derive the
# bound from suite-durations.json, and that file's own note is the argument against it: it is MEASURED ON
# CI, a local reading does not convert into a CI one, and the sign is not even fixed -- one suite ran
# 2.6x SLOWER solo on an 18-thread workstation than on a 4-lane runner. A per-suite bound derived from a
# CI row would therefore be tightest exactly where the machine is slowest, i.e. on the population this
# bound already fails hardest on. It is also incomplete: #2232 found 91 of the 121 suites listed, and a
# suite missing from that file is charged the MAXIMUM, so the suites with no reading at all would draw
# the most generous bound rather than the most careful one. Refreshing the file is real work and is
# tracked separately (#2252, which needs a CI run that does not exist yet); it does not make the
# derivation sound. Whether 1800 is the right constant is a third question, deliberately not settled
# here.
$script:GateSuiteTimeoutSeconds = 1800

# HOW LONG A TIMED-OUT LANE IS GIVEN TO DIE BEFORE THE POOL STOPS WAITING ON IT AT ALL (issue #1941).
# Stop-NativeProcessTree is best-effort by nature -- its own docstring says so at length: taskkill can be
# refused, and it can simply be slow to start under load. Every other caller in this file can afford that,
# because it waits a fixed 5s and then reads the capture files regardless. THIS caller cannot: a lane whose
# kill did not take has HasExited = $false forever, and a pool that only reaps exited lanes would go
# straight back to the unbounded wait this whole mechanism exists to end. So past this window the lane is
# abandoned rather than reaped -- reported, its capture files kept, and removed from the running list with
# its process left to whatever the OS does with it. That is the honest verdict: the gate has measured that
# the suite did not finish and that killing it did not work, and both facts belong on the console.
$script:GateSuiteKillGraceSeconds = 30

# THE PROGRESS RECORD THE GATE PUBLISHES FOR A READER WHO CANNOT SEE ITS OUTPUT -- issue #2101.
# Format-GateProgressLine below prints into the run's stdout, which is exactly the thing a backgrounded
# run does not show anybody: Claude Code streams no stdout at all from a Bash call made with
# run_in_background, in the terminal CLI and in the VS Code extension alike. So the same three numbers
# are ALSO published to a file that the statusline -- the one surface that keeps rendering -- draws.
#
# THE DOT-SOURCE IS GUARDED, AND THAT IS WHAT LETS THIS FILE STAY BYTE-IDENTICAL TO ITS TWO MIRRORS.
# run-progress-lib.ps1 is not mirrored into the plugins, so in a consumer the Test-Path simply fails and
# the gate behaves exactly as it did -- the same shape the guarded dot-sources already in this tree use,
# and the reason the bar can be turned on for a consumer later by shipping one more file rather than by
# editing this one again.
$script:RunProgressAvailable = $false
try {
    $runProgressLib = Join-Path $PSScriptRoot 'run-progress-lib.ps1'
    if (Test-Path -LiteralPath $runProgressLib -PathType Leaf) {
        . $runProgressLib
        $script:RunProgressAvailable = $true
    }
} catch { $script:RunProgressAvailable = $false }

function Publish-GateProgress {
    <#
        The gate's own progress, published for the statusline -- issue #2101. A no-op where the lib is
        absent, and silent on every failure: a diagnostic must not be able to cost the run it describes.

        THE DEPTH IS IN THE ID, not only in the line. A gate driving itself over a fixture is a second
        live run, and Get-RunProgressId separates records by pid -- which a nested gate in the same
        process tree does not necessarily change. Without the depth an inner run could overwrite the
        outer one's record, which is precisely the confusion #1717 introduced the depth to end.

        WHAT IS PUBLISHED IS DONE-OF-TOTAL, WITH STARTED CARRIED AS A NOTE. The console line reports
        both counts because a done-count alone sits at 0 for the first quarter of an 84-suite run; a BAR
        cannot show two numbers at once, so the bar is the one that means "finished" and the other rides
        along as text. Neither is dropped and neither is invented.
    #>
    param(
        [Parameter(Mandatory = $true)][int]$Started,
        [Parameter(Mandatory = $true)][int]$Done,
        [Parameter(Mandatory = $true)][int]$Total,
        [Parameter(Mandatory = $true)][datetime]$StartedUtc,
        [int]$Depth = 1
    )
    if (-not $script:RunProgressAvailable) { return }
    try {
        [void](Write-RunProgress -Id (Get-RunProgressId -Name "test-gate-d$Depth") -Label 'test gate' `
            -Current $Done -Total $Total -Note "$($Started - $Done) running" -StartedUtc $StartedUtc)
    } catch { }
}

function Clear-GateProgress {
    <# The gate's record removed when the pool closes -- issue #2101. Never throws; see above. #>
    param([int]$Depth = 1)
    if (-not $script:RunProgressAvailable) { return }
    try { [void](Complete-RunProgress -Id (Get-RunProgressId -Name "test-gate-d$Depth")) } catch { }
}

# HOW BIG A JUMP IN THE GATE'S OWN CLOCK IS NO LONGER TIME THIS POOL SPENT RUNNING (issue #2095).
#
# THE DEFECT. The bound above is measured off a Stopwatch, and a Stopwatch keeps counting while the
# machine is SUSPENDED -- so nothing in the mechanism could tell a suite that would not finish from a
# workstation that had gone to sleep underneath one that was finishing fine. Measured on an unattended
# overnight run: the machine suspended ~7s into two suites and woke 3.03 h later, the first poll after
# the wake read $sw.Elapsed - StartOffset as ~10,900s against the 1,800s bound, and both process trees
# were killed. Neither suite is broken -- both pass in seconds, and the same tree had just run all 113
# green twice. What that cost is the whole night: the gate refuses, so nothing is pushed, and the
# remedy it prints ('Fix the tests') names a defect that does not exist, in two files picked by nothing
# more than which lanes happened to be open at suspend.
#
# WHAT IS ACTUALLY MEASURED HERE. The poll loop sleeps 100 ms and goes round again, so the seconds
# between two consecutive passes are that sleep plus the loop's own work. A suspend leaves a
# discontinuity in that series which the loop cannot otherwise produce, because nothing ran across it
# -- the watchdog included. That gap, and only that gap, is what gets credited back.
#
# 300 SECONDS, AND WHAT THAT NUMBER IS SIZED OFF. #2095's own progress stream carried five gaps over
# 60s, four of them 62-99s: a reap pass settles up to $script:NativeCaptureSettleMilliseconds per
# capture file and then writes a whole suite's output per lane, so a busy iteration is legitimately
# slow and a tight threshold would call it a suspend. This sits at ~3x the largest honest gap that run
# recorded and at a sixth of the bound it protects -- and the asymmetry is the argument, not the
# midpoint: a gap wrongly credited only makes the pool 300s MORE patient with a wedged tree, while a
# suspend not credited turns a passing suite red and refuses the push.
#
# IT CANNOT DISARM #1941, WHICH IS THE ONE THING THIS MUST NOT DO. A deadlocked tree produces no gap at
# all -- the loop goes on polling ten times a second while nothing in the suite moves -- so the sweep
# kills it at the bound exactly as before. #1941's own measurement is the proof: 141 minutes, 90
# processes alive, AND a gate that was still looping. What is credited here is wall clock that no
# process was running across, the gate's own included.
#
# AND THE THIRD OPTION #2095 LISTED IS DELIBERATELY NOT BUILT: judging a lane on CPU consumed cannot
# tell these two apart, because a deadlock burns no CPU either -- #1941 measured 0.23s across 29
# children over 141 minutes. A signal that reads identically in both states is not a discriminator.
$script:GateSuspendGapSeconds = 300

function Get-GateSuspendCredit {
    <#
        HOW MUCH OF THIS GAP WAS NOT TIME THE POOL SPENT RUNNING -- issue #2095.

        Given the seconds the gate's own stopwatch advanced between two consecutive passes of the poll
        loop, return the seconds to credit back to every open lane: the whole gap where it is a
        discontinuity the loop cannot produce, and 0 otherwise. $script:GateSuspendGapSeconds carries
        the defect this exists for, what the threshold is sized off, and why it cannot disarm #1941.

        THE WHOLE GAP, NOT THE GAP MINUS THE THRESHOLD. At most the threshold's worth of a 10,896s jump
        could be the loop's own work, and subtracting it would leave every lane 300s nearer a bound none
        of them was anywhere near. Rounding towards patience is the same asymmetry the threshold itself
        is sized on.

        A FUNCTION RATHER THAN THREE INLINE LINES, BECAUSE IT IS THE SEAM. Nothing in a fixture can put
        a laptop to sleep, so the pool's rebase is proven by redefining this after the dot-source -- the
        way test-suite-gate.tests.ps1 already shadows Get-ResidentPowerShellCount (#1464) for OS state a
        test cannot control either. Being pure is what lets the judgement itself be asserted directly,
        rather than only through a run that has to be staged around it.
    #>
    param(
        [double]$GapSeconds,
        # 0 = resolve the module default. A caller naming its own threshold is how the suite asserts
        # both sides of the boundary without pinning itself to whatever the constant currently says.
        [double]$ThresholdSeconds = 0
    )
    $limit = if ($ThresholdSeconds -gt 0) { $ThresholdSeconds } else { $script:GateSuspendGapSeconds }
    if ($GapSeconds -gt $limit) { return [double]$GapSeconds }
    return [double]0
}

# HOW LONG THE CPU SAMPLE WINDOW IS, AND WHY THERE IS A WINDOW AT ALL -- issue #2279. The cumulative
# reading alone cannot see a suite that did real work and THEN stopped: a lane that ran honestly for 25s
# and wedged for the remaining 29 minutes carries a healthy cumulative figure and a dead one over the
# last three seconds. So the sweep takes two snapshots and reports both -- what the tree has consumed in
# its whole life, and what it consumed while the gate watched it.
#
# 3 SECONDS, AND WHAT IT IS SIZED AGAINST. Windows accounts CPU in ~15.6ms clock ticks, so a window has
# to be long enough that a genuinely running tree accrues something unmistakable: over 3s a single busy
# thread accrues ~3000ms, against a floor two orders of magnitude below that. It is also 0.17% of the
# bound it reports on -- the pool is already 1800s into this lane by the time a byte of this is read, so
# the cost is invisible. #2279's own hand measurement used 4s; nothing in the reading turns on the
# difference, and the shorter window is the one that holds the poll loop up less.
#
# THE LOOP IS BLOCKED FOR THAT WINDOW, ONCE PER SWEEP AND NOT ONCE PER LANE. Every lane that passed its
# bound in the same pass is measured off the same pair of snapshots, so two lanes timing out together
# cost 3s between them rather than 6s. What the pause actually delays is the reaping of lanes that
# finished during it, by up to 3s on a run that has already spent half an hour -- and it cannot delay a
# kill past its bound, because the kill happens after the second snapshot in the same pass.
$script:GateCpuSampleSeconds = 3

# WHAT COUNTS AS "NOTHING RAN" -- 1% of the window, i.e. 30ms over the 3s above. A floor rather than a
# threshold, and the distinction is the whole of what this number is allowed to mean: it separates a
# reading that is indistinguishable from zero from one that is not, and it decides nothing. #2231's
# wedged tree read 0.000s over a sampled window; a tree still executing reads three full seconds. There
# is no case in this repo's measurements that lands near 30ms, which is why a coarse floor is enough.
$script:GateCpuIdleFloorFraction = 0.01

function Get-GateProcessSnapshot {
    <#
        EVERY PROCESS ON THE MACHINE, WITH ITS PARENT AND ITS CPU -- issue #2279, and this is the
        impure half.

        ONE CIM CALL FOR THE WHOLE MACHINE, NOT ONE PER PROCESS. Win32_Process carries ParentProcessId,
        KernelModeTime and UserModeTime on every row, so the tree walk below is arithmetic over a
        snapshot rather than a query per node -- which matters because the thing being measured is a
        tree whose size is unknown and, in #1941's measurement, 90 processes. Measured on DAVE-KOK-BWJ:
        506 processes in 416ms.

        Win32_Process RATHER THAN System.Diagnostics.Process.TotalProcessorTime, which is what #2279
        proposed and left open as a question. TotalProcessorTime reads the DIRECT CHILD only, and every
        wedge in this family sits in a GRANDCHILD -- #2233's three wedged suites each held exactly one
        child, which held the hook that was actually blocked -- so a direct-child reading would report
        ~0 for a tree that is working and answer the question backwards. It also opens a handle per
        process and throws on one that exited mid-read, where a CIM row for a process that has since
        gone is simply a row.

        IT RETURNS $null RATHER THAN THROWING. CIM can be refused, slow, or unavailable, and by the time
        this is called the pool is already killing a lane -- replacing a diagnosable timeout with an
        unrelated error is the failure Stop-NativeProcessTree's own docstring argues against, one
        function over. The caller reports "could not measure", which is a different sentence from
        "nothing ran" and must not be printed as it.

        THE SEAM. Nothing in a fixture can wedge a real process tree, so the suite shadows this after
        the dot-source and drives the pure walk below over a fabricated machine -- the pattern
        Get-GateSuspendCredit's docstring sets out and Get-ResidentPowerShellCount already uses (#1464).
    #>
    try {
        $rows = Get-CimInstance -ClassName Win32_Process `
            -Property ProcessId, ParentProcessId, KernelModeTime, UserModeTime, CreationDate `
            -ErrorAction Stop
    } catch {
        return $null
    }
    if ($null -eq $rows) { return $null }

    $byId       = @{}
    $childrenOf = @{}
    foreach ($row in @($rows)) {
        $id   = [int]$row.ProcessId
        $ppid = [int]$row.ParentProcessId
        # 100-NANOSECOND UNITS, WHICH IS WHAT Win32_Process REPORTS. Divided here rather than at every
        # reader, so no caller can forget the conversion and print a number 10 million times too large.
        # [double] before the addition: these are UInt64, and a long-lived process overflows Int32.
        $cpu = ([double]$row.KernelModeTime + [double]$row.UserModeTime) / 1e7
        $byId[$id] = [pscustomobject]@{
            ProcessId       = $id
            ParentProcessId = $ppid
            CpuSeconds      = $cpu
            # WHEN IT STARTED, CARRIED FOR THE PID-REUSE GUARD IN THE WALK BELOW. $null where CIM did
            # not answer, which the walk reads as "cannot disprove the parentage" rather than as a
            # reason to drop the node.
            CreatedTicks    = if ($null -ne $row.CreationDate) { [long]$row.CreationDate.Ticks } else { $null }
        }
        if (-not $childrenOf.ContainsKey($ppid)) { $childrenOf[$ppid] = New-Object System.Collections.ArrayList }
        $childrenOf[$ppid].Add($id) | Out-Null
    }
    return [pscustomobject]@{ ById = $byId; ChildrenOf = $childrenOf }
}

function Get-GateTreeCpuSeconds {
    <#
        THE CPU ONE LANE'S WHOLE TREE HAS CONSUMED -- issue #2279, and this is the pure half: a walk
        over a snapshot, with no process, clock or machine state of its own. That is what lets the
        suite assert the judgement directly instead of only through a run staged around a real wedge.

        Returns a row carrying CpuSeconds, ProcessCount and Measured. Measured is $false when the
        snapshot is absent or the root is not in it -- a lane whose process exited between the sweep
        deciding to kill it and this call is the ordinary way that happens, and it is a different fact
        from a tree that consumed nothing.

        THE PID-REUSE GUARD. A snapshot names parents by number, and Windows reuses process ids -- so a
        long-lived unrelated process that happens to hold the id of one of this tree's dead children
        would drag its whole subtree into the sum. A child that started BEFORE its claimed parent
        cannot be that parent's child, so it is dropped. Where either creation time is unreadable the
        node is kept: this measurement exists to say whether anything ran, and discarding a subtree on
        missing metadata would understate it in exactly the direction that reads as a wedge.

        THE VISITED SET IS NOT BELT-AND-BRACES. It bounds the walk whatever the snapshot says, and a
        snapshot is assembled from rows read at slightly different moments, so a cycle through a reused
        id is representable even though a real process tree has none. An unbounded walk here would hang
        the poll loop at the exact point the pool is trying to stop waiting on something.
    #>
    param(
        $Snapshot,
        [Parameter(Mandatory = $true)][int]$ProcessId
    )

    $unmeasured = [pscustomobject]@{ CpuSeconds = [double]0; ProcessCount = 0; Measured = $false }
    if ($null -eq $Snapshot -or $null -eq $Snapshot.ById) { return $unmeasured }
    if (-not $Snapshot.ById.ContainsKey($ProcessId)) { return $unmeasured }

    $total   = [double]0
    $count   = 0
    $visited = @{}
    $queue   = New-Object System.Collections.Queue
    $queue.Enqueue($ProcessId) | Out-Null

    while ($queue.Count -gt 0) {
        $id = [int]$queue.Dequeue()
        if ($visited.ContainsKey($id)) { continue }
        $visited[$id] = $true

        $node = $Snapshot.ById[$id]
        if ($null -eq $node) { continue }
        $total += [double]$node.CpuSeconds
        $count++

        if ($null -eq $Snapshot.ChildrenOf -or -not $Snapshot.ChildrenOf.ContainsKey($id)) { continue }
        foreach ($childId in @($Snapshot.ChildrenOf[$id])) {
            $cid = [int]$childId
            if ($visited.ContainsKey($cid)) { continue }
            $child = $Snapshot.ById[$cid]
            if ($null -eq $child) { continue }
            # See the PID-REUSE GUARD above: a child older than its claimed parent is somebody else's.
            if ($null -ne $child.CreatedTicks -and $null -ne $node.CreatedTicks -and
                $child.CreatedTicks -lt $node.CreatedTicks) { continue }
            $queue.Enqueue($cid) | Out-Null
        }
    }

    return [pscustomobject]@{ CpuSeconds = $total; ProcessCount = $count; Measured = $true }
}

function Get-GateTimeoutCpuNote {
    <#
        WHAT THE REAP IS ALLOWED TO SAY ABOUT WHY -- issue #2279. Pure: given two readings of a lane's
        tree, return the console lines that go under its timeout. The bound and the reap are not this
        function's business and are unchanged -- #2279 proposed the reporting half only, and this is it.

        IT IS A TWO-WAY DISCRIMINATOR, NOT THE THREE-WAY ONE #2279's TABLE ASKED FOR, and that
        correction is the whole design. That table's third row reads "deadlocked tree -- CPU varies";
        this file's own $script:GateSuspendGapSeconds block records #1941's deadlock at 0.23s across 29
        children over 141 MINUTES, which is indistinguishable from #2231's wedge at 0.58s over 22. So a
        wedge and a deadlock read the same here and no reading separates them. What CPU DOES separate is
        "something was running" from "nothing was running" -- and that is the one question the console
        currently spends a whole standalone re-run on:

            a slow suite CAN reach that bound, so this is not by itself a wedge (#2255) --
            re-run the named suite alone to tell 'never answered' from 'answered late'.

        #2255 is the measurement behind that line: a genuinely slow suite hit the bound and then passed
        all 188 asserts standalone, at the cost of a second full gate run. A tree still burning CPU at
        the moment it was killed answers "answered late" without that run; a tree at zero answers
        "never answered" and sends the reader to the handles instead of to the clock.

        AND IT DOES NOT REOPEN THE SUSPEND QUESTION. $script:GateSuspendGapSeconds's block declines CPU
        as the discriminator for MACHINE SUSPEND, correctly, and for a reason untouched here: a deadlock
        burns no CPU either, so CPU cannot be what credits a lane back. Nothing below credits, reaps or
        kills anything -- it composes sentences. A suspended machine is handled one mechanism over, and
        by the time a lane reaches this its gap has been credited or there was none.

        WHY IT HEDGES RATHER THAN CLASSIFYING. A lane blocked on slow I/O -- a network share, a cold
        disk, a CI volume -- also consumes almost no CPU while being perfectly honest, and #2279 flags
        that in its own "what is NOT established" section. So zero is evidence toward "not a runaway"
        and is not proof of a wedge, and the wording says which of the two it is offering. The value is
        removing ONE of two branches from the reader's search, not handing them a verdict nobody took.
    #>
    param(
        $Cumulative,
        $Window,
        [double]$WindowSeconds = 0,
        [double]$IdleFloorFraction = 0
    )

    $lines = New-Object System.Collections.ArrayList
    if ($null -eq $Cumulative -or -not $Cumulative.Measured) {
        # NOT SILENCE, AND NOT "NOTHING RAN". A reading that did not happen and a reading of zero are
        # opposite facts, and the second is the one that would send a reader hunting a handle that is
        # not there -- the same three-state reasoning claim-issue's read-back states for its own
        # unverifiable case.
        $null = $lines.Add('           CPU over the bound: could not be measured on this machine -- no reading either way (#2279).')
        return @($lines)
    }

    $floorFraction = if ($IdleFloorFraction -gt 0) { $IdleFloorFraction } else { $script:GateCpuIdleFloorFraction }
    # NOT $window, AND THE CASE IS NOT THE POINT -- PowerShell variable names are case-INSENSITIVE, so a
    # local $window here IS the $Window parameter and silently replaces the reading with a number. Caught
    # by a probe against a real idle tree: the seconds landed in $Window, '$Window.Measured' then read
    # $null on a [double], and every lane reported 'could not be re-read for a live sample' while holding
    # a perfectly good sample. The defect is invisible in review and unmistakable at runtime, which is
    # this file's recurring shape -- the wrong answer arrives as a plausible value instead of as an error.
    $windowLength = if ($WindowSeconds -gt 0) { $WindowSeconds } else { [double]$script:GateCpuSampleSeconds }
    $windowCpu    = if ($null -ne $Window -and $Window.Measured) { [double]$Window.CpuSeconds } else { $null }

    $null = $lines.Add(("           CPU over the bound: $(Format-GateSeconds $Cumulative.CpuSeconds -Decimals 2)s across " +
                        "$($Cumulative.ProcessCount) process(es) in the tree (#2279)."))

    if ($null -eq $windowCpu) {
        $null = $lines.Add('           The tree could not be re-read for a live sample, so that is a lifetime total only.')
        return @($lines)
    }

    $null = $lines.Add(("           Of that, $(Format-GateSeconds $windowCpu -Decimals 3)s was consumed in the last " +
                        "$(Format-GateSeconds $windowLength)s before the kill."))

    if ($windowCpu -le ($windowLength * $floorFraction)) {
        $null = $lines.Add('           NOTHING IN THAT TREE WAS RUNNING -- so this is NOT a suite answering late, and a')
        $null = $lines.Add('           standalone re-run will not reproduce it. Look for a wedge or a deadlock: an')
        $null = $lines.Add('           inherited handle nobody closes (#2233), or a lock nothing releases (#1941).')
        $null = $lines.Add('           CPU cannot tell those two apart, and a lane blocked on slow I/O also reads zero.')
    } else {
        $null = $lines.Add('           THE TREE WAS STILL EXECUTING when it was killed, so this reads as a suite')
        $null = $lines.Add('           ANSWERING LATE rather than one that never answered (#2255) -- re-run it alone.')
    }
    return @($lines)
}

function Test-GateSuiteCrashed {
    <#
        DID THIS SUITE FAIL, OR DID ITS PROCESS DIE? -- issue #1723.

        The gate judges a suite on its exit code alone, and until this function that made the two
        indistinguishable: an unhandled AccessViolationException inside the PowerShell engine was
        reported as 'FAILED (exit -1073741819)', which reads as a suite that ran and said no. It did
        not run. It was killed, so it wrote no [FAIL] line and no summary, and every minute a reader
        then spends looking for the failing assert is spent on an assert that does not exist.

        MEASURED, September 9, 2026: branch-entry-gate.tests.ps1 under a 30-lane pool ended mid-suite
        on a [PASS] line with no [FAIL] anywhere, and its .err file carried
        System.AccessViolationException raised from WildcardPatternMatcher.PatternPositionsVisitor.Add
        under CommandSearcher.SearchForFunctions -- a Get-Command probe faulting while walking the
        function table. Re-run alone on the same tree: 'OK: all 49 asserts passed.'

        THE TEST IS NTSTATUS'S SEVERITY FIELD, which is exact without being a list of known codes. A
        process killed by an unhandled structured exception exits with that exception's NTSTATUS, and
        every member of that family carries severity STATUS_SEVERITY_ERROR in its top two bits --
        0xC0000005 access violation, 0xC00000FD stack overflow, 0xC0000374 heap corruption,
        0xC0000409 stack buffer overrun. So the window is 0xC0000000..0xCFFFFFFF and nothing inside
        the family has to be enumerated or can be missed.

        THE WINDOW IS NARROWER THAN 'ANY NEGATIVE Int32', AND THAT IS THE POINT (Sebastian's security
        review of this change). The first version tested the sign bit alone, which is forgeable by the
        very content this gate exists to judge: `exit -1` is a line any .tests.ps1 may write, it
        arrives as 0xFFFFFFFF, and under the sign-bit test it would have bought that suite a free
        re-run -- turning the neighbouring promise, that an ordinary verdict is NEVER retried, into
        something the suite itself got to opt out of. 0xFFFFFFFF is outside this window, as is every
        small negative a script would plausibly choose.
        WHAT IT DOES NOT CLAIM is proof that the OS did the killing. An exit code is not a signal, and
        a suite determined to land inside the window still can. That is accepted rather than papered
        over, on the measurement that a suite wanting a green gate has `exit 0` available and needs
        none of this: the window is here to stop an ACCIDENT -- a negative code that was never a crash
        -- not to withstand the repo's own content. Measured at the time of writing: no suite or lib
        under scripts/ exits negative at all.

        ONE STATUS INSIDE THE WINDOW IS EXCLUDED BY NAME: 0xC000013A, STATUS_CONTROL_C_EXIT, which is
        what Windows leaves behind for a console process stopped by Ctrl+C (Marlowe's red-team of this
        change). It is not a crash and it is not rare -- it is the single most likely thing an operator
        does to a stuck 30-lane run, and this function's own docstring already records that every suite
        child shares ONE console via -NoNewWindow, so a CTRL_C_EVENT reaches all of them at once.
        Without the exclusion, interrupting the gate would print a magenta "the process died" for every
        suite still running and then RE-RUN each one -- the exact opposite of what the operator asked
        for, and a way to make a deliberate stop take longer than not stopping.
        IT IS EXCLUDED RATHER THAN THE WINDOW NARROWED, because the window is a severity-and-facility
        range and this is one status inside it that happens not to describe a fault. A narrower range
        would have to be justified status by status; an exclusion says what it is.

        AND IT IS ASKED OF SUITES ONLY. Get-TestCommands entries are judged in their own block further
        down, which propagates a native tool's exit code directly -- a tool returning a negative value
        is not given a re-run, because there the code is the command's answer rather than a process's
        gravestone.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()][object]$ExitCode)
    if ($null -eq $ExitCode) { return $false }
    $code = [int]$ExitCode
    # THE BOUNDS ARE WRITTEN AS THE HEX THEY COME FROM, and no conversion is needed to compare them:
    # Windows PowerShell parses 0xC0000000 as the Int32 -1073741824, which is exactly the value .NET's
    # Process.ExitCode hands back for that status. So the line reads as the NTSTATUS window it is.
    # A [uint32] cast is NOT the way to do this -- PowerShell's is checked and throws on a negative.
    # The facility bits matter as much as the severity: 0xFFFFFFFF (`exit -1`) also carries severity
    # ERROR, and is excluded only because 0xCxxxxxxx pins the facility to NT's own.
    # STATUS_CONTROL_C_EXIT: inside the window, but a stop rather than a fault. See the docstring.
    if ($code -eq 0xC000013A) { return $false }
    return ($code -ge 0xC0000000 -and $code -le 0xCFFFFFFF)
}

function Format-GateExitCode {
    <# A crash code as the hex a reader can look up, an ordinary one as itself -- issue #1723. #>
    param([Parameter(Mandatory = $true)][int]$ExitCode)
    # NO [uint32] CAST: PowerShell's is CHECKED, so it throws on a negative Int32 rather than
    # reinterpreting the bits -- which is how the first version of this failed, inside the gate's own
    # report. Int32's own hex format is already two's complement, so -1073741819 formats as C0000005
    # with no conversion at all.
    if ($ExitCode -lt 0) { return ('0x{0:X8}' -f $ExitCode) }
    return "$ExitCode"
}

function Format-GateSeconds {
    <#
        The elapsed-seconds figure Invoke-TestSuiteGate prints, FORMATTED INVARIANTLY -- and that is not
        a style choice (issue #1159). PowerShell's '-f' formats in the current culture: on a Dutch
        machine '{0:N0}' renders 2182 as '2.182', which an English reader of this repo reads as 2.182
        seconds -- off by a factor of a thousand and still plausible. It only misformats above 1000s,
        which is exactly the runs worth noticing, so nothing looked wrong until a slow run produced one.
        Same reasoning measure-skill-lib.ps1's Format-* helpers state at length: a figure must not
        depend on the machine that printed it. Repo content is English (CLAUDE.md, Language), and a
        number whose meaning depends on regional settings is the same defect as an untranslated string.
    #>
    param(
        [Parameter(Mandatory = $true)][double]$Seconds,
        # WHOLE SECONDS BY DEFAULT, and the default is what every caller before #1358 gets -- a test
        # asserts that 0.4 renders as '0'. The per-suite table added by that issue is the one caller that
        # needs a decimal: most suites in this pool finish under a second, and a column of '0s' rows
        # records nothing. Still routed through the invariant culture, because that is the whole point of
        # this function and a second format string is a second chance to lose it.
        [int]$Decimals = 0
    )
    return [string]::Format($script:NativeCaptureInvariant, ('{0:N' + $Decimals + '}'), $Seconds)
}

# THE ENVIRONMENT VARIABLE THAT MAKES A NESTED GATE RUN LEGIBLE (issue #1717). Invoke-TestSuiteGate sets
# it for the children it spawns, so a gate running INSIDE one of them -- which is not hypothetical:
# test-suite-gate.tests.ps1 drives the gate over its own fixture, and any consumer testing this lib does
# the same -- reports depth 2 instead of being indistinguishable from the run that started it. A name
# nobody else is likely to hold, because this lib is mirrored into every consumer's plugin cache and a
# generic TEST_GATE_DEPTH would collide with whatever their own tooling means by it.
$script:GateDepthEnvName = 'DKJ_TEST_GATE_DEPTH'

function Get-GateNestingDepth {
    <#
        How deep the gate about to run is nested: 1 at the top level, parent + 1 inside another gate's
        child -- issue #1717.

        WHY A DEPTH AND NOT A PID. Both tell two runs apart; only a depth says WHICH of them is the one
        the operator is waiting on. #1717 measured three independent ways of deriving the gate's progress
        from outside, and the second failed exactly here: a watcher picking the newest
        'test-suite-gate-<pid>-<guid>' directory silently switched to a FIXTURE's directory mid-run and
        reported 26 started / 8 finished falling back to 3 / 0, which reads as the gate having restarted.
        A pid would have separated those two streams without ever saying which was the real one; 'depth 1'
        does, and it is the same one character to filter on in a CI log.

        MALFORMED IS TREATED AS ABSENT rather than as an error. This value crosses a process boundary
        into a variable anybody can set, and every wrong reading of it costs exactly one wrong number on
        a progress line -- so a non-numeric or negative value falls back to the top level, which is what
        an unnested run reports anyway. It never fails a gate over a diagnostic.
    #>
    $parsed = 0
    $raw = [Environment]::GetEnvironmentVariable($script:GateDepthEnvName, 'Process')
    if ($raw -and [int]::TryParse("$raw", [ref]$parsed) -and $parsed -gt 0) { return $parsed + 1 }
    return 1
}

function Format-GateProgressLine {
    <#
        The one line Invoke-TestSuiteGate prints every time a lane opens or a suite leaves one -- the
        progress signal the gate had none of until issue #1717, September 9, 2026.

        WHAT IT COST TO HAVE NONE. The gate buffers a suite's output until that suite exits and prints
        it as one block, so for the 15-30 minutes a local run takes the only signal was walls of output
        arriving in completion order with no index -- no way to tell 20/84 from 70/84 without counting
        headers by hand, and therefore no way to tell a slow run from a wedged one. That distinction is
        not cosmetic here: #1443 (an OOM at the default lane count) and #1701 (a subprocess bound
        exceeded under gate load) are both states where the run really has stopped making progress and
        looked identical to one that had not.

        STARTED IS REPORTED AS WELL AS DONE, and that is the half a naive fix leaves out. The queue
        dequeues longest-first since #1358, so with truthful hints the opening lanes hold the heaviest
        suites and NOTHING completes -- and therefore nothing is printed -- for the first ~15 minutes of
        an 84-suite run. A done-count alone sits at 0 through exactly the window an operator is asking
        the question in.

        WHY THE GATE EMITS THIS RATHER THAN A CALLER DERIVING IT. Three independent derivations from
        outside were tried and all three failed inside one afternoon (#1717): 'grep -c ^== ' on the log
        reported 175 of 84, because every suite prints headers of that shape and a failing one prints a
        second; watching the newest capture directory switched to a fixture's mid-run; and counting
        completed blocks sat at 0 for minutes for the reason above. Each is separately fixable, and the
        gate is the only party that knows the queue, the lane count and the pool size without inferring
        any of them.

        IT IS ITS OWN LINE AND DOES NOT TOUCH THE BLOCK HEADER, which is what #1717 proposed as the
        cheap version ('== [37/84] roster-sync.tests.ps1 =='). Printed immediately ABOVE the header it
        announces, it reads as that index and costs nothing that shape would have cost: '== <suite> =='
        stays byte-identical, so the suite's own output remains the very next line (asserted), and
        nothing that already matches a header has to learn a new one.

        AND IT CARRIES NO REMAINING-TIME ESTIMATE, deliberately. The duration hints the queue is ordered
        by are CI's seconds, and #1713 corrected this very file for claiming they convert to a local
        machine by a ratio -- the sign of the difference is not even fixed. An ETA computed from them
        would be that mistake again, printed 168 times a run. Counts and the gate's own elapsed clock are
        both measurements; the remainder is left unstated rather than guessed.

        NO SHARD NOTE EITHER, unlike the opening line and the verdict (#1318, #1351). Those two are the
        lines a session copies into a branch document, where a figure without its scope is unreadable
        later. This one is ephemeral by design -- it is superseded by the next event -- so it carries
        what a reader watching a run needs and nothing for the record.
    #>
    param(
        # 'started' or 'done' -- what just happened to $Suite. Not [ValidateSet]: this is a label on a
        # diagnostic, and a caller passing something else should print oddly rather than throw inside a
        # gate run.
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$Suite,
        [int]$Started = 0,
        [int]$Done = 0,
        [int]$Running = 0,
        [int]$Total = 0,
        [double]$Elapsed = 0,
        [int]$Depth = 1
    )
    # Every figure through Format-GateSeconds for the reason that function exists: a number whose meaning
    # depends on the machine's regional settings is the same defect as an untranslated string (#1159).
    return ("test gate: progress [depth {0}] {1}/{2} started, {3} done, {4} running (+{5}s) -- {6} {7}" -f `
        $Depth, $Started, $Total, $Done, $Running, (Format-GateSeconds $Elapsed -Decimals 1), $Action, $Suite)
}

function Write-GateCaptureBlock {
    <#
        ONE reaped suite's out.txt/err.txt, printed under the header the caller already wrote -- and a
        VISIBLE note when a writer still held one of them (issue #1731).

        WHY NOT Get-Content, WHICH IS WHAT STOOD HERE. This lib built Read-NativeCaptureFile for exactly
        the hazard the gate is most exposed to: a grandchild that inherited a suite's redirected stdout
        handle and outlives it, so the file is still open when the gate reads it the moment WaitForExit
        returns. Get-Content does not FAIL on that -- measured September 9, 2026, it opens the held file
        happily and returns whatever was flushed -- so the block printed short and nothing said so. That
        is this file's own recurring failure shape: a wrong answer arriving as a plausible value. The
        tolerant reader answers the same read AND says whether a writer held it.

        Read-NativeCaptureFile's docstring used to call itself internal with one caller. That sentence
        described the callers of the day rather than arguing the gate should not be one, and this is now
        the second.

        THE NOTE IS PRINTED, NOT RETURNED, because these blocks are read by a person and not by a caller
        that inspects a flag. WriterHeld on the Utf8 arm becomes ShortRead for a script to branch on; the
        only consumer here is the reader looking at the console, so a silent field would be the same
        defect in a new place.

        AND THE NOTE SURVIVES AN EMPTY READ -- that ordering is the point rather than a detail. The
        whitespace skip below exists so a suite with no stderr does not print a blank block, and it used
        to run before anything else. A held file that has flushed NOTHING yet is precisely "the child
        said nothing" against "we read before the flush", which is the ambiguity #1679 named, so skipping
        it silently would drop the note in the one case it matters most.

        THE SETTLE BUDGET IS THE FULL ONE, because a reaped suite is the clean-exit case
        Invoke-NativeCaptureUtf8 spends it on: the suite exited of its own accord, so its whole output
        exists and a lingering handle is a grandchild being reaped rather than a document that ends there.

        COST, MEASURED BEFORE ADOPTING IT (September 9, 2026 -- the check #1731 asked for). On files no
        writer holds, 170 reads -- 85 suites' worth of both captures -- cost 147 ms through this reader
        against 67 ms through Get-Content: 0.86 ms against 0.39 ms per file. That is ~80 ms on a run
        costing ~140 s, and the settle budget is not touched at all in that case; it is spent only where
        the alternative was a short block nobody could see was short. The decode is byte-identical.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Path
    )

    # -Encoding Oem matched what a redirected Windows PowerShell child writes (its
    # [Console]::OutputEncoding is the OEM codepage). Everything in scope here is ASCII by repo
    # convention, where every candidate decoder agrees; the choice only shows on a high byte that
    # reached a suite's output from a document it was reading. Get-Content's own `-Encoding Oem`
    # resolves to this same code page, so the swap changes the decode by nothing -- asserted in the
    # suite rather than assumed here.
    $oem = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)

    foreach ($f in @($Path)) {
        if (-not (Test-Path -LiteralPath $f)) { continue }
        $read = Read-NativeCaptureFile -Path $f -Encoding $oem `
                                       -SettleMilliseconds $script:NativeCaptureSettleMilliseconds
        if ($read.WriterHeld) {
            Write-Host ("[short read] a writer still held '" + (Split-Path -Leaf $f) + "' after the settle budget -- the block below may be truncated, or empty because nothing had been flushed yet (issue #1731).") -ForegroundColor Yellow
        }
        if ([string]::IsNullOrWhiteSpace($read.Text)) { continue }
        Write-Host $read.Text.TrimEnd()
    }
}

function New-ScratchPath {
    <#
        A path under the OS temp directory that NOBODY ELSE CAN NAME IN ADVANCE -- and, with
        -Directory, the directory itself, created here rather than by the caller.

        WHY THIS EXISTS RATHER THAN A Join-Path AT EACH CALL SITE (issue #1659). Seven sites in this
        script layer composed a temp path from a label and $PID alone, and $PID is neither secret nor
        large: a local actor who can write to the temp directory can pre-plant a symlink or a junction
        at the exact leaf before the script's first write. New-Item -ItemType Directory -Force and
        [System.IO.File]::WriteAllText both FOLLOW a reparse point, so the write lands wherever the link
        points. The content is not attacker-controlled at any of the seven, but the LOCATION is -- and
        two of them delete recursively at that path afterwards, which turns the same window into a
        delete primitive somewhere else.

        THE GUID CLOSES IT BY REMOVING THE TARGET, NOT BY CHECKING FOR ONE. Testing the composed path
        for a reparse point before writing was the other candidate and was declined: it is a
        check-then-write with a window between the halves, and it cannot be applied to the temp ROOT at
        all, because on macOS /tmp IS a symlink (to /private/tmp) -- a check there refuses a whole
        platform for the ordinary case. Nothing can be pre-planted at a name that does not exist until
        the moment it is used, so this function needs no such check and deliberately carries none.

        $PID STAYS IN THE LEAF, in front of the GUID. It buys nothing against an attacker and is not
        there for that: it is what makes a leftover attributable to a run that is still alive, which is
        exactly what the retained-capture note (#1636) and ship-pr's fold-worktree line print for a
        reader. scripts/README.md's fixture convention already names both spellings for that reason.

        THE LABEL IS VALIDATED, because it is the one half a caller composes: ship-pr's carries a PR
        number, verify-resolved-issues' an issue number and sync-main's a branch name. A segment held to
        [A-Za-z0-9._-] with no leading dot can hold no separator and no '..', so the result is a direct
        child of the temp directory whatever a caller passes it.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        # '.md', '.txt' -- for a FILE path. Omitted for a directory, and for a path something else
        # creates (git worktree add makes ship-pr's).
        [string]$Extension = '',
        # Create the directory here, and WITHOUT -Force: at a name nothing can have reached first, an
        # existing item means something is badly wrong and earns the throw rather than a silent reuse.
        [switch]$Directory
    )

    if ($Label -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "New-ScratchPath: -Label '$Label' is not a single safe path segment (letters, digits, '.', '_' and '-', not starting with a dot)."
    }
    if ($Extension -and $Extension -notmatch '^\.[A-Za-z0-9]+$') {
        throw "New-ScratchPath: -Extension '$Extension' is not a plain dotted extension (e.g. '.md')."
    }

    $leaf = "$Label-$PID-" + [guid]::NewGuid().ToString('n') + $Extension
    # The marker is what native-capture.tests.ps1's scan reads: this one line cannot carry the guid the
    # rule asks for, because it is the line that USES the guid built above. Declared at the site rather
    # than matched by its source text, so renaming $leaf or reflowing this line does not turn the scan
    # against its own composer.
    $path = Join-Path ([System.IO.Path]::GetTempPath()) $leaf # temp-path-exempt: this IS the composer
    if ($Directory) { New-Item -ItemType Directory -Path $path | Out-Null }
    return $path
}

function ConvertTo-NativeArgumentToken {
    <#
        One argument, quoted the way CreateProcess parses it back apart. Start-Process joins
        -ArgumentList on SPACES and quotes nothing, so an argument carrying a space would arrive at the
        child as two -- which is why this exists and why it is not needed on the & path, where
        PowerShell does the quoting itself.

        The backslash rule is the fiddly half and it is not optional: inside quotes, a run of
        backslashes immediately before the closing quote is halved by the parser, so a value ending in
        '\' would escape the very quote that terminates it. Doubling that run is the documented fix.
        An empty string becomes '""', which is a real argument rather than nothing at all.

        Internal to this lib (no export, no contract row): it exists only to serve the -Utf8 path
        below.
    #>
    param([AllowEmptyString()][Parameter(Mandatory = $true)][string]$Value)

    if ($Value -eq '') { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }

    # Double any backslash run that precedes a quote, and any that ends the value; escape the quotes.
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Get-NativeArgumentDefect {
    <#
        The SHAPE of one argument the & operator cannot hand to a child faithfully, or '' where it can.
        Pure string in, string out -- the whole predicate behind Invoke-NativeCapture's refusal below,
        in a function a test can hold against a real argv probe rather than against a copy of itself.

        THREE SHAPES, AND THE PREDICATE IS EXACT RATHER THAN CAUTIOUS (issue #1966, measured
        September 14, 2026 against a compiled C# probe printing each argv element with its length; 800
        random argument sets, 239 mis-delivered, 0 false positives and 0 false negatives against this
        function). That matters more than it looks: a guard that over-refuses would make the & arm
        unusable for ordinary text, and one that under-refuses leaves exactly the silent class it was
        built to end.

          'empty'              -- the empty string is DROPPED, shifting every later argument one place
                                  left. The child is handed a different command line, not a shorter one.
          'quote'              -- a value containing '"' loses the quote AND swallows what follows it:
                                  without whitespace the bare quote opens an argv region, with
                                  whitespace PowerShell's own quoting fails to escape the inner one.
          'trailing-backslash' -- whitespace PLUS a trailing '\' escapes the closing quote PowerShell
                                  added, so the region never ends and the rest of the line is absorbed.

        A TRAILING BACKSLASH WITHOUT WHITESPACE IS FINE and is deliberately not refused -- nothing
        quotes it, so nothing mis-escapes it. That is why the third shape is one clause and not two, and
        it is the clause a "be safe, refuse every backslash" reading would get wrong: 'C:\repo\' is an
        ordinary path argument and passes through this arm unharmed.
    #>
    param([AllowEmptyString()][AllowNull()][Parameter(Mandatory = $true)][string]$Value)

    if ($null -eq $Value -or $Value -eq '') { return 'empty' }
    if ($Value.Contains('"')) { return 'quote' }
    if ($Value -match '\s' -and $Value.EndsWith('\')) { return 'trailing-backslash' }
    return ''
}

function Get-NativeArgumentRefusal {
    <#
        The refusal message for an argument list the & operator cannot pass faithfully, or '' where
        every element survives it. Pure array in, string out; Invoke-NativeCapture throws whatever this
        returns, so the wording is testable without starting a process.

        IT NAMES THE INDEX AND THE SHAPE AND NEVER THE VALUE (issue #1313). An argument on this path can
        carry a token or a remote URL, and what WE compose is what reaches a log unredacted -- git
        redacts its own output, nobody redacts ours. The index plus the shape is enough for the caller to
        find the argument in their own code, which is where the value already is.

        IT POINTS AT -Utf8 RATHER THAN AT A WORKAROUND, because that arm quotes the arguments itself
        (ConvertTo-NativeArgumentToken above) and delivers all three shapes intact -- measured 0/300 in
        the same run that measured 129/300 here. The file-based idiom -- git's -F, gh's --body-file --
        is the other way out and is what park-lib and verify-resolved-issues already use.
    #>
    param([AllowEmptyCollection()][AllowNull()][string[]]$Arguments)

    if ($null -eq $Arguments -or $Arguments.Count -eq 0) { return '' }

    $bad = @()
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $shape = Get-NativeArgumentDefect -Value $Arguments[$i]
        if ($shape) { $bad += "index ${i} (${shape})" }
    }
    if ($bad.Count -eq 0) { return '' }

    return ("Invoke-NativeCapture: " + $bad.Count + " argument(s) cannot be passed faithfully by the & " +
        "operator -- " + ($bad -join ', ') + ". Windows PowerShell 5.1 would hand the child a DIFFERENT " +
        "command line, silently and at exit code 0. Pass -Utf8 (Start-Process quotes the arguments " +
        "itself and delivers all three shapes intact), or use the file-based idiom -- git's -F, gh's " +
        "--body-file. The value is deliberately not printed here: an argument on this path can carry a " +
        "token or a remote URL (#1313). Measurement and shapes: issue #1966.")
}

function Push-NativeNonInteractiveEnv {
    <#
        Set the non-interactive environment for the child about to be started and hand back what was
        there before, for the finally to put back. Internal to this lib (no export, no contract row).

        [Environment]::SetEnvironmentVariable rather than $env:NAME = ... for ONE reason that matters:
        it can write $null, which REMOVES the variable. `$env:NAME = $null` in Windows PowerShell 5.1
        leaves an empty-string variable behind, and empty is not absent -- git reads a defined
        GIT_TERMINAL_PROMPT='' differently from an undefined one, so restoring with the assignment
        form would leave every script that ran a single git call in a state it did not start in.

        The previous value is captured BEFORE the set, per name, so a caller that deliberately set one
        of these itself (a test, a consumer's wrapper) gets its own value back rather than ours.
    #>
    $previous = @{}
    foreach ($name in @($script:NativeCaptureNonInteractiveEnv.Keys)) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $script:NativeCaptureNonInteractiveEnv[$name], 'Process')
    }
    return $previous
}

function Pop-NativeNonInteractiveEnv {
    <#
        Put back what Push-NativeNonInteractiveEnv handed over. Internal to this lib.

        Runs from a finally, so it must not throw whatever it is given: a $null (the push never ran
        because Start-Process threw first) is a no-op rather than an error, because an exception raised
        HERE would replace the one the caller is actually trying to report.
    #>
    param([AllowNull()][hashtable]$Previous)

    if (-not $Previous) { return }
    foreach ($name in @($Previous.Keys)) {
        [Environment]::SetEnvironmentVariable($name, $Previous[$name], 'Process')
    }
}

function Stop-NativeProcessTree {
    <#
        Kill a timed-out child AND ITS CHILDREN. Internal to this lib.

        /T IS THE ENTIRE POINT, and it is what the measurement in #1179 argues for: the process that
        blocked was not the `git.exe push` (PID 11372) but the `git credential-manager get` it spawned
        (PID 27176), and killing only the parent leaves that one holding the prompt. taskkill is the
        one tool on Windows that walks the tree; Stop-Process signals a single process.

        BOTH ATTEMPTS ARE ALLOWED TO FAIL, and that is deliberate rather than sloppy. taskkill reports
        "not found" for a child that exited in the gap between the wait giving up and this call, and it
        can be refused for a process this session may not signal. By the time we are here the wait has
        already stopped waiting, so failing is better than throwing -- a throw would replace a
        diagnosable timeout with an unrelated error.

        WHAT A FAILED OR SLOW KILL COSTS IS NOT ONLY A STRAY PROCESS, and this paragraph said for months
        that it was (#1852). THIS FUNCTION IS NOT THE END OF THE TIMEOUT PATH: its caller waits up to five
        more seconds to reap the child and then reads the capture files regardless. So a child that
        outlives the kill -- because taskkill was refused, OR merely because taskkill.exe's own cold
        startup under load took longer than the child had left to run -- finishes inside that grace
        window, and its FULL output is read back and returned as Output with TimedOut = $true. Measured
        September 11, 2026 in CI under the test gate's sixteen lanes: a 5s child under a 1s bound came
        back complete, and connector-sessioncheck.ps1 -- which picked its verdict from Output's content
        and never read TimedOut -- printed the killed run's answer as a clean version check.

        SO THE ANSWER IS STILL NOT TO THROW HERE, and nothing below this line changed: a kill is
        best-effort by nature, and no amount of trying makes the read that follows it unambiguous. The
        answer is at the CALLER, and the fields it needs already exist -- TimedOut and ShortRead say what
        the exit code and the content cannot. Read them before parsing Output. What was wrong was this
        paragraph telling a caller there was nothing here to read.

        taskkill writes to stderr, so its call is bracketed with EAP=Continue for the #96/#107 reason
        this whole lib exists for. The -Utf8 arm that calls this does NOT set EAP itself (it has no &
        call to protect), so the caller's 'Stop' would otherwise be live right here.
    #>
    param([Parameter(Mandatory = $true)][int]$ProcessId)

    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & taskkill.exe '/PID' "$ProcessId" '/T' '/F' 2>&1 | Out-Null
    } catch {
        # Deliberately swallowed -- see the docstring.
    } finally {
        $ErrorActionPreference = $prevEap
    }

    Get-Process -Id $ProcessId -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

function New-NativeCaptureBudget {
    <#
        A RUN-WIDE DEADLINE FOR NETWORK CALLS -- issue #1958. See the
        $NativeCaptureHookNetworkBudgetSeconds block above for why a hook needs one and why a smaller
        per-call bound is not the same thing.

        $TotalSeconds of 0 (the default) is the NO-BUDGET shape, and it is the ordinary one: a script
        somebody typed has no ceiling to finish inside, so every call keeps the standing per-call bound.
        That is what makes this safe to thread through a script's network calls unconditionally -- the
        by-hand run is byte-for-byte the behaviour it had before the budget existed.

        A PLAIN OBJECT WITH AN ABSOLUTE EXPIRY, not a Stopwatch. The three readers below only ever ask
        "how much is left", a UTC instant answers that with no state to start, stop or forget to pass on,
        and a test can build one by hand to exercise the exhausted arm without waiting for it.

        -ExpiresUtc STATES THAT INSTANT DIRECTLY, and it WINS over -TotalSeconds (#2077). A duration is
        measured from whenever this function happened to be called, which under a hook is after the
        script's own start-up and lib loading -- time the hook's ceiling has already spent. A caller that
        KNOWS the deadline can now say it, which is strictly more correct than re-deriving it here: it
        makes the budget a fact about the turn rather than about this process. Pass a DateTime whose
        value is UTC ([DateTimeOffset]::FromUnixTimeSeconds(n).UtcDateTime is the shape the callers
        have); the readers below subtract it from UtcNow and never convert it.

        TotalSeconds is then what the budget had LEFT at creation, floored at 0, so the object stays
        self-consistent for anything that reads that field. A deadline already past yields an Expires
        that is set and spent, which is the honest answer and the one every reader below already handles.
    #>
    param(
        [int]$TotalSeconds = 0,
        [datetime]$ExpiresUtc = ([datetime]::MinValue)
    )

    if ($ExpiresUtc -ne [datetime]::MinValue) {
        $leftAtBirth = [int][math]::Floor(($ExpiresUtc - (Get-Date).ToUniversalTime()).TotalSeconds)
        if ($leftAtBirth -lt 0) { $leftAtBirth = 0 }
        return [pscustomobject]@{ TotalSeconds = $leftAtBirth; Expires = $ExpiresUtc }
    }

    $expires = $null
    if ($TotalSeconds -gt 0) { $expires = (Get-Date).ToUniversalTime().AddSeconds($TotalSeconds) }
    return [pscustomobject]@{ TotalSeconds = $TotalSeconds; Expires = $expires }
}

function Test-NativeCaptureBudgetSet {
    <#
        Is there a budget at all? Separated from "is there room in it" because the two mean OPPOSITE
        things at the call site: no budget means every call proceeds under the standing bound, and an
        exhausted budget means the call must not be made. A single function returning seconds would
        answer 0 to both -- which is precisely the two-opposite-facts-in-one-boolean shape #1628 took out
        of claim-issue's read-back, and it is not being reintroduced here.

        READ THROUGH PSObject.Properties, not $Budget.Expires: Set-StrictMode -Version Latest THROWS on a
        property an object does not carry, and this lib is loaded by scripts whose whole contract is that
        they never fail. A malformed budget must cost the bound, never the run.
    #>
    param($Budget)

    if ($null -eq $Budget) { return $false }
    $prop = $Budget.PSObject.Properties['Expires']
    return [bool]($prop -and $null -ne $prop.Value)
}

function Get-NativeCaptureBudgetSecondsLeft {
    <#
        Seconds left on a budget, floored at 0 and never negative. Answers 0 for a budget that is not set
        as well as for one that is spent, which is why every caller asks Test-NativeCaptureBudgetSet
        first -- see its own note.
    #>
    param($Budget)

    if (-not (Test-NativeCaptureBudgetSet -Budget $Budget)) { return 0 }
    $left = ($Budget.PSObject.Properties['Expires'].Value - (Get-Date).ToUniversalTime()).TotalSeconds
    if ($left -le 0) { return 0 }
    return [int][math]::Floor($left)
}

function Test-NativeCaptureBudgetHasRoom {
    <#
        MAY THIS CALL BE MADE AT ALL? $true when there is no budget (nothing constrains the call) and when
        at least $NativeCaptureHookNetworkFloorSeconds remain; $false when the budget is spent, which the
        caller reports as a skipped call rather than making one it cannot finish.
    #>
    param($Budget)

    if (-not (Test-NativeCaptureBudgetSet -Budget $Budget)) { return $true }
    return ((Get-NativeCaptureBudgetSecondsLeft -Budget $Budget) -ge $script:NativeCaptureHookNetworkFloorSeconds)
}

function Get-NativeCaptureBudgetBound {
    <#
        THE -TimeoutSeconds A NETWORK CALL SHOULD PASS RIGHT NOW: the standing bound where there is no
        budget, and otherwise whatever is smaller -- the standing bound or what the budget has left. Ask
        Test-NativeCaptureBudgetHasRoom first; on a spent budget this returns the floor rather than 0,
        deliberately, because 0 is Invoke-NativeCapture's UNBOUNDED value and a guard that fails open into
        an unbounded network call inside a hook would reinstate the exact defect #1958 is about.
    #>
    param($Budget)

    if (-not (Test-NativeCaptureBudgetSet -Budget $Budget)) { return $script:NativeCaptureNetworkTimeoutSeconds }
    $left = Get-NativeCaptureBudgetSecondsLeft -Budget $Budget
    if ($left -lt $script:NativeCaptureHookNetworkFloorSeconds) { return $script:NativeCaptureHookNetworkFloorSeconds }
    if ($left -lt $script:NativeCaptureNetworkTimeoutSeconds) { return $left }
    return $script:NativeCaptureNetworkTimeoutSeconds
}


function Get-NativeLineText {
    <#
        One object from a capture's Output, as the text a reader should see. Internal to this lib, and
        used at BOTH levels since #2155: Invoke-NativeCapture's & arm runs every line through it, so
        Output holds plain text on both arms, and Get-NativeOutputText below runs it again over an
        Output a caller hands back (which may come from an older copy of this lib, or from the days
        before that decision -- see its own docstring).

        A '2>&1' redirect turns every stderr line into an ErrorRecord wrapping a RemoteException, and
        under PowerShell 5.1 that record carries its own positional info: a CategoryInfo line, a
        FullyQualifiedErrorId line, and a source-line caret pointing at whichever line of THIS lib ran
        the command. Rendering such a record with Out-String prints all of it.

        TargetObject IS READ FIRST -- it is the raw stderr line, string-typed, empty string and all --
        with the exception's message as the fallback for a record that is not a native stderr line.
        That order is Get-ShopifyLineText's, in shopify-cli-lib.ps1, and for the reason measured there
        and re-measured here against a powershell.exe child writing three stderr lines with an empty
        one in the middle: on that middle record TargetObject came back String-typed and empty,
        Exception.Message empty, and [string]$Line the TYPE NAME -- so a caller got a literal
        'System.Management.Automation.RemoteException' where the command's own blank line belonged.
        The two libs stay separate copies rather than one shared helper because shopify-cli-lib
        deliberately does not dot-source this file -- see its header for why its wrapper is
        purpose-built, and Get-ShopifyLineText's own docstring for the trade written out. That reason
        is the answer to #2158, which asked the question from the other side.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()]$Line)

    if ($null -eq $Line) { return '' }
    if ($Line -is [System.Management.Automation.ErrorRecord]) {
        if ($Line.TargetObject -is [string]) { return [string]$Line.TargetObject }
        return [string]$Line.Exception.Message
    }
    return [string]$Line
}

function Get-NativeOutputText {
    <#
        A capture's Output as PLAIN, TRIMMED TEXT -- what '($res.Output | Out-String).Trim()' was
        always meant to produce. Pass it $res.Output; it returns a string.

        WHY THIS EXISTS RATHER THAN Out-String (issue #2154). On the '&' arm, Output carried
        ErrorRecords for every stderr line, and Out-String renders a record's full exception display.
        So a caller interpolating a failure reason into an operator-facing message printed git's one
        line followed by a CategoryInfo/FullyQualifiedErrorId block and a caret pointing into
        native-capture-lib.ps1 -- naming a file the operator did not run and cannot act on. Measured on
        prune-merged's refused-delete verdict, where 'error: the branch ... is not fully merged' -- the
        whole of what the reader needed -- arrived buried in nine lines of exception text.

        #2155 THEN DECIDED THE WIDER QUESTION THIS FUNCTION DELIBERATELY LEFT OPEN, AND DECIDED IT THE
        OTHER WAY (Dave, September 19, 2026). This docstring used to argue that normalising at the
        capture would give every caller in every consumer a different result shape, and that the loud,
        additive form here was the one available without taking that decision. The decision was taken:
        the & arm normalises, on the measurement that the old shape was not merely a different shape
        but a WRONG RENDER, and on shopify-cli-lib having already made the same call for a lib mirrored
        the same way. So the paragraph is corrected rather than left standing -- an argument for a road
        not taken reads as current policy once the fork is behind you.

        THE FUNCTION IS NOT REDUNDANT AFTER THAT, and this is the half worth reading before proposing
        its removal. Out-String is still not the same thing: this one TRIMS and normalises line endings
        to "`n", which is what its ~seven callers actually want and what Out-String's console-width
        padding and trailing newline do not give them. And it is still the only correct reader for an
        Output that did NOT come from this copy of the lib -- a capture handed across from a consumer
        on an older plugin release, where the & arm still returns records. Get-NativeLineText is a
        no-op on a string, so running it over an already-normalised Output costs one call per line and
        cannot be wrong.

        SAFE ON ANYTHING Output CAN HOLD: $null, a single object, or an array. Line endings are
        normalised to "`n" so a caller splitting the result does not have to care which arm answered.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()]$Output)

    if ($null -eq $Output) { return '' }
    $lines = @(@($Output) | ForEach-Object { Get-NativeLineText $_ })
    return ($lines -join "`n").Replace("`r`n", "`n").Trim()
}

function New-NativeNotStartedCapture {
    <#
    .SYNOPSIS
        The capture Invoke-NativeCapture returns when the child NEVER STARTED -- the executable is not
        on PATH, or the OS refused to launch it (issue #2234).

    .DESCRIPTION
        THE THIRD STATE ON ExitCodeUnknown'S OWN AXIS, and the reason it is a state rather than a guard
        at each call site. Until this existed, a missing executable was the one outcome of a capture that
        a caller could not read at all: BOTH arms threw before composing anything, so there was no
        ExitCode, no ExitCodeUnknown, no TimedOut and no Output to judge. Under a caller's
        $ErrorActionPreference = 'Stop' -- which every task script in this workflow sets on line 1 --
        that ended the whole run rather than the one call.

        BOTH ARMS THREW, WHICH IS ONE STEP PAST WHAT #2234 MEASURED and is why the repair is here rather
        than in Start-Process's arm alone. The report measured the Start-Process arm, where a missing
        file surfaces as InvalidOperationException out of the cmdlet. The & arm throws too, earlier and
        for a different reason: command DISCOVERY fails with CommandNotFoundException, which is a
        terminating error that $ErrorActionPreference = 'Continue' does not suppress -- so this
        function's own EAP dance, which exists precisely so a caller gets a verdict rather than an
        exception, never reached it. A repair on one arm would have left `gh` missing fatal on every
        unbounded call in the family, which is most of them.

        WHY A GUARD AT EACH CALL SITE WAS REFUSED. There were two unguarded sites when this was written
        -- new-branch.ps1's already-done check and fold-changelog-entry.ps1's PR enrichment, both of them
        OPTIONAL enrichment whose own docstrings promise they degrade -- and the objection is that the
        third one is written by whoever forgets. A missing executable is a fact about the call, and this
        lib already has the vocabulary for exactly that class of fact.

        THE FIELDS, AND WHY ExitCodeUnknown IS $true HERE. A caller reads one field whichever arm
        answered it, which is the promise TimedOut and ShortRead already make -- so a never-started child
        reports the exit code it does not have the same way a raced one does:

          - Output          : one '[not-started]' line naming the command and the launcher's own reason,
                              because that is where every existing caller already looks. It is safe to
                              append here where ExitCodeUnknown's own docstring refuses to append for the
                              race: a child that never started wrote no stdout, so there is no
                              machine-readable capture to corrupt -- and ExitCode is $null, so every
                              site that parses Output gates on `-eq 0` and never reaches the parse.
          - ExitCode        : $null. There is no exit code, and a substituted number would be a verdict
                              this function invented -- which is the distinction TimedOut's own 124 is
                              careful to be on the other side of.
          - ExitCodeUnknown : $true. NOT because the child ran, but because the FIELD'S QUESTION is "is
                              ExitCode a measurement of how it ended", and the answer is no. Setting it
                              $false and relying on NotStarted alone was considered and is measurably
                              worse: a site reading ExitCodeUnknown directly would then treat $null as
                              measured, land on `$null -ne 0`, and print "(exit )" -- the empty-number
                              sentence #2081 was filed to end. So ExitCodeUnknown's documented meaning
                              widens to "ExitCode is not a measurement", and NotStarted says WHICH of the
                              two reasons it is.
          - TimedOut        : $false. Nothing was waited on.
          - ShortRead       : $false. No capture file was read.
          - NotStarted      : $true, and $false on every other return from both arms.

        THE ONE THING THE FIELD BUYS THAT ExitCodeUnknown CANNOT is the WORDING, and it is not cosmetic:
        Get-NativeExitLabel's unmeasured sentence says "the child ran" and advises "this normally settles
        on a re-run". Both are false here and the second is actively misleading -- a command that is not
        installed does not settle on a re-run. The two sites in this family that RE-ASK on an unmeasured
        code (claim-issue's read, park-cycle's PR check) read this field for the same reason: a second
        launch of a command that does not exist buys nothing and reports "answered twice" about a child
        that never answered once.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Reason
    )

    # ONE LINE, AND THE SHAPE MATCHES THE TIMEOUT DIAGNOSIS ABOVE IT -- a '[tag]' prefix, the command in
    # quotes, then the reason -- because a reader meeting either one is reading the same console and the
    # two answer the same question about the same call.
    #
    # $FilePath IS A CALLER-CHOSEN LITERAL, AND THAT IS A CONSTRAINT RATHER THAN AN OBSERVATION. The line
    # below interpolates it, and $Reason, into text a console and an agent session both read -- with no
    # control-character strip, unlike ConvertTo-ConsoleStrippedText which claim-issue-lib applies to
    # TRACKER-supplied text, and no masking, unlike Format-UrlForDisplay. That is sound only because
    # every call site in this tree passes a hardcoded literal ('gh', 'git', 'powershell'), so $Reason can
    # only ever echo one of those back; verified across the tree when this was written.
    #
    # SO A CALLER MUST NOT DERIVE $FilePath FROM TRACKER, BRANCH OR USER CONTENT. The library cannot
    # enforce it -- the parameter is a plain [string] -- and the rule is written here because one nobody
    # wrote down is one the next caller gets to discover. A call site that genuinely needs a
    # caller-supplied path strips it first, the way park-cycle and claim-issue already do with a branch
    # name. Raised in security review on this branch, not exploitable as the tree stands, and recorded
    # because this shape is exactly what made those two existing rules necessary.
    $line = "[not-started] '$FilePath' could not be started: $Reason"
    return [pscustomobject]@{
        Output          = @($line)
        ExitCode        = $null
        TimedOut        = $false
        ShortRead       = $false
        ExitCodeUnknown = $true
        NotStarted      = $true
    }
}

function Test-NativeCommandStarted {
    <#
    .SYNOPSIS
        Did the child actually start? $false only for a capture New-NativeNotStartedCapture made.

    .DESCRIPTION
        THE ASK, on Test-NativeExitMeasured's precedent one function down, and property-guarded for the
        same reason: a caller can be holding a capture object made by an OLDER copy of this lib -- the
        plugin mirror lags its own source by however many merges have landed -- and under
        Set-StrictMode -Version Latest a bare $Capture.NotStarted THROWS on an object without the field.

        THE MISSING FIELD ANSWERS $true, and that is the honest default rather than the convenient one:
        before this field existed a capture object could not be produced at all unless the child had
        started, because the launch failure threw instead. So "no field" really does mean "it started",
        and the degrade is exact rather than merely safe.

        A NULL CAPTURE ANSWERS $false -- the call did not happen, which is the strongest possible
        statement that nothing was started. Same answer shape as Test-NativeExitMeasured gives $null, and
        for the same reason.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()]$Capture)

    if (-not $Capture) { return $false }
    if ($Capture.PSObject.Properties['NotStarted'] -and $Capture.NotStarted) { return $false }
    return $true
}

function Invoke-NativeCapture {
    <#
        Run $FilePath with $Arguments under $ErrorActionPreference = 'Continue' and return a
        pscustomobject with:
          - Output   : the command's output, AS PLAIN TEXT ON BOTH ARMS (issue #2155). By default
                       stderr is merged in (2>&1) so a caller can echo full progress; with
                       -DiscardStderr stderr is dropped (2>$null) so it cannot pollute a
                       machine-readable stdout (e.g. gh --json).
                       THE ELEMENT TYPE IS THE PROMISE, NOT THE CONTAINER. Both arms hand back strings;
                       what still differs is the container, and deliberately so -- the -Utf8 arm always
                       returns an array of lines, while this arm keeps PowerShell's own unrolling
                       ($null / scalar / array). A caller that wants one shape asks for it the way it
                       always did: @($res.Output), or $res.Output | Out-String.
                       WHY IT IS A PROMISE AT ALL: with 2>&1 the & operator hands back an ErrorRecord
                       per stderr line, and rendering one costs a caller the command's own words twice
                       over -- the first record stringifies as a full PowerShell exception dump naming
                       THIS file and line, and an EMPTY stderr line stringifies as the literal
                       'System.Management.Automation.RemoteException'. See Get-NativeLineText above for
                       the measurement and for which field is read instead.
          - ExitCode : $LASTEXITCODE recorded immediately after the command ran.
          - TimedOut : $true only when -TimeoutSeconds was given AND expired. Present on every return
                       from both arms, so a caller never has to know which arm answered it.
          - ShortRead: $true when a capture file was STILL HELD BY A WRITER when it was read, so
                       Output may be truncated -- or empty -- with ExitCode 0. THE POINT IS THAT AN
                       EMPTY Output IS NOW ANSWERABLE (issue #1679): before this field, a caller
                       could not tell "the child said nothing" from "we read before the flush", and
                       five callers in this family resolved that toward a substantive answer -- "no
                       PR", "no issue declared", "the body does not carry the section". Always $false
                       on the & arm, which has no capture file; see Read-NativeCaptureFile for why the
                       flag is honest rather than defensive, and for the settle wait that removes most
                       occurrences of it.
                       A CALLER THAT PARSES Output MUST READ IT. Two sites in this repo can produce an
                       empty capture LEGITIMATELY -- `git show --name-status --format=` on a commit
                       that changed no files, and `gh --json body -q .body` on a PR with an empty body
                       (both measured, 0 bytes, exit 0) -- so "empty means the read failed" is not a
                       rule a caller may assume. This field is the only thing that separates them.
          - NotStarted: $true when the child NEVER RAN -- the executable is not on PATH, or the OS
                       refused to launch it (issue #2234). Present on every return from both arms, so a
                       caller never has to know which arm answered it. THIS USED TO BE THE ONE OUTCOME
                       WITH NO FIELD AT ALL: both arms threw before composing anything, and under a
                       caller's $ErrorActionPreference = 'Stop' -- which every task script in this
                       workflow sets on line 1 -- that ended the whole run rather than the one call.
                       Read it with Test-NativeCommandStarted, which is property-guarded for a capture
                       made by an older copy of this lib. See New-NativeNotStartedCapture above for the
                       full argument, including why a guard at each call site was refused and why BOTH
                       arms needed the repair rather than the Start-Process one #2234 measured.
          - ExitCodeUnknown: $true when ExitCode is NOT a measurement of how the child ended -- issue
                       #1931. IT USED TO SAY "when the child RAN and ExitCode is not a measurement of
                       it", and #2234 widened it by one case rather than changing its question: a child
                       that never started has no exit code either, so it sets this field too. That is
                       deliberate and is what keeps every site audited under #2081 correct without being
                       touched -- a site reading this field directly would otherwise treat $null as
                       measured and print "(exit )", the empty-number sentence that audit was filed to
                       end. NotStarted says WHICH of the two reasons it is, and the only callers that
                       need to know are the two that re-ask. THE REST OF THIS ENTRY IS ABOUT THE RACE,
                       which is the case it was built for. THIS IS NOT WHAT #1931 ITSELF CLAIMS: its text says #1920 already added
                       this field to both arms, so the state was merely unconsulted. That is not what
                       the tree held when this was picked up -- `ExitCodeUnknown` did not exist
                       anywhere in scripts/ (grep confirms it), and #1920's own fix narrowed
                       Test-GitCanCommit to refuse on the single git exit code 128 rather than adding a
                       reportable field to this function. The premise was wrong; the ask -- a
                       consultable field, on the ShortRead precedent -- was not, so this is that field,
                       built rather than merely wired up.

                       CONFINED TO THE -Utf8/Start-Process ARM, AND MEASURED RATHER THAN ASSUMED. #1931
                       reports 27 of 960 captures (2.8%) under 16 lanes of fresh PowerShell children,
                       and that it never recovers inside a 200ms re-read budget. Reproduced independently
                       while building this field (September 13, 2026): 300 fresh `powershell.exe`
                       children, each running exactly the documented pattern below (Start-Process
                       -PassThru, read .Handle, unbounded WaitForExit(), read .ExitCode) against a
                       trivial `cmd.exe /c exit 0` -- 1 of 300 came back with .ExitCode LITERALLY $null
                       (PowerShell's own $null, not a 0 or a thrown exception; System.Diagnostics.Process
                       does not expose a nullable ExitCode, so this is .NET handing back an uninitialised
                       value rather than the documented type). The SAME test against the & operator's
                       $LASTEXITCODE, 300 fresh children, came back real every time -- matching #1931's
                       own confinement to "the first Start-Process in a fresh process" and matching why
                       ShortRead is a Start-Process-only field too (no capture file, no OS handle race,
                       on the & arm). $LASTEXITCODE is still checked below, for the same reason ShortRead
                       is reported ($false rather than omitted) on the arm that cannot produce it: a
                       caller reads one field whichever arm answered it, and never has to know which arm
                       that was.

                       NOT REPAIRED BY RETRYING, deliberately -- #1931 already measured that a 200ms
                       re-read budget still leaves 7 of 240 unresolved, so a retry loop here would spend
                       wall-clock on every capture for a recovery that is not reliable. The field reports
                       the state honestly instead; see Get-GitFileTextAtRef below for the one caller in
                       this file that turns it into a refusal rather than a silent wrong answer.
        EAP and the environment are always restored (finally), whether the command succeeds, fails, or
        throws.

        -DiscardStderr IS NOT A CREDENTIAL GUARD, AND THAT WAS MEASURED (issue #1313). The reason to
        pass it is the one above: stderr merged into output a caller then PARSES. It is tempting to
        reach for it as a security flag as well -- a git call that talks to the remote writes all of
        its output to stderr, and its failure line quotes the remote URL -- but git redacts that URL
        itself. Measured on git 2.55.0.windows.5: `user:token@host`, `token@host` and an unresolvable
        host all came back as a bare `https://host/o/r.git`, because the "unable to access" and
        "Authentication failed" messages go through transport_anonymize_url, which strips userinfo. A
        token somewhere ELSE in the URL (a query string, a path segment) is printed verbatim -- also
        measured -- but that is not a shape any remote of this family uses.

        SO THE TRADE RUNS THE OTHER WAY on a network call, and #1313 is the worked example: it proposed
        the flag for the `git fetch` in ship-pr.ps1's fold step, in worktree-lane.ps1 and in
        prune-merged.ps1, and applying it would have removed git's own diagnosis from three failure
        paths -- one of them the step where the PR is ALREADY MERGED and git's reason is all a reader
        has -- in exchange for nothing. Declined on that measurement, and the same measurement is why
        Invoke-GitPark's `git push` keeps stderr on purpose (#1143): git's words there are the answer.

        WHERE A CREDENTIAL REALLY DOES REACH A LOG is where WE compose the line rather than git. A URL
        an operator handed us, interpolated into our own Write-Host or our own throw message, gets no
        redaction from anybody -- that was the standing half of #1313, in publish-to-business.ps1, and
        the fix there is to mask the userinfo before printing (Format-UrlForDisplay), not to drop
        stderr. If you are about to print a URL, mask it; if you are about to hide git's output, ask
        what the reader is left with.

        -Utf8: DECODE THE OUTPUT AS UTF-8 INSTEAD OF WITH THE CONSOLE CODE PAGE (issue #907,
        August 26, 2026). Windows PowerShell 5.1 decodes a native child's stdout with
        [Console]::OutputEncoding, so the SAME command returns different strings on cp65001 and cp850.
        For a progress line that is cosmetic; for output the caller then PARSES or COMPARES it is a
        wrong answer that arrives as a plausible value. Measured on the DEPLOY lock: gh's UTF-8
        em-dash 'e2 80 94' came back as 'c3 94 c3 87 c3 b6' on a cp850 console, so the lock refused a
        PR whose body was intact and named a line that reads as correct -- in a gate with no -Force.
        Pass -Utf8 wherever the output is DATA rather than progress.

        WHY A REDIRECT AND NOT [Console]::OutputEncoding = UTF8 AROUND THE CALL. That setter is
        SetConsoleOutputCP: console-WIDE, not per-process. The test gate runs every suite with
        -NoNewWindow on one shared console, and a sibling holding UTF-8 is exactly how inbound #821
        stayed invisible -- an assert green under the gate and red on its own.
        .claude/rules/language-layers.md states the prohibition outright. Redirecting to a file and
        reading it with an explicit UTF-8 decode touches no shared state and is provably immune:
        measured identical on cp65001, cp850 and cp437.

        THE -Utf8 PATH IS A DIFFERENT MECHANISM, not a flag on the same one, so two things differ and
        both are deliberate. Output comes back as an ARRAY OF LINES, always -- where the & arm returns
        strings too since #2155 but keeps PowerShell's unrolling, so a one-line capture is a scalar on
        the & arm and a 1-element array on this one. (The arms are named rather than pointed at: the
        two passages that describe this pair sit either side of the dispatch below, so 'here' and
        'there' swap referents between them -- which is why the #1963 block further down says 'this
        arm' throughout.) And the child is started by Start-Process, so $Arguments are
        quoted here rather than by PowerShell; see ConvertTo-NativeArgumentToken above.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$DiscardStderr,
        [switch]$Utf8,
        [int]$TimeoutSeconds = 0
    )

    # A BOUND IMPLIES THE Start-Process ARM, because the & operator cannot be interrupted: it hands
    # control to PowerShell's own pipeline reader until the child exits, and there is no handle to wait
    # on with a deadline. The -Utf8 arm already starts the child with -PassThru, which is exactly the
    # handle a bounded wait needs -- so -TimeoutSeconds routes there whether or not -Utf8 was asked for.
    # THE CONSEQUENCE IS REAL AND WORTH KNOWING: a bounded call therefore also gets that arm's UTF-8
    # decode and its line-array Output. For the push and fetch progress the bound is applied to, that is
    # cosmetic-to-better; for a caller that PARSES the output it is a change of shape, which is why
    # -TimeoutSeconds is opt-in per call site rather than a default. SINCE #2155 THAT CHANGE IS SMALLER
    # THAN IT WAS -- the element type no longer moves, only the container ($null/scalar/array on the &
    # arm, always an array on the -Utf8 one) and the decode -- but it is not nothing, so the flag stays
    # opt-in.
    if ($Utf8 -or $TimeoutSeconds -gt 0) {
        return Invoke-NativeCaptureUtf8 -FilePath $FilePath -Arguments $Arguments `
                                        -DiscardStderr:$DiscardStderr -TimeoutSeconds $TimeoutSeconds
    }

    # THIS ARM LEAVES ARGV QUOTING TO WINDOWS POWERSHELL 5.1, AND THREE SHAPES DO NOT SURVIVE IT
    # (issue #1963). Measured against a compiled C# probe printing each argv element with its length:
    # of 300 random argument sets, 129 arrived at the child wrong on this arm and 0 on the -Utf8 one.
    #
    #   - THE EMPTY STRING is dropped entirely, shifting every later argument one place left.
    #   - A VALUE CONTAINING A QUOTE loses the quote AND swallows the arguments after it -- without
    #     whitespace the bare quote opens an argv region, with whitespace PowerShell's own quoting
    #     fails to escape the inner one.
    #   - WHITESPACE PLUS A TRAILING BACKSLASH escapes the closing quote PowerShell added, so the
    #     region never ends and the rest of the command line is absorbed. A trailing backslash
    #     WITHOUT whitespace is passed through unquoted and is fine.
    #
    # SO A CALLER PASSING FREE TEXT PASSES -Utf8, which routes to Start-Process and quotes the
    # arguments itself (ConvertTo-NativeArgumentToken). open-pr's `gh pr create --title` is the call
    # site that was measured exposed, and it does. The file-based idiom -- git's -F, gh's --body-file
    # -- is the other way out, and is what park-lib and verify-resolved-issues already use.
    #
    # SO THE THREE SHAPES ARE REFUSED HERE, and #1966 is the issue that decided it. #1963 repaired the
    # one call site it had measured exposed and withdrew the guard, because this lib is mirrored into the
    # plugins and runs in consumers' repos -- a throw is a behaviour change for every consumer rather
    # than a bug fix, which is a decision of its own rather than a side effect of a prio-2 repair.
    #
    # WHAT MAKES IT SAFE TO MAKE THAT CHANGE: the guard fires ONLY on arguments that were ALREADY being
    # mis-delivered. No consumer call that works today starts throwing -- what changes is that a call
    # which was silently handing the child a different command line now says so. The refusal is the
    # first time that class is visible at all.
    #
    # AND THE COST IS NOT HYPOTHETICAL, WHICH IS THE ARGUMENT FOR IT. #1963 expected the guard to break
    # legitimate hostile-name TEST FIXTURES and left that as the open objection. Measured here instead of
    # assumed, and it ran the other way: ref-print-lib.tests.ps1 passed a branch name carrying a quote to
    # `git check-ref-format` through THIS arm, so git was asked about 'fix/ab' and answered about
    # 'fix/ab' -- the assert proving git accepts a quote in a ref name had never once tested a quote. The
    # fixture's repair is -Utf8, which makes it test what it claims; it was not an exception the guard
    # needed. A false green is what this refusal turns red.
    #
    # A SILENT REROUTE TO THE -Utf8 ARM IS STILL NOT THE CHEAP ALTERNATIVE IT LOOKS LIKE, though #2155
    # HAS TAKEN THE STRONGEST HALF OF THAT ARGUMENT AWAY AND THAT IS SAID RATHER THAN QUIETLY DROPPED.
    # #1963 argued it on the element type: that arm returned strings where this one returned pipeline
    # objects, ErrorRecords included. Both arms return strings now, so that difference is gone. What is
    # left is real and smaller -- the container (this arm unrolls to $null/scalar/array, that one is
    # always an array) and the UTF-8 decode -- and it is still enough: switching on the CONTENT of an
    # argument would change a caller's result shape on exactly the days a title happened to contain a
    # quote, which is the data-dependent surprise -Utf8 was itself introduced to end. Refusing is loud;
    # rerouting is another silent difference.
    #
    # #1963's CANDIDATE REPAIR #2 IS MEASURABLY WRONG AND IS RECORDED SO IT IS NOT RE-PROPOSED: giving
    # this arm the same tokeniser is correct on every hand-picked example and still wrong on 7/300,
    # because PowerShell 5.1 re-processes a token that already carries quotes.
    $refusal = Get-NativeArgumentRefusal -Arguments $Arguments
    if ($refusal) { throw $refusal }

    $prevEap = $ErrorActionPreference
    $prevEnv = $null
    try {
        $ErrorActionPreference = 'Continue'
        $prevEnv = Push-NativeNonInteractiveEnv
        # NORMALISED IN THE PIPELINE, AND THE SHAPE IS DELIBERATELY LEFT ALONE (issue #2155). Assigning
        # a pipeline follows exactly the same unrolling rule the bare & operator followed here before:
        # nothing -> $null, one line -> a scalar, many -> an array. Only the ELEMENT TYPE changes, which
        # is the whole of the decision; wrapping this in @() would additionally turn every single-line
        # capture into a 1-element array, and a caller reading $res.Output as a string would break on a
        # change nobody asked for.
        #
        # THE -DiscardStderr BRANCH IS NORMALISED TOO EVEN THOUGH IT CANNOT PRODUCE A RECORD (a branch
        # of this arm, not a third arm -- 'arm' is this file's word for the & / -Utf8 split), because a
        # caller reads one field whichever arm answered it -- the same reasoning ShortRead and
        # ExitCodeUnknown are reported on this arm under. [string] on a string is a no-op; branching on
        # it would only add a second shape to reason about.
        # THE CATCH IS COMMAND DISCOVERY, NOT THE CHILD'S OWN FAILURES (issue #2234). A missing
        # executable is the ONE error on this arm that $ErrorActionPreference = 'Continue' does not
        # reach: CommandNotFoundException is raised by PowerShell's command resolver BEFORE the EAP
        # dance above has anything to apply to, and it is terminating regardless of the preference -- so
        # the whole point of this function, that a caller gets a verdict rather than an exception, did
        # not hold for it. See New-NativeNotStartedCapture for why that is a state rather than a guard
        # at each call site.
        #
        # THE TYPE IS NAMED RATHER THAN CAUGHT BARE, deliberately. A bare `catch` here would also
        # swallow a child's own terminating failures and hand every one of them back as "not started",
        # which is a wrong answer arriving as a plausible value -- the exact failure mode -Utf8 was
        # introduced to end. Anything else still propagates, exactly as it did before this branch.
        try {
            if ($DiscardStderr) {
                $output = & $FilePath @Arguments 2>$null | ForEach-Object { Get-NativeLineText $_ }
            } else {
                $output = & $FilePath @Arguments 2>&1   | ForEach-Object { Get-NativeLineText $_ }
            }
        } catch [System.Management.Automation.CommandNotFoundException] {
            return New-NativeNotStartedCapture -FilePath $FilePath -Reason $_.Exception.Message
        } catch [System.Management.Automation.ApplicationFailedException] {
            # THE SECOND WAY A LAUNCH FAILS ON THIS ARM, and it is the one the first catch alone does not
            # reach: the file IS found on PATH and the Win32 loader then refuses the image -- a wrong
            # architecture, a corrupt binary, or an extensionless POSIX shim handed to CreateProcess.
            # PowerShell raises ApplicationFailedException rather than CommandNotFoundException for it.
            #
            # CAUGHT IN REVIEW AND THEN MEASURED, because the asymmetry it creates is invisible from the
            # diff: Start-Process raises InvalidOperationException for BOTH shapes, so the -Utf8 arm was
            # already returning a verdict for this one while this arm went on throwing -- against a
            # docstring that says "the OS refused to launch it" for both. Reproduced September 21, 2026
            # with a text file named '.exe' on PATH: the & arm threw ApplicationFailedException, the
            # -Utf8 arm returned NotStarted with the loader's own words.
            #
            # NOT A HYPOTHETICAL SHAPE HERE: Resolve-NativeApplicationPath above exists precisely because
            # npm's global install drops an extensionless shim beside its '.cmd', and handing that file
            # to the loader fails with "%1 is not a valid Win32 application" -- this class, one arm over.
            return New-NativeNotStartedCapture -FilePath $FilePath -Reason $_.Exception.Message
        }
        # $LASTEXITCODE IS STILL THE NATIVE COMMAND'S, read after the pipeline drains: only a native
        # command writes it, and ForEach-Object is not one. Get-ShopifyLineText's caller one lib over
        # reads it in exactly this position for exactly this reason.
        $code = $LASTEXITCODE
    } finally {
        Pop-NativeNonInteractiveEnv -Previous $prevEnv
        $ErrorActionPreference = $prevEap
    }

    # ShortRead IS ALWAYS $false ON THIS ARM, and that is a fact rather than a default (#1679):
    # the & operator hands PowerShell's own pipeline reader the child's output directly, so there is no
    # capture file for a lingering grandchild handle to truncate. A caller therefore reads one field
    # whichever arm answered it, which is the same promise TimedOut already makes.
    #
    # ExitCodeUnknown IS CHECKED HERE TOO, EVEN THOUGH IT WAS NEVER MEASURED TO FIRE ON THIS ARM
    # (issue #1931): 300 fresh-process runs of this exact & pattern all came back with a real
    # $LASTEXITCODE -- see Invoke-NativeCapture's docstring for the measurement. $LASTEXITCODE needs no
    # OS process handle, which is the mechanism the Start-Process arm's race depends on, so there is no
    # reason to expect it here. The check stays rather than being narrowed to the other arm, on the same
    # reasoning ShortRead's own comment gives one line up: a caller reads one field whichever arm
    # answered it, and $null -eq $LASTEXITCODE costs nothing to ask.
    #
    # NotStarted IS $false HERE AS A FACT, not as a default: this line is reached only after the &
    # operator resolved the command and ran it, since the one failure that prevents that returns from
    # the catch above. Reported rather than omitted for the reason ShortRead's own comment gives -- a
    # caller reads one field whichever arm answered it.
    return [pscustomobject]@{ Output = $output; ExitCode = $code; TimedOut = $false; ShortRead = $false; ExitCodeUnknown = ($null -eq $code); NotStarted = $false }
}

function Read-NativeCaptureFile {
    <#
        ONE capture file, read as text, PLUS WHETHER A WRITER STILL HELD IT: { Text; WriterHeld }.
        Internal to this lib, with TWO callers since #1731: the -Utf8/timeout arm below, and
        Write-GateCaptureBlock above for the test gate's own capture files. This line used to say the
        arm was the only one, which described the callers of the day -- it was never an argument that
        the gate should not be one, and reading it as one is how the gate kept a plain Get-Content for
        the very hazard this function was built for.

        WHY THE TOLERANT READ EXISTS (issue #1252). On a timeout, Invoke-NativeCaptureUtf8 force-kills
        the child's whole process tree with taskkill /T and then waits on the DIRECT child only. A
        grandchild that inherited the redirected stdout handle keeps out.txt open until IT is reaped
        too, and the gap between the kill and that moment is wall-clock -- invisible on a fast machine,
        a lost race on a CI runner several times slower. [System.IO.File]::ReadAllText opens the file
        with FileShare.Read, which cannot coexist with the writer handle still held, so it throws
        "The process cannot access the file ... because it is being used by another process." -- and
        the exception replaces a diagnosable timeout with an unrelated IO error, on a branch whose diff
        never touched this code.

        FileShare.ReadWrite coexists with that lingering handle and returns whatever was flushed. For a
        process tree that was just killed, a possibly-truncated tail is the honest answer -- the same
        judgement Stop-NativeProcessTree already makes when it lets its own kill attempts fail. Used
        for BOTH reads, not only the timeout path: a grandchild can outlive a clean exit too, and a
        shared read costs the normal case nothing.

        WHY IT NOW ALSO REPORTS WriterHeld (issue #1679). That trade is right where it was made and is
        unchanged -- what was wrong is that it was made SILENTLY. A caller got a possibly-truncated
        document with ExitCode 0 and no way to tell "the child said nothing" from "we read before the
        flush", so five callers in this family resolved the ambiguity toward a SUBSTANTIVE answer:
        "no PR", "no issue declared", "the body does not carry the section". A short read then produces
        a confident wrong verdict on a loaded machine, which is exactly when it happens (#1676 is the
        first site, repaired caller-side).

        THE INFORMATION WAS NEVER LOST, ONLY UNASKED FOR. #1679 recorded the lib-side answer as needing
        "information the shared read deliberately gave up"; it does not. An open with FileShare.Read
        FAILS precisely when a writer still holds the file, which is the whole question -- so the
        answer is one open away, and it is free.

        THE OPEN IS THE PROBE, deliberately, rather than a probe followed by a read. A separate ask
        leaves a window in which the writer releases between the two calls, and that window fails in
        the WRONG direction: the read would then be complete while WriterHeld said otherwise, and the
        DEPLOY lock refusing a mergeable PR is the very failure (#1446) this exists to prevent. Reading
        from the handle the probe opened cannot be wrong about its own stream.

        -SettleMilliseconds IS SPENT ONLY WHERE WAITING IS HONEST, and the arm passes 0 on a timeout.
        #1252 chose not to wait longer, and that reasoning is exact for a KILLED tree: a truncated tail
        is the honest answer there, because nothing more is coming. On a CLEAN exit it is not -- the
        child exited of its own accord, so its full output exists and a lingering handle is a
        grandchild being reaped rather than a document that ends there. Waiting a moment for that is
        the difference between reporting a short read and not having one.

        Measured, September 9, 2026: five consecutive `gh issue view --json body` captures settled on
        the FIRST probe, which cost 2-8 ms. So the budget below is not spent in the normal case at all;
        it is spent only where the alternative was a wrong answer. And a grandchild that is still
        RUNNING (rather than being reaped) never releases inside it -- there WriterHeld is the correct
        verdict, which is why the budget is short rather than generous.

        A file that is not there is NOT a sharing violation and is not retried -- it is rethrown at
        once. FileNotFoundException derives from IOException, so without this a missing capture would
        spend the whole budget before failing with the same error it started with.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][System.Text.Encoding]$Encoding,
        [int]$SettleMilliseconds = 0
    )

    # THE TYPED CATCH IS DELIBERATELY NOT USED HERE, and it is not style: `catch
    # [System.IO.IOException]` DOES NOT MATCH. A failing constructor comes back as a
    # MethodInvocationException wrapping the real exception, so the sharing violation escaped the
    # handler and surfaced as a raw New-Object error from inside this lib -- measured while writing
    # this function, on the one case it exists to handle. The chain is unwrapped explicitly instead,
    # which is deterministic in a way the typed catch demonstrably is not.
    #
    # AND ONLY A SHARING VIOLATION IS RETRIED. Anything else is rethrown at once, unchanged from the
    # behaviour before this function reported anything: a missing capture file or a permissions
    # problem is not something a wait can fix, and spending the budget on it would delay the same
    # error it started with.
    $waited = [System.Diagnostics.Stopwatch]::StartNew()
    $settled = $false
    while (-not $settled) {
        try {
            $probe = New-Object System.IO.FileStream(
                $Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
            try {
                $reader = New-Object System.IO.StreamReader($probe, $Encoding)
                try { return [pscustomobject]@{ Text = $reader.ReadToEnd(); WriterHeld = $false } }
                finally { $reader.Dispose() }
            } finally {
                $probe.Dispose()
            }
        } catch {
            $ex = $_.Exception
            while ($ex -is [System.Management.Automation.MethodInvocationException] -and $ex.InnerException) {
                $ex = $ex.InnerException
            }
            $isSharingViolation = ($ex -is [System.IO.IOException]) -and
                                  -not ($ex -is [System.IO.FileNotFoundException]) -and
                                  -not ($ex -is [System.IO.DirectoryNotFoundException])
            if (-not $isSharingViolation) { throw }
            if ($waited.ElapsedMilliseconds -ge $SettleMilliseconds) { $settled = $true }
            else { Start-Sleep -Milliseconds 25 }
        }
    }

    $stream = New-Object System.IO.FileStream(
        $Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $reader = New-Object System.IO.StreamReader($stream, $Encoding)
        try { return [pscustomobject]@{ Text = $reader.ReadToEnd(); WriterHeld = $true } }
        finally { $reader.Dispose() }
    } finally {
        $stream.Dispose()
    }
}

function Resolve-NativeApplicationPath {
    <#
        The file $FilePath actually resolves to when Start-Process is told to search PATH for it
        itself -- or $FilePath unchanged when there is nothing to resolve. Exists for
        Invoke-NativeCaptureUtf8 alone, because that arm's PATH search is not PowerShell's own.

        WHY THIS EXISTS AT ALL (issue #1988). npm's global install on Windows drops three files for one
        bin -- an extensionless POSIX shim, a '.cmd', and a '.ps1' -- all in the same PATH entry.
        Start-Process resolves a bare name via CreateProcess's own search, which matches the EXACT
        (extensionless) file before it ever tries an appended extension, and handing that file to the
        Win32 loader fails with "%1 is not a valid Win32 application". The & operator arm never hits
        this: PowerShell's own command discovery (the order Get-Command uses) picks the '.ps1' first
        and runs it as a script instead of loading a raw file.

        So this looks for what Get-Command would find, filtered to what Start-Process can actually
        launch as a native process -- CommandType Application (excludes the '.ps1', an ExternalScript
        Start-Process would only ever hand to whatever program owns that extension) WITH a non-empty
        Extension (excludes the bare POSIX shim itself). The first such match, in Get-Command's own
        order, is the file PATHEXT-style resolution would have picked had the colliding extensionless
        file not been sitting in the same directory.

        Left unchanged -- not refused, not searched further -- when $FilePath already names a specific
        file (a path separator is present) or when nothing Application-shaped with an extension turns
        up; Start-Process then fails exactly as it always did, so a genuinely missing command still
        reports as one.
    #>
    param([Parameter(Mandatory = $true)][string]$FilePath)

    if ($FilePath -match '[\\/]') { return $FilePath }

    $match = Get-Command -Name $FilePath -All -CommandType Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension } | Select-Object -First 1
    if ($match) { return $match.Source }
    return $FilePath
}

function Invoke-NativeCaptureUtf8 {
    <#
        The -Utf8 arm of Invoke-NativeCapture; see that function's docstring for WHY. Split out rather
        than nested in an if/else because the two share no lines: different launcher, different
        capture, different decode. Callers pass -Utf8 instead of naming this -- and since #1179 they
        also arrive here by passing -TimeoutSeconds, because the bounded wait needs the -PassThru
        handle only this arm has. So the arm is no longer "the UTF-8 one": it is the Start-Process one,
        and UTF-8 decoding is one of the two things that follows from that.

        Start-Process -PassThru THEN $proc.Handle THEN WaitForExit is the proven pattern from
        Invoke-TestSuiteGate below, and reading .Handle is NOT a no-op: without it .NET does not retain
        the OS handle and .ExitCode comes back EMPTY once the child has exited -- empty is not 0, and
        that is how this file's own gate once judged every green suite as failed.

        Capture goes to FILES rather than pipes: with -Wait-less Start-Process a full pipe buffer
        deadlocks, and a file cannot. Temp directory is per-process AND per-call, so two captures in
        one script cannot read each other's output.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$DiscardStderr,
        [int]$TimeoutSeconds = 0
    )

    $capDir  = Join-Path ([System.IO.Path]::GetTempPath()) ("native-capture-$PID-" + [guid]::NewGuid().ToString('n'))
    $outFile = Join-Path $capDir 'out.txt'
    $errFile = Join-Path $capDir 'err.txt'

    $prevEnv = $null
    try {
        New-Item -ItemType Directory -Path $capDir -Force | Out-Null

        # Before Start-Process, because a child inherits its environment at CREATION -- setting these
        # after the process exists would guard nothing. Restored in the finally below.
        $prevEnv = Push-NativeNonInteractiveEnv

        $startArgs = @{
            FilePath               = (Resolve-NativeApplicationPath -FilePath $FilePath)
            NoNewWindow            = $true
            PassThru               = $true
            RedirectStandardOutput = $outFile
            RedirectStandardError  = $errFile
        }
        # An EMPTY -ArgumentList is an error in Windows PowerShell 5.1, so it is omitted rather than
        # passed empty -- a command with no arguments is a normal call, not a special case.
        if ($Arguments.Count -gt 0) {
            $startArgs['ArgumentList'] = @($Arguments | ForEach-Object { ConvertTo-NativeArgumentToken -Value $_ })
        }

        # THE LAUNCH IS GUARDED, AND ONLY THE LAUNCH (issue #2234). Start-Process raises
        # InvalidOperationException when the OS refuses to create the process at all -- a file that is
        # not on PATH, or one the Win32 loader will not take -- and it does so before there is a handle,
        # an exit code or a capture file, so none of the verdicts below could be composed. Under a
        # caller's $ErrorActionPreference = 'Stop' that ended the whole run rather than the one call;
        # see New-NativeNotStartedCapture for the state that replaces it and why it is not a per-site
        # guard.
        #
        # SCOPED TO THIS ONE STATEMENT rather than wrapped around the body, because everything after it
        # -- the bounded wait, the kill, the settle, the decode -- already reports its own outcome
        # through a field, and a catch spanning those would convert a real measurement into "not
        # started". The finally below still runs on this return, so the environment is restored and the
        # capture directory is removed exactly as on every other path.
        try {
            $proc = Start-Process @startArgs
        } catch [System.InvalidOperationException] {
            return New-NativeNotStartedCapture -FilePath $FilePath -Reason $_.Exception.Message
        }
        $null = $proc.Handle

        # THE BOUNDED WAIT (#1179). WaitForExit(ms) returns $false when the deadline passed rather than
        # throwing, so the timeout is a verdict to report and not an exception to catch. The second,
        # short wait after the kill is not belt-and-braces: the capture files are still open handles
        # until the child is actually reaped, and reading them before that returns a truncated document
        # -- which would drop the very git output a reader needs to see WHY it stalled. That wait is on
        # the DIRECT child only, though, so a killed grandchild can still hold out.txt when the read
        # runs -- see Read-NativeCaptureFile below (#1252) for why the read tolerates that rather
        # than waiting longer.
        $timedOut = $false
        if ($TimeoutSeconds -gt 0) {
            if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
                $timedOut = $true
                Stop-NativeProcessTree -ProcessId $proc.Id
                $null = $proc.WaitForExit(5000)
            }
        } else {
            $proc.WaitForExit()
        }

        # A KILLED CHILD HAS AN EXIT CODE OF ITS OWN and it is a misleading one -- taskkill /F leaves 1
        # or 0x40010004 behind, which reads as an ordinary git failure. The timeout code is substituted
        # so the number and TimedOut tell the same story.
        $code = if ($timedOut) { $script:NativeCaptureTimeoutExitCode } else { $proc.ExitCode }

        # ExitCodeUnknown (issue #1931) -- READ BEFORE $code IS USED FOR ANYTHING ELSE, same discipline
        # TimedOut already needs one line up: a substituted code is not a measurement gap, it is a
        # verdict this function chose, so the check is $false whenever $timedOut is true regardless of
        # what $proc.ExitCode itself would have read. On a clean exit .ExitCode CAN come back as
        # PowerShell's own $null even after .Handle was read and WaitForExit() returned -- reproduced
        # independently at 1 in 300 fresh processes; see the docstring above for the measurement and for
        # why a retry is not the fix. System.Diagnostics.Process.ExitCode is a non-nullable int, so this
        # is .NET/the OS handing back an unmeasured value rather than the type's documented contract --
        # not a 259 (STILL_ACTIVE) and not a thrown exception, both of which were considered and neither
        # of which reproduced.
        $codeUnknown = (-not $timedOut) -and ($null -eq $code)

        # No BOM on the decoder: a BOM-emitting child is not something gh or git does, and
        # UTF8Encoding($false) still strips one if it is there.
        $utf8 = New-Object System.Text.UTF8Encoding $false
        $text = ''

        # THE SETTLE BUDGET IS SPENT ONLY ON A CLEAN EXIT (issue #1679), and 0 on a timeout is #1252's
        # own judgement kept intact: a killed tree's truncated tail is the honest answer, because
        # nothing more is coming. A child that exited of its own accord is the opposite case -- see
        # Read-NativeCaptureFile above for the full argument and the measurement.
        $settle = if ($timedOut) { 0 } else { $script:NativeCaptureSettleMilliseconds }

        # SHORT-READ IS PER-CAPTURE AND THEN OR-ED, because out.txt and err.txt are separate handles
        # and a grandchild can hold one without the other. Either one being short makes $text short.
        $shortRead = $false
        if (Test-Path -LiteralPath $outFile) {
            $readOut = Read-NativeCaptureFile -Path $outFile -Encoding $utf8 -SettleMilliseconds $settle
            $text = $readOut.Text
            if ($readOut.WriterHeld) { $shortRead = $true }
        }
        if (-not $DiscardStderr -and (Test-Path -LiteralPath $errFile)) {
            $readErr = Read-NativeCaptureFile -Path $errFile -Encoding $utf8 -SettleMilliseconds $settle
            $text += $readErr.Text
            if ($readErr.WriterHeld) { $shortRead = $true }
        }

        # Lines, to match what the & path hands back. A single trailing newline is the terminator of
        # the last line rather than an empty line after it, so it is dropped; anything else is content.
        $lines = @()
        if ($text.Length -gt 0) {
            $text = $text -replace "`r`n", "`n"
            if ($text.EndsWith("`n")) { $text = $text.Substring(0, $text.Length - 1) }
            $lines = @($text -split "`n")
        }

        # THE DIAGNOSIS GOES IN Output, not only in the exit code, because that is where every existing
        # caller already looks: they pipe Output to Write-Host and then judge ExitCode. Appending the
        # line means the three bounded sites report a stall in full without one of them changing a line
        # -- and it names the command, so a reader who only has the console scrollback still knows which
        # call it was. It goes AFTER git's own output rather than before: what git managed to say before
        # it stalled is the evidence, and this is the verdict on it.
        if ($timedOut) {
            $lines = @($lines) + @(
                "[timeout] '$FilePath' did not finish within $TimeoutSeconds seconds; its process tree was killed (reported as exit $($script:NativeCaptureTimeoutExitCode)).",
                "[timeout] A git network call that stalls this way is usually a credential helper waiting on a prompt nothing can answer (inbound #1179). Check 'git config --get-all credential.helper' and that the credential for this remote is still valid."
            )
        }

        # NOTHING IS APPENDED TO Output FOR THIS, unlike the timeout lines above -- and that asymmetry is
        # deliberate rather than an oversight. A timeout is opt-in per call site (-TimeoutSeconds), so
        # every caller that could hit it already expects extra lines; ExitCodeUnknown can happen on ANY
        # -Utf8 call, including the `gh --json ...` ones whose Output a caller feeds straight into
        # ConvertFrom-Json, so inserting a line here would corrupt exactly the callers ShortRead's own
        # docstring warns against breaking. The field is the only signal, same as ShortRead.
        # NotStarted IS $false HERE AS A FACT, for the reason the & arm's own return states: this line
        # is reached only after Start-Process handed back a process object, since the launch failure
        # returns from the catch above.
        return [pscustomobject]@{ Output = $lines; ExitCode = $code; TimedOut = $timedOut; ShortRead = $shortRead; ExitCodeUnknown = $codeUnknown; NotStarted = $false }
    } finally {
        Pop-NativeNonInteractiveEnv -Previous $prevEnv
        if (Test-Path -LiteralPath $capDir) {
            Remove-Item -Recurse -Force -LiteralPath $capDir -ErrorAction SilentlyContinue
        }
    }
}

function Test-NativeExitMeasured {
    <#
    .SYNOPSIS
        Is this capture's ExitCode a MEASUREMENT of the child's exit, or merely a number-shaped gap?

    .DESCRIPTION
        THE CONSUMER ExitCodeUnknown WAS BUILT FOR (issue #1931, audited under #2081). The field landed
        on both arms of Invoke-NativeCapture and then had no reader outside this file for four days --
        so every one of the 48 bounded call sites went on judging `$r.ExitCode -ne 0` against a value
        that, once in roughly 300 fresh Start-Process children, is PowerShell's own $null.

        WHY A FUNCTION RATHER THAN THE FIELD ITSELF, and it is the direction that makes it worth one:

            $null -eq 0   ->  False      # a site that requires success SILENTLY TREATS IT AS FAILURE
            $null -ne 0   ->  True       # a site that refuses on failure REFUSES

        Both spellings fail toward "something went wrong" and neither can be told apart from a measured
        non-zero -- so a caller cannot ask the question by reading ExitCode at all, whichever way round
        it writes the comparison. It has to ask BEFORE it looks at the number, and this is that ask.

        PROPERTY-GUARDED, AND THE MISSING FIELD ANSWERS $true. A caller can be holding a capture object
        made by an older copy of this lib -- the plugin mirror lags its own source by however many merges
        have landed -- and under Set-StrictMode -Version Latest a bare $Capture.ExitCodeUnknown THROWS on
        an object without the field. $true is the honest default there: it is exactly the behaviour every
        one of these sites had before the field existed, so an older capture degrades to the old reading
        rather than to a new refusal nobody asked for. The same guard, for the same reason, that
        git-identity-lib.ps1 already writes around TimedOut.

        A NULL CAPTURE ANSWERS $false, because the call did not happen: `if (-not $Capture)` is the shape
        several callers here already write for a command that could not be run at all, and "no capture"
        is the strongest possible statement that no exit code was measured.

        THE AUDIT'S RESULT, IN ONE PLACE, because #1931 asked for a decision per family rather than a
        blanket sweep and a decision nobody can find is not one. 56 bounded sites outside scripts/tests/,
        grouped by what the site DOES on a non-zero:

        THE COUNT TOOK THREE READINGS AND ONLY THE LAST ONE IS A MEASUREMENT. #2081 reported 32, which is
        what a single-line grep counts. A line-joining regex counted 48, which is what you get when the
        continuation heuristic is "the line ends in a backtick, or the next one starts with a dash" -- it
        stops dead at a call that opens `@(` and continues with an argument. The PARSER counts 56, and the
        eight it adds include two writes in sync-main.ps1 (`gh pr create` and `gh pr merge`) whose failure
        text tells the operator to redo a write that may already have landed. Both were missed by the
        first pass and found by the code review on that branch.

        SO THE ENUMERATION IS THE PARSER'S, AND THE PIN IN native-capture.tests.ps1 IS TOO. That is this
        repo's own rule -- the lint gate's parameter check says the same thing about the same mistake --
        and it is recorded here rather than only in the test because the next person to widen this family
        will reach for a grep first, exactly as this audit did.

          REFUSES / FAILS SAFE -- recorded as deliberate, code unchanged. Every one of them is written
          as a POSITIVE test (`-eq 0`, `-and -not $r.TimedOut`), which is what makes it right: $null is
          not 0, so the site already lands on its cautious branch. Test-GitCanCommit is the exception
          that proves it -- it is immune through a NEGATIVE test (`-ne 128`), which is correct today and
          would invert the moment somebody rewrote the comparison, so that one gained an explicit ask.

          REPORTS A SUBSTANTIVE ANSWER -- repaired where the wrong answer was silent. park-cycle's
          collision fetch is the sharpest: '' is its word for "nothing to report", so the detector
          answered all-clear on a look it never judged.

          PRINTS A DIAGNOSIS -- repaired, and this is the large family. All of them are written `-ne 0`,
          which $null satisfies, so each composed a sentence about a cause nobody measured: "no access,
          or the repo is gone", "a statement about the token or the network", "gh is not logged in here".
          Twelve of them interpolated the number as well, and PowerShell renders $null as the EMPTY
          STRING -- so the reader got "(exit )", a sentence whose grammar promises a number that is not
          there. Get-NativeExitLabel below is for the ones whose verdict was already right.

          WRITES -- nine that reach a remote, and they get their own answer: a write whose exit code was
          never measured may have LANDED, so it is reported as "this run does not know" rather than as a
          failure. open-pr's create needed no new verdict, only routing into the recheck #1916 had
          already built, and sync-main's `gh pr merge` had been printing "merge it by hand" beside a
          TIMEOUT arm that has said the right thing all along. The one
          deliberate exception is update-plugins, whose two writes are LOCAL and whose question runs the
          other way -- "did every update succeed" -- so an unknown stays a failure there, and re-running
          is idempotent anyway.

        ONE SITE RE-ASKS, AND ONLY ONE. #1931 allows an idempotent read-only command to ask again, and
        claim-issue's `gh issue view` meets both halves of the test the lib itself cannot apply -- the
        command changes nothing, and the cost of not asking is the whole assignment, since that read is
        the first step of an issue-driven session. Everywhere else a re-ask buys a skipped check back at
        the price of a second network call, and the state reported as itself is cheaper and honest.

        IT ANSWERS $false FOR A CHILD THAT NEVER STARTED TOO, and that needs no code here (issue #2234):
        New-NativeNotStartedCapture sets ExitCodeUnknown on the capture it builds, precisely so that
        every one of the sites audited above keeps working unchanged. The two questions are different
        and the difference is real -- "it ran and I could not measure how it ended" against "it never
        ran" -- but they have the SAME answer to this one, because neither produced a measurement. A
        caller that needs to tell them apart asks Test-NativeCommandStarted, and the only ones that do
        are the two that re-ask and Get-NativeExitLabel, which has to word it.

        IT SAYS NOTHING ABOUT A TIMEOUT, deliberately. Invoke-NativeCapture SUBSTITUTES 124 on a bounded
        call it killed, which is a verdict this lib chose rather than a measurement gap -- ExitCodeUnknown
        is $false there by construction, and TimedOut is the field that reports it. A caller that judges
        both reads them as two questions, in the order the answers differ: did it answer at all, and was
        what it answered measurable.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()]$Capture)

    if (-not $Capture) { return $false }
    if ($Capture.PSObject.Properties['ExitCodeUnknown'] -and $Capture.ExitCodeUnknown) { return $false }
    return $true
}

function Get-NativeExitLabel {
    <#
    .SYNOPSIS
        The phrase a diagnosis interpolates INSTEAD of "exit $($r.ExitCode)" -- "exit 3", or a sentence
        saying the code could not be measured.

    .DESCRIPTION
        THE OTHER HALF OF #2081'S AUDIT, AND THE ONE THAT SHOWS UP ON A CONSOLE. Twelve of the bounded
        sites compose a sentence around the number -- "gh refused the read (exit $($read.ExitCode))",
        "FAILED (exit $($r.ExitCode))", "git fetch exited $($fetch.ExitCode)" -- and PowerShell
        interpolates $null as the EMPTY STRING. So the unmeasurable case does not print a wrong number,
        which a reader could at least query; it prints no number at all, inside a sentence whose grammar
        promises one:

            gh refused the read (exit ) -- no access, or no such branch

        THAT IS WORSE THAN THE MISSING BRANCH IT SITS IN, which is why the label exists separately from
        Test-NativeExitMeasured above. A site that gains a third state stops reaching this sentence; a
        site whose single branch is already the right verdict -- it refuses, and refusing is correct
        either way -- keeps the branch and only has to stop lying about why. One token per call site,
        and no behaviour change at any of them.

        THE WORDING NAMES THE ISSUE, not the mechanism. A reader who meets this line has hit a race
        measured at roughly 1 in 300 fresh processes and will not find it by re-reading their own
        script; the number is the only durable pointer to the measurement, and "run it again" is the
        whole remedy, because the next process is overwhelmingly likely to answer.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()]$Capture)

    # THE NOT-STARTED CASE IS ASKED FIRST, because it is a SUBSET of "not measured" and the general
    # sentence below is wrong about it in both halves (issue #2234): it says "the child ran", which is
    # exactly what did not happen, and it advises "this normally settles on a re-run", which is false
    # advice rather than merely imprecise -- a command that is not installed does not settle on a
    # re-run, and a reader who takes that advice spends the retry and learns nothing. The order is the
    # whole of the mechanism here: reversed, the broader test would answer first and this branch would
    # be unreachable.
    if (-not (Test-NativeCommandStarted -Capture $Capture)) {
        # THE SAME NOUN-PHRASE CONTRACT the measured form and the sentence below both keep, so it drops
        # into the parenthetical every existing caller already wrote: "(exit $($r.ExitCode))". The
        # remedy names the command rather than the mechanism, because a reader who meets this line has
        # a missing dependency and the install is the whole of the fix.
        return 'the command could not be started -- it is not on PATH, or the system refused to launch it (issue #2234); install it, or check the name'
    }

    if (-not (Test-NativeExitMeasured -Capture $Capture)) {
        # A NOUN PHRASE, AND THE CALL SITE HAS TO GIVE IT A NOUN SLOT. Both returns are things rather than
        # verbs -- "exit 3", not "exited 3" -- because the measured form has to drop into the parenthetical
        # every existing caller already wrote: "(exit $($r.ExitCode))". A site whose sentence wants a verb
        # gets "'git ls-remote' exit 3", which is a regression in the COMMON case to repair a rare one, so
        # such a site takes a colon or a parenthetical instead. Caught in review on this branch's own two
        # sync-main call sites, where it had been spliced into exactly that verb slot.
        #
        # AND THE WORD IS "MEASURED" THROUGHOUT, never "readable": this whole family says measurable or
        # could not be measured, and a lone "unreadable" here would propagate to every site that reuses
        # this one string -- which is most of them.
        return 'no measurable exit code -- the child ran, and what came back was not a measurement of how it ended (issue #1931); this normally settles on a re-run'
    }
    return "exit $($Capture.ExitCode)"
}

function Get-GitFileTextAtRef {
    <#
        The text of ONE file as a given git ref has it -- the commit's blob, not the working copy -- or
        $null when that ref does not carry the path at all.

        WHY THIS EXISTS AT ALL (issue #970, August 27, 2026). A gate that runs before a merge has to judge
        the document the MERGE will merge, and the working tree is not that document: ship-pr.ps1 waits on
        CI -- 10m57s on the run that produced the report -- and a session that backgrounds the ship and
        starts the next piece of work has moved the checkout while it waits. Reading a commit instead of a
        checkout is the whole repair, and it is one call so that every caller makes the same three decisions
        the same way.

        DECISION ONE: -Utf8, AND IT IS LOAD-BEARING. git's stdout here is DATA rather than progress, and
        5.1 decodes a native child with [Console]::OutputEncoding -- so on cp850 an em dash in the document
        arrives as three characters, and the DEPLOY lock then compares that against a PR body read with an
        explicit UTF-8 decode. See Invoke-NativeCapture's docstring for the measurement, and
        .claude/rules/language-layers.md for the rule.

        DECISION TWO: -DiscardStderr, so git's own 'fatal: path ... does not exist' line can never arrive
        INSIDE the returned document. A missing path is signalled by $null, which is what the exit code
        already said; a caller must never have to recognise it in the text.

        DECISION THREE: ABSENT AND EMPTY ARE DIFFERENT ANSWERS. A ref that has the path but holds an empty
        file returns '', which is falsy in PowerShell -- so every caller tests $null explicitly. A gate that
        conflates them treats a file it could not find as a file with nothing in it, which is exactly the
        silence this repair exists to remove.

        -Path takes repo-relative FORWARD slashes, which is what Get-BranchFilePaths hands out; a
        backslash path is converted rather than refused, because Join-Path output is the likeliest input.
        -RepoRoot is optional and becomes `git -C`, so a caller does not have to Set-Location first.

        The ref is passed as given. Prefer a full 'refs/heads/<branch>' over a bare branch name: `git show`
        resolves its left half as a rev, and a name that also names a directory is otherwise ambiguous.

        AN UNKNOWN EXIT CODE THROWS RATHER THAN RETURNING $null (issue #1931), and this is the sharpest
        site in the family that audit found. This function's OWN contract already conflates two things a
        caller cannot tell apart -- "the ref does not carry this path" and "the read could not be judged"
        -- both come back $null, and decision three above defends that conflation only against an EMPTY
        file, never against an unmeasured one. Its one caller (ship-pr.ps1's step-list gate and the
        DEPLOY lock, issue #884) reads $null as "no document -- nothing to check" and SKIPS BOTH GATES on
        that reading. So where ShortRead's five callers (#1679) resolved an ambiguous read toward a
        substantive answer that was too CONFIDENT, this one would resolve it toward a substantive answer
        that is too PERMISSIVE -- an ExitCodeUnknown read of a document that genuinely still carries an
        unresolved step, or has genuinely drifted from what the PR published, would merge silently. That
        is a worse failure than refusing a mergeable PR: nothing tells the reviewer the check never ran.

        THROWING IS THE RIGHT DIRECTION HERE BECAUSE OF WHO CALLS THIS, and it is not the general answer
        for every $null-returning function in this file (see Get-TrunkGap's Measured field and
        git-porcelain-lib.ps1's Known field for the other, tri-state shape -- both are read by callers
        that already have a defined "could not tell" branch). This function has exactly one caller,
        reached through a bare scriptblock invocation with no try/catch, in a script that runs under
        `$ErrorActionPreference = 'Stop'` -- so an uncaught throw here is a hard stop with a non-zero
        exit, not a silent pass-through. That is the fail-closed direction a merge gate needs, and it is
        available cheaply here BECAUSE there is only one caller to widen: changing this function's
        return shape to a third state was not on the table -- see Invoke-NativeCapture's own docstring
        for why widening EVERY caller's contract was declined on size -- but throwing on the one call
        site that would otherwise disable a security-relevant gate is a change with a blast radius of one.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Ref,
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$RepoRoot
    )

    $rel = $Path -replace '\\', '/'
    $gitArgs = @()
    if ($RepoRoot) { $gitArgs += @('-C', $RepoRoot) }
    $gitArgs += @('show', "${Ref}:${rel}")

    $show = Invoke-NativeCapture -Utf8 -DiscardStderr -FilePath 'git' -Arguments $gitArgs
    # A git THAT NEVER STARTED IS ITS OWN THROW (issue #2234), asked ahead of the unmeasured one because
    # the not-started state sets ExitCodeUnknown as well -- absorbed below, this function's refusal would
    # tell the reader to "re-run once the transient native-process read has cleared" about a git that is
    # not installed, where no amount of re-running clears anything. The DIRECTION is unchanged and
    # deliberately so: both still throw, because the one caller treats an absent path as nothing to
    # check, and a launch failure must not be read as an absent path either.
    if (-not (Test-NativeCommandStarted -Capture $show)) {
        throw "Get-GitFileTextAtRef: 'git show ${Ref}:${rel}' could not be started (issue #2234) -- git is not on PATH here, or the system refused to launch it. This cannot be read as 'the path is absent', because the one caller of this function treats an absent path as nothing to check. Install git, or check the name; re-running will not help."
    }
    if ($show.PSObject.Properties['ExitCodeUnknown'] -and $show.ExitCodeUnknown) {
        throw "Get-GitFileTextAtRef: 'git show ${Ref}:${rel}' did not return a measurable exit code (issue #1931) -- this cannot be read as 'the path is absent', because the one caller of this function treats an absent path as nothing to check. Re-run once the transient native-process read has cleared."
    }
    if ($show.ExitCode -ne 0) { return $null }
    # Lines back to one string: the -Utf8 arm hands back an array and drops the single trailing newline.
    # Every reader of this document splits on newlines again, so the terminator is not reconstructed.
    return ((@($show.Output) | ForEach-Object { "$_" }) -join "`n")
}

function Get-TestSuiteCostHints {
    <#
    .SYNOPSIS
        Reads the optional per-suite duration hints sitting beside a test directory, or $null.

    .DESCRIPTION
        A HINT, NEVER A CONTRACT -- issue #1358, September 4, 2026. Invoke-TestSuiteGate uses these to
        decide which shard a suite lands in and in what order the queue hands it a lane. It never uses
        them to decide WHETHER a suite runs: every *.tests.ps1 in the directory runs exactly once across
        the shards whether or not it appears here, a suite listed here that no longer exists is ignored,
        and a missing, unreadable or empty file falls the gate back to the stride it used before. That
        asymmetry is the whole safety argument for persisting anything at all -- stale data can only cost
        wall clock, never coverage, which is the property the SORT ORDER note in Invoke-TestSuiteGate
        would otherwise have to give up.

        WHY THE FILE IS COMMITTED RATHER THAN WRITTEN BY THE GATE. The numbers that matter are CI's, and
        only CI produces them: a local reading does not convert into a CI one, so a gate that refreshed
        this file from whatever machine last ran it would pack a hosted runner off workstation figures and
        do worse than no data at all. It is regenerated deliberately from a CI run's own tables by
        scripts/maintenance/record-suite-durations.ps1, which names the runs it read in the file.

        AND THE REASON IS STRONGER THAN THE ONE THIS DOCSTRING GAVE UNTIL SEPTEMBER 9, 2026 (issue #1713).
        It said the same suites run "3.6-4.0x faster on a developer machine". That is not a constant, and
        its SIGN is not fixed either -- so there is no divisor, and a reader who trusted the old sentence
        would convert a local figure by ~3.8 and land about ten times out. Two readings that disagree, on
        two machines: check-plugin-integrity-links.tests.ps1 ran 759.1s SOLO on an 18-thread workstation
        against a 290.9s mean over three 4-lane CI runs -- 2.6x SLOWER locally, not faster -- while the
        whole 85-suite pool finishes in about 255s of wall clock on a 32-thread machine at 30 lanes,
        against CI's four shards of four to six minutes each. What the old number was doing here was
        supporting a conclusion the correction does not weaken but reinforces: CI is a DIFFERENT machine,
        not a scaled one, so its durations cannot be derived at all. Any figure quoted for either side
        states its machine and its lane count or it means nothing.

        A BAD FILE IS A WARNING AND A FALLBACK, NOT A THROW. The gate refuses to guess at a nonsensical
        (Shard, ShardCount) because every wrong reading of those is silent and runs the wrong SET of
        suites. This is the opposite case: the worst a corrupt hints file can do is a worse partition of
        the same set, so refusing to run the tests over it would trade a real gate for a cosmetic one.
    #>
    param([Parameter(Mandatory)][string]$TestsDir)

    $path = Join-Path $TestsDir 'suite-durations.json'
    if (-not (Test-Path -LiteralPath $path)) { return $null }

    try {
        $doc = ConvertFrom-Json ((Get-Content -LiteralPath $path -Raw -Encoding UTF8))
    } catch {
        Write-Warning "test gate: $path is not readable JSON - using the stride. ($($_.Exception.Message))"
        return $null
    }
    if (-not $doc -or -not $doc.seconds) {
        Write-Warning "test gate: $path has no 'seconds' map - using the stride."
        return $null
    }

    $hints = @{}
    foreach ($p in $doc.seconds.PSObject.Properties) {
        # A non-numeric or non-positive entry is DROPPED rather than defaulted to zero: zero would sort
        # that suite to the very back of the queue, which is the one position a suite of unknown cost must
        # never take. Dropping it makes it unknown, and unknown is charged the maximum below.
        $value = $p.Value -as [double]
        if ($null -ne $value -and $value -gt 0) { $hints[$p.Name] = [double]$value }
    }
    if ($hints.Count -eq 0) {
        Write-Warning "test gate: $path holds no usable durations - using the stride."
        return $null
    }
    return $hints
}

function Get-TestSuiteShardOrder {
    <#
    .SYNOPSIS
        Selects one shard's suites and puts them in the order the gate should dequeue them.

    .DESCRIPTION
        TWO DECISIONS, ONE TABLE, AND THE ORDERING IS THE BIGGER HALF -- issue #1358, September 4, 2026.
        Which suites a shard draws, and in which order its queue hands them a lane, are both answered from
        the same duration hints, and simulated over this repo's measured 65-suite pool neither is worth
        much without the other:

            stride + name order (what this was)                 305s
            stride + longest-first                              266s
            LPT bin-pack + name order                           307s   <-- WORSE than doing nothing
            LPT bin-pack + longest-first                        237s

        Packing alone is not merely a small win, it is a LOSS: a balanced shard whose heaviest file is
        dequeued late still ends on that file's tail, and balancing hands each shard a heavier heaviest
        file than an unbalanced one did. That is the counter-intuitive result and the reason both halves
        landed in one change rather than in the order they were thought of.

        THE PACK IS LPT (longest-processing-time-first), the textbook greedy: walk the suites most
        expensive first and give each to the shard holding the least work so far. THE ORDER WITHIN A SHARD
        IS THE SAME SEQUENCE, which is list scheduling -- a lane never sits idle while an expensive suite
        waits behind a cheap one, and the pool's tail is a short suite instead of a long one. Measured on
        run 33842129201 before this existed: new-branch.tests.ps1 is alphabetically late, drew a lane at
        +40.9s, ran 249.2s, and set its shard's 290s makespan single-handedly -- a 41s tail bought by
        nothing but the letter it starts with.

        WHAT THIS DOES NOT FIX, so nobody re-derives it: after both halves the pool sits at its longest
        FILE (237s), and the only lever past that is inside a file. Splitting the longest one buys the
        gap to the 16-lane work bound, ~15s on the measured pool -- which is what #1358 was filed to price
        and why it is not being spent on preserving 340 asserts across ~2,950 lines.

        SORT ORDER IS STILL THE CONTRACT, it is simply a different order. The key is (cost DESC, name ASC)
        -- a total order, so a given (Shard, ShardCount) still selects the same files and is still
        re-runnable by hand from two integers. What changed is that the answer now depends on the hints
        file as well as the directory, which is why that file is committed rather than generated.

        NO HINTS AT ALL IS THE STRIDE, byte for byte what every caller got before this. A consumer that
        copies this lib and has no suite-durations.json is untouched, which is most of them.

    .PARAMETER Suites
        The pool, in any order. Anything with a .Name is accepted, so a test can pass fakes.

    .PARAMETER Costs
        Name -> seconds, from Get-TestSuiteCostHints. Null or empty selects the stride.

    .PARAMETER Shard
        1-based shard to select, or 0 with -ShardCount 0 for the whole pool.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Suites,
        [hashtable]$Costs,
        [int]$Shard = 0,
        [int]$ShardCount = 0
    )

    if ($Suites.Count -eq 0) { return @() }

    if (-not $Costs -or $Costs.Count -eq 0) {
        $byName = @($Suites | Sort-Object -Property @{Expression = { $_.Name }})
        if ($ShardCount -le 1) { return $byName }
        return @($byName | ForEach-Object -Begin { $i = 0 } -Process {
            if (($i % $ShardCount) -eq ($Shard - 1)) { $_ }
            $i++
        })
    }

    # A SUITE NOBODY HAS TIMED IS CHARGED THE MAXIMUM, which is the safe direction in both halves at once:
    # it is packed into the emptiest shard and dequeued in the opening lanes, so a new suite that turns out
    # to be expensive costs its own runtime and never a tail behind sixteen others. A new suite that is
    # actually trivial costs nothing for starting early -- it finishes and frees its lane. The asymmetry is
    # real, so the default follows it rather than a median.
    $unknownCost = ($Costs.Values | Measure-Object -Maximum).Maximum
    $costOf = {
        param($suite)
        if ($Costs.ContainsKey($suite.Name)) { [double]$Costs[$suite.Name] } else { [double]$unknownCost }
    }

    $ordered = @($Suites | Sort-Object -Property `
        @{Expression = { & $costOf $_ }; Descending = $true}, @{Expression = { $_.Name }; Descending = $false})

    if ($ShardCount -le 1) { return $ordered }

    $bins = @(1..$ShardCount | ForEach-Object { , (New-Object System.Collections.ArrayList) })
    $load = New-Object double[] $ShardCount
    foreach ($suite in $ordered) {
        # Lowest index wins a tie, so the assignment is reproducible rather than merely balanced.
        $lightest = 0
        for ($k = 1; $k -lt $ShardCount; $k++) { if ($load[$k] -lt $load[$lightest]) { $lightest = $k } }
        $bins[$lightest].Add($suite) | Out-Null
        $load[$lightest] += (& $costOf $suite)
    }
    return @($bins[$Shard - 1])
}

function Get-TestSuiteFocusOrder {
    <#
    .SYNOPSIS
        The queue for a FOCUS run: N copies of one suite, spread through enough real sibling suites to
        keep every other lane busy while they run. Issue #1944.

    .DESCRIPTION
        WHY THIS EXISTS. Invoke-TestSuiteGate runs its suites across many lanes, and this repo has
        measured a whole CLASS of defect that is only visible there: a suite that is red under the pool
        and green standalone. #1915 (a git probe in new-branch.tests.ps1) and #1939 (an unbounded
        powershell.exe bring-up against a fixed 2s bound in native-capture.tests.ps1) landed three days
        apart, different files and different causes, with an IDENTICAL discovery path -- the gate refused
        a push on a branch that touched neither suite, minutes after the same tree had passed it.
        Until this function there was no way to put ONE suite under that contention, so repairing one
        meant: change the suite, run it standalone (green BY DEFINITION OF THE BUG, and therefore
        evidence of nothing), then run the whole ~19-minute gate to learn whether the repair held.

        AND A SYNTHETIC LOAD IS NOT A SUBSTITUTE -- THAT WAS MEASURED, WHICH IS WHY THE LOAD HERE IS REAL
        SUITES. Building sixteen concurrent PowerShell processes that spawn short-lived PowerShell
        children got launch-to-print to 0.47-0.95s; the real gate, by native-capture.tests.ps1's own
        calibration, reaches 3.25s. The imitation falls ~3.4x short of the thing it imitates, and the
        suite stayed green under it. So the contention has to be the genuine article: the same pool, the
        same console, the same spawn model, the same siblings.

        WHAT IT RETURNS, and why it is not a list of files. One item per lane-slot the gate will open, in
        dequeue order, each carrying:
          - File     : the FileInfo to run
          - IsTarget : $true for a copy of the suite under test, $false for load
          - Label    : what the console calls it -- the plain name for load, 'name [focus 2/5]' for a
                       target copy, so five headers for one file are still told apart
          - Stem     : the capture-file stem, unique per ITEM. This is the half a bare file list cannot
                       carry: the pool names its capture files after the suite, and the same suite
                       appearing five times would have five lanes writing one pair of files.

        THE SIZING RULE, stated because it is the only judgement in here. The run should last about as
        long as the target's repeats do, with every other lane full for that whole span -- so the load
        budget is (Lanes - 1) x Repeat x the target's own cost, in lane-seconds, and siblings are cycled
        until it is met. Cycling rather than taking each sibling once is deliberate: load is load, a
        repeated load suite contends exactly as well as a fresh one, and a pool of 91 suites would
        otherwise cap the achievable span at whatever those 91 happen to cost.

        COST COMES FROM THE SAME HINTS THE SHARD PACKER USES, with the same rule for a suite nobody has
        timed -- charged the maximum. Here that direction is safe for a different reason than it is
        there: over-charging the target makes the load list LONGER, i.e. the reproduction attempt more
        thorough, and over-charging a load suite makes it shorter, which the target's own repeats then
        outlast. With no hints file at all every suite costs the same notional unit, which still fills
        the lanes -- it just cannot predict the span.

        WHAT IT REFUSES. A target that matches no suite, and a Repeat below 1. Both are refused rather
        than interpreted, for the reason this file's -Shard validation already gives at length: every
        wrong input here has a plausible-looking silent reading, and a focus run that quietly measured
        nothing is the exact shape of a green gate that proved nothing.

    .PARAMETER Suites
        The pool, in any order. Anything with .Name and .FullName is accepted, so a test can pass fakes.

    .PARAMETER Costs
        Name -> seconds, from Get-TestSuiteCostHints. Null or empty makes every suite one notional unit.

    .PARAMETER FocusSuite
        The suite under test. Matched against the file name, the base name, and the name with
        '.tests.ps1' removed -- all three, because all three are what a person has in their hand at that
        moment and stripping characters is not something a caller should have to learn.

    .PARAMETER Repeat
        How many times the target runs under the load.

    .PARAMETER Lanes
        The resolved lane count, which is what turns Repeat into a load budget.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Suites,
        [hashtable]$Costs,
        [Parameter(Mandatory)][string]$FocusSuite,
        [int]$Repeat = 5,
        [int]$Lanes = 1
    )

    if ($Repeat -lt 1) {
        throw "Get-TestSuiteFocusOrder: -Repeat must be at least 1 -- got $Repeat."
    }

    # THREE SPELLINGS, ONE TARGET. Exact file name first so a caller who typed the full name cannot be
    # ambushed by a prefix match; only then the looser forms.
    $wanted = $FocusSuite.Trim()
    $target = @($Suites | Where-Object { $_.Name -eq $wanted })
    if ($target.Count -eq 0) {
        # THE BASE NAME IS ONE OF THE THREE, and it is the one a shell hands you: tab-completing a
        # directory and deleting the extension leaves 'roster-sync.tests', which matches neither of the
        # other two forms. It was missing from the first version of this resolver while the docstring
        # above already promised it, so the refusal fired on a spelling this function claimed to accept.
        $target = @($Suites | Where-Object {
            $_.Name -eq ($wanted + '.tests.ps1') -or
            $_.Name -eq ($wanted + '.ps1') -or
            ($_.Name -replace '\.tests\.ps1$', '') -eq $wanted
        })
    }
    if ($target.Count -eq 0) {
        # THE NEAR MISSES ARE NAMED, because the commonest way to get here is a typo or a half-remembered
        # name, and a refusal that only says no sends the reader to Get-ChildItem.
        $near = @($Suites | Where-Object { $_.Name -like "*$wanted*" } | ForEach-Object { $_.Name } | Sort-Object)
        $hint = if ($near.Count -gt 0) { " Did you mean: $($near -join ', ')?" } else { '' }
        throw "Get-TestSuiteFocusOrder: no suite matches -FocusSuite '$FocusSuite' among the $($Suites.Count) in the pool.$hint"
    }
    $targetFile = $target[0]

    $load = @($Suites | Where-Object { $_.Name -ne $targetFile.Name } | Sort-Object -Property @{Expression = { $_.Name }})

    $unknownCost = 1.0
    if ($Costs -and $Costs.Count -gt 0) {
        $unknownCost = [double]($Costs.Values | Measure-Object -Maximum).Maximum
    }
    $costOf = {
        param($suite)
        if ($Costs -and $Costs.ContainsKey($suite.Name)) { [double]$Costs[$suite.Name] } else { [double]$unknownCost }
    }

    $items = New-Object System.Collections.ArrayList
    $stemSeen = @{}
    $addItem = {
        param($file, [bool]$isTarget, [string]$label)
        # THE STEM IS UNIQUE PER ITEM, not per file -- see the docstring. A counter rather than a guid so
        # a retained capture directory is readable: 'roster-sync.tests.2.out.txt' says which repeat it is.
        $stem = $file.BaseName
        if ($stemSeen.ContainsKey($stem)) {
            $stemSeen[$stem] = $stemSeen[$stem] + 1
            $stem = "$stem.$($stemSeen[$stem])"
        } else {
            $stemSeen[$stem] = 1
        }
        $items.Add([pscustomobject]@{
            File = $file; IsTarget = $isTarget; Label = $label; Stem = $stem
        }) | Out-Null
    }

    if ($load.Count -eq 0) {
        # A ONE-SUITE POOL IS NOT AN ERROR, it is a reproduction with nothing to contend against -- the
        # caller gets their repeats and the summary says the lane count, which is the honest report.
        for ($i = 1; $i -le $Repeat; $i++) {
            & $addItem $targetFile $true "$($targetFile.Name) [focus $i/$Repeat]"
        }
        return @($items)
    }

    $targetCost = & $costOf $targetFile
    $budget = [Math]::Max(1, $Lanes - 1) * $Repeat * $targetCost

    # AND A FLOOR IN ITEMS, NOT ONLY A BUDGET IN SECONDS. The budget alone under-delivers exactly when
    # the load is dearer than the target: a cheap target beside expensive siblings meets its
    # lane-seconds in two or three files, the queue is then shorter than the lane count, and
    # Invoke-TestSuiteGate's clamp quietly lowers -MaxParallel to fit -- so a run asked for at 16 lanes
    # is measured at 5. Measured on this repo's own hints while building #1944: -MaxParallel 6 on
    # check-report-lib produced 3 load items and ran at 5 lanes. The floor is one load item per
    # non-target lane per repeat, which is what it takes to have something to put in every lane for
    # every draw; the budget then only ever ADDS to that.
    $floor = [Math]::Max(1, $Lanes - 1) * $Repeat

    # Cycle the siblings until both are met, so the lanes stay full for the whole span rather than for
    # however long one pass over the pool happens to last. Cycling rather than one pass is deliberate:
    # load is load, a repeated load suite contends exactly as well as a fresh one, and a pool of 91
    # would otherwise cap the achievable span at whatever those 91 happen to cost.
    #
    # THE COSTS ARE CI SECONDS READ ON WHATEVER MACHINE THIS RUNS ON, and this file records at length
    # that such a reading does not convert. It does not have to: both sides of this comparison are in
    # the same units, so what is used here is a RATIO between suites, which survives the scale being
    # wrong. Nothing in this function quotes a duration.
    $loadRun = New-Object System.Collections.ArrayList
    $spent = 0.0
    $i = 0
    while ($spent -lt $budget -or $loadRun.Count -lt $floor) {
        $s = $load[$i % $load.Count]
        $loadRun.Add($s) | Out-Null
        $spent += (& $costOf $s)
        $i++
    }

    # ONE TARGET AT THE HEAD OF EACH OF $Repeat EQUAL CHUNKS. That is what spreads the repeats across the
    # run instead of firing them all into the opening lanes, where they would contend with each other
    # rather than with the load -- and it is arithmetic a reader can check against the printed queue,
    # which a cost-weighted placement would not be.
    $chunk = [Math]::Max(1, [int][Math]::Ceiling($loadRun.Count / [double]$Repeat))
    for ($r = 1; $r -le $Repeat; $r++) {
        & $addItem $targetFile $true "$($targetFile.Name) [focus $r/$Repeat]"
        $from = ($r - 1) * $chunk
        for ($k = $from; $k -lt [Math]::Min($from + $chunk, $loadRun.Count); $k++) {
            & $addItem $loadRun[$k] $false $loadRun[$k].Name
        }
    }
    return @($items)
}


function Get-AvailableMemoryMB {
    <#
        Physical memory this machine could hand a new process RIGHT NOW, in MB, or 0 when the question
        cannot be asked. Split out from Invoke-TestSuiteGate for exactly the reason
        Get-ResidentPowerShellCount above is: OS-wide state is not something a test fixture can set up,
        but a plain function can be shadowed by redefining it after this file is dot-sourced -- which is
        how test-suite-gate.tests.ps1 measures the lane formula against a machine it does not have.

        Win32_OperatingSystem.FreePhysicalMemory, and NOT Get-Counter '\Memory\Available MBytes', which
        is the figure a reader would reach for first. Performance-counter paths are LOCALISED: on the
        Dutch-language Windows this was measured on, that exact call fails with "The specified object
        was not found on the computer", and a lane formula that silently loses its memory term on every
        non-English machine is worse than one that never had it. The CIM property is language-independent.

        FREE rather than AVAILABLE, deliberately. Win32_PerfRawData_PerfOS_Memory.AvailableBytes is the
        wider definition -- it also counts the standby cache Windows can reclaim -- so by definition it
        is at least this class's figure, and reading it would mean a second CIM class for a number the
        caller then divides by a per-lane reservation carrying its own margin.

        THE MEASURED PAIR CAME OUT THE OTHER WAY ROUND, AND THAT IS THE POINT RATHER THAN A CONTRADICTION:
        2,963 MB from AvailableBytes against 3,063 MB from this class, read seconds apart on a machine
        whose free memory was moving between the two calls. So the gap between the definitions is smaller
        here than the noise on either of them -- which is the whole argument for taking the cheaper
        property, and also the reason this figure is never treated as precise anywhere downstream.

        Returns 0 rather than throwing, the same contract Get-ResidentPowerShellCount states: a gate
        must not fail because a diagnostic it only wanted to size a pool with could not be read. The
        caller reads 0 as "do not apply a memory term" and falls back to the core formula alone.
    #>
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if ($null -eq $os -or $null -eq $os.FreePhysicalMemory) { return 0 }
        return [int]([double]$os.FreePhysicalMemory / 1024.0)
    } catch {
        return 0
    }
}


function Get-TestSuiteGateLaneCount {
    <#
        Invoke-TestSuiteGate's automatic lane count, as a PURE judgement over two integers -- issue #2121.

        WHY IT IS A FUNCTION AND NOT FOUR LINES INSIDE THE POOL, which is where it lived until this
        change. Both inputs are properties of the MACHINE, so the arithmetic inside the gate is only
        reachable by running a real pool on a real box, and what that pool then reports is clamped to the
        suite count and therefore says nothing about the formula. Get-GateSuspendCredit above is the same
        shape for the same reason and is the precedent followed here: the judgement is asserted directly,
        and the stub around it proves only the plumbing.

        THE LOWER OF TWO RESERVATIONS. Cores minus two -- the older term, whose own reasoning is at the
        call site -- and free physical memory divided by $script:TestSuiteGateLaneMemoryMB, the newer one,
        whose measurement is in that constant's banner. Floor 2 on each, and therefore on the result.

        -AvailableMemoryMB 0 MEANS 'COULD NOT ASK', NOT 'NO MEMORY', which is Get-AvailableMemoryMB's
        stated contract one caller up. It resolves to the core count alone, exactly the behaviour this
        function replaced -- so a machine that cannot answer is never throttled to the floor on the
        strength of a reading nobody took. Any negative value is treated the same way.

        Returns the count and the two terms behind it, because the caller prints them: a run that chose 6
        lanes where the cores would have allowed 30 has made the largest single decision about its own
        trustworthiness, and #2121 is a report about that decision being invisible.
    #>
    param(
        [int]$ProcessorCount,
        [int]$AvailableMemoryMB
    )

    $coreLanes = [Math]::Max(2, $ProcessorCount - 2)
    if ($AvailableMemoryMB -le 0) {
        return [pscustomobject]@{
            Lanes       = $coreLanes
            CoreLanes   = $coreLanes
            MemoryLanes = 0
            BoundBy     = 'cores'
        }
    }

    $memoryLanes = [Math]::Max(2, [int][Math]::Floor($AvailableMemoryMB / [double]$script:TestSuiteGateLaneMemoryMB))
    # TIES GO TO 'cores', deliberately: the caller prints only when memory bound, and a line announcing
    # that memory chose a number the cores would have chosen anyway is noise that teaches a reader to
    # stop reading it.
    if ($memoryLanes -lt $coreLanes) {
        return [pscustomobject]@{
            Lanes       = $memoryLanes
            CoreLanes   = $coreLanes
            MemoryLanes = $memoryLanes
            BoundBy     = 'memory'
        }
    }
    return [pscustomobject]@{
        Lanes       = $coreLanes
        CoreLanes   = $coreLanes
        MemoryLanes = $memoryLanes
        BoundBy     = 'cores'
    }
}


function Get-ResidentPowerShellCount {
    <#
        The number of powershell.exe processes on this MACHINE right now (this repo's gate targets
        Windows PowerShell 5.1 -- see this file's header). Split out from Invoke-TestSuiteGate as its
        own function for exactly one reason: OS-wide process state is not something a test fixture can
        set up, but a plain function can be shadowed by redefining it after this file is dot-sourced --
        the same seam Get-TestCommands above already relies on for the same purpose.

        Returns 0 rather than throwing when Get-Process itself refuses (not a case this repo has hit --
        the caller uses this figure to WARN, and a diagnostic that can fail the run it is only trying
        to comment on would be worse than no diagnostic at all).

        WHY A COUNT AND A WARNING, AND NOT A REAP (issue #1464). The issue that asked for this named two
        heavier options -- track and reap spawned PIDs on the gate's own exit paths, or run the lanes
        inside a Windows job object so the tree dies with the parent by construction -- and declined to
        propose either from inside a report. Both are real changes to Invoke-TestSuiteGate's spawn model,
        for a hazard that is namable far more cheaply than it is fixable: this function is the cheap half,
        landed on its own rather than waiting on a rewrite neither this fix nor that issue commits to.
    #>
    try {
        return @(Get-Process -Name 'powershell' -ErrorAction Stop).Count
    } catch {
        return 0
    }
}

function Invoke-TestSuiteGate {
    <#
        Runs every *.tests.ps1 in $TestsDir as a child process and returns $true when they all passed.
        Prints each suite's name and its own output as it goes, so a failure is attributable without a
        second run.

        ONE OWNER, BECAUSE THERE ARE NOW TWO GATES (August 7, 2026). open-pr.ps1 has run the suites
        before pushing since PR #54's lesson; cut-release.ps1 ran the LINT only, which made the release
        commit the least-checked commit in the workflow -- the one that bumps four plugin versions,
        rewrites four RELEASE.md cards and empties CHANGELOG.md. Issue #510.

        The obvious repair was to copy those fifteen lines into the cut. That is the duplication this
        repo spent August 7 removing in six other places: two copies of one rule, free to drift, with the
        one that drifts being whichever nobody looked at. So the loop moved here and both call it.

        WHY THIS LIB AND NOT A NEW ONE, stated because the fit is imperfect. This file's synopsis is "run
        a native command safely and capture its output + exit code", and a test-suite gate is a step above
        that. A dedicated gate-lib.ps1 would read better -- and would cost an entry in the shared-scripts
        registry, a mirror file, and a row in the script contract, for one function. Both callers already
        dot-source this lib, and what the function does IS running child processes and judging their exit
        codes. The trade was taken deliberately; if a second gate helper ever appears, move both out
        together rather than widening this file again.

        NOT -SkipTests AWARE. The caller owns the escape valve, because the two differ: open-pr's is
        -SkipTests, the cut's is its own flag, and a lib that knew about either would be reaching into its
        callers' parameter sets.

        A KILLED RUN'S CHILDREN OUTLIVE IT, AND THE NEXT RUN CANNOT SEE THAT -- issue #1464, September 5,
        2026. Start-Process children are never tracked past this function's own $running list, which lives
        in memory this process loses the moment something kills it -- a harness OOM-kill, most measured --
        so nothing here ever reaps them. An immediate retry can then be killed too, even with -MaxParallel
        set correctly, because the retry's own memory budget assumed room a prior run's orphans were still
        holding: measured as 28 orphaned processes and 1.7 GB free where -MaxParallel alone reported nothing
        wrong. This function does not reap anything -- see Get-ResidentPowerShellCount above for why a
        warning is what shipped and a job-object rewrite of the spawn model did not. It prints one line
        naming the resident count when it looks anomalous, so the NEXT kill reads as "something is still
        draining" instead of "the machine got slower".

        THE REPO'S OWN TEST COMMANDS RUN HERE TOO (inbound #644, August 13, 2026). The gate globbed
        scripts\tests\*.tests.ps1 and nothing else, while both callers describe it as "all test suites
        green" -- true in the source, whose suites are all PowerShell, and an overstatement in a consumer
        whose stack is not: the reporting repo runs 4 PowerShell suites next to 605 Vitest tests, and the
        gate saw only the first number. The release route is where that gap bites, because it is the one
        route with no later gate that can still stop anything -- CI fires after the tag is pushed, against
        a commit this repo's own rules say is not rewritten.

        The seam is the optional Get-TestCommands in scripts/repo-config.ps1: extra command lines to run
        alongside the suites (e.g. 'npm test'), defaulting to none, so an unadopting repo keeps exactly
        yesterday's gate. IT IS READ HERE AND NOT AT THE CALL SITES, deliberately: a seam read once in
        the shared gate cannot leave the gates checking different things -- which is this function's
        founding rule, stated above. THE CALLERS ARE THREE, NOT TWO, and each must have dot-sourced
        repo-config before calling this: open-pr and cut-release do so for their other seams, and
        ci.yml does so explicitly for this one -- it dot-sources only this lib otherwise, and without
        that line the required merge-blocking check would be the one gate that cannot see the repo's
        own commands, silently. The
        commands run SEQUENTIALLY, after the parallel pool: their runtimes and internal parallelism are
        their own (npm test manages its workers itself), and sequential output needs no capture files to
        stay attributable. Each runs as its own powershell child with the caller's location, exit code
        propagated, and a failing command fails the gate exactly like a failing suite.

        THE SUITES RUN IN PARALLEL (issue #512, August 7, 2026). Measured in the source repo on one machine
        within one session, all 27 suites green every time: 510s one at a time, against 128-263s parallel
        over six runs (median 159s). Every suite is an independent child process that spends most of its
        time waiting on children of its own, so running them sequentially was the simplest possible
        arrangement rather than a considered one. Parallel, the gate costs what its SLOWEST SINGLE SUITE
        costs instead of the sum -- which is why the remaining half of #512 matters more after this change
        than before it (check-plugin-integrity.tests, ~154s for 86 full lint runs over its fixture: the
        critical path all by itself), and also why the spread above is wide where the sequential figure is
        not. A sum averages its own variance out; a maximum does the opposite.

        AND THAT REMAINING HALF WAS THE WHOLE BILL, MEASURED (August 16, 2026, issue #714). At 40 suites the
        gate's total EQUALLED that one suite to a tenth of a second, four runs out of four: every other
        suite finished at 126.9s, after which one process ran alone for another 70-86 seconds with 15 of 16
        lanes empty. A new suite could therefore only lengthen the gate by CONTENDING with it -- which is
        what the "+40% and diffuse" report in #714 had actually measured. Because this scheduler
        parallelises per FILE, the repair was to make that work more than one file: it is now four suites
        sharing one fixture builder, ~51s across four lanes instead of ~160s in one, with no scenario
        removed. Read before proposing anything about this gate's cost: the lever is the slowest FILE, and
        splitting it is available where narrowing it is not.

        WHY Start-Process AND NOT A JOB. Windows PowerShell 5.1 has no ForEach-Object -Parallel, and
        Start-Job pays for a whole runspace to then spawn the same child process this does directly. What
        parallelism costs here is the console: two dozen suites writing to one screen interleave into an
        unreadable weave, so each child's output is captured to its own pair of files and printed as ONE
        BLOCK when it exits. Attribution therefore comes from the '== <suite> ==' header the block opens
        with, not from its position -- which is the property that mattered in the sequential version too.
        Blocks arrive in COMPLETION order, so the log is no longer alphabetical; the closing summary names
        the failures in a fixed order for that reason.

        AND ON A RED RUN THOSE CAPTURE FILES SURVIVE, named on the verdict line -- issue #1636. A green run
        deletes them as it always did; a run with a failing suite keeps that suite's pair and deletes the
        rest, so the console stops being the only copy of the evidence. See the 'finally' block for why
        printing the block was not enough on its own.

        -WorkingDirectory IS NOT OPTIONAL, and leaving it off is the one way this rewrite could have
        broken a suite silently. Start-Process starts the child in [Environment]::CurrentDirectory, which
        does NOT follow Set-Location -- so a suite that asks git about "the tree I am in" would have been
        answered by whatever directory the process was launched from, days ago. roster-sync.tests.ps1
        asserts exactly that (Sylvester's lens: "run a suite from the tree it is meant to judge"), and a
        false red there reads like a regression in the branch under test. Passing PowerShell's own location
        reproduces precisely what '& powershell -File' handed the child before.

        ONE CONSOLE, AND THAT IS SHARED STATE BETWEEN SUITES (inbound #821, August 21, 2026). -NoNewWindow
        means every child attaches to THIS console, so anything a suite does to the console rather than to
        itself is done to all of them. The measured case is [Console]::OutputEncoding, whose setter is
        SetConsoleOutputCP: one suite held it at UTF-8 for its whole run, and while that window was open
        every concurrently scheduled suite decoded native output as UTF-8 too. A second suite's accented-path
        assert was therefore GREEN under the gate and RED on its own, on the same commit -- and the bug it
        was correctly reporting (a git path decoded with the inherited code page) read as a test quirk for
        as long as nobody ran it alone. Reproduced deterministically by starting the two 1.2s apart.
        The rule that follows: a suite green under the gate and red standalone is reporting a real defect
        until proven otherwise, because the gate is the run with the shared state in it. Isolating the
        console per suite is possible (its own hidden console instead of -NoNewWindow) and is NOT done here:
        it changes how all 50 children are created, for a hazard whose one known instance is now scoped to
        a few lines inside the suite that needs it. Named rather than fixed, deliberately.

        AND THE CONVERSE, MEASURED (issue #1033, August 28, 2026). The rule above reads in one direction
        only, and the commoner event is the other one: a suite RED under the gate and GREEN standalone. A
        re-run during the v4.22.0 cut reported 11 of 54 suites failed in 626s, every one with the same
        shape -- a child that exited 1, then every downstream assert about what that child should have
        written -- on a tree the cut itself had just passed 54/54 on. The report inferred that the verdict
        depended on WHO CALLED the gate, because the red run came from a session that had dot-sourced this
        lib and repo-config while the green one came from cut-release.ps1. IT DOES NOT: cut-release
        dot-sources exactly those two libs before calling this function, so both runs had identical state,
        and the axis the report names cannot be the difference. Five full runs on that same tree were all
        54/54 green -- 16 lanes 194s, 18 lanes 216s, 18 lanes with the console at UTF-8 203s, and two
        18-lane runs side by side 421s and 419s. That last pair is the number to keep: 2x load reproduces
        the release's own 443s "green" wall clock to within 5%, which makes 443s a reading of the MACHINE
        rather than a cost of this gate, whose cost on that tree was ~200s.

        SO A RED HERE IS EVIDENCE ABOUT THE RUN BEFORE IT IS EVIDENCE ABOUT THE TREE, and the standing
        response is re-running the suite alone -- which is already written down twice, from two earlier
        sightings of these same suites: the Start-Job fan-out of August 12, 2026 (6 of 31, all green
        alone) and the two reds in the post-split pool of August 16 (bootstrap-drift and fix-mojibake,
        both green alone, not diagnosed). What cost 22 minutes of that release was not the flake; it was
        that neither page was reached before the chase started.

        AND SINCE #1723 ONE HALF OF IT IS REPAIRED -- THE HALF THAT WAS NEVER A FLAKE. #1723 measured a
        30-lane run whose two reds had two different shapes, and only one of them was this paragraph's
        subject. The other was a suite whose PROCESS DIED: branch-entry-gate.tests.ps1 ended mid-suite on
        a [PASS] line with no [FAIL] anywhere, its .err file carrying System.AccessViolationException from
        WildcardPatternMatcher.PatternPositionsVisitor.Add under CommandSearcher.SearchForFunctions -- a
        Get-Command probe faulting while walking the function table. That suite did not fail; it never
        finished, so it returned no verdict at all, and this function reported it as
        'FAILED (exit -1073741819)' because it judges on the exit code alone.
        A CRASH IS THEREFORE NOT A VERDICT, and it is now told apart from one: Test-GateSuiteCrashed
        reads the sign bit (see it for why that is exact rather than a list of codes), the header says
        CRASHED with the code as hex, and the suite is re-run ALONE once after the pool has emptied --
        which is precisely what the paragraph above already told a reader to do by hand. Green on the
        re-run leaves the gate green and still names the crash on the verdict line; a second crash, or a
        real failure the crash was hiding, is red.
        WHAT IS STILL NOT REPAIRED is the flake this paragraph opened with -- a suite that exits 1 under
        the pool and 0 alone. Nothing here retries that, deliberately: an exit 1 has measured the tree
        and said no, so re-running it would mask a verdict rather than obtain one. The console is still
        not isolated either, for the reason given above.

        SHARDING: -Shard/-ShardCount RUN ONE SLICE OF THE POOL (issue #1351, September 3, 2026). The
        paragraph above says the lever is the slowest FILE and that splitting one is available where
        narrowing it is not. That was the answer while the gate had lanes to spare. It does not hold on a
        hosted runner, which is where the number that actually blocks a merge is produced: measured on run
        33798952362, `lint-en-tests` spent 12m23s of its 13m03s in this function -- 'all 64 suites passed
        in 742s (4 lanes)' -- against ~200s for the same pool on 16-18 lanes on a workstation. In
        lane-seconds that is 2968 against ~3400: comparable total work, so the 3.7x is LANE COUNT, and
        `windows-latest` has four cores. The gate was not critical-path-bound there (the #714 regime, where
        its total equalled one file to a tenth of a second) but contention-bound, which is the one regime
        where adding lanes is close to linear -- and the only way to add lanes to a four-core runner is to
        use more than one runner.
        So the caller may now ask for a quarter of the pool and run four of itself. ci.yml does; every
        other caller passes neither parameter and gets the whole pool, unchanged, down to the wording of
        its summary line.

        A SHARD IS BOUND BY max(ITS LONGEST FILE, ITS LANE-SECONDS / ITS LANES) -- AND UNTIL #1364 ONLY
        THE FIRST TERM WAS EVER CHECKED (issues #1354 and #1358, corrected September 4, 2026). This
        paragraph used to say a sharded job is max(longest file) plus provisioning, full stop, and drew
        two conclusions from it: that raising the shard count stops paying, and that a duration-aware
        bin-pack "would reach that same wall, so recording durations to FEED ONE buys nothing here." The
        first conclusion survives. THE SECOND WAS FALSE, and this function now does feed one.
        WHAT THE OLD READING MISSED is that it was only ever tested where the first term dominates. It
        was measured on the four check-plugin-integrity-* suites because the stride happened to put those
        in queue positions 3-4, which is also the only place a duration could be read off a log at all --
        so the evidence was drawn entirely from the shards where the file was the binding constraint, and
        generalised to the ones where it is not. Read off the first REAL per-suite tables (runs
        33842129201 and 33812817842, 4 shards x 4 lanes): three of four shards finished ABOVE their
        longest file, by 41-95s. Their lane-seconds over four lanes already exceeded it, so they were
        work-bound, and no split of any file in them would have moved anything.
        WHICH MAKES THE PARTITION THE LEVER, NOT THE FILES, and it was worth 305s -> 237s on the measured
        pool -- see Get-TestSuiteShardOrder above for the four-way simulation, including the result that
        packing WITHOUT reordering is worse than doing neither. The same measurement is what closes the
        file-splitting question rather than opening it: at 237s the pool finally is at its longest file,
        and splitting that file buys the ~15s gap to the 16-lane work bound, for the price of preserving
        340 asserts across ~2,950 lines.
        THE SHARD-COUNT CONCLUSION IS UNCHANGED, and now has the arithmetic it was missing: another
        runner lowers only the second term. Once max(longest file) is the larger of the two -- which is
        exactly where a balanced partition lands you -- an extra shard buys its own ~20s of provisioning
        and nothing else.
        AND #1358's OWN FIGURES ARE A STANDING WARNING about where all of this came from: until the gate
        began reporting durations, it named the wrong suite as the pool's heaviest and put seven others
        outside a band they are in.
        AND PAST THAT POINT THE LEVER IS INSIDE THE FILE, NOT AROUND IT -- so #714's "split the slowest
        file" is one answer and not the only one. What a heavy suite here actually costs is its child
        processes: the four check-plugin-integrity suites are ~100% their own lint invocations, and #1358
        took ~12.6% off all four by removing a duplicated AST walk from the script they invoke, without
        touching this function or any partition. A caller staring at a slow required check should price
        that before buying another runner.
        ONE WARNING FOR WHOEVER RE-MEASURES: READ THE TABLE THIS FUNCTION PRINTS, NOT THE LOG TIMESTAMPS.
        Every suite's duration and the offset at which its lane opened are reported after the pool (#1364,
        stated again below). THE WARNING OUTLIVED THE FIX because the misleading timestamps did: this
        function buffers a suite's output until that suite completes, so a log
        timestamp is a FINISH time. Subtracting the shard's start yields a duration only for a suite that
        started at t0 -- queue positions 1..MaxParallel. Do it further down the queue and you are reading
        lane wait as runtime; that error put two files on a five-file "plateau" that has four, one of them
        reconstructed at 189s against 17.0s standalone. Local figures also do not transfer, and NOT by a
        ratio one could divide out: the direction itself changes with the machine -- one suite measured
        2.6x SLOWER solo on an 18-thread workstation than on a four-lane hosted runner, where this
        docstring claimed 3.6-4.0x faster until issue #1713. So a standalone reading is corroboration only
        once the machine AND the lane count are stated, and it is never a conversion.
        WHY THE FUNCTION PARTITIONS RATHER THAN THE CALLER -- and why a STRIDE: both at the partition
        itself, below the suite glob. WHY THIS DOES NOT PAY #714's BILL TWICE: the four
        check-plugin-integrity suites build a fixture EACH, in a per-process directory (that file's own
        header says so), so scattering them across shards duplicates no shared setup -- verified before
        this was written, because a shared builder would have made a stride the worst possible split.
        WHAT SHARDING CANNOT SLICE is Get-TestCommands, handled at its own comment below.
        THE HAZARD IT REMOVES INCIDENTALLY: suites in different shards no longer share a console, so the
        SetConsoleOutputCP class of cross-talk (inbound #821) cannot reach across a shard boundary. The
        rule above still holds WITHIN one.
        AND THE HAZARD IT ADDS: the fail-closed summary. Four green shards prove nothing unless something
        refuses when one of them did not report -- a workflow-level concern, so it lives in ci.yml's own
        banner rather than here, and it is the reason this function throws on a nonsensical (Shard,
        ShardCount) instead of quietly selecting nothing.

        PER-SUITE DURATIONS ARE RECORDED, NOT RECONSTRUCTED (issue #1358). Before that this function timed
        only the pool, and because it buffers a suite's output until that suite exits, the only per-suite
        signal a log carried was a FINISH time. Subtracting the pool's start from it is a duration only for
        a suite that started at t0 -- one of the first -MaxParallel dequeued -- and nothing in the
        arithmetic says so. It cost a five-file plateau that had four members: the method was applied
        correctly to the four suites in the opening lanes and then extended to two sitting 5th and 9th in a
        4-lane queue, reading their lane wait as runtime. The table printed after the pool now carries each
        suite's duration AND the offset at which its lane opened, slowest first, and marks the one that set
        the makespan -- the only suite whose shortening moves the total, which is #714's finding and the
        thing every wall-clock question about this pool starts from.

        THE POOL REPORTS ITS OWN PROGRESS (issue #1717, September 9, 2026). Because this function buffers
        a suite's output until that suite exits, a run used to print one line naming the lane count and
        then nothing for 15-30 minutes -- so an operator sitting through their own gate could not tell
        20/84 from 70/84, nor a slow run from a wedged one. It now prints one line as each lane opens and
        one as each suite leaves one: started, done and running out of this run's own total, with the
        elapsed clock and the gate's NESTING DEPTH. All of the reasoning -- why started is reported as
        well as done, why the three external ways of deriving this each failed, why the '== <suite> =='
        header is untouched, and why no remaining-time estimate is printed -- is in
        Format-GateProgressLine and Get-GateNestingDepth above, beside the code that shapes the line.

        NO SUITE RUNS UNBOUNDED ANY MORE -- issue #1941, September 13, 2026. Until then this loop had NO
        deadline of any kind: it slept 100 ms and went round again for as long as a lane took, whatever
        had stopped that lane progressing. One wedged suite therefore wedged the entire gate, and did it
        SILENTLY, because this function buffers a suite's output until that suite exits -- a suite that
        never exits prints nothing after its opening 'started' line. Measured on DAVE-KOK-BWJ: 141
        minutes, 61 powershell.exe and 29 git.exe alive, 0.23 s of CPU between all 29 git children, no
        output, no error, no red, and nothing to stop a later gate on that machine starting its own 30
        lanes on top of them.
        SO EACH LANE NOW CARRIES A DEADLINE ($script:GateSuiteTimeoutSeconds, -SuiteTimeoutSeconds to
        override, a NEGATIVE value to turn it off). Past it the lane's process TREE is killed, and past a
        further grace window a lane that did not die is ABANDONED rather than waited on -- which is the
        half that actually makes this loop terminate, since Stop-NativeProcessTree is best-effort and a
        kill that taskkill refuses would otherwise put the pool straight back into the unbounded wait.
        A TIMEOUT IS A FOURTH VERDICT AND IT IS NOT RE-RUN, which is the one judgement worth arguing.
        #1723's crash path re-runs a suite alone because a killed process measured nothing, so a re-run
        is the only way to get a verdict at all. A timeout HAS measured something: this suite did not
        finish inside a window sized at ~6x the slowest run this repo has ever recorded. Re-running it
        alone would remove the contention that is the likeliest cause, pass, and hand back a GREEN gate
        over a run that cost the machine 90 processes -- which is the exact silence #1941 was filed
        about. So it goes red, its capture files are kept, and the verdict names it.
        WHAT THIS DOES AND DOES NOT CLAIM: #1941's own inferred cause (a blocked-pipe deadlock in the
        Start-Process capture) is unverified, and nothing here repairs it. This bounds it, names which
        suite it was, and keeps the evidence -- which is also what closes the residual #1704 was left
        with, a degraded run that keeps no per-suite table.

        AND THAT BOUND COUNTED MACHINE SUSPEND UNTIL ISSUE #2095, September 18, 2026. The deadline is
        read off a Stopwatch, which keeps accruing while the machine sleeps, so the first poll after a
        wake found every open lane hours past a 1,800s bound and killed the two suites that happened to
        be in flight -- both of which pass in seconds, and both of which the same tree had just run
        green twice. The verdict was false, the remedy it printed ('Fix the tests') named a defect that
        did not exist, and the gate refused the push, which on an unattended overnight run is the rest
        of the night. It also plausibly answers #1704's 'cause not established' -- a gate that reported
        11,112s for a pool it runs in ~225s is the same shape, a normal run plus one multi-hour
        discontinuity with no CPU behind it, so #1941's bound had been converting that unexplained
        stall into an unexplained test failure.
        SO THE POLL LOOP WATCHES ITS OWN CLOCK (Get-GateSuspendCredit, $script:GateSuspendGapSeconds).
        A jump no 100 ms poll can produce is credited back to every lane that was open across it, by
        moving their start offsets rather than the clock -- a lane opened after the wake was not asleep
        and must not be credited. #1941 is untouched by this: a deadlocked tree produces no jump, since
        the loop goes on polling while the suite does not move.

        -FocusSuite PUTS ONE SUITE UNDER THIS POOL'S REAL CONTENTION -- issue #1944. This repo has a
        whole CLASS of defect visible only here: a suite red under the pool and green standalone (#1915,
        #1939, three days apart, different files, identical discovery path -- the gate refusing a push on
        a branch that touched neither). There was no way to reproduce that for ONE suite, so repairing
        one meant running the whole ~19-minute gate to learn whether the repair held, because a
        standalone run is green BY DEFINITION OF THE BUG. A synthetic imitation does not substitute and
        that was measured: sixteen concurrent PowerShell processes spawning short-lived children reached
        0.47-0.95s launch-to-print against the real gate's 3.25s, ~3.4x short, with the suite staying
        green under it.
        SO THE LOAD IS REAL SIBLING SUITES, composed by Get-TestSuiteFocusOrder above -- same pool, same
        console, same spawn model. Only the named suite's repeats decide the verdict; the load's do not,
        and its headers say so. A focus run is a REPRODUCTION, not a gate, and every line it prints says
        which it is -- because 'all 47 suites passed' off one of these would be read as a measurement of
        the tree, and it is a measurement of one suite, N times.
        THE TARGET IS NOT RE-RUN ALONE ON A CRASH EITHER, unlike an ordinary run: running it alone is
        exactly what this mode replaces, so a crash under load is the answer being asked for and is red.

        Returns $true when every suite exited 0, $false when any did not, and $true with a warning when
        there is nothing to run -- an empty or missing directory is a repo without suites, not a failure,
        and neither is a shard that drew none of them. In a focus run it returns $true only when every
        repeat of the named suite passed; the load's verdicts are reported and decide nothing.
    #>
    param(
        [Parameter(Mandatory)][string]$TestsDir,
        [string]$Context = 'the gate',
        # 0 = decide from the machine. 1 = run them one at a time, which is the valve for debugging a
        # suite that only fails with 25 siblings competing for the disk -- a real possibility this
        # function introduces, so it ships with the way to rule it out.
        [int]$MaxParallel = 0,
        # WHICH SLICE OF THE POOL TO RUN, 1-based; 0 (both) = the whole pool, which is the unchanged
        # behaviour every existing caller gets. See the SHARDING banner in the docstring for why the
        # partition is computed HERE from two integers rather than taken as a list of suite names.
        [int]$Shard = 0,
        [int]$ShardCount = 0,
        # THE DEADLINE ONE SUITE RUNS UNDER (issue #1941). 0 = resolve $script:GateSuiteTimeoutSeconds,
        # the same "0 means decide for me" idiom -MaxParallel above already uses in this function, so a
        # caller that passes neither gets the module's answer to both. A NEGATIVE value turns the bound
        # OFF -- the escape valve for a deliberately long-running suite, and the only way back to the
        # unbounded wait this function had until #1941.
        [int]$SuiteTimeoutSeconds = 0,
        # PUT ONE SUITE UNDER THE POOL'S REAL CONTENTION (issue #1944). Naming a suite here turns the run
        # from a gate into a REPRODUCTION: the named suite runs -FocusRepeat times while real sibling
        # suites fill every other lane, only the named suite's verdicts decide the result, and the
        # summary reports per repeat. See Get-TestSuiteFocusOrder above for how the queue is composed
        # and why the load is real suites rather than a synthetic imitation.
        [string]$FocusSuite = '',
        [int]$FocusRepeat = 5
    )

    # BOTH OR NEITHER, AND IN RANGE -- REFUSED RATHER THAN INTERPRETED. Every wrong combination here has
    # a plausible-looking silent reading, which is this file's own documented failure family (see the
    # .Handle comment further down): -Shard 3 with no -ShardCount could defensibly mean "the whole pool",
    # and -Shard 5 -ShardCount 4 selects nothing and would report a green gate over zero suites. A gate
    # that silently ran none of its suites is exactly the shape of #1294's dropped runs -- green, and
    # measuring nothing -- so this is the one input this function will not guess at. It throws rather
    # than returning $false: a caller that passed nonsense has a bug, and a red gate would send its
    # operator looking at the suites instead.
    if (($Shard -gt 0) -ne ($ShardCount -gt 0)) {
        throw "Invoke-TestSuiteGate: -Shard and -ShardCount go together -- got Shard=$Shard, ShardCount=$ShardCount."
    }
    if ($ShardCount -gt 0 -and ($Shard -lt 1 -or $Shard -gt $ShardCount)) {
        throw "Invoke-TestSuiteGate: -Shard must be between 1 and -ShardCount ($ShardCount) -- got $Shard."
    }
    # FOCUS AND SHARDING ARE TWO ANSWERS TO ONE QUESTION, and the combination has no meaning worth
    # guessing at -- refused on the same ground as the pair above. Sharding divides the pool so four
    # runners cover it between them; focus replaces the pool with one suite plus purpose-built load.
    # A sharded focus run would slice load that was sized for a whole lane count and then report a
    # reproduction attempt that never reached the contention it was asking about.
    if ($FocusSuite -and $ShardCount -gt 0) {
        throw "Invoke-TestSuiteGate: -FocusSuite and -Shard/-ShardCount cannot be combined -- focus replaces the pool, sharding divides it."
    }
    if (-not $FocusSuite -and $PSBoundParameters.ContainsKey('FocusRepeat')) {
        throw "Invoke-TestSuiteGate: -FocusRepeat means nothing without -FocusSuite."
    }
    $focusMode = [bool]$FocusSuite

    # THE DEADLINE, RESOLVED ONCE HERE so every site below reads one number (issue #1941). Negative is
    # the off switch and is carried through as 0, which is what the pool's own checks test for.
    $suiteDeadline = if ($SuiteTimeoutSeconds -lt 0) { 0 }
                     elseif ($SuiteTimeoutSeconds -eq 0) { $script:GateSuiteTimeoutSeconds }
                     else { $SuiteTimeoutSeconds }

    # ADVISORY ONLY, AND CHECKED BEFORE THIS RUN ADDS A SINGLE CHILD OF ITS OWN (issue #1464). See
    # $script:ResidentPowerShellWarnThreshold and Get-ResidentPowerShellCount above for the numbers and
    # the reasoning; this never blocks the run, because a resident count says nothing about whose
    # processes they are or whether they are about to exit on their own -- it only names what a silent
    # kill would not have: that the number was already unusual before this run started.
    $residentPowerShell = Get-ResidentPowerShellCount
    if ($residentPowerShell -gt $script:ResidentPowerShellWarnThreshold) {
        Write-Warning ("test gate: $residentPowerShell powershell processes already resident before " +
            "this run started -- a recent gate may still be draining; consider waiting or lowering " +
            "-MaxParallel.")
    }

    # The repo's own extra test commands (inbound #644) -- read via Get-Command like every other optional
    # repo-config function, so a repo that defines nothing is untouched and a missing repo-config cannot
    # crash the gate.
    $extraCommands = @()
    if (Test-FunctionDefined 'Get-TestCommands') {
        $extraCommands = @(Get-TestCommands | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
    }

    $suites = @()
    if (Test-Path -LiteralPath $TestsDir) {
        $suites = @(Get-ChildItem -Path $TestsDir -Filter '*.tests.ps1' -File | Sort-Object Name)
    }
    $poolTotal = $suites.Count

    # THE PARTITION IS COST-AWARE, AND SO IS THE QUEUE ORDER -- issues #1351 and #1358.
    #
    # BOTH DECISIONS LIVE IN Get-TestSuiteShardOrder, above, together with the measurements that set
    # their shape and the reason neither half is worth building without the other. What matters here is
    # only what this call does to the rest of this function: it returns THE SUITES THIS SHARD RUNS, in
    # THE ORDER THE QUEUE BELOW SHOULD DEQUEUE THEM. Nothing downstream reorders it.
    #
    # THE STRIDE IS STILL IN THERE and is still what a caller without a suite-durations.json gets --
    # including every consuming repo that copies this lib, which is most of them. What the stride was
    # chosen for (never piling the alphabetically-adjacent check-plugin-integrity-* suites into one
    # shard, WITHOUT this function having to know what anything costs) is unchanged in that path; the
    # cost-aware path simply no longer has to approximate cost by name.
    #
    # WHY THE HINTS ARE READ HERE AND NOT PASSED IN. Same answer as the two integers: the alternative is
    # a list the caller keeps in sync with a directory, and this repo has measured what happens to a
    # second copy of a list nobody looks at (#512's inline gate copy, which would have kept running the
    # suites one at a time for days after both local callers were parallelised). A file that lives beside
    # the suites cannot drift from a workflow it is not written in.
    $costHints = Get-TestSuiteCostHints -TestsDir $TestsDir

    # THE LANE COUNT IS RESOLVED BEFORE THE QUEUE IS COMPOSED, not after (issue #1944). It used to sit
    # inside the pool block below, which was fine while the queue was the directory glob -- nothing about
    # the order depended on how many lanes would run it. A focus run does: the load is sized in
    # lane-seconds, so Get-TestSuiteFocusOrder cannot be called before this number exists. Only the
    # MACHINE half moves here; the clamp to the queue's own length stays below, because in focus mode the
    # queue is longer than the directory and clamping to the directory would starve the lanes it is
    # sizing load for.
    #
    # Two cores held back: the suites spawn children of their own, and a gate that saturates the machine
    # it runs on makes every other window on it unusable for two minutes. The floor is 2 and not 1,
    # because on a four-core machine that reservation would otherwise cost HALF the box and a two-core one
    # would fall back to the sequential loop this replaced -- and the suites spend most of their time
    # waiting on children rather than computing, so a little oversubscription is cheap. A runner nobody is
    # sitting at should pass its own core count instead; ci.yml does.
    #
    # AND THE CORES ARE ONLY HALF THE QUESTION -- issue #2121. What a lane exhausts is memory, not CPU,
    # so the automatic count is the LOWER of the two reservations: cores minus two, and free physical
    # memory divided by $script:TestSuiteGateLaneMemoryMB. The constant's own banner carries the
    # measurement, both the runs that produced it and why the margin is deliberate. The floor of 2
    # survives both terms -- a machine too small for two lanes is one the sequential loop this replaced
    # would not help either, and refusing to run at all is not a verdict a gate gets to reach.
    #
    # A MEMORY READING OF 0 MEANS 'COULD NOT ASK', NOT 'NO MEMORY'. Get-AvailableMemoryMB returns 0 on
    # any failure, by the same contract Get-ResidentPowerShellCount states, so a machine that cannot
    # answer falls back to exactly the core formula it had before this change rather than to two lanes.
    # The two states are distinguishable here and nowhere downstream, which is why the branch is here.
    $laneLimitReason = ''
    if ($MaxParallel -le 0) {
        $availableMB = Get-AvailableMemoryMB
        $laneChoice  = Get-TestSuiteGateLaneCount -ProcessorCount ([Environment]::ProcessorCount) -AvailableMemoryMB $availableMB
        $MaxParallel = $laneChoice.Lanes
        if ($laneChoice.BoundBy -eq 'memory') {
            # SAID OUT LOUD, BECAUSE THE SILENCE IS HALF OF WHAT #2121 REPORTED. The knob existed and
            # worked; what no line anywhere told a session was that the lane count was worth suspecting.
            # A run that quietly picks 6 where the core formula would have picked 30 has made the single
            # largest decision about its own trustworthiness, and it now names the figures it made it on
            # -- so a later reader of this console can check the arithmetic instead of re-deriving the
            # whole finding from three gate runs, which is what #2121 cost.
            $laneLimitReason = ("memory, not cores: $availableMB MB free / $($script:TestSuiteGateLaneMemoryMB) MB per lane " +
                                "= $($laneChoice.MemoryLanes), under the $($laneChoice.CoreLanes) this machine's cores would allow (issue #2121)")
        }
    }

    # THE QUEUE, AS ITEMS RATHER THAN FILES. Every entry carries File/IsTarget/Label/Stem -- see
    # Get-TestSuiteFocusOrder for why the stem has to be per-ITEM and not per-file. An ordinary run wraps
    # the shard order in exactly the same shape, so the pool below has one kind of thing to handle and a
    # focus run is not a second code path through it.
    $runItems = @()
    if ($focusMode) {
        if ($suites.Count -eq 0) {
            throw "Invoke-TestSuiteGate: -FocusSuite '$FocusSuite' was asked for, but $TestsDir holds no *.tests.ps1 suites."
        }
        $runItems = @(Get-TestSuiteFocusOrder -Suites $suites -Costs $costHints `
                        -FocusSuite $FocusSuite -Repeat $FocusRepeat -Lanes $MaxParallel)
    } else {
        $suites = @(Get-TestSuiteShardOrder -Suites $suites -Costs $costHints -Shard $Shard -ShardCount $ShardCount)
        $runItems = @($suites | ForEach-Object {
            [pscustomobject]@{ File = $_; IsTarget = $true; Label = $_.Name; Stem = $_.BaseName }
        })
    }

    # Get-TestCommands BELONGS TO ONE SHARD, NOT TO EVERY SHARD (issue #1351). These are the repo's own
    # whole-stack commands -- 'npm test' and its kind -- and they are not a per-file pool this function
    # can slice: running them in all four shards runs the consumer's entire test suite four times, for
    # four times the wall clock this change exists to reduce, and any of them that writes outside its own
    # process (a coverage file, a build artefact, a fixture database) would then have three concurrent
    # writers. Shard 1 carries them. That leaves shard 1 the longest, which is the correct place for a
    # cost that cannot be divided: it is bounded by the commands' own runtime either way, and the pool
    # keeps flowing around it.
    if ($ShardCount -gt 1 -and $Shard -ne 1 -and $extraCommands.Count -gt 0) {
        Write-Host "test gate: $($extraCommands.Count) repo test command(s) run in shard 1 -- not repeated here." -ForegroundColor DarkGray
        $extraCommands = @()
    }

    # A repo with neither suites nor commands is a repo without tests, not a failure -- but each empty
    # half stays quiet once the OTHER half has something to run: a consumer whose whole suite is
    # Get-TestCommands legitimately has no scripts\tests at all.
    #
    # AND UNDER SHARDING AN EMPTY SLICE IS A THIRD THING, which neither warning below describes: more
    # shards than suites is a workflow configured wider than the pool, not a repo without tests, and
    # saying "no suites found in scripts\tests" of a directory holding sixty of them sends the reader
    # to the wrong place. Still green -- there is genuinely nothing for THIS shard to run, and the
    # summary job's fail-closed check is what makes an entire pool of empty shards impossible to
    # mistake for a pass.
    if ($runItems.Count -eq 0 -and $extraCommands.Count -eq 0) {
        if (-not (Test-Path -LiteralPath $TestsDir)) {
            Write-Warning "$TestsDir not found - test gate skipped."
        } elseif ($ShardCount -gt 1 -and $poolTotal -gt 0) {
            Write-Warning "shard $Shard of $ShardCount got none of the $poolTotal suites in $TestsDir - more shards than suites."
        } else {
            Write-Warning "no *.tests.ps1 suites found in $TestsDir - test gate had nothing to run."
        }
        return $true
    }

    $launchDir  = (Get-Location).Path
    $sw         = [System.Diagnostics.Stopwatch]::StartNew()
    # THE SAME INSTANT AS $sw, AS A WALL-CLOCK STAMP -- issue #2101. The published record carries when
    # the run STARTED rather than how long it has been going, because the statusline derives elapsed
    # itself: a Stopwatch cannot cross a process boundary, and a run blocked inside one long child call
    # must not have its bar freeze. Taken here so the bar's clock and the console line's are one clock.
    $gateStartedUtc = (Get-Date).ToUniversalTime()
    # WALL CLOCK THIS RUN OCCUPIED WITHOUT RUNNING, TALLIED -- issue #2095. Only the verdict reads it;
    # the deadlines are corrected by rebasing the open lanes at the moment the jump is observed (see the
    # poll loop), because a lane opened AFTER a suspend must not be credited for one. Kept so the line a
    # session quotes can say which part of its own seconds nothing was running for -- the figure #2095
    # was filed on is '11,749s' for a pool that did 853s of work.
    $suspendedSeconds = 0.0
    $failedNames = New-Object System.Collections.ArrayList
    # THE SUITES WHOSE PROCESS DIED IN THE POOL, whatever their lone re-run then decided -- issue #1723.
    # Out here beside $failedNames because the verdict is printed after the pool block has closed, and a
    # crash that was cleared by its re-run has to reach the GREEN verdict too: that is the line a session
    # copies into a branch document, and 'all 85 suites passed' is not the whole of what happened.
    $crashedNames = New-Object System.Collections.ArrayList
    # PER-SUITE DURATIONS, RECORDED RATHER THAN RECONSTRUCTED -- issue #1358. This function used to time
    # only the whole pool, and it buffers each suite's output until that suite exits, so the ONLY per-suite
    # signal in a log was the timestamp of a completed suite's first line: a FINISH time. Subtracting the
    # pool's start from it gives a duration only for a suite that started at t0, i.e. one of the first
    # $MaxParallel to be dequeued -- and that assumption is invisible in the arithmetic. Measured cost of
    # leaving it implicit: a five-file plateau reported off this pool had four members, because the method
    # was applied correctly to the suites in the opening lanes and then extended to two that were 5th and
    # 9th in a 4-lane queue, reading their lane wait as runtime.
    #
    # BOTH NUMBERS ARE KEPT, and the start offset is the one that was missing. A duration alone still
    # cannot be checked against the pool's makespan by a reader who does not know when the suite began, and
    # the offset is what makes 'this suite waited for a lane' visible instead of inferable.
    $suiteTimings = New-Object System.Collections.ArrayList
    # THE CAPTURE DIRECTORY THAT SURVIVES A RED RUN, named on the verdict line -- issue #1636. Declared
    # out here, beside $failedNames, because the retention decision is made in the pool's own 'finally'
    # (below) and the line that has to state it is printed after that block has closed. Empty means
    # nothing was kept, which is the green case and also the case where a failing suite wrote nothing.
    $retainedCaptureDir = ''
    # THE SUITES THE POOL STOPPED WAITING FOR -- issue #1941. Beside $crashedNames and for the same
    # reason: the verdict is printed after the pool block has closed, and a timeout has to reach it.
    # They are NOT crashes and are deliberately not routed through the crash path -- see the reap loop.
    $timedOutNames = New-Object System.Collections.ArrayList
    # ONE ROW PER FOCUS REPEAT -- issue #1944. Filled in the reap loop, where an item's verdict and its
    # duration are both in hand, and printed as its own table after the pool: the point of a focus run is
    # how the SAME suite fared across N draws under load, which the slowest-first table cannot show
    # because it sorts the draws away from each other.
    $focusResults = New-Object System.Collections.ArrayList

    if ($runItems.Count -gt 0) {
        if ($MaxParallel -gt $runItems.Count) { $MaxParallel = $runItems.Count }

        $modeLabel = if ($MaxParallel -eq 1) { 'one at a time' } else { "$MaxParallel at a time" }
        # 'all N' IS A CLAIM, AND UNDER SHARDING IT IS A FALSE ONE. This line and the verdict at the foot
        # of the function are the two a session copies into a branch document or a commit message, so a
        # sliced run has to say so on both -- otherwise 'all 16 test suites' is on the record for a pool
        # of 64, which reads as 48 suites having been deleted rather than as one shard of four.
        #
        # AND A FOCUS RUN IS NOT A GATE AT ALL, so it says what it is on this line rather than claiming a
        # count of suites it is not measuring: '3 of 91' would be true of the files and a lie about the
        # verdict, which rests on one of them (issue #1944).
        $scopeLabel = if ($focusMode) { "$FocusRepeat x $FocusSuite under $($runItems.Count - $FocusRepeat) load" }
                      elseif ($ShardCount -gt 1) { "shard $Shard/$ShardCount -- $($runItems.Count) of $poolTotal" }
                      else { "all $($runItems.Count)" }
        Write-Host "test gate: running $scopeLabel test suites for $Context ($modeLabel)..." -ForegroundColor Cyan
        if ($focusMode) {
            Write-Host "  FOCUS RUN (issue #1944) -- this is a reproduction, not a gate: only $FocusSuite decides the verdict, the rest is load." -ForegroundColor Yellow
        }
        # WHICH RESERVATION CHOSE THE LANE COUNT, whenever it was not the cores -- issue #2121. Printed
        # only when the memory term actually bound, so an ordinary run sees no byte it did not see
        # before; a caller that passed -MaxParallel never reaches this, because it made the decision
        # itself and has nothing to be told.
        if ($laneLimitReason) {
            Write-Host "  lanes set by $laneLimitReason -- pass -MaxParallel to override." -ForegroundColor DarkGray
        }
        if ($suiteDeadline -gt 0) {
            Write-Host "  each suite is bounded at $(Format-GateSeconds $suiteDeadline)s (issue #1941); -SuiteTimeoutSeconds -1 turns that off." -ForegroundColor DarkGray
        }

        # THE PROGRESS SIGNAL, AND THE DEPTH THAT MAKES IT ATTRIBUTABLE -- issue #1717. The reasoning for
        # both, and for what is deliberately NOT printed, is in Format-GateProgressLine above; here are
        # only the three moving parts. $startedCount and $doneCount are kept explicitly rather than read
        # off $suiteTimings and $running, because the reap loop prints between mutating them and a count
        # derived from a list mid-loop is one refactor away from being off by one.
        $gateDepth    = Get-GateNestingDepth
        $startedCount = 0
        $doneCount    = 0
        # SET FOR THE CHILDREN, RESTORED IN THE 'finally' BELOW. Start-Process children inherit this
        # process's environment, so one assignment reaches every suite and every gate a suite runs in
        # turn. SetEnvironmentVariable rather than $env:NAME = ... for the reason Push-NativeNonInteractiveEnv
        # states at length: only this form can write $null, and $null is how a variable is REMOVED --
        # $env:NAME = $null leaves an empty string behind, and empty is not absent.
        # BOUNDED TO THE POOL, deliberately: Get-TestCommands runs after the 'finally' has put the
        # variable back, so a consumer's own 'npm test' sees the environment it would have seen before
        # this change. What that costs is one honest edge -- a gate nested inside such a command reports
        # depth 1 -- and what it buys is that this lib does not leave a variable behind in a child it
        # does not print progress for.
        $gateDepthOuter = [Environment]::GetEnvironmentVariable($script:GateDepthEnvName, 'Process')
        [Environment]::SetEnvironmentVariable($script:GateDepthEnvName, "$gateDepth", 'Process')

        $captureDir = New-ScratchPath -Label 'test-suite-gate' -Directory

        # THE STDIN EVERY LANE CHILD IS GIVEN -- an empty file, and never this process's own handle
        # (issue #2233, September 21, 2026). The spawn below redirects stdout and stderr and said nothing
        # about stdin, so a lane INHERITED the gate's own, and every grandchild a suite started inherited
        # it in turn. Where the gate itself runs under a pipe nobody closes -- a harness, a shell that
        # redirects, a capture one layer up -- a child that reads stdin to end-of-stream blocks forever:
        # zero CPU, no output, no error, and #1941's deadline then converting it into a 30-minute red that
        # names a timeout rather than the defect.
        # MEASURED ON DAVE-KOK-BWJ: three suites wedged on four separate gate runs at four lane counts,
        # each holding exactly one child, and all three children hook-shaped -- a statusline renderer and
        # two session checks, every one of which reads a payload from stdin by design. The same three
        # passed standalone in 4s, 13s and 48s. Reproduced in isolation against this exact spawn: the child
        # wedges at zero CPU without this line and exits in 10 ms with it, reading an empty payload.
        # AN EMPTY FILE RATHER THAN A CLOSED HANDLE, because Start-Process has no way to say "closed" --
        # and it is the honest thing to hand over anyway. A hook asks [Console]::IsInputRedirected, which
        # is $true under this pool either way, so what it needs is a redirected handle already at
        # end-of-stream rather than one that will never reach it.
        # IT REPAIRS THE GATE AND NOT THE CHILDREN, deliberately. A hook whose own stdin bound does not
        # bind is that hook's defect and is filed as #2249; this is the pool declining to hand anybody a
        # handle it never closes, which is the half that belongs here and fixes every suite at once.
        $laneStdin = Join-Path $captureDir 'lane-stdin.empty'
        Set-Content -LiteralPath $laneStdin -Value '' -NoNewline -Encoding Ascii
        # THE FAILING SUITES' CAPTURE FILES, so the 'finally' below can keep exactly those and delete the
        # rest -- issue #1636. Collected in the reap loop because that is the only place a suite's exit code
        # and its two file paths are held at once; after $running.Remove the paths are gone, the same reason
        # $suiteTimings is filled there.
        $failedCaptureFiles = New-Object System.Collections.ArrayList
        # THE SUITES WHOSE PROCESS DIED, re-run one at a time once the pool is empty -- issue #1723.
        # Collected rather than judged on the spot, because a crash is not a verdict about the tree and
        # the standing response to one was already 'run that suite alone' -- see this function's own
        # notes on #1033. Doing it here makes that response the gate's, instead of the next reader's.
        $crashedSuites = New-Object System.Collections.ArrayList

        try {
            $queue = New-Object System.Collections.Queue
            foreach ($it in $runItems) { $queue.Enqueue($it) | Out-Null }
            $running = New-Object System.Collections.ArrayList
            # WHEN THE LAST PASS OF THE POLL LOOP READ THE CLOCK -- issue #2095. Seeded before the first
            # pass rather than at 0, so the pool's own bring-up is never read as a discontinuity.
            $lastPollAt = $sw.Elapsed.TotalSeconds

            while ($queue.Count -gt 0 -or $running.Count -gt 0) {
                # THE CLOCK IS CHECKED FOR A DISCONTINUITY BEFORE ANYTHING IS JUDGED AGAINST IT --
                # issue #2095, and it runs ahead of the launch block so the pass that OBSERVES a
                # suspend also acts on it. $sw is wall clock and a suspended machine keeps accruing it
                # while nothing runs, so without this the first poll after a wake reads every open lane
                # as hours past its bound and kills whichever suites happened to be in flight.
                #
                # REBASING THE OPEN LANES RATHER THAN SUBTRACTING FROM THE CLOCK. Both would fix the
                # bound; only this one is right about a lane the suspend did not touch. A lane opened
                # after the wake has a StartOffset on the far side of the jump and must be judged from
                # there -- a global correction would hand it a credit for a sleep it was not alive for.
                # It also leaves every reading of $sw honest: the progress line, the per-suite table and
                # the verdict go on reporting the wall clock this run really occupied, and the verdict
                # says separately how much of it nothing was running for.
                $pollAt = $sw.Elapsed.TotalSeconds
                $suspendCredit = Get-GateSuspendCredit -GapSeconds ($pollAt - $lastPollAt)
                $lastPollAt = $pollAt
                if ($suspendCredit -gt 0) {
                    $suspendedSeconds += $suspendCredit
                    foreach ($r in @($running)) {
                        $r.StartOffset += $suspendCredit
                        # THE GRACE WINDOW IS REBASED TOO, and leaving it out would be the same defect
                        # one layer down: a lane killed just before the suspend would come back with
                        # $sw.Elapsed - KilledAt in the hours, be abandoned on the first pass after the
                        # wake, and be reported as a tree that refused to die when nothing had yet had
                        # the chance to. 0 means it was never killed and is left alone.
                        if ($r.KilledAt -gt 0) { $r.KilledAt += $suspendCredit }
                    }
                    # WHAT WAS MEASURED, THEN THE KNOWN CAUSE -- in that order, because this line has to
                    # survive a reader who met it for some other reason. The gap is a fact; machine
                    # suspend is what produces one, and #2095 is where the measurement is written down.
                    Write-Host ("test gate: the clock jumped $(Format-GateSeconds $suspendCredit -Decimals 1)s between two polls and " +
                                "nothing ran across it -- the machine was suspended. Not counted against any suite's bound (issue #2095).") -ForegroundColor Yellow
                }

                while ($queue.Count -gt 0 -and $running.Count -lt $MaxParallel) {
                    $item    = $queue.Dequeue()
                    $suite   = $item.File
                    # THE STEM, NOT THE BASE NAME -- issue #1944. They are the same thing on every
                    # ordinary run, and they diverge the moment a focus run puts five copies of one file
                    # in the queue: five lanes writing one pair of capture files would leave the
                    # retention block below holding whichever copy finished last.
                    $outFile = Join-Path $captureDir ($item.Stem + '.out.txt')
                    $errFile = Join-Path $captureDir ($item.Stem + '.err.txt')
                    # The suite path is quoted: Start-Process joins ArgumentList on spaces, so an unquoted
                    # path under a folder with a space in it would arrive as two arguments.
                    $proc = Start-Process -FilePath 'powershell' `
                        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $suite.FullName + '"')) `
                        -WorkingDirectory $launchDir -NoNewWindow -PassThru `
                        -RedirectStandardOutput $outFile -RedirectStandardError $errFile `
                        -RedirectStandardInput $laneStdin
                    # READING .Handle IS NOT A NO-OP -- it is what makes .ExitCode readable later, and leaving
                    # it out is how this rewrite first shipped. Start-Process -PassThru hands back a Process
                    # object without retaining the OS handle, so once the child has exited .NET has nothing
                    # left to ask and .ExitCode comes back EMPTY. Empty is not 0: every suite was then judged
                    # 'FAILED (exit )', and the gate reported all of them failing while printing each one's
                    # green, passing output directly underneath. Same family as the rest of this file -- the
                    # wrong answer arrives as a plausible value instead of as an error.
                    $null = $proc.Handle
                    $running.Add([pscustomobject]@{
                        # Path, so a suite whose process died can be launched again without going back
                        # to the pool for it -- issue #1723.
                        # NAME IS THE ITEM'S LABEL, not the file's -- issue #1944. On every ordinary run
                        # they are the same string; in a focus run the label is what tells five headers
                        # for one file apart, and it is what the per-suite table and the verdict print.
                        Name = $item.Label; Path = $suite.FullName
                        # WHOSE VERDICT COUNTS. $true for every suite on an ordinary run, and in a focus
                        # run only for the copies of the suite under test -- the load is there to contend,
                        # not to be judged (issue #1944).
                        Decides = $item.IsTarget
                        Process = $proc; OutFile = $outFile; ErrFile = $errFile
                        # WHEN THIS LANE OPENED, off the gate's own stopwatch -- see $suiteTimings for why
                        # the offset is recorded and not just the duration (issue #1358).
                        StartOffset = $sw.Elapsed.TotalSeconds
                        # THE DEADLINE BOOKKEEPING (issue #1941). TimedOut is set by the sweep below the
                        # moment this lane passes $suiteDeadline, KilledAt records when its tree was told
                        # to die, and the pair is what lets the pool abandon a lane whose kill did not
                        # take instead of waiting on HasExited forever.
                        TimedOut = $false
                        KilledAt = 0.0
                        # WHAT THE TREE WAS DOING WHEN IT WAS KILLED (issue #2279). Filled by the
                        # deadline sweep only, and empty on every lane that never timed out -- so a
                        # suite that simply passed carries nothing and prints nothing.
                        CpuNote  = @()
                    }) | Out-Null
                    # ONE LINE PER LANE OPENING -- issue #1717, and this is the half a done-count alone
                    # cannot report: the queue dequeues longest-first (#1358), so on a truthful hints
                    # file nothing COMPLETES for the first ~15 minutes of an 84-suite run while the
                    # opening lanes chew through the heaviest suites. Printed after Start-Process rather
                    # than before it, so it reports a lane that actually opened.
                    #
                    # RUNNING IS DERIVED, NOT COUNTED. started - done is exactly what is in flight,
                    # because every dequeued suite is one or the other -- whereas $running.Count means
                    # two different things here and in the reap loop below, where a suite already judged
                    # is still in the list until $running.Remove. One identity, both call sites.
                    $startedCount++
                    Write-Host (Format-GateProgressLine -Action 'started' -Suite $item.Label `
                        -Started $startedCount -Done $doneCount -Running ($startedCount - $doneCount) `
                        -Total $runItems.Count -Elapsed $sw.Elapsed.TotalSeconds -Depth $gateDepth) -ForegroundColor DarkGray
                    # AND THE SAME EVENT TO THE STATUSLINE -- issue #2101. Beside the Write-Host rather
                    # than instead of it: the console line is what a foreground reader and a CI log get,
                    # the record is what a backgrounded run has instead of a reader. One event, two
                    # surfaces, and neither derived from the other's text.
                    Publish-GateProgress -Started $startedCount -Done $doneCount -Total $runItems.Count `
                        -StartedUtc $gateStartedUtc -Depth $gateDepth
                }

                # THE DEADLINE SWEEP -- issue #1941, and it runs BEFORE the reap so a lane that has just
                # passed its bound is killed in the same pass that would otherwise have slept on it.
                # Two stages, because Stop-NativeProcessTree is best-effort by nature (its own docstring
                # says so): first tell the tree to die, then, if the lane is STILL not exited a grace
                # window later, stop waiting on it at all. Without the second stage a kill that taskkill
                # refused would put the pool straight back into the unbounded wait this exists to end --
                # which is the 141-minute measurement in #1941, one layer down.
                if ($suiteDeadline -gt 0) {
                    # WHICH LANES PASSED THEIR BOUND IN THIS PASS, COLLECTED BEFORE ANYTHING IS KILLED --
                    # issue #2279. The kill used to happen inside this loop; the CPU reading has to be
                    # taken while the tree is still alive, and taking it per lane would pay the sample
                    # window once per lane. So the pass is now three steps over one list: mark, measure,
                    # kill. Nothing about WHEN a lane is reaped changed -- the kill still happens in the
                    # same pass that observed the bound, a few seconds later in it.
                    $overBound = New-Object System.Collections.ArrayList
                    foreach ($r in @($running)) {
                        if ($r.TimedOut -or $r.Process.HasExited) { continue }
                        if (($sw.Elapsed.TotalSeconds - $r.StartOffset) -le $suiteDeadline) { continue }
                        $r.TimedOut = $true
                        $r.KilledAt = $sw.Elapsed.TotalSeconds
                        Write-Host ("test gate: $($r.Name) passed its $(Format-GateSeconds $suiteDeadline)s bound -- killing its process tree (issue #1941).") -ForegroundColor Red
                        $overBound.Add($r) | Out-Null
                    }

                    if ($overBound.Count -gt 0) {
                        # TWO SNAPSHOTS OF THE WHOLE MACHINE, SHARED BY EVERY LANE IN THIS PASS -- issue
                        # #2279. One CIM read each, and the sleep between them is the sample window, so
                        # the pass costs $script:GateCpuSampleSeconds however many lanes timed out. The
                        # whole block is guarded: on a machine where CIM does not answer, both readings
                        # come back unmeasured and the note says so rather than reporting a zero.
                        $cpuBefore = Get-GateProcessSnapshot
                        Start-Sleep -Seconds $script:GateCpuSampleSeconds
                        $cpuAfter  = Get-GateProcessSnapshot
                        foreach ($r in $overBound) {
                            $before = Get-GateTreeCpuSeconds -Snapshot $cpuBefore -ProcessId $r.Process.Id
                            $after  = Get-GateTreeCpuSeconds -Snapshot $cpuAfter  -ProcessId $r.Process.Id
                            # THE LIFETIME TOTAL IS TAKEN FROM THE LATER SNAPSHOT, and the window is the
                            # difference. A process that exited during the window is missing from the
                            # second one, which is why the fallback is the first rather than a zero --
                            # a tree that finished dying mid-sample still consumed what it consumed.
                            $cumulative = if ($after.Measured) { $after } else { $before }
                            $window = if ($before.Measured -and $after.Measured) {
                                # NEVER NEGATIVE. A child that exited between the two reads takes its
                                # CPU out of the second sum, so the difference can go below zero while
                                # nothing whatsoever was running -- and a negative printed here would
                                # read as a measurement error rather than as the idle tree it is.
                                $delta = [Math]::Max([double]0, ([double]$after.CpuSeconds - [double]$before.CpuSeconds))
                                [pscustomobject]@{ CpuSeconds = $delta; ProcessCount = $after.ProcessCount; Measured = $true }
                            } else { $null }
                            # HELD ON THE LANE RATHER THAN PRINTED HERE, so the note sits under the
                            # suite's own '== <name> == TIMED OUT' header where a reader meets it, and
                            # not thirty lines above it among the other lanes' kill lines.
                            $r.CpuNote = Get-GateTimeoutCpuNote -Cumulative $cumulative -Window $window `
                                -WindowSeconds ([double]$script:GateCpuSampleSeconds)
                        }
                    }

                    foreach ($r in $overBound) { Stop-NativeProcessTree -ProcessId $r.Process.Id }
                }

                # A LANE IS REAPABLE WHEN ITS PROCESS EXITED, OR WHEN THE POOL HAS GIVEN UP ON IT. The
                # second arm is the one that makes this loop terminate under every condition: it does not
                # ask the process anything, so a child that ignored its own kill cannot hold it open.
                $done = @($running | Where-Object {
                    $_.Process.HasExited -or
                    ($_.TimedOut -and (($sw.Elapsed.TotalSeconds - $_.KilledAt) -gt $script:GateSuiteKillGraceSeconds))
                })
                if ($done.Count -eq 0) {
                    Start-Sleep -Milliseconds 100
                    continue
                }

                foreach ($d in $done) {
                    # WaitForExit() IS NOT CALLED ON AN ABANDONED LANE -- issue #1941. It blocks with no
                    # deadline, so calling it on the one lane the pool has just decided it cannot kill
                    # would re-open the unbounded wait at the exact point that wait was closed. A lane
                    # whose process HAS exited is settled the way it always was.
                    $exited = $d.Process.HasExited
                    if ($exited) { $d.Process.WaitForExit() }   # settles ExitCode before it is read
                    $code = if ($exited) { $d.Process.ExitCode } else { $null }
                    # $code CAN COME BACK AS POWERSHELL'S OWN $null HERE, EVEN THOUGH .Handle WAS READ AND
                    # WaitForExit() RETURNED -- issue #1931, and this is the one site in this file where
                    # that race can turn a PASSING suite into a gate-failing one. Reproduced independently
                    # while auditing #1931: 1 in 300 fresh `powershell.exe` children racing exactly this
                    # Start-Process -> .Handle -> WaitForExit -> .ExitCode sequence against a trivial
                    # command, which is precisely what this loop does once per suite, per lane, all run.
                    # #1931 itself measured 27 in 960 (2.8%) under this repo's own 16-lane gate. A $null
                    # here is NOT a crash in Test-GateSuiteCrashed's sense (that function reads $null as
                    # "not a crash", correctly, since a genuine NTSTATUS is a real negative int) -- it is
                    # the SAME "the pool has measured nothing about this suite yet" state #1723 built the
                    # crash-and-retry path for, so it is routed there instead of a fourth, new branch.
                    # A TIMED-OUT LANE IS NOT AN UNMEASURABLE ONE, even though both arrive with $code
                    # $null -- issue #1941. #1931's state is "the process ran and the OS did not hand
                    # back a verdict this run could read", which is a transient worth a lone re-run;
                    # this one is "the process was still running when the pool stopped waiting", which
                    # is a fact about the suite. Checking TimedOut first is what keeps them apart.
                    $codeUnknown = (-not $d.TimedOut) -and ($null -eq $code)
                    # RECORDED HERE, WHERE BOTH ENDS ARE KNOWN. Reaping is the only moment this loop holds
                    # a suite's start and its finish at once; after $running.Remove the start offset is gone.
                    $suiteTimings.Add([pscustomobject]@{
                        Name        = $d.Name
                        StartOffset = $d.StartOffset
                        Duration    = ($sw.Elapsed.TotalSeconds - $d.StartOffset)
                        # THE ROW SAYS SO, for the same reason the CRASHED flag below exists: the number
                        # on a timed-out row is the bound plus the grace window, which is a fact about
                        # this RUN and says nothing about what the file costs (issue #1941).
                        TimedOut    = $d.TimedOut
                        # (-not $codeUnknown), FIRST: `$null -ne 0` is $true in PowerShell, so without this
                        # guard an unmeasured code recorded a PASSING suite as Failed in this table before
                        # the crash branch below ever got a chance to correct it on a successful re-run.
                        Failed      = (-not $codeUnknown) -and ($code -ne 0)
                        # CRASHED IS TRACKED SEPARATELY FROM FAILED, so the table below cannot report a
                        # crashed suite as a cheap one -- issue #1723. A process that died 2s into what
                        # is a 60s suite records 2s here, which is TRUE of this lane and a lie about the
                        # file: the whole purpose of this table (#714, #1358) is finding the file that
                        # sets the makespan, so an unmarked 2s row is the one wrong answer it must not
                        # give. The row keeps the honest 2s and says CRASHED beside it; the lone re-run
                        # prints its own seconds, which is where that file's real cost is legible.
                        Crashed     = $false
                    }) | Out-Null
                    # ONE LINE PER SUITE LEAVING A LANE, printed immediately ABOVE the block header it
                    # announces -- issue #1717. That placement is what makes it read as the index #1717
                    # asked for ('== [37/84] roster-sync.tests.ps1 ==') while '== <suite> ==' stays byte
                    # for byte what it was: the suite's own output is still the very next line after the
                    # header (asserted in this function's suite), and no existing matcher has to change.
                    #
                    # THE WORD IS 'done' FOR ALL THREE VERDICTS. The header on the next line already says
                    # whether the suite passed, FAILED or CRASHED, and a progress counter that also
                    # classified would be a second place for that judgement to drift from the first.
                    $doneCount++
                    Write-Host (Format-GateProgressLine -Action 'done' -Suite $d.Name `
                        -Started $startedCount -Done $doneCount -Running ($startedCount - $doneCount) `
                        -Total $runItems.Count -Elapsed $sw.Elapsed.TotalSeconds -Depth $gateDepth) -ForegroundColor DarkGray
                    # The other half of the same event -- issue #2101; see the lane-opening call above.
                    Publish-GateProgress -Started $startedCount -Done $doneCount -Total $runItems.Count `
                        -StartedUtc $gateStartedUtc -Depth $gateDepth
                    # WHAT THIS ITEM IS FOR, said on its own header rather than inferred from the queue
                    # -- issue #1944. On an ordinary run every item decides and this is empty; in a focus
                    # run it is the difference between a red header that fails the run and one that is
                    # simply what the load did while the suite under test was being measured.
                    $loadNote = if ($d.Decides) { '' } else { '  (load -- does not decide this focus run)' }
                    # THE VERDICT THIS ITEM CONTRIBUTES, recorded for the focus table below. Set by each
                    # branch rather than derived afterwards, because 'crashed' and 'timed out' are not
                    # readable off an exit code once the branch that knew has closed.
                    $itemVerdict = 'passed'
                    if ($d.TimedOut) {
                        # THE FOURTH VERDICT -- issue #1941. Deliberately NOT routed into $crashedSuites
                        # and its lone re-run, and that is the whole judgement in this branch. A crash is
                        # a process that died having measured nothing, so re-running it is the only way
                        # to get a verdict at all. A TIMEOUT has measured something: this suite did not
                        # finish in a window sized at ~6x the slowest run this repo has ever recorded.
                        # Re-running it alone would remove the contention that is the likeliest cause,
                        # pass, and leave the gate GREEN over a run that cost the machine 90 processes --
                        # which is exactly the silence #1941 was filed about.
                        $itemVerdict = 'timed out'
                        $killNote = if ($exited) { 'its process tree was killed' }
                                    else { "its process tree did NOT die within $(Format-GateSeconds $script:GateSuiteKillGraceSeconds)s of the kill and was ABANDONED -- it may still be running" }
                        Write-Host "== $($d.Name) == TIMED OUT after $(Format-GateSeconds ($sw.Elapsed.TotalSeconds - $d.StartOffset) -Decimals 1)s (bound $(Format-GateSeconds $suiteDeadline)s) -- $killNote; no verdict (issue #1941)$loadNote" -ForegroundColor Red
                        # WHAT THE TREE WAS DOING WHEN IT WAS KILLED, directly under this suite's own
                        # header -- issue #2279. This is the line a session copies into an issue, so the
                        # measurement has to travel attached to the suite it is about rather than being
                        # findable somewhere further up the run.
                        foreach ($cpuLine in @($d.CpuNote)) { Write-Host $cpuLine -ForegroundColor Red }
                        $timedOutNames.Add($d.Name) | Out-Null
                        if ($d.Decides) { $failedNames.Add($d.Name) | Out-Null }
                        $failedCaptureFiles.Add($d.OutFile) | Out-Null
                        $failedCaptureFiles.Add($d.ErrFile) | Out-Null
                    } elseif ($codeUnknown) {
                        # CHECKED BEFORE '$code -eq 0' AND BEFORE Test-GateSuiteCrashed, DELIBERATELY:
                        # Format-GateExitCode takes a non-nullable [int], so calling it with $code here
                        # would itself throw inside the gate rather than report anything (issue #1931).
                        $itemVerdict = 'crashed'
                        Write-Host "== $($d.Name) == CRASHED (exit code unmeasurable -- issue #1931) -- the process ran, but .NET/the OS did not hand back a verdict this run could read; no verdict$loadNote" -ForegroundColor Magenta
                        $crashedTiming = ($suiteTimings | Where-Object { $_.Name -eq $d.Name } | Select-Object -Last 1)
                        if ($null -ne $crashedTiming) { $crashedTiming.Crashed = $true }
                        # GATED ON Decides, AND OFF IN A FOCUS RUN -- issue #1944, two separate reasons.
                        # A LOAD suite that crashed is noise from a process that was only there to
                        # contend, and re-running it would spend a whole suite's runtime deciding
                        # something no verdict rests on. And the TARGET is not re-run alone either,
                        # because running it alone is precisely what this mode exists to replace: a
                        # focus run asks what happens under load, so a crash under load is the answer
                        # it was looking for and is red.
                        if ($d.Decides -and -not $focusMode) {
                            $crashedNames.Add($d.Name) | Out-Null
                            $crashedSuites.Add([pscustomobject]@{
                                Name = $d.Name; Path = $d.Path; ExitCode = $code; Timing = $crashedTiming
                            }) | Out-Null
                        } elseif ($d.Decides) {
                            $failedNames.Add($d.Name) | Out-Null
                        }
                        $failedCaptureFiles.Add($d.OutFile) | Out-Null
                        $failedCaptureFiles.Add($d.ErrFile) | Out-Null
                    } elseif ($code -eq 0) {
                        Write-Host "== $($d.Name) ==$loadNote" -ForegroundColor Cyan
                    } elseif (Test-GateSuiteCrashed -ExitCode $code) {
                        # NOT ADDED TO $failedNames HERE -- issue #1723. A killed process returned no
                        # verdict, so the pool has measured nothing about this suite yet; the lone
                        # re-run below is what decides it. The word CRASHED is the point of the branch:
                        # 'FAILED (exit -1073741819)' sent a reader hunting for an assert that never ran.
                        $itemVerdict = 'crashed'
                        Write-Host "== $($d.Name) == CRASHED (exit $(Format-GateExitCode -ExitCode $code)) -- the process died; no verdict$loadNote" -ForegroundColor Magenta
                        $crashedTiming = ($suiteTimings | Where-Object { $_.Name -eq $d.Name } | Select-Object -Last 1)
                        if ($null -ne $crashedTiming) { $crashedTiming.Crashed = $true }
                        # Same two reasons as the unmeasurable-code branch above.
                        if ($d.Decides -and -not $focusMode) {
                            $crashedNames.Add($d.Name) | Out-Null
                            $crashedSuites.Add([pscustomobject]@{
                                Name = $d.Name; Path = $d.Path; ExitCode = $code; Timing = $crashedTiming
                            }) | Out-Null
                        } elseif ($d.Decides) {
                            $failedNames.Add($d.Name) | Out-Null
                        }
                        $failedCaptureFiles.Add($d.OutFile) | Out-Null
                        $failedCaptureFiles.Add($d.ErrFile) | Out-Null
                    } else {
                        $itemVerdict = "failed (exit $code)"
                        Write-Host "== $($d.Name) == FAILED (exit $code)$loadNote" -ForegroundColor Red
                        if ($d.Decides) { $failedNames.Add($d.Name) | Out-Null }
                        $failedCaptureFiles.Add($d.OutFile) | Out-Null
                        $failedCaptureFiles.Add($d.ErrFile) | Out-Null
                    }
                    # ONE ROW PER REPEAT OF THE SUITE UNDER TEST -- issue #1944. Only the deciding items,
                    # because the load's verdicts are not what the run is asking about.
                    if ($focusMode -and $d.Decides) {
                        $focusResults.Add([pscustomobject]@{
                            Name        = $d.Name
                            Verdict     = $itemVerdict
                            StartOffset = $d.StartOffset
                            Duration    = ($sw.Elapsed.TotalSeconds - $d.StartOffset)
                            # HOW MANY LANES WERE BUSY BESIDE IT when it finished. The whole question a
                            # focus run asks is whether contention changes the answer, so a row without
                            # it cannot be read against the one above it.
                            Siblings    = ($startedCount - $doneCount)
                        }) | Out-Null
                    }
                    # THROUGH THE TOLERANT READER, and it says so when a block may be short -- issue
                    # #1731. This is the site most exposed to a grandchild still holding the suite's
                    # capture file: it reads the moment WaitForExit returns. See Write-GateCaptureBlock
                    # for the encoding, the settle budget and what the swap cost.
                    Write-GateCaptureBlock -Path @($d.OutFile, $d.ErrFile)
                    $running.Remove($d)
                }
            }

            # A CRASHED SUITE IS RE-RUN ALONE, ONCE -- issue #1723.
            #
            # THIS IS NOT A RETRY ON FAILURE, and the distinction is the whole licence for it. A suite
            # that exits 1 has measured the tree and said no; re-running that would be masking a
            # verdict, and nothing here does it. A suite whose process was killed measured nothing --
            # it has no [FAIL] line, no summary and no exit code of its own -- so there is no verdict
            # to mask and re-running is the only way to get one. #1622 and #1723 both ended with a
            # human doing exactly this by hand, on the advice this function's own docstring gives.
            #
            # ALONE AND AFTER THE POOL, not back into a lane: the fault measured in #1723 is a
            # PowerShell 5.1 engine fault under 30-way contention, so a re-run beside 29 siblings is
            # the same draw again. Sequential also bounds the cost -- one suite, once, and only when
            # a crash actually happened, which is why an ordinary run never reaches this block.
            #
            # AND THAT IS ALSO THIS BLOCK'S OWN WEAKNESS, WHICH IS WORTH STATING WHERE IT LIVES
            # (Marlowe's red-team of #1723). Removing the contention is what makes the re-run useful
            # AND what makes it near-certain to pass, for exactly the load-triggered class of crash
            # this was built for -- so a crash that recurs every run still leaves a green gate, and
            # the only trace is a magenta line nobody tallies across runs. Two things are done about
            # that rather than nothing: the crash is named on the GREEN verdict, which is the line a
            # session copies, and the pool run's capture files are KEPT even on that green run, so
            # the evidence #1622 lost is on disk at a path the verdict prints. What is deliberately
            # not built is a tally: a counter across runs needs somewhere to persist, and this
            # function has no state between invocations.
            #
            # A SECOND CRASH IS A FAILURE, and it is reported as a crash rather than dressed up as
            # one: the suite goes into $failedNames so the gate is red and nothing merges, and the
            # word CRASHED stays on the line so the reader is not sent looking for an assert.
            if ($crashedSuites.Count -gt 0) {
                $word = if ($crashedSuites.Count -eq 1) { 'suite' } else { 'suites' }
                Write-Host ''
                Write-Host "test gate: $($crashedSuites.Count) $word CRASHED in the pool -- the process died without a verdict, so each is re-run ALONE (issue #1723)." -ForegroundColor Magenta
                foreach ($c in $crashedSuites) {
                    $retryOut = Join-Path $captureDir ($c.Name + '.retry.out.txt')
                    $retryErr = Join-Path $captureDir ($c.Name + '.retry.err.txt')
                    $rp = Start-Process -FilePath 'powershell' `
                        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $c.Path + '"')) `
                        -WorkingDirectory $launchDir -NoNewWindow -PassThru `
                        -RedirectStandardOutput $retryOut -RedirectStandardError $retryErr `
                        -RedirectStandardInput $laneStdin
                    $null = $rp.Handle      # same reason as the pool's launch: without it .ExitCode is empty
                    $retrySw = [System.Diagnostics.Stopwatch]::StartNew()
                    $rp.WaitForExit()
                    $retrySw.Stop()
                    $rc = $rp.ExitCode
                    # THE RETRY'S OWN CODE CAN ALSO COME BACK $null (issue #1931) -- the same race the
                    # pool run itself just measured, on the same Start-Process pattern, one process later.
                    $rcUnknown = ($null -eq $rc)
                    $retrySecs = Format-GateSeconds $retrySw.Elapsed.TotalSeconds -Decimals 1
                    $crashedAgain = (-not $rcUnknown) -and (Test-GateSuiteCrashed -ExitCode $rc)
                    # THE POOL'S OWN CODE ($c.ExitCode) CAN NOW BE $null TOO (issue #1931, the branch above
                    # this one): Format-GateExitCode takes a non-nullable [int] and would throw on it, so
                    # the label is built without calling it when there is nothing to format.
                    $poolExitLabel = if ($null -eq $c.ExitCode) { 'unmeasurable exit code' } else { "exit $(Format-GateExitCode -ExitCode $c.ExitCode)" }
                    if ($rcUnknown) {
                        # A SECOND UNMEASURABLE READ IS TREATED AS A SECOND CRASH, on the same "ONCE"
                        # doctrine the comment above this block already states for a genuine crash: the
                        # re-run exists to settle the ONE verdict the pool could not, and a re-run that
                        # also cannot measure one leaves nothing left to retry against. Failing closed
                        # here is the same direction Get-GitFileTextAtRef's docstring argues for a merge
                        # gate elsewhere in this file -- an unmeasured verdict must not read as a pass.
                        Write-Host "== $($c.Name) == re-ran ALONE after ${retrySecs}s and its exit code could ALSO not be read (issue #1931) -- treated as a second crash, so the gate does not merge on an unmeasured verdict" -ForegroundColor Red
                        $failedNames.Add($c.Name) | Out-Null
                    } elseif ($rc -eq 0) {
                        # GREEN, AND THE CRASH STILL GETS SAID. The pool's own timing row is corrected
                        # so the per-suite table does not carry a FAILED flag for a suite that passed.
                        Write-Host "== $($c.Name) == re-ran ALONE and PASSED in ${retrySecs}s -- the pool's $poolExitLabel was a crash, not a verdict" -ForegroundColor Yellow
                        if ($null -ne $c.Timing) { $c.Timing.Failed = $false }
                    } elseif ($crashedAgain) {
                        Write-Host "== $($c.Name) == CRASHED AGAIN alone after ${retrySecs}s (exit $(Format-GateExitCode -ExitCode $rc)) -- this is the suite or the engine, not the pool" -ForegroundColor Red
                        $failedNames.Add($c.Name) | Out-Null
                    } else {
                        Write-Host "== $($c.Name) == re-ran alone and FAILED in ${retrySecs}s (exit $rc) -- the crash hid a real verdict" -ForegroundColor Red
                        $failedNames.Add($c.Name) | Out-Null
                    }
                    # The re-run's own output, whichever way it went: on a pass it is the evidence that
                    # the tree is fine, and on a failure it is the only block carrying a verdict at all.
                    Write-GateCaptureBlock -Path @($retryOut, $retryErr)
                    if ($rc -ne 0) {
                        $failedCaptureFiles.Add($retryOut) | Out-Null
                        $failedCaptureFiles.Add($retryErr) | Out-Null
                    }
                }
                Write-Host ''
            }
        } finally {
            # THE NESTING DEPTH GOES BACK FIRST -- issue #1717. Before the retention block below, because
            # this restores process state the caller owns while that one only tidies a temp directory: a
            # throw in there must not leave the variable set for whatever the caller runs next. Restored
            # from the value read before the set, so a caller that deliberately set its own (a fixture
            # driving this gate at a chosen depth) gets its own back -- Push-NativeNonInteractiveEnv's
            # rule, for the same reason, and the same $null-removes-it form.
            [Environment]::SetEnvironmentVariable($script:GateDepthEnvName, $gateDepthOuter, 'Process')
            # AND THE PUBLISHED RECORD GOES WITH IT -- issue #2101. In the 'finally' so a gate that
            # throws does not leave a bar standing at 61/84 for the rest of the session. It is a tidy-up
            # and not a contract: a run KILLED outright never reaches this line, and the reader drops
            # that record on its next pass because the writer is gone. Two seconds late, not forever.
            Clear-GateProgress -Depth $gateDepth
            # A RED RUN KEEPS THE FAILING SUITES' OUTPUT; A GREEN ONE KEEPS NOTHING -- issue #1636 --
            # WITH ONE EXCEPTION SINCE #1723: a suite that CRASHED in the pool and then passed on its
            # lone re-run leaves the pool run's two capture files behind on an otherwise green run. That
            # is the point rather than a leak. #1622's entire cost was a sighting whose evidence had been
            # thrown away, and a crash cleared by a re-run is exactly that sighting -- the verdict says
            # green, so nothing else would ever keep it. The green verdict names the directory for the
            # same reason the red one does. This
            # block used to delete the directory either way, which made the console the ONLY copy of a
            # failing suite's output and gave no flag to keep it. The gate does print each block, and that
            # is what #1622 correctly observed -- but a pipe through 'tail', a scrollback limit, a truncated
            # CI log or a closed terminal each throw it away, and none of those is the reader's error. A run
            # here costs ~140s and the failure it carries is, by construction, one that may not reproduce.
            #
            # ONLY THE FAILING SUITES' FILES SURVIVE, so a red run does not leave 79 suites of green noise
            # behind, and an EMPTY file is dropped too: keeping a 0-byte .err.txt would name a directory on
            # the verdict line that holds nothing to read. If nothing survives, the directory goes and
            # $retainedCaptureDir stays empty -- so the note below is printed only when there is something
            # at the other end of it.
            #
            # $captureDir IS UNPREDICTABLE AND PER-RUN (New-ScratchPath, issue #1659), so a retained directory
            # cannot collide with a later run's -- not even one that reuses this PID. It used to be
            # "test-suite-gate-$PID" and the try opened by deleting whatever stood there, a recursive delete
            # at a name anyone could have planted a junction at; there is no stale one to clear now.
            #
            # THE LENGTH IS READ THE SAME SETTLE-AWARE WAY Write-GateCaptureBlock JUST READ THESE SAME
            # FILES TO PRINT THEM -- issue #2295. A plain Get-Item races the exact ambiguity #1679/#1731
            # already named for this lib: $proc.WaitForExit() returning true says the CHILD has exited, not
            # that Start-Process's own pipe-to-file copy (running in THIS process, on its own thread) has
            # caught up, and a grandchild that inherited the handle (#1252) can hold it a moment longer
            # still. Under CI contention that gap widens rather than closes -- measured twice in one CI
            # hour, on a genuinely wedged suite and on an ordinary failing one, both cases where the console
            # had just printed the suite's own marker text a few lines above the now-empty verdict. Read-
            # NativeCaptureFile's probe waits (bounded, $script:NativeCaptureSettleMilliseconds) for a
            # lingering writer to release before it is read as empty, exactly as the print already does --
            # so the retention decision can no longer disagree with what the console just showed.
            $captureOem = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
            if (Test-Path -LiteralPath $captureDir) {
                $keep = @()
                foreach ($f in @($failedCaptureFiles)) {
                    if (-not (Test-Path -LiteralPath $f)) { continue }
                    $settled = Read-NativeCaptureFile -Path $f -Encoding $captureOem `
                                                       -SettleMilliseconds $script:NativeCaptureSettleMilliseconds
                    if ($settled.Text.Length -gt 0) { $keep += $f }
                }
                if ($keep.Count -eq 0) {
                    Remove-Item -Recurse -Force -LiteralPath $captureDir -ErrorAction SilentlyContinue
                } else {
                    foreach ($f in @(Get-ChildItem -LiteralPath $captureDir -File -ErrorAction SilentlyContinue)) {
                        if ($keep -notcontains $f.FullName) {
                            Remove-Item -Force -LiteralPath $f.FullName -ErrorAction SilentlyContinue
                        }
                    }
                    $retainedCaptureDir = $captureDir
                }
            }
        }
    }

    # The repo's own commands, sequentially and after the pool -- see the docstring for why they do not
    # join it. Same header-then-output shape as a suite, so a failure is attributable the same way.
    if ($extraCommands.Count -gt 0) {
        Write-Host "test gate: running $($extraCommands.Count) repo test command(s) from Get-TestCommands for $Context (one at a time)..." -ForegroundColor Cyan
        foreach ($cmd in $extraCommands) {
            # A command that does not PARSE is refused rather than run: an unterminated quote would
            # swallow the judging suffix below into its string literal, and the truncated statement's
            # own exit code (usually 0) would stand -- the wrong answer arriving as a plausible value,
            # this file's own failure family (see the .Handle comment above).
            $parseErrors = $null
            [void][System.Management.Automation.Language.Parser]::ParseInput($cmd, [ref]$null, [ref]$parseErrors)
            if ($parseErrors -and $parseErrors.Count -gt 0) {
                Write-Host "== $cmd == FAILED (does not parse: $($parseErrors[0].Message))" -ForegroundColor Red
                $failedNames.Add($cmd) | Out-Null
                continue
            }
            # A child powershell rather than in-process invocation: the command line stays an opaque
            # string ('npm test', a script call, anything) and its noise cannot trip this scope's EAP.
            # The judging suffix starts on its OWN LINE, so a trailing comment in the command cannot
            # absorb it, and it judges both halves a command can fail in: a native exit code where one
            # was set, and $? where none was -- a pure-PowerShell entry ending in a non-terminating
            # Write-Error sets no $LASTEXITCODE at all, and a bare 'exit $LASTEXITCODE' would have
            # coerced that to exit 0, a green gate over a red command.
            $judge = '$__gateOk = $?; if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; if (-not $__gateOk) { exit 1 }; exit 0'
            $r = Invoke-NativeCapture -FilePath 'powershell' -Arguments @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', ($cmd + "`n" + $judge))
            if ($r.ExitCode -eq 0) {
                Write-Host "== $cmd ==" -ForegroundColor Cyan
            } else {
                Write-Host "== $cmd == FAILED (exit $($r.ExitCode))" -ForegroundColor Red
                $failedNames.Add($cmd) | Out-Null
            }
            $cmdText = (@($r.Output | ForEach-Object { "$_" }) -join "`n")
            if (-not [string]::IsNullOrWhiteSpace($cmdText)) { Write-Host $cmdText.TrimEnd() }
        }
    }

    $sw.Stop()
    $total = $runItems.Count + $extraCommands.Count

    # THE PER-SUITE TABLE, slowest first -- issue #1358. Printed before the verdict so the verdict stays
    # the last line a session copies, and only when there is a pool to describe.
    #
    # WHY SLOWEST FIRST RATHER THAN COMPLETION ORDER: the whole reason to have this is to find the file
    # that sets the shard's wall clock, and #714's finding is that a shard costs its slowest FILE. The
    # blocks above are already in completion order, so ordering by cost adds the view the log did not have.
    #
    # THE MAKESPAN MARKER IS THE ACTIONABLE BIT. A suite is marked '<-- set the makespan' when it finished
    # last, because that is the only suite whose shortening moves this pool's total -- everything else has
    # slack behind it. That is the claim #714 proved and #1354 re-proved, and printing it stops the next
    # reader deriving it from timestamps.
    if ($suiteTimings.Count -gt 0) {
        $lastFinish = ($suiteTimings | ForEach-Object { $_.StartOffset + $_.Duration } | Measure-Object -Maximum).Maximum
        $nameWidth = ($suiteTimings | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
        Write-Host ''
        Write-Host "test gate: per-suite durations, slowest first (recorded, not reconstructed -- #1358)" -ForegroundColor Cyan
        Write-Host "  'started' is when a LANE OPENED, not when the suite was queued: a late start is lane wait, not runtime." -ForegroundColor DarkGray
        foreach ($t in ($suiteTimings | Sort-Object -Property Duration -Descending)) {
            $finish = $t.StartOffset + $t.Duration
            # Within a tick of the pool's end, so a rounding difference does not hide the marker.
            $marker = if ([Math]::Abs($finish - $lastFinish) -lt 0.05) { '  <-- set the makespan' } else { '' }
            # CRASHED WINS OVER FAILED in the flag, because the two say different things about the
            # number on the same row: FAILED means the suite ran that long and said no, CRASHED means
            # it died that far in and never answered -- so the duration is a fragment of the file's
            # real cost rather than a measurement of it (issue #1723).
            # TIMED OUT WINS OVER BOTH, for the reason CRASHED wins over FAILED: a timed-out row's
            # number is the bound plus the grace window, so it is not a reading of the file at all --
            # and unlike a crash there is no lone re-run below carrying the real cost (issue #1941).
            $flag   = if ($t.TimedOut) { " TIMED OUT -- this is the bound, not the file's cost; nothing re-ran it" }
                      elseif ($t.Crashed) { ' CRASHED -- died this far in; real cost is in the lone re-run above' }
                      elseif ($t.Failed) { ' FAILED' } else { '' }
            Write-Host ("  {0,8}s  {1,-$nameWidth}  started +{2}s{3}{4}" -f `
                (Format-GateSeconds $t.Duration -Decimals 1), $t.Name,
                (Format-GateSeconds $t.StartOffset -Decimals 1), $flag, $marker) `
                -ForegroundColor $(if ($t.Failed) { 'Red' } else { 'Gray' })
        }
        Write-Host ''
    }

    # THE FOCUS TABLE -- issue #1944, and it is a different question from the table above. That one sorts
    # slowest first to find the file that sets the makespan; this one keeps the repeats IN ORDER, because
    # what a reproduction run asks is whether the answer changed from draw to draw and how loaded the pool
    # was each time. Sorting them apart would destroy exactly that.
    if ($focusMode -and $focusResults.Count -gt 0) {
        $focusFailed = @($focusResults | Where-Object { $_.Verdict -ne 'passed' })
        Write-Host "test gate: focus run -- $FocusSuite, $($focusResults.Count) repeat(s) under $MaxParallel lanes of real sibling suites (issue #1944)" -ForegroundColor Cyan
        foreach ($f in ($focusResults | Sort-Object -Property StartOffset)) {
            $colour = if ($f.Verdict -eq 'passed') { 'Gray' } else { 'Red' }
            Write-Host ("  {0,8}s  started +{1}s  with {2} sibling lane(s) busy  --  {3}" -f `
                (Format-GateSeconds $f.Duration -Decimals 1),
                (Format-GateSeconds $f.StartOffset -Decimals 1), $f.Siblings, $f.Verdict) -ForegroundColor $colour
        }
        # THE READING OF THE TABLE, printed rather than left to the reader, because the whole reason this
        # mode exists is that a standalone green proves nothing -- and so does a focus run of one draw.
        if ($focusFailed.Count -eq 0) {
            Write-Host "  $($focusResults.Count)/$($focusResults.Count) passed under load. That is EVIDENCE OF ABSENCE ONLY AS FAR AS THE DRAW COUNT GOES: raise -FocusRepeat or -MaxParallel before concluding a load-triggered defect is gone." -ForegroundColor DarkGray
        } else {
            Write-Host "  $($focusFailed.Count)/$($focusResults.Count) did NOT pass under load -- reproduced." -ForegroundColor Red
        }
        Write-Host ''
    }

    # The verdict is printed here rather than left to the caller, because completion-order blocks bury it:
    # in a 27-suite weave the one red header is 2000 lines up. Sorted, so two runs name the same failures
    # in the same order. The elapsed line is deliberate too -- the whole point of this function's shape is
    # a number, and one it reports at every run cannot go stale in a document. The count includes the
    # Get-TestCommands entries: each is a suite of the repo's own stack, judged by the same exit-code rule.
    $elapsed = Format-GateSeconds $sw.Elapsed.TotalSeconds
    # THE LANE COUNT RIDES THE SAME LINE AS THE SECONDS, green and red (issue #1318, the #1314 defect one
    # step upstream). This summary line is the one a session copies into a branch document, a changelog
    # entry or a commit message -- and the seconds on their own are a draw from a distribution that spans
    # at least 4.5x, because the run's parallelism is not stated. $modeLabel already put the lanes on the
    # opening line at :674, which nobody quotes; this carries the same number to the line everybody does,
    # and the workflow's DEPLOY-section rule asks a quoted gate figure to name what produced it. Only when the pool
    # actually ran: a commands-only gate never resolves $MaxParallel and runs its commands one at a time,
    # so there is no lane count to state. The MACHINE is deliberately left off -- CI passes
    # -MaxParallel ([Environment]::ProcessorCount) while a dev box resolves its own count, so the lane
    # number already tells a hosted runner from a workstation without naming either.
    #
    # THAT NUMBER IS NO LONGER A FUNCTION OF THE CORES ALONE -- issue #2121. A dev box used to take
    # ([Environment]::ProcessorCount - 2) and nothing else, which made the lane count on this line a
    # reading of the machine's width; since the automatic count also divides free memory by
    # $script:TestSuiteGateLaneMemoryMB, the same box can quote a different number on two runs. The
    # sentence above survives that, because it only ever claimed to separate a hosted runner from a
    # workstation -- but do NOT read a quoted lane count back as a core count, which is what the
    # arithmetic it used to name invited. The run that produced it says which reservation bound it, on
    # its own opening line.
    $laneNote = ''
    if ($runItems.Count -gt 0) {
        $laneWord = if ($MaxParallel -eq 1) { 'lane' } else { 'lanes' }
        $laneNote = " ($MaxParallel $laneWord)"
    }
    # THE SHARD RIDES THE SAME LINE, for the reason #1318 put the lane count here: this is the line that
    # gets quoted, and a figure quoted without its scope is unreadable later. '742s (4 lanes)' and
    # '186s (4 lanes)' say nothing about each other unless the second one also says it ran a quarter of
    # the pool -- and the whole argument of #1351 is a comparison between those two numbers.
    $shardNote = if ($ShardCount -gt 1) { " [shard $Shard/$ShardCount]" } else { '' }
    # A FOCUS RUN SAYS SO ON THE VERDICT LINE, for the reason the shard does -- this is the line a session
    # copies, and 'all 47 suites passed' off a reproduction run would be read as a gate that measured the
    # tree, which it did not: it measured one suite, repeatedly, and ran the other 42 items purely as load
    # (issue #1944).
    $focusNote = if ($focusMode) { " [FOCUS RUN -- $FocusSuite x $FocusRepeat, not a gate]" } else { '' }
    # AND SO DOES THE PART OF THOSE SECONDS NOTHING WAS RUNNING FOR -- issue #2095, for the reason
    # #1318 put the lane count here and #1351 the shard: this is the line that gets quoted, and the
    # seconds on it are the whole point of the function's shape. The run #2095 was filed on reported
    # '11,749s' for a pool that did 853s of work, and a reader meeting that figure in a branch document
    # has no way to tell it from a tree that got three hours slower. Absent on every ordinary run, so
    # nothing that already reads this line sees a byte it did not see before.
    $suspendNote = if ($suspendedSeconds -gt 0) { " [$(Format-GateSeconds $suspendedSeconds)s of that was machine suspend, issue #2095]" } else { '' }
    if ($failedNames.Count -eq 0) {
        $passScope = if ($focusMode) { "{0} focus repeat(s) of $FocusSuite passed" }
                     elseif ($ShardCount -gt 1) { "{0} of $poolTotal suites passed" }
                     else { 'all {0} suites passed' }
        $passCount = if ($focusMode) { $focusResults.Count } else { $total }
        Write-Host ("test gate: $passScope in {1}s{2}{3}{4}{5}." -f $passCount, $elapsed, $laneNote, $shardNote, $focusNote, $suspendNote) -ForegroundColor Green
        # NAMED ON THE GREEN VERDICT TOO -- issue #1941. A timeout on a LOAD item cannot fail a focus run
        # (its verdict decides nothing), and a run that quietly abandoned a process while reporting green
        # is the silence this whole mechanism was built to end. Same shape as the crash note below it.
        if ($timedOutNames.Count -gt 0) {
            Write-Host ("           TIMED OUT and did not decide this run: " + (@($timedOutNames | Sort-Object) -join ', ')) -ForegroundColor Red
        }
        if ($crashedNames.Count -gt 0) {
            # GREEN, AND NOT SILENT (issue #1723). Every one of these passed on its lone re-run, so the
            # tree is fine and the gate is right to be green -- but a process that died is a fact about
            # the RUN, and #1622's whole cost was a sighting nobody could re-read. Indented under the
            # verdict, the same shape the kept-output note below the red one already uses.
            Write-Host ("           crashed in the pool and passed alone: " + (@($crashedNames | Sort-Object) -join ', ')) -ForegroundColor Magenta
            if ($retainedCaptureDir) {
                Write-Host ("           crash output kept at $retainedCaptureDir") -ForegroundColor Magenta
            }
        }
        return $true
    }
    $namesInOrder = @($failedNames | Sort-Object) -join ', '
    $redTotal = if ($focusMode) { $focusResults.Count } else { $total }
    $redUnit  = if ($focusMode) { 'focus repeat(s)' } else { 'suites' }
    Write-Host ("test gate: {0} of {1} $redUnit FAILED in {2}s{3}{4}{5}{6}: {7}" -f $failedNames.Count, $redTotal, $elapsed, $laneNote, $shardNote, $focusNote, $suspendNote, $namesInOrder) -ForegroundColor Red
    # WHICH OF THE RED ONES DID NOT FINISH, spelled out under the verdict -- issue #1941. A reader who
    # only has this line cannot otherwise tell a suite that asserted and said no from one that never
    # answered, and the two send you to completely different places.
    if ($timedOutNames.Count -gt 0) {
        Write-Host ("           did not finish within the $(Format-GateSeconds $suiteDeadline)s bound: " + (@($timedOutNames | Sort-Object) -join ', ')) -ForegroundColor Red
        # AND A TIMEOUT IS NOT BY ITSELF A WEDGE -- issue #2255. $script:GateSuiteTimeoutSeconds's own
        # comment claimed "no suite can reach it by being slow" until a 9-lane run of this repo's 121
        # suites timed out check-plugin-integrity-docs.tests.ps1, which then passed all 188 asserts
        # standalone on the same checkout. The correction belongs HERE and not only in that comment: the
        # console line is what a session reads at the moment it decides what to suspect, and the cost of
        # the false reading was a second full gate run before anything else was considered. One sentence,
        # naming the single measurement that settles it, so the next reader spends one suite instead of a
        # whole pool.
        Write-Host ("           a slow suite CAN reach that bound, so this is not by itself a wedge (#2255) --") -ForegroundColor Red
        # AND THE CPU READING IS WHERE TO LOOK BEFORE SPENDING THAT RE-RUN -- issue #2279. The standalone
        # re-run is still the measurement that settles it, and this does not claim otherwise: what it says
        # is that each suite's own block above already carries a reading which usually removes one of the
        # two branches, so the re-run is confirming an answer rather than searching for one. #2255's cost
        # was a whole second gate run spent on a suite that was merely slow, which is exactly the case
        # that reading names on sight.
        Write-Host ("           re-run the named suite alone to tell 'never answered' from 'answered late'") -ForegroundColor Red
        Write-Host ("           -- and read the CPU line under each one first (#2279): it usually says which.") -ForegroundColor Red
    }
    # THE KEPT OUTPUT IS NAMED ON THE VERDICT, for the reason #1318 put the lane count there: this is the
    # line a session copies into a branch document, a commit message or an issue, so it is the one place a
    # path is certain to travel with the failure it belongs to. Indented under the verdict rather than
    # spliced into it, so nothing that already parses that line has to learn a new shape. Silent when
    # nothing was kept -- a commands-only gate, or a suite that failed without writing a byte.
    if ($retainedCaptureDir) {
        Write-Host ("           output kept at $retainedCaptureDir") -ForegroundColor Red
    }
    return $false
}
