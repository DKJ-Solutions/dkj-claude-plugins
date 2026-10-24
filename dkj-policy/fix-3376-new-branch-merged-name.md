## fix/3376-new-branch-merged-name

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

### CREATE

- [x] `Get-MergedHeadRecord` and `Select-FollowUpBranchName` in `pr-issues-lib.ps1`, the gh/git probe `Get-FreeFollowUpBranchName` in `remote-ahead-lib.ps1`
- [x] `new-branch.ps1` refuses a used-up name before the checkout, under a repo name and a hosted origin only
- [x] `open-pr.ps1` names the first free `-vN` instead of `-v2` unconditionally
- [x] The `new-branch` and `open-pr` skill pages say so; the plugin mirrors are synced

### TEST

- [x] `pr-issues.tests.ps1` covers both pure functions; `new-branch-base.tests.ps1` cases x10-x12 cover the wiring

### DEPLOY: fix/3376-new-branch-merged-name

`new-branch` now refuses a branch name whose pull request has already merged, before it checks anything
out, and names the first free follow-up name (`<name>-v<N>`). Until now that branch was cut, committed and
pushed, and only `open-pr` noticed, after the work, with a hint that always said `-v2` even where `-v2`
was taken. `open-pr`'s hint now names the first free name too
([#3376](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3376)).

**Score:** 3

#### What makes this deploy extra special

A consumer re-using a branch name after its merge is stopped at `new-branch` instead of after a commit and
a push, and is told the exact name to use. The check only asks `gh` where the repo names itself and has a
hosted origin, so an offline run is unchanged.

**Score:** 2

#### Pull Request

new-branch refuses a branch name a merged PR has used up, and names the first free -vN
