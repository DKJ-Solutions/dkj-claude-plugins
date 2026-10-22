## fix/3303-page-column-padding

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

Issue #3303: `.page-column` takes the padding `var(--spacing-4) var(--spacing-4) var(--spacing-12)`.
It sits on `<main>`, whose own padding is `--spacing-6` on top. The class outranks the element, so the
page column now starts `--spacing-4` under the header. Sides and bottom are as before.

#### Merging after #3302

#3302's branch moves the same sha256 pin in the `house-style` skill. Whichever of the two merges second
takes the trunk in and pins the hash of the stylesheet as it stands after the merge.

### CREATE

- [x] `.page-column` takes the padding `var(--spacing-4) var(--spacing-4) var(--spacing-12)` in
  `house-style.css`
- [x] Move the `house-style` skill's sha256 pin for `house-style.css` to the new file

### TEST

- [~] `open-pr.ps1 -GatesOnly` before the park: dropped at the owner's word. The ship after the review
  runs open-pr's gate and the required CI check on this same branch (#3304)
- [ ] The owner looks at a page with a page column in the hub (awaiting-review-dev)

### DEPLOY: fix/3303-page-column-padding

The house style's page column (`.page-column`) sits closer under the header: it takes its own padding
of `--spacing-4` on top, sides `--spacing-4` and `--spacing-12` at the bottom, where `<main>` gave it
`--spacing-6` on top (#3303).

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions app that takes the new `house-style.css` gets the tighter top on every page built on
`.page-column` without changing anything of its own.

**Score:** 2

#### Pull Request

The page column sits closer under the header: .page-column takes its own padding

