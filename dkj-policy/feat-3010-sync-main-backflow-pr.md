## feat/3010-sync-main-backflow-pr

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

#### Scope

Part 3 of [#2998](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2998): when `Get-ShopifyLiveDeployBranch` names a branch, `sync-main` opens the deploy-branch->trunk back-flow PR instead of pulling live into a mirror. The CLI model is untouched.

#### Design choices

- Back-flow is measured as content, `git diff --name-status <trunk>...<deploy>` (three dots), not as a commit count. This is the reasoning #3008 gave `Get-LivePromotionStep`: a promotion's merge commit stays on the deploy branch.
- The standing-predecessor guard becomes "an open PR with that head". It is reported, not duplicated, and an unreadable PR list refuses a real run.
- It never merges, whatever `Get-ShopifySyncMerges` says, because the back-flow must be a merge commit and the PR is the moment somebody looks. It warns when `Get-PrMergeMethod` is not `merge`.
- The two required seams (store, theme id) are not required in this mode, because nothing is pulled from the store. No sync log entry is written, because there is no sync branch to carry it.

### CREATE

- [x] `ConvertFrom-BackflowNameStatus` and `New-SyncPrBody -Backflow` in `scripts/lib/sync-rules.ps1`.
- [x] `sync-main.ps1`: the seam, the relaxed refusals, step 2b, and the docstring's seam list.
- [x] `sync-main` skill page: the seam row and the connected-mode section. Shopify README: the seam row names `sync-main` too.
- [x] Mirrors regenerated.

### TEST

- [x] `sync-rules.tests.ps1` 191/0, and `sync-main.tests.ps1` 174/0 with ten fixture cases for connected mode: level branches end cleanly without store seams; a bot commit is counted and named; no CLI step runs; no branch is created; a real run refuses when it cannot read the PR list; an option-shaped or trunk-named deploy branch is refused. The network-call count moves 12 -> 15 and `native-capture`'s audited count 91 -> 94, each with its audit note.

### DEPLOY: feat/3010-sync-main-backflow-pr

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

sync-main: open the back-flow PR when the live theme deploys from a branch

