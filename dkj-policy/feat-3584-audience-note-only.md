## feat/3584-audience-note-only

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

Inbound #3584 (the owner, October 27, 2026: "ik wil dit gewoon nooit meer zien nergens"): no `## What it is worth`
and no `## What was still open at this release` in any audience release note, in any repo. #2564 had made them
opt-out through `Get-ReleaseNoteSections`, whose absent answer still meant all three. Verified: the default lives in
`Resolve-ReleaseNoteSections` and `Build-ReleaseNoteDraft`, and the blueprint copies the source's all-three answer.
The repair is the issue's full ask, not the minimal one: the sections leave the generator, and the seam is retired
in the contract the way earlier seams were, so a consumer that still defines it changes nothing.

### CREATE

- [x] `release-lib.ps1`: `Build-ReleaseNoteDraft` drafts the audience section only; the Value/Open defaults and hints, `-Sections` and `Resolve-ReleaseNoteSections` are gone; `Compare-ReleaseNoteForm` loses `-Sections`
- [x] The audience line no longer promises colleagues a section: `consumers of this product` at tier 2, `colleagues in the organisation` at tier 1
- [x] `cut-release.ps1` and `check-release-note-form.ps1` no longer read `Get-ReleaseNoteSections`
- [x] `script-contract-lib.ps1`: the record retired with a dated note; the `Get-ReleaseNoteWording` Returns text names the keys no longer read; `repo-config.ps1` drops its answer; the blueprint and the mirrors rebuilt
- [x] The cut-release skill (step 0a, step 2, step 4), `RELEASES-portable.md` and the release lens describe one section
- [~] `new-internal-note.ps1` still drafts both headings in the retired two-document flow's internal note -- outside this issue's list, so filed as #3590 for the owner's call

### TEST

- [x] `release-lib.tests.ps1` (624), `release-note-form.tests.ps1`, `cut-release-guardrail.tests.ps1` (127), `cut-release-drive.tests.ps1` (119), `script-contract.tests.ps1`: all green, with new asserts that neither heading nor hint is drafted, that a retired wording key brings no heading back, that the form check refuses the two headings written back by hand even where the retired seam still answers all three, and that the contract counts fifty records

### DEPLOY: feat/3584-audience-note-only

The audience release note that `cut-release` drafts now has one section, *What changed*, in every repo. The two
organisational sections, *What it is worth* and *What was still open at this release*, are gone, and so is the
`Get-ReleaseNoteSections` seam that could only switch them off; a repo that still defines it changes nothing. The
`For whom` line names only the reader the note has, and the release-notes form check refuses either heading
written back by hand.

**Score:** 3

#### What makes this deploy extra special

Every repo's next release note arrives without the two sections nobody filled in, with nothing to configure.

**Score:** 3

#### Pull Request

The audience release note drops 'What it is worth' and 'What was still open' everywhere
