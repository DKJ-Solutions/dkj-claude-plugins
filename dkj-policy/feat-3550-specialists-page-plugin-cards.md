## feat/3550-specialists-page-plugin-cards

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

#### Settled while doing it (#3550)

- **Two levels** (the owner, after a first look: the cards must link to a deeper page). `/specialists` is
  the tiles plus one link card per plugin, three to a row in the hub's card form (as `/connectors` does its
  owner groups); `/specialists/<plugin>` is that plugin's page, with its specialists' table.
- **What a card shows:** the plugin's short name as an h2, then core team or add-on team, enabled or off
  here, its specialist count, its summed listing and full read.
- **Plugins not enabled here get a card too**, muted rather than hidden; their page says what being off
  means here: no session carries its listing, and it has no lens.
- **Order:** the core team first, then add-on teams enabled here, then the off ones, by name.
- **The overview is the cards and nothing else** (the owner, on the second look): no tiles, no lead, no
  heading over the grid, and no "When each part loads", which stays on the plugin pages under their table.
- **URL scheme:** `/specialists/<short>`, the plugin name without `dkj-subagents-`; an unknown one is a 404.

### CREATE

- [x] `Format-SpecialistsPageHtml` in `scripts/lib/dev-pages-lib.ps1`: the overview of plugin cards and a
  `-Plugin` detail page, with `Get-SpecialistPlugins` for the grouping and order.
- [x] `scripts/dashboard/serve-connector-dashboard.ps1`: the `/specialists/<plugin>` route.

### TEST

- [x] `scripts/tests/dev-pages.tests.ps1`: the overview's cards, links, order and off state, and the
  detail page's trail, table and 404 case (370 passed, 0 failed, run alone before the park).
- [ ] The owner's look at `http://localhost:4870/specialists` on this branch.

### DEPLOY: feat/3550-specialists-page-plugin-cards

The product's Specialists page shows one card per specialist plugin
([#3550](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3550)), the core team first, each with
its specialist count, its total context cost and whether it is enabled here. Each card links to that
plugin's own page, `/specialists/<plugin>`, with its specialists and what each one costs. A plugin that is
not enabled here still gets a card, muted, and its page says no session here carries its listing.

**Score:** 2

#### What makes this deploy extra special

N/A: this repo's own product pages; nothing a consumer runs changes.

**Score:** N/A

#### Pull Request

Specialists page: one card per specialist plugin

