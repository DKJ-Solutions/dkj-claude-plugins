## fix/3423-hub-release-notes-eyebrow

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

#3423 (inbound) asked to remove the eyebrow from the release-notes page TEMPLATE. Verified, the reason
holds only for the hub: the house rule is "no eyebrow under a site header, which already names the site",
and only the hub's copy has one (`Format-ReleaseNotesDevPage`). The template is also the page the
Cloudflare Worker serves, standalone and with no header, where the eyebrow is the one line naming whose
releases these are. So the eyebrow goes in the hub's dressing, under the site header, and the template
stays as it is.

### CREATE

- [x] `general-pages-lib.ps1`: `Format-ReleaseNotesDevPage` drops the masthead's eyebrow when it draws the
  site header
- [x] `dev-pages.tests.ps1`: no eyebrow under a site header; the eyebrow stays without one

### TEST

- [x] `dev-pages.tests.ps1`: 316 passed
- [ ] The owner's look at `/release-notes` from this branch's hub server

### DEPLOY: fix/3423-hub-release-notes-eyebrow

The hub's release-notes page now opens its masthead with the `Release notes` heading, with no product
name in small capitals above it: the site header above the page already names the repo, as on every other
hub page. The page a Cloudflare Worker serves keeps that line, because it has no header to name the
product.

**Score:** 2

#### What makes this deploy extra special

Nothing to do: the page is dressed on the way out, so the next hub session shows it.

**Score:** N/A

#### Pull Request

The hub's release-notes page drops the eyebrow under its site header

