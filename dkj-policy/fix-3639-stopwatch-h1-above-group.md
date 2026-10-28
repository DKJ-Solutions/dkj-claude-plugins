## fix/3639-stopwatch-h1-above-group

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

Closes #3639. The owner's rule from 3fb642b72 (October 28, 2026): a page's h1 stands above its card group and is never framed inside it. The group and SessionStart pages follow it; the Stopwatch pages still set their h1 in a `grid__head` inside the group. A visible result, so the branch stops for the owner's look before the merge.

### CREATE

- [x] `stopwatch-lib.ps1`: the overview / Logbook, a label's page and a run's page set their h1 (and the run page's sub line) in a bare `<div>` above the group, as `Format-HubGroupPageHtml` does
- [x] `general-pages-lib.ps1`: `Get-PageSectionCount`'s docstring no longer describes a grid__head holding the page's h1
- [x] `stopwatch.tests.ps1`: the four asserts on the old shape follow, and two new ones pin the h1 above the group on the overview and a label page

### TEST

- [x] `stopwatch` 268/0, `dev-pages` 478/0
- [x] The owner has looked at `/stopwatch`, a label page, a run page and `/logbook`

### DEPLOY: fix/3639-stopwatch-h1-above-group

The hub's Stopwatch pages follow the house rule that the `h1` is never framed: the overview, the Logbook, a label's page and a run's page now set their `h1` above the card group instead of inside its surface.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

the Stopwatch pages set their h1 above the card group

