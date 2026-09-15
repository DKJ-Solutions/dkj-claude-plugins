## fix/2024-console-strip-zl-zp-combining

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

Add Zl/Zp (U+2028/U+2029) and stacking combining marks (Mn/Me) to the shared console-strip character
class, alongside the existing Cc/Cf, across the shared call sites and their plugin mirrors and tests.

**Verified against the tree before repairing (issue #2024's own reasoning, checked rather than
trusted).** #2024 says the class is carried at "at least four" call sites, the fourth being
`Format-ForConsole` in `plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.ps1`, added by
`fix/2019-asana-mirror-console-strip` (#2019). That branch is real (`git log --all` shows it,
`15ee243f`) but it is still parked -- pushed, no PR, not merged -- so `asana-mirror.ps1` on `main`
carries no such function today; `dkj-policy-bwj.tests.ps1` confirms it (no `Cc`/`ForConsole` hit).
So THIS branch widens the class at the three call sites that actually exist on `main`:
`claim-issue-lib.ps1` (`Format-ForConsole`), `pr-issues-lib.ps1` (`Format-AuthoredText`), and
`ref-print-lib.ps1` (`Get-DisplayRef` AND `Get-DisplayPath`, both of which carry the same class) --
plus every byte-identical mirror of those three files (`plugins/dkj-policy/scripts/lib/*` for all
three, and `plugins/dkj-subagents/dkj-subagents-shopify/scripts/lib/ref-print-lib.ps1` for
ref-print-lib specifically), plus the two prose mentions of the pattern in `adopt-ci-floor.ps1` (and
its mirror), plus every test that pins the literal class string. When #2019 lands, its own
`Format-ForConsole` copy should be typed with this widened class from the start -- that is #2019's
job, not this branch's; this branch does not touch a file that does not yet exist on `main`.

### CREATE

- [x] Confirm the widened class strips U+2028, U+2029 and stacking combining marks correctly (PowerShell smoke test) and settle on `[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}]`
- [x] Widen the class in `scripts/lib/claim-issue-lib.ps1` (`Format-ForConsole`) and its docstring
- [x] Widen the class in `scripts/lib/pr-issues-lib.ps1` (`Format-AuthoredText`) and its docstring
- [x] Widen the class in `scripts/lib/ref-print-lib.ps1` (`Get-DisplayRef`, `Get-DisplayPath`) and its docstrings, including the two prose descriptions of "the deceptive class"
- [x] Sync the three widened libs into their byte-identical plugin mirrors (`plugins/dkj-policy/scripts/lib/*`, `plugins/dkj-subagents/dkj-subagents-shopify/scripts/lib/ref-print-lib.ps1`)
- [x] Update the two prose mentions of the old literal class in `scripts/task/adopt-ci-floor.ps1` and sync its mirror
- [x] Update every test that pins the literal class string (`claim-issue.tests.ps1`, `pr-issues.tests.ps1` drift pin, `remote-ahead-lib.tests.ps1`) and every test that checks the class survives nowhere in an output (`gate-lib.tests.ps1`, `ref-print-lib.tests.ps1` x2, `worktree-lib.tests.ps1` x2)
- [x] Add positive coverage for Zl/Zp/Mn/Me at each function: `Format-ForConsole`, `Format-AuthoredText` (via `Get-AuthoredFailureNote`), `Get-DisplayRef`, `Get-DisplayPath`

### TEST

- [x] `scripts\tests\claim-issue.tests.ps1` -- 224 passed, 0 failed
- [x] `scripts\tests\pr-issues.tests.ps1` -- 975 asserts passed
- [x] `scripts\tests\ref-print-lib.tests.ps1` -- 453 pass, 0 fail
- [x] `scripts\tests\remote-ahead-lib.tests.ps1` -- 57 pass, 0 fail
- [x] `scripts\tests\worktree-lib.tests.ps1` -- 100 asserts passed
- [x] `scripts\tests\gate-lib.tests.ps1` -- 161 pass, 0 fail
- [x] `scripts\lint\check-plugin-integrity.ps1` -- the full lint gate plus every test suite

### DEPLOY: fix/2024-console-strip-zl-zp-combining

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

Widen the shared console-strip class to Zl/Zp and stacking combining marks

