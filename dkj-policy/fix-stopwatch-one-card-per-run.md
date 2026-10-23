## fix/stopwatch-one-card-per-run

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

The owner asked twice on October 23, 2026 for every run to get a card of its own on `/stopwatch`, linking to a page of
its own. The overview still grouped runs by label, so the 17:22 run of `CSS comment, start to end` was merged into
one card with the earlier run that had the same label. The card's name is the run's start, not the label (the owner,
same day).

### CREATE

- [x] `ConvertTo-StopwatchModel` makes one group per run, keeping each run's change against the previous run of its label; a run's page is addressed by its start, and a label's old slug arrives at its newest run
- [x] The overview gives every run a card named by its start, with the label, time and change beneath; `Format-StopwatchLabelPageHtml` becomes `Format-StopwatchRunPageHtml`, showing that one run
- [x] `stopwatch.tests.ps1` and the dashboard suite's wording follow

### TEST

- [x] `stopwatch.tests.ps1`: 129 passed, 0 failed
- [ ] The owner's look at `/stopwatch` and a run page on the hub

### DEPLOY: fix/stopwatch-one-card-per-run

The Stopwatch overview now gives every run its own card, also when runs share a label. Each card is named by the
run's start and leads to that run's page. Before this, runs with the same label were merged into one card.

**Score:** 3

#### What makes this deploy extra special

N/A: the Stopwatch is this repo's own hub tooling under `scripts/`, and no plugin ships it.

**Score:** N/A

#### Pull Request

The Stopwatch gives every run a card and a page of its own, also when two runs share a label

