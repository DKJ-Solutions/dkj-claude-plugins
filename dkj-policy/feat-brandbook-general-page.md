## feat/brandbook-general-page

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

The owner (October 20, 2026): the Brandbook sat in the hub's "This repo" card, but the house style is every
DKJ-Solutions repo's. Mid-turn they refined it: "General" is for every repo, BWJ and djcylow included, so a
third card, DKJ-Solutions, holds what only the DKJ-Solutions repos share.

### CREATE

- [x] Move `ConvertFrom-HouseStyleAssets` and `Format-BrandbookPageHtml` from `scripts/lib/dev-pages-lib.ps1` into the plugin's `general-pages-lib.ps1`, with the repo's name and the source folder as parameters
- [x] `Get-DkjSolutionsPages` and `Format-DkjSolutionsPagesCardHtml`: the third card, the same card as General with other rows, heading and sub line
- [x] The general server answers `/brandbook` from its own plugin copy; this repo's server keeps answering it from the tree
- [x] The source repo's hub and the placeholder hub draw the DKJ-Solutions card after General; the Brandbook leaves "This repo"
- [x] The plugin README, the house-style README (block 7) and the allowlist entry follow

### TEST

- [x] `dev-pages.tests.ps1`, `dev-preview-sessionstart.tests.ps1` (the general server serves `/brandbook`), `connector-dashboard.tests.ps1` green
- [x] `check-plugin-integrity.ps1` and `check-house-style.ps1` green

### DEPLOY: feat/brandbook-general-page

The Brandbook page moves out of this repo's own server into the dkj-solutions plugin's general pages server,
and the Repo hub gets a third card for it, **DKJ-Solutions**, after **This repo** and **General**. General
keeps the pages every repo has; DKJ-Solutions holds what only the DKJ-Solutions repos share, the house style
first. This repo's hub still answers `/brandbook` itself, from the tree, so a house-style change is seen here
before it is released.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions repo's Repo hub gets the Brandbook, the house style's themes, tokens and components, in a
new DKJ-Solutions card, where until now only this repo had the page.

**Score:** 3

#### Pull Request

The Repo hub gets a DKJ-Solutions card, and the Brandbook moves into it
