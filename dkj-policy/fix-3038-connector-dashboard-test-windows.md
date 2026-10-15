## fix/3038-connector-dashboard-test-windows

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

Repair #3038 test-side. Measured unloaded: server start ~0.6s (10s window), a request behind a silent
connection ~1.0s and group 3's cold page ~0.5s (both against a 3s read window). The failing assert of
the recurrence on PR #3051 sits on the smallest margin, so the read window is the likelier cause; the
start-up window is widened too, and group 3 now asserts its start-up on its own so a recurrence tells
the two apart.

### CREATE

- [x] `connector-dashboard.tests.ps1`: `Get-Raw`'s read window 3s -> 15s; one `Wait-ServerUp`
  (poll to a 30s deadline) for both groups; group 3 asserts its server came up

### TEST

- [x] `connector-dashboard.tests.ps1` standalone: 91 pass, 0 fail, 4.9s (no added time on a pass)

### DEPLOY: fix/3038-connector-dashboard-test-windows

`connector-dashboard.tests.ps1` failed on loaded CI shards and passed on a rerun
([#3038](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3038)), first in group 3's page
asserts, then in group 2's stalled-connection assert. Its 3s read window held about a 3x margin over
the measured unloaded latency, so it now reads for 15s and waits up to 30s for the server to start. A
passing run costs nothing extra, and a stalling server still fails, because the stalling client stays
open until after its assert. Group 3 now asserts its start-up on its own, so a recurrence says which
window it overran.

**Score:** 1

#### What makes this deploy extra special

**Score:** N/A

#### Pull Request

connector-dashboard tests: widen the read and start-up windows that a loaded CI runner overran

