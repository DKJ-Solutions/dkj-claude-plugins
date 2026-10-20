## feat/ink-and-paper

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

The owner (Dave, October 20, 2026): split the primary colours into two groups, ink and paper. Ink is the colours
on the text, paper the colours behind it, and `--primary-*` no longer exists afterwards. Ink may take large steps
(as `-9` to `-12` do now), paper very small ones (as `-1` to `-3` do now). Asked where the greys `-5` to `-8` go,
the owner chose: they become ink, and the stronger border `-5` becomes a paper tint (`paper-4`). `-4`, the light
anchor, had no CSS role and is no token any more.

### CREATE

- [x] `house-style.css`: every theme block and both default blocks define `--paper-1` to `--paper-4` and `--ink-1` to `--ink-7`; `-1`/`-2`/`-3` become paper-1 to -3, `-9`/`-10`/`-11`/`-12` ink-1 to -4, `-8`/`-7`/`-6` ink-5 to -7; `paper-4` computed at 36% of the way from paper-1 to the light anchor in OKLCH (the formula reproduces `-2` at 4% and `-3` at 16%); every use renamed and the token comments rewritten
- [x] README: Paper and Ink rows replace the Primary rows, the theme-reach section restated in paper and ink, a rename table for apps; the dialog exception named the tokens it really re-declares (`--paper-2`, `--ink-7`, was `-5`/`-2`)
- [x] `house-style-rules.ps1`: `--primary-1` to `--primary-12` retired, so the gate reports a leftover in a consumer; `--ink-2` taken off the retired list, it is live again
- [x] The brand book app, the hub pages, the repo's dev pages, `repo-config.ps1` and the two suites follow the rename; the showcase lists paper and ink as two groups
- [x] The stylesheet checksum re-pinned in the `house-style` skill

### TEST

- [x] `check-house-style.tests.ps1` 88/88, `dev-pages.tests.ps1` 259/259, `npm run gate` in `brandbook/` green
- [ ] The owner has looked at paper and ink, `paper-4` above all (a tint now, 1.08:1 on a card in Oker)

### DEPLOY: feat/ink-and-paper

The house colour splits into two groups. **Paper** (`--paper-1` to `--paper-4`) is what sits behind the text, in
very small steps: the page, the cards, every line and the tinted surfaces, and a stronger border. **Ink**
(`--ink-1` to `--ink-7`) is what sits on it, in large steps: the highlight and `h1`, `h2`, `h3`-`h5`, all text,
then the three greys for the breadcrumb, sub lines and notes, and the eyebrow and fills. `--primary-*` is gone.
Every role keeps its colour except the stronger border, which turns from a grey into a tint a step past the line.
The house-style gate reports every `--primary-*` left behind as a retired token.

**Score:** 4

#### What makes this deploy extra special

Every DKJ-Solutions app that takes this release has to rename its own layer: `--primary-1`..`-3` become
`--paper-1`..`-3`, `-5` becomes `--paper-4`, `-9`..`-12` become `--ink-1`..`-4`, and `-8`/`-7`/`-6` become
`--ink-5`/`-6`/`-7`. The house-style README carries the table, and the gate names each leftover.

**Score:** 5

#### Pull Request

Split the primary scale into ink and paper

