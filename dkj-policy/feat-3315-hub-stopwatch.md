## feat/3315-hub-stopwatch

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

Card + /stopwatch page with manual timed runs, labels and improvement notes, compared per label; transcript phases follow in a second PR.

#### Owner's choice

Option 3 on #3315 (Maikel, October 23, 2026): the manual stopwatch first, in this PR; the phases read from
the session transcripts in a second one.

#### Design

- The clock is the server's: Start, Lap and Stop write timestamps, the page draws the time since the stored
  start. The hub restarts whenever HEAD moves, and the workflow being timed moves HEAD at every merge and
  fold, so a clock kept in the page would be lost mid-run.
- The store is outside the tree (`%LOCALAPPDATA%\dkj-claude-plugins\stopwatch.json`): a file in the
  checkout would dirty it in the middle of the workflow it times.
- A button is a same-origin POST to `/stopwatch/<action>` with its values in the query, answered before the
  restart check so a Stop pressed during a fold is not lost to the 503.

### CREATE

- [x] `scripts/lib/stopwatch-lib.ps1`: the store, the six actions, the model and the page
- [x] `serve-connector-dashboard.ps1`: the `/stopwatch` page, the POST route, `-StopwatchPath` for tests
- [x] The Stopwatch card in `Get-RepoHubPages`

### TEST

- [x] `scripts/tests/stopwatch.tests.ps1` (42 asserts), in the `pages` group of `suite-groups.json`
- [x] `dev-pages.tests.ps1` updated for the hub's third page of its own (294 green)
- [x] Smoke test on a throwaway server: start, a refused second start (409), lap, stop, the page and the
  hub card; a cross-site POST is 403, a POST to another route 405
- [x] `check-plugin-integrity.ps1`: 0 errors

### DEPLOY: feat/3315-hub-stopwatch

The hub has a Stopwatch page. Start it with a label when an assignment is given, mark the phases with Lap
and stop it when the work is done. Each run is compared with the previous run of the same label, faster or
slower, and carries a note on what to improve next time. The runs are kept on this machine, outside the
checkout, so timing a run never dirties the tree it is timing.

**Score:** 2

#### What makes this deploy extra special

The hub is this repo's own dev server, so nothing a consumer takes changes.

**Score:** N/A

#### Pull Request

Stopwatch card on the hub

