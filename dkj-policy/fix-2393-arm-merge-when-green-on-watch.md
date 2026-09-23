## fix/2393-arm-merge-when-green-on-watch

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

#### Design, since the issue left the direction open

- **Arm before the wait.** Once the gates passed and the PR is open, only CI and a timing state stand
  between it and the merge. Arming there covers every ending by construction: a process that dies
  mid-watch, step 3b's refusals, and the old CI refusal.
- **A settle window in the picker (10 min).** The sweep is woken by CI completing, which is the same moment a
  live ship's watch returns. Without the window every ordinary ship would be handed to a second ship-pr on the
  runner, with `FOLD_PUSH_TOKEN` in its workspace. A live ship merges seconds after green, and a forward lap
  resets the clock with a new head. The cost to an orphan is one more half-hourly sweep at most.
- **Disarm only where a refusal repeats identically until a person acts**: the step-list gate, the DEPLOY
  lock, a 4xx from `gh pr merge`, and a required check with no Actions run behind it (the last two were added on review). The picker hands over the
  lowest-numbered eligible PR, so one that refuses identically on every retry would starve every armed PR
  above it. A red on the forwarded head stays armed, like any red, because a re-run can clear it.
- Not touched: `merge-on-green.yml`, and #2346's branch. Its hunks in the same two files are separate from these.

### CREATE

- [x] `ship-pr.ps1`: `Set-ShipMergeOnGreenArm` arms just after step 2b, before step 3. The CI-refusal
  branch now only says the PR stays armed. `Remove-ShipMergeOnGreenArmForJudgement` runs at the four
  refusals only a person can clear.
- [x] `merge-on-green-lib.ps1`: `Get-MergeOnGreenSettleMinutes` and `Get-RequiredGreenAgeMinutes` (pure,
  handles PS 7's pre-parsed dates and the zero date of a pending check). `Get-MergeOnGreenPrVerdict` takes
  `-GreenAgeMinutes` and refuses when it is unread or under the window.
- [x] `pick-merge-on-green.ps1`: asks for `completedAt` on the payload it already reads (no extra call).
- [x] Plugin mirrors synced. The Sylvester lens, `adopt-dkj-policy`'s SKILL and `scripts/README.md` now describe the new arming moment.

### TEST

- [x] `merge-on-green-lib.tests.ps1`: 92 pass, 0 fail under Windows PowerShell 5.1. New asserts cover the
  settle window, the age parser (slowest check, UTC, unreadable shapes, zero date), the picker reading
  `completedAt`, NaN/Infinity ages, and arming before step 3 plus disarming at all four refusals (structural). PowerShell 7
  is not installed on this machine, so the PS 7 date branch runs only in CI, if CI runs it.
- [x] `ship-pr.ps1` parses clean. `gh pr checks 2390 --required --json completedAt` returns the field as ISO Z.

### DEPLOY: fix/2393-arm-merge-when-green-on-watch

`ship-pr` now labels a pull request `merge-when-green` once it is open and before it starts waiting on CI.
Until now it did that only when its own CI verdict refused. So a ship that dies mid-watch, or refuses at
step 3b on a timing state, still has its merge finished by the sweep. The sweep now takes over only a pull
request whose required checks have been green for ten minutes, so it never races a live ship. `ship-pr`
removes the label again at the refusals only a person can clear: the step-list gate, the DEPLOY lock, a merge
GitHub itself refuses, and a required check with no Actions run behind it. Leaving the label on would starve
every armed pull request numbered above it.

**Score:** 2

#### What makes this deploy extra special

A shipped pull request no longer sits green and unmerged because the session that shipped it ended early.

**Score:** 2

#### Pull Request

ship-pr: arm merge-when-green before the CI wait, with a settle window so the sweep never races a live ship

Plugins: dkj-policy
