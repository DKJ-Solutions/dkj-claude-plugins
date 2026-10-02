## feat/session-start-score

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

Template computes score = 100 x no-influence tokens / total, with a delta against the previous run; Dave chose the floor-share formula.

### CREATE

- [x] The template shows a score panel above the tiles: `none` tokens over all tokens, rounded, 1-100, capped
  at 99 while anything is added, with a meter and a delta against the previous run (up is green).
- [x] The render adds `previous.noneTokens`, summed over the previous page's own items by their own
  influence (Victor's review: pairing per current item let a removed or renamed `none` layer fake a delta).
- [x] SKILL.md says how the score is computed and that it cannot be set from the data; the two labels are
  `scoreHeading` and `scoreText`.
- [x] Review: Victor (correctness, the previous-score skew) and Edith (the "never 100" claim, which was
  false against the rounding, and "every token anywhere") -- both applied.

### TEST

- [x] `measure-session-start.tests.ps1`: 200 passed, 0 failed, including two new asserts on
  `previous.noneTokens` (a removed `none` item still counts; an empty previous gives 0).
- [x] The page's own script run against a stub DOM on today's real data: 40/100, +3 against the previous
  measurement (37). Test gap, named: the score's JavaScript has no automated test, because the suites are
  PowerShell and no JS runner is part of the gates.

### DEPLOY: feat/session-start-score

The session-start report now opens with an efficiency score from 1 to 100: the share of the session
start that Claude Code itself brings along, set against what the repo and the account add. The page
computes it from the layers alone, so the model writing the data cannot set it, and it shows the change
against the previous measurement.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

An efficiency score on the session-start page

