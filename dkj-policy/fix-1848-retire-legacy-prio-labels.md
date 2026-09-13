## fix/1848-retire-legacy-prio-labels

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

Both BWJ-Development/smartwatchbanden and BWJ-Development/xoxowildhearts have migrated to prio-1..prio-4 with no legacy label left on either store; drop LegacyPrioLabels and narrow the stale-label sweep in templates/asana-mirror.ps1, and drop the two dkj-policy-bwj.tests.ps1 asserts that pinned its count and its disjointness.

### CREATE

- [x] Verified both stores against the tracker and the repos themselves: #1848's own comments show
  neither had started as of 2026-09-11/12; both have since migrated (additively, not by rename) and
  carry no legacy label at all any more -- confirmed live via `gh label list` / `gh issue list` on
  `BWJ-Development/smartwatchbanden` and `BWJ-Development/xoxowildhearts`.
- [x] Dropped `$script:LegacyPrioLabels` and its comment block from
  `plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.ps1`, and narrowed the `$stale` line in
  `Set-IssuePrioLabel` back to `$script:PrioLabels` alone.
- [x] Dropped the two asserts in `scripts/tests/dkj-policy-bwj.tests.ps1` that pinned
  `LegacyPrioLabels`' count and its disjointness from `PrioLabels`, and the comment block explaining
  them.
- [x] Grepped the tree for any other reference to `LegacyPrioLabels` -- none remain outside this
  branch's own document.

### TEST

- [x] `scripts/tests/dkj-policy-bwj.tests.ps1` runs clean with the two asserts removed (the loop
  asserting every score maps to a `PrioLabels` name already covers the disjointness that mattered).
- [x] `open-pr.ps1`'s own lint + full test-suite gate (`check-plugin-integrity.ps1` + all suites)
  before the push.

### DEPLOY: fix/1848-retire-legacy-prio-labels

Removes dead code from the BWJ Asana-mirror template: `$script:LegacyPrioLabels` existed only to
bridge the window while `smartwatchbanden` and `xoxowildhearts` still carried the pre-#1842 label
names. Both have now migrated and carry no legacy name at all, so the array guards a state that can
no longer arise -- closes #1848.

Only this repo's own maintainers notice: a reader of the sweep logic no longer has to reason about a
legacy-name bridge that no BWJ store still needs, and a future consumer adopting dkj-policy-bwj fresh
never sees the old names at all. Internal script hygiene.
**Score:** 1

#### What makes this deploy extra special

No subscriber of a service is affected -- this is internal script hygiene in a template two already-
migrated consumer repos already run their own copy of; nothing here reaches past this repo's own
maintainers.
**Score:** N/A

#### Pull Request

Retire the legacy BWJ prio-label sweep now that both stores are migrated

