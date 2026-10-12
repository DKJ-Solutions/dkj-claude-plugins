## feat/house-style-spacing

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

Tokenize spacing only; every value stays exactly as tuned (no visual change). Stops for the owner's look before merge (visible result).

### CREATE

- [x] `house-style.css`: the Figma library's 40 spacing variables (`--spacing-0-5` … `--spacing-96`, read from the file's "Collection") in `:root`, names and values exact; every gap, margin and padding rewritten to the matching token, so each computed value is unchanged
- [x] Optical nudges (the sort arrow's 3px, the info button's 5px, hit-area insets, outline offsets) left literal and named as such in the scale's comment
- [x] `SKILL.md`: a Spacing row in the token table, naming the Figma library as the scale's source
- [x] Gwen's lens filled in: her domain here is the house style (first work for her in this repo)

### TEST

- [x] Grep for a px value left in any `padding`/`margin`/`gap`: only the two optical nudges remain
- [~] No automated visual comparison: no suite renders the stylesheet, and the arithmetic is exact by construction (each multiple is the source px divided by 4). The owner's look before the merge is the check

### DEPLOY: feat/house-style-spacing

The house stylesheet carries the Figma library's spacing scale in `:root`, the 40 tokens
`--spacing-0-5` (2px) to `--spacing-96` (384px) with Figma's own names and values, and every gap,
margin and padding in it now uses one of them. Nothing renders differently: each token equals the
hand-tuned pixel value it replaced. Gwen's repo lens is
filled in now that she has her first work here.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions app can space its own repo-layer components with `var(--spacing-N)`, the same names a
designer sees in Figma, and land on the same rhythm as the house components, without copying pixel values. Existing pages look exactly
the same.

**Score:** 2

#### Pull Request

House style: a --spacing base unit in :root, every gap, margin and padding a multiple of it

