## fix/2655-preview-step-scaffolded

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

#### Inbound checks (#2655)

- **Symptom holds.** No scaffold writes `Is the change visible in the frontend / storefront?`: the
  sentence occurs only in `PREVIEW-portable.md`, the bwj README, `plugin.json` and one archived note.
- **Reason holds.** `Format-Development` writes exactly one step, `FirstStep`, and has no way to add a
  closing one, so the step-list gate had nothing to hold.
- **Repair, adjusted.** The report proposed "write it where `dkj-policy-bwj` is installed". That trigger
  is wrong: this repo enables bwj too, and the preview chapter's reach excludes it. dkj-policy also
  cannot dot-source a bwj lib. So the carrier is a generic `decide` seam, `Get-BranchClosingSteps`,
  which bwj's adoption proposes in the two store repos only.
- **Size.** Small, as reported.

### CREATE

- [x] `Format-Development -ClosingSteps`: open steps written after the first step, in the first-step phase, branch documents only
- [x] `new-branch` reads the `Get-BranchClosingSteps` seam and passes it in
- [x] Contract record (`decide`, optional); this repo states it as empty; count assert 47 -> 48
- [x] adopt-dkj-policy-bwj step 2 proposes the seam for the store repos; PREVIEW-portable and the bwj README say what writes the step
- [x] Mirrors kept byte-identical (entry-scaffold-lib, script-contract-lib, new-branch)
- [~] Is the change visible in the frontend / storefront? -- no: scripts and docs, nothing renders

### TEST

- [x] entry-scaffold: the closing step is last under CREATE, open, never on the trunk; none passed is byte-identical
- [x] new-branch-document: a fixture repo-config's answer reaches the written document
- [x] dkj-policy-bwj: the proposed seam text equals the step the preview page prescribes
- [x] script-contract green

### DEPLOY: fix/2655-preview-step-scaffolded

`new-branch` can now close CREATE with steps a repo names through a new optional seam,
`Get-BranchClosingSteps`, written as open steps after the first one. `adopt-dkj-policy-bwj` proposes it
for the two store repos with the preview question. So *"Is the change visible in the frontend /
storefront?"* is finally written as the last CREATE step, and the step-list gate holds the PR on it, as
[`PREVIEW-portable.md`](../plugins/dkj-policy/dkj-policy-bwj/PREVIEW-portable.md) always said it did.
Until now nothing wrote it
([#2655](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2655)).

**Score:** 2

#### What makes this deploy extra special

In a BWJ store repo, the preview handover stops depending on memory once `Get-BranchClosingSteps` is
added to `scripts/repo-config.ps1` (adopt-dkj-policy-bwj, step 2). Every branch created after that
carries the preview question and cannot reach its PR until it is answered. Branches already open get
the line by hand.

**Score:** 3

#### Pull Request

The preview question is scaffolded as the last CREATE step in the store repos

