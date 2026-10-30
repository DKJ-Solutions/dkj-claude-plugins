## docs/3689-recurrence-of-completed-issue

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

Route (c), decided by Maikel on #3689 (October 30, 2026): a recurrence of an issue closed as completed
is a comment on that issue, and it converts the issue to a record.

### CREATE

- [x] `CONTRIBUTING-portable.md`: a paragraph after the search-before-filing rule covering the
  recurrence of an ordinary issue closed as completed, the conversion to a record, and the subject
  search over closed issues.

### TEST

- [x] Docs only. The gates run in `ship-pr`.

### DEPLOY: docs/3689-recurrence-of-completed-issue

The filing rules covered a new instance of a record and of an `awaiting-recurrences-first` issue, but
not of an ordinary issue closed as *completed* whose repair did not hold. Three sessions handled the
same case two ways (#3288, #3687). [`CONTRIBUTING-portable.md`](../plugins/dkj-policy/CONTRIBUTING-portable.md)
now says what to do: comment on the closed issue, and convert it to a record in the same movement
(`awaiting-recurrences`, `[RECORD]`, the close reason changed to *not planned*, left closed).

**Score:** 2

#### What makes this deploy extra special

A session in a consuming repo that finds a recurrence of a closed, completed issue now has one route:
comment on it and make it a record, instead of filing a new issue beside it.

**Score:** 2

#### Pull Request

A recurrence of an issue closed as completed makes it a record

