## fix/2487-ci-floor-metered-minutes

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

Inbound #2487, from `BWJ-Development/smartwatchbanden` (private, Team plan): the runners
`adopt-ci-floor` places used up the included Actions minutes. Checked on pickup against the
tree: the symptom stands. `fold-on-merge` and `verify-resolved` run on every trunk push on
`windows-latest`, and `merge-on-green` runs on `*/30` on `windows-latest`. The source's reason
for not skipping fold pushes (`verify-resolved.yml`: "one short job", and "coupling to a format
it does not own") has **expired for a metered repo**. The coupling is already accepted in
`ci.yml:399`, which skips on `startsWith(head_commit.message, 'fold:')`.

Scope: proposals 1, 2 and 4 from the report. Proposal 3 (`ubuntu-latest` + `pwsh`) is a
runtime migration of scripts that target Windows PowerShell 5.1, so it gets its own issue
rather than riding along.

### CREATE

- [x] Job-level skip of a single-commit `fold:` push in `fold-on-merge.yml` and `verify-resolved.yml`: the consumer templates in `adopt-ci-floor.ps1` and the source's own copies
- [x] `merge-on-green` consumer template: sparser schedule, with `workflow_run` staying the ordinary path
- [x] `adopt-ci-floor` prints what the runners it places cost a private (metered) repo
- [x] Plugin mirror of `adopt-ci-floor.ps1` kept identical
- [x] Separate issue filed for `ubuntu-latest` + `pwsh` -- #2488
- [x] #2492 (this branch's own contradiction, small enough to fix inside the assignment): reworded the
  five "half-hourly" / "half an hour later" sites in `scripts/ci/pick-merge-on-green.ps1`,
  `scripts/lib/merge-on-green-lib.ps1` and `scripts/release/ship-pr.ps1` to name "the scheduled sweep"
  generically, true for both the source's `*/30` and a consumer's `0 */3`; left `ship-pr.ps1`'s other
  "half an hour" (the $maxRequiredWaitSec/1800s check-registration budget, unrelated to the sweep
  cadence) untouched. Plugin mirrors of all three kept byte-identical.

### TEST

- [x] `adopt-ci-floor.tests.ps1` asserts the skip, the schedule and the cost note
- [x] Lint + suites green -- run by open-pr, which refuses the push on any failure; the touched suites and `check-plugin-integrity.ps1` were green beforehand

### DEPLOY: fix/2487-ci-floor-metered-minutes

The CI-floor runners no longer spend Actions minutes on pushes that have nothing to do
([#2487](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2487)). `fold-on-merge` and
`verify-resolved` skip, at job level, a push carrying exactly one commit whose subject starts with
`fold:`. A job skipped by `if:` is not billed, and about half of a trunk's pushes are folds. This
applies to both the source's own workflows and the templates `adopt-ci-floor` places. Anything
else, a batch under a fold head included, still runs. The `merge-on-green` template now sweeps
every 3 hours instead of every 30 minutes (8 jobs a day instead of 48), and `workflow_run` stays
the ordinary path. `adopt-ci-floor` now prints what each runner it places costs on a metered
repo. The "half-hourly" wording in the sweep's shared scripts now fits either cadence
([#2492](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2492)). Moving the runners to
`ubuntu-latest` + `pwsh` is left to
[#2488](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2488).

**Score:** 3

#### What makes this deploy extra special

A private consumer's CI floor stops using up the plan's included Actions minutes. The consumer that
reported it lost every Actions job to the spending limit. `adopt-ci-floor` never overwrites a runner
that is already there, so a consumer that placed the floor before this release must apply the new
`if:` and schedule by hand. The other way is to remove the three files and re-run the adoption.

**Score:** 4

#### Pull Request

The CI floor stops spending a private repo's Actions minutes on fold pushes and a half-hourly sweep

