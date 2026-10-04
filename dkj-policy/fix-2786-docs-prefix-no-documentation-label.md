## fix/2786-docs-prefix-no-documentation-label

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

#2786 asked whether Dave's #2783 rule (an issue is always a `feature` or a `bug`, no `documentation`
label) reaches past the BWJ stores. #2783 states it as "vanaf nu altijd", and Dave asked for #2786 to be
fixed, so it does: this repo's `docs/` prefix answers no label, as the BWJ table already does.

### CREATE

- [x] `scripts/lib/branch-info.ps1`: the `docs` row answers `Label = $null`, docstring says why
- [x] `scripts/tests/branch-info.tests.ps1`: the docs assert follows
- [x] `specialists-init/bootstrap.ps1`: the commented example table proposes no `documentation` label (docs and chore)

### TEST

- [x] `branch-info.tests.ps1` green; the full gate runs in open-pr

### DEPLOY: fix/2786-docs-prefix-no-documentation-label

A `docs/` pull request in this repo now goes out without a label, because the `documentation` label is
retired here too: an issue is always a `feature` or a `bug`
([#2786](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2786), following
[#2783](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2783)).

**Score:** 1

#### What makes this deploy extra special

For a new consumer running `specialists-init`: the commented example prefix table no longer proposes a
`documentation` label for `docs/` or `chore/` branches, so it no longer suggests the label #2783
retired.

**Score:** 1

#### Pull Request

This repo's docs/ prefix stops labelling PRs 'documentation'

