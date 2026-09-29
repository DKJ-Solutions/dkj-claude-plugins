## fix/2616-placed-workflows-linux-runners

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

#2616 is the half #2488 left out: `merge-on-green`, and the gates the floor and `adopt-dkj-policy` place
(`branch-entry` / `reusable-branch-entry`, `always-on-budget` / `reusable-always-on-budget`,
`unfolded-entry`), move to `ubuntu-latest` + `pwsh` with #2488's shim. ci.yml's own tree-judging shards
stay on Windows, because the whole tree is judged there.

#### How each move is proved

- `branch-entry.yml` and `always-on-budget.yml` are `pull_request` gates, so this PR's own run on Linux
  proves them. Their suites also join the Linux leg.
- The two reusable copies run the same scripts from `.workflow-scripts`, so the proof carries over. A
  consumer calling them at `@main` switches at the merge.
- `unfolded-entry.yml` runs on a trunk push. `check-unfolded-entry.ps1` is already pinned on Linux by
  `unfolded-entry-gate` in the leg, and the first push after the merge is its live run.
- `merge-on-green.yml` runs the default branch's copy, so it cannot be proved here. No suite runs
  `ship-pr` end to end, and a pre-merge probe of the full ship would wait on the CI run it is part of.
  The proof is after the merge: a `workflow_dispatch` run (the pick step alone when nothing is armed),
  then the first sweep that ships an armed PR. The failure is bounded: a Linux ship that breaks after its
  merge leaves the fold to `fold-on-merge` and the resolves to `verify-resolved`, both on Linux since #2488.

### CREATE

- [x] The five gate workflows: `runs-on: ubuntu-latest`, the shim step, `shell: pwsh`, headers rewritten.
- [x] `merge-on-green.yml`: the same move, the shim ahead of every step that holds a token, and a header
  saying how it is proved.
- [x] `adopt-ci-floor.ps1` (source and plugin mirror): the merge-on-green template moves too, the
  cost section says all four runners are on Linux, and the three other templates stop saying it stays.
- [x] The headers of `fold-on-merge`, `verify-resolved` and `repo-settings` stop saying merge-on-green stays.
- [x] ci.yml's Linux leg also runs `branch-entry-gate` and `always-on-budget`.

### TEST

- [x] Windows PowerShell 5.1, locally: `adopt-ci-floor` 271/0, `ci-shard` 92/0, `merge-on-green-lib`
  236/0, `branch-entry-gate` 58/0, `always-on-budget` 135/0, `workflow-timeouts` 66/0, `ci-fold-lib`
  75/0, `shared-scripts` 1112/0, `check-plugin-integrity` 0 errors
- [x] The Linux half is wired into the required check, so the merge waits on it: `linux-runner-path` now runs `branch-entry-gate` and
  `always-on-budget` under pwsh on ubuntu-latest, and this PR's own `Branch entry` and `Always-on budget`
  runs are the gates on Linux. The dispatch run after the merge is in the PLAN above.
- [x] Pre-PR review, with Victor, Sebastian and Edith working in parallel. There was no blocking finding.
  The stale comments were repaired here: ci.yml's banner, a reflow in merge-on-green.yml, and
  merge-on-green-lib's filesystem note. Two findings outside the branch were filed. #2621: the fold reads
  the branch document through a symlink on a Linux runner. That exposure exists since #2488, and this
  branch extends it to merge-on-green. #2622: the branch-entry gates splice `head_ref` into `run:`, which
  predates this branch.

### DEPLOY: fix/2616-placed-workflows-linux-runners

`merge-on-green` and the gates `adopt-dkj-policy` places now run on `ubuntu-latest` under `pwsh`, with
#2488's one-line shim that makes `powershell` resolve to `pwsh`. The gates are `branch-entry`,
`always-on-budget` and `unfolded-entry`, including the reusable copies consumers call. That covers this
repo's copies and the `merge-on-green` template `adopt-ci-floor` places. A consumer calling the reusable
gates at `@main` moves at this merge. A `merge-on-green.yml` it already has is left alone, like every file
the floor places, so it stays on Windows until it is re-scaffolded. The `branch-entry-gate` and
`always-on-budget` suites join CI's Linux leg. `merge-on-green` runs the default branch's copy, so its
first Linux run is the first sweep after this merge. If that breaks, the fold and the resolves still land
through `fold-on-merge` and `verify-resolved`, which have run on Linux since #2488. Issue #2616.

Every CI job that judges this repo's tree stays on `windows-latest`. The move is to the runners around it.
**Score:** 3

#### What makes this deploy extra special

On a private consumer, the gate that runs on every PR event (`Branch entry`: 137 runs in one consumer in
September, #2487) and the merge sweep now bill Linux minutes instead of Windows ones. Nothing changes in
what they check.
**Score:** 2

#### Pull Request

Move merge-on-green and the other placed Windows-only workflows to ubuntu-latest + pwsh

