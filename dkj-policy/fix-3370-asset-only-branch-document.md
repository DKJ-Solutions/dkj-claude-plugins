## fix/3370-asset-only-branch-document

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

Issue #3370: take the branch's own development document out of the change CI's asset-only selection judges.

### CREATE

- [x] `Remove-BranchDocumentPath` in `ci-suite-selection-lib.ps1`: one exact path, nothing when unresolved
- [x] `get-pr-suite-selection.ps1` resolves the head branch's document through `Resolve-BranchFilePath` and drops it before the verdict; a failed resolve keeps it in
- [x] asserts in `ci-suite-selection-lib.tests.ps1`, the #3369 case included

### TEST

- [x] the gates, run by ship-pr

### DEPLOY: fix/3370-asset-only-branch-document

A pull request that changes only stylesheets, images or fonts now really runs only the suites that read them on CI. The asset-only lane from #3309 had never fired, because every pull request also carries its own branch document, a Markdown file, and that one file sent every run to the whole pool. CI now leaves that one document out of the judgement, and only that one: any other changed file still runs everything. On a one-line CSS change like #3369 the suites leg drops from about seven and a half minutes over five shards to the handful of suites that touch the stylesheet.

**Score:** 2

#### What makes this deploy extra special

N/A -- this repo's own CI; nothing a plugin user takes changes.

**Score:** N/A

#### Pull Request

Let CI's asset-only suite selection see past the branch document

