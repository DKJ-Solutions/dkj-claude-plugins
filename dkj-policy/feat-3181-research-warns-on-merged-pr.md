## feat/3181-research-warns-on-merged-pr

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

#3181, split off from #3179's comment: `-Research` says "Nothing has changed" and never looks at whether
a merged pull request closes or references the issue (smartwatchbanden#919). The issue left warn versus
refuse open; this branch warns, because a PR can cite a research ticket without changing the store and
only the session knows which, and a refusal would make `-Force` the ordinary path again (#2957's lesson).

#### A visible result?

No: a console warning in a script, proven by the suite.

### CREATE

- [x] `build-golive-block.ps1`: the landing read as one function (`Read-GoLiveLandingState`), shared by
  the result form's refusal and the new `-Research` warning on the post path
- [x] Docs: the driver's `-Research` help and the `golive-block` skill page

### TEST

- [x] `bwj-development.tests.ps1`: 750 pass -- the warning's place and that it does not exit, the query
  written once, and `-Measure` through `-File` (the block and its three refusals)
- [x] The full gate runs in `ship-pr`

### DEPLOY: feat/3181-research-warns-on-merged-pr

`build-golive-block.ps1 -Research -Post` now warns when a merged pull request closes or references the
issue: the research form tells the requester "Nothing has changed", which is then likely false, and the
warning names the go-live form with `-LiveSince` and `-Measure` instead. It is a warning, not a refusal
(#3181).

**Score:** 2

#### What makes this deploy extra special

A session about to close a BWJ ticket with a research message after a change already went live is told
so before the requester reads "Nothing has changed".

**Score:** 2

#### Pull Request

build-golive-block -Research warns when a merged pull request closes or references the issue

