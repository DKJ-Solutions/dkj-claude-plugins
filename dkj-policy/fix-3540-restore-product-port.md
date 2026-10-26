## fix/3540-restore-product-port

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

Every repo has a product port (Maikel, October 26, 2026), and #3493 removed this repo's along with the brandbook
app. Decision on #3540: the same form as every consumer -- drop `OwnHub`, so the plugin's hub is this repo's hub,
and the connector dashboard server becomes the product with Connectors, Specialists and DKJ repos.

#### Visible result

The product's home page and the hub's Product card are judged by eye: this branch stops for the owner's look
before the merge.

### CREATE

- [x] `Get-DevPreview` states the connector dashboard as the repo's server, with no `OwnHub`
- [x] The server is the product: home page with a Hub card and the three pages; `/hub` sends to the plugin hub; the general pages, Repository, Test gate, Stopwatch, Logbook, Plugins and release notes are no longer relayed or built here
- [x] `dev-pages-lib.ps1`: `Get-ProductPages` and `Format-ProductHomeHtml` replace the own-hub functions; every page is tagged `product`
- [x] The hub README and Sylvester's lens say the source repo runs the plugin's hub now

### TEST

- [x] `dev-pages.tests.ps1` and `connector-dashboard.tests.ps1` rewritten for the product and green locally (335 and 213 asserts)

### DEPLOY: fix/3540-restore-product-port

This repo has a product port again ([#3540](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3540)):
its `Get-DevPreview` no longer opts out with `OwnHub`, so the session start hands out the dkj-policy plugin's hub,
as in every other repo, and the connector dashboard as the product beside it. The product's home page opens on a
card back to the hub, then Connectors, Specialists and DKJ repos; the general pages are the hub's alone. The
suite selection the old own hub showed on its Test gate went with it.

**Score:** 2

#### What makes this deploy extra special

N/A: this repo's own dev server; no plugin behaviour a consumer runs changes.

**Score:** N/A

#### Pull Request

This repo has a product port again: the plugin's hub, and the connector dashboard as the product
