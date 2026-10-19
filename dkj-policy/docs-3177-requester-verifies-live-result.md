## docs/3177-requester-verifies-live-result

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

Inbound #3177: in BWJ ticket handling, the requester checks a live result against its acceptance,
not a dev session. The requester's refinement (a closed issue, not one parked on
`awaiting-review-client`) and the owner's ruling (BWJ-wide, no per-repo seam) are both on the thread.
The closed-message form that makes it concrete is #3179, which is not in scope here.

### CREATE

- [x] `bwj-development/WORKFLOW-portable.md` chapter 4: a new section, *A result that is a number*,
  placed after the go-live half so the existing sections stay whole. It also says what to use until
  #3179 lands.

### TEST

- [x] Copy edit (Edith) on the diff.
- [x] Lint and test gates through `open-pr`.

### DEPLOY: docs/3177-requester-verifies-live-result

Inside this repo the rule is text in the bwj-development page. Nothing reads it.

**Score:** 1

#### What makes this deploy extra special

In a BWJ store repo, a dev session stops taking the post-live acceptance measurement of a fix whose
result is a number (PageSpeed, conversion, ranking). It closes the issue instead, with a closed message
telling the requester how to measure and against which targets. In smartwatchbanden that measurement
was picked up four times and stalled on PageSpeed quota and missing browser tooling.

**Score:** 3

#### Pull Request

