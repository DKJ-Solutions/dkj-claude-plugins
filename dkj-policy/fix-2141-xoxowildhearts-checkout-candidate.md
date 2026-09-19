## fix/2141-xoxowildhearts-checkout-candidate

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

Verified the report before repairing it: the checkout is at `../../bwj-development/xoxowildhearts` on
this machine, and the manifest lacks that candidate its sibling carries. The sweep the issue asked
for found no other drift -- the three single-candidate manifests name checkouts absent from this machine
altogether, so there is no measured layout to add.

### CREATE

- [x] Append `../../bwj-development/xoxowildhearts` to `connectors/xoxowildhearts.json`
- [x] `connectors.tests.ps1` case 6b: members of one `siblingGroup` declare the same layouts, so a fifth recurrence fails the gate instead of printing a false `[SKIP]`

### TEST

- [x] `check-connectors.ps1 -Manifest connectors/xoxowildhearts.json` no longer skips: the connector is checked, 0 errors
- [x] Case 6b fails against the pre-fix manifest (`got: '../../bwj-development'`) and passes against the fixed one; suite 384 pass, 0 fail
- [x] `check-plugin-integrity.ps1`: 0 errors (the full suite run is `open-pr.ps1`'s own gate, which refuses the push on a failure)

### DEPLOY: fix/2141-xoxowildhearts-checkout-candidate

`check-connectors` reported `[SKIP] checkout ... not present on this machine` for the xoxowildhearts consumer while its checkout sat at `bwj-development/xoxowildhearts`, so nothing about that consumer was checked here. Its manifest lacked the `bwj-development/` candidate that its sibling `smartwatchbanden.json` gained in #1831 -- the fourth time a candidate fix reached one manifest of a pair and not the other (#1524, #1807, #1831). The candidate is appended, and `connectors.tests.ps1` now holds every manifest of one `siblingGroup` to the same set of layouts, so the next drift fails the gate rather than reading as an absent checkout.

**Score:** 3

#### What makes this deploy extra special

Maintainer-only: the register is read by this repo's own maintenance, and no subscriber of the service sees it. N/A.

**Score:** N/A

#### Pull Request

connectors/xoxowildhearts.json resolves the bwj-development/ layout, so check-connectors stops reporting a false SKIP

