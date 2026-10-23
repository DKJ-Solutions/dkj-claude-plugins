## feat/3309-local-always-narrowing

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

Lever 1 of #3309 (lever 2 shipped in #3311). The ~40 suites that walk the live tree ran on every
local selection; narrow them to the walks that can return a changed path's type, and fold in the
review note's guard: a walk that can return ANY type (unfiltered) is never narrowed.

### CREATE

- [x] `Get-SuiteReferenceSet` reports `WalksOpen`: a recursive Get-ChildItem with no -Filter/-Include/wildcard, a git ls-files/grep with no wildcard pathspec, or the `# gate-selection: always` line
- [x] The reference cache carries the new flag (extractor key v2)
- [x] `Get-AffectedSuiteSelection` keeps a walk only when it is open or its source names a changed extension; a path with no extension keeps every walk; a narrowed walk still goes through the ordinary match; dropped walks reported as `Unread`
- [x] `ci-suite-selection-lib.ps1` takes the map's narrowed `Always` instead of its own text filter, which was blind to an open walk
- [x] The gate's console line names the walks left out
- [x] Mirror `plugins/dkj-policy/scripts/lib/gate-lib.ps1` byte-identical

### TEST

- [x] `affected-suites.tests.ps1`: open-walk detection (8 shapes) and a new section 4b on the narrowing -- 96 pass
- [x] `ci-suite-selection-lib.tests.ps1` reshaped to the map deciding -- 33 pass
- [x] Measured against `origin/main` in a temp worktree: brandbook CSS 40 -> 3 suites, house-style CSS 44 -> 7, README 67 -> 58, App.tsx 41 -> 1, a `.ps1` lib 87 -> 87

### DEPLOY: feat/3309-local-always-narrowing

A change that touches no PowerShell now skips the test suites that walk the repo for other file
types, in the local `open-pr` gate. A CSS fix in `brandbook/` runs 3 suites where it ran 40, a
`.tsx` change 1 where it ran 41, a README 58 where it ran 67; a script change still runs all of
them. A walk that can return any file type is never skipped, which also closes the gap the lever-2
review found in the CI selection for asset-only pull requests (#3309).

**Score:** 3

#### What makes this deploy extra special

A repo running this workflow waits on fewer suites in `open-pr` for a change to stylesheets, front-end
sources or docs, because the shared gate library ships with the plugin.

**Score:** 3

#### Pull Request

Narrow the always-run tree walks to the file types a change touches

