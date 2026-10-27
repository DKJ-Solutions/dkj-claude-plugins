## feat/hub-to-toolbox

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

Maikel, October 27, 2026: rename Hub to Toolbox, and on the toolbox's port rename Home to Tools. Only
what is seen changes; the code, the `/hub` route and the `OwnHub` key keep the word hub, because a
consumer's `Get-DevPreview` states `OwnHub` and renaming it would break that repo.

### CREATE

- [x] The session-start line opens with `Toolbox:` (`$script:DevPreviewLabel`)
- [x] The site header tags the repo's name `toolbox`, and the first crumb on every toolbox page reads Tools (`-HomeLabel`, default `Tools`)
- [x] The product keeps Home for its own pages (`-HomeLabel 'Home'`) and links the toolbox on a Toolbox card
- [x] The toolbox's own prose (Repository facts, setup cards, footers, banner title) says toolbox
- [x] The hub README and the house-style README say what the screen calls it

### TEST

- [x] dev-pages, dev-preview-sessionstart and connector-dashboard green locally; one layer assert re-anchored past the new Tools crumb
- [x] The owner looks at the toolbox and the product in the browser (visible result): Maikel approved, October 27, 2026

### DEPLOY: feat/hub-to-toolbox

The hub is called Toolbox on screen: the session-start line opens with `Toolbox:`, the site header
tags the repo's name `toolbox`, and the first crumb on every toolbox page reads Tools instead of Home.
A product's own pages keep Home. The code, the `/hub` route and the `OwnHub` key are unchanged.

**Score:** 2

#### What makes this deploy extra special

Every user of the plugin sees the hub under its new name, Toolbox, with Tools as its first crumb;
nothing has to be done to take it.

**Score:** 2

#### Pull Request

The hub is called Toolbox, and its Home crumb Tools

