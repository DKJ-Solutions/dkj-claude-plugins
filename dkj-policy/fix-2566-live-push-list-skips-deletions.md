## fix/2566-live-push-list-skips-deletions

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

Inbound #2566 (xoxowildhearts): the live push list read the range with `git diff --name-only`, so every
theme file DELETED in the range came out as a `push` row. Reason verified in the tree before the repair:
`prepare-release.ps1:310` and `live-preflight.ps1:388`, no `--diff-filter`, and `Get-LivePushRows` had no
notion of a deletion.

### CREATE

- [x] `Get-LivePushRows` takes `-DeletedPaths` and gives a fourth verdict, `deleted` (never pushed), tested after sync provenance -- a deletion a sync mirrored in came from live and is already gone there
- [x] `live-preflight.ps1` and `prepare-release.ps1` read the deletions with `--diff-filter=D`, both reads with `--no-renames` so a renamed file's old path is reported too, and a failed deletion read refuses rather than reading as none
- [x] a `deletions` step in each driver (`warn` in live-preflight, `attention` in prepare-release) names the count still on live
- [x] mirrors rebuilt with `build-shared-scripts.ps1`

### TEST

- [x] `live-push-rules.tests.ps1`: 101 pass -- the deleted verdict, separator matching, the order against a sync-owned and a non-theme deletion, and both drivers feeding the set with renames split
- [x] `dkj-policy-bwj.tests.ps1` (488) and `native-capture.tests.ps1` (355) green

### DEPLOY: fix/2566-live-push-list-skips-deletions

Inside this repo: `Get-LivePushRows` in `scripts/lib/live-push-rules.ps1` gained a `-DeletedPaths` set and a
`deleted` verdict, and `live-preflight.ps1` and dkj-policy-bwj's `prepare-release.ps1` now feed it from a
`--diff-filter=D` read, with rename detection off in every range read.

**Score:** 2

#### What makes this deploy extra special

For whoever prepares a store's live push: a theme file deleted since the last release is no longer
offered as a `push` row. That row claimed a change `--only` cannot make, and the file stayed on live
unnoticed. Each such file is now listed under `held` as deleted and still on live, with its own step
saying the store delete is a separate decision. A renamed file's old path, which used to be in no list
at all, is reported the same way.

**Score:** 3

#### Pull Request

live push list lists files deleted in the range as push rows

