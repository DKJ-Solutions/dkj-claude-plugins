## feat/sessionstart-section-pages

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

The owner asked (October 26, 2026) to make the hub's SessionStart page easier to scan by giving every h2
section its own card and its own page, exactly like the Stopwatch page: a bare overview with an h1 and a
grid of link cards, and each card opening a page with a crumb back.

#### Visible result -- parked for the owner's look

This is a page the owner judges by eye, so the branch stops before the PR and the checkout stays on it.

### CREATE

- [x] `Get-SessionStartSections` (and `Get-SessionStartSnapshotSections`, which replaces
  `Format-SessionStartSnapshotHtml`) in `hub/lib/general-pages-lib.ps1`: every section as
  @{ Slug; Title; Sub; Value; Body }
- [x] `Format-SessionStartPageHtml -Section`: the overview is bare, an h1 and one card per section in the
  house `.grid-3` (three to a row, then two and one); a section's page is bare too, its h1, sub line and one
  card, with a SessionStart crumb; an unknown slug returns `$null`
- [x] the routes: `/sessionstart/<section>` on `serve-general-pages.ps1` (404 for an unknown slug), and
  relayed by this repo's `serve-connector-dashboard.ps1`

### TEST

- [x] `dev-pages.tests.ps1` rewritten for the cards and the section pages: 364 passed, 0 failed
- [x] `dev-preview-sessionstart.tests.ps1` asserts a section page and the 404 over HTTP: 376 passed, 0 failed
- [x] served from this tree on a spare port: `/sessionstart` and all seven section pages answer 200 with
  this repo's real measurement and snapshot, `/sessionstart/nope` a 404

### DEPLOY: feat/sessionstart-section-pages

The hub's SessionStart page was one long column of seven sections, each a wide table or block, so finding
one part meant scrolling past the rest. It is now shaped like the Stopwatch page: an overview of seven
cards, each naming its section with one headline figure (the path against the budget, the efficiency
score, the open actions), and each opening a page of its own at `/sessionstart/<section>`. A failed or
over-budget measurement is still warned about on the overview.

**Score:** 3

#### What makes this deploy extra special

Every repo running the hub gets the new SessionStart overview on its next plugin update: the same numbers,
now one card per section, each with its own page.

**Score:** 2

#### Pull Request

SessionStart: one card and one page per section
