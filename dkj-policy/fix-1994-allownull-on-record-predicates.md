## fix/1994-allownull-on-record-predicates

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

Both predicates open with a null guard a Mandatory parameter can never reach. Add [AllowNull()] to match
the sibling Get-PluginUpdateScope, and assert the behaviour.

#### The reported reason is right about one function and wrong about the other, and both were checked

#1994 says the unreachable guards break a documented promise. For `Test-PluginInstalledHere` that holds:
its doc is built entirely around the permissive answer, and `$null` is the same "I could not look" state
read one step earlier than the unreadable and absent cases it already names. For `Get-RecordShape` it does
not -- the sentence the issue quotes, "Returns `$null` ... when there is nothing to judge at all", is about
a record set holding nothing for this id, not about a `$null` argument. Repairing it on the quoted reason
would have written a promise into the doc that was never there.

The argument that does hold for it is its own standing rule, which its suites already pin: it may suppress
a finding, never invent one. A binder failure is the loudest possible way to invent one -- a caller asking
about a shape gets its whole run ended.

#### The state is reachable from a caller in this tree, which is what makes it a repair

`scripts/task/check-policy-drift.ps1` sets `$installRecord = $null` and fills it inside a `try`/`catch`, so
a throw in `Get-InstallRecord` leaves exactly that value at exactly this call site. It carried
`if ($installRecord -and ...)` to keep it away from the binder. `Get-InstallRecord`'s own happy path never
returns `$null` -- one `return`, always a `pscustomobject` -- which is why nothing was broken today and why
this was a latent contradiction rather than an outage.

### CREATE

- [x] `[AllowNull()]` on `$InstallRecord` in `Test-PluginInstalledHere` and `Get-RecordShape`, each with its
      own argument for the answer it gives, in `scripts/lib/check-report-lib.ps1`
- [x] `Get-PluginUpdateScope`'s doc block rewritten -- it asserted the inconsistency this branch removes
- [x] the redundant `$installRecord -and` clause dropped at `check-policy-drift.ps1`'s call site, with the
      reason stated rather than the line silently deleted
- [x] mirrors regenerated (`scripts/sync/build-shared-scripts.ps1`) -- 4 updated

### TEST

- [x] four asserts added to `scripts/tests/check-report-lib.tests.ps1`, each wrapped in a `try`/`catch`: a
      regression here is a TERMINATING error rather than a wrong value, and a bare call would end the suite
      instead of failing one assertion
- [x] `check-report-lib.tests.ps1`: **308 pass, 0 fail**, with the four new asserts confirmed by name in the
      output
- [x] full lint + test gate via `open-pr.ps1`

### DEPLOY: fix/1994-allownull-on-record-predicates

Two predicates in `check-report-lib.ps1` -- `Test-PluginInstalledHere` and `Get-RecordShape` -- each opened
with an `if ($null -eq $InstallRecord)` line that had never once run. A `Mandatory` parameter rejects
`$null` during BINDING, with `ParameterArgumentValidationErrorNullNotAllowed`, before a line of the body
executes, so each function's documented answer for that input was a promise its own signature broke.
`[AllowNull()]` makes both reachable, which is the choice the sibling `Get-PluginUpdateScope` already made
deliberately for the same reason.

**The three answers stay different, and that is the point.** They are not one contract repeated: the
permissive predicate answers `$true` because an absent authority is not evidence of absence, the shape
predicate answers `$null` because it may suppress a finding and never invent one, and the scope function
answers a usable `project`/`default` because every caller needs something to put in a command. Three
answers to one input is why the attribute is repeated three times rather than factored into a shared
validator.

**One caller proved the state is real.** `check-policy-drift.ps1` sets `$installRecord = $null` and fills it
inside a `try`/`catch`, then guarded its call site with `if ($installRecord -and ...)` -- a clause
hand-rolling the contract the signature would not honour. It is gone, with the reasoning left at the line,
and the behaviour is identical: `$true` means the guarded branch is not taken either way.

**The issue's reason was half right, and the half that was wrong is recorded in the code.**
`Get-RecordShape`'s doc never promised a `$null` answer for a `$null` argument. Repairing on the quoted
reason would have written a promise into the doc that was never there; the argument that does hold is the
direction-of-error rule its suites already pin.

**Score:** 2

#### What makes this deploy extra special

Nothing here was broken today -- `Get-InstallRecord` never returns `$null`, so no run has ever reached the
binder. That is exactly what makes it worth four asserts rather than a one-line edit: a latent contradiction
between a doc and a signature is invisible until somebody writes the caller that meets it, and #1986
measured that happening, in this same file, to a new sibling written from the same template.

**Score:** 1

#### Pull Request

Make the null guards in Test-PluginInstalledHere and Get-RecordShape reachable
