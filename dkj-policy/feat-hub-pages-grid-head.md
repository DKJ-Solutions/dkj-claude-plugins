## feat/hub-pages-grid-head

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

The owner asked for one heading over the Repo hub's two Pages cards, which since #3117 stand side by side
in the house `.grid-2`: a `grid__head` inside that row carries the h2, and the two card titles become h3s.

### CREATE

- [x] `scripts/lib/dev-pages-lib.ps1`: `Format-RepoHubHtml` opens the `.grid-2` with `<div class="grid__head"><h2>Pages</h2></div>`, and the cards are titled with the house's own `h3` -- **This repo** and **General** (a `.card__title` would keep them at the h2 size) -- each nav named "<title> pages"; `grid__head` is a page-layer name the house file does not define, spanning both columns (`grid-column: 1 / -1`) and the cards drop the house `.card`'s `margin-top` inside that row, where it came on top of the grid's own `--spacing-4` gap and doubled it (the owner's look; a negative margin on the head was tried first) -- a house class touched in context, so asked for upstream in DKJ-Solutions/dkj-brandbook#207. One card alone stays block 7 as the form gives it, its title the h2
- [x] Block 11 the same way, for consistency and a clearer split from Pages (the owner's look): **About this repo**'s h2 leaves its card for a `grid__head` in a `.grid-2` of its own, and the card spans that row (`grid__full`, a page-layer name beside `grid__head`), so head and card sit at the same gap as in the Pages row

### TEST

- [x] `scripts/tests/dev-pages.tests.ps1`: the head and its h2 open the row, the h3s and their rows, no card repeating the h2, the head spanning both columns, the cards without their margin-top in the row, and one card alone keeping the plain block 7, and About this repo's h2 outside its full-row card; 137 pass
- [x] Served on this machine's dev server for the owner's look -- a visible result, so it waits for that before it merges

### DEPLOY: feat/hub-pages-grid-head

The Repo hub's two Pages cards stand under one **Pages** heading spanning the row, and each card is titled
one level lower: **This repo** and **General**. **About this repo** takes the same shape, its heading above
its card rather than inside it.

**Score:** 2

#### What makes this deploy extra special

N/A -- the hub lives on this repo's own dev server; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

a grid heading over the Repo hub's two Pages cards
