## fix/release-notes-served-from-tree

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

The hub banner on `/release-notes` stood in the wrong place although `main` already had the fix: the hub
relayed that page to the general pages server, which runs from the installed plugin (v5.30.0). The owner
wants the release notes, which are this repo's own, to follow this tree without a cut (October 25, 2026).

### CREATE

- [x] `serve-connector-dashboard.ps1` builds and serves `/release-notes` itself, from this tree's builder and `Format-ReleaseNotesDevPage`; it is no longer one of the relayed routes

### TEST

- [x] `connector-dashboard.tests.ps1`: the route answers here with and without a page on disk, the banner stands above the site header, and the HEAD relay assert moved to `/artifacts` (212 passed)
- [x] Checked by hand on `:4873`: the banner is the first thing in `<body>`, as on `/stopwatch`; a removed page, and a touched builder, rebuild the page on request
- [x] Victor's review: nothing blocking; his point that a builder or template change did not rebuild the page is repaired

### DEPLOY: fix/release-notes-served-from-tree

**This repo's hub builds the release-notes page from its own tree.** `/release-notes` on the hub was relayed
to the general pages server, which runs from the installed plugin, so a change to that page showed here only
after a release. The hub now builds and dresses the page with this tree's `build-release-notes-page.ps1` and
`Format-ReleaseNotesDevPage`, and rebuilds it when a release document, the builder or its template changed.
The hub banner stands above the site header there, as on every other hub page. Artifacts, Issues and SessionStart are still relayed.

**Score:** 2

#### What makes this deploy extra special

N/A: only this repo's own hub changes; consumers' hubs keep serving the page from the plugin.

**Score:** N/A

#### Pull Request

the hub builds /release-notes from this tree, not from the installed plugin

