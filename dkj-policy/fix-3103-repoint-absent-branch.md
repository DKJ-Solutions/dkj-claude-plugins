## fix/3103-repoint-absent-branch

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

Cause verified (#3103): the runner appends `exit $LASTEXITCODE` to every `pwsh` step, so the
`git ls-remote --exit-code` answer 2 (branch absent, the normal first run) became the step's exit, and
`pwsh -command` reported it as 1. Reproduced locally: the same script shape exits 1.

### CREATE

- [x] `house-style-repoint.yml`, step "Is its pull request already open?": read `ls-remote`'s exit into
  `$onOrigin`, treat 0 and 2 as answers and anything else as a failure, and end the step with `exit 0`.

### TEST

- [x] The repaired shape, with the runner's appended line, exits 0 on an absent branch (local repro).

### DEPLOY: fix/3103-repoint-absent-branch

The house-style repoint runner's open-PR check no longer fails on the first run for a brand-book release:
`git ls-remote --exit-code` answering 2 for an absent branch was left in `$LASTEXITCODE`, which the
runner's appended `exit $LASTEXITCODE` turned into a failed step, so no repoint pull request was ever
opened (run 39112387739, `v0.3.0`). The step now treats 0 and 2 as answers, fails on any other exit, and
ends with an explicit `exit 0`. Only this repo's own CI is touched.

**Score:** 3

#### What makes this deploy extra special

N/A -- a CI workflow of this repo only; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

the house-style repoint workflow no longer fails when its branch is not on origin yet

