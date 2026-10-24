## fix/3403-stopwatch-fetch-state

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

#3403, verified in the code: `Get-StopwatchPageRuns` raised `Fetching` only while no other machine had been
read, so a fetch on a later visit was silent, and the page never said how old its copy of the other machines'
runs was. A visible result: parked for the owner's look, no PR until then.

#### For the owner's look

Open `http://localhost:4871/stopwatch` (restarted on this branch). The footer now ends "...the runs of 2 other
machines are shown with these, as last fetched <time>." While a sync runs, the page shows "Checking origin for
newer runs from the other machines. This page reloads in a few seconds to show any." and reloads.

### CREATE

- [x] `Fetching` on every visit a sync runs, with its own wording once other machines are shown.
- [x] The footer names when the other machines' runs were last fetched (the mtime of `stopwatch-sync.log`).

### TEST

- [x] `stopwatch.tests.ps1`: the later-visit notice and its reload, the fetched time in local time, and no time
  claimed without one (179 passed standalone).
- [x] The owner has looked at `/stopwatch` and approved it (Dave, October 24, 2026).

### DEPLOY: fix/3403-stopwatch-fetch-state

The Stopwatch overview now says when its copy of the other machines' runs was last fetched, and says so
whenever a fetch is running, not only on the first visit
([#3403](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3403)). The page renders the runs last
fetched into `refs/stopwatch-origin/*` and starts a fetch in the background, so a run another machine had just
published was missing with no sign of why. Measured: a group showed one card short of another machine's
overview. The footer now ends with `as last fetched <time>`. While a fetch runs, the page says it is checking
origin for newer runs and reloads until the fetch ends.

**Score:** 2

#### What makes this deploy extra special

N/A: the Stopwatch is this repo's own dev-server page; no plugin ships it.

**Score:** N/A

#### Pull Request

The Stopwatch says when the other machines' runs were last fetched, and when a fetch is running

