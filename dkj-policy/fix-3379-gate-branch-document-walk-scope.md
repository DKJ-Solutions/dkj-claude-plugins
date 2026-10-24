## fix/3379-gate-branch-document-walk-scope

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

Issue #3379: the local gate's `Get-AffectedSuiteSelection` matched the branch's own document against
every `'*.md'` walk scope, so five slow suites ran on every branch. Leave the document out of the
walk-scope match only (the reference graph still sees it), the local half of #3370.

Checked before excluding it: none of the five suites reads a branch document. `cut-release-guardrail`
reads root docs only, `subagent-shared` personas and agent defs, `measure-always-on` the always-on
closure, and neither `check-script-contract.ps1` nor `connector-sessioncheck.ps1` resolves one.

### CREATE

- [x] `Get-AffectedSuiteSelection -BranchDocument`, skipped in the walk-scope match only (`scripts/lib/gate-lib.ps1`, mirror synced)
- [x] `Get-GateBranchDocument` resolves it through `Resolve-BranchFilePath`, and the test gate passes it
- [x] The dev server's /test-gate page passes it too, and its CI line drops the document as CI does (#3370)

### TEST

- [x] `affected-suites.tests.ps1`: four asserts (document alone scopes nothing, whatever its case or slashes; another `.md` still does; empty name removes nothing) -- 167 pass; `dev-pages.tests.ps1` 311 pass
- [x] The issue's case remeasured: `showcase.css` + the branch document now selects `ci-suite-selection-lib` and `dev-pages`, against seven before

### DEPLOY: fix/3379-gate-branch-document-walk-scope

open-pr's local test gate no longer counts the branch's own development document as a change to any
suite's walk scope, so a branch that changes only a stylesheet runs 2 suites instead of 7 (89s down
to about 23s on the measured case). A suite that names the document itself is still selected. The dev
server's /test-gate page shows the same selection, and its CI line now drops the document as CI does.

**Score:** 2

#### What makes this deploy extra special

A consumer whose suites declare a `'*.md'` walk scope gets the same saving on every branch.

**Score:** 1

#### Pull Request

Local test gate leaves the branch document out of walk scopes

Plugins: dkj-policy

