## fix/2489-fixed-release-history-head

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

Issue #2489, the same shape as #2486 one file over: the release list (`Get-ReleaseHistoryPath`) gets a
fixed head, `# Release history` and nothing else above the first `<n>.x` section. The cut re-applies it
where it inserts the row, because the cut is the one writer every repo's list has. The adopt output prints
the same head. It still does not scaffold the file, for #786's reason: the major in the first heading is a
version decision.

The two readers the issue flagged were checked first. `Get-OverviewTargetMajor` and
`Get-OverviewSectionHeading` only read `<n>.x` headings between the top of the file and the first table, so
the prose was never theirs. Where no `<n>.x` heading exists the function changes nothing. The body cannot
be located then, and replacing the whole document the way the changelog's head does would delete rows.

### CREATE

- [x] `Set-ReleaseHistoryCanonicalHead` in `release-lib.ps1`, fence-aware, bounded by the same heading
  pattern the two readers use; `Get-ReleaseHistoryHeadLines` in `entry-scaffold-lib.ps1` beside the
  changelog's head, because the adopt script loads that lib and not `release-lib`.
- [x] `cut-release.ps1` applies it to the snapshot the guardrails read and in the row inserter.
- [x] `adopt-workflow-folder.ps1` prints the head in its template and says nothing goes above the section.
- [x] This repo's `dkj-policy/releases/history.md`: the 85-line intro replaced by the fixed head (written
  by the function itself). The load-bearing structure it explained moved to `RELEASES-portable.md`.
- [x] `adopt-dkj-policy` skill: the template shows the head.
- [x] Plugin mirrors synced (all four pairs were identical at HEAD before the copy).

### TEST

- [x] `release-lib.tests.ps1`: 11 new asserts (replacement, the readers unchanged, lower rows and
  between-section prose kept, idempotent, fenced example, no section left alone, empty, CRLF). 562 pass.
- [x] `cut-release-drive.tests.ps1`: the happy path asserts that a real cut replaced the fixture's intro.
  60 pass.
- [x] `adopt-workflow-folder.tests.ps1` 115 pass, `entry-scaffold.tests.ps1` 881 pass.

### DEPLOY: fix/2489-fixed-release-history-head

The release list (`dkj-policy/releases/history.md` unless repointed) now has one fixed head:
`# Release history` and nothing else above the first `<n>.x` section. The cut re-applies it where it
inserts the new row, and the adopt output prints it instead of leaving the head to each repo. In this repo
the list's 85-line intro is gone. The structure it explained is on `RELEASES-portable.md`.

**Score:** 2

#### What makes this deploy extra special

At your next release cut, anything you wrote above the first `<n>.x` section of your release list
disappears and is replaced by the title `# Release history`. If something written there mattered, move it
to a page you own before you cut. The sections, their tables and every row are untouched.

**Score:** 3

#### Pull Request

The release list carries one fixed head, with no intro prose

