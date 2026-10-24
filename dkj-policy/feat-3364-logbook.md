## feat/3364-logbook

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

#### Decisions

The owner's choices (#3364): the working name Logbook; a run starts at the first prompt of a new session, only on
a clean trunk; it stops when a turn ends on a clean trunk, also when HEAD never moved. The Stopwatch's store,
model, phases and pages are reused, its page functions taking a route, title and note. The Logbook is not shared
to origin, because a label is a prompt's first line and the repo is public. A live ship-pr CI wait holds the run open.

### CREATE

- [x] `scripts/lib/logbook-lib.ps1`: the rules, the label, the two pages on the Stopwatch's
- [x] `scripts/lib/stopwatch-lib.ps1`: a run's Session and the store's session list, `-KeepOpenRuns`, page parameters
- [x] `scripts/dashboard/logbook-hook.ps1` and its two hooks in `.claude/settings.json`
- [x] `/logbook` and `/logbook/<slug>` on the hub server, and the card on the home page

### TEST

- [x] `scripts/tests/logbook.tests.ps1` (new, in the pages group), plus the hub's and the server's suites
- [x] The lint gate (0 errors) and the four touched suites, run directly; `open-pr` runs the whole gate at the PR

### DEPLOY: feat/3364-logbook

The hub has a new card, **Logbook** ([#3364](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3364)).
It times every assignment given in a clean session, with no marker. The first prompt of a new Claude Code session
starts a run when the checkout is on a clean trunk. The run stops when a turn ends with Claude back on the clean
trunk, including when nothing was merged, and never while a `ship-pr` is still waiting on CI. Each session keeps
its own run. A branch parked for a look keeps its run going. Every run gets a card and a page with its transcript
phases, built from the Stopwatch's own pages. The runs stay on this machine and are not shared.

**Score:** 3

#### What makes this deploy extra special

N/A: the Logbook is this repo's own hub tooling under `scripts/`, and no plugin ships it.

**Score:** N/A

#### Pull Request

A Logbook card on the hub that times every assignment of a clean session, first prompt to back on the trunk

