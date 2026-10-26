## fix/brandbook-shared-theme

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

The owner (October 26, 2026): the brand book is part of this repo's product, so it behaves like the other
product pages on the product port (`/connectors`, the root page). It had its own default theme (blue) and its own
storage key, so the theme changed on the way in and a pick made elsewhere did not carry over.

### CREATE

- [x] `brandbook/index.html`: `data-theme-default="lilac"` and `data-theme-key="general-pages"`, the root page's pair
- [x] `brandbook/root.html` and `brandbook/src/showcase/theme.ts`: the comments that said the app keeps its own theme

### TEST

- [x] `npx tsc -b --noEmit` in `brandbook/`: no errors
- [x] The owner's look at `http://localhost:5174/`: root page, brand book and `/connectors` keep one theme

### DEPLOY: fix/brandbook-shared-theme

The brand book now opens in the product's theme, lilac, and keeps whatever theme was picked on any other page of
the product port, because it stores the pick under the same `general-pages` key. A repo preview inside it still
opens in that repo's own default theme while no theme has been picked.

**Score:** 2

#### What makes this deploy extra special

N/A: the brand book is this repo's own dev preview; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

The brand book shares the product's theme: lilac by default, under the general-pages key

