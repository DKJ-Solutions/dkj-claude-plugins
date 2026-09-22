## feat/2263-suite-bound-scaling

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

Verify the issue's inferred mechanism before building: it names the lane count as the cause, and the code order says the gate does not even hold that number when it sets the deadline.

#### What #2263 reports, and which half of it survived verification

#2263 is deliberately not a proposal -- it lists three shapes and says none has a measurement behind
it. So the assignment is the measurement, and two of the issue's own claims did not survive it.

**The claim that the lane count is in hand when the bound is set is false.** `$suiteDeadline` is
resolved at the top of `Invoke-TestSuiteGate`, about eighty lines before `$MaxParallel` is resolved
from cores and memory, and the final clamp to the queue's own length is later still. Nothing about the
repair turns on this -- the bound simply has to be read where the lane count exists rather than where
it does not -- but the issue's "the one the gate already holds in hand at that moment" is not a fact
about this code.

**The claim that lane CONTENTION is the mechanism is backwards, and that half does change the
repair.** The issue reads a 9-lane run as slower-per-suite than a 22-lane one and infers that fewer
lanes make a suite slower. Instrumented with `scripts/maintenance/reproduce-suite-contention.ps1` --
the tool built for exactly this question, and the instrumentation #2263 says was never done --
contention runs the other way on one machine, one suite (`connectors.tests.ps1`):

Ratios are against **53.4s**, the slower of the two standalone readings, so every row is the
conservative reading of the same baseline:

| busy siblings | duration | vs 53.4s standalone |
|---|---|---|
| 0, settled machine | 53.4s, 50.5s | 1.00x, 0.95x |
| 3 (4 lanes) | 53.4s, 53.2s, 53.6s | 1.00x |
| 13 | 118.0s | 2.21x |
| 23 (24 lanes) | 198.9s, 188.1s | **3.72x, 3.52x** |

More lanes make a suite **slower**. So a bound scaled by the lane count would be most generous exactly
where suites run fastest, and the shape #2263 points hardest at is the one shape that cannot be built.
The 9-lane run was slow for a reason its lane count only *reports*: that machine was memory-starved,
which is why #2121's formula opened 9 lanes there at all. Measured separately on the same box, a
standalone run with 46 resident powershell processes draining took 95.4s against 53.4s settled -- 1.8x
from machine load alone, with no gate lanes involved.

#### What the repair is keyed on instead, and why all three readings agree on it

The quantity that tracks the failure is the **pace of the whole run against the recorded one**: the
seconds the finished suites actually spent, over the seconds `suite-durations.json` records for those
same suites. That is what the code computes, and it is immune to how well the pool was packed, because
both halves are per-suite runtime.

The three rows below are a **reconstruction** of that ratio and not the ratio itself -- #2263's runs left
wall clock and a lane count, not per-suite tables -- so what is recoverable is each pool's wall clock
against the 6,253.7 lane-seconds its rows sum to, over its lanes:

| #2263's reading | lanes | wall | ideal | reconstructed pace |
|---|---|---|---|---|
| the fast idle workstation | 24 | 300s | 261s | 1.15x |
| the same box, critical-path bound | 22 | 421.2s | 284s | 1.48x |
| the memory-starved box that hit the bound | 9 | 1,890s | 695s | **2.72x** |

**A pool's tail drains with lanes standing idle**, so wall clock charges a run for capacity nobody was
using and every figure here is an *upper* estimate of what the summed-duration ratio would have read.
That is stated rather than glossed, because a basis nobody re-checked is the defect this whole area is
being repaired for. The conclusion survives it: at 2.72x the recorded 669.1s of
`check-plugin-integrity-docs.tests.ps1` predicts **1,820s**, within about one percent of the 1,800s bound
that killed it -- and even at 1.8x, well below the estimate, the bound would be 3,240s and that file
finishes. Both figures are asserted. No lane-count model predicts the failure at all.

#### Two things this branch does NOT do, and one it inherited

