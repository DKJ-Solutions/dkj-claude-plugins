## feat/3493-house-style-components

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

Point 2 of #3493: the brandbook app's component CSS moves into the house style. Owner's choice (issue
comment, 2026-10-26): only the families the house style lacks, renamed to the house convention; the
duplicates of house classes are dropped. The `brandbook/` app itself stays untouched here and is removed
in a later branch, together with points 3 and 4.

A house-style change is a visible result, so this branch stops for the owner's look instead of merging.

### CREATE

- [x] Gwen: the missing component families appended to `house-style.css`, their tokens added or mapped
  onto existing house tokens (67 KB to 108 KB). The generic `.warn` tone helper she ported was taken out
  again: MesoWise and the ETF tracker both style a `.warn` of their own
- [x] Gwen: the README's reserved-name list and a section on the new group, with the measured collisions
- [x] The house-style skill's sha256 for `house-style.css` updated
- [x] `Get-HouseStyleAllowlist`: the app's own `prose.css`/`tables.css` set `--prose-h1..3` and `--gutter`,
  now house tokens; four entries until the app is removed

### TEST

- [x] `house-style-css` gate (syntax, `var()` definitions, colour literals) green
- [x] `check-house-style` (81/81) and `house-palette` (128/128) suites green
- [x] Edith: copy edit of the README diff; the MesoWise section's "the chips stayed in the app" and five
  missing reserved names repaired
- [x] Specimen page for the owner's look (scratchpad, not in the tree; a hub specimen page is point 3)

### DEPLOY: feat/3493-house-style-components

The house style gains the components that until now existed only in this repo's brandbook app, the first
step of retiring it ([#3493](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3493)). The CSS
gate, the checksum and an allowlist entry for the app's own copies moved with it.

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions app that takes the next copy of `house-style.css` gets alerts, banners, panels, chips,
tags, filter chips, steppers, a search combobox, value boxes, stat rows, bill/compare/calc tables, date
rows, figures and prose as house classes. An app that already styles a class of the same name (MesoWise:
`.chip`, `.help`, `.amount`, `.calc`, `.verdict`, `.question-head`) now collides with the house name, and
its `check-house-style` gate says so: it renames its class or adopts the house one.

**Score:** 4

#### Pull Request

House style: the brandbook app's missing components move into house-style.css

