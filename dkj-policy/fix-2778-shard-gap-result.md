## fix/2778-shard-gap-result

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

- [x] Measure the shard spread on the four PR runs carrying #2774 (37121339222, 37122330637,
  37122436214, 37122841927): max − ideal 61 / 52 / 105 / 117s
- [x] Regenerate `scripts/tests/suite-durations.json` from those four runs (`record-suite-durations.ps1`)
- [x] Replace the lens's "not yet measured" sentence with the result

### TEST

### DEPLOY: fix/2778-shard-gap-result

Refreshing the suite durations (#2747) did not close the CI shard gap. Across seven PR runs the slowest
shard still lands 49-117s above a perfect partition, and the performance lens now records that figure
instead of "not yet measured". `suite-durations.json` is regenerated from the four runs that carry #2774,
which made the 15 integrity suites about 30% cheaper than the file recorded, so the gate packs from current
figures again. Whether the remaining gap is runner noise or packing is still open (#2775).

**Score:** 1 -- prevents the gate from packing CI shards off figures that overcharge the integrity suites.

#### What makes this deploy extra special

N/A -- CI shard packing and a lens paragraph; nothing a consumer receives changes.

**Score:** N/A

#### Pull Request

Record that the duration refresh did not close the CI shard gap, and refresh the integrity-suite figures

