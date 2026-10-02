## fix/2701-golive-closing-rule-blank-line

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

Issue [#2701](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2701): both go-live block
composers appended the closing `---` directly under the block's last text line, which Markdown reads as
a setext H2.

### CREATE

- [x] `Format-GoLiveBlock` (`golive-block-rules.ps1`) writes a blank line before the closing rule
- [x] the CI backstop `New-AsanaPasteBlockComment` (`templates/asana-mirror.ps1`) does the same
- [x] `dkj-policy-bwj.tests.ps1` pins the blank line for both composers, and for blocks ending on the ask, the when and an English section

### TEST

- [x] `dkj-policy-bwj.tests.ps1`: 500 of 500 asserts pass
- [x] rendered through `gh api markdown` (gfm): the old shape gives the last paragraph as `<h2>`, the new one as `<p>` followed by `<hr>`

### DEPLOY: fix/2701-golive-closing-rule-blank-line

**The go-live block's last paragraph no longer renders as a big bold heading on GitHub.** Both composers
(`build-golive-block` and the `asana-mirror` CI backstop) put the closing `---` directly under the last
line of text, and Markdown reads a line followed by `---` as a heading. Each now leaves a blank line
before that rule, and a test holds both to it
([#2701](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2701)).

**Score:** 2 -- noticed in the rendered comment once pointed out; the text itself was always correct.

#### What makes this deploy extra special

A colleague reading the issue comment on a BWJ store repo now sees the closing sentence as a normal
paragraph rather than a heading. They take this in with the next plugin update, and nothing needs doing.

**Score:** 2

#### Pull Request

golive-block: a blank line before the closing rule, so the last paragraph is not an H2

