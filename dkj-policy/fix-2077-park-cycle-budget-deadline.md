## fix/2077-park-cycle-budget-deadline

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

#### What #2077 measured, and the half of it that was wrong

`park-cycle.tests.ps1`'s last case -- *"a budget healthy at the PR check and spent by the look says
which it was"* -- failed on a GitHub-hosted runner and passed on a rerun of the **same commit**, on
PR #2072. It sits on `lint-en-tests`, this repo's one required check, so it cost a full CI cycle and
blocked a merge with no defect behind it.

The symptom stands. **The reason the report gave does not**, and the repair changes with it. #2077 read
the failure as *"the PR check read as spent before the fixture `gh` was ever reached"* -- but that arm
prints `the network budget for this turn is spent before the PR check`, and what the runner printed was
`gh did not answer in time`. That is the **timeout** arm: the call was made, and it was killed.

#### The arithmetic, which is what rules out the obvious repair

The bound handed to that `gh` call **is what the budget has left** (`Get-NativeCaptureBudgetBound`). So
with a budget `B`, a fixture sleep `d`, and `e` seconds of local git plumbing between the budget's
creation and the PR check, the case needs both:

- `d < B - e` -- the call survives its own bound, so `PR #42` is printed;
- `B - e - d < 5` -- the look after it finds less than the floor, so it is skipped.

That confines `e` to the window `(B - d - 5, B - d)`, **four seconds wide** -- and raising `B` and `d`
together, which is what the comment at :898 proposed and what the issue assumed, slides that window
without widening it by one second. There was no pair of numbers to move to. The comment's own claim of
"7s of process start-up" was the piece that was wrong: it costed the budget check and not the bound the
same budget then hands to the call.

#### So the declined seam is the repair, and it is no longer test-only

The file recorded a clock seam as **declined** -- *"test-only machinery in a lib every script here
loads, to save a cost measured at zero"*. The cost is no longer zero, and the seam is no longer
test-only. A duration is measured from the line that creates the budget, which sits after the process
start-up and five dot-sources; under a hook that time is the **ceiling's** already. So the deadline can
be stated absolutely, by a caller that knows when the turn falls due -- which is strictly more correct
than re-deriving it from a later moment, and which is what takes the case off the clock: with the
budget's deadline and the shim's wake-up anchored to the same instant, the gap between the two calls is
a constant.

### CREATE

- [x] `scripts/lib/native-capture-lib.ps1`: `New-NativeCaptureBudget -ExpiresUtc` -- the deadline as an
      absolute UTC instant, winning over `-TotalSeconds`, with `TotalSeconds` reported as what was left
      at creation and floored at 0
- [x] `scripts/task/park-cycle.ps1`: `-BudgetDeadlineEpochSeconds`, winning over `-BudgetSeconds` and
      `-UnderHook`, documented in the comment-based help and at the seam
- [x] `scripts/sync/build-shared-scripts.ps1`: the three mirrors regenerated

### TEST

- [x] `scripts/tests/park-cycle.tests.ps1`: the fixture's `-GhDelaySeconds` replaced by
      `-GhWakeFromFile` -- the shim answers at an absolute instant read from `_bin/gh-wake.txt`
- [x] `scripts/tests/park-cycle.tests.ps1`: case (u) pins both instants from one reading of the clock,
      and its comment block now carries the arithmetic instead of the margin that was wrong
- [x] `scripts/tests/native-capture.tests.ps1`: `-ExpiresUtc` asserted -- a live deadline, the
      precedence over `-TotalSeconds`, a deadline already past reading as set-and-spent, and the
      no-budget default untouched
- [x] both suites green (121 and 213 asserts), then the lint gate and the full test gate via `open-pr`

### DEPLOY: fix/2077-park-cycle-budget-deadline

A required check that goes red without a defect behind it costs a CI cycle, blocks a merge, and teaches
the next session to rerun rather than to read. `park-cycle.tests.ps1`'s mid-run-budget case did exactly
that on PR #2072 -- red on a GitHub runner, green on a rerun of the same commit -- and it is now off the
wall clock.

`New-NativeCaptureBudget` accepts the deadline as an absolute UTC instant (`-ExpiresUtc`), and
`park-cycle.ps1` accepts it as `-BudgetDeadlineEpochSeconds`, ahead of both `-BudgetSeconds` and
`-UnderHook`. That is not only a test seam: a duration starts at the line that builds the budget, after
the process start-up and five dot-sources, and under a hook that time belongs to the ceiling already --
a caller holding the turn's real deadline can now state it rather than have it re-derived from a later
moment.

**What the case looked like, and why raising the numbers could not have fixed it.** It ran a 12-second
budget against a fixed 8-second `gh` sleep. The bound handed to that call *is* what the budget has left,
so with `e` seconds of local plumbing before it the call needs `8 < 12 - e` to survive and
`12 - e - 8 < 5` for the look after it to be skipped -- a window on `e` four seconds wide, which raising
both numbers slides rather than widens. The margin the comment claimed to be protecting, "7s of process
start-up", had costed the budget check and not the bound that check then hands out. Both instants now
come from one reading of the clock taken after the fixture is built: the budget expires at `T+20`, the
shim answers at `T+17`, so the second margin is a constant 3 against a floor of 5 and the first
tolerates 15 seconds of start-up where it used to tolerate about 3.

**Score:** 3

#### What makes this deploy extra special

N/A -- nothing a subscriber runs changes. `cycle-autopark` still calls `park-cycle.ps1 -UnderHook`, the
duration path is byte-for-byte what it was, and no shipped caller passes the new parameter; it is a
capability their own hook could use, not a behaviour they receive. The failure this repairs is in this
repo's own gate.

#### Pull Request

The mid-run budget case is pinned to an absolute deadline, so a loaded runner cannot turn it red
