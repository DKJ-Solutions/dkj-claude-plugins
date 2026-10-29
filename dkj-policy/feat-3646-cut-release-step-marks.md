## feat/3646-cut-release-step-marks

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

#### Issue

[#3646](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3646): on the v5.36.0 cut, 753 s of 903 s
landed in "Other tool calls", because `cut-release.ps1` marked no steps and no phase named its call.

### CREATE

- [x] `cut-release.ps1` (both byte-identical copies) marks eight steps with `Add-RunStepMark -Run 'cut-release'`:
  `origin-check-before`, `lint`, `tests`, `origin-check-after`, `builds`, `write`, `commit-tag`, `push`.
- [x] `stopwatch-lib.ps1` gives a `cut-release.ps1` call its own phase, `Release cut`, and generalises the ship
  split into `Split-StopwatchSteppedTool`: each stepped phase is cut only at its own run's marks.

### TEST

- [x] `stopwatch.tests.ps1`: the cut's phase, its split (a ship's mark inside it does not cut it), its steps in
  the window's phases, and a contract assert that the steps `cut-release` marks are exactly the steps the reader
  names, in order. 273 passed, 0 failed.

### DEPLOY: feat/3646-cut-release-step-marks

The Stopwatch now splits a release cut into its steps instead of filing most of it under "Other tool calls"
([#3646](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3646)). `cut-release.ps1` marks each step it
enters in the opt-in step log, the way `ship-pr.ps1` already did (#3338): the origin check and guardrails, the
lint gate, the test gate, the origin check after the gates, the release builds, the notes, overview and version
bumps, the commit and tag, and the push. A cut's call is now a phase of its own, `Release cut`, and a run's page
cuts it at those marks, so a change meant to make the next cut faster shows which step it moved. Runs already
read stay as they were cached. A cut from before this release, or on a machine without the step log, stays one
`Release cut` phase.

**Score:** 3

#### What makes this deploy extra special

The step log is opt-in (`DKJ_RUN_STEP_LOG`), and this repo is the one that turns it on, so a consumer sees no
change unless it does the same.

**Score:** N/A

#### Pull Request

cut-release marks its steps, and the Stopwatch splits a cut by them

