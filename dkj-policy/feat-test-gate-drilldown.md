## feat/test-gate-drilldown

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

The owner, October 27, 2026: the Test gate page was one long scroll -- a groups table, then a full table
per group, each with its notes. Everything should fit a screen of about 1300 x 900 (a guideline, not a
measure), drilling down through the breadcrumbs as deep as the content needs, and a page that runs past
the window should say so at once.

- `/test-gate` becomes an overview of cards (one per group, the measurement, the change where the source
  repo passes one); `/test-gate/<group>` one group's suites in tables of at most twelve rows side by side;
  `/test-gate/<group>/<suite>` one suite; `/test-gate/measured` and `/test-gate/selection` the rest of the
  old page.
- The fit alarm goes in the hub's page shell (`Format-GeneralPageHtml`), so every hub page carries it, and
  NOT in `house-theme.js`: that file ships into customer-facing apps, where a developer's warning has no place.
- The density rule moves from 1400 x 600 to about 1300 x 900 at its source (the `house-style` skill and the
  house-style README), with drilling down named as the way to keep a page to one screen.

### CREATE

- [x] `hub/lib/test-gate-lib.ps1`: `Get-TestGateLists` and a `-Path` on `Format-TestGatePageHtml` for the four levels; `$null` for a path no page has
- [x] `hub/pages/serve-general-pages.ps1`: the `/test-gate/...` routes, a 404 for an unknown one
- [x] `hub/lib/general-pages-lib.ps1`: `Format-FitAlarmHtml`, drawn by the page shell on every page
- [x] The density rule in the `house-style` skill and `assets/house-style/README.md`
- [x] The owner, on a first look: no tiles above the overview's cards; the unrecorded count moves onto the measurement's card

### TEST

- [x] `dev-pages.tests.ps1`: the page section rewritten for the levels, plus the fit alarm (368 passed); the two asserts that counted every `msg--warn` on a page now leave the hidden alarm aside, as they did the banner
- [x] The other hub suites green: connector-dashboard, dev-preview-sessionstart, native-capture, hub-airsquats, logbook, stopwatch, stopwatch-sync
- [x] Every Test gate page served from this tree and judged by the fit alarm in headless Chrome at a 1300 x 900 window (a 1284 x 805 viewport): all thirteen groups, the overview, the measurement's page and two suite pages fit
- [ ] The owner judges the pages in the working copy (a visible result)

### DEPLOY: feat/test-gate-drilldown

In this repo the Test gate stops being one long scroll: an overview of cards drills down through the
breadcrumbs into a page per group and per suite, each fitting a screen of about 1300 x 900, and every hub
page now warns at its bottom right the moment it runs past the window.

**Score:** 3

#### What makes this deploy extra special

Every repo's hub gets the same: the Test gate drills down from an overview (`/test-gate`) to a group
(`/test-gate/<group>`) and a suite (`/test-gate/<group>/<suite>`), and every hub page carries the fit
alarm. The house style's density rule now names a screen of about 1300 x 900, a guideline, instead of
1400 x 600.

**Score:** 3

#### Pull Request

Test gate: one screen per level, drill down by breadcrumbs, and a hub-wide overflow signal

