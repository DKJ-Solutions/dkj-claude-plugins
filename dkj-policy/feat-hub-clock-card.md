## feat/hub-clock-card

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

The owner asked (October 27, 2026) for a new card on the hub home page, named Clock, holding Stopwatch and
Logbook. A first build put both as two rows in one card; the owner rejected it -- a hub card is always ONE link -- so Clock is a card linking a /clock page that holds the two. The owner then moved Test gate there too.

### CREATE

- [x] `Get-GeneralPages`: a `Group = '/clock'` key on Test gate, Stopwatch and Logbook; `Get-HubGroups` names the Clock group
- [x] `Format-HubPageCardsHtml` draws a group as one card link; `Format-HubGroupPageHtml` draws `/clock`, routed in `serve-general-pages.ps1`
- [x] The Test gate, Stopwatch and Logbook pages' trails read Home > Clock > ...
- [x] The house-style README states that a card is always one link, and names the group page

### TEST

- [x] `dev-preview-sessionstart` and `dev-pages`: six one-link cards, Clock in Test gate's place, and the /clock page
- [x] `stopwatch`, `logbook` and `connector-dashboard` suites green
- [x] The owner has looked at the hub home page (visible result), and asked for the PR

### DEPLOY: feat/hub-clock-card

The hub's home page links Test gate, Stopwatch and Logbook through one card, Clock, in the place the Test
gate's card held; it opens `/clock`, a page with a card for each, and their trails read Home > Clock > the page. A page
joins a group by a `Group` key in `Get-GeneralPages`, and a hub card stays one link.

**Score:** 2

#### What makes this deploy extra special

Every repo's hub home page shows one Clock card instead of the Test gate, Stopwatch and Logbook cards; all three are a click further, on `/clock`.

**Score:** 2

#### Pull Request

Group Test gate, Stopwatch and Logbook under one Clock card on the hub home page

