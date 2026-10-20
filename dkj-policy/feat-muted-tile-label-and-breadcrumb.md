## feat/muted-tile-label-and-breadcrumb

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

### CREATE

- [x] `house-style.css`: `.tile .label` and `.breadcrumbs [aria-current='page']` from `--primary-12` to `--primary-7`; role comment and breadcrumb comment updated
- [x] Owner's second pass: breadcrumb links `--primary-9` to `--primary-7`, current page to `--primary-8`
- [x] Owner's third pass: the current page's weight 600 to 400
- [x] Owner's fourth pass: no underline on the breadcrumb links, hover included
- [x] Owner's fifth pass: a chevron SVG replaces the slash separator (the connector dashboard, the hub's general pages, the brand book's `Breadcrumbs`, their tests); the link underline shows on hover only
- [x] Brand book: `.dkj-breadcrumbs [aria-current='page']` and the showcase intro follow; house-style README's breadcrumb trail bullet names the colour

### TEST

- [x] No other copy pins either colour (grep over the tree)
- [x] `house-style` skill: the `house-style.css` sha256 repinned to the branch's final stylesheet
- [x] `connector-dashboard`, `dev-pages`, `dev-preview-sessionstart` suites green

### DEPLOY: feat/muted-tile-label-and-breadcrumb

A stat tile's label now takes the muted grey `--primary-7` (as `.muted`, sub lines and notes) instead of the
paragraph colour `--primary-12`, so the figure leads. The breadcrumb trail moves wholly into the muted greys: the
ancestor links `--primary-7`, underlined only under the pointer, instead of the underlined theme colour
`--primary-9`, the current page `--primary-8` at weight 400 instead of `--primary-12` semibold, and a chevron in
`--primary-6` instead of the slash between crumbs (owner, October 20, 2026). The pages this repo's dev servers
render (the connector dashboard and the hub's general pages) draw the chevron. The brand book's own
breadcrumbs follow.

**Score:** 2

#### What makes this deploy extra special

Every DKJ-Solutions page with stat tiles or a breadcrumb bar shows the labels and the current page in grey once
it takes the new house style; nothing to migrate.

**Score:** 2

#### Pull Request

Muted grey for the tile label and the breadcrumb's current page

