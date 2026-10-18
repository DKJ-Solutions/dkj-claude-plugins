## feat/house-style-v0-3-0

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

Opened by the house-style repoint runner (#3100): `DKJ-Solutions/dkj-brandbook` released `v0.3.0`, and the skill pinned `v0.2.0`.
The files served at `v0.3.0` passed the denylist of spellings the skill page forbids, which is not a
review of the script. Both files changed, so the two vendored copies move with the pin. No token was renamed or removed, so the retired-name list stands.
Before shipping: read the release in the brand book, score the two DEPLOY tiers, and say there what an
app that takes the new copy will notice.

### CREATE

- [x] Repoint every brand-book link in the `house-style` skill to `v0.3.0`, its commit to `ea4bf213` and both checksums
- [x] Replace the vendored copies under `scripts/dashboard/house-style/` and the plugin's `assets/house-style/`
- [x] `Get-HouseStyleRetiredTokens` follows the new tag

### TEST

The required check runs `check-house-style.tests.ps1`, which holds both vendored copies to the new checksums.

- [ ] Read the `house-theme.js` diff in full: it is inlined into every app that takes the copy, and no check here can prove a script harmless

### DEPLOY: feat/house-style-v0-3-0

The `house-style` skill now fetches from the brand book's `v0.3.0` release
([DKJ-Solutions/dkj-brandbook@v0.3.0](https://github.com/DKJ-Solutions/dkj-brandbook/releases/tag/v0.3.0)). Both files changed, so the two vendored copies move with the pin. No token was renamed or removed, so the retired-name list stands.

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

house-style skill: repoint at dkj-brandbook v0.3.0

