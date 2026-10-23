## feat/3309-suite-overview

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

Lever 3 of #3309, the last one (lever 2 is #3311, lever 1 #3314). For each suite, the /test-gate page
shows what it protects and what it costs, and why a given diff selects it. A visible result, so the
branch is parked for the owner's review and not merged.

### CREATE

- [x] `Get-AffectedSuiteSelection` returns `Why`, one sentence per selected suite: it reaches the changed path, it names it, its walk scope covers it, or it walks unscoped
- [x] `Get-SuiteSynopsis` reads what a suite protects from its own `.SYNOPSIS`, so no second description has to be kept in sync
- [x] /test-gate opens with "This checkout's change": the changed paths, what runs locally and on CI, and one row per selected suite with its reason and cost
- [x] Every suite row shows its synopsis under its name
- [x] The server loads the gate's selection guarded and caches it on HEAD plus `git status`
- [x] The page and `suite-groups.json` no longer claim that CI runs every suite on every PR
- [x] Mirror `plugins/dkj-policy/scripts/lib/gate-lib.ps1` byte-identical

### TEST

- [x] `dev-pages.tests.ps1` (308), `affected-suites.tests.ps1` (139), `connector-dashboard.tests.ps1` (198), `ci-suite-selection-lib.tests.ps1` (34): all pass
- [x] The live dev server serves the new page (200); for this branch it says that every suite runs, because the change touches the selector
- [x] Victor (code review): nothing blocking; the section now claims the selection rather than the whole gate, a whole-pool selection reads "every suite", a failed git read is not cached, and rows are keyed on the suite path

### DEPLOY: feat/3309-suite-overview

The dev server's test-gate page now opens with this checkout's change: which suites the local gate
runs for it, what CI runs, and one line per suite saying why it is in (the file it reaches, the walk
scope that covers it, or an unscoped walk) and what it costs. Every suite also shows what it protects,
taken from its own header (#3309).

**Score:** 3

#### What makes this deploy extra special

N/A: the page belongs to this repo's dev server and ships to no consumer. `Get-AffectedSuiteSelection`
gains a `Why` field that a consumer's gate does not read.

**Score:** N/A

#### Pull Request

The test-gate page says what each suite protects and why this checkout's change selects it

