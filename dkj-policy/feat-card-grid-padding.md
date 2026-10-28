## feat/card-grid-padding

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

The owner wants the container the cards sit in (a .grid-2, a .grid-3, a repo's own card grid such as .dr-repos) to always carry a minimum padding of 12px, so the cards never touch the edge of their group.

### CREATE

- [x] `house-style.css`: `:is(.grid-2, .grid-3, .card-grid) { padding: var(--spacing-3); }`, with `.card-grid` as the
  house class a repo puts on its own card grid beside the class that sets its columns
- [x] `dev-pages-lib.ps1`: the DKJ repos page's `.dr-repos` grid carries `card-grid` (the example the owner named,
  `/connectors/dkj`); its test follows
- [x] the group is a `--paper-2` surface with a 16px radius, and each direct `.card` in it sits one step further on
  `--paper-3`, its lines (border, table rows, hover) moved to `--paper-4`, with no token of its own
- [x] the house-style README names the padding and `.card-grid`; the skill's sha256 pin follows the stylesheet

### TEST

- [x] suites `check-house-style` (90), `dev-pages` (478) and `house-palette` (128) pass
- [x] the owner looked at `/connectors/dkj` and said "ship it" (October 28, 2026)

### DEPLOY: feat/card-grid-padding

Every container of cards in the house style -- a `.grid-2`, a `.grid-3`, and a repo's own card grid marked with the
new house class `.card-grid` -- now keeps at least 12px of padding round its cards, so a card never touches the
edge of its group. The group stands on a surface one step off the page, and each card in it one step further, so on
a dark theme the cards read a little lighter than their group and the group a little lighter than the page (on a
light theme each step is a little darker). The DKJ repos page under Connectors is the first page to use `.card-grid`.

**Score:** 2 -- small; noticed if somebody points it out

#### What makes this deploy extra special

A DKJ-Solutions app that takes the next house-style copy sees its card groups gain 12px of padding and a surface of their own, and can put
`.card-grid` on a card grid of its own.

**Score:** 2 -- small; a slightly roomier card group in every app on its next copy

#### Pull Request

Every container of cards keeps at least 12px of padding

