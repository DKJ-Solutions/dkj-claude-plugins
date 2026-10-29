## feat/plugins-cards-installed-vs-marketplace

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

The toolbox and the product port each had a card called Plugins, with the same plug icon, while one
shows what this checkout installs and the other what the marketplace offers. Agreed with the owner
(October 29, 2026): Installed plugins on the toolbox, Marketplace on the product port, and Connectors
off the shared plug too. A visible result: parked for the owner's look, not merged.

### CREATE

- [x] Toolbox card, page title and crumbs read Installed plugins; the icon is a plug in its socket
- [x] Product card, page title and crumbs read Marketplace; the icon is a storefront
- [x] Connectors draws a chain link instead of a second plug

### TEST

- [x] dev-pages, connector-dashboard and dev-preview-sessionstart suites green, with an assert that the three icons differ
- [x] The owner has looked at both ports (product on 4870, the branch's toolbox on 4891)

### DEPLOY: feat/plugins-cards-installed-vs-marketplace

The toolbox's Plugins card and page are now **Installed plugins**, drawn as a plug in its socket. The
product port's Plugins card and page are now **Marketplace**, drawn as a storefront. Connectors draws
a chain link. The two pages kept their `/plugins` URLs, and the three cards no longer share one plug.

**Score:** 2

#### What makes this deploy extra special

Every repo running dkj-policy shows the toolbox card and page as Installed plugins instead of Plugins.
That is a rename the user will notice, and nothing for them to do.

**Score:** 2

#### Pull Request

Name the two Plugins cards apart: Installed plugins and Marketplace

