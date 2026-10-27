## fix/3576-record-recurrence-stays-closed

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

Owner decision on #3576 (Maikel, October 27, 2026): option A, a recurrence on a record is a comment only.
Reword the workflow page and the runner's close comment, then close #3459 again as not planned.

### CREATE

- [x] `CONTRIBUTING-portable.md`: a new instance on a record is a comment, no reopen; the search-before-filing
      line reopens only an `awaiting-recurrences-first` match
- [x] `close-parked-recurrences.yml` and the `adopt-ci-floor.ps1` template (both copies): the close comment
      says a record stays closed and a first recurrence reopens

### TEST

- [x] The template and the source repo's runner carry the identical new comment, the two `adopt-ci-floor.ps1`
      copies stay byte-identical, and no old wording is left in the tree

### DEPLOY: fix/3576-record-recurrence-stays-closed

A new instance of a recurring problem is now only a comment on its closed `[RECORD]` issue. The record is no
longer reopened, so it stays closed through every recurrence. Before, the page said to reopen it and named
no step that closed it again, so the first recurrence left a record open for good (#3459). An issue still
waiting on its first recurrence is reopened as before. The workflow page and the comment the
`close-parked-recurrences` runner posts both say so.

**Score:** 2

#### What makes this deploy extra special

A consumer that follows the workflow page now logs a recurrence on a record as a comment instead of a
reopen, and once the CI floor is adopted again, its runner's close comment says the same.

**Score:** 2

#### Pull Request

A recurrence on a record is a comment only, and the record stays closed

