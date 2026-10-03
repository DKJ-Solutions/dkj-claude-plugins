## docs/2750-issue-labels-not-types

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

Dave's decision on #2750 (October 3, 2026): stop using GitHub issue types, use labels only. An issue
with no `bug` or `feature` label is a task. The Asana `Github Type` field stays, filled from the labels.
Deleting the org-wide types is an org setting, so it is the owner's to do.

### CREATE

- [x] `report-issue`: classify with `--label bug` / `--label feature` on the create, drop the type `PATCH`, fill `Github Type` from the label
- [x] `WORKFLOW-portable.md`: the classification section becomes labels-only, and the `Github Type` paragraph maps from the labels
- [x] `adopt-dkj-policy-bwj` step 4: check for and create `bug` (magenta) and `feature` (cyan); seam comment updated
- [x] `README.md`: the `Get-AsanaTypeFieldGid` line names the label as the source

### TEST

- [x] No test or script pins the removed wording (searched every `.ps1` for the type `PATCH`, the old anchor and "issue type")
- [x] Every link to the renamed `WORKFLOW-portable.md` heading points at the new anchor

### DEPLOY: docs/2750-issue-labels-not-types

`report-issue` no longer sets a GitHub issue type. It classifies an issue by label: `bug` for a defect
in existing behaviour, `feature` for a capability the store does not have yet, and neither for
everything else, which counts as a task. Where the Asana board has a `Github Type` field, it is filled
from that label. `adopt-dkj-policy-bwj` now checks for `bug` and `feature` and prints the create line
for whichever is missing. Both were deleted from the BWJ stores in September, so a store has to create
them before the next filing that uses one.

**Score:** 3

#### What makes this deploy extra special

Nothing beyond the switch itself.

**Score:** N/A

#### Pull Request

dkj-policy-bwj: classify issues by label, not by GitHub issue type

