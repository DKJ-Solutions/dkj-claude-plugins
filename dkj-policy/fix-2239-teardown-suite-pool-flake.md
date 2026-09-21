## fix/2239-teardown-suite-pool-flake

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

#### What was verified before anything was repaired

The issue's reason is "the child was refused or killed rather than having said anything". That was read
against the code rather than taken: every failure path of `bootstrap.ps1` is loud (both `exit 1` branches
write a line first), and a probe child that *throws* aborts the suite's own `Invoke-Script` with a
`NativeCommandError` under its `Stop` preference -- so a real defect in the bootstrap cannot produce
`exit 1` with an empty capture. That leaves a process that died without speaking, which the lib's own
comment (`native-capture-lib.ps1`, "a killed child has an exit code of its own") says reads exit 1 on Windows.

**Not reproduced.** This checkout's machine has ~1 GB free against the reporter's 22-lane machine, and the
gate's own memory-aware count (#2121) would pick 2 lanes here, so forcing 22 would measure memory
starvation, not the reported condition. The cause of the child's death is therefore inferred, not observed.

#### The repair, and its scope

Only `New-BootstrappedConsumer` in `teardown.tests.ps1`: on a non-zero exit with an empty capture it builds
the fixture again from scratch, once, and says so. Not the teardown or re-init calls (a partly applied
teardown is not safe to repeat blindly), and not the six other suites with the same `Invoke-Script` shape --
one measured failure does not justify sweeping them.

### CREATE

- [x] `Test-SilentChildFailure` and the one-shot rebuild in `New-BootstrappedConsumer`
- [x] The final failure message names the exit code and says when the child printed nothing on both attempts

### TEST

- [x] The predicate is asserted against real children: silent exit 1, spoke-then-exit 1, clean exit
- [x] The retry is asserted both ways: silent-once recovers to a real fixture; speak-and-fail is called once
- [x] `teardown.tests.ps1` standalone: 240 pass, 0 fail (223 before)

### DEPLOY: fix/2239-teardown-suite-pool-flake

`teardown.tests.ps1` no longer fails the gate when a child `powershell.exe` dies without a word while the
suite is building a fixture. It builds the fixture again once, prints a `[NOTE]` line so the occurrence is
counted rather than invisible, and lets anything the child actually said stand as the failure.

The cause of the child dying is not established: the failure was seen once in two pool runs at 22 lanes
and was not reproduced. If a `[NOTE]` line ever shows up in a gate log, that is the next data point, and
with it the n=5 this repo asks for before a moving verdict is trusted.

**Score:** 1 -- prevents a failure that has already happened once: a red gate on a tree nobody touched,
found while measuring the gate for #2232.

#### What makes this deploy extra special

Nothing here reaches a consumer; it is one test suite. What it adds for the next reader is the argument for
why retrying is safe here and would not be for the general case: the retry keys on a state the code under
test cannot produce (a silent non-zero exit), so it cannot hide a real defect.

**Score:** N/A -- this reaches nobody outside this repo; the suite is not plugin payload.

#### Pull Request

teardown.tests.ps1 builds its fixture again once when the bootstrap child dies silent

