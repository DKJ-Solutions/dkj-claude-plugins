## feat/2705-admit-phone-factory

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

Dave on #2705 (October 2, 2026): `phone-factory` is a Lightspeed store, so admit it for ticket handling
only. The two Shopify-named parts of chapter one (the `CRO` label, the board-request step) keep their
reach; that decision is #2712.

### CREATE

- [x] `asana-mirror-gate.ps1`: `phone-factory` joins the admitted list.
- [x] `adopt-dkj-policy-bwj` (description, step 0 with the decision, step 7 skipped outside the two
      Shopify stores), `report-issue` (description, "Before you start"), `WORKFLOW-portable.md`, the
      README, and the opening of chapters two to four.

### TEST

- [x] `guard-asana-mirror.tests.ps1`: a phone-factory issue counts as a mirror, and every admitted name
      is in report-issue's list. 49 pass.

### DEPLOY: feat/2705-admit-phone-factory

Inside this repo: the BWJ extension's admitted-repo list, held in `asana-mirror-gate.ps1` and in the two
skill pages that state it, grows to four, and a suite assert now holds the page's list to the gate's.

**Score:** 2

#### What makes this deploy extra special

For the maintainer of `phone-factory`: `adopt-dkj-policy-bwj` and `report-issue` now run there instead
of refusing at step 0, for ticket handling. The Shopify chapters (sync log, preview handover, theme
lifecycle) do not apply, and adopt's step 7 says to skip the sync-log scaffold
([#2705](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2705)).

**Score:** 4

#### Pull Request

dkj-policy-bwj admits phone-factory, for ticket handling only

