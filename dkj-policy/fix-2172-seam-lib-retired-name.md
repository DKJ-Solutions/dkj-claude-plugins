## fix/2172-seam-lib-retired-name

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

Issue #2172: `Get-WorkflowFolderName`'s docstring named the CURRENT folder name in the two places
whose whole job is to preserve the RETIRED one, so the passage read as a tautology --
*'dkj-policy' became 'dkj-policy'* -- and the migration story it tells was unreadable. The symptom
was verified against the tree before the repair: both spots stood as reported, and the code directly
below them (`@('dkj-policy', 'contributing-davekjohn', 'workflow-davekjohn')`) was correct, so this
is prose only and no gate can see it.

#### The rest of the tree was checked, and those two spots were the only casualties

The reported cause -- a rename sweep overwriting the old name -- predicts the same class in every
other rename sentence, so each was read: `consumer-runner-lib.ps1:25`,
`entry-scaffold-lib.ps1:7949`, `pr-body-lib.ps1:769`, `script-contract-lib.ps1:299`,
`seam-lib.ps1:388`, `check-plugin-integrity.ps1:3179`, `build-release-notes-page.ps1:737` and
`fold-changelog-entry.ps1:332` all name `contributing-davekjohn` correctly. Nothing else was swept.

### CREATE

- [x] `scripts/lib/seam-lib.ps1:168` -- the walk order names `'contributing-davekjohn', then 'workflow-davekjohn'` again
- [x] `scripts/lib/seam-lib.ps1:177` -- the #1437 sentence reads `'contributing-davekjohn' became 'dkj-policy'` again
- [x] Mirror regenerated with `build-shared-scripts.ps1` -- `plugins/dkj-policy/scripts/lib/seam-lib.ps1`, the registered `LibOnly` pair

### TEST

- [x] Lint gate + all suites green, run by `open-pr.ps1`

### DEPLOY: fix/2172-seam-lib-retired-name

`Get-WorkflowFolderName`'s docstring names the retired folder name again. Two sentences in
`scripts/lib/seam-lib.ps1` whose whole job is to preserve the name the folder used to carry had been
overwritten with the name it carries now, so the walk order read `'dkj-policy', then
'workflow-davekjohn'` and the #1437 sentence read *'dkj-policy' became 'dkj-policy'*. Both say
`contributing-davekjohn` again. Prose only: the array below them was always correct, so no behaviour
changes -- what changes is that the docstring can again be used to check the array, which is the one
thing a mid-migration consumer depends on and the only place stating why the function walks three
names newest-first. The other eight rename sentences in the tree were read and all name the retired
folder correctly, so the sweep reached these two and nothing else.

**Score:** 2

#### What makes this deploy extra special

N/A -- an in-repo docstring. Nothing a consumer of these plugins can observe: the function's
behaviour, its argument list and the three names it walks are all unchanged.

**Score:** N/A

#### Pull Request

Get-WorkflowFolderName's docstring names the retired folder name again

