## feat/2764-enhancement-label-becomes-feature

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

#2764 (Dave): the GitHub default label `enhancement` becomes `feature` on this tracker -- the cyan
family `feature-inbound` (#2756) already belongs to. A `gh label edit --name` moves every issue and PR
with it and keeps the colour (`a2eeef`). The label is also what `open-pr` puts on a `feat/` PR, read from
this repo's own seam (`scripts/lib/branch-info.ps1`), so the seam changes with it; otherwise the
missing-label gate refuses the next `feat/` PR. The config blueprint records the seam as `adopt:
decide`, so a consumer keeps its own table and its own tracker's label -- this rename stays here.

### CREATE

- [x] `branch-info.ps1`: `feat` -> `feature`, and the header says why it departs from GitHub's default
- [x] Derek's lens: the prefix table, the two paragraphs naming the label, and the `feature-inbound` family line
- [x] `config-blueprint.json` regenerated from the seam
- [x] Tracker: `gh label edit enhancement --name feature`, run just before the ship so the window in which
  another machine's `feat/` PR meets the old seam stays minutes long -- `open-pr`'s missing-label gate
  refuses that PR before the push, with the remedy, so nothing is left half-done
- [~] Test fixtures that stand for a tracker as it was (`adopt-triage-labels`, `pr-issues`, `teardown`)
  keep `enhancement`

### TEST

- [x] `branch-info.tests.ps1` 42/42 with the pin moved to `feature`; the rest through `ship-pr`

### DEPLOY: feat/2764-enhancement-label-becomes-feature

The `enhancement` label on the source tracker is now `feature`, and a `feat/` pull request here is
labelled `feature`. Consumers keep whatever label their own branch table names.

**Score:** 1

#### What makes this deploy extra special

Nothing beyond the rename itself.

**Score:** N/A

#### Pull Request

The enhancement label is renamed to feature
