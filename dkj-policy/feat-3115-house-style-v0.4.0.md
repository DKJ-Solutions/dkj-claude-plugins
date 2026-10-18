## feat/3115-house-style-v0.4.0

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

Opened by the house-style repoint runner (#3100): `DKJ-Solutions/dkj-brandbook` released `v0.4.0`, and the skill pinned `v0.3.0`.
The files served at `v0.4.0` passed the denylist of spellings the skill page forbids, which is not a
review of the script. Both files changed, so the two vendored copies move with the pin. No token was renamed or removed, so the retired-name list stands.
Before shipping: read the release in the brand book, score the two DEPLOY tiers, and say there what an
app that takes the new copy will notice.

### CREATE

- [x] Repoint every brand-book link in the `house-style` skill to `v0.4.0`, its commit to `b1f1a69f` and both checksums
- [x] Replace the vendored copies under `scripts/dashboard/house-style/` and the plugin's `assets/house-style/`
- [x] `Get-HouseStyleRetiredTokens` follows the new tag
- [x] The repoint's safety read refused `v0.4.0` (`house-theme.js stores under more than one key: key, widthKey`). The single-key rule was the script's own reading, not one #2954 or #3100 names (they name network calls, `eval`, `@import` and remote `url()`); the width choice is a device preference exactly as the theme is. `Get-HouseStyleSafetyFindings` now accepts several keys only where every one is a house `dkj-` name (the whole expression `'dkj-<name>'`, optionally `+ <identifier>`, or a variable whose one assignment outside comments is that); a foreign second key is still a finding. Victor's and Sebastian's reviews found the first draft passed a commented-out declaration, a reassignment, a `DKJ-` capital and a computed `'dkj-'.slice(...)` key; each is now refused and held by `house-style-repoint.tests.ps1`

### TEST

The required check runs `check-house-style.tests.ps1`, which holds both vendored copies to the new checksums.

- [x] Read the `house-theme.js` diff in full: it is inlined into every app that takes the copy, and no check here can prove a script harmless -- read: the width group, `setWidth`/`width()` and a second `localStorage` key `dkj-width<suffix>` holding only a value checked against `fluid|phone|full`; no network, no `eval`, no new sink beyond the panel's own fixed markup
- [x] The dev server serves the new copy (`/house-theme.js` carries `dkj-width`); the settings panel's look is for the owner to judge on this branch

### DEPLOY: feat/3115-house-style-v0.4.0

The `house-style` skill now fetches from the brand book's `v0.4.0` release
([DKJ-Solutions/dkj-brandbook@v0.4.0](https://github.com/DKJ-Solutions/dkj-brandbook/releases/tag/v0.4.0)). Both files changed, so the two vendored copies move with the pin. No token was renamed or removed, so the retired-name list stands.
The settings panel of every page the dev server renders now offers the page width -- fluid, phone or
full -- remembered per device like the theme ([#3115](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3115),
brand book #203). The repoint's safety read now accepts a second storage key where it is a house
`dkj-` name, which is what let this release through; a foreign key is still refused.

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions app that takes the plugin's `assets/house-style/` copy gets the width choice in its
settings panel without writing a line, and can opt out with `settings(el, { widths: false })` where
its layout has no page column.

**Score:** 2

#### Pull Request

