## feat/2564-audience-note-sections

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

Inbound #2564: the `Wording` seam can rename any of the audience note's three sections but not omit
one. The narrow repair the body asks for, as a new optional seam `Get-ReleaseNoteSections`. The wider
shape two later comments describe (a note drafted from the `asana-task` markers, live-only) stays open
on the issue and is not built here, so this ships with `-NoResolves`.

### CREATE

- [x] `Build-ReleaseNoteDraft -Sections` (default all three, byte-identical) and `Resolve-ReleaseNoteSections` in `release-lib.ps1`
- [x] `cut-release.ps1` reads and validates the seam before anything is written
- [x] contract record, this repo's own answer in `repo-config.ps1`, mirrors and blueprint regenerated
- [x] the cut-release skill (step 0a, step 2) and `RELEASES-portable.md` read the sections as conditional

### TEST

- [x] `release-lib.tests.ps1` (594 asserts), `script-contract.tests.ps1` (count 44 -> 45), `cut-release-guardrail.tests.ps1` (the seam resolves before the first write), `config-blueprint.tests.ps1` green standalone

### DEPLOY: feat/2564-audience-note-sections

Inside this repo: `Build-ReleaseNoteDraft` takes `-Sections`, and `cut-release.ps1` fills it from a new
optional seam, `Get-ReleaseNoteSections`, validated by `Resolve-ReleaseNoteSections` before the cut writes
anything. This repo states all three sections, so its own notes do not change.

**Score:** 2

#### What makes this deploy extra special

A repo whose release-note readers only want to know what changed can now say so once, in
`Get-ReleaseNoteSections`, for example `@('Audience')`. The drafted note then leaves out *What it is
worth* and *What was still open at this release*, heading and hint, so nobody deletes the two headings
by hand at every cut. A misspelt section name stops the cut before anything is written. A repo that
states nothing keeps all three sections
([#2564](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2564)).

**Score:** 3

#### Pull Request

Let a consumer choose which sections the audience release note carries

