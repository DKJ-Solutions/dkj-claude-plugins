## feat/prio-label-colors

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

### CREATE

- [x] Canonical hexes in `scripts/repo-config.ps1`, both copies of `adopt-triage-labels.ps1` and the blueprint
- [x] `adopt-dkj-policy-bwj` step 4 hexes, and its `fbca04` collision note replaced
- [x] Derek's lens: the colour table and the ramp sentence
- [x] Live labels in this repo re-coloured with `gh label edit`

### TEST

- [x] `repo-config`, `adopt-triage-labels` and `dkj-policy-bwj` suites green

### DEPLOY: feat/prio-label-colors

The four `prio-` labels now read as two yellows and two reds, on Dave's request: `prio-1` is yellow
(`FFE033`), `prio-2` a yellow leaning to orange (`F9A825`), `prio-3` a red leaning to orange (`E0321A`)
and `prio-4` stays red (`B60205`). They replace the teal → yellow → orange → red ramp. The canonical set
`adopt-triage-labels` prints and the BWJ adopt skill's step 4 carry the new hexes, and this repo's live
labels were re-coloured. Moving `prio-2` off `FBCA04` also ends its shared badge colour with `tier-1`
in a BWJ repo (#1844). A repo that already has the labels keeps its old colours until someone runs
`gh label edit --color`, because the adopt steps never rewrite an existing label.

**Score:** 2

#### What makes this deploy extra special

N/A -- a badge colour on the issue tracker. No release document reader acts on it.

**Score:** N/A

#### Pull Request

Re-colour the prio labels: yellow for 1-2, red for 3-4

