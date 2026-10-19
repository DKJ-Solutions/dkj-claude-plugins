## feat/3179-golive-measure-form

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

Inbound #3179 from smartwatchbanden: a ticket whose result is a number the requester re-measures fits
neither completed form -- the go-live form points at a page where nothing visible changed, and
`-Research` says "Nothing has changed", which is false (smartwatchbanden#919, where it was used as a
stand-in and the requester removed the message by hand). Verified in the tree: the two forms and their
markers are the only ones `build-golive-block.ps1` and `asana-closed-message.ps1` know. Built first
because #3177's rule (the requester verifies, not a dev session; owner decided BWJ-wide) names this form.
The comment's `-Research` warning is filed as #3181.

### CREATE

- [x] `golive-block-rules.ps1`: the measurement line and headings (nl/en), the four prose sections,
  `Format-GoLiveClosedLine -Measure`, `Format-GoLiveMeasureBlock`
- [x] `asana-task-lib.ps1` + the template's copy: `Get-AsanaMeasureBlockMarker`
- [x] `asana-closed-message.ps1`: the measurement second line, `Get-ClosedMessageMeasureAsk`, the form in
  `New-ClosedMessageHtml`, detected first in the main flow, with the done section
- [x] `build-golive-block.ps1 -Measure`: its refusals, no go-live half, no pull-request check
- [x] `guard-stale-paste-block.ps1`: the hint names `-Measure`; `live-message-rules.ps1` names the block
- [x] Docs: `golive-block` skill page, `WORKFLOW-portable.md`
- [x] Filed #3181 for the `-Research` warning

### TEST

- [x] `bwj-development.tests.ps1`: 742 pass (block shape and order, optional sections, refusals, the
  closed message's form, ask and precedence, the marker copy held equal)
- [x] The driver run print-only: the block, and its three refusals (`-Link`, measure prose without
  `-Measure`, `-Measure` with `-Research`)
- [x] The full gate runs in `ship-pr`

### DEPLOY: feat/3179-golive-measure-form

`build-golive-block.ps1` gains a third completed form, `-Measure`, for a ticket whose result is a number
the requester measures again -- a page-speed target, a conversion rate, a ranking. From a prose file's
`[measure]` and `[targets]` (and optional `[baseline]` and `[when]`) it writes how to measure and the
targets, and the closed message opens with "Nothing changes visibly on the storefront. You can take a new
measurement yourself, as described below." and ends by asking whether the target is met (#3179).

**Score:** 3

#### What makes this deploy extra special

A BWJ store can close a measurement follow-up with a message that tells the requester how to measure it
and against which targets, instead of a research message that says nothing changed or a go-live message
that points at nothing. The colleague gets a clear "is the target met?" in the Asana task.

**Score:** 3

#### Pull Request

golive-block gains a measurement form for a ticket whose result is a number the requester re-measures