- **It does not derive a per-suite bound from `suite-durations.json`.** #2255 declined that and was
  right to: that file is measured on CI, a local reading does not convert, and the sign is not even
  fixed. Nothing here converts anything -- both halves of the pace ratio are seconds from the same
  suites in the same run, so whatever makes CI and a workstation incomparable divides out. The
  constant's own comment already called itself "an upper bound on patience, not a model of any suite",
  and keeping it exactly that is what makes the objection not reach this shape.
- **It does not raise the constant.** 1,800s is now the **floor**, unchanged for every run at or faster
  than the recorded pace, so no currently-green run can be turned red by this.
- **The comment's basis moved underneath it while this was being written.** It sized 1,800s off
  `new-branch.tests.ps1` at 290.2s in a hints file of 91 rows. #2252's refresh landed today, took it to
  121 rows, and moved the maximum to 669.1s -- so the claimed headroom fell from ~6x to ~2.7x with no
  line of the lib changing. Corrected here, since the branch is rewriting that paragraph anyway. The row
  count is deliberately not restated as a coverage claim: the directory already holds 122 suites, one
  having merged after the run those rows came from, and a suite with no row simply contributes no pace
  sample.
- **The three pace figures are computed from TODAY's recording, not from the file as it stood at the
  time.** Each of those runs executed 121 suites; the file then held 91 rows summing 3,747.3
  lane-seconds, against today's 121 rows summing 6,253.7. Using the current, more complete recording is
  the right basis precisely because the older one was missing thirty suites -- but it is a
  reconstruction, and it is named as one rather than presented as what those runs would have computed
  about themselves.

#### The ordering against PR #2262 (issue #2255) -- settled and done

