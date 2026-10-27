## feat/3551-specialist-detail-pages

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

#3551, on #3550's plugin pages. Maikel's decision on the thread settles the URL scheme: nested pages,
Specialists > plugin > specialist, so `/specialists/<plugin>/<name>`. A visible result, so the branch is
parked for the owner's look.

### CREATE

- [x] `ConvertTo-SpecialistRow` carries the detail page's parts: a slug (the name lowercased, else the id),
  the listing and definition text, and the three file paths (a path only where the file exists)
- [x] A plugin's page opens on one card per specialist, in roster order, above its table; the table's
  names link to the same pages
- [x] `Format-SpecialistPageHtml`: the specialist's own page, with the trail, its tiles, what it is and when
  it loads, its files, its listing, and its definition folded
- [x] The server routes `/specialists/<plugin>/<specialist>`, with a 404 for one the plugin does not ship
- [x] After the owner's look (October 27, 2026): the specialist cards sit four to a row (`.sp-grid-4`, stepping
  down 4, 3, 2, 1), and a plugin's page opens on them as the overview does, with no tiles, no lead and no
  heading over the grid, each card title an h2

### TEST

- [x] `dev-pages.tests.ps1`: cards, roster order, links, slug rule, paths, trail, tiles, facts, escaping,
  the off-plugin notice and both 404 cases (393 passed)
- [x] Probed on the running product server: `/specialists/alpha` shows 19 cards, and
  `/specialists/alpha/tessa` names its three files
- [ ] The owner's look

### DEPLOY: feat/3551-specialist-detail-pages

The product's **Specialists** pages go one level deeper
([#3551](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3551)). A plugin's page now opens on
one card per specialist, and each card, like each name in the table below the cards, leads to that
specialist's own page at `/specialists/<plugin>/<name>`. That page shows the specialist's context cost
per part, what it is and when it loads, where its definition, manual and lens live, its listing, and its
definition.

**Score:** 3

#### What makes this deploy extra special

N/A: the product's dev-server pages exist only in this repo's checkout. No plugin ships them.

**Score:** N/A

#### Pull Request

Specialists: a card per specialist inside its plugin's page, and a detail page per specialist

