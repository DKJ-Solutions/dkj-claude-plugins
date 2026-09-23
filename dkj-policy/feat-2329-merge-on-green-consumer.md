## feat/2329-merge-on-green-consumer

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

Add a workflow template to adopt-ci-floor.ps1 so a consumer gets the sweep that reads merge-when-green, plus its inventory entry and tests.

#### What the issue did not say

The issue's "the ship must run in the consumer's tree" was true one layer further in than it named:
`pick-merge-on-green.ps1` resolved its root as `$PSScriptRoot\..\..`, which in a consumer is the checkout
of the SOURCE tree, so its `Get-RepoName` read would have swept the source repo's pull requests. The
picker needed a dual-context root and a mirror, not only a template beside it.

### CREATE

- [x] `scripts/ci/pick-merge-on-green.ps1`: source-repo guard plus `Resolve-RepoRootOrFail`, so it judges the tree `CLAUDE_PROJECT_DIR` names
- [x] registered as a shared script (`shared-scripts-lib.ps1`) and mirrored to `plugins/dkj-policy/scripts/ci/`
- [x] `adopt-ci-floor.ps1`: a fourth runner, `merge-on-green.yml`, derived from the source's own; `workflow_run` names read off the consumer's pull_request workflows' top-level `name:`, left out where none is usable; the plugin checkout excluded via `.git/info/exclude` so the fold runs in place
- [x] the `Pull requests: Read and write` scope note, printed when the file is placed
- [x] `Get-AdoptionInventory` (`script-contract-lib.ps1`): the fourth `Places` entry with its `Gained` note
- [x] `adopt-dkj-policy` Part 3 page and Sylvester's lens updated

### TEST

- [x] `adopt-ci-floor.tests.ps1`: section 2e -- plugin paths exist, both steps carry `CLAUDE_PROJECT_DIR`, token split, branch only through `env:`, exclude line, wake list from the tree, the unnamed-workflow case, the scope note firing alone; the trunk and the skeleton name followed (204 pass)
- [x] `script-contract.tests.ps1`: the file counts moved from 3 to 4 (388 pass)
- [x] `merge-on-green-lib`, `shared-scripts`, `pin-parity`, `connectors` suites green

### DEPLOY: feat/2329-merge-on-green-consumer

A consumer now gets the merge-on-green sweep. `adopt-ci-floor` places a fourth runner,
`.github/workflows/merge-on-green.yml`, that reads the `merge-when-green` label `ship-pr` already sets on
a CI refusal and hands a green pull request to the plugin's own `ship-pr.ps1`. So the refusal's promise
that a sweep will finish the merge is true outside the source repo too. The runner wakes on the
consumer's own CI workflows (read off their top-level `name:`), a half-hourly schedule and
`workflow_dispatch`. It acts on the consumer's workspace through `CLAUDE_PROJECT_DIR`, and
`pick-merge-on-green.ps1` now travels as a mirrored script with a dual-context root. Until now it
resolved its root from its own location, which in a consumer would have swept the source repo's pull
requests. The script-contract session check reports the runner as a gained file wherever the floor was
built before it.

**Score:** 3

#### What makes this deploy extra special

The runner uses the consumer's existing `FOLD_PUSH_TOKEN`, and that token needs one scope more than the
fold runner's: `Pull requests: Read and write`. A merge made with the job-scoped token starts no workflow
runs, so it would silence the consumer's CI, fold and resolves runners in one go. Without the scope the
merge fails with a 403, loudly, and the run says so when it places the file.

**Score:** 3

#### Pull Request

The merge-on-green runner now reaches a consumer through adopt-ci-floor

