## feat/2885-store-admin-prerequisites

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

Issue #2885, decided by Dave on October 7, 2026: a store-admin prerequisite is recorded as a checklist
on the issue itself. `build-golive-block` refuses to post while a box is open (`-Force` past it), and
the preview handover warns.

- The marker is `<!-- store-admin-prerequisites -->`. Only the task-list lines after it count, in the
  body or in any comment.
- The check reads the issue only for `-OutFile` (the handover page's run, which warns) and `-Post`
  (which refuses). A print-only run stays offline.
- An unreadable issue refuses the post, for the same reason the duplicate check does.

### CREATE

- [x] `golive-block-rules.ps1`: `Get-StoreAdminPrerequisiteMarker` and `Get-StoreAdminPrerequisites`
  (pure)
- [x] `build-golive-block.ps1`: one `gh issue view --json body,comments` read for `-OutFile`/`-Post`;
  `-OutFile` warns about each open item, and `-Post` refuses on an open or unreadable checklist before
  the duplicate check, unless `-Force`
- [x] Docs: `WORKFLOW-portable.md` gains the checklist's section and template, `PREVIEW-portable.md`
  the warning above the cards, and the `golive-block` skill step 8 and the `-Force` row
- [x] Review: Victor #19, Sebastian #23, Edith #17. Fixed from it: the checklist ends at the next
  heading or HTML comment, the marker is matched ordinally, a `gh` that throws reads as unreadable rather
  than ending the `-OutFile` run, and the parser fails closed (a bare, numbered, quoted or unspaced box
  counts, and so does a marker with no box under it). One `-Force` for both checks stays, as the
  owner's decision names it

### TEST

- [x] `bwj-development.tests.ps1`: the parser (only the boxes after the marker count, `x`/`X` and
  `-`/`*` bullets, no marker or no text declares nothing), static asserts on the driver's read and
  refusal order, the checklist's end and the fail-closed variants, and an end-to-end run through a stand-in `gh` on PATH: `-OutFile` exits 0 and names
  only the open item, and `-Post` exits 1 with "Nothing posted" -- 348 passed
- [x] Live run against this repo's #2885 with `-OutFile` (no marker, so no warning, exit 0), and against
  a repo that does not exist (warns that the issue is unreadable, exit 0)

### DEPLOY: feat/2885-store-admin-prerequisites

`build-golive-block` now checks the store-admin prerequisites an issue records
([#2885](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2885)). These are steps a change
needs on the store rather than in the theme, such as a metafield definition, a menu or a setting. They
go on the issue as a checklist under `<!-- store-admin-prerequisites -->`. `-Post` refuses while a box
is open or the issue cannot be read, and `-Force` gets past it. `-OutFile`, which the preview handover
page embeds, warns and names the open items. A print-only run reads nothing. `WORKFLOW-portable.md`
carries the checklist's template, and `PREVIEW-portable.md` has the handover page name the open items
above the cards.

**Score:** 3

#### What makes this deploy extra special

A BWJ store repo can no longer send a go-live block that asks a colleague to review a feature whose
store setup is missing. In `xoxowildhearts` a block went out for a metafield whose definition nobody
had created. A session that finds such a step writes it on the issue, and the block waits until it is
ticked.

**Score:** 3

#### Pull Request

golive-block checks store-admin prerequisites on the issue
