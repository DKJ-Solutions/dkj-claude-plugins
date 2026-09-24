## fix/2438-stranded-sweep-sessioncheck

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

A SessionStart check lists armed + green + settled pull requests the sweep will never take because they change code the runner executes, so a dead ship no longer strands them silently.

### CREATE

- [x] Read issue #2438 + its comments (Sebastian's design review: Option B, the SessionStart check,
  is ACCEPTABLE as-is; Option A needs a three-job CI split this issue does not ask for). Read
  `merge-on-green-lib.ps1`, `pick-merge-on-green.ps1` and `merge-on-green-lib.tests.ps1` to find the
  existing verdict logic (`Get-MergeOnGreenPrVerdict`, `Get-MergeOnGreenExecutedPathHit`,
  `Test-MergeOnGreenArmed`) rather than restating it.
- [x] Checked `origin/fix/2436-honest-sweep-promise`'s diff to `merge-on-green-lib.ps1`
  (`Get-MergeOnGreenSweepRefusal`, inserted right after `Get-MergeOnGreenExecutedPathHit`) and put my
  own addition in a separate hunk, at the end of the file after `Select-MergeOnGreenCandidate`, so the
  two branches do not collide.
- [x] Verified the lib mirror mechanism: `scripts/lib/merge-on-green-lib.ps1` is the tested source,
  `plugins/dkj-policy/scripts/lib/merge-on-green-lib.ps1` is a byte-identical mirror kept that way by
  `scripts/sync/build-shared-scripts.ps1`, off the registry in `scripts/lib/shared-scripts-lib.ps1`
  (`Get-SharedScriptPairs`), guarded by check 8 (`[shared-script]`) in `check-plugin-integrity.ps1`.
  Edited the source only and ran the sync script to update the mirror.
- [x] Added `Get-MergeOnGreenStrandedVerdict` to `scripts/lib/merge-on-green-lib.ps1` -- pure,
  injectable (`Record`, `MergeBlockVerdict`, `GreenAgeMinutes`, `Label`), reusing
  `Get-MergeOnGreenExecutedPathHit` and `Get-MergeOnGreenPrVerdict` by exact string identity of the
  Reason rather than re-deriving the armed/draft/cross-repo checks, and reusing
  `Get-MergeOnGreenSettleMinutes` for the settle window. Did NOT reorder or edit
  `Get-MergeOnGreenPrVerdict` itself: its executed-path check runs before the mergeable/required-check/
  settle checks (deliberately, per its own docstring), so a record armed-but-not-yet-green also reports
  the executed-path Reason there, and several existing asserts in `merge-on-green-lib.tests.ps1`
  (lines ~162-172) construct exactly that shape and pin the current order.
- [x] Ran `scripts/sync/build-shared-scripts.ps1` -- mirrored `merge-on-green-lib.ps1`.
- [x] Wrote `scripts/lint/check-stranded-sweep.ps1`: feature-detects `.github/workflows/merge-on-green.yml`,
  `gh` on PATH, `gh auth status` naming an account (via the existing `Get-ActiveGhAccount`, no network),
  then makes the same two bounded `gh` reads `pick-merge-on-green.ps1` makes (`pr list --label
  merge-when-green ...`, `pr checks --required ...`), reusing `Get-MergeOnGreenArmLabel`,
  `ConvertFrom-MergeOnGreenListJson`, `Get-MergeBlockVerdict`, `Get-RequiredGreenAgeMinutes` and the new
  `Get-MergeOnGreenStrandedVerdict` -- no hardcoded label, settle window or check name. Fails quiet
  (`[SKIP]`, exit 0) on any unclean read; scrubs branch name and PR title to `[^\x20-\x7E]` (the same
  pattern `Get-MergeOnGreenExecutedPathHit` already uses on a pushed path) before printing either.
- [x] Registered `check-stranded-sweep` in `shared-scripts-lib.ps1` (Plugin `dkj-policy`, no skill --
  its only caller is the hook, same reasoning as `check-unfolded-entry`), ran the sync script again to
  create the mirror, and confirmed no `MeasureArgs` is declared -- a bare run reads live tracker state
  over the network, the same declaration `pick-merge-on-green`'s own row carries.
- [x] Verified `ship-pr.ps1`'s actual resume form before writing it into the check's output: its param
  block (`scripts/release/ship-pr.ps1:342`) carries no `-Pr` or `-Branch` parameter at all. It looks up
  the open pull request for the CURRENT branch (`gh pr list --head <branch> --base main`), so the
  resume form the check prints is `git checkout <branch>` followed by a bare
  `powershell ... -File scripts/release/ship-pr.ps1` -- two lines, not one chained with `&&` (which
  Windows PowerShell 5.1 does not have).
