## fix/2540-guard-created-write-targets

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

#2533 put `Get-WriteTargetReparsePoint` in front of the adoption writes into files a consumer already
has. The writes that CREATE a file still tested absence with `Test-Path`, which follows a reparse point.
Verified by reading the sites: adopt-workflow-folder's placement loop, and bootstrap's persona-lens loop,
subagent-lens loop, script-scaffold loop and `SPECIALISTS.md` inclusion. The script-scaffold loop was not
named in the issue; it writes `scripts/repo-config.ps1`, the exact junction case the lib's own header
names, so it is in scope. The two `.claude/settings.*` artifacts are left out and filed as #2545: their
reporting assumes the file was written.

### CREATE

- [x] adopt-workflow-folder: each placement target is checked before the existence test; a hit prints `[refused]`, is counted, and the summary names the count
- [x] bootstrap: the lib is loaded once at the top; `Test-WriteRefused` guards the four create sites, `New-DirectoryInside` stops the mkdir that precedes them from creating a directory through a junction, and the CLAUDE.md guard uses the same helper
- [x] the shared-script mirror rebuilt (`build-shared-scripts.ps1`)

### TEST

- [x] `adopt-workflow-folder.tests.ps1`: a junctioned `.github/` -- nothing lands outside, the refusal is named and counted, the changelog is still created (148 asserts green)
- [x] `bootstrap-drift.tests.ps1`: a junctioned seam directory and `scripts/` -- nothing lands outside either, each create site reports `[refused]`, CLAUDE.md is still created (all new asserts green)
- [x] `check-plugin-integrity.ps1`: 0 errors after the mirror rebuild (the one bootstrap-suite failure was that lint assert, from the stale mirror)

### DEPLOY: fix/2540-guard-created-write-targets

The adoption commands no longer create files through a symlink or junction. `adopt-workflow-folder` and
`specialists-init`'s bootstrap tested whether a file they were about to create existed with `Test-Path`,
which follows a reparse point. So a junctioned `.github/`, `dkj-policy/`, `.claude/specialists/` or
`scripts/` had the new file written outside the repo, and a dangling symlink at the target read as
absent, so the write created whatever it pointed at. Every such create now goes through
`Get-WriteTargetReparsePoint` first, as the writes into existing files have since #2533. A hit is
reported as `[refused]`, the file is left for placing by hand, and the run's summary counts the
refusals. The rest of the run carries on. Bootstrap also no longer creates a missing lens directory
through a junction. The two `.claude/settings.*` suggestion files are not covered yet (#2545).

**Score:** 1

#### What makes this deploy extra special

N/A. Adoption tooling does not reach a subscriber of a service.

**Score:** N/A

#### Pull Request

Adoption writes that create a file refuse a symlink or junction too

