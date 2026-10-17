## feat/3097-dev-server-pages

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

#3097 asks for a hub on `/` linking four pages. Two of its dependencies, DKJ-Solutions/dkj-brandbook#199
(the name "Repo hub") and #200 (the house block linking a repo's own pages), closed after the brand
book's v0.2.0 and are not released, so the hub itself waits. The issue names what does not wait: the
connector overview on its own route and the two measurement pages. This branch builds those; `/` keeps
the connector overview until the hub lands, so nothing a reader has today goes away.

#### What to look at

`http://localhost:4872/connectors`, `/sessionstart` and `/test-gate`, in both themes.

### CREATE

- [x] `scripts/lib/dev-pages-lib.ps1`: one page shell (breadcrumb bar, settings, intro, footer note) and
  the SessionStart and test-gate pages
- [x] `Format-ConnectorDashboardHtml -SubPage`: the overview as the Connectors page, two crumbs
- [x] The server: `/connectors`, `/sessionstart` (measured in a child process, cached like the overview),
  `/test-gate` (read per request), and `/refresh?page=` back to a page from a fixed list
- [x] `scripts/tests/dev-pages.tests.ps1`, and the new routes in `connector-dashboard.tests.ps1`

### TEST

- [x] `dev-pages.tests.ps1`: 39 passed, 0 failed
- [x] `connector-dashboard.tests.ps1`: 125 passed, 0 failed
- [x] `check-house-style.ps1`: OK at v0.2.0
- [x] All four routes served from the branch on port 4872; the SessionStart figures match what
  `always-on-sessioncheck` printed at session start (58,895 B, budget 100,000 B)

### DEPLOY: feat/3097-dev-server-pages

This repo's dev server has three pages under the Repo dashboard: **Connectors** (`/connectors`, the
connector overview `/` shows), **SessionStart** (`/sessionstart`, the always-on document path every
session loads, per document, against its budget) and **Test gate** (`/test-gate`, the per-suite CI
durations from `scripts/tests/suite-durations.json`, and the suites not recorded yet). The hub that
links them from `/` follows once the brand book releases its index block
([#3097](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3097)).

**Score:** 3

#### What makes this deploy extra special

N/A -- the dev server is this repo's own; nothing a plugin ships changes.

**Score:** N/A

#### Pull Request

Dev server: the connector overview at /connectors, and pages for the SessionStart and test-gate measurements

