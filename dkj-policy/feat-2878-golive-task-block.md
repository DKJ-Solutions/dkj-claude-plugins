## feat/2878-golive-task-block

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

Inbound #2878 from smartwatchbanden: go-live blocks that taught the SEO colleague a new task failed
five times over three rounds. Verified against the tree: the golive-block page prescribes the headings
but says nothing about how the `[changed]` and `[where]` prose is ordered. The report's claim that
`WAT ER NU ANDERS IS` leads the block is out of date (`TE BEKIJKEN OP` leads since #2700), but the ask
is about the order inside the prose, which the session writes, so no script change is needed.

### CREATE

- [x] golive-block SKILL.md: new subsection "When the change hands the requester a task" -- goal and
  default first, the click route walked as a non-admin, one worked example, then the exceptions; a
  model change rewrites the whole instruction
- [x] WORKFLOW-portable.md: one pointer to it under "The facts are the script's, and the prose is the
  session's"

### TEST

- [~] no automated test: the guidance governs prose the session writes, which no script checks

### DEPLOY: feat/2878-golive-task-block

`golive-block` now says how to write a block that hands the requester a new task rather than a
result to look at ([#2878](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2878)). The
prose follows a fixed order: first the goal and what happens when the reader does nothing, then the
click route walked once with a non-admin account, then one worked example on the reader's own page,
and the exceptions last. When the model changes, the whole instruction is rewritten rather than only
the delta. `WORKFLOW-portable.md` points to it. The headings and the script are unchanged.

**Score:** 2

#### What makes this deploy extra special

A colleague who is handed a new task in a go-live block gets the goal, a click route that works with
their own account, and an example, in that order. Before, the block could give them the latest delta
and a list of system names.

**Score:** 3

#### Pull Request

golive-block: guidance for a block that teaches a colleague a new task

