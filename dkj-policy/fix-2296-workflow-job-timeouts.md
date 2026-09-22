## fix/2296-workflow-job-timeouts

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

Cap every job in `.github/workflows/` and every job this workflow scaffolds into a consumer. Values
read off run history rather than picked; the one on `suites` picked against `ship-pr`'s own
registration wait, so a wedge goes red while the shipping session is still listening.

- [x] Verify the report against the tree: zero `timeout-minutes` across all nine workflow files.
- [x] Measure the real job durations (19-20 most recent successful runs per workflow) instead of
      quoting the issue's own paragraph.

### CREATE

- [x] `.github/workflows/`: a cap on all eleven jobs across the nine files, with the derivation in a
      banner above `jobs:` in `ci.yml` and a pointer to it from the rest.
- [x] `scripts/task/adopt-ci-floor.ps1`: caps on the four jobs it composes for a consumer -- the fold
      runner, the resolves runner, the scheduled repo-settings runner, and the skeleton `ci.yml`.
- [x] `scripts/task/adopt-workflow-folder.ps1`: caps on the branch-entry and always-on-budget gates.
- [x] `scripts/task/adopt-shopify-floor.ps1` and the `asana-mirror.yml` template: the two scaffolded
      runners that sit outside the three the issue named, reached by the same argument.
- [x] Mirrors rebuilt with `scripts/sync/build-shared-scripts.ps1`.
- [x] `.claude/specialists/lenses/specialist-05-15-lens.md`: the layer distinction recorded where
      Sylvester's other CI runners are described.

### TEST

- [x] `scripts/tests/workflow-timeouts.tests.ps1` -- new suite, 54 asserts, all green.
- [x] `check-plugin-integrity.ps1` green on the tree (the full suite gate runs inside `open-pr`, so it
      is not a step here).

### DEPLOY: fix/2296-workflow-job-timeouts

Every job in `.github/workflows/` now declares `timeout-minutes`, and so does every job this workflow
scaffolds into a consuming repo. Until now none did, so a wedged job ran to GitHub's six-hour default --
and the damage is not a red check but a check that never registers at all: `lint-en-tests` `needs:` the
suite shards, so a wedged shard leaves the required check unreported, which reads as *still running* to
`ship-pr`, to the ruleset and to anyone looking at the pull request. Measured on run 35728958033, where
`suites (2)` sat in progress for 38 minutes against a normal ~13 and a local re-run of the identical
shard that finished every suite in 344s; the branch could not merge until somebody cancelled the job by
hand, which itself took about eight minutes to land.

The caps are read off run history rather than chosen: 10 on `lint` (max 1.5m), 5 on the summary job
(max 0.1m), 10 on each short runner (all under 1m), 60 on the two agent jobs, whose runtime is the
model's work rather than a script of this repo's. The one on `suites` is picked against a second number
instead -- `ship-pr`'s required-check registration wait is also 1800s, so a cap of 30 or more would time
the job out at the same moment the shipping session gives up and teach it nothing. At 25, roughly twice
the worst shard ever observed, the shard goes red and `ship-pr` reads a failed check with a job log
behind it.

This does not replace the in-process suite bound and is not another argument about its constant.
`$script:GateSuiteTimeoutSeconds` reaps a wedged child *with an attribution*, and here it never fired --
so whatever wedged sat below the level a bound inside the process can reach.

**Score:** 3

#### What makes this deploy extra special

A consumer's scaffolded runners get the same treatment, which is the half no gate in this repo could
ever see: a wedge in an adopted `branch-entry`, `fold-on-merge`, `verify-resolved`, `repo-settings`,
theme-check or `asana-mirror` job blocks that repo's own required check with nobody watching, and the
write-capable ones would spend six hours holding a standing credential. Existing consumers pick the caps
up on their next `adopt-dkj-policy` run; nothing already scaffolded changes on its own.

**Score:** 2

#### Pull Request

Every CI job declares timeout-minutes, so a wedged job cannot hold the required check for six hours
