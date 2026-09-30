## feat/dossier-parks-issue

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

Dave (September 30, 2026): an issue carrying a purple label always waits on something, so a sweep must
ignore it. Of the two purple labels, `awaiting-recurrence` already parked. `dossier` did not: it was
documented as "stays sweepable" (#2587). The mechanism behind that no longer holds. A dossier waits on its next instance or
its root cause, and no single repair closes it, so a sweep that picks one up finds nothing to build.

### CREATE

- [x] `dossier` joins the parking set: the sweep-issues command line, claim-issue's single-issue default (both copies), and the dashboard's PARKING_LABELS.
- [x] The prose that called a dossier sweepable is revised in CONTRIBUTING-portable.md, repo-config.ps1, claim-issue.ps1 and the claim-issue and issue-dashboard skills.

### TEST

- [x] claim-issue.tests.ps1: 560 passed, 0 failed. issue-dashboard.tests.ps1: 384 pass, 0 fail, and the parking-label asserts now cover four labels.

### DEPLOY: feat/dossier-parks-issue

A `dossier` issue is now parked like `needs-decision` and `awaiting-recurrence`. `sweep-issues` skips it,
`claim-issue <n>` warns that it is parked, and the issue dashboard shows it as Waiting.

**Score:** 2

#### What makes this deploy extra special

A repo that sweeps its issues no longer spends a pickup on a dossier that cannot be finished in one repair.

**Score:** 2

#### Pull Request

