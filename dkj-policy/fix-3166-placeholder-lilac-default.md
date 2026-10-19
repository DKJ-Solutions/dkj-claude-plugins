## fix/3166-placeholder-lilac-default

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

Issue #3166: `Format-DevPreviewPlaceholderHtml` wrote `<html>` with `data-theme-light="teal"
data-theme-dark="sky"` and no `data-theme-default`, so the dev-preview placeholder page fell back to
Petrol or Hemelsblauw where every sibling page falls back to Lila. Verified in the tree before the
repair; no reason for the difference is written in the file or its history (#3119, #3130), so it takes
the sibling default. The release-notes page, the other page on the pair, is repaired on its own branch
(#3162).

#### A visible result

The fallback theme is something the owner judges by eye, so the branch is parked for that look rather
than shipped.

### CREATE

- [x] `dev-preview-placeholder.ps1`: the placeholder page takes `data-theme-default="lilac"`
- [x] `dev-preview-sessionstart.tests.ps1`: an assert pins the new attribute

### TEST

- [x] `dev-preview-sessionstart.tests.ps1`: 179 passed, 0 failed

### DEPLOY: fix/3166-placeholder-lilac-default

With no theme chosen yet, the dev-preview placeholder page (the Repo hub a repo without a dev page of
its own gets) now opens in Lila, the same default as every other dev and general page, instead of
Petrol or Hemelsblauw depending on the OS mode (#3166).

**Score:** 2

#### What makes this deploy extra special

A consumer running the dkj-solutions dev-preview hook sees its placeholder page open in the same
default theme as its other pages. Cosmetic.

**Score:** 1

#### Pull Request

The dev-preview placeholder page falls back to lilac like every other dev page

