## fix/2667-always-on-strip-html-comments

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

#2667: `measure-always-on` counts block-level HTML comments as loaded bytes, but the harness strips them
before a document reaches the session. The reason was verified in this session: the context this session
received holds `SPECIALISTS.md` and the orchestrator persona **without** their six comment blocks.

The repair belongs in the row, not in one report. `always-on-sessioncheck`, the budget gate and
`measure-always-on` all read `Get-AlwaysOnDocuments`, so the walk now measures what loads, and every
consumer follows without its own change.

- Only a whole-line block comment outside a code fence is stripped: `<!--` at the start of a line,
  `-->` at the end of one. The shapes that were not observed (text after `-->`, a mid-line opening, an
  unclosed comment) still count as loaded, because undercounting is the direction this measurement must
  not err in.
- `Bytes`, `LfBytes`, `TreeBytes` and `TreeLfBytes` leave the stripped lines out, and `CommentBytes`
  reports them, so `Bytes + CommentBytes` is the file length.
- `Get-DocumentSections` keeps tiling the whole file by default and gets `-LoadedOnly` for the report.

### CREATE

- [x] `Get-LoadedByteLines` + `Measure-LoadedBytes` in `measure-context-lib.ps1`, used by the walk
  and by `Get-DocumentSections -LoadedOnly`
- [x] `measure-always-on.ps1`: the provenance line names the unit, a new block lists the stripped
  comment bytes per document, and the section table uses `-LoadedOnly`
- [x] Mirrors synced (`plugins/dkj-policy/scripts/`, `dkj-policy-bwj/scripts/lib/`)

### TEST

- [x] `measure-always-on.tests.ps1` (Tycho): which comment shapes are stripped and which are kept,
  `Bytes + CommentBytes` against the file length, the loaded sections against the row, a stripped CRLF
  line not counted as a loaded line-end, and the report block. The two live-repo asserts now reconcile
  the row against the file through `CommentBytes`. 106/106
- [x] `always-on-budget.tests.ps1` 135/135 and `measure-session-start.tests.ps1` 198/198, unchanged
- [x] Live run: 59,414 B across 6 documents. 1,016 B of comments named (522 in `SPECIALISTS.md`, 494
  in the persona), matching the issue's 1,010 B plus the comment lines' own line endings
- [x] `open-pr` runs the lint gate and all suites before the push (enforced by the gate itself)

### DEPLOY: fix/2667-always-on-strip-html-comments

The always-on measurement now counts what a session actually loads. Block-level HTML comments
(`<!-- ... -->` on lines of their own) are on disk but are stripped by the harness before the document
reaches the session. `measure-always-on`, the always-on budget gate and `always-on-sessioncheck` still
counted them, and overstated this repo's path by about 1 kB. The comment bytes are now left out of every
size the walk reports, and `measure-always-on` lists them per document in a block of their own.

**Score:** 2

#### What makes this deploy extra special

A consumer's always-on figure and budget headroom grow by whatever their always-on documents hold in
HTML comments, so a comment is now a free place for rationale on the always-on path. For a repo with no
such comments nothing changes.

**Score:** 1

#### Pull Request

measure-always-on and the budget gate leave out the HTML comments the harness strips
