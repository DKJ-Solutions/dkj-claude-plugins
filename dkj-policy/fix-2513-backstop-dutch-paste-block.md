## fix/2513-backstop-dutch-paste-block

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

The issue left the direction open between three options. The choice here is the session route's own
frame, cut down to what CI can know. Calling `Format-GoLiveBlock` is not possible, because the template
ships standalone into a consumer's `.github/` without the plugin's libs. So the template carries a copy
of the words, and the suite holds that copy equal to `Get-GoLiveBlockText`.

### CREATE

- [x] `New-AsanaPasteBlockComment` writes the Dutch header line plus `TE BEKIJKEN OP` with the
  `[ADD LINK]` sentence, and no other section
- [x] `WORKFLOW-portable.md`'s backstop section states the new shape and why it is a copy

### TEST

- [x] `dkj-policy-bwj.tests.ps1`: the backstop's pasted block, line by line, and its parity with
  `Get-GoLiveBlockText` (448 asserts green)

### DEPLOY: fix/2513-backstop-dutch-paste-block

The CI backstop in `asana-mirror.ps1` no longer posts the old English sentence (`The fix for
<repo>#<n> is done. You can view the result here: [ADD LINK]`). It posts the frame the session route
writes since #2507: the Dutch opening line `— automatisch bericht vanuit GitHub #<n>` and the
`TE BEKIJKEN OP` section, with `[ADD LINK]` still standing where the link goes. The sections CI cannot
fill are left out rather than placeholdered. The template carries a copy of those words, because it
ships without the plugin's libs, and `dkj-policy-bwj.tests.ps1` now holds that copy equal to
`Get-GoLiveBlockText`. The two writers of one block therefore cannot drift apart again. The marker and
the lead sentence the de-duplication matches on are unchanged.

**Score:** 2

#### What makes this deploy extra special

A BWJ store that re-adopts the template gets a backstop block in its colleagues' language and in the
same shape as the session's own. So a person no longer has to rewrite it before pasting it into Asana.
It reaches the store only on that re-adoption, and only on the rare close where the session skipped
its own block.

**Score:** 2

#### Pull Request

asana-mirror's backstop writes the Dutch sectioned paste block, not the old English one

