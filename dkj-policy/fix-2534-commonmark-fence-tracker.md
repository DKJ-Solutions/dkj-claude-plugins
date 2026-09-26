## fix/2534-commonmark-fence-tracker

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

#2534, filed from the #2531 branch: `Test-IsFenceLine` was used as a plain toggle, so a four-backtick
block wrapping a three-backtick example closed at the inner fence, and the lines after it were read as
headings and `@`-imports. Verified on pickup by reading the code. The issue named two walk sites; a grep
found a third with the same toggle, check 28 in `check-plugin-integrity.ps1`, so all three move.

The repair is one CommonMark tracker in `measure-context-lib.ps1`, `Get-NextFenceState`, which returns
the state after a line (`''` outside, the opening run inside). `Test-IsFenceLine` is removed rather
than kept beside it, so there is one definition. `adopt-workflow-folder.ps1`'s local tracker from
#2531 now calls it too.

### CREATE

- [x] `measure-context-lib.ps1`: `Get-NextFenceState` replaces `Test-IsFenceLine`; `Get-DocumentSections`
  and `Get-AlwaysOnDocuments` use it.
- [x] `check-plugin-integrity.ps1` check 28: the import scan uses it.
- [x] `adopt-workflow-folder.ps1`: dot-sources the lib at file scope and drops its own tracker.
- [x] Plugin mirrors rebuilt with `build-shared-scripts.ps1`.
- [x] Review pass: Victor found no correctness defect. He noted that seven other fence trackers in the
  tree are still plain toggles, so the new docstring now says it serves the always-on walk, not every
  walk. Filed #2536 for the rest.

### TEST

- [x] `measure-always-on.tests.ps1`: a nested-fence document (no invented section, bytes still sum, no
  import walked) and nine one-line asserts on the tracker's rules. 97 passed.
- [x] `adopt-workflow-folder.tests.ps1`: 140 passed, its own nested-fence case included.
- [x] `check-plugin-integrity.ps1`: 0 errors.

### DEPLOY: fix/2534-commonmark-fence-tracker

The always-on walk now tracks code fences the CommonMark way. A fence closes only on a run of the same
character at least as long as the one that opened it, so a four-backtick block that wraps a
three-backtick example no longer ends at the inner fence. Before this, an `@`-line or a `#` line inside
such an example could be counted as an import or a heading. That affected the always-on budget, the
consumer-prose session check, the "constitution imported" verdict and the import check in the lint
gate. There is now one fence tracker, `Get-NextFenceState` in `measure-context-lib.ps1`, and every walk
calls it, including the constitution-import scan in `adopt-workflow-folder.ps1`. No consumer is known to
have hit the miscount yet; this closes it before one does.

**Score:** 1

#### What makes this deploy extra special

N/A. Lint and measurement tooling does not reach a subscriber of a service.

**Score:** N/A

#### Pull Request

One CommonMark fence tracker for the always-on walks (#2534)

