## docs/2796-parking-labels-at-filing

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

#2796: only `awaiting-decision` had a "set at filing" rule, and the filing rules a session has always
loaded (Chris's lens) named `prio-N` and `minor` but no parking label. So #2795 was filed unparked.
One rule for the whole `awaiting-*` family, placed where filing rules are read.

### CREATE

- [x] Chris's lens: a filing bullet beside `prio-N`/`minor` naming all five parking labels
- [x] `CONTRIBUTING-portable.md`: a general "parking label goes on at filing" paragraph ahead of the per-label ones
- [x] Derek's lens: the parking-labels heading and a lead line say all of them are set at filing

### TEST

- [x] Lint and test gates through open-pr

### DEPLOY: docs/2796-parking-labels-at-filing

An issue whose next step waits on something other than work now carries its `awaiting-*` parking label
from the moment it is filed, for all five labels rather than `awaiting-decision` alone. The rule now
sits beside the `prio-N` and `minor` filing rules in Chris's lens, which every session here loads, so it
is read when an issue is filed. Before, a waiting issue could be filed unparked and look like free work
to both pickup routes.

**Score:** 2

#### What makes this deploy extra special

`CONTRIBUTING-portable.md` now says once that every parking label (`awaiting-decision`, `awaiting-pull`,
`awaiting-event`, `awaiting-first-recurrence`, `awaiting-more-recurrences`) goes on in the same
`gh issue create` as the `prio-N`. Before, it said that only for `awaiting-decision`. A consumer's
waiting issues are parked from the start rather than picked up by a sweep that has nothing to build.

**Score:** 2

#### Pull Request


Every parking label goes on at filing, not only awaiting-decision
