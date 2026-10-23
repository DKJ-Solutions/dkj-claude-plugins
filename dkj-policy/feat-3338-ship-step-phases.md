## feat/3338-ship-step-phases

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

#### Why the printed lines were not enough

The issue's first repair option, reading ship-pr's own step lines out of its output, cannot place a step in
time: neither the tool result of a foreground call nor the output file of a backgrounded one carries a
timestamp per line. So ship-pr writes a mark per step instead. It is a shared script, so the mark goes into
an opt-in log: `Add-RunStepMark` in `run-progress-lib.ps1` writes nothing unless `DKJ_RUN_STEP_LOG` is set,
and only this repo's `.claude/settings.json` sets it. A consumer's ship is unchanged.

The open `feat/stopwatch-phase-table` branch (the label page's phase cards) touches `stopwatch-lib.ps1`
too, in its rendering half; this branch touches the transcript half, so the two do not depend on each other.

### CREATE

- [x] `run-progress-lib.ps1`: `Get-RunStepLogPath`, `Add-RunStepMark` (opt-in, never throws, capped at 1 MB) and `Read-RunStepMarks`
- [x] `ship-pr.ps1`: a guarded mark at `gates`, `ci-wait`, `forward` (a forwarded head's re-certification), `merge` and `fold`
- [x] `stopwatch-lib.ps1`: `Split-StopwatchShipTool` cuts a ship call at its marks; `Get-StopwatchTranscriptPhases -ShipMarks`; the cache reads this checkout's marks
- [x] the dev server passes the step log beside the store; `.claude/settings.json` sets `DKJ_RUN_STEP_LOG`
- [x] the plugin mirrors regenerated (`build-shared-scripts.ps1`)

### TEST

- [x] `stopwatch.tests.ps1`: a ship cut at its marks, a mark outside the call, an unknown step, a non-ship call, the cache reading only this checkout's marks (116 passed, 0 failed)
- [x] `run-progress.tests.ps1`: the log off writes nothing, a mark round-trips, a torn line and a mark outside the window are skipped (84 passed)

### DEPLOY: feat/3338-ship-step-phases

The Stopwatch's transcript phases now split a ship-pr call into its own steps
([#3338](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3338)): the checks before the PR,
the local gates and opening the PR, the CI wait, a forwarded head's re-certification, the merge, and the
fold. A whole ship used to be one phase, so 92% of a measured run sat under one row that hid 13 minutes of
local gates and two CI waits. `ship-pr.ps1` marks each step in a step log that `run-progress-lib.ps1`
keeps only when `DKJ_RUN_STEP_LOG` is set, which this repo's `.claude/settings.json` does. A ship with no
marks, from before this change, stays one phase.

**Score:** 2

#### What makes this deploy extra special

N/A: the marks are written only where `DKJ_RUN_STEP_LOG` is set, and no consumer sets it, so a consumer's
ship-pr behaves exactly as before.

**Score:** N/A

#### Pull Request

Stopwatch: a ship-pr call is split into its gates, CI waits, merge and fold
