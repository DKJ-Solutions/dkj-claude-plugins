## fix/2526-shared-bounded-pr-scan

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

Fold the bounded PR-scan scaffold that `check-stranded-sweep.ps1` and `check-unshipped-pr.ps1` both
carried into one lib, with each check keeping its filter, its verdict and its prose (#2526). This
waited on #2527, which is where the second copy came from.

- [x] Put the shared scan in a new `scripts/lib/pr-scan-lib.ps1`, not in `merge-on-green-lib.ps1`.
      That lib's header says it is pure (no git, no gh), and this scan is the half that makes the reads.
- [x] Keep the preamble (root resolution and the gh/account/repo gates) in each script. The gate order
      differs per check, and the cheap gates run before the heavy libs load, which a lib function
      cannot do for its caller.
- [~] Nolan's network half on the issue (one shared `gh pr list` in place of two) was dropped. The two
      checks are separate SessionStart hooks, each its own process, so sharing one read would need them
      merged into one. His own measurement shows neither hook sets the wall-clock tail.

### CREATE

- [x] `scripts/lib/pr-scan-lib.ps1`: `Invoke-BoundedPrScan` (the list read, an optional precheck, the
      per-PR required-check read, both budgets, the judged/unjudged split), `New-PrScanFinding`
      (the display scrub plus `Get-PasteableRef`), `Get-PrScanIncompleteLine` and `Get-PrScanResumeLines`.
- [x] Both checks call it. Their scan bodies went from ~130 lines to ~50.
- [x] Registered as a `LibOnly` row in `shared-scripts-lib.ps1`, and the mirror rebuilt.

### TEST

- [x] `stranded-sweep-gate` (46), `unshipped-pr-gate` (42) and `merge-on-green-lib` (208) all green,
      unchanged. The two gate suites drive both checks end to end against a fake `gh`, so they exercise
      the helper from both callers: skip paths, findings, the hostile-branch placeholder, the precheck
      and `[INCOMPLETE]`.
- [~] No separate suite for `pr-scan-lib.ps1`. Every function in it is reached through those two
      end-to-end suites, and a unit suite would only restate their asserts.

### DEPLOY: fix/2526-shared-bounded-pr-scan

`check-stranded-sweep.ps1` and `check-unshipped-pr.ps1` no longer carry the same ~100-line bounded
PR-scan scaffold twice. It now lives once, in `scripts/lib/pr-scan-lib.ps1` (`Invoke-BoundedPrScan`):
the filtered list read, the per-PR required-check read under a per-call and a total budget, the honest
judged/unjudged split, the display scrub and the paste-safe checkout token. Each check keeps only its
list filter, its verdict and its report prose, so a repair to the pattern now lands once. What the checks
report is unchanged, apart from one wording: `check-unshipped-pr.ps1`'s `[INCOMPLETE]` line now reads
the same as its sibling's.

**Score:** 2

#### What makes this deploy extra special

N/A: an internal refactor of two session-start checks. A subscriber sees the same report as before.

**Score:** N/A

#### Pull Request

The two session-start PR scans share one bounded scan helper

