## feat/house-style-h2-in-card

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

Maikel asked for an h2 inside the Stopwatch's label cards and, asked about the conflict with #3175, chose to
retire that rule (October 24, 2026). Stacked on `feat/house-style-h1-sans`, which merges first.

### CREATE

- [x] `house-style-rules.ps1`: check 4, `heading`, and `Find-HouseStyleHeadingHit` removed; the counts say three
- [x] `check-house-style.ps1`, `house-style-sessioncheck.ps1`, the skill page and the house-style README follow
- [x] `scripts/repo-config.ps1`: the two allowlist entries that answered the heading check are gone
- [x] `check-house-style.tests.ps1`: the heading asserts replaced by one that the check is gone and an h2 card passes

### TEST

- [x] `check-house-style` (79), `dev-pages`, `connector-dashboard`, `dev-preview-sessionstart`, `stopwatch` green
  locally; the gate and `check-plugin-integrity` pass on this repo

### DEPLOY: feat/house-style-h2-in-card

The house rule that an `h2` never stands inside a card (#3175) is retired, and with it `check-house-style`'s
fourth check, `heading`. An `h2` may now title a card; the grouping form with an `h2` in a `.grid__head` above
`h3`-titled cards stays where a page groups cards.

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions app whose CI runs the house-style gate no longer fails on an `h2` inside a card.

**Score:** 3

#### Pull Request

Retire the house rule that an h2 never stands inside a card

