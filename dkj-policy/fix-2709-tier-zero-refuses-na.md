## fix/2709-tier-zero-refuses-na

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Issue [#2709](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2709): PR #2706 shipped tier 0 as
`N/A` through `open-pr` and the CI `branch-entry` check. The reason held up against the code: the parser
flagged `N/A` per tier but nothing refused it on tier 0.

**Where the refusal goes, and why there.** `open-pr` already splits the entry faults by kind: a *malformed*
value (off the rubric, an unknown tier) is refused before the push, and a *missing* score is only reported,
because Dave placed that refusal at the cut (August 5, 2026). Tier 0 answered `N/A` is the malformed kind, a
value the model has no meaning for. So it became a parser error in `Resolve-EntryImpact`, which `open-pr`
refuses as it stands. `check-branch-entry` refused no malformed value at all, so it gains `open-pr`'s
refusal. The cut sees it through `Get-EntryImpactFindings`, which carries the parser's errors.

**A blank tier-0 score still passes, deliberately.** That is what keeps a repo that never adopted the
ranking quiet ("TIER 0 OWES NOTHING"), and the issue asked about `N/A` only.

#### The pending entry this would have stopped

`#2706`'s entry is in `CHANGELOG.md`, pending the next cut with tier 0 as `N/A`, and the cut would refuse
it after this change. PR #2710 scored it on `main` while this branch was in CI, so the merge-up takes
`main`'s version and this branch no longer touches `CHANGELOG.md`.

### CREATE

- [x] `entry-scaffold-lib.ps1` (both copies): `N/A` under tier 0 is a parse error naming the rule
- [x] `check-branch-entry.ps1` (both copies): refuses a malformed tier or score, as `open-pr` does
- [x] `check-branch-entry` SKILL.md: the new refusal in its table, and blank set apart from `N/A`
- [~] `dkj-policy/CHANGELOG.md`: #2706's pending entry gets its tier-0 score -- dropped, PR #2710 did it on `main` first
- [x] tests: `entry-scaffold.tests.ps1` (both entry shapes, plus the valid audience-tier `N/A`) and `branch-entry-gate.tests.ps1` (exit 1 on the measured case)

### TEST

- [x] `entry-scaffold.tests.ps1`: 898 of 898
- [x] `branch-entry-gate.tests.ps1`: 67 of 67

### DEPLOY: fix/2709-tier-zero-refuses-na

**A tier 0 answered `N/A` is now refused before the merge.** `open-pr` and the CI `branch-entry` check
refuse it, and so does the release cut. DEVELOPMENT-portable gives tier 0 a score, always, but no gate read
that rule, so PR #2706 shipped one through both. It is now a malformed value, refused like an off-rubric
score. `check-branch-entry` now refuses malformed values the way `open-pr` does, where before it only
reported them. A blank tier-0 score still passes
([#2709](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2709)).

**Score:** 2

#### What makes this deploy extra special

For a maintainer of a repo running this workflow: an entry with tier 0 written as `N/A` is refused at
`open-pr` and by the `branch-entry` CI check, naming the rule, so it gets fixed on the branch rather than
on the trunk. A green `branch-entry` check now also means no malformed score.

**Score:** 2

#### Pull Request

The entry gates refuse N/A on tier 0, which always takes a score

