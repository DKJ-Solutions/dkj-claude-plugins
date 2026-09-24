## fix/2425-life-hub-connector-owner

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
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

`life-hub` was transferred from `DaveKJohn` to `DKJ-Solutions` (#2425). Verified: `gh repo view
DKJ-Solutions/life-hub` resolves, and the register's `repo` value is not only a label -- check 1b in
`scripts/sync/check-connectors.ps1` compares a checkout's `origin` against it, so a repointed checkout
reads as a mismatch. Repair the live entry and the format example that mirrors it; the other hits of the
old name are comments, fixtures and dated measurements, left as history.

### CREATE

- [x] `connectors/life-hub.json`: `repo` is `DKJ-Solutions/life-hub`
- [x] `connectors/README.md`: the format example names the same owner

### TEST

- [x] `check-connectors.ps1` reads the entry as `DKJ-Solutions/life-hub`; the lint + test gate runs in `open-pr`

### DEPLOY: fix/2425-life-hub-connector-owner

The connector register names `life-hub` under its new owner, `DKJ-Solutions/life-hub`, so the
origin-vs-register check no longer treats a repointed checkout as a clone of something else. Prevents a
false mismatch on the first `life-hub` checkout whose `origin` is set to the new owner.

**Score:** 1

#### What makes this deploy extra special

N/A -- the register is this repo's own bookkeeping and ships to no subscriber.

**Score:** N/A

#### Pull Request

Connector register names life-hub under its new owner DKJ-Solutions

