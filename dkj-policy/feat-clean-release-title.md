## feat/clean-release-title

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

Dave, 2026-09-21: a release gets no descriptive title any more. The GitHub Release name is always 'Release Version vX.Y.Z'. A short description stays allowed as its own row -- the notes line and the history table column -- so only the NAME changes.

### CREATE

- [x] `cut-release.ps1`: the printed `gh release create` line names `Release Version <tag>` instead of
      a `<short title>` placeholder, with the decision recorded beside it
- [x] its `.PARAMETER Title` help says outright that the parameter is a description and never the name
- [x] the plugin mirror brought back in sync via `build-shared-scripts.ps1` (the root copy is canonical)
- [x] `cut-release/SKILL.md`: the printed command, plus the reasoning and the description carve-out
- [x] the same page's milestone passage repaired -- it offered `Release version X.Y.Z` as a *fallback
      title*, which describes the world before this change
- [x] `v5.6.0`, published an hour earlier under a composed title, retitled to `Release Version v5.6.0`

#### Deliberately not done

- [~] renaming `-Title` to `-Description` -- dropped. Its help has read *"short description of the
      release as a whole"* for its whole life, so the parameter never made the claim; only the printed
      command did. A rename is a consumer-visible break on a mirrored script, bought for nothing.
- [~] changing the history overview's `Title` column header -- dropped. Dave's instruction explicitly
      keeps a short description as its own row, and that column is that row. Renaming it would touch the
      header matcher in `release-lib.ps1`, every existing history table and three suites, for cosmetics.

### TEST

- [x] `cut-release-guardrail.tests.ps1`: three asserts on the printed line -- that it is found, that it
      names the fixed form, and that no placeholder sits beside it
- [x] proved the guard BITES rather than passing vacuously: reverting the line to the old form turns
      exactly those two asserts red (2 failed, 109 passed), and restoring it returns all 111
- [x] `build-shared-scripts.ps1 -Check`: no mirror drift

### DEPLOY: feat/clean-release-title

A release is named `Release Version vX.Y.Z`, derived from its tag, and nothing composes that name any
more. `cut-release.ps1` printed a `--title "<tag> - <short title>"` placeholder, so what a release was
CALLED came from whatever sentence the person cutting it invented at that moment -- an authoring
decision taken at the most expensive step of the procedure, by whoever happened to be running it, and
the one artefact in this workflow that no gate could check. Two cutters produced two conventions.

**The short description is not removed, which is the distinction the whole change turns on.** It keeps
its own row -- the first line of the generated Release body, and the last column of the release
overview -- and `-Title` still feeds both. That parameter's own help has read *"short description of the
release as a whole"* since it existed, so the parameter was never the thing that claimed to be a title;
one printed line was. Nothing about the release documents changes.

Two neighbouring repairs came with it rather than being swept in: the parameter help now says outright
that it is not the name, and the milestone section offered `Release version X.Y.Z` as a *legitimate
fallback title* for a release too broad to summarise -- true before this change and misleading after it,
since that is now simply the name. It says to omit `-Title` instead, which is the same advice with the
stale half removed.

**Score:** 3

#### What makes this deploy extra special

A consumer cutting their next release sees a different command printed, and their releases stop being
named after a sentence somebody wrote on the spot. Nothing is asked of them and nothing is refused:
the line is printed for a person to paste, so a repo that prefers its own convention types its own
`--title` exactly as before -- this changes what the workflow RECOMMENDS, not what it permits.

Their already-published releases are untouched, and renaming one is a `gh release edit` they may run or
skip; the release documents, the overview table and the description row are all unchanged, so there is
no migration and nothing to re-adopt.

**Score:** 2

#### Pull Request

The release name is always Release Version vX.Y.Z

