## feat/3572-stale-park-external-waits

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

Extend the `stale-park` read in `claim-issue -Candidates` (#3136) to the two parking labels whose wait a
script can read: `awaiting-pull-external` and `awaiting-release-external` (#3572). Verified before building:
`awaiting-release` is already listed by `cut-release`, and the other parking labels wait on a person or on
nothing a tracker records, so they stay out.

### CREATE

- [x] `Get-ParkingWaitReferences` reads `owner/repo#n` apart from local numbers and branches, the `owner/repo`
  a release is awaited from, and the parking comments date; `Test-PublishedSince` compares a release to it
- [x] `-Candidates` reads both external waits, with one new bounded read (`releases/latest`), and prints the
  unpark line for the label it read
- [x] `sweep-issues` and `CONTRIBUTING-portable` name the parking-comment form and what clears each label

### TEST

- [x] `claim-issue.tests.ps1`: the cross-repo parse on #3464s shape, #3505s real comment, both date
  shapes, and the comparison; `native-capture.tests.ps1` moves the bounded count to 101
- [x] a live `-Candidates` run: #3505 stays skipped (smartwatchbandens newest release predates the park),
  #3464 says its comment names no `owner/repo#n`, and `awaiting-pull` still reads #3566 as `stale-park`

### DEPLOY: feat/3572-stale-park-external-waits

A sweep now also notices when an issue parked on another repo has stopped waiting. `claim-issue -Candidates`
reports an `awaiting-pull-external` issue as `stale-park` once its upstream pull request has merged and
that repo has published a release since. It does the same for an `awaiting-release-external` issue once
the repo it names has published a release after the park. It prints the two lines that unpark the issue,
so the issue is free for the same sweep. Before this, only `awaiting-pull` was ever read again.

**Score:** 2

#### What makes this deploy extra special

N/A -- a sweep in a consumer reads two more parked labels again; nothing changes for the person who takes
the next version unless they run sweeps on issues waiting on another repo.

**Score:** N/A

#### Pull Request

stale-park reads the two external waits
