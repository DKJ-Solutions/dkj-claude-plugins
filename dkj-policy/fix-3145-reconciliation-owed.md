## fix/3145-reconciliation-owed

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

Inbound #3145, verified on pickup: `Write-SyncReconciliationBase` puts live's bytes into the path's history, and `Test-LiveContentIsOurs` (and the consumer's drift check, by the same test) then reads live as ours while the trunk still lacks live's content. Nothing checked that the content reconciliation had happened.

### CREATE

- [x] `Get-ReconciliationOwedPaths` + the two shared subjects in `live-push-rules.ps1`; `sync-main` writes its commits from them and says the follow-up is required before a live push
- [x] `live-preflight` refuses at step 3 (`-AcceptOwedReconciliation` turns it into a note); `prepare-release` flags it as attention
- [x] skill pages for `sync-main` and `live-preflight`

### TEST

- [x] `live-push-rules.tests.ps1` 178/0, `sync-main.tests.ps1` 174/0

### DEPLOY: fix/3145-reconciliation-owed

A merged `sync-main -ReconcileBase` branch no longer leaves a path that reads as safe to push while the trunk still lacks live's third-party content. `live-preflight` now refuses a push-list path whose newest commit is still the reconciliation base, `prepare-release` flags it days ahead, and `sync-main`'s closing text says the content commit is required before any live push. A person who decides the trunk's version should win passes `-AcceptOwedReconciliation`.

**Score:** 1 -- the maintainer of this repo sees nothing change here.

#### What makes this deploy extra special

A Shopify store that reconciled a sync conflict with `-ReconcileBase` is now stopped before a live push that would have silently reverted what a third party changed on live -- measured in a store, where it would have undone a raised shipping threshold and a `noindex`.

**Score:** 3

#### Pull Request

A merged reconciliation base reads as safe to push until the content is reconciled

