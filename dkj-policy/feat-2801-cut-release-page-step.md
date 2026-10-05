## feat/2801-cut-release-page-step

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

Inbound [#2801](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2801), verified: `cut-release.ps1`'s
closing block names the GitHub Release and the hand-written documents, and nothing for the release-notes page,
and the skill's Block 1 has no step for it. The consumer's own publish script is not shipped upstream:
`build-release-notes-page.ps1 -Worker` already prints the deploy and the byte check, and the deploy stays a
command a person runs.

### CREATE

- [x] `cut-release.ps1` prints the page step after the GitHub Release line where `Get-ReleasePageWorkerName` is answered (both copies)
- [x] `cut-release` skill: step 5b, after the GitHub Release
- [x] Static asserts in `cut-release-guardrail.tests.ps1`

### TEST

- [x] `cut-release-guardrail.tests.ps1`: 120 pass

### DEPLOY: feat/2801-cut-release-page-step

`cut-release` now names the release-notes page as a step. Where a repo answers `Get-ReleasePageWorkerName`,
the cut's closing block prints the `build-release-notes-page.ps1 -Worker` command after the GitHub Release
line, with the instruction to verify the bytes the URL serves. The `cut-release` skill carries it as step 5b.

**Score:** 2

#### What makes this deploy extra special

A repo that publishes a release-notes page is told to rebuild and redeploy it at every cut. Before, nothing
named the step, so the page could stay on the previous release until somebody asked.

**Score:** 3

#### Pull Request

cut-release names the release-notes page step where a repo publishes one

