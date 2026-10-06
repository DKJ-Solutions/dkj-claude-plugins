## docs/2856-reopen-only-to-build

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

Issue #2856, Dave's rule of October 6, 2026: a closed issue is reopened only once research shows there
is something to build. Write it where a reopen is prescribed: the reopened-message bullet and the
rejection round in `bwj-development/WORKFLOW-portable.md`, and the claim-issue page's "reopen it first".
Point 3 of the issue, how an explain-only answer reaches the task, is the owner's choice and was split
out as #2860 (`awaiting-decision`).

### CREATE

- [x] `WORKFLOW-portable.md`: the precondition under *Reopening an issue*, with the measurement, and the rejection round pointing at it
- [x] `skills/claim-issue/SKILL.md`: "still broken" is established, not asked
- [~] `claim-issue.ps1`'s refusal text left as is -- it already conditions the reopen on "closed and still broken"

### TEST

- [x] doc-only; the gates run in `ship-pr`

### DEPLOY: docs/2856-reopen-only-to-build

The `bwj-development` workflow page now says when to reopen a closed issue: only once research shows
something has to be built. A follow-up question or a rejection on the Asana task is researched with
the issue still closed. Since #2854 a reopen posts "back in development" on the task. Reopened at the
question, it told the requester something false whenever the answer turned out to be an explanation.
The `claim-issue` page reads the same way.

**Score:** 2

#### What makes this deploy extra special

In a store repo, a colleague's follow-up question no longer reopens the issue by itself. They hear
"back in development" only when work has actually restarted. An answer that is only an explanation
goes to them without a reopen; how it reaches the task is still open (#2860).

**Score:** 2

#### Pull Request

Reopen a closed issue only once research shows there is something to build

