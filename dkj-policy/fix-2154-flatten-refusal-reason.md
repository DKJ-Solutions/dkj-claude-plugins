## fix/2154-flatten-refusal-reason

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

#### What #2154 reported, and what was verified before repairing it

The report named two code sites and a reason. Both were read before anything was changed, and both
stand exactly as described:

- `scripts/lib/native-capture-lib.ps1` captures native stderr with `2>&1` under
  `$ErrorActionPreference = 'Continue'`. Under PowerShell 5.1 that wraps every stderr line in an
  `ErrorRecord` carrying its own positional info.
- `scripts/task/prune-merged.ps1` composed its refused-delete verdict with
  `($delRes.Output | Out-String).Trim()`, which renders that record's full exception display.

Reproduced end to end on a throwaway repo with an unmerged branch: the old rendering came back
byte-identical in shape to the paste in the issue -- git's one line, then a `CategoryInfo` line, a
`FullyQualifiedErrorId` line, and a source-line caret naming `native-capture-lib.ps1`.

**The report's "structural rather than tied to that branch" reading is right, and it is wider than the
one site it names.** Seven sites in `prune-merged.ps1` render captured *failure* output into an
operator-facing message; all seven had the same exposure.

#### The one decision this branch made, and the reason it went that way

#2154 left the placement open -- *"if that flattening belongs to the capture layer rather than to each
caller, it is worth doing there"*. Two readings of that were available:

1. Normalise inside `Invoke-NativeCapture`, so `Output` hands back strings on both arms.
2. Add the flattening to the capture layer as a helper a *reader* calls, leaving the capture's own
   contract alone.

**This branch took 2.** `native-capture-lib.ps1` is mirrored into `dkj-policy` and
`dkj-subagents-shopify` and runs in consumers' repos, so changing what `Output` holds is a result-shape
change for every caller in every consumer -- which is the line the lib's own `#1963`/`#1966` block
already draws in as many words: *a behaviour change for every consumer rather than a bug fix, which is
a decision of its own rather than a side effect*. A prio-1 rendering repair is not where that decision
gets made as a side effect. Reading 1 remains open and is filed as [#2155](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2155) rather than dropped.

The helper is not invented here either: `Get-ShopifyLineText` in `scripts/lib/shopify-cli-lib.ps1`
already solved this exact class, and its measured ordering -- `TargetObject` first, `Exception.Message`
as the fallback -- is carried over, because on an *empty* stderr line `ToString()` falls back to the
type name.

### CREATE

- [x] `Get-NativeLineText` + `Get-NativeOutputText` in `scripts/lib/native-capture-lib.ps1`, placed
      beside `Invoke-NativeCapture`, documenting why the normalisation sits at the reader and not at
      the capture.
- [x] All seven failure-path renders in `scripts/task/prune-merged.ps1` moved onto the helper
      (the refused delete, the failed step-off, the failed hand-back, the fast-forward refusal, the
      fetch, the `gh` merged-PR list, and `ls-remote`).
- [x] The success-path stdout parsing in the same file left on `Out-String` deliberately -- those
      captures carry no `ErrorRecord`, so moving them would widen the diff without changing an output.
- [x] Mirrors regenerated with `scripts/sync/build-shared-scripts.ps1` (3 updated).

### TEST

- [x] New section in `scripts/tests/native-capture.tests.ps1`, driven by a **real** refused
      `git branch -d` rather than a hand-built `ErrorRecord` -- the wrapping is the subject, so a
      fixture that constructs the record would assert this suite's idea of the shape instead of the
      one PowerShell produces at the call site.
- [x] The **old** rendering is pinned too (`CategoryInfo`, the caret). Without it a future PowerShell
      that stopped wrapping stderr would turn the whole section green while proving nothing.
- [x] The success path is asserted unchanged: on plain stdout the helper and `Out-String` agree
      exactly.
- [x] `$null`, a bare string and an array are covered, plus a source assert that the measured call
      site carries the helper -- same shape as the existing `open-pr` source assert, and for the same
      reason.
- [x] `native-capture.tests.ps1`: 249 pass, 0 fail (16 of them new).
- [x] Full lint + test gate green via `open-pr.ps1`.

### DEPLOY: fix/2154-flatten-refusal-reason

A refusal captured from a native command now reads as **the command's own words**. `prune-merged`'s
verdict on a branch `git branch -d` declined was git's single line -- `error: the branch '<name>' is
not fully merged` -- followed by a `CategoryInfo` line, a `FullyQualifiedErrorId` line and a
source-line caret pointing into `native-capture-lib.ps1`: a file the operator never ran and cannot act
on, in the middle of the sentence telling them what to do. `Get-NativeOutputText` flattens each
captured line to the text the command actually wrote, and the seven failure-path renders in
`prune-merged.ps1` go through it. git's own `hint:` lines survive -- the repair must not trade an
exception dump for a truncation.

**It normalises at the reader, not at the capture, and that was the branch's one real decision.**
Making `Invoke-NativeCapture` hand back strings would fix every caller at once and change the result
shape for every caller in every consumer, which the lib's own `#1963`/`#1966` reasoning already calls a
decision of its own rather than a side effect of a repair. That reading is filed as [#2155](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2155), not dropped.

**Score:** 2

#### What makes this deploy extra special

`prune-merged.ps1` and `native-capture-lib.ps1` both ship in `dkj-policy`, so this lands in every
consuming repo that runs the tidy-up lanes: the next time a delete is refused there, the operator reads
git's three lines instead of twelve, and nothing points them at a file inside the plugin. Small, and on
a path nobody visits until something declines -- which is exactly when a readable message is worth the
most.

**Score:** 2

#### Pull Request

Render a refused git delete as git's own line, not a PowerShell ErrorRecord dump
