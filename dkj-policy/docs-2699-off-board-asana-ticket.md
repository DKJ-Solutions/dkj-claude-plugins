## docs/2699-off-board-asana-ticket

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

#### The verified reason (inbound check, #2699)

- The Asana MCP has no add-to-project call: `asana_update_task` takes no project, and
  `asana_create_task` sets one only at creation. So a session cannot put an off-board task on the board.
- `asana-mirror.ps1` deliberately reads the board off the task's own memberships
  (`Select-StageMembership`) and leaves a task on no numbered board alone. Having CI multi-home a
  colleague's task would reverse that design, so this branch takes the issue's other option: the
  skill names the case and says what to do.

### CREATE

- [x] `report-issue` SKILL.md step 2: the off-board case -- read the memberships first, skip the move
      and both field writes, still prepend the link and post the `created:` comment, name the one hand
      act left (add the task to the board), and note that the sweep stages it from then on.

### TEST

- [x] Docs-only change; the gates run inside `ship-pr`.

### DEPLOY: docs/2699-off-board-asana-ticket

N/A inside this repo: it changes only a skill page that ships to consumers.

**Score:** N/A

#### What makes this deploy extra special

For a BWJ store maintainer filing an issue from a colleague's Asana ticket that lives in another project
(`SEO`, a workload overview): `report-issue` now says what to do instead of prescribing a card move and
two field writes that Asana refuses. It skips those writes, still links the task and posts the
`created:` comment, and names the one act left to a person, adding the task to the board, after which
the daily sweep stages it like any other card
([#2699](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2699)).

**Score:** 2

#### Pull Request

report-issue: say what to do when an Asana-originated ticket is not on the repo board
