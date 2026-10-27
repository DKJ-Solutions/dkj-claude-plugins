## feat/3566-one-hub-card-component

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

Give `Format-HubCardLinkHtml` the slots the hand-written card variants existed for, move every variant onto
it, and shrink the guard #3563 added to the one function (#3566). The wait it was parked on (#3563) landed
through #3567, so the `awaiting-pull` label was removed at pickup.

#### A visible result -- it stops for the owner's look

Every overview's cards change markup, so this branch is parked unmerged. To look: run
`plugins/dkj-policy/hub/pages/serve-general-pages.ps1 -Port 4899` from this checkout (the hub on 4890
serves the installed release, not this tree), and open /sessionstart, /test-gate, /plugins, /stopwatch,
/logbook; /connectors and /specialists are on the product server (4870).

### CREATE

- [x] `Format-HubCardLinkHtml` takes `-SubHtml`, `-ValueHtml` (a headline figure on its own line),
  `-BadgeHtml` (in the icon's place), `-Heading 2`, `-Id` and `-Class`; the house stylesheet gains
  `.menu-item__value`, `.menu-item__title` and a badge in the row
- [x] moved onto it: SessionStart's `ss-card`, the Plugins badge card (its badge and sub line kept), the
  Stopwatch label and run cards (the run card keeps the owner's order: start, prompt label, time, its tone and
  its live clock), the Test gate's three `tg-card`s (its bar kept), the Connectors groups and the Specialists
  plugins (both their `h2` labels kept)
- [x] the guard in `dev-pages.tests.ps1` names `Format-HubCardLinkHtml` alone; the house-style README
  describes the slots; the skill's pinned sha256 follows the stylesheet

### TEST

- [x] `dev-pages`, `connector-dashboard`, `dev-preview-sessionstart`, `logbook` and `stopwatch` suites green
  with their markup asserts moved to the one card shape; `check-plugin-integrity` 0 errors
- [x] the tree's general pages server (port 4899) serves every overview with the one card and none of the
  old shapes

### DEPLOY: feat/3566-one-hub-card-component

Every card link on the hub is now the one house card. `Format-HubCardLinkHtml` gained the slots the
hand-written variants existed for: a headline figure on a line of its own, a status badge in the icon's
place, the label as an `h2`, and an `id` and extra classes. SessionStart, Plugins, Stopwatch, Logbook, Test
gate, Connectors and Specialists use it, keeping what each card shows. The suite that refuses a hand-written
card now allows only that function, so a new overview cannot add a shape of its own again.

**Score:** 2

#### What makes this deploy extra special

N/A -- the hub's overview cards look alike and keep their content; nothing changes for the person who takes
the next version beyond that.

**Score:** N/A

#### Pull Request

Hub cards: one card component, every variant moved onto it

