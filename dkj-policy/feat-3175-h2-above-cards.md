## feat/3175-h2-above-cards

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

Maikel, October 19, 2026: a hard rule that an `h2` never stands inside a card and always stands above it,
so the `h2` headers group the cards visually (#3175). The form already existed for two blocks (#206: a
`.grid-2` with a `.grid__head`); this makes it the only form and holds it with the gate.

### CREATE

- [x] The rule in `assets/house-style/README.md` (a section of its own under "Page patterns", blocks 7, 10
  and 11 of the Repo hub) and in the `house-style` skill, with the new checksum of `house-style.css`.
- [x] `house-style.css`: `.card__title` is an `h3` at `--text-h3`; a headed group in the page column takes an
  extra `--spacing-5` above it, so an `h2` sits closer to its own cards than to the group before it.
- [x] `patterns/repo-dashboard.html`: the in-flight cards stand under one `h2` "In flight", each titled with an `h3`.
- [x] The brand book: `CardHead` in a data card renders an `h3`; `InFlightCards`, `PageLinks` (one group)
  and the "DKJ-Solutions repos" card stand in a `CardGroup`.
- [x] Every dev-server and general page: each in-card `h2` moved above its card; the Issues page's three
  closed breakdowns and the placeholder's two setup cards share one `h2` each.
- [x] `check-house-style` check 4, `heading`: an `h2.card__title` or an `h2` opening a `.card__head` is a finding.

### TEST

- [x] `check-house-style.tests.ps1` (unit tests for the heading check, the gate's fixture, and this repo
  passing its own gate), `dev-pages`, `connector-dashboard` and `dev-preview-sessionstart` suites: green.
- [x] The brand book gate (`npm run gate`: lint, CSS checks, build): green.

### DEPLOY: feat/3175-h2-above-cards

An `h2` never stands inside a card any more: it stands above the card or cards it heads, in a `.grid-2`
with a `.grid__head`, and a card's own title is an `h3` (`.card__title` now renders at `--text-h3`). A
headed group takes extra room above it in the page column, so the `h2`s visibly group the cards. The
`check-house-style` gate gains a fourth check, `heading`, that reports an `h2` inside a card (#3175).

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions app whose cards carry an `h2` title fails the house-style CI gate from the merge on,
because the reusable gate runs its checks from `main`: move each `h2` and its sub line into a `.grid__head`
above the card and add `.grid__full` to the card, as the house-style README's "An h2 never stands inside a
card" lays out. That form already works with the current release. Once the release is taken, a
`.card__title` renders at the `h3` size in the sans instead of the `h2` size in the serif.

**Score:** 3

#### Pull Request

House style: an h2 never stands inside a card

