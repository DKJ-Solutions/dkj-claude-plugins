## feat/2775-measure-suites

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

A repo-local `measure-suites` skill, as #2775 proposes: read-only, a baseline set and an optional
comparison set of PR run ids, printing the pool total, per-family totals, the slowest shard per run and
the per-suite delta. The log parsing moves out of `record-suite-durations.ps1` into a lib both scripts
use, rather than being copied. Repo-local because both scripts read this repo's own CI job names.

### CREATE

- [x] `scripts/lib/suite-durations-lib.ps1`: the parser, its row validation, the shard and family readers
- [x] `scripts/maintenance/record-suite-durations.ps1`: uses the lib; behaviour unchanged
- [x] `scripts/maintenance/measure-suites.ps1`: the read-only comparison
- [x] `scripts/tests/suite-durations-lib.tests.ps1`: the pure functions, the fixture-row drop above all
- [x] `.claude/skills/measure-suites/SKILL.md`: the page, documenting both scripts
- [x] `native-capture.tests.ps1`: the bounded-site audit moves 86 -> 87 for the new `gh run view --json jobs` read, which asks `Test-NativeExitMeasured`

### TEST

- [x] the new suite, standalone: 18 passed
- [x] `measure-suites` on two real runs, 37120366656 (PR #2772) against 37123517722 (PR #2779): integrity family 2,069s to 1,372s, slowest shard 435s to 401s, 2 fixture rows dropped
- [x] the full gate, through `ship-pr`

### DEPLOY: feat/2775-measure-suites

A new repo-local skill, `measure-suites`, measures the test suites' CI cost for one set of CI runs, or
compares two sets: the pool total, a total per named family of suites, the slowest shard, and the suites
that changed most. It writes nothing. Before this, a before/after check of a change to the suites was
summed by hand. `record-suite-durations.ps1` now shares its log parser with it.

**Score:** 2

#### What makes this deploy extra special

N/A -- the skill and both scripts are this repo's own, and nothing in a plugin changes.

**Score:** N/A

#### Pull Request

measure-suites: compare the test suites' CI cost between two sets of runs

