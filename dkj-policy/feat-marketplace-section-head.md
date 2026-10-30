## feat/marketplace-section-head

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

The owner asked for a `dkj-marketplace` h2 above the Marketplace grid with the cards under it as h3s, and
mid-turn added that a page's url always matches its h1 -- so `/plugins` becomes `/marketplace`.

### CREATE

- [x] `Format-MarketplacePluginsPageHtml`: a `.grid__head` with the h2 `dkj-marketplace` opens the overview's grid, its cards' labels h3s
- [x] The product's Marketplace pages move from `/plugins` to `/marketplace` (cards, trails, the home card, the Specialists redirect)
- [x] `Resolve-MarketplaceRedirect`: an old `/plugins` address answers a 303 to the same level under `/marketplace`
- [x] dkj-policy's add-ons (bwj-development, dkj-solutions) leave the overview for an Add-ons section at the top of dkj-policy's page, each at `/marketplace/dkj-policy/<name>`; `Resolve-MarketplaceAddOnRedirect` sends the old top-level address there

### TEST

- [x] `dev-pages.tests.ps1` (500 passed) and `connector-dashboard.tests.ps1` (235 passed), the redirect asserted end to end
- [x] Product server on 4870 restarted: `/marketplace` shows the h2 over two h3 cards, `/marketplace/dkj-policy` its two add-ons, the old addresses answer 303

### DEPLOY: feat/marketplace-section-head

The product's Marketplace overview opens its card grid with an h2 naming the marketplace, `dkj-marketplace`,
and its cards carry h3 titles under it. dkj-policy's two add-ons, bwj-development and dkj-solutions, moved
off the overview into an Add-ons section at the top of dkj-policy's own page, each at `/marketplace/dkj-policy/<name>`. The Marketplace pages moved from `/plugins` to `/marketplace`,
so a page's url matches its h1; every old `/plugins` address answers a 303 to the same page under
`/marketplace`, and the old Specialists addresses now land there directly.

**Score:** 2

#### What makes this deploy extra special

The product's local dev pages are this repo's own; nobody who takes a release sees them.

**Score:** N/A

#### Pull Request

The Marketplace page moves to /marketplace and groups its cards under a dkj-marketplace heading

