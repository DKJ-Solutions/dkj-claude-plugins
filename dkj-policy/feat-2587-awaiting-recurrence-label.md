## feat/2587-awaiting-recurrence-label

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

Option B from #2587, as decided by the owner in the issue thread. It adds a separate parking label for an issue that waits on
its first reproducible recurrence, and `dossier` stays sweepable. The shape follows #2519 (`needs-decision`, PR #2524).
The name `awaiting-recurrence` was left open by the decision, so I took the issue's own example.

### CREATE

- [x] `Get-TriageLabels` (repo-config) and `adopt-triage-labels.ps1`'s built-in fallback carry a seventh record, `awaiting-recurrence` (`EDEDED`)
- [x] `claim-issue.ps1`'s single-issue default `-SkipLabel` and `sweep-issues`' command line skip it
- [x] `CONTRIBUTING-portable.md` documents it beside `dossier`/`needs-decision`; the claim-issue skill, the scripts README, the contract record and Derek's lens follow
- [x] Mirrors regenerated (`build-shared-scripts.ps1`) and the blueprint rebuilt (`build-config-blueprint.ps1`)
- [x] The label created on this repo's tracker and set on #2572, the issue it was built for

### TEST

- [x] Suites `adopt-triage-labels`, `repo-config`, `script-contract`, `claim-issue` and `config-blueprint` updated and green
- [x] `check-plugin-integrity.ps1` 0 errors; `check-script-contract.ps1` 0 errors

### DEPLOY: feat/2587-awaiting-recurrence-label

`adopt-triage-labels` now also prints a `gh label create` line for `awaiting-recurrence`, a parking label
for an issue whose only remaining step is its first reproducible occurrence. `claim-issue <n>` skips it
by default next to `needs-info` and `needs-decision`, and `sweep-issues` skips all three.
`CONTRIBUTING-portable.md` says when to set the label and when it comes off. It is not `dossier`: a
dossier collects a problem that demonstrably recurs, so it stays sweepable.

Tier 0 is scored for a session running a sweep. An n=1 flake with nothing left to build (#2572) was picked
up four times in one day, and each pickup ended in *nothing to do*.

**Score:** 2

#### What makes this deploy extra special

N/A. It is a label definition, a filing convention and a default skip list, and nothing reaches a
subscriber.

**Score:** N/A

#### Pull Request

An awaiting-recurrence parking label for an issue waiting on its first reproducible occurrence

