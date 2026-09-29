## fix/2627-golive-per-market-paths

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

Inbound #2627, verified in the tree. It named two defects. The `preview_theme_id` on the live list was
already closed by #2625 (#2619), so this branch covers only the other half: `Get-MarketUrls` applied
every normalized `-Path` verbatim to every market row, so `-Path /collections/apple-watch-straps` gave
all five markets the UK handle (measured in BWJ-Development/smartwatchbanden#394, 2026-09-29). The
repair is additive: a page may carry a per-market spec, `default|NL=/path|DE=/path`, and a plain path
behaves exactly as before. Every caller (`Get-MarketPreviewUrls`, `Get-MarketHandoverPairs`,
`Write-MarketPreviewUrls`, `build-golive-block.ps1`) funnels through `Get-MarketUrls`, so the one
function is the repair. Closes #2627.

### CREATE

- [x] `market-urls.ps1`: new `Get-PageSpecs` parses a page into a default plus per-market overrides; `Format-StorefrontPath` is the shared slash-and-mangled-path step; `Get-MarketUrls` resolves the market table once and uses them
- [x] Refusals with clear messages: unknown label (known ones listed), a label twice, two defaults, an empty `LABEL=`, a page with no default that leaves a market unnamed
- [x] `build-golive-block.ps1` (`.PARAMETER Path`, a second `.EXAMPLE`) and the `golive-block` SKILL.md describe the per-market form

### TEST

- [x] Sanity run of the new form and every refusal on a three-market table; the mangled-path refusal holds on a `LABEL=` segment
- [x] Tycho: the suite for the per-market form in `bwj-market-urls.tests.ps1`

### DEPLOY: fix/2627-golive-per-market-paths

`-Path` of the go-live block and of the preview URL printers now takes a different storefront path per
market, for a page whose handle differs by market: `/collections/apple-watch-straps|NL=/collections/apple-watch-bandjes|DE=...`.
A bare segment is the default for every market not named, and labels match the market table without
regard to case. Before, one path was used on every market domain, so every other market was handed a
handle it does not recognise: it still loaded through a redirect, but it was not that market's address.
Unknown or repeated labels, two defaults, an empty path and a page that leaves a market without a path
are refused. Plain paths behave as before (#2627), with one narrow exception: a path holding `=` and
written without its leading slash (`x=y`) is now read as a market label, so write it `/x=y`.

**Score:** 2

#### What makes this deploy extra special

Nothing to do: a plain `-Path` works unchanged. A store whose collection handles differ per market
should switch its go-live command to the per-market form. The `preview_theme_id` half of #2627 was
already closed by #2625.

**Score:** 1

#### Pull Request

golive-block: -Path takes a per-market handle for a page (default|NL=/path|...)
