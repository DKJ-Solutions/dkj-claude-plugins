## fix/2402-edited-claim-marker

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

#2402: after #2399 a claim marker must be written by its tag's own account, but a comment's `author`
and `createdAt` both survive an edit -- so an account could edit its own marker into a year-old
comment of its own and win every race. Repair as the issue proposed: drop a marker whose comment has
`includesCreatedEdit` true (gh already returns it on every comment, so no extra call; the tooling never
edits a claim comment). The advisory -- a null author drops the marker, so the issue reads free -- is
kept as the behaviour and pinned by a test.

### CREATE

- [x] `claim-issue-lib.ps1`: `Get-ClaimRecords` skips a marker in an edited comment; docstring names
  both #2402 decisions.
- [x] Plugin mirror in sync (`build-shared-scripts.ps1`: nothing further to update).

### TEST

- [x] `claim-issue.tests.ps1`: 512 passed -- the issue's measured backdating case through
  `Get-ClaimRecords`, `Resolve-ClaimRace` (`keep`) and `Get-TagClaimVerdict` (`free`), an unedited
  comment still read, and the null-author case pinned.
- [x] Field verified live: `gh issue view --json comments` returns `includesCreatedEdit` on each comment.

### DEPLOY: fix/2402-edited-claim-marker

`claim-issue.ps1 -Tag` no longer counts a claim marker that sits in an **edited** comment. A comment
keeps its original author and creation time when it is edited, so a marker edited into an old comment
of one's own used to win every claim race and hold the issue indefinitely. The tooling never edits a
claim comment, so a genuine claim is lost only if somebody edits it by hand. A marker whose author
has been deleted or suspended is still dropped, which means the issue it held reads as free. That
behaviour is now pinned by a test.

**Score:** 2

#### What makes this deploy extra special

A repo that sweeps its backlog with `claim-issue -Tag` could have an issue held by anybody who edited
a claim marker into an old comment of their own. That no longer works. If you edit a genuine claim
comment by hand, that claim is released.

**Score:** 2

#### Pull Request

claim-issue: a marker in an edited comment is not a claim

