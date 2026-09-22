## fix/2295-capturedir-empty-race

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

### CREATE

- [x] `Invoke-TestSuiteGate`'s capture-retention decision reads each failing/timed-out suite's
      capture file through the same settle-budget-aware `Read-NativeCaptureFile` that
      `Write-GateCaptureBlock` already uses to PRINT it, instead of a raw `Get-Item .Length`
      (`scripts/lib/native-capture-lib.ps1`, mirrored via `scripts/sync/build-shared-scripts.ps1`).

### TEST

- [x] `scripts/tests/test-suite-gate.tests.ps1` standalone: 273 pass, 0 fail.
- [x] `scripts/tests/native-capture.tests.ps1` standalone: 337 pass, 0 fail (the settle-budget
      reader this fix reuses already carries direct coverage there).
- [x] `scripts/tests/shared-scripts.tests.ps1`: all 972 asserts pass -- the three mirrors of
      `native-capture-lib.ps1` are byte-identical again after `build-shared-scripts.ps1`.
- [x] `scripts/lint/check-plugin-integrity.ps1`: 0 errors.

### DEPLOY: fix/2295-capturedir-empty-race

#2295 measured `test-suite-gate.tests.ps1`'s capture-retention asserts going red in CI at random,
twice in one hour on two unrelated branches, always in CI and never standalone: `CaptureDir` came
back empty on a run that should have kept it, once for a genuinely timed-out suite and once for an
ordinary failing one.

The retention decision (in `Invoke-TestSuiteGate`'s own `finally` block) judged whether a suite's
output survived by calling `(Get-Item -LiteralPath $f).Length -gt 0` the instant the pool reaped it.
That races the exact ambiguity this file already named and built a fix for, twice, elsewhere
(#1679, #1731, #1252): `$proc.WaitForExit()` returning true says the CHILD process exited, not that
`Start-Process`'s own pipe-to-file copy -- running on its own thread, in this process -- has caught
up, and a grandchild that inherited the handle can hold it a moment longer still. Under CI
contention that gap widens rather than closes, which is exactly the class #2255 already measured
for this same pool one door over. `Write-GateCaptureBlock` already reads these same files through
`Read-NativeCaptureFile`'s settle-budget-aware probe when it PRINTS them a few lines above the
verdict -- the retention check was the one remaining reader of a reaped suite's capture file that
still used the unprotected form, so it could (and did) disagree with what the console had just
shown.

The retention check now reads through the same settle-aware probe, bounded by the same
`$script:NativeCaptureSettleMilliseconds` budget the print path already spends, so a suite whose
output legitimately arrived -- just not by the instant `Get-Item` was called -- is no longer read as
having written nothing and its whole capture directory deleted out from under it.

**Score:** 2 -- an occasional, CI-only false-red on the required check (`lint-en-tests`), costing a
full CI cycle plus a judgement call each time it fires; most PRs never touch this path at all.

#### What makes this deploy extra special

`scripts/lib/native-capture-lib.ps1` mirrors into every consumer that runs this workflow's test
gate as their own CI check, so the same race -- deleting a failing suite's kept evidence under the
consumer's own CI contention -- was reachable there too, not only in this repo's CI.

**Score:** 1 -- a reliability fix for a race a consumer would rarely hit and would have read as "the
gate deleted my evidence," not as something to act on.

#### Pull Request

guard the capture-retention asserts against an empty CaptureDir race

