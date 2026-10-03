## fix/2748-low-prio-labels-orange

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

#2748 (Dave): `prio-1` and `prio-2` move from the yellow family into the orange one. `prio-1` leans to
yellow and `prio-2` leans to red, which leaves yellow free for another family. The colours were not only
a tracker setting: they are pinned in the canonical triage-label list (`adopt-triage-labels.ps1`, its
plugin mirror and this repo's `Get-TriageLabels` seam), in the config blueprint, in the BWJ adoption
page and in Derek's lens. All of them change together.

### CREATE

- [x] `prio-1` `FFE033` → `FFA726`, `prio-2` `F9A825` → `F57C00`, in the two scripts, the seam, the
  blueprint, the BWJ adoption page and the lens table and prose
- [x] This repo's tracker: `gh label edit prio-1 --color FFA726`, `gh label edit prio-2 --color F57C00`
- [~] The test fixtures that stand for an EXISTING tracker keep the old hex values. They describe a
  tracker as it was, not the canonical list

### TEST

- [x] `adopt-triage-labels.tests.ps1` 94/94, `repo-config.tests.ps1` 74/74

### DEPLOY: fix/2748-low-prio-labels-orange

The two low priority labels are now oranges: `prio-1` `FFA726`, leaning to yellow, and `prio-2`
`F57C00`, leaning to red. Yellow is free for another label family. `adopt-triage-labels` prints the new
colours for a tracker that does not have the labels yet. It matches existing labels by name, so a
tracker that already has them keeps its colours until someone runs `gh label edit`.

**Score:** 1

#### What makes this deploy extra special

**Score:** N/A

#### Pull Request

prio-1 and prio-2 move into the orange family, freeing yellow
