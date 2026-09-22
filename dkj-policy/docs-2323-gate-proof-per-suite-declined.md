## docs/2323-gate-proof-per-suite-declined

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

Answer #2323's design question with the measurement it asked for, and record the decline in gate-lib.ps1's own
header where the next proposal will meet it.

#### What #2323 actually asked for

It is explicitly a design question rather than work, and it names its own blocker: *"The measurement #2317 did
not take: how often is the discarded proof actually recoverable? ... The data is in the repo's own history --
the commits between a gate run and a ship -- and nobody has looked."* So the assignment is to look, and then to
answer -- build one of the three shapes it names, or decline with the numbers.

#### One premise in the issue body does not hold

#2323 says levers 1 and 3 *"are built on `feat/2317-gate-cost-ci-wait`"*, and its "not urgent" framing rests on
that. Measured on the day of this branch: that branch carries one `park:` commit with its plan document and
`- [ ] TODO: the first step of this branch`. Lever 1 is scoped, not built. It does not change the verdict --
it strengthens it, since lever 1 still dominates lever 2 on the same case at a fraction of the cost -- but it
is recorded on the issue rather than left for the next reader to trip over.

### CREATE

- [x] Take the measurement: a static read-set model per suite, a defined commit population, and per-commit
      survival both by suite count and weighted by `suite-durations.json`. Throwaway analysis, in the
      scratchpad -- nothing of it lands in the tree, because the verdict is what this branch is for and a
      one-off script nobody will re-run is not evidence, it is furniture.
- [x] Verify the load-bearing numbers against the tree rather than accepting them: the near-universal libs
      (`command-probe-lib.ps1` reached transitively through 10 libs that nearly every suite loads) and the
      whole-tree self-check suites (18 invoke `check-plugin-integrity.ps1` against the live repo).
- [x] Record the decline in `scripts/lib/gate-lib.ps1`'s header, beside the argument for the fingerprint it
      questions -- the measurement, the three findings, the cheaper alternative, and why each of the three
      proposed shapes fails `Get-TestSuiteCostHints`' bar.
- [x] Mirror it to `plugins/dkj-policy/scripts/lib/gate-lib.ps1`, which the shared-scripts drift lint holds
      byte-identical.

### TEST

- [x] The lint gate, locally via `open-pr.ps1`. This branch changes one docstring in a file every other lib
      loads, so the load path is what there is to prove; there is no behaviour to assert.
- [~] The full suite pool, locally. Dropped with the reason, and it is a DELIBERATE GATE BYPASS rather than an
      omission: on this machine (hostname `Dave`) the local pool is repeatedly killed under system-wide memory
      pressure that builds during the run, which can also go false red. `-SkipTests` moves where the suites are
      measured, never whether -- the required check `lint-en-tests` runs them on GitHub's runners and
      `ship-pr.ps1` refuses to merge until it is green. Agreed by Dave in #2267.
- [~] No new suite. Dropped with the reason: the change is a docstring. A test asserting the presence of prose
      would pin wording rather than behaviour, and the drift lint already holds the two copies identical,
      which is the only mechanical property this diff has.

### DEPLOY: docs/2323-gate-proof-per-suite-declined

#2323 asked whether the local gate proof should be keyed per suite instead of over the whole tree, so that a
comment-only commit stops discarding 130 green suites. Measured over 1,114 non-merge commits in the 14 days
after the September rename, the ceiling for the issue's own target class is a median 88.5% of suites and 80.5%
of suite-seconds -- real, and not the prize. Sixteen suites are whole-tree self-checks that no keying scheme
can narrow; `command-probe-lib.ps1` sits in 72% of read sets, mostly transitively, so a commit touching it is
close to the status quo whatever the mechanism; and wall clock runs 10-15 points behind suite count, because
the suites that never survive are the expensive ones. The deciding fact is the cheaper alternative: #2317's
lever 1 removes the expensive instance entirely where a per-suite proof recovers four fifths of it. Declined,
with the reasoning written into `gate-lib.ps1`'s own header so the next proposal meets it there.

**Score:** 1

The failure it prevents, since that is the only part a later reader can use: a per-suite gate proof built on
the cheap shape, drifting silently, skipping a suite on a tree it never measured. Nothing behind the local
proof catches that -- it is the one direction `Get-TestSuiteCostHints`' bar rules out, and the measurement is
what says the saving would not have been worth the exposure.

#### What makes this deploy extra special

A measurement that says *do not build it* is the cheapest deliverable this repo produces and the easiest to
lose. This one cost a full read of the dependency graph and 1,114 commits of history, and it lands as fifty
lines of docstring in the file that would have been changed -- so the next person to have this idea meets the
numbers before they write anything, rather than after.

**Score:** N/A

#### Pull Request

Record why the local gate proof is whole-tree and not per-suite: measured, and declined with the numbers
