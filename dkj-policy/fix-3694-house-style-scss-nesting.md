## fix/3694-house-style-scss-nesting

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

Inbound #3694, verified on the tree: `Find-HouseStyleClassHit` reads the text between the previous
`{`/`}`/`;` and a `{` as the whole selector, so a house class nested inside a domain rule reads app-wide.

### CREATE

- [x] `Find-HouseStyleClassHit -Nesting`: walks the braces with a stack (comments blanked), so a rule
      nested in a rule whose every selector names a domain class is composition; `Invoke-HouseStyleCheck`
      passes it for `.css`, `.scss`, `.less` and `.pcss`
- [x] The house-style skill's check 2 says nesting counts as composition
- [x] Nine asserts in `check-house-style.tests.ps1`, the measured SCSS shape among them
- [x] Review (Victor): SCSS `@at-root` lifted a nested house rule out of its scope and hid it; it is now
      read unscoped, with three asserts. Interpolated selectors (`.a-#{$n}`) stay a false positive, as
      before this branch: filed as #3698

### TEST

- [x] `check-house-style.tests.ps1`: 115 passed, 0 failed; this repo passes its own gate

### DEPLOY: fix/3694-house-style-scss-nesting

`check-house-style` now reads a nested rule in a `.css`, `.scss`, `.less` or `.pcss` file together with
the rules around it ([#3694](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3694)). A house
class nested inside a rule of the repo's own (a `.menu-item` rule inside `.thumb-card`) is composition,
as it already was written out flat, and no longer a `[redefine]` finding; nested only inside an element
or an at-rule it still is. The skill page says so under check 2.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo that writes its styles in SCSS no longer has to flatten its nested house-class
compositions, or allowlist them, to pass the house-style gate: the gate and the skill's own rule now
agree.

**Score:** 3

#### Pull Request

check-house-style reads a nested SCSS selector as an app-wide redefinition of a house class

