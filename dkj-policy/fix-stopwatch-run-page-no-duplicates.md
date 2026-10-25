## fix/stopwatch-run-page-no-duplicates

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

The owner saw a run's start three times and its time twice on `/stopwatch/css-comment/2026-10-24-1657`.

### CREATE

- [x] `Format-StopwatchRunPageHtml`: the Time card is gone (owner, round 2); its total, change against the run before, work-time note and other-machine note close the phases card; the phase card gets no title
- [x] Round 3 (owner): the label beneath the heading goes where the crumb already names it (the Stopwatch, not the Logbook), and the Phases heading and its explanation go
- [x] `Format-StopwatchPhaseCard`: `-Title` optional with no empty card head; `-TotalNote` adds a Total row in the table's `tfoot`, or a Total line under the reason when there is no table

### TEST

- [x] `stopwatch.tests.ps1`: the start and the time each appear once, the total closes the table, no Time card, no label beneath the heading under -LabelCrumb, no Phases heading; 214 passed; `logbook.tests.ps1` 52 passed
- [x] Live page counted: the date once, 5:29 once

### DEPLOY: fix/stopwatch-run-page-no-duplicates

A Stopwatch run page names the run's start once, in its heading, and its total time once, as the closing Total row of its phases table with its change against the previous run beside it. The separate Time card is gone, and the phase card no longer carries a title restating the start and the time, and the label beneath the heading and the Phases heading with its explanation are gone too, the label staying in the crumbs, so the page stays compact. The Logbook's run page, which shares the layout, gets the same total row with its work time beside it.

**Score:** 2

#### What makes this deploy extra special

N/A -- the Stopwatch is this repo's own dev hub page, which no consumer runs.

**Score:** N/A

#### Pull Request

A stopwatch run page shows its start and time once

