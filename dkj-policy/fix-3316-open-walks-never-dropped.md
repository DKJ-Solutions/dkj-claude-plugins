## fix/3316-open-walks-never-dropped

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

#### Status

Scripts and tests only: the gates prove it, so it ships without an intermediate stop.

### CREATE

- [x] `Get-SuiteReferenceSet` reports `WalksOpen`: a live-tree walk is open unless a constant in a filtering position names a file type. These are the rules from PR #3313's `f3f2f17b8`, re-cut onto `main`, plus one more: a `Get-ChildItem -Directory` lists no file, so it is not open. The flag travels through the parse cache
- [x] `Get-AffectedSuiteSelection` reports `Open`: the walkers with an open walk in any test-owned file they reach, or a reached file that does not parse. It follows the reference graph past an unscoped walk instead of stopping there, so an open walk further along is still seen
- [x] `Get-StaticAssetSuiteSelection` (`ci-suite-selection-lib.ps1`) never drops an `Open` walker by file type
- [x] The `gate-lib.ps1` plugin mirror is byte-identical again

### TEST

- [x] `affected-suites.tests.ps1`: 21 `WalksOpen` asserts covering every shape #3316 measured, plus `-Directory`/`-Depth`, and `Open` on the fixture walker (158 passed)
- [x] `ci-suite-selection-lib.tests.ps1`: an open walker whose text never names `css` is kept for a CSS-only change (35 passed)

### DEPLOY: fix/3316-open-walks-never-dropped

CI's asset-only selection ([#3316](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3316)) kept a
tree-walking suite only when the suite's text named the changed extension. A walk that can return any file type
was dropped, and nothing ran behind it, so the merge went ungated. `Get-SuiteReferenceSet` now reports `WalksOpen`
for every live-tree walk that no constant narrows to a type. `Get-AffectedSuiteSelection` reports those suites as
`Open`, and the CI selection never drops an `Open` suite by type. The issue said no suite walked this way. On
October 23, 2026 this tree had four: three unfiltered at the source, and one reaching a file that does not parse.
For a CSS-only change CI now keeps 6 of 41 walkers, where it kept 3.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

CI's asset-only selection never drops a suite whose live-tree walk can return any file type

