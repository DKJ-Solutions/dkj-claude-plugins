## fix/3588-house-style-tag-fallback

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

Option A of [#3588](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3588), the owner's
decision of October 27, 2026: a copy that fails the installed pin is judged again against the skill page
as it reads at the tag it names.

### CREATE

- [x] `Get-HouseStyleTagPin` in `house-style-rules.ps1`: fetches the page at the tag (5s timeout), and takes it only when it pins that same tag
- [x] The session check and a hand-run gate (no `-SkillPath`) use it, and only after a `pin` finding
- [x] The skill page: the fetch rule checks against the page at the tag before stopping, and the claim that an installed page is coherent is corrected

### TEST

- [x] `check-house-style.tests.ps1`: unit asserts on the tag pin, plus a fixture whose copy matches only the tag's table, offline through `DKJ_HOUSE_STYLE_TAG_PAGE` (90 passed)
- [x] Live: the page fetched at `v5.34.0` pins `265a61cd...`, the checksum the issue measured on the consumer's copy

### DEPLOY: fix/3588-house-style-tag-fallback

The house-style session check no longer flags a consumer's copy that is exactly the released file. An
install tracks `main`, so between a house-style merge and the next cut the installed skill page named
the old tag beside the new checksums, and the check told a correct repo to replace its copy with itself.
A copy that fails the installed page is now judged again against the page as it reads at that tag. The
page is fetched only in that case, so a clean session makes no network call. A hand run of
`check-house-style.ps1` from an install does the same, and the skill tells a session that fetches the
files to check that page before it stops.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo's session no longer opens with a house-style warning it cannot clear in the days
between a house-style change and the release that carries it.

**Score:** 2

#### Pull Request

house-style check falls back to the skill page at its tag

