## feat/stopwatch-ship-pr-card

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

The owner asked (October 25, 2026) for a card named Ship PR on the Stopwatch page, carrying the steps to time
a ship repeatedly and see where it can be made faster. The overview drew cards only from runs, so a label with
no run had nowhere to stand. A visible result: this branch parks for the owner's look, with no PR.

### CREATE

- [x] `scripts/lib/stopwatch-lib.ps1`: `$script:StopwatchPinnedLabels` with Ship PR and its five steps; a
  pinned label with no run gets a card of its own on the overview (`Format-StopwatchPinnedCard`), and once it
  has runs its ordinary label card carries the steps (`Format-StopwatchPinnedSteps`). One `.sw-steps` rule,
  house tokens only. The Logbook's flat overview is unchanged.
- [x] `scripts/tests/stopwatch.tests.ps1`: the pinned card with no run, the steps on the label card once a
  run exists, no link without runs, nothing in the Logbook.
- [ ] The owner has looked at `/stopwatch` on the hub and approved the card.

### TEST

- [x] `stopwatch.tests.ps1` 188/188, `logbook.tests.ps1` 52/52, `dev-pages.tests.ps1` 314/314, run alone
  while building; the full gate is `ship-pr`'s, after the owner's look.

### DEPLOY: feat/stopwatch-ship-pr-card

The Stopwatch overview now carries a Ship PR card before its first run, with the five steps that time a ship the
same way every time: a branch made ready outside the clock, a prompt whose first line is exactly
`stopwatch: Ship PR`, and the run page's split of the ship into its checks, local gates, CI wait, merge and fold.
Once a Ship PR run exists, the steps move onto that label's ordinary card. Runs of one label are compared with
each other, so the card is where a slow step and a speed-up attempt show.

**Score:** 2

#### What makes this deploy extra special

N/A: the Stopwatch is this repo's own dev-server page; no plugin ships it.

**Score:** N/A

#### Pull Request

The Stopwatch overview carries a Ship PR card that says how to time a ship again and again