#2262 rewrote the same comment block. It was a **prerequisite, not a competitor**: this branch settles
the question it explicitly parks ("whether 1800 is the right constant is a third question, deliberately
not settled here"), and its "why it is still a fixed constant" paragraph stops being true once this
lands. Dave's call was to ship #2262 first and reconcile; it merged as `889c018e` and this branch then
merged `main`.

Two things about that ordering are worth keeping:

- **#2262 needed `-SkipStaleCheck`**, recorded on the PR. `ship-pr` refused twice on #1292's staleness
  guard having spent both #2087 forward laps -- the trunk took merges from two other sessions at 09:25Z
  and 09:38Z while a certifying run takes ~15 minutes, so every lap was overtaken. The window was
  proved disjoint before the valve was used, three-dot from the merge base: main gained two hook scripts
  and `hook-stdin-guard.tests.ps1`, this branch touches the capture lib and its own suite, intersection
  empty, and that new suite neither dot-sources the lib nor asserts on its content.
- **The conflict resolution kept both accounts rather than choosing one.** #2262's retraction and its
  printed discriminator stand unchanged. Its argument against a per-suite bound derived from CI rows
  also stands -- and is now stated as what this change honours, since a within-run ratio converts
  nothing. What was corrected is the half #2252 retired (91 of 121 rows) and the CI figure that moved
  with it (290.2s -> 669.1s).

#### One defect this branch caused and caught, recorded because it is the class the branch is about

Resolving that conflict with a PowerShell here-string that had no trailing newline glued
`$script:GateSuiteTimeoutSeconds = 1800` onto the end of a comment line. **The file still parsed**, so
the syntax check said OK while the constant was never assigned and every bound resolved to 0. Caught by
the suite, in seconds, because the asserts read the printed figures rather than trusting the parse --
which is the same "well-formed wrong output" class `.claude/rules/language-layers.md` records for a
`sed` substitution that wrote valid ASCII and the wrong characters.

### CREATE

- [x] `Get-TestSuitePaceScale` in `scripts/lib/native-capture-lib.ps1` -- a pure judgement over three
      numbers: the recorded cost of the finished suites, what they actually spent, and how many there
      were. Two independent floors on the evidence (5 suites AND 60s of recorded mass), and clamped so
      it can never return less than 1.0.
- [x] `Get-TestSuiteDeadlineSeconds` -- the floor/ceiling clamp, with a non-positive base carried
      through untouched so `-SuiteTimeoutSeconds -1` stays off.
- [x] `$script:GateSuiteTimeoutCeilingSeconds = 3600`, with the measurement that sized it: twice the
      1,820s the worst honest reading in this repo's history needed, and still 2.4x inside the
      141-minute wedge #1941 measured.
- [x] Wire both into `Invoke-TestSuiteGate`: accumulate the pace sample as each suite is reaped
      (excluding timed-out and crashed rows, both of which would bias the ratio downwards), and
      **re-read the bound on every poll pass** rather than stamping it when a lane opened -- the queue
      dequeues longest-first, so the heaviest file opens at t=0 when there is no pace to read yet.
- [x] Only the resolved default scales. An explicit `-SuiteTimeoutSeconds` is a number somebody chose,
      and `native-capture.tests.ps1`'s #2233 fixture asks for 25s precisely to make a wedge reachable.
- [x] Announce it: the opening line says the bound is a floor that rises, and one line per change names
      the figures it was made on.
- [x] And say it on the VERDICT where the bound had already been raised. #2255's discriminator -- "a slow
      suite CAN reach that bound, re-run it alone" -- is the right default and the wrong one once the
      scaling has already paid out: a suite that overran a bound widened to fit a machine measured slow
      has spent that allowance and blown it anyway, which moves the weight back towards a wedge. Without
      this a reader meets that sentence and spends the very pool it exists to save.
- [x] Correct the `1800 SECONDS` comment's stale basis (290.2s / ~6x -> 669.1s / ~2.7x after #2252).
- [x] Mirror the lib to its two plugin copies (`scripts/sync/build-shared-scripts.ps1`).

### TEST

- [x] `scripts/tests/test-suite-gate.tests.ps1` -- **26 asserts added, 0 removed** (counted off the diff,
      not by hand, after a review recount caught a claim of 19). Both pure functions are asserted row by
      row against #2263's three measured runs rather than against round numbers, including the 2.72x row
      that is the repair itself and the 1.8x row that shows the conclusion survives that estimate being
      generous. A `-PaceScale`/`-PaceScaleThen` seam on the driver (the idiom the memory and suspend
      seams already use) drives the mid-run re-read end to end: the line fires, the bound moves
      1,800s -> 3,600s, it does **not** follow a falling pace back down, and neither an explicit bound
      nor a disabled one is reached by it. After merging #2262 and adding the raised-bound note to the
      timed-out verdict: **271 pass, 0 fail.**
- [x] A defect the suite caught during the work: the ratio was first composed with PowerShell's `-f`,
      which formats in the **current** culture, and printed `2,72x` on the Dutch machine it was written
      on -- the exact defect `Format-GateSeconds` exists for (#1159). Now `[string]::Format` against the
      invariant culture, held by a source assert since an English runner cannot tell the two apart.
- [x] `native-capture.tests.ps1` (337 pass), `script-contract.tests.ps1` (386 pass), `shared-scripts`
      and `ci-shard` -- the lib's own behaviour, the mirrors and the shard partition are all untouched.

#### What the review chain changed, since two of it were real defects

- **The bound could SHRINK under a running lane** (code review). `Get-TestSuiteDeadlineSeconds` never
  returns below the floor, and that is *not* the same guarantee as a bound that only grows across a run
  -- the call site assigned on `-ne`. The pace ratio is cumulative and cumulative ratios are not
  monotonic: the early samples are taken under the heaviest contention, so the ratio peaks early and
  eases as the queue drains. A lane 2,500s into a 3,600s bound would have been killed by a 1,980s bound
  computed after it started, having never exceeded any bound in force while it ran. Now a ratchet
  (`-gt`), with the regression case the review also had to ask for, since a stub returning one fixed
  value can never drive a pace that rises and falls. **This branch's own comment claimed the property
  the code did not enforce**, which is the same defect class the branch exists to repair.
- **The ceiling could be missed by an overflow** (code review and security review, independently). The
  `[int]` cast happened before the ceiling clamp, so a large enough ratio threw out of the one function
  whose stated job is that the ceiling always catches an arbitrarily large one. Practically unreachable;
  repaired anyway, because a property the arithmetic guarantees beats one the input space happens not to
  reach.
- **Three prose defects** (copy edit): an assert count of 19 against 26 actually added, a contention
  table whose rows silently divided by different standalone baselines, and a UTF-8 BOM on this document
  that no sibling branch document carries. All three corrected above.
- **Security review found no blocking finding.** The bound cannot be disabled or driven unbounded by
  data -- the ceiling is a script constant, never read from the hints file -- and the new console line
  prints only numbers the gate computed, so it does not join this repo's list of sites that print
  foreign text. It named one thing worth recording: this is the first place `Get-TestSuiteCostHints`'
  output sizes a *safety timeout* rather than an ordering hint, and that docstring's guarantees
  (numeric, positive) were written for the ordering use. The blast radius is bounded by the ceiling and
  by the loosen-only direction.
- **Cost review found nothing to change and sized the tradeoff.** The two new calls cost ~64us per poll
  pass against a 100ms tick -- two to three orders of magnitude under the `Start-Process` and `taskkill`
  the same loop already does. `.github/workflows/ci.yml` sets no `timeout-minutes`, so both jobs take
  GitHub's 6-hour default and a 3,600s ceiling comes nowhere near it. The suite costs ~4.5s more locally
  (~8%). The real price is the one this branch already states, now with a number on it: on a run whose
  pace reaches 2.0x or more, a genuine wedge is reported up to 30 minutes later than before.

### DEPLOY: feat/2263-suite-bound-scaling

`Invoke-TestSuiteGate` bounded every suite at a fixed 1,800s, and #2255 measured what that costs on a
loaded machine: a 9-lane run spent 31 minutes to end red over `check-plugin-integrity-docs.tests.ps1`,
which passed all 188 of its asserts standalone minutes later. The bound was blind to the one thing that
decides whether a suite reaches it -- how fast the machine is actually going.

It now scales with that. As each suite finishes, the gate compares what it spent against the cost
`suite-durations.json` records for it, and the ratio of the two is how much slower this run is going
than the recording; the per-suite bound is that ratio applied to 1,800s, clamped between 1,800s and
3,600s. Nothing is converted between machines -- both halves of the ratio are seconds from the same
suites in the same run -- which is why this does not re-open the per-suite derivation #2255 declined.
Applied to the run that produced the failure, the pace reads 2.72x and the bound would have been
3,600s against the 1,820s that file needed.

**It can only ever loosen.** A run at or faster than the recorded pace is bounded at exactly 1,800s, so
no currently-green run can be turned red; an explicit `-SuiteTimeoutSeconds` and the `-1` off switch are
untouched. The cost is stated rather than hidden: on a machine slow enough to reach the ceiling, a
genuine wedge is now reported after 60 minutes instead of 30.

The issue proposed scaling by the **lane count**. Instrumented, contention runs the other way -- one
suite takes 3.7x longer under 23 busy siblings than under 3 -- so that shape would have been most
generous exactly where suites run fastest. The 9-lane run was slow because the machine was starved,
which is also why only 9 lanes opened; the lane count reports the cause rather than being it.

**Score:** 4

#### What makes this deploy extra special

`native-capture-lib.ps1` is mirrored into `dkj-policy`, so every consumer running this workflow's test
gate gets the scaled bound. It lands hardest where it is worth most: a slow or loaded machine is the one
that reaches an 1,800s bound on a green suite, and also the one least able to afford a second full gate
run spent hunting a wedge that was never there. A consumer with no `suite-durations.json` is unaffected
-- no recorded cost means no pace, and no pace resolves to exactly the bound they have today.

**Score:** 3

#### Pull Request

The per-suite test-gate bound now scales with the machine state that actually slows a suite down
