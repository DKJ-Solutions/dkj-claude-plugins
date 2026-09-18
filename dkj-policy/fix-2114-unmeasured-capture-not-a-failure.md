## fix/2114-unmeasured-capture-not-a-failure

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

#### What this repairs, and what it deliberately does NOT

`update-plugins.tests.ps1` asserted `exit 0` in eight scenarios while the script it drives is
SPECIFIED to exit 1 whenever any capture in the run comes back with no measurable exit code. Those two
statements cannot both hold, and the suite lost the argument roughly half the time.

**The script is correct and is untouched.** `update-plugins.ps1` consults the state through
`Get-NativeExitLabel` and counts it as a failure by a decision #2081's audit argues at
`scripts/task/update-plugins.ps1:207`: this script answers *did every update succeed*, and for an
updater the conservative answer to *I could not tell* is no. That still holds, so nothing about the
script's behaviour changes here.

#### The arithmetic, which is the part that was being read wrongly

#1931 measured `ExitCodeUnknown` at **2.8% per capture** under 16 lanes of fresh PowerShell children.
A full run of this suite makes on the order of 30 captures through that arm, so the chance of at least
one landing is roughly **50% per run** -- not the 1-in-300 the per-capture figure suggests to a quick
reader. Two consecutive CI failures are an ordinary draw from that.

#### How it was diagnosed, including the wrong turn

Filed as `update-plugins.ps1` failing to consult `ExitCodeUnknown`. That was wrong -- read off the
`-ne 0` line without the seventeen lines of argument directly under it -- and #2114 carries the
correction. The shape that misled: the shim WAS called with the right ids and scopes and the run still
exited 1, which reads as a defect and is in fact the specification.

Ruled out on the way: contention. `reproduce-suite-contention.ps1 -Suite update-plugins.tests.ps1
-Repeat 4` passed 4/4 under 30 lanes, so this is not the #1915/#1939/#2068 class.

### CREATE

- [x] `Assert-CleanExit` -- asserts `exit 0` unless the run's own output carries the unmeasurable
      marker `Get-NativeExitLabel` emits, in which case it is counted apart and tolerated. NOT a
      blanket "0 or 1": an exit 1 without that marker still fails.
- [x] The eight clean-exit scenarios (1, 2, 3, 4, 8, 9, 10, 11) routed through it. The three that assert
      `exit 1` are untouched -- an extra unmeasured capture cannot change their verdict.
- [x] The footer prints the tolerated count when it is non-zero, and never folds it into pass or fail: a
      tolerated exit is not a passed assert, and a reader should know which scenarios were waved through.
- [~] Any change to `update-plugins.ps1` -- dropped deliberately. Reversing #2081's decision was the
      alternative, and it is the owner's call rather than a repair made on the way past. Decided against
      this branch.

### TEST

- [x] Suite green: **56 pass, 0 fail**, up from 51.
- [x] All three inputs to the helper driven with fabricated captures, since the state itself is a race
      at a few percent and a scenario that waited for it would be the flakiest thing in the tree:
      tolerated, a real exit 1 that still fails, and a clean exit 0.
- [x] The deliberate failure is **given back** after it is asserted, so this suite's own verdict stays
      honest; its red line is labelled as the assert working.
- [x] Lint gate: `0 error(s)`.
### DEPLOY: fix/2114-unmeasured-capture-not-a-failure

`update-plugins.tests.ps1` asserted `exit 0` on eight scenarios while the script it drives is
specified to exit 1 whenever a capture comes back with no measurable exit code -- a state measured at
2.8% per capture, which over a run's ~30 captures is roughly a coin flip. The suite now asserts on the
work done and tolerates that one documented state, counted and reported apart rather than folded into
the pass count. The script is untouched: counting an unmeasured capture as a failure is #2081's stated
decision and it still holds.

**Score:** 2

#### What makes this deploy extra special

The report that produced it was wrong, and the correction is the useful part. It was filed as the script
failing to consult `ExitCodeUnknown`; the script consults it and the counting is argued at the exact
line. What made that misreading easy is worth keeping: the shim was called with the right ids at the
right scopes and the run still exited 1, which reads as a defect and is in fact the specification.

The other half is arithmetic. A per-capture probability is not a per-run one, and 2.8% quoted as a rare
race becomes an even-odds failure once a suite makes thirty captures. The number was in the tree all
along; nobody had multiplied it.

**Score:** N/A

#### Pull Request

The update-plugins suite stops asserting an exit code a documented race owns