## fix/2619-golive-bare-live-urls

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

Inbound #2619, verified in the tree: `build-golive-block.ps1` pinned every live-URL row to
`Get-ControlThemeId`, so each "live" link read `?preview_theme_id=<live id>` under a label saying live.
The repair is the issue's first option: bare URLs, and the cookie caveat in the label, which
`LiveBare` already carried for the unpinned case. The issue's "also seen" note (the NL path reused on
every market domain) is marked inferred and not a defect there, so it is left alone.

### CREATE

- [x] `golive-block-rules.ps1`: the `LivePinned` wording and switch removed; beside a result link the label is always `LiveBare`
- [x] `build-golive-block.ps1`: `-LiveThemeId` and the `Get-ControlThemeId` read removed; the list is always `Get-MarketUrls`
- [x] `golive-block` SKILL.md and `WORKFLOW-portable.md`: the block and the fact table describe bare URLs

### TEST

- [x] `dkj-policy-bwj.tests.ps1`: a live-id seam no longer pins the URL, a throwing seam is never called, and the private-window caveat stands beside a result link -- 490 asserts green standalone

### DEPLOY: fix/2619-golive-bare-live-urls

The go-live block's live-URL list now shows plain storefront URLs. They were pinned to the live theme
id, so every "live" link read `?preview_theme_id=...` and looked like a preview link to the colleague
reading it. Beside a result link, the label now tells the reader to open the links in a private window
until the release, since a browser that opened the preview keeps showing it. `-LiveThemeId` is gone
from `build-golive-block.ps1` (#2619).

**Score:** 2

#### What makes this deploy extra special

In a store repo running `dkj-policy-bwj`, the block pasted into Asana no longer has to be rewritten by
hand before it goes out: the live links are the plain URLs a colleague recognises. A session that still
passes `-LiveThemeId` to `build-golive-block.ps1` is refused by parameter binding, so drop the argument.

**Score:** 2

#### Pull Request

golive-block: the live-URL list is bare, with the private-window caveat