- [x] Wrote `plugins/dkj-policy/hooks/stranded-sweep-sessioncheck.ps1`, modelled on
  `unfolded-entry-sessioncheck.ps1` / `git-identity-sessioncheck.ps1`: runs the mirrored check in-process
  via `hook-check-lib.ps1`'s `Invoke-CheckScript`, forwards only its `[STRANDED]` marker line(s) via
  `Select-CheckMarkerLine` (data, not instructions), stays silent on `[OK]`/`[SKIP]`, always exits 0.
  Registered it in `plugins/dkj-policy/hooks/hooks.json` under `SessionStart`, beside
  `unfolded-entry-sessioncheck`; validated the JSON still parses.
- [x] Docs: grepped `*.md` for `unfolded-entry-sessioncheck` and `merge-on-green` and updated the two
  places a list/description would otherwise be incomplete: `plugins/dkj-policy/scripts/README.md`'s
  shared-scripts table (new row for `check-stranded-sweep.ps1`, extended the `merge-on-green-lib.ps1`
  row) -- this table sits inside the opt-in shared-scripts-mirror marker span check 32 holds against
  the registry, so both additions were mandatory rather than optional. Also corrected a now-stale count in
  `scripts/tests/hook-check-lib.tests.ps1`'s own docstring ("Six SessionStart hooks take the default
  path" -> seven), found while grepping for `SessionStart` — an inconsistency in prose, not an
  assertion, so nothing failed, but a wrong count reads as authority.
- [x] Checked `origin/fix/2436-honest-sweep-promise` for a ship-pr message pointing at this check: that
  branch only touches `merge-on-green-lib.ps1` (`Get-MergeOnGreenSweepRefusal`) and `ship-pr.ps1`'s own
  CI-refusal message text -- neither names a SessionStart hook or this check, and per this assignment I
  do not edit `ship-pr.ps1`. No doc on this branch needed a forward pointer to a message that does not
  exist yet on either branch.
- [x] Ran the real `check-stranded-sweep.ps1` and the real hook against this repo (see TEST) --
  1 armed pull request today, correctly read as not stranded.

### TEST

- [x] `scripts/tests/merge-on-green-lib.tests.ps1` -- 110 pass, 0 fail (unchanged from before this
  branch; the new function added no regression to the existing verdict/picker coverage).
- [x] `scripts/lint/check-plugin-integrity.ps1` -- full run, "No findings. Summary: 0 error(s)." Checks
  8 (`[shared-script]`, 112 checked), 32 (`[shared-script-list]`, 84/84), and 39 (`[mirror-depth]`) all
  pass with the new pair registered and mirrored.
- [x] `scripts/tests/shared-scripts.tests.ps1` -- 1022/1022 asserts pass (the registry/mirror
  invariants the new row has to satisfy).
- [x] `scripts/tests/measure-skill.tests.ps1` -- 93/93 pass (the new registry row declares no
  `MeasureArgs`, so pass 2's safety-invariant asserts have nothing new to check against it, and were
  re-run to confirm that).
- [x] `scripts/tests/hook-check-lib.tests.ps1` -- 28/28 pass; `scripts/tests/hook-stdin-guard.tests.ps1`
  -- 47/47 pass (its `Get-ChildItem -Filter hooks.json` walk picks the new hook up automatically).
- [x] `scripts/tests/check-plugin-integrity-scripts.tests.ps1` -- 58/58,
  `scripts/tests/check-plugin-integrity-figures.tests.ps1` -- 24/24 (fixture-based, unaffected, run to
  confirm).
- [x] Ran `check-stranded-sweep.ps1` directly against this real repo: reported `[OK] 1 armed pull
  request(s), none stranded on the executed-path reason.` -- a real, non-mocked run against this
  repo's own tracker.
- [x] Ran `check-stranded-sweep.ps1 -RootOverride <a tree with no .github/workflows/merge-on-green.yml>`
  -- reported `[SKIP]` and exited 0, confirming the feature-detection.
  Ran `Get-MergeOnGreenStrandedVerdict` by hand against four hand-built records (armed+executed-path+
  green+settled -> Stranded; not-yet-settled -> not; not armed -> not; no executed-path hit -> not) --
  all four came back correct.
