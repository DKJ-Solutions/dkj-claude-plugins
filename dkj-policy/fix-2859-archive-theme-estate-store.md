## fix/2859-archive-theme-estate-store

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

Issue #2859: `archive-theme.ps1` read its store from `Get-ShopifyStoreDomain`, the seam a consumer may
leave unanswered as a brake on `sync-main` (#1965 point 4), while `backup-live-theme`,
`sweep-preview-themes` and `live-preflight` read `Get-ShopifyThemeEstateStore`. Verified in the tree.
Read the estate seam first and keep `Get-ShopifyStoreDomain` as a fallback, so a consumer answering only
that one keeps working. `push-preview` has the same shape and is filed as #2862.

### CREATE

- [x] `archive-theme.ps1` (shopify plugin and root copy, byte-identical): estate seam first, fallback, refusal names the estate seam, `-Store` help updated
- [x] `skills/archive-theme/SKILL.md`: the `-Store` row names the seam it overrides

### TEST

- [x] `theme-archive-rules.tests.ps1`: three seam asserts through the script with `-RootOverride` (estate only, store domain only, neither) -- 156/156 green; two of them fail against the unfixed script

### DEPLOY: fix/2859-archive-theme-estate-store

`archive-theme` now finds its store through `Get-ShopifyThemeEstateStore`, the seam the other
theme-lifecycle scripts read. It falls back to `Get-ShopifyStoreDomain` where only that one is answered.
It used to read `Get-ShopifyStoreDomain` alone, so a store repo that leaves that seam unanswered on
purpose, as a brake on `sync-main`, had to pass `-Store` on every run.

**Score:** 2

#### What makes this deploy extra special

In a store repo that answers `Get-ShopifyThemeEstateStore`, `archive-theme -ThemeId <id>` runs without
`-Store`. Do not answer `Get-ShopifyStoreDomain` to make it run: that also opens `sync-main`'s bare
pull-request route.

**Score:** 2

#### Pull Request

archive-theme reads Get-ShopifyThemeEstateStore, like the rest of the theme lifecycle

