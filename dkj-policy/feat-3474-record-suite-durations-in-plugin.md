## feat/3474-record-suite-durations-in-plugin

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

The owner's decision on #3474 (October 26, 2026): build the writer and the CI contract; the path seam is
not part of it.

### CREATE

- [x] `record-suite-durations.ps1` resolves its root dual-context and takes `-Machine` (kept from the file when omitted) instead of this repo's runner hard-coded
- [x] it and `suite-durations-lib.ps1` registered as shared pairs and mirrored into `dkj-policy`
- [x] the `record-suite-durations` skill page, with the CI contract; scripts README, ADOPTION list, `measure-suites` page and the hub's Test gate texts point at it

### TEST

- [x] `-DryRun` against PR run 40241168736 reads the table (pool total 7537s, nothing written)

### DEPLOY: feat/3474-record-suite-durations-in-plugin

`record-suite-durations` now ships in `dkj-policy`, with a skill page of its own
([#3474](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3474)). It writes
`scripts/tests/suite-durations.json` from CI runs, and until now only this repo could run it. The skill page
states what a repo's CI must do for it to read the runs: keep its suites in `scripts/tests`, run them through
the plugin's gate, which prints the per-suite table, and let `gh run view --log` read the log. The runner's
description is no longer hard-coded to this repo's: `-Machine` names it, and a refresh keeps the value already
in the file. `suite-durations-lib.ps1` travels with it; `measure-suites` stays here.

**Score:** 3

#### What makes this deploy extra special

A repo using this workflow can fill the hub's Test gate page, which so far showed its empty state everywhere
but here: run the `record-suite-durations` skill on two or three pull-request runs and commit the file.

**Score:** 3

#### Pull Request

record-suite-durations ships in dkj-policy, with the CI contract it reads

