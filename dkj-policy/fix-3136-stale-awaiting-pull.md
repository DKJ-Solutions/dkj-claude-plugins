## fix/3136-stale-awaiting-pull

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

Issue #3136: `awaiting-pull` is defined as coming off at the merge, and nothing lifts it. Verified: no
script removes the label, and `Get-SweepCandidates` skips on the label alone. Of the issue's two options
this takes the read-only one, because it holds for every merge route (a UI merge included), where a
lift inside `ship-pr` would only cover merges that `ship-pr` itself makes.

### CREATE

- [x] `Get-ParkingWaitReferences` (claim-issue-lib): the `#<n>` numbers and branches in the last parking comment's `waiting on` clause
- [x] `claim-issue -Candidates`: an `awaiting-pull` issue whose references have all landed reads `stale-park`, with the unpark lines printed
- [x] `sweep-issues` and `CONTRIBUTING-portable.md` say how the label now comes off, and how a parking comment names its blocker

### TEST

- [x] `claim-issue.tests.ps1`: the three measured comment shapes (#3126, #3127, #3130), last comment wins, nothing named (597 passed)
- [x] live run: #3126 and #3127 parse to their landed blockers, #3130 to its four open step issues and stays `skipped`

### DEPLOY: fix/3136-stale-awaiting-pull

A sweep no longer leaves an `awaiting-pull` issue skipped after the issue it was waiting on has landed.
`claim-issue -Candidates` reads the parking comment's `waiting on` clause and checks every `#<n>` and
branch it names with the tracker. When all of them have landed (an issue closed, a pull request
merged, or a branch with a merged pull request), the issue reads `stale-park` and the run prints the
two lines that unpark it. The `sweep-issues` skill asks for parking comments to name the blocker in that
form (#3136).

**Score:** 3

#### What makes this deploy extra special

A consumer's sweep picks up an issue whose wait has cleared, where it used to skip that issue until
somebody noticed. Older parking comments are read too, provided they name the blocker as `#<n>` or by
branch.

**Score:** 2

#### Pull Request

Sweeps report an awaiting-pull issue whose blocker has landed as stale-park

