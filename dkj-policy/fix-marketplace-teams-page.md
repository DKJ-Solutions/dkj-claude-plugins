## fix/marketplace-teams-page

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

### CREATE

- [x] `Resolve-MarketplaceAddress` in `scripts/lib/dev-pages-lib.ps1`: a `/marketplace` address parsed into its levels, with `dkj-subagents` alone read as the teams' group page
- [x] `serve-connector-dashboard.ps1` routes through it instead of its inline regex
- [x] The teams' page groups its cards: `dkj-subagents-alpha` under an `Alpha` h2, the other teams under an `Extensions` h2, each card an h3 (Maikel, October 30, 2026)

### TEST

- [x] `dev-pages.tests.ps1`: an assert on every level of a `/marketplace` address, the bare `dkj-subagents` among them, and on the two sections and their order (510 passed)
- [x] The product server on :4870 restarted: `/marketplace/dkj-subagents` answers 200, Alpha over the core team, Extensions over the other three
- [x] The owner has looked at `/marketplace/dkj-subagents` and said ship it

### DEPLOY: fix/marketplace-teams-page

`/marketplace/dkj-subagents` is the specialist teams' page again, and it now groups them: the core team
alone under an **Alpha** heading, the other teams under **Extensions**. The move of dkj-policy's
add-ons onto its own page (in #3680, the same day) had made the server read that address as a plugin
called `dkj-subagents`, which does not exist, so it answered 404. The address is now parsed in one lib
function, `Resolve-MarketplaceAddress`, which a unit test holds to every level; the server's own fixture has
no teams, so its 404 assert could not tell the two readings apart.

**Score:** 3

#### What makes this deploy extra special

N/A: the product hub runs only in this repo's own checkout; no consumer serves it.

**Score:** N/A

#### Pull Request

/marketplace/dkj-subagents shows the specialist teams again instead of a 404

