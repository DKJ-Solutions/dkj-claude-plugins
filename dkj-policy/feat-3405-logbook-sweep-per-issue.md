## feat/3405-logbook-sweep-per-issue

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

A `/sweep-issues` run is timed as one Logbook run, the whole sweep; the owner wants each issue timed from a clean
trunk back to a clean trunk (#3405). The step log already marks every ship-pr fold per checkout, so the pages cut
a sweep there and name each piece from its fold commit. The store and the hooks stay as they are.

### CREATE

- [x] `Split-LogbookSweepRuns`, `Get-LogbookFolds` and `Get-LogbookRuns` in `scripts/lib/logbook-lib.ps1`, and both Logbook routes of the dev server read their runs through it
- [x] Measured on this machine's own store: the 77-minute sweep of October 24 reads as #3392 (43.3 min) and #3397 (33.0 min)

### TEST

- [x] `scripts/tests/logbook.tests.ps1`: the fold matching and the cut, finished, going, plugin-qualified, without a fold, not a sweep, without a step log (52 passed)

### DEPLOY: feat/3405-logbook-sweep-per-issue

The Logbook now times a `/sweep-issues` session per issue
([#3405](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3405)). A sweep used to be one run of the
whole sweep, whose length only said how many issues the backlog held. Its pages now cut it at every `ship-pr` fold
of this checkout, the moment the trunk is clean again: each issue gets a card and a page of its own, from the
previous clean trunk to its fold, named after the issue its fold commit names (`/sweep-issues #3397`), with its own
transcript phases and work time. The time after the last fold belongs to no issue and is not shown; in a sweep
still going, the issue in progress shows as going. The store and the hooks are unchanged.

**Score:** 3

#### What makes this deploy extra special

N/A: the Logbook is this repo's own hub tooling under `scripts/`, and no plugin ships it.

**Score:** N/A

#### Pull Request

The Logbook times a /sweep-issues run per issue, clean trunk to clean trunk

