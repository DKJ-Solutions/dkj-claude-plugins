## fix/1939-native-capture-flaky-at-16-lanes

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

#### What #1939 reported, and the half of its reasoning that did not survive the check

The report is right that `native-capture.tests.ps1`'s flushed-before-the-kill case is flaky at 16
lanes, and right about the mechanism: unlike the `TimedOut` assert immediately above it, this one
needs the child to have **reached** `Write-Host` before the kill, so its fixed `-TimeoutSeconds 2`
has to cover `powershell.exe` bring-up -- a quantity nothing bounds.

**Its headline figures are not the quantity that has to fit inside 2s, and that changes the size of
the repair.** #1939 cites 0.5s standalone against 3.25s at 16 lanes, both read out of the
`Stop-NativeProcessTree` calibration block further down the same file. That block times **two** cold
startups -- the outer script, then the grandchild it `Start-Process`es -- plus its 100ms marker poll.
The per-startup halves behind those figures are therefore roughly 0.25s and 1.6s. So the contended
case is 1.6s against a 2s bound: thin margin that loses on a bad sample rather than every time, which
is exactly the shape a flake has. Budgeting the two-startup number here would have over-sized this
bound by about 2x.

Shape 1 of the three the report weighs is still the right one, and is the pattern the file already
carries -- it is only the quantity fed into it that the check changed.

#### What is deliberately left alone

The `$stalled` case above it keeps its fixed `-TimeoutSeconds 2`: it needs only that the bound
**expire** against a 30s sleep, which any bound well under 25s delivers, and its elapsed assert is
what makes the small number meaningful. Same for `$inTime`'s 30s bound on `cmd /c exit 7`, where cmd
bring-up is an order cheaper and the bound is 15x the one that bit.

### CREATE

- [x] Verify the reported reason against the lib before repairing it -- confirm the timeout clock
      starts after `Start-Process` returns (`native-capture-lib.ps1:865,878`), so the budget must
      cover the child's own runtime bring-up
- [x] Re-derive the report's figures: establish that its 3.25s is a two-startup measurement and the
      per-startup quantity is ~1.6s
- [x] Calibrate the bound against **one** cold startup to first output, unbounded, immediately before
      the case -- the same shape the grandchild bounds below already use
- [x] Guard the calibration, so the bound cannot be derived from a failed probe
- [x] Derive the bound at 4x, floored at the old 2s and capped at 20s; derive the child's sleep from
      the bound rather than leaving it fixed at 30
- [x] Correct the comment above the case, which claimed "no kill race involved" -- true only on an
      idle machine
- [x] Name the calibrated figure in the failing assert's message, so a reader can tell a slow machine
      from a broken capture

### TEST

- [x] Suite standalone on the repaired tree: `Result: 119 pass, 0 fail` (118 before, +1 for the new
      calibration guard)
- [x] Mechanism reproduced first: on an idle machine the case passes at a 1s bound, confirming the
      failure is contention and not the flush
- [x] The **wide** branch exercised directly -- the path that never ran before. At bounds 2s, 8s and
      20s with the derived sleep, all three properties hold: `timedOut=True exit=124 marker=True`
- [x] The derived arithmetic checked across the range: 0.25s calibration gives 2s (the floor, so an
      idle run pays exactly what it always paid), 1.6s gives 7s, 3.25s gives 13s, 12s gives 20s (the
      cap). The report's own contended per-startup figure now buys 4.4x margin where it had 1.25x
- [~] A red-then-green reproduction under the real 16-lane gate is not carried here: 20 lanes of
      synthetic startup churn moved the calibration only to 0.29s, so the load that produced the
      report is the gate's own 102 suites. `open-pr`'s gate run is that measurement, and running it
      twice would charge the same clock twice for the same answer

### DEPLOY: fix/1939-native-capture-flaky-at-16-lanes

`native-capture.tests.ps1`'s flushed-before-the-kill case no longer races `powershell.exe` bring-up
against a fixed 2s bound. The bound is now measured on the machine at that moment -- one cold startup
to first output, the same calibration shape the grandchild bounds further down the file already use
-- and derived at 4x, floored at the old 2s so an idle run pays exactly what it always paid and
capped at 20s so a pathological reading cannot hang the gate behind one suite. The child's sleep is
derived from the bound rather than fixed at 30, so the preceding assert's property holds however wide
the calibration goes, and the failing assert now names the calibrated figure so a reader can tell a
slow machine from a broken capture.

**The repair is smaller than the report asked for, because one half of its reasoning did not
survive the check.** #1939's 0.5s and 3.25s are read out of a calibration that times **two** cold
startups; the quantity this case actually spends is one, so the contended figure is ~1.6s against a
2s bound rather than 3.25s. Budgeting the reported number would have over-sized this bound by about
2x. That correction is recorded at the call site, where the next reader of these figures is.

**Score:** 2

#### What makes this deploy extra special

N/A. The suite does not travel: only `native-capture-lib.ps1` is mirrored into the plugin payload,
and the lib is untouched here. No consumer runs this file, no scaffolded CI runner reaches it, and
nothing is asked of anybody. The cost is paid entirely by this repo's own gate, which is also where
the flake was.

**Score:** N/A

#### Pull Request

The flushed-before-the-kill case no longer races PowerShell bring-up against a fixed 2s bound
