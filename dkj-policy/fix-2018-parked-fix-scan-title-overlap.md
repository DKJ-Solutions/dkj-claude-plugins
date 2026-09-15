## fix/2018-parked-fix-scan-title-overlap

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

Closes #2018. `claim-issue.ps1`'s fourth pickup signal (#1853) greps commits off the trunk for the
issue number in three spellings, so a branch named for its SUBJECT rather than its number writes none
of them and stays invisible to the whole scan -- measured on `fix/asana-stage-letter-codes` while
claiming #2016. The issue's own text declined the obvious widening (matching commit content) and
pointed at the branch NAME instead, matched on shared words with the issue's title, leaving the noise
measurement to whoever picked it up.

#### What makes this deploy extra special

Adds a fifth pickup signal to `scripts/lib/claim-issue-lib.ps1` (`Get-SignificantWords`,
`Get-BranchSlugWords`, `Get-TitleOverlapBranches`, `Format-TitleOverlapReport`) and wires it into
`scripts/task/claim-issue.ps1` alongside the fourth signal, sharing its one fetch. Warn-only, never
folded into the fourth signal's `$foreignParked` verdict -- a name collision is weaker evidence than a
number, per the issue's own text.

The threshold (`MinSharedWords`, default 2) is measured rather than guessed: run against this repo's
own branch history (21 branches, 21 issue titles, `scripts/tests/claim-issue.tests.ps1` pins the
corpus), threshold 1 is too noisy (27 unrelated cross-hits), threshold 3 misses the very branch #2018
was filed about, and threshold 2 catches it with only 3 cross-hits, each a genuinely related pair
rather than coincidence.

### CREATE

- [x] Add the fifth-signal functions to `claim-issue-lib.ps1`, measured against this repo's own
      branch/issue history to pick `MinSharedWords`.
- [x] Wire the scan into `claim-issue.ps1`, sharing the fourth signal's fetch; never sets
      `$foreignParked`.
- [x] Pin the corpus measurement and the new functions' behaviour in `claim-issue.tests.ps1`.
- [x] Sync the `dkj-policy` plugin mirror (`scripts/sync/build-shared-scripts.ps1`).

### TEST

- [x] `scripts/tests/claim-issue.tests.ps1` -- 221 passed, 0 failed.
- [x] `scripts/lint/check-plugin-integrity.ps1` -- 0 errors.

### DEPLOY: fix/2018-parked-fix-scan-title-overlap

`claim-issue.ps1`'s parked-fix scan (#1853) reads a commit's CONTENT for the issue number, so a branch
named for the subject rather than the number -- `fix/asana-stage-letter-codes` for issue #2016, the
case this was measured against -- carries no commit the scan can ever match. A fifth pickup signal now
also matches the issue's TITLE against every branch name off the trunk, warn-only and never as strong
as the fourth signal's verdict. The threshold is measured against this repo's own branch history rather
than guessed, and that measurement is pinned in the test suite.

**Score:** 3 -- a clear improvement to a check every claim already runs, noticed the next time a
subject-named branch is sitting on the same work.

#### What makes this deploy extra special

Every repo running `dkj-policy`'s `claim-issue` skill gets one more chance to catch a duplicate
implementation before it is built twice -- exactly the incident #2018 itself measured.

**Score:** 2 -- small, but a subscriber notices it the day it saves them a duplicate build.

#### Pull Request

claim-issue's parked-fix scan also warns on branch-name/title token overlap

