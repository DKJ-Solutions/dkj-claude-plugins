## feat/2186-baseline-into-specialists-seam

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

Move the always-on budget ratchet's baseline from the workflow folder into `.claude/specialists/`,
preserving the recorded low-water mark and every consumer's existing baseline.

#### What the issue asked, and what the code said back

#2186 asked whether the move is possible and how the file can be moved safely. Possible: the path is
composed in exactly one function, `Get-AlwaysOnBaselinePath`. Safely: three things, all read out of
the code rather than assumed.

1. The file is a **low-water mark**, and this repo is over the budget (110,075 B against 100,000). A
   `git mv` carries the number; a delete-and-regenerate resets it to whatever the path measures that
   day.
2. The lib is **plugin payload**, so the move reaches an existing consumer as a plugin update rather
   than as a commit they reviewed.
3. A missing baseline is **not an error**: `Read-AlwaysOnBaseline` returns `$null`,
   `Get-AlwaysOnBudgetVerdict` calls that `first-run`, and a first run never refuses. So a hard path
   switch would not break a consumer's ratchet -- it would silently forget it, which is worse.

Hence the resolver prefers whichever file is actually there, seam first, which is the answer
`Get-WorkflowFolderName` already gives one layer up for the folder itself.

### CREATE

- [x] `git mv dkj-policy/always-on-baseline.json .claude/specialists/always-on-baseline.json` -- the
      recorded 110,075 B and the file's history carried across intact.
- [x] `Get-AlwaysOnBaselinePath` rewritten as a prefer-what-exists walk: seam, then the workflow
      folder, then the seam as the answer a writer creates from nothing.
- [x] Two script-scoped constants for the seam directory and the file name, since the walk joins one
      name onto two directories.
- [x] The lib header's location paragraph rewritten -- it argued the old home at length, and half of
      that argument (why this is not `scripts/repo-config.ps1`) still stands and is kept.
- [x] `plugins/dkj-policy/scripts/lib/always-on-budget-lib.ps1` mirror rebuilt via
      `scripts/sync/build-shared-scripts.ps1`.
- [x] `INSTALL.md`: the rename checklist's step 4 now names both paths, and a new section states the
      move, why nothing happens on a plugin update, and the one-command migration.

### TEST

- [x] Six asserts added to `scripts/tests/always-on-budget.tests.ps1` covering the walk in every
      state it can meet -- neither file, legacy only, both, seam only, a directory at the legacy
      path, and the agreement between this lib's spelled-out seam directory and `Get-SeamPaths`,
      which is its canonical definition.
- [x] One stale assert label corrected: `-Record` no longer writes into the workflow folder.
- [x] `scripts/tests/always-on-budget.tests.ps1` -- 97 passed, 0 failed.
- [x] `scripts/lint/check-always-on-budget.ps1` against this repo reads the moved baseline and reports
      the same 110,075 B, `[OK] over the budget by 10,075 B, and NOT growing` -- which is the proof
      the low-water mark survived the move.

### DEPLOY: feat/2186-baseline-into-specialists-seam

`always-on-baseline.json` moves out of the workflow folder and into `.claude/specialists/`. The
workflow folder is where prose a person writes and reviews lives; this is the one file in it nobody
may hand-edit, and three of the four documents it measures are already in the seam.

Nothing happens to an existing consumer's baseline on a plugin update, deliberately:
`Get-AlwaysOnBaselinePath` now prefers whichever file is actually there, seam first and the workflow
folder second, so an un-migrated repo keeps reading and writing the copy it has and no second
baseline appears beside it. Migrating is one `git mv`, documented in `INSTALL.md` -- and it has to be
`git mv`, because a regenerated baseline looks identical and quietly resets the low-water mark.

A consumer notices nothing unless they go looking: the gate keeps reading their existing file, and
the migration is optional and one command. What it buys is that the folder a person reviews stops
holding a file no person may edit.

**Score:** 2

#### What makes this deploy extra special

The interesting half is what was NOT done. A hard path switch would have passed every gate and broken
nothing loudly, because a missing baseline is a first run and a first run never refuses -- so every
consumer's ratchet would have reset to that day's figure, silently, with the old file orphaned beside
it. For the one file whose entire value is a number carried forward, the silent arm is the expensive
one, and the fallback read exists to close it.

**Score:** 2

#### Pull Request

Move always-on-baseline.json into the specialists seam

