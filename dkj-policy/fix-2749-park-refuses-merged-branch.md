## fix/2749-park-refuses-merged-branch

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

#2749, verified on pickup: `Invoke-GitPark` pushes whenever its commit half returns Ok, with no question
about whether the trunk already holds the branch. `park-cycle.ps1` has its own guard (it asks gh for
the PR state), so it was never the path. `park-branch` and `new-branch -Park` were.

The refusal sits in `Invoke-GitPark` behind a new `-Trunk` parameter, so both entry points share one
definition and park-cycle's behaviour is unchanged. A HEAD **equal** to the trunk tip is not refused,
because a branch just cut has shipped nothing. The issue's second proof, the head of a merged PR, is
left out: it costs a gh call on every park, and this workflow merges with merge commits, where the
ancestor proof already covers the measured case.

### CREATE

- [x] Sylvester: `Invoke-GitPark -Trunk` refuses a HEAD that `origin/<trunk>` or `<trunk>` already contains (strict ancestor), before the push; park-branch passes `'main'` (its existing guard's name, no repo config loaded), new-branch passes its resolved `$trunk`; plugin mirrors synced
- [x] Tycho: park-branch suite pins the merged case (exit 1, nothing on origin) and the fresh-branch case (still parks), 36 passed

### TEST

### DEPLOY: fix/2749-park-refuses-merged-branch

`park-branch` (and `new-branch -Park` on a resumed branch) no longer re-pushes a branch that has
already merged. It used to report "nothing new to commit" and push, which recreated the remote head the
merge had deleted, and then `prune-merged -IncludeRemote` listed it as a merged head to delete again.
Now a branch the trunk already contains is refused with exit 1, nothing is pushed, and the message
points you at `prune-merged`. A branch just cut from the trunk, with nothing on it yet, still parks as
before.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

park refuses a branch that has already merged, instead of recreating its deleted remote head

