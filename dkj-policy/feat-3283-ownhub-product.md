## feat/3283-ownhub-product

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

Maikel wants two links at session start: one for the repo's product, one for the repo itself (October
22, 2026). Since #3245 a repo without `OwnHub` already gets both; this branch gives the `OwnHub` shape
a product too, and states the brand book as this repo's product.

### CREATE

- [x] `ConvertTo-DevPreviewConfig`: a nested `Product`, only with `OwnHub = $true`, held to the server's rules, its ports clear of the hub's
- [x] The hook: starts or reuses the product beside the own hub, waits for both in one loop, prints both, and writes the product into the state file
- [x] This repo's `Get-DevPreview`: the brand book's Vite dev server as the product
- [x] The hub README and the hook's header: the new seam field and the new line

### TEST

- [x] `dev-preview-sessionstart.tests.ps1`: the seam's new rules, and the hook end to end with an own hub plus a product, reused, and with a product that cannot start (308 passed)

### DEPLOY: feat/3283-ownhub-product

A repo that serves its own Repo hub (`OwnHub = $true` in `Get-DevPreview`) can now also state a
product beside it, as a nested `Product = @{ Command; Ports; Path; Requires; WaitSeconds }` (#3283).
The dev-preview hook starts or reuses both and hands out both links on its one line:
`Repo hub: http://localhost:4870/ (started) -- product: http://localhost:5173/brandbook/ (started)`.
A product that cannot start is named beside the hub's link and costs nothing else. A `Product` without
`OwnHub`, or one whose ports overlap the hub's, is refused with the reason. This repo now states the
brand book's Vite dev server as its product, next to the connector dashboard.

**Score:** 3

#### What makes this deploy extra special

A repo that runs its own hub no longer has to choose between that hub and a link to its product at
session start: one `Product` block in `scripts/repo-config.ps1` adds the second link.

**Score:** 3

#### Pull Request

Repo hub: a repo with OwnHub can state a product beside it

