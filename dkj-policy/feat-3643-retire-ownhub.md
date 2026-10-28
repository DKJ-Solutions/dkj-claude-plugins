## feat/3643-retire-ownhub

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

Maikel chose option A on October 29, 2026: retire `OwnHub`, so every `dkj-policy` consumer gets the
plugin's Toolbox with no exceptions, always in the house style. Shape as filed in #3643: a stated `OwnHub`
or `Product` is ignored, not refused, like `Name` since #3064, and named as config drift.

### CREATE

- [x] Hook and rules: `OwnHub` and its `Product` are recorded as stated and otherwise not read; the `ownhub`
      mode, the second server, its line forms and the OwnHub drift fact go; an old `ownhub` state file
      reads as `product`
- [x] Drift: the unread keys (`Name`, `OwnHub`, `Product`) share one defect, so the worst line still ends
      inside the 300-character cap (measured 316 with one defect per key)
- [x] General pages server: the 303 to an own hub goes; the setup card no longer offers the opt-out
- [x] `cut-release.ps1` (both copies): the product's ports are the stated ports
- [x] Docs: the three-part rule in `hub/README.md`, "One look in every repo"; the house-style README's
      line 28 sharpened; the `house-style` skill; the stale DEV-PREVIEW sentence in the `dkj-solutions`
      manifest descriptions (the hook is `dkj-policy`'s since #3198)

### TEST

- [x] `dev-preview-sessionstart.tests.ps1`: 402 passed, 0 failed, the OwnHub cases rewritten as a retired
      OwnHub serving its server as the product
- [x] `dev-pages.tests.ps1` 478 passed, `connector-dashboard.tests.ps1` 236 passed

### DEPLOY: feat/3643-retire-ownhub

A repo that ran its own hub through `OwnHub` now gets the plugin's Toolbox at its next session start, its
own server becoming the product; every other repo sees no change.

**Score:** 2

#### What makes this deploy extra special

Every repo that runs `dkj-policy` now gets the plugin's Toolbox, always in the house style, with no
opt-out. A repo that still states `OwnHub = $true` (or a `Product` beside it) in `Get-DevPreview` keeps
working: its server becomes its product on the Toolbox, and in a DKJ-Solutions repo the session line asks
you to delete those keys. The rule, Toolbox for all and the house style on a product only in DKJ-Solutions
repos, is in the [hub README](../plugins/dkj-policy/hub/README.md#one-look-in-every-repo).

**Score:** 2

#### Pull Request

Retire OwnHub: every dkj-policy consumer gets the Toolbox, no exceptions

