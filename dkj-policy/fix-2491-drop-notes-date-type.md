## fix/2491-drop-notes-date-type

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

Issue #2491: the changelog release note (`# Changelog Releases`) carries a `**Date:**` / `**Type:**` pair
between its H1 and its `## Version X.Y.Z (Mon dd, yyyy)` heading, and the pair adds nothing -- the heading
states the date, and the type is the version's own shape. Its one reader is `new-internal-note.ps1`, which
has to get both some other way, and keep reading every note already published with the pair.

### CREATE

- [x] `Build-ReleaseNotes` writes no pair, and its `-Type` parameter is retired (the cut no longer passes it)
- [x] `Get-NoteVersionHeadingMeta` reads the date and type back out of the version heading
- [x] `new-internal-note.ps1` reads the pair first; where it is absent, the type from the release history's row
      (`Get-OverviewRowType`, which records a type stated with `cut-release.ps1 -Type`), then the heading
- [x] each heading component capped at nine digits, so an oversized one cannot overflow the `[int]` cast
- [x] plugin mirrors of the three scripts copied across

### TEST

- [x] `release-lib.tests.ps1`: no pair, the retired parameter asserted absent, the heading reader
      round-tripped through the note the lib writes (Major / Minor / Patch, undated, no heading, oversized),
      and the history-row reader -- 566 passed
- [x] `internal-note.tests.ps1`: a note with no pair yields the same date and type, no placeholder, no
      warning, for a minor and a patch, and a history row stating a type wins over the shape -- 122 passed
- [x] `cut-release-guardrail.tests.ps1` 111 passed; `check-plugin-integrity.ps1` 0 errors
- [x] reviewed: Victor (the stated `-Type` case, repaired), Sebastian (the overflow, repaired), Edith

### DEPLOY: fix/2491-drop-notes-date-type

The changelog release note a cut writes (`releases/changelog/<X>.x/<X.Y.Z>.md`) no longer carries the
`**Date:**` and `**Type:**` lines under `# Changelog Releases`: the `## Version X.Y.Z (Mon dd, yyyy)`
heading already says both. Where those lines are missing, `new-internal-note.ps1` takes the date from that
heading and the type from the release history's row, falling back to the version's shape, so the internal
note it builds is unchanged, including for a cut run with `-Type`. Notes published before this still read
exactly as they did. `Build-ReleaseNotes` no longer takes `-Type`.

**Score:** 1 -- prevents a duplicate that could disagree with its own heading; nothing has broken yet.

#### What makes this deploy extra special

From your next release, the changelog release note goes from its `# Changelog Releases` heading straight
to its title and version heading, without the two metadata lines between them. Nothing to do: the
internal note still fills in its date and type.

**Score:** 2

#### Pull Request

The changelog release note drops its Date and Type lines

