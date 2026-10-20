## feat/even-primary-dark-steps

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

The owner (Dave, October 20, 2026): the jump from `--primary-11` to `--primary-12` is too big -- make the
steps from `-9` to `-12` run more evenly. Then, after looking: `-1` to `-3` are much too close and `-3` to `-4`
much too far -- make that transition more natural too. Fully equal steps there made the cards bright and every
line as strong as `-4`, so each step was made twice the one before instead -- and on a look the owner kept
the headers but not the backgrounds (Dave: "bij de headers is het beter maar niet de achtergrond"), so the light
steps went back to what they were.

### CREATE

- [x] `house-style.css`: in every theme and both default blocks, `-10` and `-11` recomputed as a third and two thirds of the way from `-9` to `-12` in OKLab (before: the last step was about 3.5x the other two, e.g. blue 0.078 / 0.082 / 0.278; after: three equal steps, blue 0.146 / 0.145 / 0.145); the measured-contrast comment updated (`-10` on `-2` worst 7.8:1, `-11` 12.6:1)
- [x] README: the primary row states how `-10` and `-11` are placed
- [~] `-2` and `-3` respaced as a doubling ramp from `-1` to `-4` -- dropped on the owner's look, reverted to the trunk's values
- [x] The stylesheet checksum re-pinned in the `house-style` skill

### TEST

- [x] `npm run gate` in `brandbook/` green; `check-house-style.ps1` OK
- [x] The owner has looked at the dark steps (Dave: "dat staat nu goed")

### DEPLOY: feat/even-primary-dark-steps

The dark steps of the house primary run evenly: `--primary-10` and `--primary-11` now sit a third and two thirds
of the way from `--primary-9` to `--primary-12` in OKLab, in all twelve themes, so `h1` to `h2` to `h3` to body text
is three equal steps instead of two small ones and one large jump. On light themes `h2` and `h3` read darker, on dark
themes lighter; every contrast stays well above 4.5:1.

**Score:** 2

#### What makes this deploy extra special

Every DKJ-Solutions app that takes this release sees its `h2` and `h3`-`h5` colours shift a step towards body text.
No token is renamed, so nothing has to be migrated.

**Score:** 2

#### Pull Request

Space the primary dark steps -9 to -12 evenly
