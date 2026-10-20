## fix/drop-h3-shift-headings

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

The owner (Dave, October 20, 2026): the gap between h2 and h3 is too small -- remove the current h3 entirely,
shift everything up, and afterwards there is no h6.

### CREATE

- [x] `house-style.css`: `--text-h3` 22px, `--text-h4` 18px, `--text-h5` 16px, no `--text-h6`; the `h6` rule and its colour gone; every use moved one level up
- [x] `--text-h6` added to `Get-HouseStyleRetiredTokens`, the checksum re-pinned in the `house-style` skill
- [x] README: the type row, the heading colours, the dialog title, and a migration table for the shift
- [x] Brandbook: tokens one level up, and the elements whose level was picked for its size (card, dialog, alert, question and calc titles) one level up; nested showcase outlines keep their nesting
- [x] Connector dashboard: a repo name stays 18px, now as `--text-h4`

### TEST

- [x] `npm run gate` in `brandbook/` green; `check-house-style`, `connector-dashboard` and `dev-pages` suites green; `check-house-style.ps1` OK
- [ ] The owner has looked at the hub and the brand book

### DEPLOY: fix/drop-h3-shift-headings

The house heading scale loses its 24px `h3` and every level below it moves up one: `h3` is 22px, `h4` 18px,
`h5` 16px, and there is no `h6` or `--text-h6` any more, so `h3` now stands clearly below the 32px `h2`. The
brand book's components follow: a plain card or dialog title is an `h5`, a drawer title, an alert title and a
question title an `h4`. `--text-h6` is a retired token, so the house-style gate reports a use left behind.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions app that takes this release sees its headings change: an `h3` renders at 22px instead of
24px, and `--text-h4` and `--text-h5` keep their names but render one step smaller. An app moves each use one
level up in its own layer (`--text-h4` → `--text-h3`, then `--text-h5` → `--text-h4`, then `--text-h6` →
`--text-h5`); the table is in the house style's README.

**Score:** 4

#### Pull Request

Drop the 24px h3 and shift h4-h6 up one level, so h6 no longer exists

