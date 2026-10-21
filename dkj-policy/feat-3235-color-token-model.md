## feat/3235-color-token-model

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

Rebuild each theme's eleven colour tokens on the logic of #3235 (the owner's issue, clarified in the session of
October 21, 2026): one primary that reads on all four paper steps and they on it, two muted greys (7:1 on the page,
7:1 on the far end), four paper steps from white towards a little darker, four text steps near black in very small
steps; a dark theme is the mirror. The names were left open, so: `--primary`, `--muted`, `--muted-inverse`,
`--paper-1..4`, `--fg-1..4`. An h2 must read on the page and on a primary fill, so the text switches with the ground
(`.fill-primary`, `.fill-inverse`).

#### Visible result

This is a visible result: the branch stops for the owner's look at the brand book (Tokens, Theme reach) before a PR.

### CREATE

- [x] The model as code: `plugins/dkj-policy/dkj-solutions/scripts/lib/house-palette-lib.ps1` (OKLCH, HSL, WCAG
  contrast, the twelve themes and their steps) and `scripts/build/build-house-palette.ps1` (prints and checks;
  `-Apply` writes `house-style.css`). Documented in the `house-style` skill.
- [x] `house-style.css`: the twelve theme lines and three default blocks written by the build script; the colour
  comment rewritten for the new model; `h2` → `--fg-2`, `h3`-`h5` → `--fg-3`; `.fill-primary` and `.fill-inverse`
  added at the end, where the text switches to the paper.
- [x] Every use renamed (`--ink-1` → `--primary`, `-2` → `--fg-2`, `-3`/`-4` → `--muted`, `-5` → `--fg-4`, `-6` →
  `--fg-3`, `-7` → `--fg-1`) in the brand book, the hub and dev pages, the connector dashboard, the session-start
  template and the house-style allowlist; on the showcase's inverted panel the scrollbar and focus ring take
  `--muted-inverse`.
- [x] The showcase lists the three groups and demonstrates both fills (Tokens, Theme reach).
- [x] README: the token table, the rename table (from `--ink-*` and straight from `--primary-*`), the model, the
  measurements, the Fills section and the reserved class names.
- [x] The gate: `--ink-1`..`--ink-7` retired, `--primary` and `--muted` live again; the skill's checksum repinned.

### TEST

- [x] New suite `house-palette.tests.ps1` (91 asserts): the colour math, every theme's floors, the stylesheet
  holding exactly the computed values, the build script's dry run.
- [x] `check-house-style.tests.ps1` green after its fixtures moved to the new names (88 asserts).
- [x] Brand book `npm run gate`: eslint, CSS syntax, every `var()` resolves, no colour literal, the build.

### DEPLOY: feat/3235-color-token-model

Every theme's colours are rebuilt on one model (#3235), and computed by a script rather than tuned by hand. Each
theme has **one primary**, the most saturated colour of its hue that reads at 4.5:1 on all four paper steps (so the
paper reads on it too); **two greys**, `--muted` at 7:1 on the page and `--muted-inverse` at 7:1 on the far end;
**four paper steps** from white towards a little darker; and **four text steps** (`--fg-1` to `--fg-4`), near black
on light and near white on dark, in very small steps. `h2` and `h3`-`h5` move from the colour to the text steps, and
two new classes, `.fill-primary` and `.fill-inverse`, switch the text to the paper on a coloured ground, so an `h2`
reads there as well. On light the primary is a little darker and the paper a little lighter than before; nothing in
the model is below 4.5:1 any more. `scripts/build/build-house-palette.ps1` computes and writes the values, and a
new suite holds the stylesheet to them.

**Score:** 4

#### What makes this deploy extra special

Every DKJ-Solutions app that takes this release renames its own layer. From v5.26.0's twelve steps:
`--primary-1`..`-3` become `--paper-1`..`-3`, `-4` is removed, `-5` becomes `--paper-4`, `-6` and `-7` become `--muted`, `-8`
becomes `--fg-4`, `-9` becomes `--primary`, `-10` `--fg-2`, `-11` `--fg-3` and `-12` `--fg-1`; a grey on an
inverted surface takes `--muted-inverse`. The house-style README carries both tables, and the gate names each
leftover.

**Score:** 5

#### Pull Request

A new colour token model: primary, muted, paper and text
