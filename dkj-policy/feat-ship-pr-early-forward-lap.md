## feat/ship-pr-early-forward-lap

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

Measured on stopwatch run `20261023-131652-e081` (PR #3348, 19m15s): another PR merged 12s after CI
started, the first CI run took 8m19s, and only then did step 3b lap and start a second 8m03s run. The
first run was 43% of the assignment, and the gate was always going to discard it. Target: the next
measurement at least 5% faster.

### CREATE

- [x] `forward-lane-lib.ps1`: `Get-EarlyForwardAction` (poll / forward / watch) and `Get-UnfinishedRequiredCount` (ruleset names against the full payload, so an unregistered aggregator counts as unfinished)
- [x] `ship-pr.ps1`: step 3a polls between the first registration wait and the wait on the required check, and forwards at once on a stale reading, failing open to the existing flow
- [x] `ship-pr.ps1`: `Get-FoldExemptCommits` and `Complete-ForwardLap` extracted from step 3b and shared with 3a; the lap budget is shared
- [x] Plugin mirrors synced byte-for-byte

### TEST

- [x] `forward-lane-lib.tests.ps1`: unit cases for both new functions, plus structural asserts on step 3a's place, the shared budget and the shared helpers (107 pass)
- [x] Every suite that reads `ship-pr.ps1` re-run locally

### DEPLOY: feat/ship-pr-early-forward-lap

When the trunk gains a commit while a PR's CI is still running, `ship-pr` now brings the branch up to
date at once and waits for the fresh run, instead of first sitting out a run whose certificate step 3b
was always going to refuse. The gate is unchanged: the same staleness predicate, the same fold discount
and the same `-MaxForwardLaps` budget, which the early forward shares. Anything the early phase cannot
read hands over to the existing wait, so its worst case is the old behaviour. On PR #3348 this would
have saved about 8 of 19 minutes.

**Score:** 3

#### What makes this deploy extra special

A consumer running `ship-pr` on a busy trunk gets its pull request merged one CI run sooner whenever
another merge lands during its CI wait. Nothing to configure, and `-MaxForwardLaps 0` still switches
every lap off.

**Score:** 3

#### Pull Request

ship-pr laps forward as soon as the trunk moves during the CI wait, instead of after the stale run finishes

