## fix/2318-native-capture-absolute-deadline-floor

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

Issue #2318: `native-capture.tests.ps1`'s absolute-deadline case built a budget 30s out and asserted
at least 25s remained -- a 5-second allowance for four cheap library calls, which on a loaded CI
shard measures the runner's own responsiveness rather than the budget's arithmetic. Red on CI
(run 35758609981, shard 2/4), green locally on the same commit -- exactly the wall-clock-tolerance
class #1232/#1401/#2095/#2279 already named. Repair it by bracketing the same window with a
Stopwatch (the idiom this file already uses for `$sw`/`$flushWatch`/`$calWatch`) and deriving the
lower bound from what the run actually measured, instead of a constant chosen when the machine was
fast.

### CREATE

- [x] Replace the fixed 25s floor in the `absolute deadline` case with a Stopwatch-derived one:
      capture elapsed time between building the budget and reading `Get-NativeCaptureBudgetSecondsLeft`,
      then assert the seconds-left is no lower than `30 - ceil(elapsed) - 1`.

### TEST

- [x] `scripts/tests/native-capture.tests.ps1` run standalone: 350 pass, 0 fail, including the five
      `absolute deadline:` asserts (`floor=28` against a measured 0.02s elapsed on this machine).

### DEPLOY: fix/2318-native-capture-absolute-deadline-floor

`native-capture.tests.ps1`'s absolute-deadline assert no longer budgets 5 seconds of runner latency
against four cheap function calls -- the floor is now derived from a Stopwatch bracketing the same
window, so the assert passes under any load while still catching a wrong `SecondsLeft` calculation.
Repairs the CI-only flake in #2318.

**Score:** 1

#### What makes this deploy extra special

N/A -- a test-only change with no reach past this repo's own developers/CI.

**Score:** N/A

#### Pull Request

Native-capture budget test: derive the absolute-deadline floor from measured elapsed time instead of a fixed constant

