## fix/2620-golive-no-predicted-version

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

Inbound #2620, verified in the tree: `build-golive-block.ps1` stepped the newest tag by today's pending
tally and wrote the result into the block as `als versie vX.Y.Z`. The repair is the issue's first
option: the block names a version only when `-Version` is passed. The projection is still worked out and
printed on the console, where the session can weigh it.

### CREATE

- [x] `build-golive-block.ps1`: the derived number goes to the console as a projection; only `-Version` reaches `Format-GoLiveBlock`
- [x] the golive-block SKILL.md, `WORKFLOW-portable.md`, README and plugin.json descriptions no longer promise a version

### TEST

- [x] `dkj-policy-bwj.tests.ps1`: a fixture repo with a `v2.45.0` tag and a patch tally, run without `-Version`, prints `projected v2.45.1` and writes a block with the release day alone -- 494 asserts green standalone

### DEPLOY: fix/2620-golive-no-predicted-version

The go-live block no longer names a predicted version. It stepped the newest tag by the bump the
pending changelog named that day, and every entry still to land before the release could raise it, so
the colleague reading the block got a guess that read as a fact. The block now names the release day
alone, unless `-Version` is passed. The projection is still printed on the console for the session
(#2620).

**Score:** 2

#### What makes this deploy extra special

In a store repo running `dkj-policy-bwj`, the block pasted into Asana no longer carries a version
number the owner has to strike out by hand. Pass `-Version` once the number can no longer change.

**Score:** 2

#### Pull Request

golive-block: the colleague-facing block names no predicted version unless -Version is given
