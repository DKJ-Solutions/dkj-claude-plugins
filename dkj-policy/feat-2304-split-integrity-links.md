## feat/2304-split-integrity-links

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

Step 2 of #2304. Step 1 (PR #2310) split `-docs` and named `-links` (539.2s on CI) as the next critical
path. Split it the same way: at check boundaries, balanced on gate invocations rather than lines, all
asserts preserved and verified by running them, no scope removed. Steps 3 and 4 (`-commands`,
`-entries`) are separate branches.

### CREATE

- [x] Cut `check-plugin-integrity-links.tests.ps1` into four: `-links` (checks 4 + 28, kept together for
  scenario 23's cross-count), `-skill-spans` (check 10 + scenario 16), `-plugin-spans` (checks 29 + 32),
  `-plugin-links` (check 30) -- 13/18/21/13 of 65 invocations
- [x] Repair the order dependency the cut exposed: the fixture writes no root documents, check 4's
  scenario B did, and every later block inherited them -- now `Write-QuietRootDocuments` in the fixture
- [x] Fixture header, ci.yml's matrix comment and the carried scenario comments updated to the new layout

### TEST

- [x] Original and the four parts run side by side: 141 asserts before, 35 + 31 + 48 + 27 = 141 after, all
  green; static counts equal too (65 calls, 137 assert statements); longest part 55s against 159s
- [x] Gates via `open-pr -GatesOnly`

### DEPLOY: feat/2304-split-integrity-links

`check-plugin-integrity-links.tests.ps1` was the CI gate's critical path once step 1 had split `-docs`:
539.2s against a 391s work bound. It is now four suites, cut at check boundaries and balanced on gate
invocations, and side by side on one workstation the longest part took 55s against the original's
159s. All 141 asserts are preserved and were verified by running the four parts. This is step 2 of
#2304; the critical path moves to `-commands` (498.3s), so the shard count does not change and the
issue stays open for steps 3 and 4.

**Score:** 3

#### What makes this deploy extra special

The cut surfaced the same class of defect step 1 did, one layer up: the fixture writes no root
documents, so checks 10, 28, 29, 30 and 32 had all been starting from the files check 4's scenario B
happened to leave behind. Two leaned on it outright -- check 28's file-relative proof needs a root
`CONTRIBUTING.md`, and check 32 reads that file back to restore it. It is now stated once in the fixture
instead of inherited, which is the second time a weight-based split has found state that only held
because two scenarios shared a file.

**Score:** N/A

#### Pull Request

Split check-plugin-integrity-links into parallel suites: step 2 of the CI critical path

