## fix/1913-gate-only-suite-failures

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

Repair the proven isolation defect in closeout-lib.tests.ps1 and make new-branch.tests.ps1 report WHY
a child exited non-zero, so the remaining gate-only failure stops being undiagnosable.

#### What was verified before anything was written

#1913's symptom stands, and reproduced on this repo's own machine: the ship of
`fix/1912-noresolves-persists-in-body` went red with **two** suites failing under the 16-lane gate --
`closeout-lib.tests.ps1` and `new-branch.tests.ps1` -- and both are green standalone. That is the
mirror image the language-layers rule already names, and it implicates shared state rather than the
subject.

**They turned out to be two different defects wearing one symptom**, which is why this branch does not
have a single fix in it:

1. `closeout-lib.tests.ps1` is **deterministic**, and the cause is proven rather than inferred.
2. `new-branch.tests.ps1` is not explained by it -- and it failed in a DIFFERENT place than #1913
   reported, which is itself evidence: a fixture defect does not move.

#### What was measured and did NOT hold

The obvious shared-state candidate for the second suite was the same environment inheritance as the
first. It is not: `new-branch.tests.ps1` run with `DKJ_CLOSEOUT_SUPPRESS=1` and `DKJ_TEST_GATE_DEPTH=1`
set by hand is **265/265 green**. Stated here rather than dropped, so the next reader does not spend
the measurement again.

### CREATE

- [x] `closeout-lib.tests.ps1`: clear `DKJ_CLOSEOUT_SUPPRESS` before the receipt is measured, assert
      that the guard is in place, and hand the inherited value back at the end.
- [x] `new-branch.tests.ps1`: `Assert-ExitCode`, which prints the child's captured stdout and stderr
      when an exit-code assert fails. All 49 exit-code asserts routed through it.
- [x] `new-branch.ps1`: the repo-root fallback is judged instead of dereferenced. It was
      `(git rev-parse --show-toplevel).Trim()` -- the first statement of the script -- so a git that
      answered nothing produced `You cannot call a method on a null-valued expression` and exit 1,
      with nothing created and no cause named. That is #1913's exact signature, measured directly.
- [x] Mirror to the plugin copy (`build-shared-scripts.ps1`).
- [ ] The 36 OTHER scripts carrying that same unjudged spelling are filed as #1917, not swept here --
      one diff across every layer of the tree is not reviewable, and several of the call sites have
      their own `-RepoRoot` precedence to read first.

### TEST

- [x] `closeout-lib.tests.ps1` green in BOTH environments -- clean, and with the variable set, which
      is the state it was red in.
- [x] `new-branch.tests.ps1` green standalone after the assert rewrite and after the script change.
- [x] The refusal asserted: run outside a repository, `new-branch` now names git's exit code and what
      git said, and still exits 1 creating nothing.
- [x] Lint gate clean; the full 102-suite gate runs at the PR, which is also the next chance for the
      remaining flake to speak.

### DEPLOY: fix/1913-gate-only-suite-failures

Two suites that go red under the 16-lane test gate and green standalone are repaired, and the second
one is made capable of saying why -- closes #1913. `closeout-lib.tests.ps1` was the proven half:
`Write-CloseOutReceipt` returns silently when `DKJ_CLOSEOUT_SUPPRESS` is set, it reads that from the
environment on purpose so the conductor's declaration crosses a process boundary, and `ship-pr.ps1`
sets it before spawning `open-pr` -- whose gate spawns every suite as an inheriting child. So the suite
was green standalone and under a bare `open-pr`, and red under `ship-pr`, dying on `$lines[0]` before
one assert about the receipt had run. The mechanism is correct; what was missing is that the suite
never owned the variable its subject keys on. It now clears it, asserts the guard, and hands the
inherited value back.

`new-branch.tests.ps1` is the half that is not yet explained, and the branch says so rather than
guessing. What it repairs is the reason nobody could explain it: 49 exit-code asserts went through
`Assert-Equal`, which reports two numbers and discards the result object -- so a red lane said
`expected: '0' / got: '1'` about a CHILD PROCESS whose stdout and stderr were already captured two
lines away. `Assert-ExitCode` prints them. Separately, the one unjudged call that reproduces that exact
signature is now judged: the script's first statement resolved the repo root with
`(git rev-parse --show-toplevel).Trim()`, and a git that answers nothing there dies on a null
dereference -- exit 1, nothing created, no cause named. The other 36 scripts carrying that spelling are
#1917.

For this repo's maintainers the change is that a red gate stops being a reason to re-run the gate. It
is noticed the next time one goes red, and invisible otherwise.
**Score:** 3

#### What makes this deploy extra special

A subscriber running this workflow gets the `new-branch` refusal, which is the half that reaches them
directly: run from a worktree, from the wrong directory, or from a skill page whose working directory
is not what they assumed, they used to get a PowerShell null-dereference naming a line number in a
script they did not write. They now get a sentence naming git's exit code, what git said, that nothing
was created, and the two ways to fix it. Nothing to migrate; it arrives with the next plugin update.
**Score:** 2

#### Pull Request

The gate-only suite failures name their cause

