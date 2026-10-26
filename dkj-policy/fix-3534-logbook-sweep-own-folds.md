## fix/3534-logbook-sweep-own-folds

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Verified: a step-log mark carried no session, so `Split-LogbookSweepRuns` could only scope folds to the
checkout. `CLAUDE_CODE_SESSION_ID` is set in a Claude Code session's tool environment and equals the
session id the Logbook hook records (checked against this machine's store), so the mark can name it.

### CREATE

- [x] `Add-RunStepMark` writes `session` (default `CLAUDE_CODE_SESSION_ID`), `Read-RunStepMarks` returns it;
  the three byte-identical copies of `run-progress-lib.ps1` changed together
- [x] `Get-LogbookFolds` carries the mark's session; `Split-LogbookSweepRuns` cuts a sweep only at folds of
  its own session, while a fold or sweep naming none (written before this) cuts as before
- [x] The Logbook page's footer and the lib's header say "its own session's folds"
- [x] Asserts in `logbook.tests.ps1` (two overlapping sweeps, a legacy fold, a fold's session) and
  `run-progress.tests.ps1` (a mark's session, its default, a legacy mark)

### TEST

- [x] `logbook`, `run-progress` and `stopwatch` suites green; the overlapping-sweeps assert red without the
  fix, reproducing the issue's double count

### DEPLOY: fix/3534-logbook-sweep-own-folds

The hub's Logbook cuts a `/sweep-issues` run only at the folds its own session made, so two sweeps in one
checkout no longer take each other's issues as laps and count them twice. A ship's step-log marks now
name the Claude Code session that ran them; marks written before this still cut every sweep, as before
([#3534](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3534)).

**Score:** 2

#### What makes this deploy extra special

A repo's maintainer reading `/logbook` after two sweeps side by side sees each issue once, under the
sweep that shipped it.

**Score:** 1

#### Pull Request

Logbook: a sweep is cut only at its own session's folds

