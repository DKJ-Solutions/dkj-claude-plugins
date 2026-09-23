## fix/2304-rerecord-durations-after-split

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

#2304's last comment names the next step: re-read the per-suite durations on CI with the split
layout before choosing between splitting `-entries` and adding shards. The file on the trunk still
carried the pre-split names, so the nine new `check-plugin-integrity-*` suites were charged the
maximum and the numbers could not say which file sets the makespan.

### CREATE

- [x] `record-suite-durations.ps1` against three PR runs carrying the #2370 layout (35871835806,
  35872701189, 35873943670). The trunk pushes after the fold printed no suite table, so the
  merge-commit runs the previous re-record used were not available.

### TEST

- [x] 139 rows against 139 suites in `scripts/tests/` -- none left to be charged the maximum.
- [x] The reading: pool 7,260.5 s over 16 lanes gives a work bound of 453.8 s; the heaviest file,
  `-entries`, is 426.1 s and below it, then `new-branch` at 380.2 s.

### DEPLOY: fix/2304-rerecord-durations-after-split

Re-recorded `scripts/tests/suite-durations.json` from three CI runs carrying the split
`check-plugin-integrity-*` layout (#2304). The file still named the pre-split suites, so the nine new
ones were charged the largest recorded value and the gate packed shards off guesses. The reading:
the pool is 7,260.5 s over 16 lanes, a work bound of 453.8 s, and no single file reaches it any more
-- `-entries` is heaviest at 426.1 s -- so CI is now bound by total work, not by one file. The splits
were not free: the `check-plugin-integrity-*` family went from 2,084.3 s to 2,679.0 s of pool work
(+594.7 s), because each file builds its own fixture. That is what the next step has to weigh, since
another split raises the work bound it is meant to get under.

**Score:** 1 -- prevents the gate packing CI shards off maximum-charged guesses for nine suites; no
reader notices it except as CI wall-clock.

#### What makes this deploy extra special

N/A -- data file only; nothing to migrate.

**Score:** N/A

#### Pull Request

Re-record CI suite durations after the check-plugin-integrity splits

