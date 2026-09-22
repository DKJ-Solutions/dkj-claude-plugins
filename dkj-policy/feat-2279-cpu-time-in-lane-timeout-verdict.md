## feat/2279-cpu-time-in-lane-timeout-verdict

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

Add a tree-wide CPU reading to the deadline sweep so a TIMED OUT lane says whether anything was running. Reporting only -- the bound and the reap are unchanged.

### CREATE

- [x] `Get-GateProcessSnapshot` -- one `Win32_Process` CIM read of the whole machine (the impure seam).
- [x] `Get-GateTreeCpuSeconds` -- the pure tree walk over that snapshot, with the PID-reuse guard.
- [x] `Get-GateTimeoutCpuNote` -- the pure judgement composing the console lines.
- [x] The deadline sweep restructured to mark, measure, then kill -- one snapshot pair per pass,
      shared by every lane that passed its bound in it, so two lanes cost one window rather than two.
- [x] The note printed under each timed-out suite's own header, and the verdict's #2255 block pointed
      at it.
- [x] Both plugin mirrors of `native-capture-lib.ps1` synced byte-identical.

### TEST

- [x] Probed against real busy and idle GRANDCHILD trees before building on the mechanism -- this is
      what settled #2279's open question, and it caught a live defect: PowerShell variable names are
      case-insensitive, so a local `$window` inside the note function WAS the `$Window` parameter and
      silently replaced the reading with a number. Every lane would have reported "could not be
      re-read for a live sample" while holding a perfectly good sample.
- [x] 16 asserts on the pure walk and the note, over a fabricated machine (tree sum through a
      grandchild, PID reuse, cycle termination, unmeasured-is-not-zero, both verdicts, both sides of
      the floor, invariant formatting under nl-NL).
- [x] 3 integration asserts on the existing end-to-end wedge case -- the only place the SWEEP itself
      is shown to take the snapshots, fill the lane and print the note under the right header.
- [x] `test-suite-gate.tests.ps1`: 273 pass, 0 fail.

### DEPLOY: feat/2279-cpu-time-in-lane-timeout-verdict

A lane the test gate kills at its bound now reports what its process tree actually consumed -- the
whole tree's CPU over its lifetime, and how much of that it consumed in the last three seconds before
the kill -- directly under that suite's own `TIMED OUT` header.

**It answers ONE of the two questions #2279 asked, and the other turned out to be unanswerable.**
That issue's table wanted three cases separated: a suspended machine, a wedged lane and a deadlocked
tree. This file's own `$script:GateSuspendGapSeconds` block already records #1941's deadlock at 0.23s
across 29 children over 141 MINUTES, which is indistinguishable from #2231's wedge at 0.58s over 22 --
so no CPU reading separates those two, and this does not claim to. What it does separate is "something
was running" from "nothing was running", which is precisely the question the console had been handing
to the reader with a whole standalone re-run attached to it (#2255, whose own measurement cost a second
full gate run on a suite that was merely slow).

It also settles the implementation question #2279 left open. `TotalProcessorTime` reads the direct
child only, and every wedge in this family sits in a grandchild -- so the reading is taken from one
`Win32_Process` CIM snapshot of the machine and walked down the tree. Measured against a real busy
grandchild (3.45s of CPU over a 3s window, all of it two levels down) and a real idle one (0.000s).

Nothing about when a lane is reaped changed. The bound, the grace window and the kill are exactly what
they were; the sweep now marks, measures and then kills in the same pass, three seconds later in it.
And it does not reopen the suspend question, which that same block declines CPU for on grounds that
are untouched here: nothing added credits, reaps or kills anything -- it composes sentences.

**Score:** 3

#### What makes this deploy extra special

N/A -- this repo's subscribers consume the plugins, and the test gate is a development-time tool that
runs before a release exists. A consumer running the shared `native-capture-lib.ps1` does get the
better diagnosis on their own gate, but only ever as a maintainer of their own repo, never as a
subscriber to anything this repo ships.

**Score:** N/A

#### Pull Request

The test gate's timeout verdict reports the lane tree's CPU time

