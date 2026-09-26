## fix/2546-guard-sibling-adopter-creates

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

#2546 names three adopters #2540's sweep did not reach. Verified by reading each: `adopt-ci-floor`'s
runner placement loop, `adopt-config`'s proposal document, and `adopt-statusline`'s shim and
`.claude/settings.json` all test absence or existence with `Test-Path` and then write. `adopt-config` also
appends into an existing seam lib (`scripts/repo-config.ps1`, `scripts/lib/branch-info.ps1`) unguarded:
that is the #2533 class, missed there because #2533 covered other scripts, and it is guarded here too.

### CREATE

- [x] adopt-ci-floor: each runner target is checked before the existence test; a hit prints `[refused]`, is counted, and the summary names the count
- [x] adopt-config: the seam-lib append and the proposal document are refused through a reparse point, and a `-ProposalPath` outside the repo is refused as well
- [x] adopt-statusline: the shim and settings.json are judged once up front, so the dry run and `-Apply` refuse the same way; a refused settings.json prints the block to place by hand
- [x] the three plugin mirrors rebuilt (`build-shared-scripts.ps1`)

### TEST

- [x] `adopt-ci-floor.tests.ps1`: a junctioned `.github/workflows` -- nothing lands outside, the refusal is named and counted (250 passed)
- [x] `config-blueprint.tests.ps1`: a junctioned `scripts/` and a proposal path outside the repo -- the lib outside is untouched, both refusals are named (211 passed)
- [x] `adopt-statusline.tests.ps1`: a junctioned `.claude/` -- nothing lands outside, both refusals are named, the block is printed (73 passed)
- [x] `check-plugin-integrity.ps1`: 0 errors

### DEPLOY: fix/2546-guard-sibling-adopter-creates

Three more adoption commands no longer write through a symlink or junction: `adopt-ci-floor`,
`adopt-config` and `adopt-statusline`. Each checked whether its target existed with `Test-Path`, which
follows a reparse point. So a junctioned `.github/`, `scripts/` or `.claude/` had the write land outside
the repo, and a dangling symlink read as absent, so the write created whatever it pointed at. Each write
now goes through `Get-WriteTargetReparsePoint` first, as `adopt-workflow-folder` and `specialists-init`
do since #2533 and #2540. That covers `adopt-config`'s append into an existing seam lib too. A hit is
reported as `[refused]` and the file is left for placing by hand; the rest of the run carries on.
`adopt-config` also refuses a `-ProposalPath` that points outside the repo.

**Score:** 1

#### What makes this deploy extra special

N/A. Adoption tooling does not reach a subscriber of a service.

**Score:** N/A

#### Pull Request

Three more adopters refuse to write through a symlink or junction

