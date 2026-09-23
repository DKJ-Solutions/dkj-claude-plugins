## fix/2341-golive-private-link

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

Refuse -Link on claude.ai/artifact URLs the Asana requester cannot open; name the preview URL instead.

#### Triage (inbound #2341)

- Symptom stands: `-Link`'s help named "the handover page" and the example used a `claude.ai/code/artifact` URL.
- Reason holds: `PREVIEW-portable.md` states the handover page is private until its link is shared.
- Repair corrected: the report names `Get-MarketUrls` as a source of preview URLs; it builds LIVE URLs.
  The preview URL is `Get-MarketPreviewUrls`, which is what the refusal and the docs now name.
- Refuse rather than warn, on a separate `-AllowPrivateLink` valve: `-Force` already answers the
  duplicate-block check, and conflating the two would let one bypass wave the other through.

### CREATE

- [x] `Test-PrivateResultLink` in `golive-block-rules.ps1` -- pure, host-anchored, both Artifact shapes
- [x] `build-golive-block.ps1` refuses such a `-Link` before building the block, unless `-AllowPrivateLink`; help text and example repointed
- [x] `golive-block` SKILL.md: `-Link` row requires a link openable without an account, `-AllowPrivateLink` row, a "does not do" bullet
- [x] Asserts in `dkj-policy-bwj.tests.ps1`
- [~] Is the change visible in the frontend / storefront? No -- a script refusal and its docs; nothing renders.

### TEST

- [x] `dkj-policy-bwj.tests.ps1`: 370 asserts green
- [x] Driver run with `-Link https://claude.ai/code/artifact/abc` prints the refusal and exits 1

### DEPLOY: fix/2341-golive-private-link

`build-golive-block.ps1` accepted the preview handover page -- a private `claude.ai` Artifact -- as
`-Link`, and its own help suggested it, so the paste-ready block reached the Asana requester with a link
they could not open (measured in `BWJ-Development/smartwatchbanden#750`). It now refuses a
`claude.ai/artifact/` or `claude.ai/code/artifact/` link before the block is built, names a storefront
preview URL (`Get-MarketPreviewUrls`) as the alternative, and takes `-AllowPrivateLink` for a page that
has actually been shared. The skill page's `-Link` row now says the link must open without an account
(#2341).

**Score:** 2 -- one wrong link per affected block, caught by the owner and edited by hand; the refusal
removes the hand edit.

#### What makes this deploy extra special

N/A -- the reader of the block is a store's colleague, one hop past the party running the upgrade; for
that party it is a refusal on a mistaken argument, nothing to migrate.

**Score:** N/A

#### Pull Request

golive-block refuses a private claude.ai artifact link
