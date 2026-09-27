## fix/2555-unanswered-decide-seams

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

### CREATE

- [x] `check-script-contract` rolls every optional `decide` seam this repo leaves undefined into one non-counting `[UNANSWERED]` line; the per-record `[INFO]` lines are unchanged
- [x] `script-contract-sessioncheck` forwards that line and prints its own verdict instead of `in sync`
- [x] This repo states its four `decide` seams whose fallback is its answer (`Get-TestCommands`, `Get-ReleasePageMasthead`, `Get-ResolvesExemptMatchers`, `Get-DeclinedAdoptions`); blueprint regenerated, plugin mirror synced

### TEST

- [x] `script-contract.tests.ps1`: 401 pass -- new scenarios for one and two unanswered seams, a missing `copy` seam (not rolled up), and the hook's verdict; three info counts moved down by four
- [x] `config-blueprint.tests.ps1`: 219 pass -- undeclared count 10 to 6, plus an assert that the source leaves no `decide` record unstated

### DEPLOY: fix/2555-unanswered-decide-seams

`check-script-contract` now tells an unanswered `decide` seam apart from a harmless optional one. A `decide` seam states what the repo IS, so its fallback is an answer nobody chose; until now it printed the same `[INFO]` as a `copy` seam, and the session check called the repo `in sync`. It now adds one non-counting `[UNANSWERED]` line naming every such seam, and the session check forwards it in place of the in-sync verdict. Exit codes and tallies are unchanged. This repo now states the four `decide` seams it used to leave undefined on purpose, each returning its fallback, so a considered answer can be told from an unasked one here too ([#2555](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2555)).

**Score:** 3

#### What makes this deploy extra special

A repo on this workflow now sees, at session start, the questions only it can answer that it never has -- named in one line, such as `Get-ReleaseAudienceTier`, whose silence costs every changelog entry two empty tier sections. Answering each one, with any value including the fallback, clears the line.

**Score:** 3

#### Pull Request

check-script-contract: report unanswered 'decide' seams as their own class, and stop the session check calling that state in sync

