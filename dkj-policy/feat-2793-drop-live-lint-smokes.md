## feat/2793-drop-live-lint-smokes

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

Remove the exit-0 live-repo lint smoke from bootstrap-drift and subagent-shared, and give fix-mojibake's coverage assert a route that runs only the encoding tool, so the heaviest suite loses ~70% of its runtime.

#### Where this deviates from the issue's proposal

The issue's step 1 reads `subagent-shared`'s smoke as an exit-0 assert only. It is not: sections 7 and 9 of
that suite read the gate's `[shared]` and `[tool-block]` **coverage lines** from the same run, which is what
holds the gate to walking every agent def, every persona and every obliged def. Removing the run removes
those asserts. Narrowing it with `-SkipCheck` was measured on the live repo and declined: 40.7 s against
45.7 s for the full run (n=1). So `subagent-shared` keeps its one gate run and drops only the exit-code
assert, which was the redundant and collision-prone part.

### CREATE

- [x] `bootstrap-drift.tests.ps1`: section 5 (the live-repo lint smoke) and the unused `$Integrity` removed.
- [x] `subagent-shared.tests.ps1`: the exit-code assert on the live-repo gate run removed; the run stays for the two coverage-line asserts.
- [x] `fix-mojibake.tests.ps1`: the full gate run replaced by `fix-mojibake.ps1 -Check` run exactly as check 14 runs it, with the gate's own parse regex read from its source and applied to the tool's output, plus the `releases/` coverage-note assert read from the source.
- [x] `gate-lib.ps1` (`Get-NoteTreeOnlyVerdict`) and the `open-pr` skill page: a dated note that two of the three smokes are gone, and why the note-tree deduction still holds.
- [x] `check-plugin-integrity-links.tests.ps1`: its test-gap note no longer points at the removed smokes.

### TEST

- [x] `bootstrap-drift.tests.ps1` alone: 242 asserts green, 23 s locally (was 76.8 s, #2793's own measurement).
- [x] `fix-mojibake.tests.ps1` alone: 40 asserts green, 8 s locally (the full gate run it dropped took 45.8 s on this machine).
- [x] `subagent-shared.tests.ps1` alone: 43 asserts green.

### DEPLOY: feat/2793-drop-live-lint-smokes

The test suites no longer run the whole lint gate over the live repo just to check that it passes. `bootstrap-drift` drops that run entirely, which is ~70% of the heaviest suite. `fix-mojibake` now runs only the encoding tool behind check 14, and checks the gate's own parse of its file count against what the tool prints. `subagent-shared` keeps its run for the two coverage lines it reads, and no longer asserts the exit code. The CI lint job and `open-pr`'s local gate already run that command in every PR. Locally, `bootstrap-drift` went from 76.8 s to 23 s and `fix-mojibake` lost a 45.8 s gate run. The CI before/after with `measure-suites` comes from the runs after the merge.

**Score:** 2

#### What makes this deploy extra special

Nothing a consumer runs changes: these are this repo's own suites and gate notes.

**Score:** N/A

#### Pull Request

bootstrap-drift and fix-mojibake no longer rerun the full lint over the live repo
