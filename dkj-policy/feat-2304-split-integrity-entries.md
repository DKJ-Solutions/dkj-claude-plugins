## feat/2304-split-integrity-entries

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

Step 4 of #2304. The #2378 re-read put the pool at 7,260.5s (work bound 453.8s over 16 lanes) with
`-entries` at 426.1s and `new-branch` at 380.2s. A fifth shard alone stops at `-entries`; a split alone
buys nothing. Both together put the floor at `new-branch`. Partial step: ships with `-NoResolves`.

### CREATE

- [x] Split `check-plugin-integrity-entries.tests.ps1` at check boundaries into `-entries` (check 13),
      `-branch-document` (13b + [COVERAGE]) and `-figures` (checks 15, 16), by moving line ranges
- [x] Restate the one inherited state (`$s24Contributing` before [COVERAGE]) where it is read
- [x] `ci.yml`: matrix, step name and `-ShardCount` to 5, plus the step-4 paragraph
- [x] Fixture docs, and the shard-count wording that went stale (`ci.yml`, `get-merge-suite-skip.ps1`,
      `record-suite-durations.ps1`'s machine string)

### TEST

- [x] Original `-entries` alone: 86 asserts, 124.4s. The three parts side by side: 37 + 25 + 24 = 86, all
      green, longest 94.5s
- [x] `ci-shard.tests.ps1` green (91), which holds the matrix length to `-ShardCount`

### DEPLOY: feat/2304-split-integrity-entries

`check-plugin-integrity-entries.tests.ps1` is three suites now, and CI runs on five shards instead of
four. The re-read durations showed the gate bound by total work (453.8s over 16 lanes) with `-entries`
(426.1s) the file a fifth shard would stop at, so both levers go in together: the expected floor is
`new-branch.tests.ps1` at 380.2s. All 86 asserts are preserved and were verified by running the three
parts. Step 4 of #2304.

**Score:** 3

#### What makes this deploy extra special

The first step of #2304 that moves the shard count, and the one where the issue's own ordering is
applied rather than quoted: a split alone would have bought nothing here, and a shard alone would have
stopped at the file this change splits. A sixth shard buys nothing until `new-branch` is split.

**Score:** N/A

#### Pull Request

Split check-plugin-integrity-entries and add a fifth CI shard: step 4 of the CI critical path

