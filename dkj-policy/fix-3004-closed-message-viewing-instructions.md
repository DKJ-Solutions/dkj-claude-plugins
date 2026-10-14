## fix/3004-closed-message-viewing-instructions

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

Inbound #3004 (Maikel): `asana-closed-message` posted a bare "is now closed" on smartwatchbanden#943's
task, a research ticket closed by hand with no PR and no block. The rule: a completed close must always
say how to view the result. Three asks, all taken; Maikel's later correction withdrew the "link to the
issue" fallback, so it is not built.

- Ask 1, the fallback: a completed close that carries no block, for any reason, adds the existing #2968
  sentence "The result message for this round follows." It never sends the closed line alone. The run
  log says the assignee still owes the requester that message. Chosen over a link (withdrawn) and over
  silence (the requester would not hear the work is done).
- Ask 3, the form: `build-golive-block -Research` writes Maikel's research shape, with the findings
  under `[found]`. Recognised by a second marker (the block route of the issue's two candidates, the one
  that also gives ask 2 something to post).
- Ask 2, the guard: `guard-stale-paste-block` also reads `gh issue close` as completed and refuses it on
  an Asana-linked issue with no block for this round. The one GraphQL read now returns the body too.

### CREATE

- [x] `asana-task-lib.ps1`: `Get-AsanaResearchBlockMarker`; the block-state read returns the issue body
- [x] `templates/asana-closed-message.ps1`: the research closed line, and no completed close without a block goes out bare
- [x] `golive-block-rules.ps1` + `build-golive-block.ps1`: `-Research`, `[found]`, `Format-GoLiveResearchBlock`
- [x] `stale-paste-block-rules.ps1` + `guard-stale-paste-block.ps1` + `hooks.json`: the close guard
- [x] Docs: `WORKFLOW-portable.md`, `golive-block` and `adopt-bwj-development` skills, the README's hook row

### TEST

- [x] `guard-stale-paste-block.tests.ps1`: the close parser and the close guard against the fake gh (111 asserts pass)
- [x] `bwj-development.tests.ps1`: research block, research message end to end, no bare close, `-Research` through `-File` (623 asserts pass)

### DEPLOY: fix/3004-closed-message-viewing-instructions

An Asana task now always hears how to view the result when its issue closes as completed. Where the
close carries no go-live block, the closed message adds that the result message follows, instead of
the closed line alone. A ticket that changed nothing on the store (research, a test, a decision) gets
a research block: `build-golive-block -Research` writes the findings for the requester, and the closed
message opens with *"Nothing has changed. This issue was for research purposes only."* The
`guard-stale-paste-block` hook now also refuses `gh issue close` as completed on an Asana-linked issue
with no block for this round, naming both commands
([#3004](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3004)).

**Score:** 3

#### What makes this deploy extra special

A BWJ store maintainer meets the change the first time a session closes an Asana-linked issue by hand.
The close is refused until a block is on the issue. Requesters stop receiving a bare "is now closed".
The store's copy of `asana-closed-message.ps1` has to be taken again; `closed-message-sessioncheck`
reports the difference at session start.

**Score:** 3

#### Pull Request

asana-closed-message: a completed close always says how to view the result
