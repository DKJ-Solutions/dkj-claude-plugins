## docs/3253-created-comment-on-own-tasks

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

Inbound #3253: `report-issue` posted the `created:` comment only on a task that came from Asana, and
step 3 said a task the procedure created itself gets none. Verified on pickup: the skill says so, no
script posts the comment, and the asymmetry was only #2653's scope (it asked about Asana-originated
cards), not a guardrail.

### CREATE

- [x] `report-issue/SKILL.md`: step 2 posts the comment on a created task after its placement; step 3's
  "gets none" is replaced, the header rule kept
- [x] `WORKFLOW-portable.md`: the matching passage says a created task gets the same comment

### TEST

- [~] No suite reads this prose, and no script posts the comment: it is a step the session performs
  through the Asana MCP, so there is nothing to test beyond the gates

### DEPLOY: docs/3253-created-comment-on-own-tasks

`report-issue` now posts the fixed `created:` comment on a task it creates itself too, right after
placing it, not only on a task that came from Asana (#3253). Colleagues read that comment as the sign
that the GitHub issue exists, on every card, and a session-created card without it read as a skipped
automation. Step 3 and `WORKFLOW-portable.md` say the same.

**Score:** 2

#### What makes this deploy extra special

A session running `report-issue` in a store repo now writes one more comment on every task it creates.

**Score:** 2

#### Pull Request

report-issue: the created: comment on a task the procedure creates itself too

