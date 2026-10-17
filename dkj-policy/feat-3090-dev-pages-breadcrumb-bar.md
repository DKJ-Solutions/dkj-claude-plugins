## feat/3090-dev-pages-breadcrumb-bar

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

#### A visible result -- parked for the owner's look

Both pages render differently, so this branch stops before a pull request (issue #3090 says so). The
markup follows the brand book's `patterns/repo-dashboard.html` at `v0.2.0` block 0 verbatim.

### CREATE

- [x] The connector dashboard (`scripts/lib/connector-dashboard-lib.ps1`) opens `<body>` with the breadcrumb bar
- [x] The placeholder Repo dashboard (`dev-preview-placeholder.ps1`) does the same
- [x] Each suite asserts the bar is the first element in `<body>`, with the one crumb `Repo dashboard`

### TEST

- [x] `connector-dashboard.tests.ps1`: 120 passed, 0 failed
- [x] `dev-preview-sessionstart.tests.ps1`: 105 passed, 0 failed

### DEPLOY: feat/3090-dev-pages-breadcrumb-bar

The placeholder Repo dashboard the `dkj-solutions` plugin serves, in every repo without a dev preview of
its own, now opens with the house breadcrumb bar: one crumb, **Repo dashboard**, sticky at the top
([#3090](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3090)). It follows the rule the
brand book's `v0.2.0` sets for every page a dev server serves. Nothing in a repo's own layer changes.

**Score:** 1

#### What makes this deploy extra special

This repo's own connector dashboard carries the same bar, so both dev-server pages here now take the
Repo dashboard form block for block.

**Score:** 1

#### Pull Request

Dev-server pages here carry the house breadcrumb bar

