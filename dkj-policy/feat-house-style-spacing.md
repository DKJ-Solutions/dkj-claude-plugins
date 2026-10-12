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

Take the Figma library's spacing and type scales (Shopify Theme - LIBRARY, collection "Collection") into the house style, names and values exact. Stops for the owner's look before merge (visible result).

### CREATE

- [x] `house-style.css`: the Figma library's 40 spacing variables (`--spacing-0-5` … `--spacing-96`) in `:root`, names and values exact; every gap, margin and padding rewritten to the matching token, so each computed spacing is unchanged
- [x] Optical nudges (the sort arrow's 3px, the info button's 5px, hit-area insets, outline offsets) left literal and named as such in the scale's comment
- [x] `house-style.css`: the Figma library's 11 text variables (`--text-h0` … `--text-h6`, `--text-lg`, `--text-base`, `--text-sm`, `--text-xs`) in `:root`; every font size mapped onto them, `h1`–`h3` by level, 13px small text to `--text-sm` (both choices Maikel's)
- [x] `SKILL.md`: Spacing and Type rows in the token table, the Figma library named as the source, and each size that changed listed
- [x] Gwen's lens filled in: her domain here is the house style (first work for her in this repo)

### TEST

- [x] Grep for a px value left in any `padding`/`margin`/`gap`: only the two optical nudges remain
- [x] Grep for a px value left in any `font-size` or `font` shorthand: none; every `var(--text-*)` used is defined
- [~] No automated visual comparison: no suite renders the stylesheet. The owner's look before the merge is the check

### DEPLOY: feat/house-style-spacing

The house stylesheet carries the Figma library's spacing and type scales in `:root`, with Figma's own
names and values: 40 spacing tokens, `--spacing-0-5` (2px) to `--spacing-96` (384px), and 11 text
tokens, `--text-h0` (48px) to `--text-xs` (11px). Every gap, margin, padding and font size in it now
uses one of them. Spacing renders exactly as before. Type does not: body text 15 → 14px, `h2` 29 → 32,
`h3` 18 → 24, the 13px small text → 12, a mini-card value 20 → 18. Gwen's repo lens is filled in now
that she has her first work here.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions app picks up the Figma type scale at its next plugin update. Body and small text
get a little smaller, and the `h2` and `h3` headings bigger. An app's own components can space and
size themselves with `var(--spacing-N)` and `var(--text-*)`, the same names a designer sees in Figma.

**Score:** 3

#### Pull Request

House style: the Figma library's spacing and type scales in :root
