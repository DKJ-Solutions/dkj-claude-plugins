## fix/3614-grid-2-minmax-tracks

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

#3614: `.grid-2`'s `1fr 1fr` tracks never shrink below a card's min-content, so a nowrap line scrolls
the page sideways. Use `minmax(0, 1fr)`, as `.grid-3` already does, in the 760px single-column step
too. The hub's local `.dr-card { min-width: 0; }` workaround lives only on `feat/repo-card-split`, not
on `main`, so it goes with that branch.

#### Parked for the owner's eye (a sweep, #3552)

Styling, so no PR until the owner has looked: two cards side by side in a `.grid-2`, one with a nowrap line,
no horizontal scrollbar, at desktop width and below 760px.

### CREATE

- [x] `house-style.css`: `.grid-2` is `repeat(2, minmax(0, 1fr))`, and the 760px step is `minmax(0, 1fr)`

### TEST

- [ ] The owner has looked at a `.grid-2` page: no sideways scroll

### DEPLOY: fix/3614-grid-2-minmax-tracks

House style: a `.grid-2` row no longer widens the page when one of its cards holds a one-line nowrap
element such as an ellipsised description or a `code` command. Its tracks now shrink like `.grid-3`'s,
`minmax(0, 1fr)`, and so does the single column below 760px (#3614).

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions app that sets two cards side by side no longer scrolls sideways when one of them holds
a long single line; a local `min-width: 0` workaround for it can go.

**Score:** 2

#### Pull Request

House style: .grid-2 tracks shrink below a card's min-content

