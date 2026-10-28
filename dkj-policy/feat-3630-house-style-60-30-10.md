## feat/3630-house-style-60-30-10

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

The owner's 60-30-10 grouping (#3630), as revised the same day: Paper is the 60%, Primary the 30%, the text
(`--fg-*`) the 10%. No colour is added; only the grouping is written down, in the house-style README. A first
take that added a per-theme `--accent` as the 10% was withdrawn when the owner revised the model; it is kept as
a patch outside the tree, not on this branch.

### CREATE

- [x] README: the 60-30-10 table (Paper 60, Primary 30, Text 10) at the head of "What it holds"

### TEST

- [x] the owner confirms the grouping ("ship it", October 28, 2026)

### DEPLOY: feat/3630-house-style-60-30-10

The house-style README now reads a theme's colours by the 60-30-10 rule
([#3630](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3630)): the paper (`--paper-*`) is the 60%,
the theme's colour (`--primary`, with `--muted`) the 30%, and the text (`--fg-*`) the 10%. No token or value
changes; it is the grouping a page and a repo layer are held to.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

House style: read a theme's colours by the 60-30-10 rule (Paper 60, Primary 30, Text 10)

Plugins: dkj-policy
