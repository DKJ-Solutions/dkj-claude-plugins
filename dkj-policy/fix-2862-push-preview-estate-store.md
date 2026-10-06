## fix/2862-push-preview-estate-store

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

Issue #2862, the sibling of #2859: `push-preview.ps1` read its store from `Get-ShopifyStoreDomain` alone,
the seam a consumer may leave unanswered as a brake on `sync-main` (#1965 point 4). Checked first whether
that was deliberate: neither the script, its skill page nor #1965 gives a reason, and #1965 split the seam
off for the backup only. Same repair as #2859: estate seam first, `Get-ShopifyStoreDomain` as a fallback.

### CREATE

- [x] `push-preview.ps1` (shopify plugin and root copy, byte-identical): estate seam first, fallback, refusal names the estate seam, `-Store` help updated
- [x] `skills/push-preview/SKILL.md`: the `-Store` row and the seam table

### TEST

- [x] `push-preview.tests.ps1`: three seam asserts through the script on a fixture repo on its trunk (estate only, store domain only, neither) -- 133/133 green; two of them fail against the unfixed script

### DEPLOY: fix/2862-push-preview-estate-store

`push-preview` now finds its store through `Get-ShopifyThemeEstateStore`, the seam `backup-live-theme`
and `archive-theme` read. It falls back to `Get-ShopifyStoreDomain` where only that one is answered.
Until now it read `Get-ShopifyStoreDomain` alone, so a store repo that leaves that seam unanswered on
purpose, as a brake on `sync-main`, needed `-Store` for every preview push.

**Score:** 2

#### What makes this deploy extra special

In a store repo that answers `Get-ShopifyThemeEstateStore`, `push-preview` runs without `-Store`. A repo
that answers only `Get-ShopifyStoreDomain` sees no change.

**Score:** 2

#### Pull Request

push-preview reads Get-ShopifyThemeEstateStore first, like the theme lifecycle

