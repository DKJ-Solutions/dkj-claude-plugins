## feat/3608-default-theme-pair

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

Inbound #3608, verified against the tree: `ConvertTo-DevPreviewConfig` validated `DefaultTheme` as one id, the
state file believed one id, and all three `<html>` renderers wrote `data-theme-default` only. `house-theme.js`
already resolves `data-theme-light`/`data-theme-dark` by OS mode when no `data-theme-default` is set, so the
pair needs no change to the house style. Carry it as a `light/dark` string end to end.

### CREATE

- [x] `dev-preview-rules.ps1`: `DefaultTheme` accepts `@{ Light; Dark }` (both halves, each a theme id, nothing else), carried as `light/dark`; `Test-DevPreviewThemeValue` lets the state file believe a pair
- [x] `general-pages-lib.ps1`: `Format-GeneralPagesThemeAttributes` writes `data-theme-default` for one id, `data-theme-light`/`data-theme-dark` for a pair; the hub, the general pages and the release notes use it
- [x] `hub/README.md` and the `Get-DevPreview` comment document the pair

### TEST

- [x] `dev-preview-sessionstart.tests.ps1` and `dev-pages.tests.ps1`: the pair is carried, refused when incomplete or extended, read back from the state file, rendered on all three page kinds without `data-theme-default`, and escaped; a single id renders exactly as before

### DEPLOY: feat/3608-default-theme-pair

The hub's `DefaultTheme` gains a second form beside the single theme id; the single form renders byte-identically.

**Score:** 1

#### What makes this deploy extra special

A DKJ-Solutions repo whose product opens in a light/dark theme pair can now state the same pair for the plugin's
hub and general pages, `DefaultTheme = @{ Light = 'blue'; Dark = 'sky' }` in `Get-DevPreview`, so on a dark OS the
hub no longer opens in the light theme while the product opens in the dark one. See the
[hub README](../plugins/dkj-policy/hub/README.md).

**Score:** 3

#### Pull Request

Hub: let DefaultTheme state a light/dark theme pair

