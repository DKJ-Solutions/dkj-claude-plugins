## feat/2925-reconcile-base-prints-merge

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

Inbound #2925. Verified: `Write-SyncReconciliationBase` printed only `gh pr create`. The optional flag
that opens and merges by itself is left out: the issue offers it as optional, and the printed finish
repairs the measured failure.

### CREATE

- [x] `sync-main.ps1` prints `gh pr checks <branch> --watch` and `gh pr merge <branch> --merge` after the
  create, and says the operator merges it with no review to wait for; Shopify mirror resynced
- [x] The `sync-main` skill page says the same

### TEST

- [x] `sync-main.tests.ps1` asserts the three lines on a real `-ReconcileBase` run, 164 green

### DEPLOY: feat/2925-reconcile-base-prints-merge

`sync-main -ReconcileBase` now prints the whole finish of the reconciliation base, not only how to
open its PR: `gh pr create`, then `gh pr checks <branch> --watch`, then `gh pr merge <branch> --merge`.
It also says that whoever runs the sync merges it, with no review to wait for, because the branch
changes no file ([#2925](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2925)). At
smartwatchbanden#892 the PR was opened with the printed line and then left open behind a comment
asking somebody else to merge it, blocking the follow-up.

**Score:** 2

#### What makes this deploy extra special

A store colleague running a conflicted sync gets a finish they can paste to the end, so the follow-up
work is no longer blocked on a PR nobody knew was theirs to merge.

**Score:** 2

#### Pull Request

sync-main -ReconcileBase prints the whole finish, merge included

