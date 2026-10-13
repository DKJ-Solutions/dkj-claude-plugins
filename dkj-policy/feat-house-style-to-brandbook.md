## feat/house-style-to-brandbook

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

The house-style skill keeps the rules a session needs and points at dkj-brandbook for the stylesheet and the theme script, which leave this repo.

### CREATE

- [x] `house-style.css` and `house-theme.js` moved to DKJ-Solutions/dkj-brandbook (its PR #1, byte-identical) and removed here
- [x] `skills/house-style/SKILL.md` rewritten as a pointer: the raw URLs, the README, and the three rules a session needs first
- [x] the plugin's `README.md`, `CLAUDE.md` and `plugin.json` description name the brand book as the home
- [x] Gwen's lens here keeps only the pointer; her house-style rules moved to her brandbook lens (its PR #2)

### TEST

- [x] the raw URL `https://raw.githubusercontent.com/DKJ-Solutions/dkj-brandbook/main/house-style/house-style.css` answers 200
- [x] no file in this tree still references `house-style.css` or `house-theme.js` beside the skill page

### DEPLOY: feat/house-style-to-brandbook

The DKJ-Solutions house style moved to its own repo,
[DKJ-Solutions/dkj-brandbook](https://github.com/DKJ-Solutions/dkj-brandbook) (`house-style/`). The
stylesheet, the theme script and the full rules (tokens, themes, reserved classes) live there now and
nowhere else. The `house-style` skill in `dkj-solutions` stays and still loads in every DKJ-Solutions
session, but it is a pointer: the two raw URLs, the README, and the three rules a session needs before
it fetches anything. A change to the house style is made in the brand book from now on.

**Score:** 3

#### What makes this deploy extra special

The house style and the overview of every DKJ-Solutions component now sit in one repo, so the brand is
checked in one place. An app that takes the update gets the same values as before: nothing was changed
in the move.

**Score:** 3

#### Pull Request

The house style moves to dkj-brandbook; the skill points there

