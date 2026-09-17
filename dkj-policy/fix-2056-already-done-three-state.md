## fix/2056-already-done-three-state

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

Inbound #2056: Get-TargetIssueWarnings infers CLOSED from absence in the open-issue list, so a cross-repo citation -- which this workflow's own inbound route prescribes -- reads as closed and warns that the branch duplicates merged work. Stop inferring: resolve each unaccounted number and let only a confirmed CLOSED issue of this repo set IsClosed.

### CREATE

- [x] `Get-IssueStateVerdict` (pure, in `pr-issues-lib.ps1`) judges one `gh issue view` answer as
      `closed`, `other` or `unreadable`. The URL and not the state separates a pull request from an
      issue, because a CLOSED pull request answers exactly what a closed issue answers.
- [x] `Get-ClosedIssueSet` (impure, in the new `scripts/lib/issue-state-lib.ps1`) runs that rule over
      the numbers the caller could not already account for, and reports `Closed`, `Unreadable` and
      `Truncated` separately.
- [x] `Get-TargetIssueWarnings` takes `-ClosedIssues` in place of `-OpenIssues`, so it is TOLD which
      numbers are closed instead of inferring it from an absence.
- [x] `Get-IssueResolveBatch` (pure) owns the cap: which numbers a run takes when a document cites more
      than the limit. The NEWEST survive, not the lowest.
- [x] Both callers -- `new-branch.ps1` and `open-pr.ps1` -- do the three-state read, resolving only the
      unaccounted numbers, and both report an unreadable answer AND a truncated batch.
- [x] The new lib registered in `shared-scripts-lib.ps1` and mirrored into the plugin payload.
- [x] `new-branch`'s skill page carries the new row and why it exists.

### TEST

- [x] `scripts/tests/pr-issues.tests.ps1` -- 1003 asserts, 0 fail. Twelve of them pin the pure rule on
      real payloads measured here: a closed issue, an open one, `Could not resolve`, a MERGED pull
      request, a CLOSED pull request, an auth failure, a silent non-zero exit, an unparseable payload,
      one with no `state` field, an exit-0 capture with no payload at all, and a gh release notice
      merged in front of both a closed issue and a pull request.
- [x] Four more pin the cap: everything kept under it, the NEWEST kept over it, duplicates and
      non-positive numbers dropped first, and nothing in means nothing truncated.
- [x] `scripts/tests/new-branch.tests.ps1` -- 285 asserts, 0 fail, including a new wired case (x9) for
      #2056 itself: a cited number that is not an issue here stays SILENT, and the call log proves the
      silence comes from having asked rather than from skipping the check.
- [x] The full gate (`check-plugin-integrity.ps1` plus every suite) via `open-pr.ps1`.

#### The fake gh had to learn a second question

The `new-branch` fixture stubbed `gh issue list` only, so the new per-number resolve fell through to a
refusal and every "already CLOSED" case went silent. Three existing cases now state which numbers are
closed rather than relying on an absence -- which is the repair restated at the level of the suite:
before it, "closed" and "not here" were the same input.

#### The review caught the repair repeating the defect one layer down

The first cut passed `-DiscardStderr` on the `gh issue view` call, out of habit -- and gh writes
`Could not resolve to an issue or pull request with the number of <n>` to **stderr**. So the sentence
the whole discrimination rests on was thrown away before anything read it, and a cross-repo citation
landed on `unreadable` instead of `other`: every such branch went on printing a warning, just a
different one. The closed signal was unaffected, which is what made it invisible -- and the unit tests
could not see it either, because they feed the verdict function a string directly and never go through
the call. Verified against real gh 2.74.0 both ways before and after.

Two asserts now cover it from the side the unit tests cannot: case (x9) checks for the absence of the
**unreadable** warning as well, so the label "SILENT" is something the suite actually proves. What
merging the streams costs -- a successful capture is no longer guaranteed to be pure JSON, since gh
puts its release notices there -- is paid for by extracting the payload from the capture instead of
parsing it whole, with an assert for exactly that shape.

### DEPLOY: fix/2056-already-done-three-state

The already-done check no longer reads **"this number is not an open issue in this repo"** as
**"this issue is CLOSED"** (inbound #2056). It had no third state, so a number this repo has never had
was reported as closed and the author was told the branch "may repeat work that is already merged".

**This workflow produced the case it is repairing**, which is why it fired so often. The numbers being
tested are scraped as bare integers out of the branch's development document, and the inbound route
*prescribes* citing an issue in another repo: a shared-core finding is filed on the marketplace repo,
and the consumer then cites that number in a docstring, a README entry and the DEPLOY section. Every
one of those is a bare `#<n>` after scraping, pointing at a repo the check never queried -- so it was
loudest on exactly the branches that follow the documented route.

`Get-TargetIssueWarnings` now takes `-ClosedIssues` instead of `-OpenIssues`: it is told what is
closed rather than inferring it, because an absence cannot be the evidence for a positive claim. The
caller does the resolving, one `gh issue view` per number the open list did not already account for --
per number rather than one `--state all` list, because that list is paged and this repo is past 2000
issues, so a genuinely closed issue behind the page boundary would come back as "not here" and take
#1282's real signal with it.

**One thing the report did not name is fixed with it: a pull request number.** Issues and pull requests
share one counter, so a document citing `PR #1276` handed the check a number that is not an issue
either, and it read as CLOSED for the same reason. Measured here: `gh issue view 2053` answers exit 0
with state `MERGED`. A *closed* pull request answers exactly what a closed issue answers, so the
discriminator is the `/pull/` in the URL rather than the state.

What did NOT change: the check still warns and never blocks, and a state it cannot determine still
claims nothing.

The cost this removes is trust rather than a blocked PR -- an author who learns these warnings are
usually wrong stops reading them, and #1282's real signal goes with them. Every branch citing an
upstream finding saw it, so the noise was routine rather than occasional.

**Score:** 3

#### What makes this deploy extra special

It is the second attempt at this class and the first one to reach the cause. #1718 narrowed the scraped
region so the scaffold's own guidance block stopped contributing foreign numbers -- a real repair, and
one that removed a *source* rather than the conflation: a foreign number written in the branch's own
prose, which the inbound route requires, still landed in the target set and still read as closed.

**Score:** 2

#### Pull Request

The already-done check tells a closed issue apart from a number that is not an issue here
