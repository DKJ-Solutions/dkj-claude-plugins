## feat/3119-general-pages-from-dkj-solutions

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

Issue #3119: the four general Repo hub pages (Artifacts, Issues, Release notes, SessionStart) lived only in
this repo's dev server, so no other DKJ-Solutions repo could have them. The owner chose option 1 on the issue
(maikel-bwj, October 18, 2026): the `dkj-solutions` plugin ships its own small PowerShell server for them, the
dev-preview hook starts it beside the repo's own server, and each repo's hub links to it.

### CREATE

- [x] `general-pages-lib.ps1` (plugin): the four pages' renderers, moved out of `scripts/lib/dev-pages-lib.ps1`
  and parameterised by repo name; the shared General card; issue links from gh's own `url`
- [x] `serve-general-pages.ps1` (plugin): loopback server on 4890-4899 with `/artifacts`, `/issues`,
  `/release-notes`, `/sessionstart`, `/refresh`, `/hub` (back to the repo's hub) and `/whoami` (its identity)
- [x] The dev-preview hook starts or reuses it beside the repo's server, from one listener snapshot, and writes
  the per-checkout state file `%TEMP%\dkj-repo-hub-<leaf>-<hash>.json` (`root`, `hub`, `pages`), removing a
  stale one on its early exits
- [x] This repo's hub and the placeholder hub read the state file, verify the pages server through `/whoami`
  and render the General card; this repo's server 303s the four old paths there
- [x] `loopback-server-lib.ps1` (plugin): one request reader and response writer for both plugin servers, and one
  cross-site rule for all three servers: same-site is allowed for a top-level GET navigation only
- [x] Review (Victor, Sebastian, Edith): applied the identity check, the shared snapshot, the stale-state removal,
  the bounded `/sessionstart` measurement, the 4890-4899 constraint, the same-site navigation fix (the hub's own
  link would have been refused) and the README and lens wording
- [x] Filed out of scope: #3127 (the plugin descriptions still say a repo without `Get-DevPreview` pays nothing)

### TEST

- [x] `dev-pages.tests.ps1` 167, `dev-preview-sessionstart.tests.ps1` 173, `connector-dashboard.tests.ps1` 155,
  `native-capture.tests.ps1` 355, all passing; browser-shaped Sec-Fetch headers asserted for the hub click and
  the 303 hop
- [x] `check-plugin-integrity.ps1` 0 errors, `check-house-style.ps1` OK
- [x] Hand smoke test of every route, from this repo and from a scratch consumer in both source and cache layouts

### DEPLOY: feat/3119-general-pages-from-dkj-solutions

This repo's Repo hub lists only its own pages (Connectors, Test gate) under **This repo**. Its **General** card
now links Artifacts, Issues, Release notes and SessionStart on the `dkj-solutions` plugin's own pages server,
on a port from 4890 to 4899, and the old paths on this repo's server redirect there.

**Score:** 2

#### What makes this deploy extra special

Every DKJ-Solutions repo with `dkj-solutions` enabled gets four pages at session start that until now only
this repo had: its GitHub issues and where they stand, its release notes, what a session loads before its
first turn, and its published Artifacts. The dev-preview hook starts the plugin's pages server beside the
repo's own preview (the placeholder included), and the placeholder hub links them. A repo's own hub links them
by reading the per-checkout state file the README describes. A page whose data the repo lacks says so instead
of failing.

**Score:** 3

#### Pull Request

dkj-solutions serves the general Repo hub pages to every DKJ-Solutions repo


