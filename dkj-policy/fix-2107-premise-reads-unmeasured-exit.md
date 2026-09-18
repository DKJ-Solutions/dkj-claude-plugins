## fix/2107-premise-reads-unmeasured-exit

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

#### What this repairs

`ref-print-lib.tests.ps1` asked git whether it accepts a hostile branch name, and read the answer with
`return ($r.ExitCode -eq 0)`. That reading cannot see the one state `Invoke-NativeCapture`'s
`-Utf8`/Start-Process arm is documented to produce: an `ExitCode` that is literally `$null` -- the child
ran, but the value is not a measurement of it. `#1931` measured that at 27 of 960 captures under 16
lanes, confined to the FIRST Start-Process in a fresh process, and the lib already reports it as
`ExitCodeUnknown`. This suite never consulted the field.

`$null -eq 0` is `$false`, so an exit code nobody measured read as *"git refused this ref"*, and the
premise assert then failed claiming the opposite of what had happened.

#### Why it mattered more than an ordinary red

The failure is on a PREMISE rather than on the behaviour under test, so the red says *"the guard could
not be exercised"* while reading as *"the guard is broken"*. A reader triaging it goes looking for a
regression in `ref-print-lib.ps1` and finds nothing wrong there.

And it blocked: `ship-pr` on PR #2106 refused at its stale-certificate re-lap -- *"The required check
went RED on the forwarded head -- NOT merged"* -- on a branch touching neither the lib nor this suite.

#### The half that was worse, and that nothing would have caught

The eight premise call sites ran in two directions, and only one of them went red:

    Assert-True (Test-GitAcceptsRef -Ref $x)          -- $null is falsy, so it FAILED wrongly
    Assert-True (-not (Test-GitAcceptsRef -Ref $x))   -- -not $null is $true, so it PASSED wrongly

The negative direction is the unreachable half, asserted as defence in depth. On an unmeasured capture
it went green on nothing, silently, and would have gone on doing so. The CI red was only ever the
louder symptom of the same missing state.

### CREATE

- [x] `Test-GitAcceptsRef` returns three states -- `$true` / `$false` / `$null`, where `$null` is
      *"this run could not measure it"*. `ExitCodeUnknown` is probed with the
      `PSObject.Properties[...]` idiom native-capture-lib uses on itself, since a bare read throws
      under `Set-StrictMode -Version Latest` on a capture predating the field; a `$null` `ExitCode` is
      caught as well, so neither spelling of the state can slip through.
- [x] `Assert-GitRefPremise` added, and all eight call sites go through it in both directions
      (`-Expect $true` for the reachable half, `-Expect $false` for the unreachable one). An
      unmeasured premise is reported as `[UNMEASURED]`, counted in `$script:unmeasured`, and is
      neither a pass nor a failure.
- [x] The footer prints the unmeasured count when it is non-zero, and the suite still exits 0 on it.
      A premise that could not be established is not a premise that is false, and failing the run on
      it would hand back exactly the wrong diagnosis -- the one this issue was filed on.
- [~] A retry around the capture -- dropped deliberately. native-capture-lib's own header declines it
      on measurement: `#1931` found a 200ms re-read budget still leaves 7 of 240 unresolved, so a loop
      buys an unreliable recovery at the price of wall-clock on every capture. Reporting the state is
      what the field exists for.

### TEST

- [x] The suite is green standalone: **468 pass, 0 fail**, up from 461 -- no premise was lost in the
      rewrite, and the seven added asserts are the driven block below.
- [x] All three states driven, by substituting `Invoke-NativeCapture` in this scope and restoring it
      immediately: a measured acceptance, a measured refusal, and the `ExitCodeUnknown` shape. The
      real git is still asked by every assert outside that block.
- [x] Both directions of the unmeasured case asserted to move NEITHER counter -- the negative one
      first, since that is the half that used to go green on nothing.
- [x] A capture with no `ExitCodeUnknown` property asserted not to throw, because the probe is the
      kind of line a later edit simplifies away.
- [x] The fixture gives its own two unmeasured back (`$script:unmeasured = $before`), so the footer
      warning fires only on a genuine gap. Without it the warning would print on every healthy run,
      which is how a real unmeasured premise would go unnoticed -- the same defect one layer up.
- [x] Pure ASCII confirmed by byte count (check 27), and the diff introduces no `?`: the bulk rewrite
      went through `Set-Content -Encoding ascii`, which would have silently mangled any non-ASCII the
      file held.

### DEPLOY: fix/2107-premise-reads-unmeasured-exit

A test suite read an exit code that had never been measured as though it were a refusal, so
`ref-print-lib.tests.ps1` went red on a premise -- reporting that git rejects a branch name it
accepts. The reading is now three-state, and an unmeasured capture is reported rather than asserted
on. The same blindness in the opposite direction, where the unreachable half went green on nothing,
is closed by the same helper.

**Score:** 3

#### What makes this deploy extra special

The interesting half is not the red that was visible. Six of the eight premise call sites failed
loudly on an unmeasured capture; the other two passed silently on one, and nothing in the repo would
ever have reported that. A guard asserted as defence in depth had a state in which it proved nothing
and said so to no one.

It is also a defect of reading rather than of mechanism: `ExitCodeUnknown` has existed since `#1931`,
six files already consult it, and this suite simply did not. The repair is to consult the field that
was built for exactly this, not to add anything new.

**Score:** N/A

#### Pull Request

The ref-print premise assert reads an unmeasured exit code as a refusal
