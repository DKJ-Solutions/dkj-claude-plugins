## fix/2961-scaffold-feature-label

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

Inbound #2961: the `specialists-init` scaffold's prefix-table example still suggests
`Label = 'enhancement'` for `feat/`, while the source tracker renamed that label `feature` (#2764) and
`scripts/lib/branch-info.ps1` maps `feat` to `feature`. Five DKJ-Solutions consumers copied the old
example. This branch repairs the example only; whether `feature` becomes binding for every consumer is
the owner's decision and stays on #2961 (`-NoResolves`).

### CREATE

- [x] `bootstrap.ps1`: the example row reads `Label = 'feature'`, with a note citing #2764 beside the
  existing #2783 note.

### TEST

- [x] No suite pins the example text (`grep` over `scripts/tests`); the change is inside a comment, so
  the scaffold's behavior is unchanged.

### DEPLOY: fix/2961-scaffold-feature-label

The `specialists-init` scaffold's prefix-table example now suggests `Label = 'feature'` for `feat/`, the
name the source tracker uses since #2764, where it still suggested GitHub's old `enhancement`
([#2961](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2961)). Existing branch tables are
untouched: a consumer keeps whatever label its own table names.

**Score:** 2

#### What makes this deploy extra special

A repo that runs `specialists-init` from this release on is offered `feature` for its `feat/` pull
requests, the same label the source tracker uses, instead of a name the source already retired.

**Score:** 1

#### Pull Request

specialists-init scaffold suggests the 'feature' label for feat/

