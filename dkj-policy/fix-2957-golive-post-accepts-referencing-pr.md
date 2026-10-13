## fix/2957-golive-post-accepts-referencing-pr

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

Let build-golive-block's landing check accept an open or merged PR that cross-references the issue, so an Asana-linked issue shipped with -NoResolves can be posted without -Force.

### CREATE

- [x] `Get-GoLiveLandingNodes` in `golive-block-rules.ps1`: the closing references plus every same-repo pull
  request that cross-references the issue (timeline `CROSS_REFERENCED_EVENT`); an issue reference and a PR
  in another repo are dropped
- [x] `build-golive-block.ps1`: one GraphQL query reads both lists; refusal, unread and landing lines say
  "closes or references", and the refusal names the `-NoResolves` shape
- [x] Docs: `golive-block` SKILL.md, `WORKFLOW-portable.md` and `PREVIEW-portable.md` say a reference counts, and why

### TEST

- [x] `bwj-development.tests.ps1`: unit asserts for `Get-GoLiveLandingNodes` (same repo kept, other repo and
  issue reference dropped, closing references alone still count, null issue) and a driver run where a
  merged PR only references the issue -- 519 asserts green

### DEPLOY: fix/2957-golive-post-accepts-referencing-pr

`build-golive-block -Post` now accepts an open or merged pull request that **references** the issue, as
well as one that closes it
([#2957](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2957)). `bwj-development`'s own rule
ships an Asana-linked issue with `-NoResolves`, so its PR never closes it. The landing check from #2930
read closing references only, so on exactly the issues the block exists for `-Force` was the only way
through. Measured twice in `BWJ-Development/smartwatchbanden` on October 13, 2026. Only pull requests
in the same repo count.

**Score:** 3

#### What makes this deploy extra special

A store session posting the go-live block after a `-NoResolves` ship no longer gets a refusal telling it
to use `-Force`, and the refusal it can still get names both PR shapes.

**Score:** 3

#### Pull Request

golive-block -Post accepts a pull request that references the issue

