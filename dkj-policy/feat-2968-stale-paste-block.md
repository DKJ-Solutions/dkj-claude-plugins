## feat/2968-stale-paste-block

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

#2968, both layers of the design comment, as the owner decided (October 13, 2026). Layer 1 lives in
`bwj-development` as a PreToolUse hook rather than in core `open-pr`/`ship-pr`, because the go-live block
is that extension's concept and core knows nothing about Asana.

### CREATE

- [x] Shared judgement in `asana-task-lib.ps1`: one block predicate (the sections the closed message carries) and a verdict against the last reopen
- [x] Layer 1: `guard-stale-paste-block` PreToolUse hook on `ship-pr.ps1`/`open-pr.ps1`, with a quote-aware command parser
- [x] `build-golive-block.ps1 -Post`: the duplicate check counts only blocks posted since the last reopen
- [x] Layer 2: `asana-closed-message` withholds a stale block and says the result message follows
- [x] Docs: README, WORKFLOW-portable, golive-block, adopt-bwj-development and report-issue pages
- [x] Review round (code, security, copy) applied: one predicate for selection and freshness, parser hardening, shared bounded gh runner

### TEST

- [x] `guard-stale-paste-block.tests.ps1` (new), `bwj-development.tests.ps1`, `template-selfcontained`, `check-plugin-integrity.ps1` green locally; the full gate runs in `ship-pr`

### DEPLOY: feat/2968-stale-paste-block

A go-live block posted before an issue's last reopen no longer reaches the Asana task as the result of the
next round ([#2968](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2968)). A new
`bwj-development` PreToolUse hook refuses a `ship-pr.ps1` or `open-pr.ps1` run while an issue it closes
carries such a stale block, and names the command that posts the fresh one; it is an accident guard that
fails open, with a warning, when it cannot read the issue. `build-golive-block.ps1 -Post` accepts that
fresh block without `-Force`, and the `asana-closed-message` workflow withholds a stale block and says
the result message for this round follows. Hook, script and workflow judge the block by one predicate.

**Score:** 3

#### What makes this deploy extra special

A requester whose ticket was reopened and reworked is no longer sent the previous round's preview link and
description as the new result: the closed message either carries this round's block or says it follows.
A store repo takes the workflow change by re-adopting the `asana-closed-message` template.

**Score:** 3

#### Pull Request

Refuse a merge, and carry no block, when the go-live block predates the issue's last reopen

