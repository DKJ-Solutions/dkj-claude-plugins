## feat/connectors-group-pages

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

The owner asked (October 26, 2026) for three cards on the product's `/connectors` page -- DKJ, BWJ and Other --
each with a page of its own holding that group's connectors. A visible result, so the branch waits for the
owner's look before it ships.

### CREATE

- [x] `Format-ConnectorDashboardHtml -Group`: empty is the overview (tiles over every repo, one card per owner group
      in the hub's card form, its summary under the label); a group key is that group's page (three-crumb trail,
      its tiles, its overview table and its repo cards). Groups now ordered DKJ, BWJ, Other.
- [x] The hub serves `/connectors/dkj`, `/bwj` and `/other`, and `/refresh?page=` comes back to a group page.
- [x] The product's Vite relay (`brandbook/vite.config.ts`) passes the three group paths and their refresh on.

### TEST

- [x] `connector-dashboard.tests.ps1` rewritten for the overview and the group pages: 223 passed, 0 failed.
- [x] Owner feedback: the overview drops its tiles and its lead; a group page keeps both.
- [x] Owner feedback: each card's label -- DKJ, BWJ, Other -- is an h2, its summary under it.
- [x] Owner feedback: the group pages drop their tiles and lead too, so neither exists on any Connectors page now.
- [x] `eslint` and `tsc` clean on `brandbook/vite.config.ts`.
- [x] The owner has looked at `/connectors` and a group page on the product port ("ship it").

### DEPLOY: feat/connectors-group-pages

The product's Connectors page is now an overview of three cards, one per owner group -- DKJ, BWJ and Other, in that
order, each headed by an h2 and showing its repo count and status summary -- and each card opens a page of its own
at `/connectors/dkj`, `/connectors/bwj` or `/connectors/other` holding that group's overview table and repo cards.
No Connectors page carries tiles or a lead any more. The hub serves the new paths and the product's dev server
relays them; a group page's re-run comes back to that same page.

**Score:** 2

#### What makes this deploy extra special

N/A -- the Connectors page is this repo's own dev page; nothing a plugin ships changes.

**Score:** N/A

#### Pull Request

Connectors page: one card per owner group, each with its own page

