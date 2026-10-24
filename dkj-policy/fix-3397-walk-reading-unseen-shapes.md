## fix/3397-walk-reading-unseen-shapes

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

Issue #3397: four in-suite walk shapes were invisible to `Get-SuiteReferenceSet`, and so were neither
selected nor held by #3392's scope guard. Of the issue's two directions this takes (b), extending
detection, because (a) would first need a proof that a walk runs over a fixture, which the reading
does not have.

### CREATE

- [x] `gate-lib.ps1` (and its mirror): a Get-ChildItem past the first pipeline stage is a live walk when an
  earlier stage names a live root, rooted at the stage before it; a function's parameters are bound
  from each call site (by name, otherwise in order) and read as assignments; `Invoke-GitRead` with
  `ls-files`/`grep` and `Select-String` over a wildcard path are walks, narrowed only by a typed constant.
- [x] `ci-suite-selection-lib.ps1`'s trade note now names only what the reading still cannot see.
- [x] `affected-suites.tests.ps1` asserts each shape, its sample, and that the same shape over a fixture
  is no walk.

### TEST

- [x] `affected-suites` (194 pass), `ci-suite-selection-lib` (49) and `trusted-tree-seam` (58), standalone.
- [x] Every suite in `scripts/tests` reads the same Walks and WalksOpen as on `main`, so the local
  selection costs nothing more today, and no declared suite reads uncovered.

### DEPLOY: fix/3397-walk-reading-unseen-shapes

The test selection now recognises four more ways a suite can list the live tree: a root piped into
`Get-ChildItem`, a root handed to a function parameter, git read through `Invoke-GitRead`, and
`Select-String` over a wildcard path
([#3397](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3397)). Such a suite used to be
neither selected as a walker nor held by the declared-scope guard that CI's asset-only selection relies
on since #3392. No suite in the tree uses one of these shapes today, so nothing selects differently.

**Score:** 1

#### What makes this deploy extra special

N/A -- a consumer's local gate selects exactly as before until one of its suites uses one of these shapes,
and then it runs that suite, which is the safe direction.

**Score:** N/A

#### Pull Request

Walk reading sees piped roots, function parameters, Invoke-GitRead and Select-String

