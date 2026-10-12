## fix/2930-golive-post-waits-for-a-pr

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

Inbound #2930, verified: `build-golive-block -Post` checked the store-admin boxes and, since #2918, the Asana link, but nothing about whether the work had reached a PR. `PREVIEW-portable.md` told the handover to run `-Post` beside `-OutFile`, which is the steer #402 followed.

### CREATE

- [x] `Get-GoLivePostReadiness` in `golive-block-rules.ps1`: a closing PR that is merged or open counts as landing work; no PR, or only PRs closed without merging, does not
- [x] `build-golive-block.ps1`: on the post path only, reads the closing PRs with their state through GraphQL. `-Post` refuses on `none` or an unreadable answer, `-Force` is the early post, and `-OutFile` is untouched
- [x] Skill page (the order, the `-Force` row, the description), WORKFLOW-portable and PREVIEW-portable say the post belongs at the PR step
- [~] recording a forced early post inside the comment: dropped. The comment is what a colleague reads, and a `-Force` note there is noise for that reader. The console run is the session's record

### TEST

- [x] `bwj-development.tests.ps1`: the four readiness answers, the check placed on the post path before the comment, and an unreadable landing read refusing `-Post` end to end; 414/414
- [x] The GraphQL query run live: #2928 answers MERGED, #2930 answers none

### DEPLOY: fix/2930-golive-post-waits-for-a-pr

`build-golive-block -Post` now waits until the issue's work is in a pull request. It refuses while no open or merged PR closes the issue, or while it cannot read that. `-Force` makes a deliberate early post. `-OutFile` still works at the preview, so the handover page keeps its copy. The skill page and PREVIEW-portable now place the post at the PR step, after the owner's look
([#2930](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2930)).

**Score:** 2

#### What makes this deploy extra special

A store owner no longer finds a closed message with a release date on work they have not looked at yet. Measured on xoxowildhearts#402, where the block went on nine seconds after the preview handover.

**Score:** 3

#### Pull Request

build-golive-block -Post waits until the issue's work is in a pull request
