## fix/2044-child-output-to-host

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

Cause found and reproduced: the scripts narrate on the information stream (Write-Host) but let each child's stdout fall into their own SUCCESS stream, so any caller that pipes or captures the run replays all child output at the end. Fix: route each narrating child spawn through | Out-Host.

#### What the issue left open, and what closed it

#2044 was filed honest about its own limits: it could not reproduce the reordering from this checkout,
concluded it was "environment-dependent", and listed three consumer-side facts a pickup would need --
ending with *"it may well turn out that there is nothing to change here at all."*

That conclusion was wrong, and the reason it was wrong is worth recording: the issue's own reproduction
ran the fixture **unpiped**, which is the one shape in which the defect cannot appear. The split is not
between stdout and stderr -- the issue correctly ruled that out -- and it is not the harness. It is
between PowerShell's **information stream** (`Write-Host`, rendered live) and its **success stream** (a
child's stdout, which is the parent script's return value, and therefore collectable). Both reach one
console in printed order for exactly as long as nobody touches the success stream.

So none of the three consumer-side facts was needed. What was needed was one more variant of the
reproduction the issue had already written.

- [x] Verify the symptom still stands, and establish the mechanism rather than accepting
      "environment-dependent" -- reproduced against a two-child fixture: `| Tee-Object` and a bare
      capture each split the run exactly as reported, unpiped runs do not.
- [x] Check the reported grouping against the mechanism. The issue's point 3 (a child's `Write-Warning`
      travelling with that child's `Write-Host`) is not evidence against a stream explanation but
      evidence FOR this one: by the time the parent sees either, both are plain text on the child's
      stdout.
- [x] Settle the parked branch `fix/2043-closeout-fillable-template` that `claim-issue` flagged as
      NOT YOURS -- read its diff: it touches `closeout-lib.ps1` and the orchestrator manual and only
      **cites** #2044. Not a rival repair, so this branch proceeds.

### CREATE

- [x] Route ship-pr.ps1's three narrating child spawns through `| Out-Host` -- step 1 (open-pr),
      the fold, and step 6 (verify-resolved-issues), the last being the one measured below the receipt.
- [x] Write the mechanism out once, at the step-1 spawn, and cite it from the other two rather than
      repeating it -- including why it is not `2>&1`, which would buy the NativeCommandError trap.
- [x] Repair the two sibling scripts carrying the identical defect, found by going looking rather than
      by report: `cut-release.ps1` (the lint gate, the longest block it relays) and
      `verify-pushed-merges.ps1` (whose loop interleaves per-PR lines with each child's output, so the
      leak also destroys which report belongs to which PR).
- [x] Re-sync all three plugin mirrors under `../plugins/dkj-policy/scripts/release/`, asserted
      byte-identical at HEAD first so the copy could not mask a pre-existing drift.
- [x] Record the trap in Sylvester's portable manual -- the source, not a lens, since it is a
      PowerShell property rather than anything about this repo -- and update the section's four counts
      and the one anchor citing its heading.
- [~] Extract a shared spawn helper -- dropped. `Invoke-NativeCapture` already exists for children whose
      output is *wanted as a value*; these three sites want live passthrough, and a helper for one
      pipeline token would hide the mechanism the comment exists to teach.
- [~] Widen the repair beyond `scripts/release/` -- dropped. The other `& powershell` sites in the tree
      are deliberate captures (`$out = & powershell ...` in `hook-check-lib.ps1`, the test suites) or
      already pipe into a renderer (`check-connectors.ps1`). Nothing else narrates and leaks.

### TEST

- [x] New suite `../scripts/tests/ordering-passthrough.tests.ps1`, dependency-free, in the house style.
- [x] The behavioural half runs the SAME two-child fixture in both shapes and asserts the leaky one
      **reorders** as well as asserting the fixed one holds -- a guard whose defect cannot be
      demonstrated is one nobody can safely delete.
- [x] Assert the fixed parent returns **nothing** down the pipe, with the leaky parent's return asserted
      as that assert's premise. This is the half that says the fix is right and not merely effective.
- [x] Assert `$LASTEXITCODE` survives the pipe for both 0 and a non-zero code -- every call site reads it
      on the very next line.
- [x] Structural half: scan the real `scripts/release/` in **both** copies for an unrouted narrating
      spawn, skipping comments and deliberate captures, plus a floor assert so the scan cannot pass
      vacuously if the spawns ever move. This is what catches the sixth site, which is the failure mode
      the issue itself had.
- [x] Verify the guard actually goes red: one site reverted by hand produced 4 failures naming
      `ship-pr.ps1:706`, and the file was restored and re-verified in sync.
- [x] Full local gate -- `check-plugin-integrity.ps1` plus every suite, via open-pr.

### DEPLOY: fix/2044-child-output-to-host

A child process's narration could arrive after everything its parent printed, so where a line was placed
stopped predicting where it was read. `ship-pr.ps1`, `cut-release.ps1` and `verify-pushed-merges.ps1`
each started their children with `& powershell`, which hands the child's stdout to the parent script's
**success stream** -- its return value -- while the parent's own `Write-Host` narration goes to the
information stream. The two reach one console in printed order only while nothing consumes the success
stream; pipe such a run, capture it, or `Tee-Object` it, and the narration prints live while every
child is collected and replayed at the end. The output is not scrambled, which is what made it hard to
read as a defect: it is every parent line in file order, then every child line in file order.

All five narrating spawns across the three scripts now route through `| Out-Host`, which keeps the
child's text with the narration and leaves the success stream empty -- where a child's console output
never belonged. `$LASTEXITCODE` is unaffected, and `2>&1` is deliberately not used.

The repair went further than #2044 asked. The issue named `ship-pr.ps1` alone and expected to need three
consumer-side facts before anything could change; none was needed, because the reproduction it had
already written only had to be run through a pipe. Going looking then found the same defect in two
sibling scripts it had not reported. `../scripts/tests/ordering-passthrough.tests.ps1` pins both halves:
that the defect is real, and that no narrating spawn in either copy of `scripts/release/` is left
unrouted.

**Score:** 3

#### What makes this deploy extra special

A consumer is where this was measured -- a ship whose output arrives grouped rather than interleaved
costs a debugging session to explain, and #2044 was filed only after a second issue had already been
misdiagnosed from the resulting screen order. Consumers running a ship in a foreground shell see no
change at all; those who pipe, capture or background one get output they can read in order again.
Conditional reach is why this is not scored higher: nothing was blocked, and the workflow no longer
depends on placement anyway.

**Score:** 2

#### Pull Request

A child process's output no longer lands after everything the parent printed
