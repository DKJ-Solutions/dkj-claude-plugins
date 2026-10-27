## feat/3562-asana-reopen-card-back

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

The reopen-side mirror of #3248, as #3562 asks: after the reopened message, move the card into the
section `Get-AsanaStageMap` gives `InDevelopment` (the documented key for "somebody is building it") and
untick a completed task. The move skips where the stage does not resolve on exactly one board; the untick
is judged apart, so a skipped move never costs it.

### CREATE

- [x] `asana-closed-message.ps1`: `Read-AsanaTaskBoard` (shared by both moves, now reads `completed`),
  `Select-ReopenCardWrites` / `Resolve-ReopenCardWrites`, `New-AsanaUncompleteRequest`, and one write site
  (`Invoke-AsanaWrite`) for the comment, both moves and the untick
- [x] `bwj-development.tests.ps1`: the structural asserts hold one write site and one `completed = $false`;
  unit and end-to-end asserts for the reopen's writes
- [x] Docs: `WORKFLOW-portable.md` steps 4 and 6, the README, `report-issue`, `adopt-bwj-development`, the
  workflow yml's header

### TEST

- [x] `bwj-development.tests.ps1` standalone: 933 asserts passed; the full gate runs in `ship-pr`

### DEPLOY: feat/3562-asana-reopen-card-back

When a GitHub issue linked to an Asana task is reopened, `asana-closed-message` now moves the card into
the board's `InDevelopment` section and marks the task incomplete if it was completed, after posting the
reopened message ([#3562](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3562)). Unlike the
review move (#3248) it does take a card out of `Completed`. Where the task is on several boards, or its
board has no single section with the `InDevelopment` code, the move is skipped and the message and the
untick still go out. The untick only ever sets `completed` to false. A store takes it by re-copying
`.github/scripts/asana-closed-message.ps1`, and the move needs `InDevelopment` in its
`Get-AsanaStageMap`; without it, only the untick happens.

**Score:** 3

#### What makes this deploy extra special

A reopened ticket's Asana card now goes back to In Progress and is unticked on its own, so the board
agrees with the "back in development" message instead of waiting for someone to drag it.

**Score:** 3

#### Pull Request

asana-closed-message: on a reopen, move the card to InDevelopment and mark it incomplete

