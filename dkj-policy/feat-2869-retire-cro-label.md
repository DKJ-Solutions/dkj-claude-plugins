## feat/2869-retire-cro-label

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

Retire the `CRO` label across the BWJ procedure (#2869, Dave, October 7, 2026): a filing session
classifies the kind as `bug` or `feature` and sets the reach label, nothing else. Verified on pickup:
the three places the issue names are the only live carriers (`report-issue`, `WORKFLOW-portable.md`,
`adopt-bwj-development`). The issue leaves one question to the source: delete the existing label or keep
it. The answer here is to keep it as history. Nothing sets it again, and deleting it is a repo setting,
so that is the owner's call.

### CREATE

- [x] `WORKFLOW-portable.md`: the table row is gone, the CRO section is replaced by a short retirement
  note, and the phone-factory reach paragraph and the Asana-link gate's sentence are brought in line.
- [x] `report-issue`: the CRO row of the classification table is replaced by "never set `CRO`".
- [x] `adopt-bwj-development`: the step no longer creates the label; the link follows the new anchor.

### TEST

- [x] A grep over the tree (outside the release archive) finds no live instruction to set or create
  `CRO`, and no link to the retired anchor.

### DEPLOY: feat/2869-retire-cro-label

The `CRO` label is retired across the BWJ procedure
([#2869](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2869)). `report-issue` classifies
an issue by its kind (`bug` or `feature`) and the reach label only. `WORKFLOW-portable.md` replaces the
section on the label with a short note on its retirement, and `adopt-bwj-development` no longer creates
it. Where a store already has the label, it stays as history; nothing deletes it.

**Score:** 2

#### What makes this deploy extra special

After the update, a session filing an issue in a BWJ store no longer adds `CRO` to an issue raised by
the CRO team. That issue gets the kind and the reach label like any other. Nothing has to be done in a
store. Deleting the existing label from `smartwatchbanden` or `xoxowildhearts` is a repo setting, which
the owner changes by hand.

**Score:** 2

#### Pull Request

Retire the CRO label: report-issue classifies bug or feature only

