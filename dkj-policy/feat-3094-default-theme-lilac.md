## feat/3094-default-theme-lilac

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

Adopt this repo's default theme `lilac` from the brand book (#3094, DKJ-Solutions/dkj-brandbook#198).
The vendored `house-theme.js` that reads `data-theme-default` already landed with the v0.3.0 repoint
(#3105), so what is left is the `<html>` attribute on the pages this repo renders itself. The shipped
`dev-preview-placeholder.ps1` keeps its pair: it renders in every consumer, and each repo has a default
of its own. A visible result, so the branch stops for the owner's look.

### CREATE

- [x] Replace `data-theme-light="teal" data-theme-dark="sky"` with `data-theme-default="lilac"` on the
  three `<html>` roots: `connector-dashboard-lib.ps1` (the dashboard) and `dev-pages-lib.ps1` (the
  dev pages and their shell)

### TEST

- [x] `connector-dashboard.tests.ps1` 126/0 and `dev-pages.tests.ps1` 49/0
- [x] The dev server on :4873 restarted from this branch serves `<html lang="en" data-theme-default="lilac" ...>`
- [ ] The owner has looked at the dashboard in `lilac`

### DEPLOY: feat/3094-default-theme-lilac

The dev server's pages (the connector dashboard, the repo hub and the pages it links) open in the
brand book's `lilac` theme, this repo's default, instead of following the OS between `teal` and `sky`.
A theme a viewer picked by hand still wins.

**Score:** 2

#### What makes this deploy extra special

N/A -- the dev server is this repo's own; nothing a plugin ships changes.

**Score:** N/A

#### Pull Request

