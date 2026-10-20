## fix/h1-takes-h0-size

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

Dave, October 20, 2026: the step from h1 (40px) to h2 (32px) is too small. Remove the `--text-h0`
token and give h1 the 48px h0 had. A visible result, so this branch stops for the owner's look
before any PR.

### CREATE

- [x] `house-style.css`: drop `--text-h0`, set `--text-h1` to 48px, move `.hero .value` to `--text-h1`, note the departure from the Figma scale in the comment
- [x] `assets/house-style/README.md`: the type row names `--text-h1` … `--text-h6` and 48/32/24/22/18/16, with the reason
- [x] `brandbook/`: every `--text-h0` use (hero value, step head, the token list, the doc comments) repointed to `--text-h1`

### TEST

- [x] No `--text-h0` left in the tree outside released history (`git grep`)
- [x] Owner's look at the brand book and a house-style page (Dave, October 20, 2026: "gezien en akkoord")

### DEPLOY: fix/h1-takes-h0-size

The house style's `h1` now renders at 48px instead of 40px, so it stands clearly above `h2` (32px).
The `--text-h0` token is gone: `h1` took its size, and the hero figure (`.hero .value`), which was the
one thing set at `h0`, is now set at `--text-h1`, so it looks exactly as before. The brand book follows.

**Score:** 2

#### What makes this deploy extra special

Every DKJ-Solutions page that takes the new copy shows a larger `h1`. A repo's own domain layer that
reads `var(--text-h0)` loses that size and must switch to `var(--text-h1)`.

**Score:** 3

#### Pull Request

Give h1 the display size and retire the h0 token

