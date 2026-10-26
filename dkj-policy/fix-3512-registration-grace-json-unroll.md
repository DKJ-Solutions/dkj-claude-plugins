## fix/3512-registration-grace-json-unroll

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

Repair #3512: the registration grace in `Invoke-TrunkCatchUp` parsed its payload inside `@()`, which
under 5.1 collects the parsed array as one element, so every readable payload read as absent.
Measured before the repair: a two-record payload counts 0 inline and 2 when it is assigned first.

### CREATE

- [x] Move the predicate into gate-lib as `Test-NamedCheckUnregistered` (assign first, wrap second) and call it from cut-release
- [x] Copy both scripts into their `plugins/dkj-policy/scripts/` mirrors

### TEST

- [x] `gate-lib.tests.ps1`: a registered check (red among two, one record) is not absent; a missing check, `[]`, an empty payload and an unparseable one are absent; cut-release's wiring is pinned

### DEPLOY: fix/3512-registration-grace-json-unroll

When the trunk moves while its gates run, `cut-release` waits for the trunk's CI run. Under Windows
PowerShell 5.1 it no longer reads a check that has already registered as "has not registered yet". A
registered red check now refuses at the first read. Before, the cut spent all four grace reads, one
poll interval apart, printing a line that was not true.

**Score:** 1

#### What makes this deploy extra special

A consumer cutting a release sees no change in what the cut decides. The verdict was already right; only
the wait before a red check's refusal is shorter.

**Score:** N/A

#### Pull Request

cut-release's registration grace reads a readable payload as absent under PowerShell 5.1

