## fix/2032-sweep-living-branches

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

- [x] Verify inbound #2032 against the tree: read `Get-ThemeSweepPlan` in
  `scripts/lib/theme-lifecycle-rules.ps1` and `scripts/task/sweep-preview-themes.ps1`. Confirmed --
  only `-KeepNames` (the current branch's own preview, plus any explicit `-Keep`) is ever spared; no
  test asks whether a preview's branch is still alive elsewhere. The report's proposed repair (a sixth
  refusal, "the branch still exists", read wide) matches the shape of the five refusals already there.

### CREATE

- [x] `Get-ThemeSweepPlan`: new `-LivingBranchNames` parameter and a sixth refusal, kept separate from
  `-KeepNames` so the printed reason stays accurate ("the branch still exists" vs. "this is the current
  branch's own preview").
- [x] `sweep-preview-themes.ps1`: reads every branch still alive -- `git ls-remote --heads origin` plus
  a plain `git branch` -- flattens each the same way the current branch's own preview already is, and
  passes them all as `-LivingBranchNames`. A `ls-remote`/`branch` call that does not answer cleanly
  REFUSES the run under `-Execute` (a missing branch is a swept preview) and only WARNS under a dry run.
  Uses `native-capture-lib.ps1` (already mirrored into `dkj-subagents-shopify` as
  `native-capture-lib-shopify`) rather than `dkj-policy`'s `fetch-attempt-lib.ps1`, which would have been
  a cross-plugin dependency a Shopify-only consumer does not have.
- [x] Synced the plugin mirrors with `scripts/sync/build-shared-scripts.ps1` (`theme-lifecycle-rules.ps1`
  and `sweep-preview-themes.ps1`, both under `dkj-subagents-shopify`).

### TEST

- [x] Extended `scripts/tests/theme-lifecycle-rules.tests.ps1`: a parked-branch theme now in the store
  fixture (kept, with the new reason), the bug reproduced directly (swept with no
  `-LivingBranchNames`, kept once the branch is named), and the ordering rule pinned (a name in both
  `-KeepNames` and `-LivingBranchNames` reads as "current branch", since that test runs first). Ran by
  hand: 92 pass, 0 fail (up from 85). `sweep-preview-themes.ps1` itself stays undriven, per its own
  header -- every new path reaches a real store, a consumer's repo-config, or the remote's own branch
  list, none of which exist here.
- [x] Parsed `sweep-preview-themes.ps1` with the PowerShell language parser: no syntax errors.
- [x] Ran the lint gate (`scripts/lint/check-plugin-integrity.ps1`) by hand: 0 errors -- mirrors
  confirmed back in sync. The lint gate and the full test suite (106 suites) also run via `open-pr.ps1`
  before the push, which is this branch's remaining coverage.

### DEPLOY: fix/2032-sweep-living-branches

Inbound #2032 (from `BWJ-Development/smartwatchbanden#675`): `sweep-preview-themes.ps1` spared only the
CURRENT branch's own preview theme, so a branch parked on the remote with no pull request -- carrying
work that exists nowhere else -- had its preview swept exactly like a merged branch's, on the one round
that is not recoverable. Measured there on 2026-09-15, from `main` after a live push: three previews
offered for the sweep, one of them `dkj-fix-669-bundle-block-fr-untranslated`, a parked branch's only
copy of its work.

`Get-ThemeSweepPlan` now reads every branch still alive -- local or on `origin`, whether or not a PR is
open -- and spares every one of their previews too, each with its own reason ("the branch still
exists"). `sweep-preview-themes.ps1` gathers that list via `git ls-remote --heads origin` and `git
branch`, and refuses the run under `-Execute` (rather than silently sweeping more than intended) when
that list cannot be read cleanly.

**Score:** 3
this repo publishes plugins and has no theme estate of its own, so nobody here runs this script against
a real store. The next developer who touches `Get-ThemeSweepPlan` or `sweep-preview-themes.ps1` notices
the new parameter, the sixth refusal, and the two new test blocks the moment they read either file.

#### What makes this deploy extra special

For a Shopify consumer running this plugin's theme lifecycle: the sweep no longer destroys a parked
branch's only preview theme. `BWJ-Development/smartwatchbanden` held off running `-Execute` specifically
because of this, and carries a temporary wrapper script
(`scripts/task/sweep-previews.ps1`) whose own header names this issue as its removal trigger -- so the
reader can now both run the sweep with confidence and retire that wrapper.

**Score:** 5
a long-standing blocker is gone (the sweep could not safely run `-Execute` against a store with any
parked branch), and the consumer has a concrete follow-up: remove the temporary `-Keep`-computing
wrapper script #2032 was filed to make unnecessary.

#### Pull Request

sweep-preview-themes spares every living branch's preview, not just the current one

