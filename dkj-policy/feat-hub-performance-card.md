## feat/hub-performance-card

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

Dave, October 30, 2026: a new Performance card on the hub, with SessionStart and Clock moved onto its page.
A visible result, so the branch waits for his look before it ships.

### CREATE

- [x] `general-pages-lib.ps1`: the Performance group and its icon, Clock under it; `Get-HubGroupCrumbs` gives a group's trail, and the hub draws a page's top-level group's card (merged onto main's nested groups and Sections from #3676)
- [x] SessionStart under `/performance`, Clock under it too; the crumbs of SessionStart, Test gate, Stopwatch and Logbook pages read through Performance
- [x] README of the hub names the new card

### TEST

- [x] `dev-pages`, `dev-preview-sessionstart`, `stopwatch` suites updated and green; `logbook` and `connector-dashboard` green
- [x] The branch's own server on 4891: `/hub` shows Performance in SessionStart's place, `/performance` holds SessionStart and Clock, the trails read Tools > Performance > ...

### DEPLOY: feat/hub-performance-card

The hub's home page has a Performance card in SessionStart's place. Its `/performance` page holds the
SessionStart and Clock cards, and the Clock keeps the Test gate, the Stopwatch and the Logbook. Every page
under those two now has Performance in its trail, and the hub shows a page that sits two groups deep under
its top-level group's card.

**Score:** 2

#### What makes this deploy extra special

A user of any repo's toolbox finds SessionStart and the Clock one click deeper, behind the new Performance card.

**Score:** 2

#### Pull Request

A Performance card on the hub, holding SessionStart and Clock

