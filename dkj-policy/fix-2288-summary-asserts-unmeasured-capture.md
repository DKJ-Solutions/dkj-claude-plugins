## fix/2288-summary-asserts-unmeasured-capture

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

#### What #2288 is, and why it is a blocker rather than a footnote

`#2114` repaired a suite that asserted exit 0 on eight scenarios regardless, by giving
`Assert-CleanExit` a third state for a capture with no measurable exit code (#1931). That repair
holds and is not touched here. What it did not cover is two asserts in scenario 1 that read the
**same** capture through the script's summary line:

- `update-plugins.ps1` counts an unmeasurable capture as a failure -- deliberately, argued at
  `scripts/task/update-plugins.ps1:207`.
- So the green summary at its line 254 is never printed in exactly the runs `Assert-CleanExit` waves
  through; line 257's red one is printed instead.
- Scenario 1's two `Assert-Has` calls were looking for the green line, so they were red **by
  construction** whenever the yellow line appeared above them.

`Assert-CleanExit`'s docstring states the bound it believed it had -- *"which commands ran, with which
ids, at which scopes, in which order -- is unaffected by this state"*. True, and it is why those
asserts were correctly left alone. The summary line is not in that class: it is composed from the
failure counters, which is the one field the race owns.

#### Measured here, twice in two

Full-gate runs on this machine, September 22, 2026, while landing an unrelated branch:

- 5 lanes: `Result: 52 pass, 2 fail.` -- `[UNMEASURED] 1: exit 0` above two red summary asserts.
- 7 lanes: the identical shape, and again the only red suite in 123.
- Green standalone on the same tree both times, minutes later.

That is #2114's own signature (red in CI twice out of two on PR #2113, green standalone, not
contention), so the state is unchanged -- only the asserts it lands on are different ones.

### CREATE

- [x] `Assert-Summary` in `scripts/tests/update-plugins.tests.ps1`: asserts the green summary on a
      measured run, and on an unmeasured one asserts the **red** summary the script is specified to
      print instead. Scenario 1's two calls now go through it.
- [x] `New-DrivenRun`, which builds a run object in the shape `Invoke-UP` returns -- `Code`, `Text`
      and `Squish` -- from console text alone, for the driven block below.

### TEST

- [x] Three driven cases for the new helper, beside the three #2114 already drives: a measured run
      still asserts the green summary; an unmeasured one asserts the red summary and records it as a
      real pass; an unmeasured one that printed **neither** summary still fails.
- [x] The suite's own counters are asserted rather than its console, and the deliberate red line is
      given back -- the pattern the #2114 block established directly above it.
- [x] Corrected two off-by-one asserts the driven block caught in itself: `Assert-Summary` makes one
      assert, not two, so the expected pass delta is +1. Both were mine and both were red until fixed.
- [x] Suite green standalone: `Result: 62 pass, 0 fail.`, exit 0.
- [x] Full gate: `check-plugin-integrity.ps1` plus all 123 suites.

#### The substitute is an assert, not a waiver -- and that is the difference from #2114

`Assert-CleanExit` tolerates: the field the race owns is a number with nothing left to check, so the
scenario proves less and says so in yellow. Here the script is specified to print a *different
sentence*, so there is still something to hold it to. A run that printed neither summary fails, which
is the third driven case and the reason this is not a blanket pass.

It deliberately does **not** touch `$script:unmeasured`. That counter counts scenarios waved through
on their exit code, and a scenario reaching `Assert-Summary` was already counted there by
`Assert-CleanExit` -- incrementing it again would report one run twice.

### DEPLOY: fix/2288-summary-asserts-unmeasured-capture

`update-plugins.tests.ps1` went red under gate load at roughly the rate #2114 measured -- about a
coin flip per full run -- and for a reason that repair had left standing. #2114 gave `Assert-CleanExit`
a third state for a capture whose exit code was never measured, on the stated bound that everything
else in a scenario is unaffected by it. Two asserts are not: `update-plugins.ps1` counts such a
capture as a failure, by a decision #2081 argued and #2114 accepted, so its green summary line is
never printed in precisely the runs the tolerance waves through -- and scenario 1 was asserting that
green line. They are now asserted through `Assert-Summary`, which holds a measured run to the green
summary and an unmeasured one to the red summary the script is specified to print instead. A run that
prints neither still fails, so the scenario keeps proving something about the summary rather than
being excused from it.

**Score:** 1

#### What makes this deploy extra special

Nothing to migrate and nothing to run: this is a test suite in the source repo, and no consumer
carries it. What it buys is that a gate and a CI leg stop going red on a documented race that nobody
can act on, which is the failure mode that teaches a reader to skim red checks.

The measurement worth keeping is the shape rather than the rate. #2114 repaired the assert the race
lands on **first** and reasoned about the rest by class -- commands, ids, scopes, order -- which was
right for every assert except the one composed from the failure counters. So the lesson is that the
bound to check is not "is this assert about the exit code" but "is this assert downstream of a value
the unknown feeds".

**Score:** N/A

#### Pull Request

The update-plugins summary asserts survive an unmeasured capture, as its exit assert already does
