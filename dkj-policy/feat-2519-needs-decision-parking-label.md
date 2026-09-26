## feat/2519-needs-decision-parking-label

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

Owner chose a separate needs-decision label (not needs-info). Next: claim-issue/sweep default skips it, filing rule prescribes it.

### CREATE

- [x] Create the live `needs-decision` label on this tracker (`BFD4F2`)
- [x] Add it to `Get-TriageLabels` and `adopt-triage-labels`' built-in fallback, contract record and blueprint
- [x] `claim-issue`'s single-issue route skips `needs-info` and `needs-decision` by default; `sweep-issues` passes both
- [x] Write the filing rule in `CONTRIBUTING-portable.md` step 1, and update the claim-issue and sweep-issues pages, the scripts README and Derek's lens
- [x] Widen the test's literal extractor to read a doubled quote, which the new description is the first to carry

### TEST

- [x] `adopt-triage-labels`, `repo-config`, `script-contract`, `claim-issue` and `config-blueprint` suites green locally

### DEPLOY: feat/2519-needs-decision-parking-label

`adopt-triage-labels` now also prints a `gh label create` line for `needs-decision`, a parking label for an
issue that ends in the owner's choice. `claim-issue <n>` skips it by default next to `needs-info`: it warns
that the issue is parked instead of saying the work starts. `sweep-issues` skips both.
`CONTRIBUTING-portable.md` now says to set the label when such an issue is filed. It is a separate
label because `needs-info` already means *blocked on the submitter* in `dkj-policy-bwj`, where it moves
the mirrored Asana card to the blocked column.

Tier 0 is scored for a session filing an issue that ends in a decision, or picking one up. Until now the
filing rule named no label for it, so the decision stayed in prose and a pickup went straight past it.

**Score:** 2

#### What makes this deploy extra special

N/A. It is a label definition, a filing convention and a default skip list, and nothing reaches a
subscriber.

**Score:** N/A

#### Pull Request

A needs-decision parking label for an issue awaiting the owner's choice

