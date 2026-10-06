## feat/2854-asana-reopened-message

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

Extend the closed-message template to issues: reopened, posting the #2656 reopened form; correct the docs that say a reopen posts nothing.

### CREATE

- [x] `asana-closed-message.ps1`: an `-Event closed|reopened` parameter; a reopen with a linked task posts the header and the #2656 reopened line, whatever the close reason, and reads no block.
- [x] `asana-closed-message.yml`: triggers on `[closed, reopened]` and passes `github.event.action`; file name kept so a re-adopt replaces rather than duplicates.
- [x] Pages corrected: WORKFLOW-portable.md, README.md, the adopt-bwj-development and report-issue skills.
- [~] Rename the template to something broader than closed-message: dropped, because adopt copies by path and a renamed file would land beside the old one and post twice.

### TEST

- [x] `bwj-development.tests.ps1`: reopen decision, the reopened form, and the trigger -- 314 asserts green.

### DEPLOY: feat/2854-asana-reopened-message

The reopened message on the Asana task is back, beside the closed message. The `asana-closed-message`
template now runs on `issues: reopened` as well, and on a reopen with a linked task it posts one comment:
the automation's header and *"GitHub issue <owner>/<repo>#<n> **reopened:** this Asana task is back in
development."*, the requester's fixed form from #2656. It posts whatever the issue was closed as, reads no
go-live block, moves no card and un-completes nothing. The template keeps its name, so a re-adopt replaces
it instead of adding a second copy. The pages that said a reopen posts nothing now say it does.

**Score:** 3

#### What makes this deploy extra special

When a store's issue is reopened, the requester's Asana task hears about it again, so nobody goes on
testing a result that is being reworked. To turn it on in a store, run `adopt-bwj-development` after the
update: the two files already exist there, so it stops and shows the difference, and the maintainer copies
the new `.github/workflows/asana-closed-message.yml` and `.github/scripts/asana-closed-message.ps1` over
the old ones. Nothing else is needed: the same `ASANA_PAT` secret serves both messages.

**Score:** 3

#### Pull Request

Bring back the reopened message on the Asana task

