## feat/stopwatch-phase-table

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

The transcript phases were crammed into one table cell per run; give each run its own card with a row and a bar per phase.

### CREATE

- [x] `Format-StopwatchPhaseCard` replaces `Format-StopwatchTranscriptCell` in `scripts/lib/stopwatch-lib.ps1`: under a Phases heading, each run gets a card in the house card-head form, with a row per phase (longest first), its time, its share and a bar
- [x] The runs table drops its transcript column
- [x] A label with one run shows its time on a card of its own, with no Runs heading or comparison table; the table returns from the second run on (owner's look)
- [x] Such a page is titled with the run's start (heading, tab and crumb), the label beneath it (owner's look)
- [x] And reached at that start, `/stopwatch/yyyy-MM-dd-HHmm`; the label's own slug keeps answering, and two one-run labels started in the same minute keep their label slugs (owner's look)
- [x] Review by Victor (house card head, a run with a session but no phases) and Edith (the docstrings), applied

### TEST

- [x] `stopwatch.tests.ps1`: 115 passed, with new asserts for the row per phase, the bar, the order, the card head and the empty cases
- [x] The live hub at `/stopwatch/css-comment-change-reconstructed` serves the Phases heading and six bars

### DEPLOY: feat/stopwatch-phase-table

The Stopwatch label page no longer packs a run's phases into one table cell. Under its own Phases heading, each
run has a card with a row per phase, longest first, with its time, its share of the run and a bar of that share. A label with one run is titled with that run's start, is reached at that start
(`/stopwatch/2026-10-23-1238`, the label's own address still answering) and shows its time on a card of its own; the label title and the comparison table appear from the second run on.

**Score:** 2

#### What makes this deploy extra special

The Stopwatch is a page of this repo's own hub, so nothing a plugin user takes in a release changes.

**Score:** N/A

#### Pull Request

The Stopwatch label page shows each run's phases as a table of their own, one row and one bar per phase

