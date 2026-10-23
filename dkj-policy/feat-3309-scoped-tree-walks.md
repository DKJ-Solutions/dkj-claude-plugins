## feat/3309-scoped-tree-walks

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

Lever 1 of [#3309](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3309): narrow the local
gate's "always" set. Lever 2 (path-aware CI) shipped in #3311, and lever 3 (the per-suite overview page) is
not this branch, so the issue stays open and this ships with `-NoResolves`.

### CREATE

- [x] `Get-SuiteReferenceSet` reads `# gate-selection: walks <pattern> ...` as a walk with a scope, and
  records the literal `-Filter`/`-Include` values of every live-tree walk (`WalkFilters`).
- [x] `Get-AffectedSuiteSelection` runs a walker whose scope is declared only when a changed path falls in
  it (`Test-WalkScopeMatch`), inherits a scoped helper's scope, and reports `Scoped` and `Walkers` beside
  `Always`; the cache format is versioned to v2.
- [x] CI's asset-only selection judges every walker (`Walkers`), not just `Always`, so the declarations
  narrow the local gate while CI keeps at least what it kept before.
- [x] 37 walking suites declare their scope, each with a one-line reason; `merge-on-green-lib` and
  `suite-durations-lib` inherit one from a helper they reach, and `dev-pages` stays unbounded on purpose
  (it reads html, css and js).
- [x] The scope guard in `affected-suites.tests.ps1`: every declared scope covers its own live walks'
  filters (Victor's review note on #3309).
- [x] Victor's review: `fixture-lib-deps` and `bwj-extension-import` widened to what their libs and
  variable-built paths read; Edith's copy edit applied.
- [x] The `open-pr` skill page documents the declaration; the `gate-lib.ps1` mirror is rebuilt.

### TEST

- [x] `affected-suites.tests.ps1`: 135 pass, 0 fail. `ci-suite-selection-lib.tests.ps1`: 34 passed, 0 failed.
- [x] Measured on this tree: a change to `house-style.css` selects 5 of 165 suites (it was 44), a
  brandbook CSS change selects 2, a change to `claim-issue.ps1` selects 29 and a plugin README 44.
  CI's asset-only selection for a brandbook CSS change keeps the same two walkers as on `main`.

### DEPLOY: feat/3309-scoped-tree-walks

The local test gate in `open-pr` no longer runs every suite that walks the live tree. A suite can now
declare what its walk reads with a `# gate-selection: walks <pattern> ...` line, and it runs only when a
changed path falls inside that scope. In this repo 37 of those 40 suites declare one and two more inherit a
scope from a helper they reach, so only one still runs every time and a CSS change runs 5 suites locally
where it ran 44. The selection's own suite checks that each declared scope covers the
filters the suite's own walks use. The required CI check is unchanged.

**Score:** 2

#### What makes this deploy extra special

A repo that takes this release can declare the same line in its own tree-walking suites and stop waiting on
them for changes outside what they read. Nothing changes until it does: a suite with no declaration still
runs every time.

**Score:** 2

#### Pull Request

Tree-walking suites declare their scope, so a change outside it selects none of them locally

