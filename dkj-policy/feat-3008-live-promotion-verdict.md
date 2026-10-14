## feat/3008-live-promotion-verdict

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

The first of six PRs splitting [#2998](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2998) (a Git-connected live theme as a second deploy mode). Lib-only: the pure rules a later live-preflight connected mode needs, and the record line that names a promotion. No script calls them yet, so no behaviour changes.

#### Dropped from the issue, with the reason

The issue also proposed an anchored subject pattern for `Get-SyncMergeCommits`, so a deploy branch named `live` would not match every subject containing "live". No caller will need it: in connected mode, what a promotion carries is the exact tree diff `<deploy> <trunk>`, so the sync-provenance heuristic is never fed the deploy branch.

### CREATE

- [x] `Get-LivePromotionStep` and `Format-LivePromotionCommand` in `scripts/lib/live-push-rules.ps1`. Back-flow is measured as the three-dot path diff, not a commit count, because a promotion merge commit stays on the deploy branch alone.
- [x] `Format-LivePushRecord -PromotedSha -DeployBranch` and `Get-LivePushRecordPromotion` in `scripts/lib/live-record-lib.ps1`.
- [x] Mirrors regenerated (shopify, bwj-development, dkj-policy).

### TEST

- [x] `live-push-rules.tests.ps1` 135/0 and `live-record-lib.tests.ps1` 96/0, standalone.

### DEPLOY: feat/3008-live-promotion-verdict

The live-push libs gain the rules of a Git-connected live theme, where going live is a merge of the trunk into a deploy branch. `Get-LivePromotionStep` refuses while the deploy branch holds live edits the trunk lacks, and when there is nothing to promote. `Format-LivePromotionCommand` prints the `gh pr create` that opens the promotion PR. The live-push record can name the promoted commit on a `# promoted <sha> to <branch>` line, which `Get-LivePushRecordPromotion` reads back. Nothing calls them yet: this is the groundwork for [#3009](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3009) ([#3008](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3008)).

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

live-push libs: the promotion rules of a Git-connected live theme
