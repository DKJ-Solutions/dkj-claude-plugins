## feat/1941-gate-suite-deadline-and-focus-mode

> **How this file is read.** A step is `- [ ]` until it is resolved -- `- [x]` done, or
> `- [~]` dropped with the reason, which exists so nobody ticks a box for work they did not do.
> open-pr and ship-pr both refuse while one is still open, and there is no `-Force`.
>
> **FOUR `###` HEADINGS, AND NEVER A FIFTH** -- PLAN, CREATE, TEST, DEPLOY are the whole top
> level. A section needing its own heading goes in as a `####` UNDER whichever of the four owns
> it. No gate in YOUR repo reads a heading, so this half is on you -- only the repo that authors
> this workflow refuses a fifth (Dave, August 26, 2026).
>
> **AND NOTHING BRANCH-SPECIFIC ABOVE THE FIRST OF THOSE FOUR HEADINGS** -- everything between the
> title and it is this guidance, which is identical in every branch document. A status line, a note about
> THIS branch or an instruction to a session belongs under one of the four, normally as a `####`
> in PLAN. THIS half open-pr refuses, in every repo, before the push -- it reads the shape, so a
> guidance block in your own language passes and your own paragraph here does not (Dave,
> August 26, 2026; refused since #1650).
>
> **DEPLOY takes no steps of its own, and it is WRITTEN LAST** -- it is what the branch DID, once
> TEST says so. Written while steps above it are still open it states an INTENTION, and no gate
> holds it against what landed: the step gate splits this file at that heading and counts only
> above it. The PR title is the one exception -- new-branch -Title writes it at creation, because
> open-pr composes the PR title from it. It is the one part of this file that travels verbatim
> into `CHANGELOG.md` at the merge. In each tier, write the reason
> ABOVE the Score line -- anything below it is discarded.
>
> Relative links in that text resolve FROM THIS DIRECTORY -- `CHANGELOG.md` sits here too, so
> write each path exactly as it reads in this file.
>
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

#### The two issues, and what was verified before anything was written

**#1941 -- a gate run deadlocked for 141 minutes with its whole 30-lane tree alive.** The report's own
cause (a blocked-pipe deadlock in `Invoke-NativeCapture`'s `Start-Process` capture) is marked in the
issue as **inferred and NOT verified**, and nothing here builds on it. What *is* verified, by reading
the code, is a separate defect the symptom rests on: **`Invoke-TestSuiteGate`'s reap loop has no
deadline of any kind.** `while ($queue.Count -gt 0 -or $running.Count -gt 0)` sleeps 100 ms and loops,
forever, for whatever reason a lane stops progressing. So a wedged suite wedges the whole gate,
silently -- the pool buffers a suite's output until that suite exits, so a run that never exits prints
nothing after its opening `started` lines. That is exactly the measured shape: 90 processes, no output,
no error, no red.

**This repair is therefore narrower than the issue proposed, and wider in one way it did not ask for.**
It does not claim to fix the cause, which is still unknown. It bounds it, names it, keeps its evidence
and turns it red -- so the next occurrence reports itself instead of costing a machine in silence, and
#1704's residual (*a degraded run keeps no per-suite table*) stops applying to the wedged case.

**#1944 -- no way to put ONE suite under the pool's real contention.** Verified: `Invoke-TestSuiteGate`
takes `-TestsDir`, `-Context`, `-MaxParallel`, `-Shard`, `-ShardCount` and nothing that selects a
suite. The issue's shape 1 is the one built here -- a knob on the gate, so the contention is the
genuine article rather than the synthetic load that fell 3.4x short of it.

#### Why one branch for two issues

They meet in the same twenty lines. The deadline lives in the reap loop; focus mode changes what that
loop dequeues and whose verdict counts. Two branches would conflict on every hunk, and the kill
machinery the deadline needs -- `Stop-NativeProcessTree`, already in this lib -- is what makes a focus
run affordable to describe. One branch, one DEPLOY section covering both.

#### The number, and why this bound is on by default

`$script:GateSuiteTimeoutSeconds = 1800`. The slowest suite this repo has ever recorded is
`new-branch.tests.ps1` at 290s on CI (`../scripts/tests/suite-durations.json`), so 1800s is a ~6x
margin over the worst honest run and no suite can reach it by being slow. It is **on by default**,
unlike `$NativeCaptureNetworkTimeoutSeconds`, and the asymmetry is the whole argument: that bound is
opt-in because `gh pr checks --watch` is legitimately unbounded, and **no test suite is ever
legitimately infinite**. `-SuiteTimeoutSeconds -1` is the escape valve; `0` resolves the default, the
same idiom `-MaxParallel` already uses in this function.

### CREATE

- [x] `Invoke-TestSuiteGate`: a per-suite deadline -- mark, kill the tree, force-reap past a grace
      window, report `TIMED OUT` as a fourth verdict, keep the capture files, fail the gate (#1941)
- [x] A timed-out suite is deliberately NOT routed to #1723's lone re-run: a wedge that passes alone
      would leave the gate green, which is the silent cost #1941 reports
- [x] `Get-TestSuiteFocusOrder`: compose the focus queue -- N copies of the target interleaved with
      real sibling suites as load, sized from the recorded cost hints (#1944)
- [x] `Invoke-TestSuiteGate`: `-FocusSuite` / `-FocusRepeat`, load verdicts excluded, a per-repeat
      summary, and refusals for the combinations that cannot mean anything
- [x] The queue holds wrapper items rather than bare `FileInfo`, so a repeated suite gets its own
      capture stem instead of overwriting its sibling's
- [x] `scripts/maintenance/reproduce-suite-contention.ps1` -- a front door onto focus mode, because a
      capability reachable only by dot-sourcing a lib is one nobody uses, which is what #1944 is about

### TEST

- [x] `test-suite-gate.tests.ps1`: the deadline bounds a suite that would outlive it, names it, keeps
      its output, and the run finishes far inside that suite's own sleep
- [x] `test-suite-gate.tests.ps1`: `-SuiteTimeoutSeconds -1` turns the bound off
- [x] `test-suite-gate.tests.ps1`: focus mode runs the target N times, load failures do not fail the
      gate, a target failure does, and the summary carries one row per repeat
- [x] `test-suite-gate.tests.ps1`: `Get-TestSuiteFocusOrder`'s refusals and its ordering, in-process
- [x] `scripts/sync/build-shared-scripts.ps1` -- this lib is mirrored into `dkj-policy` and `dkj-subagents-shopify`
- [x] the lint gate and the full suite pool, green

### DEPLOY: feat/1941-gate-suite-deadline-and-focus-mode

**No test suite runs unbounded any more, and one suite can now be put under the pool's real
contention.** Two changes to `Invoke-TestSuiteGate`, the gate `open-pr.ps1`, `cut-release.ps1` and CI
all run.

**The deadline (#1941).** The reap loop had no deadline of any kind: it slept 100 ms and went round
again for as long as a lane took, whatever had stopped that lane progressing. One wedged suite
therefore wedged the whole gate, and did it in **silence**, because the pool buffers a suite's output
until that suite exits -- so a suite that never exits prints nothing after its opening `started` line.
Measured: **141 minutes**, 61 `powershell.exe` and 29 `git.exe` alive, 0.23 s of CPU between all 29
git children, no output, no error, no red, and nothing stopping a later gate on that machine starting
its own 30 lanes on top. Each lane now carries a bound (`$GateSuiteTimeoutSeconds`, 1800s -- about 6x
the slowest suite this repo has ever recorded); past it the process **tree** is killed, and past a
further grace window a lane that did not die is **abandoned** rather than waited on, which is the half
that actually makes the loop terminate under every condition.

**A timeout is a fourth verdict and it is deliberately NOT re-run.** #1723's crash path re-runs a
suite alone because a killed process measured nothing. A timeout *has* measured something, so
re-running it alone would remove the contention that is the likeliest cause, pass, and hand back a
green gate over a run that cost the machine 90 processes -- the exact silence #1941 was filed about.

**What it does not claim.** #1941's own inferred cause -- a blocked-pipe deadlock in the
`Start-Process` capture -- is marked unverified in the issue and nothing here repairs it. This bounds
it, names which suite it was, and keeps its capture files. That is also what closes the residual
[#1704](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1704) was left with: a degraded run
that keeps no per-suite table.

**Focus mode (#1944).** This repo has a class of defect visible only under the pool -- `#1915` and
`#1939`, three days apart, different files, different causes, identical discovery path: the gate
refusing a push on a branch that touched neither suite. Repairing one meant running the whole
~19-minute gate, because a standalone run is green *by definition of the bug*, and a synthetic
imitation does not substitute -- measured at 0.47-0.95s launch-to-print against the real gate's 3.25s,
~3.4x short, with the suite staying green under it. `-FocusSuite` / `-FocusRepeat` now run one named
suite N times while **real sibling suites** fill every other lane: same pool, same console, same spawn
model. Only the named suite's repeats decide the verdict, the load's headers say so, and every line
the run prints says it is a reproduction rather than a gate.
`scripts/maintenance/reproduce-suite-contention.ps1` is the front door, because a capability reachable
only by dot-sourcing a lib is one nobody uses -- which is the complaint #1944 actually made.

**Score:** 3

#### What makes this deploy extra special

**`native-capture-lib.ps1` is mirrored into `dkj-policy` and `dkj-subagents-shopify`, so every
consuming repo runs this same parallel gate** and inherited both gaps. Nothing is asked of anybody --
no config, no migration, no new call site: the bound is on by default and the ordinary run is
byte-identical in every line it prints.

**The asymmetry with `$NativeCaptureNetworkTimeoutSeconds` is the argument for that default.** That
bound is opt-in because `gh pr checks --watch` is legitimately unbounded, and a default would turn the
longest correct call in the workflow into a failure. There is no such call here: **no test suite is
ever legitimately infinite**, so the safe default is the bounded one and the escape valve is the flag
(`-SuiteTimeoutSeconds -1`).

The half a consumer will actually notice is the silence ending. A wedged gate cost one machine 90
processes and two and a half hours without printing a character; it now prints a red line naming the
suite, keeps that suite's output at a path the verdict states, and returns. The focus knob is the
quieter half and the one that changes a workflow: a consumer repairing a flaky-under-load suite no
longer has to run their whole gate to find out whether the repair held.

**Score:** 3

#### Pull Request

A test suite that never returns is bounded and named, and one suite can be put under the pool's real contention

Plugins: dkj-policy, dkj-subagents-shopify
