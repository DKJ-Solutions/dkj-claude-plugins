## feat/lens-map-card

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

Maikel asked (October 28, 2026) for the map of what the specialist lenses hold in every repo that
runs the dkj plugins, as an overview card on the product's `/connectors` page.

### CREATE

Maikel then split it (the same day): no map on `/connectors`, but a page per DKJ repo, reached from
its card on `/connectors/dkj`, holding a **Lenses** card.

- [x] `Test-LensFilled`, `Format-DashboardBytes`, `Get-CheckoutLenses` and `Format-RepoLensesCardHtml` in `scripts/lib/connector-dashboard-lib.ps1`
- [x] The connector page frame moved into `Format-ConnectorPageStart`/`Format-ConnectorPageEnd`, which the repo page shares
- [x] `Get-DkjRepoRows`, `Format-DkjRepoCardHtml`, `Get-DkjRepoCardStyle` and `Format-DkjRepoPageHtml` in `scripts/lib/dev-pages-lib.ps1`; the DKJ repo cards' titles open the repo's page
- [x] The `/connectors/dkj/<name>` route in `serve-connector-dashboard.ps1`, a 404 for a name that is neither on GitHub nor checked out here
- [x] Maikel's remake of `/connectors/dkj` (the same day): `Format-DkjReposPageHtml`, a hub card per DKJ repo; `Format-DkjReposSectionHtml` and `Format-ConnectorDashboardHtml`'s `-Section*` parameters retired
- [x] A repo's mini-card is `Format-ConnectorRepoMiniCardHtml`, shared by a group's Issues card and the repo page's Connector card
- [ ] The owner has looked at `/connectors/dkj` and a repo's page (a visible result)

### TEST

- [x] `connector-dashboard.tests.ps1`: the filled-in rule, the lens reader on a fixture tree, the Lenses card's order and markup, the page frame (234 passed)
- [x] `dev-pages.tests.ps1`: the DKJ page's cards, the repo rows and the repo page's three cards (473 passed)

### DEPLOY: feat/lens-map-card

The product's `/connectors/dkj` is now a card per DKJ repo, in the hub's card form three to a row: its
GitHub facts, its checkout here and, where it is registered under `connectors/`, its status mark. Each
card opens a page of its own, `/connectors/dkj/<name>`, holding three cards:

- **Repo** -- its description, GitHub facts and link, its checkout's state and the session to copy;
- **Connector** -- what `check-connectors.ps1` reports for it, or that it is not registered;
- **Lenses** -- what its checkout's `.claude/specialists/lenses/` holds: the filled-in lenses a table, big
  to small, by id, specialist name and size, a filled-in lens still marked `VUL-IN` tagged, and the
  scaffolds one line under it. "Filled in" is read from the text (any line that is not frontmatter, a
  heading, a quote or a comment), because the `VUL-IN` marker turned out not to say it.

The DKJ page's Connected repos table, its On GitHub grid and its Issues card are gone: what each held per
repo is on that repo's page. The BWJ and Other pages are unchanged.

**Score:** 2

#### What makes this deploy extra special

N/A: a page of this repo's own dev server, which no consumer runs.

**Score:** N/A

#### Pull Request

A page per DKJ repo on /connectors/dkj, holding what its specialist lenses say

