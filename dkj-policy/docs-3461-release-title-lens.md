## docs/3461-release-title-lens

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

Resolves #3461. Rendall's lens said every cut passes `-Title "Release version X.Y.Z"`; the `cut-release`
skill and every cut since 5.26.0 omit `-Title`, because the Release name has come from the tag since
September 21, 2026. The issue named one paragraph; the same claim also stood in a second one (line 252).

### CREATE

- [x] Rewrite both lens paragraphs: the name comes from the tag, `-Title` is omitted unless a release has one theme.

### TEST

- [x] Verified against `dkj-policy/releases/history.md`: 5.26.0-5.31.0 read `Minor release` except 5.29.0.
- [x] No other `Release version X.Y.Z` left outside the release documents.

### DEPLOY: docs/3461-release-title-lens

Rendall's lens no longer tells a cut to pass `-Title "Release version X.Y.Z"`: it says the Release name
comes from the tag and `-Title` is omitted unless the release has one theme, matching the `cut-release`
skill and the cuts since 5.26.0 (#3461).

**Score:** 1 -- prevents a cut from following the lens and writing `Release version X.Y.Z` into `history.md`'s description column again.

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Rendall's lens: the release name comes from the tag; -Title is omitted unless a release has one theme

