## docs/2415-local-gate-median-141

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

Issue #2415: record the local test gate's wall-clock on the current 141-suite pool, at the default
lane count and at `-MaxParallel 2`, per Nolan's population rules (n, median, range, machine, lane
count), so a lever for the local gate can be priced. Measured through the real entry point
(`open-pr.ps1 -GatesOnly -SkipLint`), one run at a time, nothing else touching the checkout while
a run is in flight. The figures land in Nolan's lens.

Machine: 32 logical cores, 31.8 GB RAM, Windows 11 Pro 26200.

### CREATE

- [x] Default lanes: n=5 at 30 lanes (auto, bound by cores), all green, median 229s, range 222-244s
- [x] `-MaxParallel 2`: n=5, all green, median 1,215s, range 1,125-1,320s
- [x] Figures written into Nolan's lens with the population stated

### TEST

- [x] Every run was a full run: the gate-evidence record was deleted before each, and every log reports
  all 141 suites passed with its lane count
- [x] Work sums read from the top-level duration table only (the nested `test-suite-gate` fixture row
  `l-one.tests.ps1` excluded), 141 rows per run

### DEPLOY: docs/2415-local-gate-median-141

Nolan's lens now records the local test gate's wall-clock on the current 141-suite pool: median **229s**
at the automatic 30 lanes and **1,215s** at `-MaxParallel 2`, n=5 each, all green, on one 32-core machine
with the population stated. At auto lanes the makespan is one file, `new-branch.tests.ps1`, so more lanes
buy nothing and the lever sits inside that suite; at two lanes the pool is work-bound. #2317's ~43-minute
runs and memory reaps did not reproduce on this machine. Closes #2415.

**Score:** 1

#### What makes this deploy extra special

N/A -- a measurement recorded in a maintainer's lens; nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

Record the local gate median on the 141-suite pool: 229s at auto lanes, 1,215s at two

