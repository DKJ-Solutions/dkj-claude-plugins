## feat/3563-long-pages-become-cards

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

#3563: the hub rule "a long page becomes an overview of cards, with a page each" had been applied page by
page (Stopwatch, SessionStart #3543, Specialists #3551) but was never written down or checked, so the
house-style page grew to 11 sections in one column without anyone noticing. This branch writes the rule
down once, puts it in the skill a session loads before visual work, makes the hub's page shell warn on any
page that breaks it, and reshapes the house-style page.

The threshold is **more than four** `.grid__head` sections with an `h2`. SessionStart's seven were too
many; the Issues page's three and the Artifacts page's two are not. `/test-gate` (15 sections) breaks the
rule as well. It was filed as #3565, then closed: #3561's Test gate drill-down landed on `main` while this
branch was in flight, and after the merge the page carries no warning.

This is a visible result, so the branch stops for the owner's look before it merges.

### CREATE

- [x] `Split-HouseStyleSpecimens` cuts `specimens.html` into its sections. The house-style overview is one
  card per section showing its specimen count, and `/plugins/dkj-solutions/house-style/<section>` is that
  section alone, with a 404 for an unknown slug. `specimens.html` remains the single source and loses its
  jump list.
- [x] `Get-PageSectionCount` + `$script:LongPageSectionLimit` (4): `Format-GeneralPageHtml` puts a
  `msg--warn` on every page holding more than four sections, above the first one.
- [x] The rule is written in the house-style README (*Every page: a long page becomes cards, with a page
  each*) and in the `house-style` skill's density rules and hand-over check.
- [x] Filed #3565 for `/test-gate`, then closed it as done by #3561. Merging `main` in also brought #3561's
  three hand-written Test gate cards into the card guard's allow-list (noted on #3566), and folded this rule
  into `main`'s new "Drill down rather than scroll" bullet in the skill.
- [x] The owner's first look (October 27, 2026): the overview cards were a hand-written variant (an `h3`
  link, which brought in an underline) instead of the house's one card. They now use
  `Format-HubCardLinkHtml`. The README's "The card" now says it is the card link on every page, and
  `dev-pages.tests.ps1` fails on any `card card--link` written outside it. The five older variants are on
  an allow-list that #3566 shrinks to empty.
- [x] The owner's look at `/plugins/dkj-solutions/house-style` and a section page: approved ("ship it", Maikel, October 27, 2026).

### TEST

- [x] `dev-pages.tests.ps1`: 415 passed, 0 failed after merging `main` (398 before it). It covers the split (fixture and the real
  `specimens.html`, with no section lost), the overview cards, the section page (crumbs, h1, lead, own cards
  only, style, dialogs and script kept), the 404, the routes, the section count and the warning at 4 and 5,
  and that the real house-style pages carry no warning.
- [x] A hub run from the working tree on port 4899: the overview is 8.5 KB (it was 85 KB) with no warning,
  `/tokens` returns 200, `/nope` returns 404, and `/test-gate` shows the warning.

### DEPLOY: feat/3563-long-pages-become-cards

The hub rule "a page with more than four sections becomes an overview of cards, each opening a page of its
own" is now written down in the house-style README and the `house-style` skill. The hub's page shell checks
it on every page it renders and puts a warning at the top of any page that breaks it. The House style page
under `/plugins/dkj-solutions/house-style` follows the rule itself: it shows 11 cards instead of 85 KB of
specimens in one column, and each section has its own page.

**Score:** 3

#### What makes this deploy extra special

Every repo running the hub gets the House style page as cards, with one page per section. A hub page that
grows past four sections now says so on the page itself, so the shape is caught as it happens instead of
being spotted later.

**Score:** 3

#### Pull Request

Hub pages: a long page becomes cards with a page each, written down and guarded

