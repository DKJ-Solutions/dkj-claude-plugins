## feat/logbook-speed-tones

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

Dave asked for a clearer difference between fast and slow runs on the hub's Logbook page, in red, orange and green.
Bounds chosen as a default and named in the page footer: under 15 minutes of work green, under 45 orange, from 45 red.

### CREATE

- [x] `stopwatch-lib.ps1`: `-CardTones` on `Format-StopwatchRunCard` and `Format-StopwatchPageHtml`, the `sw-card--fast|medium|slow` classes in the page's own layer, house tokens only
- [x] `logbook-lib.ps1`: `Get-LogbookSpeedTones` off the work time (the whole time where none was measured), passed to the overview, bounds in the footer

### TEST

- [x] `logbook.tests.ps1`: the three tones at their bounds, work time over whole time, an open run uncoloured, the card class and the footer (55/0); `stopwatch.tests.ps1` 241/0
- [x] Checked on the live hub at `/logbook`: 11 green, 28 orange, 11 red cards
- [x] Dave's look: the coloured time stays, the left border goes

### DEPLOY: feat/logbook-speed-tones

The hub's Logbook overview colours each finished run's time line by its work time: green under 15 minutes, orange under 45, red
from 45 on. The time spent waiting on the owner does not count, and a run
whose work time was not measured is read off its whole time. The page footer names the bounds.

**Score:** 2

#### What makes this deploy extra special

Every repo running the dkj-policy hub sees at a glance which assignments were quick and which ran long, without reading each card's time.

**Score:** 2

#### Pull Request

Logbook cards coloured green, orange or red by work time

