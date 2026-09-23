## fix/2364-parallel-gate-flaky-suites

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

#2364 reports two suites red under the 22-lane open-pr gate and green alone. The run's own kept
capture is gone, so each suite is judged on what can still be measured: a kept capture from another
gate run on this machine, and `reproduce-suite-contention.ps1` against the suite itself.

### CREATE

- [x] `test-suite-gate.tests.ps1` case 10 (the deadline): a kept 22-lane capture
  (`test-suite-gate-26272-...`, 68 powershell processes resident) shows the one-line `s-quick`
  sibling killed at the 3s bound after 8.6s, which failed "keeps its plain header" and the verdict
  line. #2005 took the six 1.2s sleepers out from under that ceiling and left `s-quick` under it.
  The bound is now sized for the sibling (20s), with the sleeper (120s) and the wall-clock assert
  (<90s) scaled so the case still tells a fired bound from a waited-out one.
- [x] `test-suite-gate.tests.ps1`, six lane-count asserts (two of them found in review): the verdict line appends optional notes
  after `(N lanes)` -- #2317's lane-hold note among them, printed when free memory is below the floor,
  i.e. under the full pool. Anchoring `)` straight to `.` or `:` reds those asserts under load; three
  failed that way in a standalone run beside a 22-lane repro. They now allow the trailing notes.
- [x] `test-suite-gate.tests.ps1` case 9d (the issue's own four asserts): no capture survived and no
  cause could be measured, so none is claimed. A red nested run now prints the driver's last 25
  lines, so the next sighting carries its evidence.
- [x] `check-plugin-integrity-fixture.ps1` `Invoke-Integrity` (the issue's scripts-suite assert): the
  gate prints every finding only at the end, above `Summary: N error(s).`, so a child that stops
  part-way loses them all and the scenario reads "not reported". In the report all 58 asserts ran,
  the in-process precondition passed and only the output assert failed -- the shape of an unfinished
  child. A run with no Summary line is now named (`[FIXTURE GATE DID NOT FINISH]`) and run once more;
  a second unfinished run is returned as it is, so a gate that really dies still fails. Inferred, not
  reproduced: a 22-lane focus run was stopped after one green repeat (~12 min each).

### TEST

- [x] All seven `check-plugin-integrity-*.tests.ps1` suites green standalone, with zero
  `[FIXTURE GATE DID NOT FINISH]` notices -- the guard is silent on a healthy run.
- [x] `test-suite-gate.tests.ps1` beside a 22-lane repro: the deadline case passed at 34.9s against
  the 120s sleeper; the three lane-count asserts that failed in that run are the ones loosened
  after it. The whole suite runs again under the open-pr gate's full pool.

### DEPLOY: fix/2364-parallel-gate-flaky-suites

Three causes behind "red under the parallel gate, green alone" in two test suites, repaired in the
suites and nowhere else. A one-line sibling in the deadline case was held to a 3s ceiling it cannot
meet under load (8.6s measured); six lane-count asserts refused the lane-hold note a memory-starved
run appends; and the integrity fixture read a child gate that stopped before its report as a gate
that found nothing. The fourth symptom the issue names, the nested-gate case, has no surviving
capture, so it now prints its own evidence when red instead of being given a guessed cause.

**Score:** 2

#### What makes this deploy extra special

N/A -- test suites only; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

Two suites fail under the parallel open-pr gate and pass alone

