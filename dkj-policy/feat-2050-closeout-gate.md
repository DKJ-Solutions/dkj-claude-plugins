## feat/2050-closeout-gate

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

Give step 6 a mechanism that refuses rather than advises, opt-in per repo through a repo-config seam.

#### The decision this branch carries, so it is not rediscovered as a surprise

This is the first hook in this workflow that BLOCKS a turn, and `cycle-autopark.ps1`'s header states
the opposite contract in so many words: *"ALWAYS EXITS 0, and never blocks."* That reasoning is right
for a hook whose worst outcome is a document one turn stale on the remote, and #2050 is the case where
it does not transfer. What carries over is the half about failing: every path in the gate that cannot
answer its question exits 0.

The band is **6 non-empty lines**, and it came from the distribution rather than from the ceiling.
Gating at the stated ceiling of 3 would fire on 73-84% of close-outs. Measured over 83 real close-outs
on this machine: over 6 is 27%, over 8 is 17%, over 12 is 7%. Dave's answer, September 17, 2026.

#### What this branch deliberately does NOT do

- It does not touch `Write-CloseOutReceipt`'s printed text. A seventh sharpening of that wording is
  the exact move #2048's measurement says has never once worked.
- It does not turn the gate on anywhere but here. `Get-CloseOutGateBand` is absent in every consumer
  and absence means off, which is the one place this seam deliberately differs from
  `Get-AlwaysOnBudget` -- a ceiling on a document is worth defaulting, a hook that blocks a turn is
  not. Its script-contract record is `Adopt = 'decide'` for the same reason.
- It does not claim the gate works. Six confident repairs preceded it; what is different is that
  #2048 left an instrument behind, so this one can be re-measured instead of judged by whether a
  complaint arrives.

### CREATE

- [x] `scripts/lib/closeout-gate-lib.ps1` -- the band, the marker, the payload parse and the verdict,
      with the argument and the measurements in its header.
- [x] `Write-CloseOutReceipt` drops the marker at the moment it prints, below both early returns, so
      the printed shape and the gated turn have one trigger between them.
- [x] `plugins/dkj-policy/hooks/closeout-gate.ps1` -- the Stop hook, thin, in the shape
      `guard-working-copy.ps1` set for a blocking hook.
- [x] Registered on `Stop` in `plugins/dkj-policy/hooks/hooks.json`.
- [x] `Get-CloseOutGateBand` in `scripts/repo-config.ps1` (6), with the distribution behind the number.
- [x] Registered in `shared-scripts-lib.ps1` and mirrored into the plugin; seam declared in
      `script-contract-lib.ps1` as `Adopt = 'decide'`.

### TEST

- [x] `scripts/tests/closeout-gate.tests.ps1` -- 47 asserts, weighted towards the ways the gate must
      NOT fire, since a regression there does not produce a wrong message but a session that cannot
      end. The hook is driven end to end through a real child process with a payload on stdin and a
      marker on disk, under an overridden cache root so a run never arms the live gate.
- [x] The loop guard is asserted as a property rather than a code path: `Pop-CloseOutMarker` consumes
      the marker as it reads it, so the firing after a block finds nothing. `stop_hook_active` is
      checked as well and is deliberately not what this rests on.
- [x] Cost measured, because this fires on every turn: ~340 ms against ~155 ms for a bare launch
      (median of 9, interleaved) -- ~185 ms its own, the rest the process any command hook costs.
      Deferring `seam-lib` into `Resolve-CloseOutGateBand` took the lib load from 162 ms to 40 ms.
- [x] Lint gate and full suite green.

### DEPLOY: feat/2050-closeout-gate

Step 6 of the ritual now has a gate instead of a seventh piece of advice. A Stop hook refuses a
close-out over this repo's band and asks for it again, once per work chain; every other turn, and
every repo that has not answered the new seam, is untouched.

**Score:** 3

#### What makes this deploy extra special

Six repairs to the close-out are on the record and all six were advice. #2048 built the instrument and
measured the baseline none of them had ever been argued against -- 84% of close-outs over the stated
ceiling, which means the rule had never been in force anywhere. This is the first one that can be
measured rather than judged by whether a complaint arrives.

It also reverses a written doctrine, narrowly: `cycle-autopark.ps1` says a Stop hook never blocks, and
that stays true of `cycle-autopark`. The exception is bounded to a measured over-run on a turn that
ended a work chain in a repo that opted in by name.

**Score:** 2

#### Pull Request

A close-out gate: a Stop hook that blocks a receipt over the band
