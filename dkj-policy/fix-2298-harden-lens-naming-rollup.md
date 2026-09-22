## fix/2298-harden-lens-naming-rollup

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

#### What this branch is

Follow-up to #2289 / PR #2294, which landed the lens-naming roll-up. Three points were raised on that PR
while it was green and deliberately not pushed onto it -- a push would have reset its checks and put its
own DEPLOY lock in the way of a merge that was in flight. Each was re-verified against the merged trunk
at `1baa9bb2` before this branch was opened, and each still stood.

#### Why one branch and not three

They are coupled in one direction: the seam in part 3 is what makes parts 1 and 2 assertable at all, and
landing it first would pin the current verdict shape as correct -- so the coverage and the two
corrections have to arrive together, or the tests certify what they were written to change.

### CREATE

- [x] **The marker.** `[LENS-NAMING]` -> `[LENS-RETIREMENT]`, 8 sites in `check-connectors.ps1` plus the
      two sample blocks in `connectors/README.md`. `check-roster-sync.ps1:1271` keeps the original for
      the unrelated fact it has always meant by it (#2219).
- [x] **The precedence.** A measured `NOT YET` now outranks an unreached connector, and carries the
      unmeasured count in its own sentence so the list is never read as complete.
- [x] **The seam.** `-ConnectorsRootOverride`, test-only, documented as such in `.PARAMETER`.
- [x] Both the header block (check 7) and `connectors/README.md` state the two reversals and their
      reasons, so the next reader meets the argument rather than the diff.

### TEST

- [x] `scripts/tests/connectors.tests.ps1` scenario 14: eight cases, 36 assertions -- all over, one
      behind, an absent checkout, a checkout with no lenses, a PART-migrated consumer, the precedence
      rule, the marker, and a narrowed run. 424 pass, 0 fail.
- [x] Run against the live register: `NOT YET: 2 of 6 ... 3 of the 6 could not be measured here`, which
      is the corrected verdict on the same data that previously printed `NOT ANSWERABLE`.
- [x] Lint gate + full suite green.

#### The assertion that failed first, and what it was right about

14h originally asserted that a narrowed run prints no `LENS-RETIREMENT` at all. It failed -- and the
code was right. The per-connector reading is about the ONE consumer in front of you and is exactly as
true on `-Manifest` or `-OnlyConsumer` as on a full sweep; only the register-wide VERDICT is unfounded
there. Asserting on the marker conflated the two halves, so the assertion now names the three verdict
wordings one by one and pins the per-connector line as still present.

That is the whole argument for part 3 in miniature: the first thing this seam did was catch a wrong
belief about the block it was built to cover.

### DEPLOY: fix/2298-harden-lens-naming-rollup

The lens-naming roll-up from #2289 gets three corrections. Its marker becomes `[LENS-RETIREMENT]`, so it
no longer shares a token with `check-roster-sync.ps1`, which prints `[LENS-NAMING]` for the unrelated
fact that its own naming vocabulary is older than the tree it reads (#2219). Its verdict now lets a
measured `NOT YET` outrank an unreached connector, carrying the unmeasured count into that same sentence.
And a test-only `-ConnectorsRootOverride` gives the roll-up the seam it needs to be tested at all.

The precedence is the half that changes an answer. Both arms are about coverage, which makes the cautious
one look like the one that should win -- but they are not on the same axis: a connector measurably on the
also-read spelling settles the condition as FALSE, and nothing an unreached one holds can make it true
again. On the live register -- 1 over, 2 behind, 3 unreached -- the run printed `NOT ANSWERABLE FROM THIS
MACHINE` while the answer, *no*, was in hand. The green ending keeps exactly the gate it had: still
reachable only when nothing is behind **and** nothing is unreached or empty.

The seam exists because the roll-up fires only on a full-register sweep, which is precisely what
`-Manifest` -- that suite's isolation everywhere else -- switches off, so its verdict logic landed with
zero assertions on it. Scenario 14 now covers all three endings, the part-migrated state, the grouping
and the narrowed run.

**Score:** 3

#### What makes this deploy extra special

It is a signal being made trustworthy in the same week it was built. A readiness check exists to be read
once, months later, by somebody deciding whether a compatibility layer may be removed -- which is the
worst possible moment to discover that its verdict understated what it measured, or that nothing ever
asserted its verdict at all.

For a subscriber of this workflow nothing changes in behaviour: no new error, no new exit code, no new
session-start line. What changes is what a deliberate run of the connector check tells them when part of
the register is out of reach, which is the normal case rather than the exception.

**Score:** 2

#### Pull Request

The lens-naming roll-up: a marker of its own, a verdict that does not understate what it measured, and the seam that pins both
