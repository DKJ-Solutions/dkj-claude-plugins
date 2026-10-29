## feat/3658-connector-check-skip-drift

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

Resolves #3658. Dave chose option "skip drift at start" from a measured menu (comment on the issue).

### CREATE

- [x] `connector-sessioncheck.ps1`: the drift step is opt-in (`-IncludeDrift`); `-SkipDrift` is kept as an accepted no-op
- [x] Docstring: the matcher note no longer claims the hook runs drift, and a dated paragraph records the measurement and where drift still runs

### TEST

- [x] Hook default 2.3-2.5 s (was ~5.0 s), `-IncludeDrift` 4.8 s; dispatcher `sessionstart: 3.0 s` (was 5.9 s)
- [x] `connector-sessioncheck` 51/51, `connectors` 417/417, `session-cache-lib` 71/71
- [~] A suite assert for the default -- dropped: the hook suite exercises no workshop-path drift at all today, and the flag is one line

### DEPLOY: feat/3658-connector-check-skip-drift

A session start in this source checkout no longer waits on the agent-def drift lint: `connector-sessioncheck` now passes `-SkipDrift` to `check-connectors.ps1` by default, which took the hook from about 5.0 s to 2.3 s and the whole session start from 5.9 s to 3.0 s (one machine). The drift step ran one `check-consumer-drift.ps1` per registered consumer in sequence and found nothing on any of the three. It still runs in a manual `scripts/sync/check-connectors.ps1`, and `-IncludeDrift` puts it back in the hook. Consumer machines never took that path, so nothing changes there.

**Score:** 3

#### What makes this deploy extra special

N/A -- only the workshop path ran the drift step, and that path exists only in this source checkout; a plugin user's session start is unchanged.

**Score:** N/A

#### Pull Request

The connector session check skips the drift lint, so a session start here takes about half the time

