## feat/3648-btn-hover

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

#### Status

A visible result, looked at and approved by the owner (Maikel, October 29, 2026).

### CREATE

- [x] `.btn:hover:not(:disabled)`: the house hover tint `--paper-3`, border one step on to `--paper-4`
- [x] `.btn:focus-visible` for every variant (the plain `.btn` had none); the identical `.btn--primary` and
  `.btn--touch` focus rules it replaces are removed
- [x] `.btn--primary:hover:not(:disabled)`: fill and border 15% toward `--fg-1` via `color-mix`, so the
  `--paper-1` label gains contrast in light and dark themes alike; outweighs `.btn--touch.btn--primary`
- [x] README: the reserved-class list, the Buttons note and the brand-book "not carried over" line name the new states

### TEST

- [x] The owner's look at the hover and focus states in a light and a dark theme (approved, October 29, 2026)

### DEPLOY: feat/3648-btn-hover

A house `.btn` now answers the pointer: an outline button takes the `--paper-3` hover tint with a
`--paper-4` edge, and a `.btn--primary` fill moves 15% toward `--fg-1` -- darker on a light theme,
lighter on a dark one, so its label gains contrast either way. A disabled button keeps still. The plain
`.btn` also gets the `--muted` keyboard focus ring the primary and touch variants already had, now one
rule for every variant.

**Score:** 2

#### What makes this deploy extra special

An app built on the house style shows hover feedback on every button once it takes this version, with
nothing to change in its own layer (asked for from `dkj-music-library`).

**Score:** 2

#### Pull Request

House style: a hover and focus state for .btn and .btn--primary

