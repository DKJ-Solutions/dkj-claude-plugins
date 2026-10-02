## fix/2728-update-plugins-summary-count

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

#### Issue

[#2728](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2728): the summary counted
`claude plugin update` calls, not plugins whose version moved.

### CREATE

- [x] `update-plugins.ps1` counts a clean call whose output says "already at the latest version" as
      current, not updated, and the summary names that count. Mirror kept byte-identical.
- [x] `update-plugins.tests.ps1` scenario 16: one plugin current, one moved. The shim gained
      `-CurrentNeedle` to print the CLI's no-op sentence.

### TEST

- [x] `update-plugins.tests.ps1` alone: 86 pass, 0 fail.

### DEPLOY: fix/2728-update-plugins-summary-count

`update-plugins` no longer says a plugin was updated when the CLI reported it already current. Its
summary line counted every `claude plugin update` call as an update, so a run that moved nothing still
ended with `5 plugin(s) updated`. It now counts the calls whose output says "already at the latest
version" separately, and the line reads, for example, `0 plugin(s) updated, 5 already at the latest
version, 0 failed`. If the CLI ever rewords that sentence, the count falls back to the old reading.

**Score:** 2

#### What makes this deploy extra special

Whoever runs `update-plugins` in a consumer now gets a closing line that matches the step-2 output
above it. A no-op run no longer reads like a run that updated something.

**Score:** 2

#### Pull Request

update-plugins summary counts plugins whose version moved, not calls made

The summary line counted every `claude plugin update` call as an update. A call whose output reports
"already at the latest version" is now counted apart, and test scenario 16 pins it.

