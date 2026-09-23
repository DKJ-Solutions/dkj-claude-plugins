## fix/2335-capturedir-pid-reuse

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

The fixture's CaptureDir lookup globs test-suite-gate-<pid>-* and demands exactly one hit, so a retained capture directory from an earlier, dead process with the same PID makes a red run read as having kept nothing.

#### The reason, measured before the repair

#2335 inferred a sibling suite deleting the directory. It is not deleted -- it is never *found*. The
lookup took the child's PID as unique, but red runs retain their capture directory on purpose (#1636):
this machine's temp folder held **110** `test-suite-gate-<pid>-*` leaves, with PIDs 13876 and 31180
twice and 37660 three times. A driver that draws a dead run's PID matches two leaves, the `-eq 1`
returns `''`, and exactly the four positive retention asserts fail while the two negative ones pass --
#2335's signature to the assert. Standalone re-runs pass because they draw a fresh PID.

### CREATE

- [x] `Invoke-Gate` records the child's launch time; the lookup (now `Find-GateCaptureDir`) keeps only
      leaves created at or after it.
- [x] Regression asserts on a planted stale leaf with the same PID, inside `$Fixture`.

### TEST

- [x] `test-suite-gate.tests.ps1` standalone: 328 pass, 0 fail (326 + the 2 new).

### DEPLOY: fix/2335-capturedir-pid-reuse

`test-suite-gate.tests.ps1` could go red under the local gate on a correct gate: the lookup that finds a
red fixture run's kept capture directory globbed `test-suite-gate-<pid>-*` and demanded exactly one hit,
while every earlier red run's directory is kept on purpose -- 110 of them in the authoring machine's
temp folder, PIDs already repeating. A driver drawing a dead run's PID found two and read as having kept
nothing. The lookup now also requires the directory to be newer than the child's launch, and a planted
stale leaf pins it (#2335).

**Score:** 2 -- an intermittent false-red on one suite of the local gate, costing a re-run and a
judgement call; the gate itself was always right.

#### What makes this deploy extra special

N/A -- `scripts/tests/` is not mirrored into consumers, and the gate lib is untouched.

**Score:** N/A

#### Pull Request

test-suite-gate capture lookup: ignore a stale directory left by a reused PID

