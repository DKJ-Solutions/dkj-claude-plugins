## fix/2800-light-pin-drops-dark-block

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

Inbound #2800, verified against the tree: the template's `@media (prefers-color-scheme: dark)` block
redefines all nine tokens, and `color-scheme` does not stop that query matching. Fix by removing the
dark block when the theme pins light, rather than back-filling light values (one source for them).

### CREATE

- [x] `Test-ReleasePageLightPin` + `Remove-ReleasePageDarkBlock` in `build-release-notes-page.ps1`, applied before the placeholders are filled
- [x] Template comment and the `release-notes-page` skill page say what the pin actually does
- [x] Mirror copied to `scripts/release/`

### TEST

- [x] `release-notes-page.tests.ps1`: a light pin leaves no dark block and keeps unnamed tokens light; `light dark` is not a pin -- 175 passed, 0 failed

### DEPLOY: fix/2800-light-pin-drops-dark-block

**A `'color-scheme' = 'light'` answer from `Get-ReleasePageTheme` now actually pins the release-notes
page light** ([#2800](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2800)). The property
alone never stopped the template's `@media (prefers-color-scheme: dark)` block matching, because that
query follows the OS rather than `color-scheme`; so on a dark-mode browser every token the repo did not
name turned dark while the ones it did name stayed light. `build-release-notes-page.ps1` now removes the
template's dark block when the theme names `light` and not `dark` (`Test-ReleasePageLightPin`,
`Remove-ReleasePageDarkBlock`), and warns if the block is no longer in the shape it looks for. The
template comment and the `release-notes-page` skill page are corrected, and the suite asserts a pin
leaves no dark override behind.

**Score:** 2

#### What makes this deploy extra special

A repo that pins its release-notes page light and names only some colours no longer gets an unreadable
page -- dark text on the template's dark background -- for every reader whose browser is in dark mode.
The hand-pinning of every token that repo did as a workaround can come out after the update.

**Score:** 3

#### Pull Request

release-notes page: a 'color-scheme: light' pin removes the template's dark block
