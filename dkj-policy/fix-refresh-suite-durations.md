## fix/refresh-suite-durations

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

### CREATE

- [x] Refresh `scripts/tests/suite-durations.json` with `record-suite-durations.ps1` from PR runs 40082613949, 40081479194 and 39990987730

### TEST

- [x] Simulate the LPT pack over all 168 suites against those runs' CI means: slowest shard 454s with the old hints, 378s with the new
- [x] Lint + test gate via `open-pr.ps1`

### DEPLOY: fix/refresh-suite-durations

The CI suite shards pack evenly again. Twelve suites added since October 7 had no recorded duration, so the packer charged each of them the largest one (267.7s) while most take 2 to 40 seconds -- about 3,000 seconds of phantom load that left shards 1 and 5 heavy. In the three latest PR runs shard 5 was the slowest every time, at 488 to 521 seconds. Refreshed from those runs, a simulation of the pack puts every shard at about 378 seconds against 454 for the slowest before: roughly 76 seconds off the required check, about a tenth of a small branch's run from prompt to fold.

**Score:** 3

#### What makes this deploy extra special

N/A -- CI wall-clock in this repo; nothing that ships to a plugin user changes.

**Score:** N/A

#### Pull Request

Refresh suite-durations.json so the CI shards pack evenly again

