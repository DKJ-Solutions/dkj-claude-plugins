## fix/2384-run-progress-fixed-clock

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

Repair [#2384](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2384), which reported two
exact elapsed asserts drifting under CI load. The reason was verified against the lib before
repairing, and it sits one function over from where the issue puts it. `Format-RunProgressLine`
reads no clock: it prints `ElapsedSeconds`, which `Get-LiveRunProgress` derives from its own
`Get-Date`. That function already takes `-NowUtc`, so no lib change is needed. The repair is
test-only, and smaller than the new parameter the issue proposed.

### CREATE

- [x] both exact-elapsed sections of `run-progress.tests.ps1` read one instant and pass it as `-NowUtc`

### TEST

- [x] `run-progress.tests.ps1`: all 63 asserts pass
- [x] race replayed with a 2 s sleep between write and read: pinned `+6m12s`, unpinned `+6m14s`, the issue's exact drift

### DEPLOY: fix/2384-run-progress-fixed-clock

`run-progress.tests.ps1` asserted two exact elapsed strings (`+6m12s`, `+11m48s`) while taking the
record's start and the reader's "now" from two separate clock reads. On a loaded CI runner two
seconds passed between them, and one red suite turned the required `lint-en-tests` check red on a PR
that never touched run-progress
([#2384](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2384)). Both sections now read
one instant and hand it to `Get-LiveRunProgress -NowUtc`, a parameter the lib already had. Test-only.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

run-progress tests: pin the clock the elapsed asserts read

