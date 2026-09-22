## feat/2304-split-critical-path-suites

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

#### What this branch is, and what it deliberately is not

This is **step 1 of #2304**, not the whole of it. #2304 measured that CI is critical-path-bound on a
single test file and set out a four-step sequence; this branch does the first and biggest step and
leaves the issue open.

`check-plugin-integrity-docs.tests.ps1` recorded **669.1s** on CI against a **391s** work bound over
16 lanes, so that one file WAS the gate -- the measured CI duration of 11.5 min matched its recorded
duration to within 0.3 min. It is split into four suites, partitioned on gate-invocation count rather
than on line count, because the invocations are what the time is spent in.

Splitting it moves the critical path to the next heaviest file
(`check-plugin-integrity-links.tests.ps1`, 539.2s) rather than to the work bound, which is why the
shard count does NOT go up here and why #2304 stays open for the remaining three files.

### CREATE

- [x] Partition the 19 check sections + the `-SkipCheck` block by gate-invocation count, into four
      groups of 19 / 26 / 22 / 24 invocations, grouped so each file has a subject a reader can name
- [x] Write the four suites: `-docs` (consumer documents), `-scripts` (the script layer),
      `-invocations` (printed invocations), `-roster` (defs and names + `-SkipCheck`)
- [x] Repair the one latent order dependency the split surfaced: check 42b wrote into `scripts\task`
      that check 18 happened to create first. `New-IntegrityFixture` now creates it, beside
      `scripts\lint` and `scripts\lib`, so no scenario depends on which one runs first
- [x] Update `check-plugin-integrity-fixture.ps1`'s own docstring: four suites -> seven, with both
      splits' measurements recorded
- [x] Update `ci.yml`'s matrix comment: #1358's "not bought" decline was correct at 221.8s and
      expired at 669.1s -- and state that the shard count still does not go up, and why
- [x] Update the two lenses that state the structure: Tycho #18 (the suite family) and Nolan #25
      (a dated note; his August 16 figures are left as measured)

### TEST

- [x] Baseline recorded before any edit: the single file reports **188 asserts, 0 FAIL, exit 0** in
      235.8s standalone
- [x] All four suites run: 31 + 58 + 39 + 60 = **188 asserts, 0 FAIL**, every one exit 0 -- the same
      invariant #714 held itself to, and nothing was removed to buy the time
- [x] Longest part standalone: **235.8s -> 64.3s**
- [x] The first run caught the order dependency (`-invocations` died at its first WriteAllText with
      DirectoryNotFoundException), which is why the count was verified by running rather than by
      reading -- a grouping that looks safe is not evidence
- [x] Full lint + suite gate green before the push: lint **0 errors**, test gate **all 127 suites passed in 278s**

### DEPLOY: feat/2304-split-critical-path-suites

The CI gate was bound by one test file. `check-plugin-integrity-docs.tests.ps1` recorded 669.1s
against a 391s work bound over 16 lanes, so the gate's 11.5 min was that file's duration and not the
pool's -- the other 120 suites ran free in its shadow. It is now four suites, partitioned on
gate-invocation count, and the family's longest part went 235.8s to 64.3s standalone. All 188 asserts
are preserved and were verified by running the four parts, exactly as the first split of this family
held itself to its own count in #714.

This is step 1 of #2304: the critical path moves to the next heaviest file rather than to the work
bound, so the shard count does not change and the issue stays open for the remaining three.

**Score:** 3

#### What makes this deploy extra special

#1358 priced this exact split and declined it -- correctly, when the file was 221.8s and the gap was
~15s. It was 669.1s when the decision was revisited, so the gap had become 278s: 40% of the gate. The
decision never became wrong, the thing it was measured on changed underneath it, and nothing reported
that. The split also surfaced a latent order dependency between two checks that only held while they
shared a file -- the standing lesson being that a cost-based partition may not depend on which
scenario runs first, and that such a dependency is invisible until somebody wants to split on weight.

**Score:** N/A

#### Pull Request

Split check-plugin-integrity-docs into four suites: CI was bound by one 669s file
