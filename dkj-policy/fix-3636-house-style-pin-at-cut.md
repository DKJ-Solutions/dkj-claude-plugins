## fix/3636-house-style-pin-at-cut

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

#### The owner's choice

Direction 1 of #3636 (davekokbwj, October 28, 2026): `cut-release` writes the house-style checksums in the
release commit beside the tag it already writes (#3133), and `check-house-style.tests.ps1` stops holding the
canonical copy to the pin between cuts.

### CREATE

- [x] `cut-release.ps1` (both copies): `Get-ReleaseVersionPins` entries take an optional `Checksums`; the
  preflight checks each file is committed and named on exactly one line beside a sha256, hashes its blob at
  HEAD, and the bump writes the hash into that cell.
- [x] `scripts/repo-config.ps1`: the skill page's pin names both house files under `Checksums`; the contract
  text (both copies) and the blueprint follow.
- [x] The pin cell put back to v5.36.0's own `house-style.css` hash, so the page names the tag's bytes again.
- [x] `SKILL.md`: the canonical-copy and release paragraphs say the cut writes the checksums.

### TEST

- [x] `check-house-style.tests.ps1`: the in-tree == pin assert is replaced by asserting the seam names both
  files; the gate and hook cases run from a plugin copy whose page pins the tree's files. 91/91, and also
  91/91 with the cell set to an unrelated hash (the between-cuts state).
- [x] `cut-release-drive.tests.ps1`: the happy path asserts both cells carry the blob's sha256, and a page
  that names a checksummed file on no line refuses before the first write. 131/131.
- [x] The first ship's gate found two more copies of the in-tree == pin assert, in
  `connector-dashboard.tests.ps1` and `dev-preview-sessionstart.tests.ps1`. Both now hold only that the
  table has a cell for each canonical file (233/233, 426/426 standalone).

### DEPLOY: fix/3636-house-style-pin-at-cut

A change to the house stylesheet or theme script no longer hand-edits the sha256 in the `house-style` skill's
pin table, and two such branches no longer conflict on that cell. The release cut now writes both checksums
from the files it tags, beside the tag it already writes
([#3636](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3636)). `Get-ReleaseVersionPins` takes an
optional `Checksums` list for this, and the cut refuses before its first write when a listed file is not
committed or is not named on exactly one line beside a sha256. Between releases the table names the previous
tag together with that tag's own checksums.

**Score:** 2

#### What makes this deploy extra special

Between releases, an installed `house-style` skill page now pins checksums that the tag beside them actually
serves. A consuming repo's session check therefore no longer flags a correct vendored copy and then fetches
the page at the tag to clear it.

**Score:** 2

#### Pull Request

House-style checksums are recomputed by the release cut, not hand-edited per branch

