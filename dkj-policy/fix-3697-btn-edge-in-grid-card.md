## fix/3697-btn-edge-in-grid-card

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

Inbound from `dkj-music-library` (#3697). Verified against the stylesheet: inside a `.grid-2`, `.grid-3` or
`.card-grid`, a direct `.card` stands on `--paper-3` and every child reads `--paper-3` as `--paper-4`, so a plain
`.btn`'s border is the card's own edge colour, one paper step from its ground, with no step beyond it. The fix is
scoped to that one place, so a plain `.btn` everywhere else keeps its `--paper-3` edge.

### CREATE

- [x] `house-style.css`: a plain `.btn` (not `.btn--primary`) on a card inside a grid takes `--muted` as its border,
  and keeps it on hover (the rule outweighs `.btn:hover`)
- [x] The header's list of where `--muted` reaches names the new use

### TEST

- [x] The owner looked at a plain `.btn` beside a `.btn--primary` on a grid card, light and dark, and approved it
  (Dave, October 30, 2026)

### DEPLOY: fix/3697-btn-edge-in-grid-card

A plain `.btn` on a card inside a `.grid-2`, `.grid-3` or `.card-grid` now draws its edge in `--muted`, so it
stays visible beside a `.btn--primary` in every theme
([#3697](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3697)). Before, its border was the card's own
edge colour, one paper step from the card, and on a dark theme it barely showed. A repo that worked around this
with a class of its own can drop that class once it takes this version.

**Score:** 2 -- a button edge that was hard to see, noticed when somebody points at it.

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

A plain .btn on a card inside a grid keeps a visible edge

