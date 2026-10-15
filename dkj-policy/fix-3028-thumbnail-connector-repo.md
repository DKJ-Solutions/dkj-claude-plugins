## fix/3028-thumbnail-connector-repo

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

#3028: the consumer `DKJ-Solutions/thumbnail-generator` was renamed to `DKJ-Solutions/dkj-thumbnail-generator`,
and on this machine the checkout folder carries the new name too. The fix follows the #2980 pattern for the
`repo` field. `localCheckout` becomes a candidate list (#1524), so a machine that still has the old folder
name keeps resolving.

### CREATE

- [x] `connectors/thumbnail-generator.json`: `repo` is now `DKJ-Solutions/dkj-thumbnail-generator`,
      `localCheckout` lists `../dkj-thumbnail-generator` before `../thumbnail-generator`, and a RENAMED note
      is appended.

### TEST

- [x] `gh api repos/DKJ-Solutions/thumbnail-generator` resolves to `DKJ-Solutions/dkj-thumbnail-generator`.
      `check-connectors.ps1` now finds the checkout and reads its block. The block shows one lag in the
      register, filed as #3029.

### DEPLOY: fix/3028-thumbnail-connector-repo

The connector register names thumbnail-generator's renamed repo, `DKJ-Solutions/dkj-thumbnail-generator`, and its
renamed checkout folder ([#3028](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3028)). Until now
the connector check could not find that checkout and skipped its whole block.

**Score:** 1

#### What makes this deploy extra special

N/A: the register is bookkeeping inside this repo, and no consumer takes it.

**Score:** N/A

#### Pull Request

connectors: thumbnail-generator names its renamed repo and checkout folder
