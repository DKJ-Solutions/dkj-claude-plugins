## feat/3356-hub-banner-everywhere

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

The owner wants the hub's general banner on every hub page, without exception (#3356). Measured on the running
hub: every route carried it except `/stopwatch` (and its label pages), bare since #3323, and `/connectors`, whose
own page shell #3297 never reached.

### CREATE

- [x] `-Bare` on `Format-GeneralPageHtml` leaves out the h1 and the lead only; the banner stays (docstrings in
  `general-pages-lib.ps1`, `dev-pages-lib.ps1`, `stopwatch-lib.ps1` follow)
- [x] the Connectors page writes the banner under its intro

### TEST

- [x] `stopwatch.tests.ps1`: the two asserts that pinned the banner's absence now pin it once, above the heading
- [x] `connector-dashboard.tests.ps1`: the banner is on the page once, between the h1 and the tiles
- [x] stopwatch, connector-dashboard, dev-pages and dev-preview-sessionstart suites green

### DEPLOY: feat/3356-hub-banner-everywhere

The hub's airsquats banner is now on every hub page: the Stopwatch overview and its label pages keep their bare
layout (no h1 or lead) but open on the banner, and the Connectors page carries it under its intro. `-Bare` on
`Format-GeneralPageHtml` now leaves out the intro only.

**Score:** 2

#### What makes this deploy extra special

The hub is this repo's own dev server; a consumer's hub pages that pass `-Bare` (none do today) would gain the
banner too.

**Score:** N/A

#### Pull Request

The hub banner shows on every hub page, the Stopwatch and Connectors included

