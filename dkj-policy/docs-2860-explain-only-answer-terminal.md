## docs/2860-explain-only-answer-terminal

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

Record the owner's decision on #2860 (October 6, 2026) in `bwj-development/WORKFLOW-portable.md`:
none of the three proposed routes. An explain-only answer to an Asana follow-up is given in the
terminal, to the person in the session, and nothing is posted anywhere.

### CREATE

- [x] Replace "how it reaches the task is #2860" under *Reopening an issue* with the decision.

### TEST

- [x] Docs-only; the ship gate covers links and integrity.

### DEPLOY: docs/2860-explain-only-answer-terminal

The `bwj-development` workflow page now says what happens to a follow-up answer that turns out to be
an explanation alone. It is given in the terminal, to the person in the session, and nothing more: no
comment on the closed issue, no relay and no connector post on the Asana task. The issue stays closed,
so nothing is done with it there. Until now the page left this open, pointing at #2860.

**Score:** 1

#### What makes this deploy extra special

In a store repo, a session answering a colleague's follow-up question with "this is already how it
works" no longer has to guess where that answer goes. It stays in the terminal; the session posts
nothing to GitHub or Asana.

**Score:** 1

#### Pull Request

Explain-only answer to an Asana follow-up stays in the terminal

