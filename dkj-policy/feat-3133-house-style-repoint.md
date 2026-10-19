## feat/3133-house-style-repoint

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

#3133, step 4 of #3130: point the house-style consumer URLs at this repo and port the three dkj-brandbook changes made after v0.4.0 (#205, #207, #206/#210). The `awaiting-release` label was stale: v5.24.0 carries `assets/house-style/`, so it was removed at pickup.

#### The tag decision (Dave, October 19, 2026)

The pin can only name a tag that carries the bytes its checksums name, and once the files ship inside this repo that is always the release that ships the change, whose number the cut decides. The owner chose "the cut rewrites it": a new optional seam, `Get-ReleaseVersionPins`, names the file and URL prefix, and `cut-release.ps1` rewrites every `<prefix>vX.Y.Z/` in it to the tag it cuts, in the release commit. That adds the skill page to what the release commit touches, beside the `plugin.json` bumps.

### CREATE

- [x] Port the post-v0.4.0 brandbook diff onto `assets/house-style/` (README, `house-style.css`, `patterns/repo-dashboard.html`), byte-identical to dkj-brandbook `main`
- [x] `Get-ReleaseVersionPins` seam: contract record (and mirror), this repo's answer in `repo-config.ps1`, blueprint regenerated
- [x] `cut-release.ps1` (and mirror) reads and checks the pins before its first write, and rewrites them beside the version bump
- [x] Pin parser reads `dkj-claude-plugins/<tag>/plugins/dkj-policy/dkj-solutions/assets/house-style/`
- [x] Skill: new URLs and checksums, the cut-rewrites-the-tag wording, the "commit b1f1a69" line dropped; README's URL paragraph repointed
- [x] Hub: its own `<style>` and the `grid__card` class dropped, now that the house style carries `.grid__head`, `.grid__full` and the `.grid-2 > .card` margin

### TEST

- [x] cut-release-drive: the happy path repins both URLs, leaves another prefix alone, and commits the page; a missing pin file refuses with nothing written (94 asserts)
- [x] check-house-style 74, dev-pages 229, script-contract 421, cut-release-guardrail 128, shared-scripts 1162, config-blueprint: all green
- [ ] The owner's look at the hub (a visible result)

### DEPLOY: feat/3133-house-style-repoint

The house style's consumer URLs now point at this repo's own release tag, and the release cut writes that tag in, so the skill page always pins the release that ships it (#3133). The three dkj-brandbook changes made after v0.4.0 are ported: a heading above a group of cards (`.grid__head`), a card that takes the whole row (`.grid__full`), and a card in a `.grid-2` without a doubled top margin. The Repo hub drops its own copies of those rules. `cut-release` takes an optional seam, `Get-ReleaseVersionPins`, for any file that pins a URL at the repo's own tag.

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions app fetching the house style now reads it from `DKJ-Solutions/dkj-claude-plugins` at the plugin's release tag instead of from `dkj-brandbook`, with new checksums, and gets three new layout classes for a heading above its cards. A consumer vendoring a copy takes the new one, and `check-house-style` reports the old copy until it does.

**Score:** 3

#### Pull Request

house-style: consumer URLs pin this repo's release tag, written by the cut, and the post-v0.4.0 brandbook rules are ported

