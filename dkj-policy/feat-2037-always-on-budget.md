## feat/2037-always-on-budget

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

Issue #2037 asks for a durable bound on the always-on document path -- `CLAUDE.md` plus its whole
`@`-import closure -- in EVERY consumer, because measurement alone has not held a line: all four
measurable repos are over 100,000 B, this one included and smallest of them at 109,385 B.

#### Three open points in the issue, and two of them had mechanical answers

The issue left three things undecided. Two are not judgement calls once the tree is read:

- **the local carrier** -- `open-pr.ps1`, not the lint gate. `Get-LintScript` names a file that exists
  only in the repo that states it ("every consumer has its own lint"), so a check placed there would
  reach exactly one repo, which is the opposite of the ask;
- **the CI carrier** -- `adopt-workflow-folder` (Part 1), not Part 3. The issue names `branch-entry.yml`
  as the runner it is modelled on, and that runner is Part 1's. The split is by TRIGGER: both fire on
  `pull_request` and gate what is about to land, where Part 3's three repair what a merge nobody watched
  left behind;
- **the ceiling** -- 100,000 BYTES, which is Dave's own figure, in the unit the measurement layer
  produces. Not tokens: no API prices a document, so a token ceiling would be a calibrated estimate
  wearing the trousers of a measurement -- the exact failure `measure-context-lib.ps1` records as this
  repo's worst. The baseline file lives in the workflow folder rather than beside `repo-config.ps1`,
  because `repo-config` is where a PERSON declares what a repo is and this file is machine-written state.

#### And one premise the issue never weighed

A CI runner has no marketplace clone, so the `~/.claude/plugins/marketplaces/...` persona import -- 30,267
B, 27.7% of this repo's path, and the issue's own argument for why `wc -c CLAUDE.md` is the wrong unit --
does not resolve there. Left alone, the same commit measures 109,385 B locally and 79,118 B in CI, and the
ratchet flaps on every push. The baseline therefore records each document's size keyed by its import
target, and a run that cannot resolve one carries the recorded figure and says so.

### CREATE

- [x] `scripts/lib/always-on-budget-lib.ps1` -- the ceiling, the ratchet (`max(budget, baseline)`), the
      baseline file, the carried/unmeasured split, and the one verdict every carrier reads. A second lib
      beside `measure-context-lib.ps1` rather than three functions inside it, whose own header promises it
      reaches no verdict (#861).
- [x] `scripts/lint/check-always-on-budget.ps1` -- the thin gate over it: the printing and the exit code,
      plus `-Record` and `-Raise -Reason`.
- [x] `Get-AlwaysOnBudget` in `scripts/repo-config.ps1`, its contract record (`copy`, optional) and the
      regenerated config blueprint.
- [x] The three carriers: a gate step in `open-pr.ps1` above the document commit, this repo's
      `.github/workflows/always-on-budget.yml`, and the `always-on-sessioncheck` SessionStart hook.
- [x] `adopt-workflow-folder.ps1` scaffolds the consumer's copy of that runner beside `branch-entry.yml`.
- [x] Registered both new shared files in the shared-scripts registry and rebuilt the plugin mirrors.

### TEST

- [x] `scripts/tests/always-on-budget.tests.ps1` -- 57 asserts: the `max()` limit with the `min()` trap
      pinned by name, all six verdict states, the seam (absent / stated / zero / non-numeric), the baseline
      round trip, the carried term proving a clone-less run reads the same total, the unmeasured term
      proving it is never counted as zero, and the script's own exit codes including `-Raise` without a
      reason.
- [x] Full gate green: lint 0 errors, all 107 suites passing.
- [x] Exercised by hand against this repo: first run records 109,385 B, an unchanged re-run holds, a
      simulated clone-less run reads the identical total, +400 B refuses, -2,000 B lowers the mark.
- [x] `scripts/tests/script-contract.tests.ps1` record count 40 -> 41, and the guard-coverage exemption
      for the new check script argued in `source-repo-guard.tests.ps1` where that list is kept.

### DEPLOY: feat/2037-always-on-budget

Nothing bounded the always-on document path -- `CLAUDE.md` plus everything it `@`-imports, which every
session reads before a single assignment is given -- and every measurable repo running this workflow had
gone over 100,000 B, the source repo included and smallest of the four. Measurement has been portable
since August 2026 and reaches no verdict by design; this adds the bound it was missing without adding the
judgement #861 argued down. It bounds a TOTAL and still says nothing about which block of prose should go.

A **ratchet rather than a cliff**, because all four repos were over on day one and a gate that refuses
from a standing start is one that gets `-Force`d once and never obeyed again: over the ceiling the limit
is a recorded baseline and GROWTH is refused; at or under it the limit is the ceiling and CROSSING is
refused. The baseline falls on its own whenever a branch measures less and rises only under `-Raise` with
a reason written into the file. Three carriers read one verdict -- `open-pr` before the push, a CI runner
on every PR, and a SessionStart hook that puts the headroom in front of whoever is about to add to it --
and only the local one writes.

**Score:** 4 -- a new refusal in the branch flow every contributor meets, and a session-start line every
session sees; the ceiling itself is a number they can now argue with instead of a figure nobody acted on.

#### What makes this deploy extra special

For a consumer this arrives as a bound that holds in their repo rather than in the repo that ships the
tooling -- which is the whole of #2037. Adopting it is one seam (`Get-AlwaysOnBudget`, optional, 100,000
bytes unstated) and one scaffolded runner; a repo already over the ceiling is held to its own history and
converges on it, instead of meeting a red check it cannot clear. The refusal names where the weight goes,
in the four classes this repo has already proved on its own path.

**Score:** 3 -- a clear improvement noticed the moment they touch their instruction documents, and it
costs them nothing to adopt: unanswered, the ceiling is the canonical figure and the first run merely
records where they are.

#### Pull Request

A ratcheted budget on the always-on document path

