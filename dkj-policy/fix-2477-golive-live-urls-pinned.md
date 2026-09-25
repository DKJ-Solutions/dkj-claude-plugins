## fix/2477-golive-live-urls-pinned

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
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

`build-golive-block.ps1` pins the paste-ready block's live URLs to the live theme id, so a requester who
opened the preview result link first is not shown the preview again on the "live" links.

#### Verification (#2477)

- Symptom stands: `Get-MarketUrls` at `build-golive-block.ps1:256` returns bare URLs, and the result
  link is a preview URL that sets the per-domain cookie (`PREVIEW-portable.md`, the control URL section).
- Repair chosen: the issue's first option, folded into the existing list rather than a second list. A
  URL pinned to the live id is a comparison before the release and the live page after it, because a
  live push keeps the theme's id. `Get-ControlThemeId` already resolves it (`-LiveThemeId`, else
  `Get-ShopifyLiveThemeId`).
- Where no id resolves, the list stays bare (never a guessed id) and its label carries the second
  option: open these in a private window before the release.

### CREATE

- [x] `golive-block-rules.ps1`: `Format-GoLiveBlock -LivePinned` picks the list's label; the unpinned label carries the private-window caveat only beside a result link
- [x] `build-golive-block.ps1`: `-LiveThemeId`, resolved through `Get-ControlThemeId`; the URLs pinned where it answers, bare and said so where it does not
- [x] Suite: the three labels, and the driver run with no id, with the seam, and with `-LiveThemeId`
- [x] WORKFLOW-portable (the facts table and the block example), PREVIEW-portable (the paragraph that left this to the script), golive-block SKILL.md
- [~] Is the change visible in the frontend / storefront? No -- the storefront renders nothing differently; the text of a GitHub comment changes

### TEST

- `dkj-policy-bwj.tests.ps1` standalone: 395 asserts green, the new ones included; the lint and test gate through `open-pr`, then CI.

### DEPLOY: fix/2477-golive-live-urls-pinned

`golive-block`'s live URLs are now pinned to the live theme id wherever the store names one
(`-LiveThemeId`, or `Get-ShopifyLiveThemeId` in `scripts/repo-config.ps1`). A bare storefront URL
renders the preview in any browser that opened the result link first, so both tabs agreed and the
change could look live before the release. Where no id resolves, the URLs stay bare and the block tells
the requester to open them in a private window until the release.

**Score:** 2 -- one script and its label; nothing a developer here calls changes.

#### What makes this deploy extra special

A store running `golive-block` hands its requester live links that show what is live now, even after
they opened the preview, and the same links show the change once it ships. A store with no live-id seam
gets a label saying how to read them instead.

**Score:** 2

#### Pull Request

golive-block pins the block's live URLs to the live theme id
