## fix/2327-cpu-idle-floor

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

#### The reason was verified before the repair, and it holds

#2327 names the cause as the floor sitting inside the noise of a sleeping process, and reports one
instance: 0.031s against a 0.030s floor under a 7-lane pool. Reproduced independently here on a
32-core box with a different load shape before anything was changed, so the repair is built on a
measurement rather than on the report.

#### What the two populations actually read

3s window, readings in CPU-seconds consumed by the whole lane tree:

| population | window CPU |
|---|---|
| sleeping tree, idle machine | 0.000 |
| sleeping tree, 16 competing lanes | 0.000 - 0.0156 |
| sleeping tree, 48 competing lanes | 0.000 - **0.0469** |
| sleeping tree of 18 processes, settled, 48 lanes | 0.000 - 0.0156 |
| working tree, idle machine | 3.20 - 3.30 |
| working tree, starved by 48 lanes | **1.42** - 2.95 |

The gap runs 0.047 -> 1.42, a factor of 30. The old floor of 0.030s sat inside the idle population.

#### The two alternatives #2327 left open, both declined on measurement

- **Widen the sample window.** Measured: over 10s a sleeping tree read up to 0.219s, which is 2.19% of
  the window against 1.56% at 3s. The noise fraction went UP, so a wider window buys a quieter reading
  only in the sense that the fixed 1% floor grows with it -- it relaxes the floor while looking like a
  fix.
- **Make the fixture's idleness measurable some other way.** It repairs the assert and leaves the
  verdict wrong on a real run, which is the half that costs a reader a standalone re-run.

A third fear was tested and dismissed: that the noise scales with tree size, which would rule out any
fixed floor. An 18-process sleeping tree read 0.875s until the sample was taken 20s after the spawn
instead of 4s, when it dropped to one clock tick. The 0.875s was process startup -- a tree genuinely
executing -- so the reading was correct rather than noisy.

### CREATE

- [x] Raise `$script:GateCpuIdleFloorFraction` from 0.01 to 0.10 (0.30s over the 3s window)
- [x] Replace the constant's block with both measured populations, the margins, and why the sentence
      it used to carry ("no case lands near 30ms") was the defect rather than a careless claim
- [x] Correct the window block: it claimed a floor "two orders of magnitude" below a busy thread, which
      is one, and it left the widen-the-window route open -- now declined there on the 10s measurement
- [x] Name at the comparison itself which way `-le` leans and why the idle side is the hedged one
- [x] Mirror the lib to its two other copies (`plugins/dkj-policy/`, `dkj-subagents-shopify`)

### TEST

- [x] Pin the DEFAULT floor against both measured populations -- the regression the two existing
      floor asserts could not catch, because they pass an explicit fraction and never read the constant
- [x] Assert the MARGIN as a number (at least 4x clear on each side), since both verdict asserts would
      also pass with the old 1% floor
- [x] `test-suite-gate.tests.ps1` standalone: 326 pass, 0 fail
- [ ] Full lint + test gate green via `open-pr.ps1`

### DEPLOY: fix/2327-cpu-idle-floor

The test gate's idle-CPU floor is now measured rather than assumed. It decided between "nothing in that
tree was running" and "the tree was still executing" at 1% of a 3s window -- 30ms -- on the written
claim that nothing in this repo's measurements lands near it. A sleeping process is not a process
consuming zero CPU: it takes timer interrupts and scheduler wakeups, and more of them on a loaded
machine. So the floor sat inside the noise it existed to clear, and this repo's own fixture sleeper
read 0.031s, inverted the verdict and failed the gate over a branch with nothing wrong with it.

Both populations were measured on a loaded 32-core box: a sleeping tree reaches 0.0469s, a working tree
starved by 48 competing lanes still holds 1.42s. The floor moves to 10% of the window -- 0.30s -- which
is 6.4x above the worst idle reading and 4.7x below the poorest working one. Widening the window was
measured and declined: over 10s the sleeping tree's share of the window rose to 2.19%.

**Score:** 3

#### What makes this deploy extra special

N/A -- the test gate is machinery this repo's own developers run; nothing a subscriber of a service
touches changes.

**Score:** N/A

#### Pull Request

The gate's idle-CPU floor is measured against a sleeping tree under load, not set at 1% of the window
