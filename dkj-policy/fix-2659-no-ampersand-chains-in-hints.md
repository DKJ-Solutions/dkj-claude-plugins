## fix/2659-no-ampersand-chains-in-hints

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

Three printed hints joined two commands with '&&', which Windows PowerShell 5.1 cannot parse; they now print on separate lines or join with ';'.

#### A third site, found while verifying the issue

The issue names two sites. A grep of every `.ps1` for `&&` found a third of the same kind: `open-pr.ps1`'s
backing gate prints `git add -A && git commit` as its remedy. It is absorbed here, in both copies.

### CREATE

- [x] `fold-changelog-entry.ps1` (source and mirror): the push-unmeasured hint prints `git fetch origin`
      and the `git log` on lines of their own.
- [x] `open-pr.ps1` (source and mirror): the backing-gate remedy prints `git add -A` and `git commit` on
      lines of their own.
- [x] `pr-issues-lib.ps1` (source and mirror): the missing-check-suite note joins the reopen remedy with
      `;` (it is one sentence, so a line break is not an option), and its docstring follows.

### TEST

- [x] `pr-issues.tests.ps1`: the four asserts pinning the remedy text now read `;`, and a new assert
      holds the note free of `&&`. The suite passes standalone (1137 asserts).

### DEPLOY: fix/2659-no-ampersand-chains-in-hints

Three recovery hints the shipping scripts print, from the fold, from `open-pr`'s backing gate and from
the missing-check-suite note, no longer join two commands with `&&`. They print on separate lines, or
join with `;` inside a sentence, so they paste into Windows PowerShell 5.1 as they are.

**Score:** 1

#### What makes this deploy extra special

Prevents a failure nobody has reported yet: pasting one of these hints into Windows PowerShell 5.1 as
printed fails with *"The token '&&' is not a valid statement separator in this version"*. That happens at
the exact moment the hint is needed, which is after something has already gone wrong.

**Score:** 1

#### Pull Request

Printed console hints no longer chain commands with '&&'

