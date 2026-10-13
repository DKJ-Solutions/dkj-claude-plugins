## feat/2977-awaiting-review-label

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

Issue #2977 asks for an awaiting label for issues that wait on somebody's eyes. It lands as a pair,
mirroring the decision pair of #2890: `awaiting-review-dev` (the owner's look) and
`awaiting-review-client` (the client's or requester's look). Review means somebody has to LOOK at a
result; decision means somebody has to CHOOSE. Neither has a former name.

### CREATE

- [x] Scripts, config, blueprint, dashboard worker and tests list the pair wherever the other parking
      labels are, in both mirrors (Sylvester #15); the shared parking purple `5319E7`.
- [x] Docs and skill pages list the pair; `sweep-issues` step 5 sets the label on a visible park and
      step 6 removes it on approval (Tessa #16).

### TEST

- [x] The affected suites green on the branch: claim-issue (590/0), issue-dashboard (448/0), pr-issues
      (1150 asserts), config-blueprint (227/0), repo-config and adopt-triage-labels; plugin-integrity
      and script-contract 0 errors. The full gate runs inside ship-pr.

### DEPLOY: feat/2977-awaiting-review-label

Two new parking labels say that an issue waits on somebody's look at a result, not on a choice
([#2977](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2977)). `awaiting-review-dev` is
the owner's look, and `awaiting-review-client` is the look of the client or requester outside the dev
team. `sweep-issues`, the claim defaults and the issue dashboard skip both, so they are treated like
the other `awaiting-*` labels. `sweep-issues` now sets `awaiting-review-dev` when it parks a visible
result and removes it again when that result is approved. `sweep-decisions` walks neither label.

**Score:** 2

#### What makes this deploy extra special

A consumer who runs `adopt-triage-labels` is offered two new labels to create. Once a preview is
waiting for someone to look at it, the issue drops out of every sweep until the label comes off.

**Score:** 2

#### Pull Request

Add awaiting-review-dev and awaiting-review-client parking labels

