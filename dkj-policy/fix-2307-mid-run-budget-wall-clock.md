## fix/2307-mid-run-budget-wall-clock

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

Issue #2307: `park-cycle.tests.ps1`'s mid-run-budget case went red on CI for the second time, on the
same two asserts, after #2077 had widened its margin from ~7s to ~15s. The trigger was a shard
relocation -- an untimed new suite is charged the pool maximum and moved this suite from shard 2 to
shard 1 -- but the relocation only exposed the defect, which is that the case had a wall-clock
assumption at all.

The arithmetic that rules out a third number: the budget starts before the process does, so the PR
check is reached with `B - e` left for `e` seconds of start-up and local git, and the case needs
`e <= B - 5`; and it cannot finish before the shim's instant falls due, so it also COSTS about `B`.
Tolerance and cost are one number, and raising `B` raises both.

- [x] Read the case, the budget lib and the shard-order function, and establish that the tolerance
      and the cost really are the same number rather than two knobs.

#### The repair, in one line

Make the deadline **late-bound**: a file holding the instant, re-read on every budget question, so
the `gh` shim can restate it mid-call. The clock is not faked -- real time still runs and a budget
still genuinely expires -- so nothing can be made immortal by this seam.

### CREATE

- [x] `native-capture-lib.ps1`: `New-NativeCaptureBudget -ExpiresFile`, winning over `-ExpiresUtc`
      and `-TotalSeconds`; `Get-NativeCaptureBudgetFileDeadline` as the reader that answers `$null`
      for every way it can fail; `Get-NativeCaptureBudgetSecondsLeft` re-reads it.
- [x] `park-cycle.ps1`: `-BudgetDeadlineFile`, fourth and most specific rung of the existing ladder.
- [x] `Get-TestSuiteShardOrder`: record beside the charged-maximum rule that it relocates suites it
      does not name, so the next author of a timing-sensitive case learns it before paying for it.
- [x] The `park` skill page: document the new parameter, and correct the `-BudgetDeadlineEpochSeconds`
      bullet, which claimed to take the budget off the wall clock when it took only half of it off.
- [x] Mirror the two shared scripts (`build-shared-scripts.ps1`).

### TEST

- [x] `park-cycle.tests.ps1` case (u) rewritten: the deadline is seeded an hour out and the shim
      rewrites it to now + 3 as it answers. Same four asserts, same arm, no wait.
- [x] `park-cycle.tests.ps1` case (t) extended with an already-past absolute deadline, so
      `-BudgetDeadlineEpochSeconds` keeps an end-to-end reading now that case (u) states its deadline
      in a file.
- [x] `native-capture.tests.ps1`: twelve asserts on the new seam -- late binding, the mid-run
      restatement, the fallback on an unreadable restatement, precedence, the no-budget shape for a
      path that cannot be read at birth, and the reader's own failure modes.
- [x] Timed, banner to first assert, on this workstation: **18.3s before, 2.4s after**.
- [x] `park-cycle.tests.ps1` (141), `native-capture.tests.ps1` (349), `shared-scripts.tests.ps1`
      (972) and `cycle-autopark.tests.ps1` (25) green; `check-plugin-integrity.ps1` green.
- [x] Negative probe: with the shim's budget-spend widened from `now + 3` to `now + 3600`, the case
      goes red on exactly the two asserts #2307 reports. It cannot pass vacuously.
- [x] Review chain on the diff -- code review, copy edit, security -- and their findings applied:
      the `[long]` cast described as a method that does not exist, a stale parameter count on the
      `park` skill page (already wrong at five before this branch added a sixth), a leftover clause
      arguing against `timeout.exe` where the rejected alternative is now a file copy, a missing
      case banner for (t2), and the floor-at-0 arithmetic written twice in `New-NativeCaptureBudget`.
      Security: no meaningful surface -- the seam moves the deadline and never the clock, cannot
      reach the lib's UNBOUNDED value, and no production caller passes it.
- [~] Full local suite gate not run -- this machine cannot finish it, so CI's required check
      `lint-en-tests` is the gate, as it is for every branch from here.

### DEPLOY: fix/2307-mid-run-budget-wall-clock

`park-cycle.tests.ps1`'s mid-run-budget case no longer measures anything in real time. A network
budget's deadline can now be stated in a **file** -- `New-NativeCaptureBudget -ExpiresFile`,
`park-cycle.ps1 -BudgetDeadlineFile` -- and is re-read on every budget question, so the suite's `gh`
shim moves it from inside the call instead of the case sitting idle until it falls due. What moves is
the deadline, not the clock: real time still runs and a budget still genuinely expires.

That case had gone red on CI twice, on the same two asserts, at ~7s of tolerance (#2077) and at ~15s
(#2307), each time costing a blocked merge and a full re-run. A third number would have failed the
same way, because the tolerance and the wall clock the case spends are one number: the budget starts
before the process does, so everything before the first call has to fit inside it, and the case cannot
end before it falls due. Timed banner to first assert on a workstation, the case went from 18.3s to
2.4s.

The trigger is recorded where it belongs rather than repaired: `Get-TestSuiteShardOrder` charges an
untimed suite the pool maximum, which is right for its own purpose and also **relocates suites it does
not name** -- a 0.7s addition priced at 669.1s moved this suite into a differently loaded shard, and the
branch that added it got the red. Its docstring now says so.

**Score:** 3

#### What makes this deploy extra special

N/A. A consumer running this workflow gets one optional parameter nobody types and a lib seam that is
inert unless it is passed: `park-cycle`'s behaviour under the Stop hook, by hand, and with either
existing budget knob is byte for byte what it was. What is fixed is this repo's own required check.

**Score:** N/A

#### Pull Request

The mid-run budget test case stops depending on how fast the machine is

