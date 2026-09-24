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
- [x] Edith (review): that "-> seven" correction was itself already stale on landing -- measured NINE
  SessionStart hooks calling `Invoke-CheckScript` (eight in `dkj-policy` plus `dkj-subagents-alpha`'s
  `roster-sessioncheck`), not seven. Dropped the number entirely from `hook-check-lib.tests.ps1`'s
  docstring rather than correcting it again, worded so it stays true as the family grows. Fixed this
  file's own CREATE line above from "-> seven" to record what actually happened (nothing to tick a
  second box for; the file itself was the inconsistency).
- [x] Victor (review, medium): `check-stranded-sweep.ps1`'s per-PR loop had no bound on TOTAL runtime --
  only each `gh` call carried `-TimeoutSeconds`, so an armed set larger than the ordinary 0-1 could run
  the loop past hooks.json's own 120s per-hook timeout, and the harness would kill the check mid-scan
  with nothing said. Added `-MaxElapsedSeconds` (default 90, measured from just before the first
  `gh pr list` read), checked once per armed pull request before its own `gh pr checks` call; once spent,
  every remaining record is counted unjudged rather than attempted. When anything went unjudged (budget
  cut-off, or a per-PR required-check read failing) the run now prints an explicit `[INCOMPLETE]` marker
  naming judged vs. total, instead of staying silent about the gap.
- [x] Victor (review, cosmetic): the `[OK]` line's `armed.Count` used to fold in PRs whose `gh pr checks`
  read failed and were skipped unjudged, reading as "N armed, none stranded" when N included ones never
  actually checked. Tracked `$judgedCount`/`$unjudgedCount` explicitly (summing to `$armed.Count` on every
  path through the loop) and only print the unchanged `[OK]` wording when `$unjudgedCount` is zero;
  otherwise `[INCOMPLETE]` reports both numbers honestly. Same mechanism as the runtime bound above.
- [x] Updated `stranded-sweep-sessioncheck.ps1` to forward `[INCOMPLETE]` the same way it already forwards
  `[STRANDED]` (via `Select-CheckMarkerLine`, now given both markers) rather than letting it fall into the
  hook's existing `[OK]`/`[SKIP]` silence -- an incomplete scan must not be silent at the one point a
  human is present to notice it.
- [x] Sebastian (review, advisory): the `git checkout $($s.Branch)` resume line printed a pull request's
  own (ASCII-scrubbed-for-display) branch name unquoted. That scrub only replaces non-printable control
  characters with `?`; `$`, `(`, `)`, `` ` ``, `;` and `|` are all printable ASCII and would sail through
  it into a command line a reader is invited to paste. Did NOT invent a new quoting convention --
  checked the repo's existing one first (per a mid-task correction): `ship-pr.ps1` and
  `pr-issues-lib.ps1` already answer exactly this (issue #1594) via `Get-PasteableRef` in
  `scripts/lib/ref-print-lib.ps1`, which judges a branch name against a narrow allowlist and returns
  either the name itself or a placeholder (`<branch>`) plus a prose note naming the real branch outside
  any command context. Dot-sourced that lib in `check-stranded-sweep.ps1` (already registered
  independently in `shared-scripts-lib.ps1`, so no registry change needed) and judge the RAW branch name
  (not the display-scrubbed one) for the checkout line specifically; the existing prose scrub is
  unchanged for the `#N (branch) -- title` line.
- [x] Victor (review, low): `Get-MergeOnGreenStrandedVerdict` re-derived
  `Get-MergeOnGreenPrVerdict`'s own blocked/pending/settle-window block instead of reusing it. Extracted
  `Test-MergeOnGreenRequiredChecksSettled` (Ready/Reason/Settle) into `merge-on-green-lib.ps1`, called
  by both functions; `Get-MergeOnGreenPrVerdict`'s own check ORDER and behaviour are unchanged (armed /
  draft / fork / executed-path / mergeable still run first, exactly as the existing asserts pin), and the
  extraction only replaces its own blocked/pending/settle block with one call to the shared helper.
  Checked `origin/fix/2436-honest-sweep-promise`'s diff again before editing: it adds
  `Get-MergeOnGreenSweepRefusal` after `Get-MergeOnGreenExecutedPathHit` and touches `ship-pr.ps1`'s
  CI-refusal text only, neither of which this hunk (inserted just above `Get-MergeOnGreenPrVerdict`)
  touches or moves.
