## feat/3309-ci-path-aware-suites

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

#3309, lever 2 (Maikel, October 22, 2026): make the required CI check path-aware for a PR that changes
nothing but static assets. Such a PR runs only the suites that read those assets, and every other PR
keeps the whole pool. Levers 1 and 3 stay open on the issue.

### CREATE

- [x] `scripts/lib/ci-suite-selection-lib.ps1`: the asset verdict (CSS, images, fonts) and the
  selection. It keeps the affected-suite map's matches plus any tree-walking suite that names the
  extension, and fails closed throughout
- [x] `scripts/ci/get-pr-suite-selection.ps1`: reads the PR's paths off the merge commit and writes
  `mode` (full/skip/selected/whole) and `suites` for the job
- [x] `ci.yml`: the suites shards and the Linux leg read the verdict. An asset-only PR runs its
  selection in shard 1, and the other shards and the Linux leg skip
- [x] `Get-AffectedSuiteSelection` treats the two new files as its own, so a change to them runs the
  whole local pool (source and plugin mirror)

### TEST

- [x] `ci-suite-selection-lib.tests.ps1`: 32 asserts covering the verdict, the selection and the
  ci.yml wiring, most of them on the refusing side
- [x] Measured on the live tree: a `brandbook/src/index.css` change selects 3 of 165 suites, and a
  `house-style.css` change selects 6 (with `check-house-style` and `house-palette`), where CI ran all of them
- [x] Code review (Victor): a failed path read in shard 1 now runs the whole pool instead of its own slice, and the script paths use forward slashes for the Linux leg
- [x] Lint gate: 0 errors

### DEPLOY: feat/3309-ci-path-aware-suites

A pull request here that changes only stylesheets, images or fonts no longer waits on every test
suite in CI. The required check runs just the suites that read those files (3 to 6 of 165 for a CSS
change, where it used to run all of them over five shards), and the Linux leg skips. Every other pull
request runs the whole pool as before.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Path-aware suite selection on the required CI check
