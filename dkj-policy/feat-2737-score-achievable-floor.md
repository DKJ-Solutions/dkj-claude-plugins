## feat/2737-score-achievable-floor

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

Owner's decision on #2737 (October 3, 2026): score against an achievable floor made of the
no-influence layers plus whatever is deliberately always-on, taken from the measured data and the
render and never from the actions' estimated `tokens`.

"Deliberately always-on" is read as **the always-on documents up to `documents.budgetBytes`**. The
budget is the repo's own seam, which collect reads and nobody types in, so the model writing the data
still cannot set the score. The score is `none / (total - keep)` and not `floor / total`, because
`floor / total` would *rise* as the always-on path grew inside its budget.

### CREATE

- [x] Template: `keepTokens` + a three-argument `score`, the previous score fed by the previous page's own budget and factor; `scoreText` rewritten
- [x] `Merge-SessionStartPrevious` carries `previous.budgetBytes` and `previous.charsPerToken` (null when absent or not a number); mirror copied
- [x] SKILL.md: the score paragraph describes the floor

### TEST

- [x] `measure-session-start.tests.ps1`: 226 passed, 0 failed, including new asserts for the carried budget and factor and for a malformed value being dropped
- [x] The score function run under node on the issue's figures: no budget gives 40 (the old score), this repo now gives 66 (74 with every open action done), and a start at the floor gives 100

### DEPLOY: feat/2737-score-achievable-floor

The efficiency score on the `measure-session-start` page now measures how far the session start is
from the floor you can actually reach, not from an empty start. The floor is what Claude Code ships
itself plus the always-on documents up to their budget, which are always-on on purpose. A start with
nothing above it scores 100. The always-on path growing inside its budget no longer moves the score,
and only a byte over the budget counts against it. Before this, the score was capped near 43 in this
repo even with every action done. It now reads 66 on the same figures
([#2737](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2737)). The first render after the
update shows a jump in the score that comes from the new formula, not from a change in the session.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

measure-session-start: score against an achievable floor

