## fix/2609-claim-refuses-pull-request

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

Refuse a number that resolves to a pull request, as its own verdict, and name the issue it closes.
Widen the state refusal from `CLOSED` to anything but `OPEN`. Cover the assignee verdict, the tag
verdict and the take-over verdict, which passes it through.

### CREATE

- [x] `Test-PullRequestUrl` and `Get-ClosingIssueNumbers` in `claim-issue-lib.ps1`; a `pull-request` verdict in `Get-ClaimVerdict`, `Get-TagClaimVerdict` and `Get-TakeOverVerdict` (the last passes `-Url` through)
- [x] the state refusal reads `-ine 'OPEN'` in both verdicts
- [x] `claim-issue.ps1` passes the URL and prints one `Write-PullRequestRefusal` in both switches, with the PR's closing issues from one bounded `gh pr view`
- [x] plugin mirrors synced; the skill's verdict table updated to six

### TEST

- [x] `claim-issue.tests.ps1`: 555 passed, 0 failed, with asserts for MERGED, an open PR, an unknown state, the URL test and the closing-issue reader
- [x] Victor's review: the take-over path's untagged probe now passes the URL, and the URL test is anchored on the resource segment
- [x] live dry-run on merged PR #2504, both default and `-Tag`: refused, names #2500, exit 1

### DEPLOY: fix/2609-claim-refuses-pull-request

`claim-issue` now refuses a pull request's number instead of claiming it. `gh issue view` answers for
a PR too, and a merged one reads as `MERGED`, a state the old check did not refuse, so the claim went
through and put an assignee on the merged PR. The refusal names the issue the PR closes, and any state
other than `OPEN` is now refused (#2609).

**Score:** 2

#### What makes this deploy extra special

If you type a PR number where you meant an issue, `claim-issue` now stops. It does not print `[OK]` and
does not assign you to the pull request. It names the issue that PR closes, so you can re-run on that
number.

**Score:** 2

#### Pull Request

claim-issue refuses a pull request's number and names the issue it closes

