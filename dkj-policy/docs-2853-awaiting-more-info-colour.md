## docs/2853-awaiting-more-info-colour

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

Issue #2853: `adopt-bwj-development` prescribed `d4c5f9` for `awaiting-more-info`, while the rest of the
`awaiting-*` family is `5319E7`. Verified: the two `--color d4c5f9` lines in its SKILL.md are the only
occurrences in the tree.

### CREATE

- [x] both colour lines in `bwj-development/skills/adopt-bwj-development/SKILL.md` now read `5319E7`
- [x] one paragraph after them gives the in-place recolour for a tracker adopted with the old colour

### TEST

- [x] `git grep -i d4c5f9` returns nothing; the gates run in `ship-pr`

### DEPLOY: docs/2853-awaiting-more-info-colour

`adopt-bwj-development` now prescribes `5319E7` for the `awaiting-more-info` label, in both the rename and
the create line, which is the colour of the rest of the `awaiting-*` family. It prescribed `d4c5f9`, so
that one label stood out on every tracker that followed the page.

**Score:** 1

#### What makes this deploy extra special

A store repo adopted before this release has `awaiting-more-info` in pale lavender. Recolour it with
`gh label edit awaiting-more-info --color 5319E7 --repo <owner>/<repo>`; xoxowildhearts and
smartwatchbanden were recoloured by hand on October 6, 2026.

**Score:** 1

#### Pull Request

adopt-bwj-development prescribes 5319E7 for awaiting-more-info

