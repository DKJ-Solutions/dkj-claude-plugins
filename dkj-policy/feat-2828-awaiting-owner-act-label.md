## feat/2828-awaiting-owner-act-label

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

Inbound #2828: an issue whose decision is made and whose only remaining step is an act the owner
performs (a live push, a release, a deletion) has no parking label, so every sweep re-reads it. Same
shape as #2784 (`awaiting-event`, PR #2787), which this branch follows file for file.

### CREATE

- [x] `awaiting-owner-act` added to the canonical triage labels (`Get-TriageLabels` and the
  adopt-triage-labels fallback), the claim/sweep `-SkipLabel` defaults, the issue dashboard, and the
  skill, contract and portable pages that list the family; mirrors and the blueprint regenerated
- [x] Tests: adopt-triage-labels, repo-config, claim-issue, issue-dashboard and script-contract counts and records

### TEST

The gate runs inside ship-pr.

### DEPLOY: feat/2828-awaiting-owner-act-label

New parking label `awaiting-owner-act`, purple like the rest of the awaiting-* family. It is for an
issue whose decision is already made and whose only remaining step is an act the owner performs
in person, such as a live push, a release or a deletion the session may not run
([#2828](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2828)). The claim and sweep routes
skip it by default and the issue dashboard shows it as parked. The issue names the act, and the label
comes off once it is done.

**Score:** 2

#### What makes this deploy extra special

For a consumer who runs `adopt-triage-labels`: it now offers one more `gh label create` line, for
`awaiting-owner-act`. A sweep no longer has to read an issue that only the owner can move and hold it
out by hand with `-SkipIssue`.

**Score:** 2

#### Pull Request

A sixth parking label: awaiting-owner-act

