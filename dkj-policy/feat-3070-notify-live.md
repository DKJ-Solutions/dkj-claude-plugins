## feat/3070-notify-live

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

Maikel chose on #3070 (October 16, 2026) where the step lives: a script a person runs right after the
live push, printed by the runbook so it is not forgotten. Not the cut and not a release workflow,
because neither knows the moment a release is live.

### CREATE

- [x] `scripts/lib/live-message-rules.ps1` -- the pure verdict, the message and the range parsing
- [x] `scripts/task/notify-live.ps1` -- the driver: tag range, merged PRs, closed issues, dry run, `-Post`
- [x] `skills/notify-live/SKILL.md`, and the runbook step after the cut in `Format-ReleaseRunbook`
- [x] the README rows, `WORKFLOW-portable.md`'s closed-message list and the `prepare-release` page

### TEST

- [x] `scripts/tests/bwj-development.tests.ps1`: the verdict case by case, the message's words and
  html, the runbook's step order, the copied escaper held equal to the template's, and the driver's
  refusal in this repo -- 715 asserts green before the last one was added

### DEPLOY: feat/3070-notify-live

The `bwj-development` plugin gains `notify-live`. It is a script a person runs right after a store
release's live push and cut. It tells the Asana task of every issue that release carried, if that task
was told the result "becomes visible with the release", that the work is now live, as version vX.Y.Z,
and that the review can start. The message repeats the go-live block's own closing ask, in the block's
language. It is a dry run until `-Post`, it never tells a task twice, and `prepare-release`'s runbook
now prints it as the step after the cut (#3070).

**Score:** 3 -- a hand step that used to be missing

#### What makes this deploy extra special

A requester whose closed message said "visible with the release" is now told when that release is out.
Until now they had to work out for themselves whether that day's release carried their work. The store
maintainer gains one step on release day, and the runbook prints it.

**Score:** 3

#### Pull Request

bwj-development: tell each carried issue's Asana task when its release goes live

