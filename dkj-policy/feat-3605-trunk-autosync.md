## feat/3605-trunk-autosync

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

Issue #3605. A trunk that is merely standing there is fast-forwarded to origin in two places, through one
shared definition (`Invoke-TrunkFastForward`, `scripts/lib/trunk-sync-lib.ps1`):

- a SessionStart prep step, `trunk-sync-sessionprep.ps1`, which the dispatcher runs before its parallel
  checks because those checks read the trunk it moves;
- a command, `sync-trunk.ps1` (skill `sync-trunk`), for one checkout or `-AllCheckouts`.

### CREATE

- [x] `trunk-sync-lib.ps1`: the safety conditions (root, origin ref, on the trunk, no tracked change, not diverged) and `merge --ff-only`
- [x] `sync-trunk.ps1` with `-AllCheckouts` / `-DryRun`, registered in `Get-SharedScriptPairs`, mirrors built
- [x] `trunk-sync-sessionprep.ps1` hook, `DKJ_TRUNK_AUTOSYNC=0` opt-out
- [x] `sessioncheck-dispatch.ps1` runs `*-sessionprep.ps1` sequentially before the pool
- [x] `sync-trunk` skill page and rows in `plugins/dkj-policy/scripts/README.md`

### TEST

- [x] `scripts/tests/trunk-sync.tests.ps1`: every outcome and every safety condition against real fixture repos, plus the dispatcher ordering
- [x] `sessioncheck-dispatch`, `shared-scripts` and `source-repo-guard` suites green; `check-plugin-integrity` 0 errors
- [x] code review (Victor): every git call bounded so the prep step cannot stall a session start; docstring no longer claims a `Get-TrunkBranchName` fallback; why `Get-TrunkGap` was not reused is written down
- [x] security review (Sebastian): every printed value stripped; the `-AllCheckouts` sweep runs git with the checkout's own hooks and fsmonitor off
- [x] copy edit (Edith): wording on merges, skips and exit codes

### DEPLOY: feat/3605-trunk-autosync

A checkout's trunk now follows origin by itself. At every session start, a checkout standing clean on
its trunk and merely behind is fast-forwarded before the session checks run. It is silent when there is
nothing to report, and `DKJ_TRUNK_AUTOSYNC=0` turns it off. The new
[`sync-trunk`](../plugins/dkj-policy/skills/sync-trunk/SKILL.md) command does the same on request, and
with `-AllCheckouts` it covers every checkout on the machine. Nothing is ever stashed or rebased, and no
merge commit is ever created. A checkout off its trunk, with an uncommitted change or with local commits
origin lacks is left alone: the command says why, and the session-start step stays silent unless the
trunk is behind.

**Score:** 3

#### What makes this deploy extra special

You no longer pull the trunk by hand after every merge, in this repo or in any other checkout on your
machine. Work in progress is never moved.

**Score:** 3

#### Pull Request

Fast-forward a clean trunk automatically, at session start and across every checkout

Plugins: dkj-policy
