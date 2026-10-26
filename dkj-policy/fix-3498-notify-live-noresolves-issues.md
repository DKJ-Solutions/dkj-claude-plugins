## fix/3498-notify-live-noresolves-issues

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

Inbound #3498: the reason was verified first. `notify-live.ps1` read issues only from
`closingIssuesReferences`. `BWJ-Development/smartwatchbanden` PR #1015 had none, while its head
branch (`liquid/1011-...`) and its body both name #1011. Of the issue's two proposed routes, the PR's
own text is the one that holds this case, and it costs one gh call the driver already makes.

### CREATE

- [x] `Get-PullIssueCandidates` in `live-message-rules.ps1`: closing references, plus the head branch's issue and every bare `#<n>` in the body (not the PR's own number, not `PR #<n>`, not `owner/repo#<n>`, not inside code)
- [x] `notify-live.ps1` step 2 asks gh for `headRefName,body`, and asks GitHub once per named number whether it is an issue (an unanswerable one is UNREAD and fails the run, like every other read); the docstring and the skill page say "carried" where they said "closed"

### TEST

- [x] seven asserts in `bwj-development.tests.ps1`, the #1015 shape among them; the suite passes 898 of 898
- [x] the issue-or-PR filter checked live against smartwatchbanden #1011

### DEPLOY: fix/3498-notify-live-noresolves-issues

`notify-live` now finds the issues a release carried, not only the ones its PRs closed through a
closing keyword. It also reads the issue a PR's head branch is named after, and every `#<n>` in the
PR body that GitHub confirms is an issue. The verdict is unchanged, so a number a PR merely mentions
shows up as a `skipped` row in the dry run and never becomes a message.

**Score:** 3

#### What makes this deploy extra special

In a store repo that answers `Get-ResolvesExemptMatchers`, every Asana-linked issue ships with
`-NoResolves` and is closed by hand, so `notify-live` could never tell any of their tasks that the work
was live. From this release on, it does.

**Score:** 4

#### Pull Request

notify-live finds the issues a -NoResolves PR carried

