## fix/2081-exitcodeunknown-audit

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

Audit every bounded (`-Utf8` / `-TimeoutSeconds`) `Invoke-NativeCapture` site outside `scripts/tests/`,
grouped by what the site does on a non-zero, and decide per family -- #1931's own ask, which its closure
never delivered. Repair the families that mislead; record the family that is already right.

#### What the audit measured, and where the issue's own number came from

48 logical call sites, not 32. `#2081` counted with a single-line grep, which misses the sixteen calls
this tree spells across a backtick continuation. The site list and the per-family verdict live in
`Test-NativeExitMeasured`'s docstring in `scripts/lib/native-capture-lib.ps1`, because a decision nobody
can find is not one -- and that is the file a later reader of `ExitCodeUnknown` opens first.

#### park-cycle's PR check is NOT in scope

`fix/2068-park-cycle-unknown-exit-code` already repairs `park-cycle.ps1:396`, and that branch is the
worked instance `#2081` was split out of. This branch touches the same file only at its collision fetch
(`Get-BranchCollisionNote`), 200 lines away, and leaves the PR check exactly as that branch has it.

### CREATE

- [x] `Test-NativeExitMeasured` and `Get-NativeExitLabel` in `native-capture-lib.ps1` -- the branch guard
      and the wording, property-guarded so an older capture object degrades to the pre-field reading
- [x] The audit's result recorded on `Test-NativeExitMeasured` itself: the four families, their verdicts,
      and why exactly one site re-asks
- [x] Family "prints a diagnosis" repaired -- a third state where the sentence named a cause nobody
      measured, the shared label where the verdict was already right and only `(exit )` was wrong
- [x] Family "reports a substantive answer" repaired -- `park-cycle`'s collision fetch no longer answers
      all-clear on a look it never judged
- [x] None of the seven writes may call itself a failure -- four say "THIS RUN DOES NOT KNOW" in those
      words, the two lower-stakes `sync-main` pushes say the outcome "is unknown here"; `open-pr`'s create routes
      into the recheck #1916 already built rather than gaining a verdict of its own
- [x] Family "refuses / fails safe" recorded as deliberate at each site, with the reason it is right
      (every one is a POSITIVE test, which is what makes `$null` land on the cautious branch)
- [x] `claim-issue`'s issue view re-asks once -- the one site where the command is idempotent AND the
      cost of not asking is the whole assignment
- [x] Plugin mirrors regenerated (`build-shared-scripts.ps1`, 18 updated)

### TEST

- [x] `native-capture.tests.ps1` extended: the direction of the trap in both spellings, the empty
      interpolation, the five verdicts of `Test-NativeExitMeasured`, both labels, and a structural pin
      that the 18 audited scripts still ask the question -- 255 pass, 0 fail
- [x] `check-plugin-integrity.ps1`: 0 errors
- [x] All suites green via `open-pr.ps1`'s gate

### DEPLOY: fix/2081-exitcodeunknown-audit

`ExitCodeUnknown` had no reader outside the lib that defines it, so all 48 bounded native-capture sites
went on judging `$r.ExitCode` against a value that is `$null` about once in 300 fresh child processes.
The direction made it worse than a wrong number: `$null -ne 0` is true, so every site that refuses on a
failure refused, and PowerShell renders `$null` as the empty string, so twelve of them printed a reason
with the number missing out of it -- `gh refused the read (exit ) -- no access, or no such branch`. The
field now has two consumers, `Test-NativeExitMeasured` and `Get-NativeExitLabel`, and the audit's verdict
per family is recorded where the next reader of the field will find it.

**Score:** 3

#### What makes this deploy extra special

Most of the repaired scripts are the ones this marketplace ships -- `claim-issue`, `open-pr`,
`new-branch`, `park-cycle`, `sync-main`, `update-plugins`, the fold. In a consuming repo the sentences
that were wrong are the ones a session acts on: *the claim failed -- #N is NOT yours* over a claim
sitting on the tracker, *git push failed* over a branch that reached origin, and `park-cycle`'s
collision detector reporting all-clear on a fetch it never read. Nothing changes on a healthy run; what
changes is what a consumer is told on the rare one, and that none of the seven writes may call itself a
failure any more.

**Score:** 3

#### Pull Request

The bounded native-capture sites audited against an unmeasurable exit code, and the ones that diagnose gain a third state
