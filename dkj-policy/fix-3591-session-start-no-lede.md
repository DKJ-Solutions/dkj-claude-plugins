## fix/3591-session-start-no-lede

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

#3585 made the rule: no intro paragraph under a page heading. Two renderers outside the hub shell still
drew one (#3591). The call #3591 left open, made here and up for the owner's look: **a lede that carries
the measurement's own finding is content, so it stays, but after the block it sums up; a lede that only
explains the page is an intro, so it goes.**

#### For the owner's look

- Hub, `/sessionstart/last-measurement`: the summary paragraph now sits under the four tiles instead of
  above them. `/sessionstart/advice`: the verdict follows the steps.
- The Artifact template (`measure-session-start`): no paragraph under the `h1` any more; the header's
  finding follows the tiles, each section's data-supplied lede follows its block, and the three built-in
  explainers (actions, documents, no-influence) are gone. An empty lede draws nothing.

### CREATE

- [x] `general-pages-lib.ps1`: `header.lede` after the tiles, `advice.lede` after the steps
- [x] `session-start-template.html`: ledes after their blocks, hidden when absent, explainer defaults removed
- [x] `measure-session-start/SKILL.md`: the data table says where a lede is drawn
- [x] `dev-pages.tests.ps1`: asserts the order of both hub ledes

### TEST

- [x] The owner looked at both pages and approved (October 27, 2026); the gates run at `ship-pr`

### DEPLOY: fix/3591-session-start-no-lede

The session-start pages now open on their content too: the measurement's summary follows the figures it
sums up, the advice's verdict follows its steps, and the explainer lines under the Artifact's section
headings are gone, the same rule #3585 set for every other hub page
([#3591](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3591)).

**Score:** 2

#### What makes this deploy extra special

Nothing beyond the entry above.

**Score:** N/A

#### Pull Request

Session-start page and template: no lede under a heading

