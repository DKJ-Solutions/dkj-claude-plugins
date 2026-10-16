## fix/3062-extension-may-close-act-only

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

#3062, decided by Maikel on October 16, 2026 (option 1): the core yields by permission. The core says an
extension may close an act-only issue instead of parking it under `awaiting-action-dev`, and
`bwj-development`'s #3059 rule then extends the core rather than contradicting it.

### CREATE

- [x] `CONTRIBUTING-portable.md`: the `awaiting-action-dev` paragraph permits an extension to close an act-only issue, and names `bwj-development` as the one that does
- [x] `bwj-development/WORKFLOW-portable.md`: the #3059 paragraph no longer calls the conflict open, and it cites the core's permission
- [x] `sweep-issues` SKILL.md: the parking step says an installed extension's close applies in place of `awaiting-action-dev`

### TEST

- [x] Text-only change. The gates run inside `ship-pr`.

### DEPLOY: fix/3062-extension-may-close-act-only

The core's `CONTRIBUTING-portable.md` now permits an extension to close an act-only issue as completed,
with a record of the act and of who performs it, instead of parking it under `awaiting-action-dev`
([#3062](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3062), Maikel, October 16, 2026).
`bwj-development` uses that permission through its #3059 rule. That rule had contradicted the core, and
since the core wins it would have lost. A repo without such an extension still parks the issue. The
`sweep-issues` skill's parking step says the same.

**Score:** 2

#### What makes this deploy extra special

Nothing changes in how either kind of repo works. What it prevents: a session in a `bwj-development`
repo reads both pages, applies "the core wins" and parks an act-only issue under `awaiting-action-dev`,
where the extension says to close it. That has not happened yet.

**Score:** 1

#### Pull Request

An extension may close an act-only issue instead of parking it

