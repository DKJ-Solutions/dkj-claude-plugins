## fix/3039-tidy-lane-remove

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

Issue [#3039](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3039). Read in
`worktree-lane.ps1`: `-HandBack` removes the lane and then checks its branch out in the primary, which
is the hand-over for work that still has to ship. Lane 1 only ever reports a finished (merged or
closed) branch, so the bare `git worktree remove` is the one command that frees it.

### CREATE

- [x] `Get-StaleLaneDecisions` (`tidy-lib.ps1`) hands over `git worktree remove` only; the `-HandBack` line and the `RawCommand` field are gone.
- [x] `tidy-machine.ps1` prints the one line, and the skill's lane table says so. Both mirrors synced.
- [x] `prune-merged.ps1` had the same handover for a merged branch a lane holds: now `git worktree remove` too (mirror synced).

### TEST

- [x] `tidy-lib.tests.ps1`: a finished lane's command is `git worktree remove` and never `-HandBack`; 91 passed.
- [x] `prune-merged.tests.ps1`: a held merged branch is handed `git worktree remove`, never `HandBack -Lane`; 128 passed.

### DEPLOY: fix/3039-tidy-lane-remove

`tidy-machine` lane 1 now hands over `git worktree remove <lane>` for a lane whose branch is finished,
instead of `worktree-lane.ps1 -HandBack`
([#3039](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3039)). The hand-back checked the
merged branch out in the primary checkout, so lane 2 still could not reap it, and its script path does
not exist in a consumer. `prune-merged`, which said the same for a merged branch a lane holds, now says
`git worktree remove` too.

**Score:** 2

#### What makes this deploy extra special

When `tidy-machine` finds a worktree holding a merged or abandoned branch, the command it prints now
removes that worktree and leaves your primary checkout where it is, so a rerun deletes the branch. It
used to print a command that put the finished branch back in your primary checkout and told you to ship
it, and in a consumer repo that command's path did not exist.

**Score:** 2

#### Pull Request

tidy-machine lane 1 hands over git worktree remove for a finished lane, not -HandBack

