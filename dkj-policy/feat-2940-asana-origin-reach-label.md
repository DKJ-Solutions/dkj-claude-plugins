## feat/2940-asana-origin-reach-label

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

Inbound #2940, verified on pickup: `guard-asana-mirror` holds issue -> card only; `asana-pickup-rules.ps1`
checks the link and never the reach label; section 8 and report-issue's "came the other way" never name it.

### CREATE

- [x] `Get-ProjectReachLabel` in `asana-mirror-gate.ps1`: the guard's inline `Get-ReachLabel` read, now one definition for both hooks
- [x] `Format-AsanaReachLabelWarning` in `asana-pickup-rules.ps1`, and `asana-link-pickupcheck` reads the labels in the same `gh` call and names a linked issue without the label
- [x] WORKFLOW-portable sections 2 and 8 and `report-issue` state that an issue made from an Asana ticket carries the reach label

### TEST

- [x] `asana-link-pickupcheck.tests.ps1`: the warning, a failed label read, the project's own label name, and `Get-ProjectReachLabel`'s three paths (48 pass)
- [x] `guard-asana-mirror.tests.ps1` still green on the shared reader (49 pass)

### DEPLOY: feat/2940-asana-origin-reach-label

In `bwj-development`, an issue made from an Asana ticket now carries the reach label by construction. WORKFLOW-portable sections 2 and 8 and `report-issue` say so. When `claim-issue` or `new-branch` picks up an issue that links an Asana task but lacks the label, `asana-link-pickupcheck` prints a `REACH LABEL MISSING` line with the `gh issue edit` that adds it. Until now only the issue -> card direction was enforced, by `guard-asana-mirror`. Both hooks now read the label's name through one function, `Get-ProjectReachLabel` ([#2940](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2940)).

**Score:** 2

#### What makes this deploy extra special

In a BWJ store repo, a ticket a colleague filed in Asana no longer drops out of the minor backlog because whoever copied it into GitHub forgot the reach label. The pickup names the missing label and gives the command that adds it.

**Score:** 2

#### Pull Request

An issue made from an Asana ticket carries the reach label, and pickup flags one that does not