- [x] Ran `stranded-sweep-sessioncheck.ps1 -CheckScriptOverride <a fixture printing [STRANDED] ...>` --
  the hook correctly forwarded the finding with its own headline and every line, verbatim.
- [x] Tycho: dedicated regression coverage for `Get-MergeOnGreenStrandedVerdict` (in
  `merge-on-green-lib.tests.ps1`, alongside its siblings) and for `check-stranded-sweep.ps1` /
  `stranded-sweep-sessioncheck.ps1` (skip paths, the `[STRANDED]` marker, untrusted-data scrubbing).
  Added 17 asserts to `merge-on-green-lib.tests.ps1` (110 -> 127 pass, 0 fail): the one Stranded=true
  shape (armed, executed-path hit, green, settled), the identity check against
  `Get-MergeOnGreenExecutedPathHit`'s own reason string (so the two cannot drift apart unnoticed), not
  armed / draft / fork / no-executed-path-hit all reading as not-stranded, an unreadable / red / pending
  required-check state each reading as not-stranded, and the settle-window boundary (one minute short
  -> not stranded, exactly the window -> stranded).
  New file `scripts/tests/stranded-sweep-gate.tests.ps1` (29 asserts, pattern reused from
  `unfolded-entry-gate.tests.ps1` and `git-identity-gate.tests.ps1`): `check-stranded-sweep.ps1` driven
  end to end against a fake `gh` on PATH (same mechanism as `verify-resolved-issues.tests.ps1`) --
  every `[SKIP]` arm (no workflow file, gh absent, gh unauthenticated, repo name unresolvable, the list
  read failing), `[OK]` with nothing armed and with an armed-but-not-stranded record, the one
  `[STRANDED]` positive case with a control character (ESC, BEL) in the pushed branch name and title
  confirmed scrubbed to `?` rather than reaching printed output or being silently dropped, the resume
  command printed as two lines, and exit 0 in every case including a per-PR required-check read
  failing. `stranded-sweep-sessioncheck.ps1` driven against stub check scripts (no `gh` needed at all):
  silent on `[SKIP]`/`[OK]`, forwards `[STRANDED]` verbatim under its own headline, reports a crashed
  check without ever failing the session, and handles a missing check script. Also asserted
  `hooks.json` carries exactly one `SessionStart` entry naming this hook, as a `command` hook with a
  positive timeout.
  No injection seam had to be added: `check-stranded-sweep.ps1`'s three `gh` reads
  (`Get-ActiveGhAccount`, `pr list`, `pr checks`) all resolve `gh` off PATH, so a fake `gh.cmd` ahead of
  it on PATH is a complete seam without touching the script.
  Ran `scripts/tests/shared-scripts.tests.ps1` (1022/1022), `measure-skill.tests.ps1` (93/93),
  `hook-check-lib.tests.ps1` (28/28), `hook-stdin-guard.tests.ps1` (47/47),
  `check-plugin-integrity-scripts.tests.ps1` (58/58), `check-plugin-integrity-figures.tests.ps1`
  (24/24) and `scripts/lint/check-plugin-integrity.ps1` (0 errors) -- all unaffected, all still green.
  No test gap left: the pure verdict, the check script's own tracker reads, and the hook's forwarding
  are all exercised without a live tracker.

### DEPLOY: fix/2438-stranded-sweep-sessioncheck

This repo's own maintainers, and any consumer running the merge-on-green sweep, could not tell a
permanently-stranded armed pull request from an ordinary, still-being-shipped one -- both stay labelled
`merge-when-green` and green, and the sweep's own decline reason lived only in a CI log nobody reads
once it stops going red. A new SessionStart hook (`stranded-sweep-sessioncheck.ps1`) now reads the
tracker the same way the sweep itself does -- reusing `Get-MergeOnGreenExecutedPathHit` and
`Get-MergeOnGreenPrVerdict` rather than a second implementation of either -- and surfaces the finding,
with the exact resume command (`git checkout <branch>` then `ship-pr.ps1`, verified against its actual
param block rather than assumed), at the start of the next session in this repo. Fails quiet with no
`.github/workflows/merge-on-green.yml`, `gh` absent or unauthenticated, or an unreadable tracker read,
and never blocks a session start.

**Score:** 3

#### What makes this deploy extra special

A consumer running this workflow's merge-on-green sweep will now occasionally see a `[STRANDED]` report
at session start naming a pull request nobody would otherwise have known was permanently stuck --
recovering work that used to require reading a CI log by hand to notice at all.

**Score:** 2

#### Pull Request

A PR the merge-on-green sweep declines as executed-path is reported at session start

