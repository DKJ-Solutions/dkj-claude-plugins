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

Make `new-branch.tests.ps1`'s gate-only failure report WHY a child exited non-zero, and judge the one
unchecked call in `new-branch.ps1` that reproduces that failure's exact signature.

#### What was verified before anything was written

#1913's symptom stands, and reproduced here: the ship of `fix/1912-noresolves-persists-in-body` went
red under the 16-lane gate with **two** suites failing -- `closeout-lib.tests.ps1` and
`new-branch.tests.ps1` -- both green standalone. That is the mirror image
[`.claude/rules/language-layers.md`](../.claude/rules/language-layers.md) already names, and it
implicates shared state rather than the subject.

They turned out to be **two different defects wearing one symptom**.

#### The closeout half is NOT this branch's -- #1910 landed it first, and wider

This branch diagnosed it independently and proved it in one command (`DKJ_CLOSEOUT_SUPPRESS=1` makes
the suite red on demand), then repaired it by teaching the suite to own the variable. **#1910 landed
the same day with the better answer**: `Invoke-WorkflowGates` SUSPENDS the suppression before either
gate and restores it in a `finally`, which covers every suite including ones nobody has written yet --
where owning the variable covers one file. Their version is taken whole; `scripts/tests/closeout-lib.tests.ps1`
on this branch is byte for byte `main`'s.

Recorded rather than quietly dropped, because it is the answer to a question the next reader of #1913
will have: the closeout half is fixed, and it is fixed in #1910.

#### What was measured and did NOT hold

The obvious candidate for the second suite was the same environment inheritance. **It is not**:
`new-branch.tests.ps1` run with `DKJ_CLOSEOUT_SUPPRESS=1` and `DKJ_TEST_GATE_DEPTH=1` set by hand is
265/265 green. Stated here so the next reader does not spend the measurement again.

### CREATE

- [x] `new-branch.tests.ps1`: `Assert-ExitCode`, which prints the child's captured stdout and stderr
      when an exit-code assert fails. All 49 exit-code asserts routed through it.
- [x] `new-branch.ps1`: the repo-root fallback is judged instead of dereferenced. It was
      `(git rev-parse --show-toplevel).Trim()` -- the script's FIRST statement -- so a git that
      answered nothing produced `You cannot call a method on a null-valued expression` and exit 1,
      with nothing created and no cause named. Measured directly, outside a repository.
- [x] Merge `origin/main`, taking #1910's `closeout-lib.tests.ps1` whole.
- [x] Mirror to the plugin copy (`build-shared-scripts.ps1`).
- [~] DROPPED, deliberately: the 36 OTHER scripts carrying that same unjudged spelling are filed as
      #1917 rather than swept here. One diff across every layer of the tree is not reviewable in a
      sitting, and several of those call sites have their own `-RepoRoot` precedence that has to be
      read one at a time -- so the sweep is its own branch, with its own shared seam, not a tail
      appended to this one.

### TEST

- [x] A case of its own for the refusal: run outside a repository, `new-branch` names git's exit code
      and what git said, states that nothing was created, and does NOT print the null-dereference.
      It is the one failure mode invisible to every other fixture in the suite, because every other
      fixture is a real repository -- so a regression to the silent form would otherwise pass.
- [x] `new-branch.tests.ps1` green standalone: 270 asserts.
- [x] The full 102-suite gate green in 597s, with both repairs in.

### DEPLOY: fix/1913-gate-only-suite-failures

`new-branch.tests.ps1` can now say WHY it went red, and the one call in `new-branch.ps1` that could
make it go red in silence is judged -- closes #1913. The suite runs the script as a CHILD PROCESS and
asserted its exit code through `Assert-Equal`, which reports two numbers and discards the result
object: a red lane said `expected: '0' / got: '1'` about a child whose stdout and stderr were already
captured two lines away. That is why #1913 could be filed but not diagnosed, and why the same suite
going red again on September 13 -- in a DIFFERENT place, which is itself evidence that this is not a
fixture defect -- reported exactly as little. All 49 exit-code asserts go through `Assert-ExitCode`,
which prints the child's output whole.

**And the one unjudged call that reproduces that signature exactly is repaired.** The script's first
statement resolved the repo root with `(git rev-parse --show-toplevel).Trim()`: where git answers
nothing that is `$null.Trim()` -- exit 1, nothing created, and the only thing printed a PowerShell
error naming a line in a script the reader did not write. Measured directly by running it outside a
repository. It now names git's exit code, what git said, and that nothing was created. Whether that
line was #1913's own cause is **not** claimed here and cannot be from what was measured; what is
claimed is that it produces that exact signature, and that after this the next occurrence names
itself either way.

The closeout half of #1913 is fixed and is **#1910's**, not this branch's -- diagnosed here
independently, landed there first and wider, and taken whole. The 36 other scripts carrying the
unjudged repo-root spelling are #1917.

For this repo's maintainers the change is that a red gate stops being a reason to re-run the gate.
Noticed the next time one goes red, invisible otherwise.
**Score:** 3

#### What makes this deploy extra special

A subscriber running this workflow meets the `new-branch` refusal directly: run from a worktree, from
the wrong directory, or from a skill page whose working directory is not what they assumed, they used
to get a PowerShell null-dereference naming a line number in a script they did not write. They now get
a sentence naming git's exit code, what git said, that nothing was created, and the two ways through.
Nothing to migrate; it arrives with the next plugin update.
**Score:** 2

#### Pull Request

The gate-only suite failure names its cause
