## feat/house-style-on-product

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

Maikel, October 31, 2026: the house style's specimens should be seen on this repo's product port, not its
toolbox. Chosen of three options: the product gets the page, and the toolbox redirects there in the source
repo only, so every consumer's toolbox keeps its own copy.

### CREATE

- [x] `plugins-page-lib.ps1`: `Get-HouseStyleSpecimensParts` holds the page's content, so the toolbox and the product render the same page in their own shells; `Resolve-HouseStyleProductUrl` decides the redirect
- [x] `serve-general-pages.ps1`: in the source repo, with a product stated, `/plugins/dkj-policy/house-style[/<section>]` is a 302 to the product
- [x] `dev-pages-lib.ps1` + `serve-consumer-dashboard.ps1`: `/marketplace/dkj-policy/house-style[/<section>]` on the product, and a card on its dkj-policy page
- [x] Maikel, same day: a plugin's page drops its Description card and puts the description behind a "?" right of the h1 -- drawn as mesowise draws its own, a 24px SVG ring and glyph in a 44px `.page-info-button`, primary on the paper -- a `.tooltip--explain` shown on hover or focus. `Format-GeneralPageHtml` takes `-Info` and `Get-PageInfoScript` places and opens the tooltip; the house style gains `.page-title` (the h1 and its button on one row) and `.page-info-button`, named in the README and the `house-style` skill beside rule 5 (#3585), which holds
- [x] Maikel, same day: the seven `plugin.json` descriptions -- the text behind the "?" -- rewritten for a user: what the plugin gives you, when to enable it, what it needs. bwj-development keeps "Four chapters", which its suite pins

### TEST

- [x] `dev-pages.tests.ps1`: the product's route, shell, 404 and read error, the redirect's three refusals, and the dkj-policy card -- 522 passed
- [x] The restarted product on port 4870 serves the overview (11 section cards), a section page (`/tokens`) and the dkj-policy page with its new card, each a 200
- [x] The owner has looked at the product page (a visible result, so it waits for that look): Maikel shaped it across the session and said "ship it"

### DEPLOY: feat/house-style-on-product

The house style's specimens are on this repo's product, at `/marketplace/dkj-policy/house-style` with a page per
section and a card on the product's dkj-policy page, read from this tree on every request. The toolbox here
sends its own house-style pages there once a release carries the redirect; in every other repo the toolbox
keeps serving them, since only the source repo holds the canonical `specimens.html`.

A plugin's page on the product has no Description card any more: its description is behind a "?" right of the
`h1`, shown as a tooltip while the pointer is on it or it has focus. `Format-GeneralPageHtml` takes it as `-Info`,
and the house style gains `.page-title`, the `h1` and its `.page-info-button` on one row, so a page still opens on its
`h1` alone (#3585).

**Score:** 2

#### What makes this deploy extra special

Every plugin's own description is rewritten for the person who installs it: what it gives you, when to enable it and
what it needs, without the internal terms the old ones were written in. It is the text `claude plugin details` and
the toolbox's Plugins page show, so it reaches every user with the next release. The redirect itself fires only in
the house style's source repo, so no consumer's toolbox changes.

**Score:** 2

#### Pull Request

The house style's specimens on the product port; the toolbox redirects there in the source repo

