## docs/3557-sweep-lane-mode

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

#3557, decided by the owner 2026-10-27. Option 1 ("teach ship-pr to fold through the worktree holding
main") was verified on pickup and found to exist already in a safer form: #2087's CI-fold arm. Revised
with the owner: build the lane mode on that arm, with no new fold path.

### CREATE

- [x] `sweep-issues`: a lane-mode section (open a detached lane, four steps that read differently, what
  happens without a CI fold runner, the lane at loop end), plus a pointer from the intro
- [x] `worktree-lane` skill page and script header (mirror synced): the stale "ship from the primary,
  always" and the post-merge fatal corrected against #1069 and #2087

### TEST

- [x] Verified rather than assumed: `Get-CiFoldRecoveryVerdict` returns `Recovered: True` here;
  `Get-TrunkReturnDecision` keeps a lane off `main` at step 2b; `new-branch` treats a detached HEAD as a
  base, not a stack; `tidy-machine`'s stale-lane check needs a finished branch (so the page does not
  claim it removes a detached lane)
- [x] Gates: run by `ship-pr`

### DEPLOY: docs/3557-sweep-lane-mode

`sweep-issues` now has a **lane mode** for a second sweep on the same machine
([#3557](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3557)). Open a detached worktree
beside the primary, start Claude Code there, and run the skill. Steps 0, 3 and 7 detach at `origin/main`
instead of checking out the trunk, and `ship-pr` runs from the lane unchanged: it merges and leaves the
fold to the CI fold runner (#2087). The `worktree-lane` page and script header no longer say a lane must
always hand back to ship, because that holds only in a repo without that runner.

**Score:** 3

#### What makes this deploy extra special

You can now run a second issue sweep beside a running one on the same machine, which roughly halves the
time a backlog takes when the gates prove it.

**Score:** 3

#### Pull Request

sweep-issues gets a lane mode: a second sweep in a worktree lane ships through the CI-fold arm

