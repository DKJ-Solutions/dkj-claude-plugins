## fix/2121-gate-lane-count-memory

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

Read the gate's lane resolution; measure per-lane memory on this machine; add a memory term to the auto
lane count with a measured constant, keep `-MaxParallel` as it is.

#### What #2121 reported, and what was verified before anything was changed

The report's symptom is a gate that reports ~40 of 116 suites red at its automatic lane count and 2 at
`-MaxParallel 6`, on one tree, twice, naming different suites each time. Its *reason* -- that the lane
count is derived from cores while what a lane exhausts is memory -- was checked against the tree rather
than taken on trust, and it was already written there: `open-pr.ps1`'s own `.PARAMETER MaxParallel` has
said since #1443 that "the reservation formula reasons about CORES, not memory", and closed with
"whether the reservation formula should account for memory as well as cores is a separate question, on
one machine's worth of evidence, and #1443 did not measure it". #2121 is that second machine.

#### The measurement this branch added

The issue named two things that would make it decidable. Both were answered:

- **Does CI see it?** No, and it cannot: `ci.yml` passes `-MaxParallel ([Environment]::ProcessorCount)`
  explicitly, so a hosted runner never reaches the automatic formula at all.
- **Does the failure rate track lanes or free memory?** Memory. Measured on DAVE-KOK-BWJ (18 logical
  processors, 16 GB), shard 1 of 4 at 8 lanes over this repo's own 116 suites, sampling every 1.5s for
  the whole 401s run: peak 26 resident `powershell.exe` (~3.25 per lane), peak 1,922 MB private bytes
  and 2,280 MB working set across them -- about 240 MB private / 285 MB working set per lane. The run
  started with 3,063 MB free and dipped to 1,686 MB. At that free figure the old formula would have
  opened 16 lanes on a machine that had room for 8.

### CREATE

- [x] `Get-AvailableMemoryMB` in `scripts/lib/native-capture-lib.ps1` -- free physical memory in MB, 0
      when the query cannot be answered, shadowable by a fixture the way `Get-ResidentPowerShellCount`
      already is.
- [x] `Get-TestSuiteGateLaneCount` -- the lane arithmetic as a pure judgement over two integers,
      returning the count, both terms and which one bound. Extracted rather than left inline because
      both inputs are properties of the machine, so inline it is only reachable by running a real pool
      on a real box.
- [x] `$script:TestSuiteGateLaneMemoryMB = 512` -- the per-lane budget, with the measurement above in
      its banner and the argument for the margin.
- [x] `Invoke-TestSuiteGate` takes the lower of the two reservations, and prints which one bound when
      it was memory -- the half of the report that is about silence rather than about the number.
- [x] The two caller docstrings that #1443 pointed here (`open-pr.ps1`, `cut-release.ps1`) and
      `ci.yml`'s override comment, all of which described a core-only default.
- [x] Mirrors regenerated via `scripts/sync/build-shared-scripts.ps1` -- the lib is mirrored into
      `dkj-policy` and `dkj-subagents-shopify`, so this default is what a consumer's gate picks too.

### TEST

- [x] `test-suite-gate.tests.ps1`: the formula asserted directly against the two reported machines
      (#2121's 32 threads, #1443's 18 cores), the floor, the tie, and `0 = could not ask`; plus the
      plumbing -- that the number the formula returns is the number the pool opens and that the line
      prints exactly when memory bound. The machine-dependent half is asserted against the function
      rather than against a literal, because a 4-core hosted runner reserves down to 2 and can never be
      memory-bound at all.
- [x] Full local gate green on this branch.

### DEPLOY: fix/2121-gate-lane-count-memory

The test gate's automatic lane count is the lower of two reservations now, not just one: the machine's
cores minus two, and its free physical memory divided by a measured 512 MB per lane. Until now it
reasoned about cores alone, while what a lane actually exhausts is memory -- every lane is a
`powershell` child that spawns children of its own. On the machine that filed #2121 that default was 30
lanes, and at 30 lanes the gate reported 44 of 116 suites red, then 43 on a rerun of the same tree,
naming different suites each time; a 6-lane run of that tree found the two real failures. A verdict a
session cannot trust is worse than a slow one, and the cost of the other direction is small: 4 lanes
finish the same suites 24% slower than 16 and they finish.

A run whose lanes were set by memory now says so, with the free figure, the per-lane budget and the
count the cores would have allowed. That is the half of the report that was not about the number: the
`-MaxParallel` knob has existed since #1443 and worked, and nothing anywhere pointed a session at it or
suggested the lane count was why a third of the pool was red.

Nothing changes for CI, which passes its own lane count explicitly, or for any caller that passes
`-MaxParallel`. A machine whose memory query cannot be answered falls back to exactly the core formula
it had before.

**Score:** 4

#### What makes this deploy extra special

N/A -- this is the gate a developer of this repo and its consumers runs before a push. No subscriber of
anything this repo ships meets it.

**Score:** N/A

#### Pull Request

The test gate's automatic lane count accounts for memory as well as cores
