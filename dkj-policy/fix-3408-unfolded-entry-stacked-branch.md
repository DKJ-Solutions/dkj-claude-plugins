## fix/3408-unfolded-entry-stacked-branch

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

#3408, verified in the code: `Get-UnfoldedTrunkEntry` excluded only the current branch's own document, so
on a stacked branch every unmerged parent's document read as a trunk leftover.

### CREATE

- [x] Off the trunk, a written document counts as a leftover only where it is also in the tree at HEAD's
  merge-base with the trunk (`origin/<trunk>` first, the local trunk second); with no merge-base, nothing is
  narrowed. Offline, as before.
- [x] Function-local `Continue`, so `cat-file`'s stderr cannot turn the narrowing off under a caller's
  `Stop` (the #107 pitfall, measured in the suite).
- [x] The plugin mirror synced.

### TEST

- [x] `unfolded-entry-gate.tests.ps1`: a two-deep stack above a trunk carrying one real leftover -- only the
  leftover is reported, with the branch passed or resolved from HEAD, and the trunk is not narrowed.

### DEPLOY: fix/3408-unfolded-entry-stacked-branch

The unfolded-entry check no longer reports a stacked branch's unmerged parents as changelog entries
stranded on the trunk ([#3408](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3408)). On a branch
stacked three deep with the trunk clean, `unfolded-entry-sessioncheck` printed `[ERROR]` for both parents.
Its remedy, `fold-changelog-entry.ps1 -Commit -Push`, would have put unmerged work's entries onto `main`. Off
the trunk, a document now counts only where it is also on the trunk's tree at HEAD's merge-base with it. A
leftover that came in from the trunk is still reported; a stacked parent's document is not. On the trunk,
nothing changes.

**Score:** 2

#### What makes this deploy extra special

A consumer who stacks branches no longer gets an `[ERROR]` at session start whose remedy folds unmerged
work onto their trunk.

**Score:** 2

#### Pull Request

The unfolded-entry check no longer reports a stacked branch's parent documents as trunk leftovers

