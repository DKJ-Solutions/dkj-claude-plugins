## fix/2197-consumer-lens-fp-measured

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

Closes #2205, the residual of #2197 rather than #2197 itself. #2197's own question -- the
false-positive rate of the two gated prose detectors over a CONSUMER's lenses -- was measured and
answered in its own thread, and it is closed on its merits. What it left behind is a sentence on the
trunk that outlived both events by minutes.

#### The ordering that produced it

Three events inside 140 seconds, none of them wrong on its own:

| time (UTC) | event |
|---|---|
| 13:49:09 | PR #2202 merges `fix/2188-gated-detectors-read-lenses` -- the widened corpus, and its "open half" sentence, reach `main` |
| 13:51:24 | #2197's measurement lands as a comment, closing with *"which is parked with no pull request"* and *"Nothing on `main` is wrong today, because the widened corpus is not on `main`."* |
| 13:51:25 | #2197 is closed `COMPLETED` |

Both of those closing statements were true when that measurement began and false when it was
written. `verify-resolved-issues.ps1` could not catch it: #2202 declared `Closes #2188` only, which
was correct at the moment it opened.

#### The measurement this branch writes down

Taken against the landed code on a machine holding four of the six registered `localCheckout`
paths -- 4 consumer checkouts, 93 lens files, 3,299 lines, every finding opened at its file and
line and classified by hand.

| detector | raw | real |
|---|---|---|
| `Get-SupremacyDeclaration` | 1 | 1 |
| `Get-RetiredDocNameMention` | 26 | 6 |

Independently corroborated on this checkout for the two BWJ consumers that resolve here
(`smartwatchbanden` 3/3 retired, `xoxowildhearts` 1/1 supremacy), with the pre-#2188 corpus run as
the baseline on both: **0 findings**, so every one of them is attributable to the lens widening.

### CREATE

- [x] Replace the `NO CONSUMER LENS WAS MEASURED` passage in `Get-ConsumerProseDocuments` with the
      result, in `scripts/lib/entry-scaffold-lib.ps1`.
- [x] Apply the identical replacement to the mirrored `plugins/dkj-policy/scripts/lib/entry-scaffold-lib.ps1`,
      so the shared-scripts drift lint stays green.
- [~] No per-detector narrowing and no call-site change. Dropped because the measurement says so:
      the `-RepoRoot` seam #2197 pre-built stays available and unused.

### TEST

- [x] Both mirrored copies byte-identical after the edit (`diff`, clean).
- [x] The retired sentence occurs nowhere in `scripts/` or `plugins/` any more.
- [x] Lint gate + all suites, via `open-pr.ps1`.

### DEPLOY: fix/2197-consumer-lens-fp-measured

`Get-ConsumerProseDocuments` now states the consumer-lens false-positive measurement instead of
naming it as the open half somebody still has to take. The passage it replaces asserted two things
that stopped being true within minutes of it reaching the trunk -- that no consumer lens had been
measured, and that #2197 carried the question -- and a docstring that names an open question is
read as an invitation to go and answer it, which is the work this would have cost the next reader.

The decision it records is that **both detectors keep the lenses**: `Get-SupremacyDeclaration` at
1 raw / 1 real and `Get-RetiredDocNameMention` at 26 raw / 6 real over 4 consumer checkouts, 93
lens files and 3,299 lines. The flat ratio is deliberately not what the entry turns on -- read per
consumer it is four for four, because every repo whose verdict the widening actually changes
receives only real findings, and the 23/3 sits entirely in one consumer that was already red on 36
non-lens findings. The `-RepoRoot` seam stays available and unused; no code changed.

**Score:** 2

#### What makes this deploy extra special

A repo running this workflow receives this file through a plugin update, and a developer there who
reads the old passage is told the question is open and the seam is waiting to be narrowed. The
nameable failure is that they measure it again, or narrow a detector on an argument the numbers
have already settled against -- the 6 real restatements and 1 real inversion it would have
suppressed are exactly the findings nothing else in this workflow could have surfaced.

**Score:** 1

#### Pull Request

Get-ConsumerProseDocuments states the consumer-lens measurement instead of naming it as an open half