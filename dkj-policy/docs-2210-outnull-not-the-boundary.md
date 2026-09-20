## docs/2210-outnull-not-the-boundary

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

#2210 asks the owner of `fix/2199-one-lens-assembler` to choose between accepting +11% on the always-on
path, inlining the call site, or "something else -- the boundary cost itself may be reducible; nothing
here has tested that". This branch tested it. The third option wins, and the repair is two lines.

**No code on that branch is touched here.** It is live under `maikel-bwj` (last commit ~1 h before this
session), #2199 is open and assigned to them, and the repair belongs in their hands. What lands here is
the measurement, in Nolan #25's lens, plus the two issues it produced. The finding is on #2210 as a
comment for the branch owner.

#### The finding

The +11-12% is **not** the call boundary -- that measures 0.038 ms. It is **35 `| Out-Null` pipelines
per invocation** that the promotion added at the call site (29 in the re-append loop, 6 in the
`$pluginNames` loop), at ~95 us each. `[void]` instead of `| Out-Null` recovers 88% and lands within
0.36 ms of the fully-inlined control, so inlining buys nothing over it.

- [x] Reproduce #2203's four rows on this machine -- rows 1 and 4 both reproduce, so the harness agrees
      with theirs where they overlap
- [x] Isolate the mechanism directly (pipeline construction vs. the boundary), rather than inferring it
      from a whole-block bisect
- [x] Measure the candidate repair end to end, five variants, rotated, contention-bracketed

### CREATE

- [x] Correct the wrong attribution in Nolan #25's lens and record the re-measurement under its own
      heading
- [x] File the repo-wide reach of the idiom separately (#2215) rather than sweeping 107 sites here
- [x] Put the repair and the numbers on #2210 for the branch owner
- [~] Apply the two-line repair -- dropped: it belongs on another account's live branch, and an
      ordering between two people's branches is the owner's call

### TEST

- [x] All 70 measurement batches in band; corpus hash identical across every variant, so the variants
      compare the same work
- [~] A test suite -- dropped: nothing in this branch is code. The measurement's own repeatability is
      what stands in for it, and the harness is described in the lens well enough to re-run

### DEPLOY: docs/2210-outnull-not-the-boundary

A measured attribution in Nolan #25's lens said the #2199 promotion's +11% was the function-call
boundary. It is not: the boundary is 0.038 ms, and the cost is 35 `| Out-Null` pipelines the promotion
added at the call site. The lens now carries the corrected cause, the five-variant bisect behind it, and
the two-line repair that recovers 88% of the regression while keeping the shared function -- which
settles the design question #2210 left open for the branch owner. The general rule is recorded with it:
an attribution is a measurement too, and a bisect that swaps a whole block tells you which block, never
which line in it.

**Score:** 3

#### What makes this deploy extra special

N/A -- no subscriber of anything this repo ships notices. The lens is internal reference, and the
always-on path it measures is unchanged by this branch.

**Score:** N/A

#### Pull Request

The #2199 regression is the Out-Null idiom in the re-append loop, not the call boundary
