## fix/2622-branch-entry-head-ref-env

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

#2622, verified in the tree: `branch-entry.yml` and `reusable-branch-entry.yml` spliced
`${{ github.head_ref }}` into their `run:` script, so a branch name carrying `$(...)` or a quote would be
expanded into code before pwsh parsed it. Repair as the issue proposes: `HEAD_REF` (and `PR_NUMBER`) under
`env:`, read as `$env:HEAD_REF`. `check-branch-entry.ps1`'s own "pass the head ref explicitly" hint
recommended the spliced form, so it now names the safe one.

### CREATE

- [x] both workflows: the head ref and PR number arrive through `env:`
- [x] `check-branch-entry.ps1` (and its dkj-policy mirror): the hint prescribes `$env:HEAD_REF`, not the spliced expression

### TEST

- [x] `branch-entry-gate.tests.ps1`: neither workflow splices a head ref into any `run:` block, and both read `$env:HEAD_REF`; the same regex flags both files as they stand on `main` -- 64 asserts green
- [x] `adopt-workflow-folder.tests.ps1`: its "passes -Pr" assert on the reusable workflow now reads `-Pr $env:PR_NUMBER` with `PR_NUMBER` under `env:` -- 148 green

### DEPLOY: fix/2622-branch-entry-head-ref-env

The branch-entry CI gate now receives the pull request's head branch through an environment variable
instead of having it pasted into the script it runs. A branch name is chosen by whoever opens the pull
request, and a pasted one carrying `$(...)` or a quote would have run as code on the runner (#2622).

**Score:** 1

#### What makes this deploy extra special

Every consumer that calls `reusable-branch-entry.yml` at `@main` gets the fix at once, before any release.
It closes a script-injection path on the runner that has not been used: a pull request whose branch name
runs a command.

**Score:** 1

#### Pull Request

branch-entry gates pass the head ref through env:, not spliced into run:
