## fix/2068-park-cycle-unknown-exit-code

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

An unmeasurable exit code is its own state, not a gh that could not be asked.

#### What #2068 reported, and what survived checking

#2068 reports `park-cycle.tests.ps1` red under the parallel gate and green standalone, minutes apart on
an unchanged tree, with `park-cycle: gh could not be asked whether 'main' has a PR` as the observable.
Three of its claims were checked against the tree before anything was repaired:

- **The symptom stands.** That sentence is reachable only from `park-cycle.ps1`'s
  `if ($prList.ExitCode -ne 0)` arm with `TimedOut` false.
- **Its citation is right, its conclusion is not.** It says the converse direction -- red under the
  gate, green alone -- is recorded nowhere. `.claude/rules/language-layers.md` does state only the one
  direction, which is what it read. But `Invoke-TestSuiteGate`'s docstring in
  `scripts/lib/native-capture-lib.ps1` records the converse at length under #1033, names re-running the
  suite alone as the standing response, separates a crash from a verdict (#1723), and says a plain
  exit 1 under the pool is deliberately not retried.
- **Its proposed mechanism is unconfirmed, and so is the better one.** The report guesses the shim is
  "reached as absent or non-zero" under load. A likelier candidate exists in this tree: `-TimeoutSeconds`
  is always > 0 at that call, so it always takes the `-Utf8`/`Start-Process` arm, the one arm where
  `.ExitCode` can come back as literal `$null` on a clean exit (#1931, 27 of 960 under 16 lanes) --
  `$null -ne 0` is `$true`, so the fail-safe fires with that exact sentence. **It did not reproduce
  here**: see TEST.

#### So what this branch does and does not claim

It repairs the `ExitCodeUnknown` gap on its own merits -- a state that was never measured must not be
printed as a neighbouring verdict -- and records the converse direction where a session can reach it.
It does **not** claim to have fixed #2068's flake, and #2068 stays open.

The tree-wide half is **#2081**, filed from this pickup: outside the lib and its tests, this branch is
the only consumer of `ExitCodeUnknown` in `scripts/` -- 126 `-ne 0` judgements and 32 bounded capture
sites, and the audit #1931 asked for has no visible product. Deliberately not swept in here.

### CREATE

- [x] `scripts/task/park-cycle.ps1`: the PR check consults `ExitCodeUnknown`. On that state alone it
      **re-asks once**, budget-gated; `gh pr list` is read-only, so a second draw costs nothing but the
      call. This is not the retry #1931 declined -- that was re-READING one handle inside 200ms -- and it
      cannot live in the lib, which cannot know a command is idempotent.
- [x] The refusal went from **two wordings to four**. It had a stall and "could not be asked", and an
      exit code that is not a measurement was folded into the second -- sending a reader to check a `gh`
      installation that was never the problem. Same shape #1628 and #2056 each repaired once in this
      family. It is four rather than three because the re-ask is budget-gated, so "asked once, unreadable"
      and "asked twice, unreadable" are different facts about the run.
- [x] `$reAsked` tracks whether the re-ask actually ran, because the three-condition gate means a spent
      budget skips it and lands at the refusal in the SAME state a failed re-ask leaves. Victor caught
      the first draft wording that arm "answered twice over" unconditionally -- this branch's own defect,
      one `elseif` over: a sentence describing a run that did not happen.
- [x] The fail-safe arm is untouched: `$null -ne 0` stays true after a failed re-ask, so an unknown
      answer still does not push and the DEPLOY lock still holds.
- [x] `.claude/rules/language-layers.md`: the converse direction named beside the one it stated, with
      the pointer to #1033. That page is the one a session loads on a `scripts/**` edit, which is why
      stating one direction there reads as the whole rule -- and is how #2068 came to be filed.
- [x] Mirror regenerated (`park-cycle.ps1` is a shared script).

### TEST

- [x] A repro harness was built and run, because #2068 named one as the next step: fresh `powershell`
      children, each making one bounded capture of the suite's own `gh` shim, counting
      `ExitCodeUnknown` and whether `-ne 0` would fire. **0 of 600 at 16 lanes** -- against #1931's 2.8%
      at the same lane count.
- [x] The instrument was validated before the negative was trusted: the same harness against a shim
      that exits 1 caught **40 of 40**. So the zero is a real zero, not a probe that measures nothing.
- [x] What that means, stated rather than glossed: the mechanism fits the symptom exactly and is the
      only one measured in this tree, but its rate is environment-dependent -- a light probe at 16 lanes
      is not a gate at 30 lanes under memory pressure -- so it is **not established** as the cause.
- [x] New structural case (v) in `scripts/tests/park-cycle.tests.ps1`: the field is consulted, the
      re-ask is budget-gated, and the fail-safe arm still decides.
- [x] Two more asserts in (v), earned by the review finding: exactly one arm claims two asks, and it
      fires only when `$reAsked` says the re-ask ran. A defect caught by eye gets a test so the next one
      is not. `OK: all 126 asserts passed.`
- [x] `scripts/tests/native-capture.tests.ps1` caught the re-ask under the gate, correctly: it pins the
      count of `Test-NativeCaptureBudgetHasRoom` in `park-cycle.ps1` **exactly**, so a dropped guard is
      red rather than a silently weaker promise (#1958). A conditional second `gh` call is a call like
      any other and owes the same check, so the pin moves 4 -> 5 and names the re-ask. `204 pass, 0 fail.`
- [~] Dropped: a behavioural case for the retry and the third wording. The state is a race inside
      `System.Diagnostics.Process`, not anything a shim controls, so the only way to reach it is to
      inject a fake capture result -- which asserts against the mock and not the script. The gap is
      named in the case's own comment rather than papered over.

### DEPLOY: fix/2068-park-cycle-unknown-exit-code

`park-cycle.ps1`'s PR check no longer reports an exit code it could not read as a `gh` it could not
ask. That call always takes the `-Utf8`/`Start-Process` arm -- `-TimeoutSeconds` is never 0 there --
and that is the one arm where `.ExitCode` comes back as literal `$null` after a **clean** exit (#1931).
`$null -ne 0` is `$true`, so the fail-safe fired and told the reader `gh` could not be asked, while
`gh` had answered and its answer was sitting in `Output`.

On that state alone the check now **re-asks once**, gated on the same network budget as every other
call in the hook. That is not the retry #1931 declined: that one re-read a single handle inside 200ms
and still left 7 of 240 unresolved, where this is a fresh child and an independent draw. It belongs at
the call site rather than in the lib for the reason the lib cannot act on -- `gh pr list` is read-only
and safe to repeat, and the lib cannot know that of a command in general. If the re-ask comes back
unreadable too, the refusal fires exactly as before -- with a wording that says which of **four**
states it is in, where there were two. Four rather than three because the re-ask is budget-gated: an
unreadable code asked once and one asked twice are different facts about the run, and only a flag set
inside the retry can tell them apart afterwards. The fail-safe direction is unchanged: an unknown
answer still does not push.

`.claude/rules/language-layers.md` now also names the direction it was missing. It stated that a suite
**green under the gate and red standalone** reports a real defect; the converse -- red under the gate,
green alone -- is the commoner event and the opposite verdict, and it was recorded only inside
`Invoke-TestSuiteGate`'s docstring (#1033, with #1723's crash/verdict split beside it).

**This does not claim to close #2068, and that issue stays open.** A repro harness built for it came
back **0 of 600 at 16 lanes** where #1931 measured 2.8%, with the instrument validated at 40 of 40
against a shim exiting 1. The mechanism fits the reported symptom exactly and is the only one measured
in this tree; its rate is environment-dependent, and a light probe is not a loaded gate. What
is repaired here is repaired because it is wrong on its own terms.

**Score:** 2

#### What makes this deploy extra special

`park-cycle.ps1` ships in `dkj-policy` and runs as a consumer's `cycle-autopark` Stop hook, so this
sentence is one a consumer reads on their own machine with none of this tree's context. Sent to check a
`gh` that was working, they find nothing wrong and learn to distrust the note -- on the one hook whose
whole job is to get unattended work onto origin before a session ends.

**Score:** 2

#### Pull Request

park-cycle reports an unreadable exit code as itself
