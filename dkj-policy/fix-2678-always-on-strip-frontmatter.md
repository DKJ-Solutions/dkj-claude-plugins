## fix/2678-always-on-strip-frontmatter

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

#### Parked on a prerequisite -- PR #2679 (fix/2667)

The repair goes in `Get-LoadedByteLines` (`scripts/lib/measure-context-lib.ps1`), and on October 1,
2026 that function existed only on `fix/2667-always-on-strip-html-comments` (PR #2679, open). Dave
chose to wait for #2679 to merge rather than stack on it. **Resume by merging `origin/main` into
this branch once #2679 has landed**, then build on its `Stripped` column.

Cause verified: the installed Chris persona opens with a `---`/`id: 01`/`group: 01`/`---` block on
disk, and the session that claimed this issue received the persona starting at `# Chris`.

### CREATE

- [x] Once #2679 has merged: merge `origin/main` in
- [x] Mark a leading `---` ... `---` block as `Stripped` in `Get-LoadedByteLines`, next to the comment rule
  -- the comment scan starts after the block; an unclosed block, a late `---` pair and the blank line
  after the block stay counted. The column keeps its name, `CommentBytes`; `measure-always-on`'s labels
  now say "HTML comments and frontmatter".
- [x] Test: a frontmatter fixture lands in `Stripped`, not `Bytes`; a `---` rule mid-document stays counted
  -- plus a late pair, an unclosed block, a CRLF block, and a fence-looking value inside the block.

### TEST

- [x] `measure-always-on.tests.ps1`: 112 passed, 0 failed.
- [x] On this repo: the stripped column is now 1,066 B -- the persona's 25 B frontmatter plus the
  orchestrator lens's 25 B, a tree file the issue had not counted. This session received both without
  it, and a paths-scoped rule from `.claude/rules/` too, so the rule is not one install's quirk.

### DEPLOY: fix/2678-always-on-strip-frontmatter

The always-on measurement now leaves out a document's leading YAML frontmatter (a `---` ... `---` block
opening the file), which the harness strips before the document reaches a session, just like the
block-level HTML comments
([#2678](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2678)). `measure-always-on`, the
always-on budget gate and `always-on-sessioncheck` counted it, overstating this repo's path by 50 B.

**Score:** 1

#### What makes this deploy extra special

A consumer whose always-on documents carry frontmatter gains that many bytes of budget headroom; for a
repo with none, nothing changes.

**Score:** 1

#### Pull Request

measure-always-on and the budget gate leave out the frontmatter the harness strips

