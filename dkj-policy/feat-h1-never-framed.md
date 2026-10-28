## feat/h1-never-framed

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

House style: the h1 is never framed -- no border, outline, shadow or background on it, and the page's h1 never sits inside a card or bordered box (owner's rule, October 28, 2026).

### CREATE

- [x] `house-style.css`: a second `h1` rule clears `border`, `outline`, `box-shadow` and `background`, with its comment
- [x] `assets/house-style/README.md`: rule 6 under "How to use it", the h1 is never framed
- [x] `house-style` skill: the same rule under "Density", and the pin table's `house-style.css` checksum follows the file
- [x] Applied in the hub: the group pages (`/clock` among them) and both SessionStart pages put their `h1` above the card group instead of in its `.grid__head`, since the group has stood on its own `--paper-2` surface since October 28; the dead `.ss-cards > .grid__head > h1` rule goes
- [x] `.page-column`'s gap from `--spacing-5` to `--spacing-3` (the owner, the same review), its two comments following, and the pin's checksum again

### TEST

- [x] `check-house-style.tests.ps1`: 90 passed, 0 failed (8 failed before the checksum followed the file, as the skill says it must)
- [x] `house-palette.tests.ps1`: 128 passed, 0 failed
- [x] `dev-pages` 484/0 (the `/clock` assert now pins the h1 above its group), `dev-preview-sessionstart` 419/0, `stopwatch` 266/0, `connector-dashboard` 235/0

### DEPLOY: feat/h1-never-framed

A new house-style rule: the `h1` is never framed. `house-style.css` now clears any border, outline, shadow and background on every `h1`. The README (rule 6) and the `house-style` skill state the layout half too: a page's `h1` stands on the page itself, never inside a card, panel or bordered box. The hub follows it already: its group pages (`/clock` among them) and the SessionStart pages had their `h1` inside the card group's surface, and now set it above the group. Alongside it, `.page-column` stacks its blocks with a `--spacing-3` gap instead of `--spacing-5`, so every page built on it is a little tighter. A repo whose own layer gave its `h1` a frame through a plain `h1` selector loses that frame when it takes this copy. A rule on a class of the repo's own still wins, and the rule says it must not be written.

**Score:** 2

#### What makes this deploy extra special

Every DKJ-Solutions app takes this the next time it copies the house style. On the hub, the group pages and the SessionStart pages now show their `h1` above the cards rather than inside the group's surface. The rule exists so that no app starts framing it.

**Score:** 2

#### Pull Request

the h1 is never framed
