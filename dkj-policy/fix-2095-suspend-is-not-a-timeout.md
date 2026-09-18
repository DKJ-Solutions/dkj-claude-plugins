## fix/2095-suspend-is-not-a-timeout

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

#### The defect, verified against the tree before anything was written

#2095 reports that the #1941 per-suite bound counts machine suspend. Verified in
`scripts/lib/native-capture-lib.ps1`: the pool times itself on a `Stopwatch` (`$sw`), each lane
records its `StartOffset` off that same clock, and the deadline sweep judges
`$sw.Elapsed.TotalSeconds - $r.StartOffset` against the bound. A `Stopwatch` keeps accruing while the
machine is suspended, and nothing in that arithmetic subtracts it -- so the first poll after a wake
reads every open lane as hours past a 1,800s bound and kills whichever suites happened to be in
flight. The report's measurement (a single 10,896s discontinuity in the run's own progress stream,
0-6s of CPU behind it, exactly the two running suites killed) is what that code produces, and the two
suites it named are not broken.

#### The option chosen, and the one that was measured and declined

#2095 listed three directions and asked whoever picked it up to check them against #1941's own
measurement, since that issue's subject -- a genuinely deadlocked 30-lane tree -- must still be
caught.

- **Detect the discontinuity (chosen).** The poll loop sleeps 100 ms and goes round again, so a gap
  no poll could have produced is a jump nothing ran across. It needs no new dependency, and a
  deadlocked tree produces no gap at all -- the loop keeps polling while the suite does not move --
  so #1941 keeps its bound.
- **`SystemEvents.PowerModeChanged` (declined).** It needs a message pump to deliver, which a
  redirected console child running a scheduler loop does not have: a dependency bought for a signal
  that may never arrive.
- **Judge a lane on CPU consumed (declined, and this is the one worth writing down).** It cannot tell
  the two states apart, because **a deadlock burns no CPU either**: #1941's own measurement is 0.23s
  of CPU across 29 children over 141 minutes -- the same near-zero the suspend case shows. A signal
  that reads identically in both states is not a discriminator, and building it would have disarmed
  the bound for exactly the case it exists for.

#### The one judgement call inside the chosen option

**Rebase the open lanes, not the clock.** Both fix the bound; only this one is right about a lane the
suspend did not touch. A lane opened after the wake has its `StartOffset` on the far side of the jump
and must be judged from there -- subtracting globally would hand it a credit for a sleep it was not
alive for. It also leaves every reading of `$sw` honest, so the progress line, the per-suite table and
the verdict go on reporting the wall clock the run really occupied; the verdict says separately how
much of it nothing was running for.

### CREATE

- [x] `$script:GateSuspendGapSeconds = 300` in `scripts/lib/native-capture-lib.ps1`, with the
      measurement it is sized off: #2095's own run carried five gaps over 60s, four of them 62-99s,
      all honest reap passes. 300 is ~3x the largest of those and a sixth of the bound it protects.
- [x] `Get-GateSuspendCredit` -- the pure judgement, and the seam a test can stage a suspend through.
- [x] The poll loop checks its own clock at the top of every pass, ahead of the launch block, and on
      a jump rebases every open lane's `StartOffset` -- and its `KilledAt`, or a lane killed just
      before the suspend would be abandoned on the first pass after the wake as a tree that refused
      to die.
- [x] It says what it measured on its own line, and the verdict carries
      `[Ns of that was machine suspend, issue #2095]` -- absent on every ordinary run, so nothing
      that already reads that line sees a byte it did not see before.
- [x] The two plugin mirrors rebuilt via `scripts/sync/build-shared-scripts.ps1`.

### TEST

- [x] Seven in-process asserts on `Get-GateSuspendCredit` itself, including the two that pin the
      sizing: 99s (the largest honest gap #2095 measured) credits nothing, and the 10,896s jump is
      credited **in full** rather than minus the threshold.
- [x] An end-to-end case with its own fixture directory (#2005's lesson), run **twice against the
      same 3s bound and the same 5s sleeper**: without the jump it TIMES OUT, with a staged 30s jump
      the suite finishes and the gate is green. The negative control is the case -- every other
      assert would also pass on a gate that had simply been given a bigger bound.
- [x] The jump is staged through the seam, the way #1464 shadows `Get-ResidentPowerShellCount`,
      because nothing in a fixture can suspend a laptop. What that leaves unproven is the
      **threshold**, which is what the in-process asserts cover; everything downstream of the
      judgement -- the rebase, the sweep, the verdict -- is the real thing.
- [x] `test-suite-gate.tests.ps1`: 223 pass, 0 fail (207 before this branch).
- [x] `check-plugin-integrity.ps1`: 0 errors.

### DEPLOY: A machine suspend no longer counts against a suite's bound

The test gate's per-suite bound (#1941) is measured off a `Stopwatch`, which keeps counting while the
machine is suspended. An unattended overnight run therefore woke to find every open lane hours past a
1,800s bound, killed the two suites that happened to be in flight -- both of which pass in seconds --
and refused the push with *"Fix the tests"*, naming a defect that did not exist in two files picked by
nothing more than which lanes were open at suspend. The gate now watches its own clock: a jump no
100 ms poll could have produced is credited back to the lanes that were open across it, and the
verdict says which part of its own seconds nothing was running for. A deadlocked tree produces no such
jump -- the loop goes on polling while the suite does not move -- so #1941 keeps its bound.

Resolves #2095.

**Score:** 4 -- it silently turns innocent suites into a red gate and costs the whole of an unattended
run, and the remedy it printed sent the reader after a defect that does not exist. Anyone running this
gate on a laptop meets it the first night they leave one going.

#### What makes this deploy extra special

It plausibly answers #1704, which closed with *"cause not established"* over a gate that reported
11,112s for a pool it runs in ~225s -- the same shape as #2095's 11,749s, a normal run plus one
multi-hour discontinuity with no CPU behind it. #1941's bound was filed off that same investigation,
so the bound had been converting an unexplained stall into an unexplained test failure.

It also writes down the option that was measured and **declined**: judging a lane on CPU consumed
cannot tell a suspend from a deadlock, because #1941's own wedged tree burned 0.23s across 29 children
over 141 minutes. Building it would have disarmed the bound for the one case it exists for.

**Score:** 2 -- a consumer of this workflow gets a gate that stops failing them overnight, but the
reasoning above is for whoever next touches the bound.

#### Pull Request

A machine suspend no longer counts against a suite's bound
