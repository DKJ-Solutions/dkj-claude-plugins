## feat/consumers-card

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

The owner asked to rename the hub's Connectors card to Consumers: the repos it lists are the ones that
install plugins from this marketplace, so the word fits the marketplace beside it. Only the label
changes; the route `/connectors` and the `connectors/` register keep their names.

### CREATE

- [x] Card label and its line on the product home (`Get-ProductPages`), the overview's h1 and every breadcrumb back to it
- [x] The asserts in `connector-dashboard.tests.ps1` and `dev-pages.tests.ps1` follow the new name

### TEST

- [x] `connector-dashboard` (234 passed) and `dev-pages` (480 passed) green
- [ ] The owner has looked at the card on the running product hub

### DEPLOY: feat/consumers-card

The product hub's Connectors card, the page it opens and every breadcrumb back to it are now named
Consumers, the repos that install plugins from this marketplace. The route `/connectors` and the
`connectors/` register keep their names.

**Score:** 2

#### What makes this deploy extra special

N/A -- the product hub is the source repo's own maintainer page; no consumer runs it.

**Score:** N/A

#### Pull Request

The hub's Connectors card is named Consumers

