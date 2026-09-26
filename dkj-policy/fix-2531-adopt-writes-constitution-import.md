## fix/2531-adopt-writes-constitution-import

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

Inbound #2531 (from dkj-etf-tracker): adoption never writes the `dkj-policy` constitution import into a
consumer's `CLAUDE.md`. Verified on pickup: `adopt-dkj-policy` Part 1 said *"This run does not write the
line, because it never edits a file that already exists"*. That ground had already lapsed, because the
same run appends the note-root seam to an existing `scripts/repo-config.ps1` (#1150). The detector
(`Test-ConstitutionImported`) and the line builder (`Get-ConstitutionImportLine`) already existed in
`consumer-check-lib.ps1`, and were used only for the session-start warning.

The repair goes in `adopt-workflow-folder.ps1` (Part 1), not in `bootstrap.ps1`. The line is
dkj-policy's own, and `bootstrap.ps1` belongs to the core team, which runs without dkj-policy too. The
same gap for the BWJ extension import is filed as #2532.

### CREATE

- [x] `adopt-workflow-folder.ps1` (root copy and plugin mirror): write the constitution import. It is
  inserted above the first `@`-import outside a fence, appended when there is no import yet, or written
  as a new `CLAUDE.md`. Line endings and BOM are kept. The write is skipped when the closure detector
  or a direct text match already finds the line. The dry run lists the write and does not make it.
- [x] Script header: the "strictly additive" paragraph now names both writes into existing files.
- [x] `adopt-dkj-policy` SKILL.md: the section says the run writes the line.
- [x] Filed #2532 for the BWJ extension import.

### TEST

- [x] `adopt-workflow-folder.tests.ps1`: new section, green at 133 asserts. It covers no CLAUDE.md, a
  CRLF+BOM file with imports (line placement, BOM kept, no lone LF, re-run unchanged), prose only
  (appended), already imported under the old marketplace name (untouched), and the dry run.
- [x] Manual smoke run in four fixture consumers, output inspected with `cat -A`.

### DEPLOY: fix/2531-adopt-writes-constitution-import

`adopt-workflow-folder.ps1`, Part 1 of `adopt-dkj-policy`, now writes the constitution import
(`@~/.claude/plugins/marketplaces/<marketplace>/plugins/dkj-policy/CLAUDE.md`) into the consumer's
`CLAUDE.md`. Until now it only asked for the line and left the rest to a session-start warning. The line
goes directly above the first `@`-import, is appended when the file has no import, or becomes the whole
of a new `CLAUDE.md`. The file's line endings and byte-order mark are kept. When the constitution is
already imported, under any marketplace name or through a file `CLAUDE.md` imports, nothing is written.
Before this, a consumer could run for weeks without the rules in context, because a warning does not
change what a session knows. The same gap for the BWJ extension import is filed as
[#2532](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2532).

**Score:** 3

#### What makes this deploy extra special

N/A. Adoption tooling does not reach a subscriber of a service.

**Score:** N/A

#### Pull Request

adopt-dkj-policy writes the constitution import into CLAUDE.md instead of asking for it

