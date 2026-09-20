## fix/2183-reserved-root-md-seam-row

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

### CREATE

- [x] Rewrote the "your permanent root docs" row of the seam-answer table in the system-administration lens so it lists every name `$script:ReservedRootMd` holds, and says `CHANGELOG` and `CONTRIBUTING` left the root and stayed on the list
- [x] Searched the repo's `.md` files (archived `dkj-policy/releases/**` excluded) for other prose saying those two names came off the list: none found, so that row was the only one to repair

### TEST

- [x] Read the new row against `$script:ReservedRootMd` in `scripts/repo-config.ps1` and against `ReservedNames` in `Get-BranchFilePaths`, name by name and claim by claim (a read-through, not a gate run)

### DEPLOY: fix/2183-reserved-root-md-seam-row

The seam-answer table in the system-administration lens now states the permanent-root-docs list the way
the code holds it. It had carried, since the deleted `dkj-policy/README.md`, a list of six names and a
note that `CHANGELOG` and `CONTRIBUTING` "came off" it on August 27, 2026. The code says the opposite:
`Get-ReservedRootMd` still lists all eight names, because the portable `cut-release` reads that list to
decide which root `.md` files are permanent documents rather than unfolded entries, and taking the two
names off the same day made it refuse a release over a changelog nobody had failed to fold. The row now
lists every name, says the two left the root and stayed on the list because the list names a permanent
document rather than one this repo holds today, and points at the code comment that carries the
reasoning and at `ReservedNames` in `Get-BranchFilePaths`, which records the same rule for the
folder's own pages. Nothing else in the table, and no script, changed.

This prevents a failure that has not happened yet: with `dkj-policy/README.md` deleted, that row is the
only prose left for this seam, so someone reconciling the code to it would take the two names off the
list and reproduce the cut refusal of August 27.

**Score:** 1

#### What makes this deploy extra special

N/A -- an internal lens row, which no subscriber of the service reads or has anything to do differently
because of.

**Score:** N/A

#### Pull Request

The seam table states Get-ReservedRootMd as the code holds it

