## fix/2463-resolves-refuses-dossier

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

Resolves #2463. The issue's open question, whether this is a second shape in the matcher seam or a seam of
its own, is answered with neither: it is a check of its own and not seam-gated at all. The matchers are one
repo's carve-out and default to nothing, while the dossier rule is shared.

### CREATE

- [x] `pr-issues-lib.ps1`: `Get-DossierLabelName` + the pure `Get-DossierClosingFindings`
- [x] `issue-state-lib.ps1`: `Get-IssueBodySet` asks for `body,labels` and returns a `Labels` map
- [x] `open-pr.ps1`: the per-issue read runs whenever the PR closes anything, and a dossier among the closing set refuses before the push
- [x] `CONTRIBUTING-portable.md` step 1: the rule now says what enforces it, and what is still yours (commit messages)
- [x] plugin mirrors of the three scripts synced

### TEST

- [x] `pr-issues.tests.ps1`: rule asserts (label, case, key spelling, unread, sorting) and call-site asserts; the cost-model assert moved deliberately. 1136/1136
- [x] `native-capture.tests.ps1`: bounded-site count unchanged at 83. 352/0
- [x] Live: `Get-IssueBodySet` on #2454 + #2463 read their labels, and the rule flagged #2454 alone

### DEPLOY: fix/2463-resolves-refuses-dossier

`open-pr` now refuses a PR that would close an issue carrying the `dossier` label, whether the close
comes from `-Resolves` or from a `Closes` already on the PR body. The rule that a repair of one instance
does not close a collecting issue (#2462) used to hold only as long as somebody remembered it. The
refusal names `-NoResolves` as the way through. The check is shared rather than seam-gated, so every PR
that closes anything now pays one `gh issue view` per closing issue, asking for the body and the labels
in one call. A closing keyword in a commit message is still not read by any gate.

Tier 0 is scored for a session shipping a repair of one instance of a dossier.

**Score:** 3

#### What makes this deploy extra special

N/A. It is a workflow gate and nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

open-pr refuses -Resolves on an issue carrying the dossier label

