## feat/2304-split-integrity-commands

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

Step 3 of #2304. Step 2 (PR #2366) split `-links` and named `-commands` (498.3s on CI) as the next
critical path. Same method: cut at check boundaries, balance on gate invocations, preserve every assert
and verify by running, remove no scope.

### CREATE

- [x] Cut `check-plugin-integrity-commands.tests.ps1` into four: `-commands` (checks 11, 12, scenario 33),
  `-script-rules` (checks 33, 31, 34), `-script-set` (check 37, the #1998 script-set scenarios, check 44),
  `-fixture-guard` (check 41) -- 19/16/17/16 of 68 invocations
- [x] Repair the cross-block read the cut exposed: the script-set scenarios assert check 31's finding and
  took its pattern from check 31's block; `-script-set` now states it itself
- [x] Fixture header, ci.yml's matrix comment and the carried "patterns above" references updated

### TEST

- [x] Original and the four parts side by side: 132 asserts before, 42 + 27 + 28 + 35 = 132 after, all
  green; static counts equal too (68 calls, 120 assert statements); longest part 64s against 184s
- [x] Gates via `open-pr -GatesOnly`

### DEPLOY: feat/2304-split-integrity-commands

`check-plugin-integrity-commands.tests.ps1` was the CI gate's critical path once steps 1 and 2 had
split `-docs` and `-links`: 498.3s against a 391s work bound. It is now four suites, cut at check
boundaries and balanced on gate invocations, and side by side on one workstation the longest part took
64s against the original's 184s. All 132 asserts are preserved and were verified by running the four
parts. This is step 3 of #2304: the heaviest remaining file, `-entries` at 377.7s, is below the work
bound, so from here the gate is bound by total work rather than by one file.

**Score:** 3

#### What makes this deploy extra special

This is the step where the lever changes. Until now each split moved the critical path to the next
heaviest file; after this one no single file is above the 391s work bound, so the next saving comes from
a shard (or a split that goes with one), not from a split alone -- which is exactly what ci.yml's matrix
comment has said since #1358. The cut again surfaced state carried across a block boundary, this time a
variable rather than a file, and it is stated again in the suite that reads it.

**Score:** N/A

#### Pull Request

Split check-plugin-integrity-commands into parallel suites: step 3 of the CI critical path

