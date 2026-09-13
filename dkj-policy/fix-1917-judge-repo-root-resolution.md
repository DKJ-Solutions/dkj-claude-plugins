## fix/1917-judge-repo-root-resolution

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

#### What #1917 reported, and what of it survived verification

The report: 37 call sites resolve the repo root with an unjudged
`(git rev-parse --show-toplevel).Trim()`, so where git answers nothing the result is `$null.Trim()`
-- and under `$ErrorActionPreference = 'Stop'`, which all 37 set, that is exit 1 with nothing said
about the cause. Reproduced directly before touching anything: outside a work tree the line yields
`You cannot call a method on a null-valued expression.`

Three of the six pickup checks moved:

- **Symptom, reason, subject, repo: confirmed.** 37 live sites, all under EAP=Stop.
- **The proposed repair's MODEL does not exist.** The report says `new-branch.ps1` "carries the
  inline form of exactly that wording as of #1913 and is the model to lift from". #1913 is still
  **open**; `new-branch.ps1:215` carried the raw unjudged form like the rest. Lifting from it would
  have copied the defect.
- **The size is off, in the direction that matters.** Reported as "36 files, on 37 lines ... the
  37th is a comment in `new-branch.ps1`". Measured: **37 files, 37 live lines, no comment among
  them**. The report's own per-layer breakdown omits `scripts/tests/` entirely, which is 7 of them.

#### And the seam the report asks for already existed

The report proposes "one `Resolve-RepoRootOrFail`-shaped helper". The tree already had **four**
dual-context resolvers, and the report names three of them -- but not the fourth, which is the one
that matters: **`Resolve-CheckRoot` in `check-report-lib.ps1`**. It is already mirrored into both
`dkj-policy` and `dkj-subagents-alpha`, already guarded by the shared-scripts dual-context invariant,
and its own docstring already names this exact bug -- "a caller under `$ErrorActionPreference = 'Stop'`
used to die on a raw `.Trim()` against `$null`".

So this branch adds no fifth spelling. It adds the missing **verdict** beside the existing
**resolution**, which is precisely the split `consumer-check-lib.ps1` already states in capitals:
*"THE VERDICT IS NOT SHARED, ONLY THE RESOLUTION."*

### CREATE

- [x] `Resolve-RepoRootOrFail` in `check-report-lib.ps1` -- delegates to `Resolve-CheckRoot`, refuses
      on `$null` naming git's exit code and its stderr, and names the CALLER rather than the lib.
- [x] `Resolve-CheckRoot` carries git's verdict additively: `GitExitCode` / `GitError`, populated
      only on the git branch, so "git was not asked" stays distinguishable from "git answered 0".
- [x] `-From` on both -- anchors the git call via `git -C` for a caller whose answer must not depend
      on the working directory. The six converted suites need it: this test tree stands up throwaway
      git repos and changes into them.
- [x] 23 acting scripts converted mechanically (16 two-source, 7 three-source with `$RootOverride`).
- [x] `new-branch.ps1` + `fold-changelog-entry.ps1` -- the `if (-not $repoRoot)` guard is gone;
      passing the case-insensitive `$RepoRoot` param as `-Override` **is** that guard.
- [x] `build-release-notes-page.ps1`, `check-fanout.ps1`, `measure-skill.ps1` -- multi-line and
      statement spellings of the same three-source chain.
- [x] The 3 lint chains (`check-branch-entry`, `check-consumer-prose`, `check-unfolded-entry`) made
      judged but **deliberately tolerant**. They already delegate to `Resolve-CheckRepoRoot` and
      already carry their own post-guard -- one refuses (`exit 1`, a CI gate), two are advisory
      (`exit 0`). Only the degraded fallback was crashing before that guard could read anything.
      Refusing there would have overridden three verdicts that are already correct.
- [x] 6 test suites anchored with `-From $PSScriptRoot`.
- [x] 31 plugin mirrors regenerated.

### TEST

- [x] The refusal measured in a **child process** -- it ends in `exit 1`, so called in-process it
      would take the suite down with it. Asserts the exit code, that nothing runs past it, that the
      null dereference is gone, and that the message carries git's code (128), git's own words, the
      caller's name and the way out.
- [x] `-From` proved against its control: same non-repo working directory, anchored resolves this
      repo, unanchored resolves nothing at exit 128. Without the control the anchor proves nothing.
- [x] The shared-scripts dual-context invariant accepts the new delegation as a third spelling, with
      the matching pair asserting `check-report-lib` defines it *and* gets its answer from
      `Resolve-CheckRoot` rather than re-deriving one -- the invariant-moves-with-the-behavior shape
      the existing asserts already use.
- [x] Every changed `.ps1` parsed via the PowerShell AST parser: 0 failures.
- [x] Lint gate green; full suite gate green.

### DEPLOY: fix/1917-judge-repo-root-resolution

Every workflow script that could not find its repository used to die on
`You cannot call a method on a null-valued expression.` -- exit 1, no cause, from the first statement
of the script. That is the line a consumer meets when a skill runs the plugin mirror from a worktree,
or with the working directory somewhere unexpected, which is exactly where `rev-parse` does not
answer. It now refuses in words, naming git's exit code, what git said, and the three ways out.

**Score:** 3

#### What makes this deploy extra special

It removes a spelling rather than adding one. The report asked for a new shared helper; the tree
already had four dual-context resolvers and the repair is the **verdict** the fourth was missing, not
a fifth resolver. `Resolve-CheckRoot` had described this exact bug in its own docstring for weeks
while 37 call sites went on committing it -- the correct shape existed and simply was not the one
that got copied.

Two of the six inbound pickup checks caught something: the model the report told us to lift from
never landed (#1913 is still open, so `new-branch.ps1` carried the defect, not the cure), and the
count was low by one file and silently omitted a whole layer.

**Score:** 2

#### Pull Request

Judge the repo-root resolution instead of dereferencing a null

