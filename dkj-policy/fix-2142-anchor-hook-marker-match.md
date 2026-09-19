## fix/2142-anchor-hook-marker-match

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

#### What was verified before anything was repaired

The report's symptom holds. `Get-ImportLinePath` reads an `@`-import as `^@(\S.*)$`, so a target may
carry any character including a square bracket, and `check-always-on-budget.ps1` printed two
tree-derived fields raw -- the target and the importing file's path. Measured on a fixture: an import
line reading `@docs/forged[ERROR]-and-[WARN].md` produced a `[WARN]` line carrying a second `[WARN]`
and an `[ERROR]`, and the hook's `[ERROR]` arm made it print the over-the-limit headline plus the
whole report on a run whose verdict was `[OK]`.

The report's *inferred* half -- that anchoring the match is "the whole repair" -- does not hold, and
that is what set this branch's scope. This tree already has a settled doctrine for exactly this class,
at the WRITER: `Format-SafePathToken` and `Format-SafeProseToken` (#309, #414, #1419, #1808) strip
square brackets out of consumer-derived values *because the hooks count them*, and they also strip
the control characters an anchor cannot see. `check-always-on-budget.ps1` was simply not using it.
So the repair is both ends, and each is written not assuming the other is there.

The sweep the report named as "probably the more useful half" was run and is the larger finding:
**eight** hooks across two plugins selected on markers, 26 call sites, every one of them
hand-writing its own `\[...\]` escape -- and one block in `connector-sessioncheck` had already been
anchored on its own, which is the drift a shared definition exists to prevent.

#### The scope this did NOT take

Only the eight session hooks' marker selection. `^Summary: \d+ error`, `source read at`, the
`always-on path:` headline and `connector-sessioncheck`'s per-line parse at its line 214 are not
marker selections and are untouched.

### CREATE

- [x] `Select-CheckMarkerLine` added to `scripts/lib/hook-check-lib.ps1`: anchored to `^\s*`, markers
      passed as literals and regex-escaped, `-cmatch` preserved from every call site it replaces.
- [x] 26 of the 29 marker selections in the eight session hooks moved onto it, across `dkj-policy` and
      `dkj-subagents-alpha`, with the comments that named `-cmatch` updated to name the helper and the
      anchoring.
- [x] The remaining three -- `connector-sessioncheck`'s engine branch -- anchored BY HAND instead, and
      the line says why. That branch runs before the lib is dot-sourced, and the dot-source's own
      comment records the measurement that keeps it where it is: moving it up turned three of that
      hook's engine-branch test cases into "skipped due to an error". Found by checking load order
      after the rewrite, not before it.
- [x] `check-always-on-budget.ps1` now wraps every tree-derived value it prints -- the two `Target`
      fields, `Format-ImporterPath`'s return and the carried-baseline `Key` -- in
      `Format-SafePathToken`.
- [x] The three docstrings asserting that the hooks match "over a check's whole output"
      (`Format-SafePathToken`, `Format-SafeProseToken`, `check-consumer-prose`, `check-connectors`)
      corrected, stating both ends and why neither is written assuming the other.
- [x] Mirrors rebuilt (`build-shared-scripts.ps1`): 7 updated.

### TEST

- [x] `hook-check-lib.tests.ps1`: ten asserts on the helper's own contract, including the one that
      fails loudest while looking right -- an unescaped `[ERROR]` read as a regex is a character class
      matching one of `E`/`R`/`O`.
- [x] `always-on-budget.tests.ps1`: an end-to-end regression on a fixture repo whose import target
      carries both markers -- the strip at the writer, exactly one surviving `[WARN]` on the line, and
      the hook run over it proving it no longer reports an over-the-limit path on an `[OK]` verdict.
- [x] All eight hooks run by hand against this repo: output identical to this session's own start.
- [x] Lint gate green (0 errors); full test gate green.
- [x] Code review and security review, in parallel on the diff. Both clean. The security review traced
      the claim this branch makes rather than taking it: `Invoke-CheckScript` splits its capture on
      CR/LF, so a value carrying an embedded newline arrives as its OWN array element and matches
      `^\s*` at position 0 like any genuine line -- which is the proof that the anchor alone would not
      have closed that half, and that the two ends are non-overlapping rather than two names for one
      fix. Two advisories acted on: the reachability wording above was too narrow (an unmerged branch
      already tripped it), and the anchor rests on a convention no gate holds -- named in the lib and
      filed as
      [#2150](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2150).

### DEPLOY: fix/2142-anchor-hook-marker-match

Every session hook now counts a verdict marker only where its check wrote it, through one shared
`Select-CheckMarkerLine`, and `check-always-on-budget.ps1` sanitizes the tree-derived values it
prints the way the rest of this tree already does. Before this, a document able to put `[WARN]` or
`[ERROR]` on the always-on path had its own line forwarded into every session start -- and `[ERROR]`
made the hook print its over-the-limit headline and the whole report on a run that was in fact `[OK]`.
Reaching it needed content in the tracked import chain of the checkout being measured -- which is a
branch under review, not only the trunk: the check runs from `open-pr`, from CI and from a session
start against whatever is checked out, so a pull request touching an `@`-import line already tripped
it. So this is robustness rather than a closed hole, and the hole was one hop nearer than "already
merged" suggests. What it removes is the shape that goes wrong later, when somebody adds a field to a
report and does not know a sanitizer was load-bearing for it. The sweep is the bigger half: eight
hooks across two plugins were selecting this way, each with its own hand-written escape.

**Score:** 2

#### What makes this deploy extra special

N/A -- no subscriber of a service notices this. It changes which lines a session-start hook forwards
in a repo running this workflow, and the visible behaviour of every healthy repo is unchanged.

**Score:** N/A

#### Pull Request

Session hooks count a verdict marker only where the check wrote it
