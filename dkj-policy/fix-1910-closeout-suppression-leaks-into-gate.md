## fix/1910-closeout-suppression-leaks-into-gate

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

ship-pr's DKJ_CLOSEOUT_SUPPRESS is inherited by every descendant, including the test suites the gate spawns, so closeout-lib.tests.ps1 crashes inside every ship that re-runs open-pr with something to push.

#### What was verified before anything was changed

Reproduced twice, exactly as #1910 reports it: the suite is 72 pass / 0 fail on its own and dies on
`Cannot index into a null array` at `$lines[0]` with `DKJ_CLOSEOUT_SUPPRESS=1` in the environment.
The chain is `ship-pr` → `Push-CloseOutSuppression` (process scope, so every descendant inherits) →
`open-pr` → `Invoke-WorkflowGates` → `scripts\tests\*.tests.ps1`.

### CREATE

- [x] `closeout-lib.ps1` gains `Suspend-CloseOutSuppression` / `Restore-CloseOutSuppression` -- a
      save-and-restore pair for a run that is UNDER a conductor. `Pop-CloseOutSuppression` cannot serve:
      it is documented as unconditional, so a nested run using it would clear the flag for the
      conductor's remaining children too.
- [x] `Invoke-WorkflowGates` suspends the suppression around both gates and restores it in a `finally`.
      This is #1910's option 3, the one that stops the class: a suite nobody has written yet is covered
      without anybody remembering. The bulk of that diff is a mechanical re-indent of the function body
      into the `try`.
- [x] `gate-lib.ps1` dot-sources `command-probe-lib.ps1` (a leaf, for `Test-FunctionDefined`) and
      `closeout-lib.ps1` (guarded on the stale-mirror reasoning open-pr already gives for its own).
      Loaded here rather than asked of the caller because open-pr reaches `Invoke-WorkflowGates` on its
      `-GatesOnly` short-circuit BEFORE that script dot-sources closeout-lib -- a caller-supplied
      dependency would leave exactly one of the two gate call sites silently uncovered.
- [x] `closeout-lib.tests.ps1` states its own precondition (#1910's option 1) and `Get-ReceiptLines`
      refuses a meaningless assertion with the cause rather than a null-index crash (#1910's option 2).
      `-UnderSuppression` marks the one assert that deliberately runs under the variable.
- [x] Mirrors rebuilt with `build-shared-scripts.ps1` -- both changed libs ship to consumers.
- [x] `gate-lib.tests.ps1` gains case 15f -- the behavioural half, asking a real spawned child what it
      inherited. Added on the code review's finding that a structural regex cannot tell a deleted
      suspend from a moved one.

#### What deliberately did not change

`ship-pr`'s own behaviour under #1884. The conductor claiming the one receipt is correct and is not what
was broken; both suppression assertions on `ship-pr.ps1` in the suite are untouched and still pass.

### TEST

- [x] `closeout-lib.tests.ps1`: 83 pass, 0 fail -- and 83 pass, 0 fail with `DKJ_CLOSEOUT_SUPPRESS=1`
      in the environment, which is the exact state that crashed it.
- [x] `gate-lib.tests.ps1`: 161 pass, 0 fail -- 153 before, plus eight in a new case 15f.
- [x] **A real spawned child asserts what it inherited** -- `gate-lib.tests.ps1` case 15f, added after
      the code review named the gap: the structural regex in `closeout-lib.tests.ps1` catches the
      suspend being DELETED and misses it being MOVED below the gates, which satisfies every assert
      and reintroduces #1910 in silence. The fixture lint script -- a genuine child, spawned by the
      same `Start-Process` the real gate uses -- writes down the value it saw. Under a conductor the
      child records `[]` and the conductor's own `1` survives; on a FAILING gate it is restored too
      (the `finally`); with no conductor the gate leaves no flag behind, which is the half an
      unconditional `Pop` would also satisfy and a naive re-set to `'1'` would not.
- [x] The full gate run under `DKJ_CLOSEOUT_SUPPRESS=1` (`open-pr -GatesOnly`), which reproduces the
      reported scenario: `closeout-lib.tests.ps1` passed in 1.6s inside it.
- [x] `check-script-contract.ps1`: 0 errors.

#### One unrelated suite failed in that run, and it is not this branch's

`new-branch.tests.ps1`, two assertions in its "capped tip" case about a 400-character commit subject
being truncated. Nothing in this diff is reachable from `new-branch.ps1` or `park-lib.ps1` -- neither
dot-sources `gate-lib.ps1` or `closeout-lib.ps1`, and the only mention is a comment. Filed separately
rather than repaired here, as [#1915](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1915) -- 265/265 green standalone on this same tree, red only at 16 lanes.

### DEPLOY: fix/1910-closeout-suppression-leaks-into-gate

A gate run no longer inherits the close-out suppression a conductor sets, so `closeout-lib.tests.ps1`
stops crashing inside every ship that re-runs `open-pr` with something to push -- closes #1910.
`Invoke-WorkflowGates` suspends the flag around both gates and restores it in a `finally`; the suite
also clears it for its own duration and says so, because a test asserting on an ambient global is its
own defect.

For this repo's maintainers it removes a blocker that sat on the recovery path the staleness guard
(#1292) itself prescribes: when `main` moves under a certified run, the way out is to bring the branch
forward and re-run `ship-pr` -- and that re-run is precisely the one where `open-pr` has something to
push, so it reaches its test gate. The failure also pointed the operator at their own tests while CI
stayed green, which is the most confusing place for the two gates to disagree.
**Score:** 4

#### What makes this deploy extra special

Every consumer running this workflow ships through the same `ship-pr` → `open-pr` → gate path, and both
changed libs travel to them as plugin mirrors, so they meet this defect on the same recovery step and
with the same green CI beside it. They do not have to act: the repair arrives with the next release and
nothing on their side changes shape -- no new switch, no new file, no behaviour they have to adopt. What
they get back is the one route out of a stale-base refusal, which is a route they cannot work around
locally, since `-SkipTests` is the only alternative and that is the switch that says the run did not
measure.
**Score:** 3

#### Pull Request

Clear the close-out suppression around a gate run, and make the suite state its own precondition
