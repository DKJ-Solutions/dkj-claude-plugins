## docs/2769-bwj-pr-labels-from-prefix

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

Dave decided yes on #2769. The labels half already landed with #2772, because adoption step 4 creates
`bug` and `feature`. What is left is the prefix-table answer, and it lives in each BWJ consumer's own
`branch-info.ps1`, so the source-side repair is the adoption page saying what to answer.

### CREATE

- [x] `adopt-dkj-policy-bwj` step 4: the prefix table answers `feature` / `bug` / `documentation`, and a pre-#2750 `$null` is replaced
- [x] `open-pr` label-gate example: `feat/` -> `feature`, matching #2764 and #2750

### TEST

- [x] The gates run inside `ship-pr`.

### DEPLOY: docs/2769-bwj-pr-labels-from-prefix

In a BWJ store repo, a `fix/` pull request is labelled `bug` again and a `feat/` pull request
`feature`, now that #2750 brought those labels back for issues. The adoption skill (step 4) shows the
prefix-table rows to use. A table adopted before #2750 still answers no label for those two prefixes,
and the step says to replace those answers. It also says to create the labels first, because `open-pr`
refuses a PR whose label the repo does not have
([#2769](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2769)).

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

BWJ: fix/ and feat/ PRs carry bug and feature again

