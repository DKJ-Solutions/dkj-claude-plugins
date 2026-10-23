## feat/3327-golive-market-optout

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

#### Inbound #3327, checked against the tree

`build-golive-block` builds its live list with `Get-MarketUrls`, which reads every row of the store's
`Get-StorefrontMarkets` table. There is no per-row switch, so deleting the rows was the only lever, and
that would also have taken the GB markets out of the preview handover. The issue left one choice to the
maintainers: should the preview paths drop the rows too? They do not. The request named only the go-live
block, and the field is read only where `-GoLiveOnly` is passed.

### CREATE

- [x] `market-urls.ps1`: `Get-MarketTable` reads an optional boolean `GoLive` (default `$true`, a quoted value refused) and carries it on each row
- [x] `Get-MarketUrls -GoLiveOnly` drops the `GoLive = $false` rows after the pages are parsed against the whole table, and refuses when no row is left
- [x] `build-golive-block.ps1` passes `-GoLiveOnly`; its synopsis and the `golive-block` skill say so

### TEST

- [x] `bwj-market-urls.tests.ps1`: default, the filter on hashtable and object rows, the preview paths unchanged, a per-market override of a dropped market, an empty result refused, a quoted value refused (167 pass, 0 fail)
- [x] `bwj-development.tests.ps1`: the driver run through `-File` leaves a `GoLive = $false` market out of the block

### DEPLOY: feat/3327-golive-market-optout

A store can now leave a market out of the go-live block's live URL list without removing it from its
previews ([#3327](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3327)). A row in
`Get-StorefrontMarkets` takes an optional `GoLive = $false`, and `build-golive-block` drops that market
from `WHEN IT GOES LIVE`. The preview URLs and the handover cards still carry it, and so does the
`-Path` a session already gives the preview, a per-market override of that market included. A row
without the field is listed as before. A quoted `'false'` is refused, because PowerShell reads it as
true. A table where every market is marked `$false` is refused too.

**Score:** 2

#### What makes this deploy extra special

A store that previews a market but does not want it in the message to the requester sets one field on
that row. Before, deleting the row also took it out of the preview handover.

**Score:** 2

#### Pull Request

build-golive-block: let a store keep a market out of the go-live block's live URL list
