## fix/3190-live-record-whole-pr-diff

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

#### Issue #3190

`notify-live -LivePushRecord` read a PR's paths as `git diff <merge>^1 <merge>`. For a rebase-merge, that
diff is only the last rebased commit. I verified this against the code that landed with #3191.

### CREATE

- [x] `live-message-rules.ps1`: `Get-PullChangedPaths` joins the merge's diff with gh's `files`. It
  reports the paths as not complete where gh's list is short of `changedFiles` (gh caps the list) and the
  merge is not a two-parent merge commit
- [x] `notify-live.ps1`: asks for `files,changedFiles` in the same `gh pr view` call, reads the merge's
  parent count, and reads an incomplete PR as UNREAD (the issue is not told)

### TEST

- [x] `bwj-development.tests.ps1`: the union, the capped one-parent case, the two-parent case, an empty PR,
  and the driver wiring (789 passed)

### DEPLOY: fix/3190-live-record-whole-pr-diff

The change here is only in the bwj-development plugin's script and its tests.

**Score:** 1

#### What makes this deploy extra special

In a BWJ store repo, `notify-live -LivePushRecord` now sees a held file that an earlier commit of a
rebase-merged PR touched, and does not tell that issue's requester their work is live. A PR whose file
list gh truncates is reported as UNREAD instead of guessed. This prevents a failure that has not happened
yet: a "Rebase and merge" through the GitHub UI telling a requester "live" while their file was held back.

**Score:** 1

#### Pull Request

notify-live -LivePushRecord: read a PR's whole diff, so a rebase-merged PR's earlier commits count

