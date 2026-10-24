## fix/3377-stopwatch-first-sync-fetching

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

#### The cause, verified

`Get-StopwatchPageRuns` in `scripts/dashboard/serve-connector-dashboard.ps1` starts the sync with
`Start-StopwatchSync`, which returns at once, and then reads `refs/stopwatch-origin/*` as they stood
before it. On a machine's first visit there are none yet, so the overview states "no other machine has
shared a run yet" while the fetch is still under way (#3377).

### CREATE

- [x] `Test-StopwatchSyncRunning` in `scripts/lib/stopwatch-sync-lib.ps1`: a stamp younger than the sync
  interval, with a log missing or older than it, is a sync under way.
- [x] The hub marks the shared read `Fetching` when it found no other machine and a sync is under way.
- [x] `Format-StopwatchPageHtml -Fetching`: a status line above Measurements, the footer clause "still
  being fetched" in place of the empty-origin one, and a reload every four seconds until the sync has ended.

### TEST

- [x] `stopwatch-sync.tests.ps1`: five asserts on `Test-StopwatchSyncRunning` (no stamp, no log yet, an
  older log, a newer log, a stamp aged past the interval).
- [x] `stopwatch.tests.ps1`: the empty page states an empty origin and does not reload; `-Fetching` says
  the runs are being fetched and reloads.
- [ ] The owner looks at `/stopwatch` on a first visit (a visible result).

### DEPLOY: fix/3377-stopwatch-first-sync-fetching

The Stopwatch overview on a machine's first visit no longer says that no other machine has shared a run
while its first sync is still fetching them. Until that sync has ended it says the other machines' runs
are being fetched, and reloads every few seconds to show them
([#3377](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3377)).

**Score:** 2

#### What makes this deploy extra special

N/A: the Stopwatch is this repo's own hub page and ships in no plugin.

**Score:** N/A

#### Pull Request

Stopwatch: say the other machines' runs are being fetched while the first sync runs
