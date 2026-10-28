## feat/specialists-card-under-plugins

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

Maikel, October 28, 2026: "verplaats de Specialists card naar de Plugins card", and then: the
Specialists and dkj-subagents are the same thing. Both opened one card per team, one to the plugin's
facts and one to its specialists and their context cost, so they become one: a team's own page under
`/plugins/dkj-subagents/<team>` shows its facts and then its specialists, and a specialist's page sits
under its team. `/specialists[/<team>[/<slug>]]` answers a 303 to the same page at its new address. A
visible result, so the branch waits for the owner's look before it merges.

### CREATE

- [x] `scripts/lib/dev-pages-lib.ps1`: Specialists out of `Get-ProductPages`;
  `Format-SpecialistsPageHtml` replaced by `Format-SpecialistTeamHtml` (the cards, the table and the
  column legend, drawn on a team's Plugins page); `Format-MarketplacePluginsPageHtml` takes the specialist
  rows, counts them on each team's card and serves a specialist's page; `Resolve-SpecialistsRedirect`
- [x] The specialists' card grid carries the house `.card-grid` beside its own `.sp-grid` columns, so
  it gets the group's padding and surface (`house-style.css:224`, `:230`) as `.grid-2` does; its
  heading moved inside it and the cards under it lost their h2 (#206)
- [x] `scripts/dashboard/serve-connector-dashboard.ps1`: the `/specialists` route becomes the redirect,
  and `/plugins` takes a third level and reads the specialists for the teams' pages only
- [x] `scripts/tests/dev-pages.tests.ps1` and `connector-dashboard.tests.ps1`: the Specialists asserts
  moved onto the team and specialist pages, plus the redirect

### TEST

- [x] `dev-pages.tests.ps1`: 478 passed, 0 failed; `connector-dashboard.tests.ps1`: 236 passed, 0 failed
- [x] `check-plugin-integrity.ps1`: 0 errors
- [x] The owner has looked at the product server's pages and said "ship it" (Maikel, October 28, 2026)

### DEPLOY: feat/specialists-card-under-plugins

The Specialists pages are merged into the specialist teams' Plugins pages: the product home page drops
its Specialists card, a team's card on `/plugins/dkj-subagents` counts its specialists and their full
read, a team's own page shows its facts and then its specialists with what each costs, and a
specialist's page sits under its team. An old `/specialists` address redirects to the same page at its
new one.

**Score:** 2

#### What makes this deploy extra special

N/A: the product's own dev pages, which no consumer takes.

**Score:** N/A

#### Pull Request

Merge the Specialists pages into the specialist teams' Plugins pages

