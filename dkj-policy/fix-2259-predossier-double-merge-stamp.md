## fix/2259-predossier-double-merge-stamp

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
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

The fold writes the merge moment in exactly one of two places: the entry's own heading, or the closing
`[PR #NN](url)` line. `fold-changelog-entry.ps1` chose between them by asking
`Test-EntryHasSection -EntryText $entryContent -Key 'PullRequest'` -- a **proxy**, accurate only while
`Set-EntryMergeStamp` wrote onto the `'Pull Request'` section heading.

Two later changes broke the proxy and nothing connected them:

1. **August 23, 2026** -- the stamp moved to the entry's **own** heading (the first heading at the entry
   level). The gate did not move with it.
2. **August 26, 2026** -- the heading levels shifted, so a **pre-dossier** entry's title-heading, once
   promoted by the fold's own re-level step, sits at exactly that level.

From that day such an entry has a heading the writer stamps **and** no `'Pull Request'` section for the
gate to find, so the footer is handed the date as well -- the same moment stated twice, in the one
document whose subject is when things landed.

#### The repair: the gate asks the writer's own question

`Get-EntryMergeStampTarget` (private) resolves *where* the stamp goes, once.
`Set-EntryMergeStamp` writes there and `Test-EntryHeadingTakesMergeStamp` reports whether there is a
there -- so the fold reads the writer's decision instead of a restatement of it, and the pair cannot
drift apart again.

#### What the old note in the suite claimed, and why it is gone

`entry-scaffold.tests.ps1` already recorded the August 26 collapse and dismissed it: *"IT COSTS NOTHING
IN PRACTICE ... Set-EntryMergeStamp is only ever called by the fold, on a freshly written current-shape
entry. No caller hands it a historical one."* The first clause tested the wrong function -- the cost was
in the **caller's** gate -- and the second is contradicted by `fold-changelog-entry.ps1`'s own comment,
which calls the pre-dossier shape one it *"explicitly still folds rather than a hypothetical"*. Two
documents disagreeing about whether a path is reachable is what an assert settles, so the note is
replaced by asserts over the **composition** both halves produce.

### CREATE

- [x] `entry-scaffold-lib.ps1`: `Get-EntryMergeStampTarget` (the shared scan) + `Test-EntryHeadingTakesMergeStamp` (the gate's predicate); `Set-EntryMergeStamp` rewritten to read the target
- [x] `entry-scaffold-lib.ps1`: `Format-EntryFoldFooter`'s docstring, which still described the retired proxy as the caller's test
- [x] `fold-changelog-entry.ps1`: the gate now calls `Test-EntryHeadingTakesMergeStamp`, and its comment block records why the proxy was wrong rather than restating it
- [x] `scripts/sync/build-shared-scripts.ps1` re-run -- both plugin mirrors updated

### TEST

- [x] `entry-scaffold.tests.ps1`: the stale "costs nothing in practice" note replaced by asserts over the **composition** -- stamp-then-footer, in the fold's own order -- across four shapes: pre-dossier, current DEPLOY, no heading at the entry level, and a heading that exists only inside a fence
- [x] each shape asserted to fold with the moment in **exactly one place**, and the gate asserted to agree with what the writer actually did
- [x] `Get-EntryMergeStampTarget` asserted directly, so the predicate is held to the shared scan rather than to a regex of its own
- [x] Suite green: 848 asserts. Repro from the issue re-run against the patched lib -- pre-dossier now yields one stamp where it yielded two

### DEPLOY: fix/2259-predossier-double-merge-stamp

The fold wrote the merge moment twice on a pre-dossier entry -- once on its heading, once on the closing
`[PR #NN](url)` line -- because its gate still asked whether the entry had a `'Pull Request'` section, a
question the stamp writer stopped acting on on August 23, 2026. The gate now reads
`Test-EntryHeadingTakesMergeStamp`, which shares `Set-EntryMergeStamp`'s own scan, so the two cannot
answer differently. Nothing changes for an entry written in the current shape.

**Score:** 2

#### What makes this deploy extra special

A consumer of this workflow meets the fold through the plugin mirror, so the duplicate landed there too.
It prevents a failure that has not happened yet, and the failure is namable: any branch parked before
August 6, 2026 -- here or in a consuming repo -- carries a pre-dossier entry, and folding one now writes
the landing date in two places at once.

**Score:** 1

#### Pull Request

A pre-dossier entry no longer folds with the merge date written twice
