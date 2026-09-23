## fix/2350-backup-waits-through-short

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

#2350: `Get-ThemeFillVerdict`'s two callers read `short` differently -- `backup-live-theme` broke on the
first one, `push-preview` waited until its deadline. Dave's decision (September 23, 2026): push-preview's
reading is right; a stable count below the source is a refusal only once the wait is over, since a copy
grows in bursts with pauses between them (#1965). Verified in the tree: the backup's break is one line, and
the check below its loop already fails anything that is not `complete` at the deadline.

### CREATE

- [x] `backup-live-theme.ps1`: the wait ends early only on `complete`; `short` is judged after the deadline
- [x] `theme-lifecycle-rules.ps1`: `Get-ThemeFillVerdict`'s docstring states the shared reading
- [x] Shopify plugin mirrors synced

### TEST

- [x] `theme-lifecycle-rules.tests.ps1`: a guard that neither caller breaks its fill wait on `short` -- red
  without the fix, green with it (106 pass). The loops drive a live store, so the guard holds their shape.
- [x] Gates run by `ship-pr` itself

### DEPLOY: fix/2350-backup-waits-through-short

`backup-live-theme` failed a backup the moment two file-count samples agreed below the live theme's count,
while `push-preview` waited such a reading out. A duplicate grows in bursts with pauses between them, so a
pause could fail a copy that was still filling. The backup now waits until its deadline like the preview
does, and still refuses a copy that is short when the wait is over.

**Score:** 2

#### What makes this deploy extra special

A Shopify store's release-cut backup no longer fails on a copy that was only pausing, which left a
half-copy standing and the cut step red. A copy that really stopped short is still refused, only later.

**Score:** 2

#### Pull Request

backup-live-theme waits through a 'short' fill verdict until its deadline, as push-preview does

