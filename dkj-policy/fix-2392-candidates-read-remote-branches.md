## fix/2392-candidates-read-remote-branches

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

#2392: `-Candidates` judged from the tracker alone, so an issue somebody was working without `-Tag`
read `free` while its branch sat on origin. Verified on the trunk before building: `Get-SweepCandidates`
reads only the `gh issue list` payload. Repair: one fetch (the claim's own seam) and one
`git for-each-ref refs/remotes/origin` for the whole backlog, and a new `branch` verdict.

### CREATE

- [x] `Get-RemoteIssueBranches` in `claim-issue-lib.ps1`: issue number, branch, author, commit time per
      `<prefix>/<n>-<name>` remote branch
- [x] `Get-SweepCandidates -Branches`: an unmarked issue with a branch reads `branch`, with the newest
      branch's author and age; a marker still wins
- [x] `claim-issue.ps1 -Candidates` reads origin once, counts `branch` in the summary, and says what
      `free` means when the listing is unreadable
- [x] Plugin mirrors synced; `claim-issue` and `sweep-issues` skill pages name the new verdict

### TEST

- [x] `claim-issue.tests.ps1`: 471 passed, including the new #2392 block
- [x] `native-capture.tests.ps1`: bounded-site count moved 78 -> 79 with its audit note; 352 pass
- [x] `shared-scripts.tests.ps1`: 1009 passed (mirrors byte-identical); lint gate 0 errors
- [x] Live run on this repo: 12 of 14 open issues now read `branch` (the report's 9 among the 12) with
      author and age, 2 `free`

### DEPLOY: fix/2392-candidates-read-remote-branches

`claim-issue.ps1 -Candidates` now reads origin's branches once for the whole backlog. An open issue with
no claim marker but a `<prefix>/<n>-<name>` branch on origin reads `branch` instead of `free`, and the
reason names the branch, its author and how long ago it last moved. A claim marker still takes
precedence. If the branch listing cannot be read, the run still judges from the tracker and says that
`free` then means only "no claim marker".

**Score:** 3

#### What makes this deploy extra special

A sweep no longer offers you an issue somebody else is already building just because they did not
claim it by tag. Before this, the only warning came after the claim was written, one issue at a time.

**Score:** 2

#### Pull Request

