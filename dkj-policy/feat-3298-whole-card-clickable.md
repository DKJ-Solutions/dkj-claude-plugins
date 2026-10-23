## feat/3298-whole-card-clickable

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

#### Status

A visible result: parked for the owner's eye, with no pull request until they have looked.

### CREATE

- [x] `house-style.css` gains `.card--link`: a card around one link, whose area stretches over the whole card (a positioned card, the link's `::after` at `inset: 0`). The card tints on hover instead of the row alone
- [x] This repo's hub puts it on every one-link card: the page cards on the home page and the cards on the Repository page (`dev-pages-lib.ps1`)
- [x] The house-style README's Pages block names the class; the `house-style` skill's checksum is re-pinned

### TEST

- [x] `dev-pages.tests.ps1`: the card markup asserts carry `card--link`, every page card is one, and the house file holds the stretch rule (296 passed)
- [x] `open-pr.ps1 -GatesOnly` before the park

### DEPLOY: feat/3298-whole-card-clickable

A hub card that holds one link ([#3298](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3298)) used
to respond only on its row, so a click on the card's padding did nothing. The house style now has
`.card--link`: the card's one link stretches over the whole card, and the card tints on hover. This repo's hub
uses it on the page cards of its home page and on the cards of its Repository page, and the house-style README
names it in the Pages block.

**Score:** 2

#### What makes this deploy extra special

A page that builds on the house style can make a one-link card clickable over its whole area with one class,
`.card--link`, without any CSS of its own.

**Score:** 2

#### Pull Request

A hub card that is one link is clickable over its whole area

