## feat/2917-awaiting-info-client

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

Inbound #2917, the owner's request: `awaiting-more-info` becomes `awaiting-info-client`, in the
`-client` shape of `awaiting-decision-client`. The same pattern as #2723, #2890 and #2904: the new name
everywhere it is prescribed, the old one kept wherever a tracker's label is read.

### CREATE

- [x] The name replaced across the scripts, skills, portable pages, worker and lens; history prose names
  both
- [x] The former name kept in `claim-issue`'s default skip list, every printed `-SkipLabel` line, the
  dashboard's `PARKING_LABELS` and `PARKED_BECAUSE`
- [x] `asana-closed-message.ps1` reads either name as the on-hold label (`Get-OnHoldLabelNames`)
- [x] `adopt-bwj-development` prints the in-place `gh label edit` from either former name
- [x] The config blueprint regenerated
- [x] This tracker's own label: noted on #2905, which waits on the release for the same reason

### TEST

- [x] `bwj-development`, `claim-issue` and `issue-dashboard` suites green on their own, with asserts for
  the former name in the closed message, the skip list and the dashboard

### DEPLOY: feat/2917-awaiting-info-client

The `awaiting-more-info` parking label is now `awaiting-info-client`, so it says who owes the answer, in
the same shape as `awaiting-decision-client`
([#2917](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2917)). `claim-issue`, the sweeps,
the issue dashboard and the BWJ closed message still answer to the old name, because a tracker keeps it
until somebody renames it there. `adopt-bwj-development` prints the in-place rename:
`gh label edit awaiting-more-info --name awaiting-info-client --color 5319E7`.

**Score:** 2

#### What makes this deploy extra special

A BWJ store team that parks a ticket on its requester uses a new label name, and renames the label on its
tracker once, with the command above. Nothing stops working before they do.

**Score:** 3

#### Pull Request

Rename the awaiting-more-info label to awaiting-info-client

