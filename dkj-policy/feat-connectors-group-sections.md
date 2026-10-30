## feat/connectors-group-sections

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

Maikel, October 30, 2026: on `/connectors`, three h2 headers for DKJ, BWJ and Other, and the cards moved
one level up with an h3 each. Read as: the repo cards from the group pages move up under their group's h2.

### CREATE

- [x] `Format-DkjRepoCardsHtml` (`scripts/lib/dev-pages-lib.ps1`): the DKJ repo cards on their own, with a
  heading level, shared by the DKJ group page (h2) and the overview (h3)
- [x] `Format-ConnectorDashboardHtml` overview: a section per group, its h2 head with summary and a link to
  the group page; DKJ holds its own cards, BWJ and Other a card per registered repo opening its details
- [x] The server hands the overview the DKJ cards, their style and any GitHub read warning
- [x] The url follows the h1: the Consumers pages move from `/connectors` to `/consumers`, an old address answered with a 303
- [x] The group h2 stands alone, with no sub line or button under it (Maikel)
- [x] The DKJ cards' smaller title is scoped to their h2, so an h3 card keeps the house `--text-h3`

### TEST

- [x] `connector-dashboard.tests.ps1` and `dev-pages.tests.ps1` green, the overview's asserts rewritten
- [ ] The owner's look at `http://localhost:4870/consumers`

### DEPLOY: feat/connectors-group-sections

The Consumers page is now three sections, DKJ, BWJ and Other, each under an h2 of its own. Under each sit that group's repo cards, one level up from where they
were and an h3 each: every DKJ repo's card, as on the DKJ page, and a card per registered BWJ and Other repo
that opens its details on the group's page. The pages moved from `/connectors` to `/consumers`, so the url matches their h1 Consumers; an old
address lands on its new page.

**Score:** 2

#### What makes this deploy extra special

N/A -- a page of this repo's own dev server, which no consumer runs.

**Score:** N/A

#### Pull Request

The Consumers page shows each owner group as a section with its repos' cards

