## feat/3462-cut-stops-own-product

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

Issue #3462: the held-build refusal (#3353) fired at every cut here, because the dev-preview hook starts the
brandbook product in every session. The cut now stops that product itself where the hook's ownership rule reads
the holder as this checkout's, and keeps the refusal for anything else.

### CREATE

- [x] `Get-DevPreviewOwnedTreeRoots` in `hub/lib/dev-preview-rules.ps1`: the nearest process naming the root above each of our listeners on the given ports (pure, no I/O)
- [x] `cut-release.ps1` (root copy and plugin mirror): before the held-build refusal, stop the trees of the product `Get-DevPreview` states, re-probe, and refuse only if still held
- [x] `brandbook/README.md`: the "stop the dev server before a cut" line now says the cut does it
- [x] `shared-scripts-lib.ps1`: `cut-release` declares `MirrorRunExempt`, since it now probes the hub lib at both depths (the integrity gate's mirror-depth check)

### TEST

- [x] Unit asserts in `dev-preview-sessionstart.tests.ps1`: the hook's cmd.exe is the tree, a hand-run server under the editor stops alone, foreign and other-clone listeners and off-range ports give nothing; the existing `cut-release-drive` held-build case still refuses a holder it does not recognise. Run by `ship-pr`'s gate.

### DEPLOY: feat/3462-cut-stops-own-product

`cut-release.ps1` now stops this checkout's own dev-preview product when it holds a release build's folder, rather
than refusing the cut ([#3462](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3462)). The product is
the one `Get-DevPreview` states (its `Product` beside an own hub, or the server itself). Only a listener on its
ports that the hook's ownership rule reads as this checkout's is stopped, as the tree of the nearest process naming
the root, and the cut names the pid and says that the next session start restarts it. A holder it does not
recognise still refuses the cut before the gates, as it did under #3353. The cut refused at both v5.30.0 and v5.31.0
until the brandbook dev server was stopped by hand.

**Score:** 3

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

cut-release stops this checkout's own product dev server instead of refusing

