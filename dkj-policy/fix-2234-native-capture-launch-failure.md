## fix/2234-native-capture-launch-failure

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

Both arms of Invoke-NativeCapture throw when the executable is absent, so the two unguarded gh call sites (new-branch's already-done check, fold-changelog's PR enrichment) die instead of degrading as their docstrings promise. Add a NotStarted state on the ExitCodeUnknown axis, and repair the call sites that compose a sentence around the number.

### CREATE

- [x] `New-NativeNotStartedCapture` + `Test-NativeCommandStarted` in `../scripts/lib/native-capture-lib.ps1` -- the third state on ExitCodeUnknown's own axis
- [x] Guard the launch on BOTH arms -- and on both SHAPES: `CommandNotFoundException` (not found) and `ApplicationFailedException` (found, loader refuses the image) on the `&` arm, `InvalidOperationException` for both on the Start-Process arm
- [x] `Get-NativeExitLabel` gains the not-started sentence, asked AHEAD of the unmeasured one
- [x] `Get-GitFileTextAtRef` -- its refusal stops telling the reader to re-run when git is simply absent
- [x] `../scripts/task/new-branch.ps1` -- both gh calls degrade; one stops printing "(exit )", the other stops claiming "gh ran"
- [x] `../scripts/release/open-pr.ps1` -- the twin of that second site, kept in step because new-branch's comment says it is
- [x] `../scripts/release/fold-changelog-entry.ps1` -- the same two repairs on the PR enrichment
- [x] `../scripts/task/park-cycle.ps1` and `../scripts/task/claim-issue.ps1` -- neither re-asks a command that never started, and each names the state; claim-issue's WRITE arm stops saying the claim "may be on the tracker already" when nothing was sent
- [x] Mirrors rebuilt (`build-shared-scripts.ps1`)

### TEST

- [x] `native-capture.tests.ps1` -- four entry shapes across both arms return a verdict; `$ErrorActionPreference` restored on the early return; an ordinary call and a ran-and-failed call are untouched
- [x] `claim-issue.tests.ps1` (343 pass) and `park-cycle.tests.ps1` (138 pass) -- structural pins on both re-ask guards
- [x] `fold-changelog.tests.ps1` -- 268 pass, unchanged
- [x] Measured by hand against a PATH with no `gh`: every arm returns, nothing throws

#### The named test gap

An absent `gh` cannot be fixtured -- it is a PATH with no `gh` on it, which is machine state rather than
a shim -- so the two re-ask guards are pinned structurally and the end-to-end run was measured by hand.
The lib itself IS fixtured behaviourally, with a guid-suffixed name that cannot collide with something
a developer happens to have installed.

### DEPLOY: fix/2234-native-capture-launch-failure

`Invoke-NativeCapture` threw when the executable was absent, so a caller got an exception where the
whole point of the function is that it gets a verdict. Under `$ErrorActionPreference = 'Stop'` -- which
every task script in this workflow sets on line 1 -- that ended the run rather than the one call. It now
returns a capture carrying a new `NotStarted` field, and the two optional `gh` calls that used to die
degrade the way their own docstrings already promised.

The report measured the `Start-Process` arm. The `&` arm threw too, earlier and for a different reason:
command discovery raises `CommandNotFoundException`, which is terminating regardless of
`$ErrorActionPreference`, so the function's own preference dance never reached it. Both arms are
repaired -- a fix on one would have left `gh` fatal on every unbounded call in the family, which is most
of them.

`ExitCodeUnknown` is set on the new state deliberately, so all 63 bounded call sites keep working
untouched; `NotStarted` only says which of the two reasons it is. The four sites that needed more than
that got it: two that composed a sentence around a number that is now `$null`, and two that would have
spent a re-ask relaunching a command that is not installed.

**Score:** 3

#### What makes this deploy extra special

Anyone adopting this workflow before installing the GitHub CLI -- the first hour of every adoption --
met this as a dead `new-branch` run that created no branch and no development document. On such a
machine `fold-changelog.tests.ps1` also ran red, 20+ asserts across four fixture scenarios, every one
reporting a fold that never ran; that half is felt by whoever runs this repo's suites without `gh`,
not by a consumer, who never runs them. And `claim-issue`'s documented *no account* refusal never
printed on the one machine state it was written for, because the read above it threw first. All three
are gone.

**Score:** 3

#### Pull Request

Invoke-NativeCapture returns a verdict instead of throwing when the executable cannot be started