- [x] Ran `scripts/sync/build-shared-scripts.ps1` again after all of the above -- mirrored
  `merge-on-green-lib.ps1` and `check-stranded-sweep.ps1`.
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
- [x] Tycho: coverage for the four review fixes above.
  `Test-MergeOnGreenRequiredChecksSettled` -- added 17 asserts to `merge-on-green-lib.tests.ps1`: direct
  cases against the extracted helper (unreadable, blocked with its own Reason, pending, no age passed,
  NaN, Infinity, one minute short of settle, exactly settle, and `.Settle` always reporting the window),
  each pinning the exact Reason string `Get-MergeOnGreenPrVerdict` printed for that case before the
  extraction. Then a direct identity check -- unreadable / blocked / pending / not-yet-settled fed into
  both `Test-MergeOnGreenRequiredChecksSettled` and `Get-MergeOnGreenPrVerdict` and asserted
  `Assert-Equal` on the Reason -- so the two cannot drift apart unnoticed. And two re-confirmations that
  the cheaper disqualifiers still run first: a draft and an unarmed record each refuse on their own
  reason rather than on the (unreachable) required-check block. All of `merge-on-green-lib.tests.ps1`'s
  existing check-order asserts (armed/draft/fork/executed-path/mergeable ahead of the settle block) were
  re-run unchanged against the refactored code and still pass -- 149 pass, 0 fail (127 -> 149).
  The `-MaxElapsedSeconds` budget -- added to `stranded-sweep-gate.tests.ps1`: `Invoke-Check` grew an
  optional `-MaxElapsedSeconds` passthrough (a `-1` sentinel keeps every existing call on the script's own
  default). A tiny budget (0) against three armed, ordinary pull requests reports `[INCOMPLETE]`, never
  `[OK]`, names `judged 0 of 3` and `3 not checked`, and still exits 0 -- deterministic (the budget check
  fires before the first per-PR `gh pr checks` call, so no sleep-based timing was needed). No fixture
  reaches a PARTIALLY-judged split without a controllable delay in the fake `gh`, which the existing
  fake-gh harness does not have; the all-unjudged (budget 0) and none-unjudged (ordinary/OK) shapes
  together already exercise every branch of the judged/unjudged accounting, so this is a deliberate,
  narrower proof than "some judged, some not" rather than a gap -- flagging it rather than leaving it
  silent.
  The judged/unjudged honesty split -- the existing `partial-fail` case (one armed pull request, its
  `gh pr checks` read failing) now additionally asserts `[INCOMPLETE]` (not `[OK]`) and `judged 0 of 1`.
  A new `ok-multiple` case (three armed, all judged, none stranded) asserts the unchanged `[OK]` wording
  stays honest about the count at more than one, and that no `[INCOMPLETE]` marker appears when nothing
  went unjudged.
  The safe-checkout quoting -- a new `quoting` case: two armed pull requests touching an executed path,
  one with headRefName `` fix/601`x`;$(y) `` (backtick, semicolon and `$(...)` together -- all printable
  ASCII, all untouched by the existing `[^\x20-\x7E]` scrub), one with the ordinary `fix/602-safe`. Both
  strand; asserted the hostile branch never appears in a `git checkout` line, that line reads
  `git checkout <branch>` instead, `Get-PasteableRef`'s note appears and names the real branch as prose,
  and the ordinary branch's own checkout line is unaffected (`git checkout fix/602-safe`, printed as-is).
  The hook -- added an `[INCOMPLETE]` stub case to the existing hook block: the hook forwards it under its
  own headline (not silent, unlike `[OK]`/`[SKIP]`), verbatim including the judged/total count.
  No existing assert needed adjusting -- none of the four review fixes changed a string an existing
  assert pinned verbatim.
  Ran `scripts/tests/merge-on-green-lib.tests.ps1` (149/149), `scripts/tests/stranded-sweep-gate.tests.ps1`
  (46/46, up from 29), `scripts/tests/hook-check-lib.tests.ps1` (28/28),
  `scripts/tests/shared-scripts.tests.ps1` (1022/1022) and `scripts/lint/check-plugin-integrity.ps1`
  (0 errors) -- all green.

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

Review pass (Victor, Sebastian): the check's own scan is now bounded in TOTAL, not only per `gh` call --
an `-MaxElapsedSeconds` budget (default 90) stops judging further armed pull requests once spent, and
reports an honest `judged X of Y` `[INCOMPLETE]` line (forwarded by the hook, not silent) whenever a
budget cut-off or a per-PR read failure left anything unjudged, rather than folding that gap silently
into "none stranded". The printed `git checkout` resume line now judges the branch name through
`Get-PasteableRef` (ship-pr.ps1's own #1594 mechanism) instead of the display-only ASCII scrub, so a
branch name carrying a shell metacharacter prints a safe placeholder plus a note rather than a pasteable
command. And `Get-MergeOnGreenStrandedVerdict`'s blocked/pending/settle-window checks now share one
helper with `Get-MergeOnGreenPrVerdict` instead of re-deriving them, so the two cannot drift apart.

**Score:** 3

#### What makes this deploy extra special

A consumer running this workflow's merge-on-green sweep will now occasionally see a `[STRANDED]` report
at session start naming a pull request nobody would otherwise have known was permanently stuck --
recovering work that used to require reading a CI log by hand to notice at all.

**Score:** 2

#### Pull Request

A PR the merge-on-green sweep declines as executed-path is reported at session start

