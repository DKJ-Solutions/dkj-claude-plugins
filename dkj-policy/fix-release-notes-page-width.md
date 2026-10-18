## fix/release-notes-page-width

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

The settings panel's width (house style v0.4.0, #3115) is written as `<html data-width>` and applied by
`house-style.css` to `main` and `.container` only. The release-notes template's column is a
`<div class="wrap">` with a fixed `max-width: 52rem`, so the setting never reached it: only the breadcrumb
bar followed the choice. Repaired in the shared template, so every repo whose page runs the house theme
script gets it at once, and a page without that script is unchanged.

### CREATE

- [x] `release-notes-page-template.html`: `.wrap` answers `data-width="phone"` (360px) and `"full"` (no maximum); fluid stays the template's own 52rem column
- [x] Plugin mirror refreshed with `build-shared-scripts.ps1`

### TEST

- [x] `dev-pages.tests.ps1` pins the two width rules in the template (108 passed); `release-notes-page.tests.ps1` 175 passed
- [x] The visible result was reported for the owner's look at `/release-notes`; the owner gave the explicit PR command ("open de pr")

### DEPLOY: fix/release-notes-page-width

The release-notes template's column now follows the page width a reader picks in the house settings
panel: Phone narrows it to 360px and Full lifts its maximum, where it used to stay at 52rem whatever was
picked while only the breadcrumb bar moved. Fluid keeps the template's own reading column. The rules key
off the attribute the house theme script sets, so a page without that script, a Worker-served one
included, renders exactly as before.

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions repo that serves its release notes with the house theme script gets a width setting that
actually applies to the notes, after its next plugin update and page rebuild.

**Score:** 2

#### Pull Request

The release-notes page follows the house page-width setting

