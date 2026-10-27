## fix/3602-second-issue-branch-refused

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

The reported reason did not hold: the second sweep for #3596 ran on a different machine, and its claim
DID refuse (`held`). It ran `claim-issue.ps1 3596 -Tag 2>&1 | Select-Object -Last 1; ...; new-branch.ps1`,
so the refusal was cut to its URL line and `;` ran `new-branch` anyway. The guard goes in the step that
makes the branch, which cannot be chained past.

### CREATE

- [x] `new-branch.ps1`: a fresh cut of `<prefix>/<n>-*` refuses when `origin` carries another branch for `<n>` (and its plugin mirror)
- [x] `new-branch-base.tests.ps1` (t5): refused, nothing pushed; a longer number and a resume pass
- [x] `sweep-issues` and `new-branch` skill pages say so

### TEST

- [x] `new-branch.tests.ps1`, `new-branch-base.tests.ps1`, `new-branch-document.tests.ps1` green

### DEPLOY: fix/3602-second-issue-branch-refused

`new-branch` now refuses to cut a new branch for an issue when `origin` already carries another branch
for the same issue number (`<prefix>/<n>-*`). Two sweeps had parked two independent fixes for one
issue: the second sweep's claim refused, but its command chained `new-branch` after it with `;` and
cut the claim's output to its last line, so the refusal was never read. A resume of the existing branch
still works, and the run names that branch. The `sweep-issues` skill now says to run the claim on its
own and read its whole verdict before cutting a branch.

**Score:** 2

#### What makes this deploy extra special

A sweep, or two machines working one backlog, can no longer leave you two competing fixes for one issue
to compare by hand.

**Score:** 2

#### Pull Request

new-branch refuses a second branch for an issue that already has one on origin

