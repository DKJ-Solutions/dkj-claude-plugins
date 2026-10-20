---
id: 15
group: 05
---

# Sylvester ⚙️ · claude-code-specialists addendum

> Repo-lens (claude-code-specialists) accompanying the portable playbook in the `dkj-subagents-alpha` plugin (`plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-05-15-manual.md`). This file does not describe the craft, but what Sylvester does in this repo.

A system administrator does the same thing everywhere — manage the harness and the tooling the team
works in: scripts, config, the safety guards. **What is repo-specific in claude-code-specialists is not
that Sylvester maintains the harness, but which scripts, manifests, and config that involves here.**
In this repo that is a large and visible part of the work, because the repo is itself a piece of
infrastructure.

### What Sylvester owns here

- **`plugins/dkj-policy/hooks/guard-working-copy.ps1`** — the second `PreToolUse` guard in this
  marketplace, and the one that answers
  [#1669](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1669): a dispatched subagent
  may not run the git commands that discard the checkout it was dispatched into. Its judgement is
  `scripts/lib/working-copy-guard-lib.ps1` and its false-positive machinery
  `scripts/lib/command-guard-lib.ps1`, both mirrored into the plugin.

  **Three things about it are worth knowing before touching it, and each was measured rather than
  argued.** First, **the gate is `agent_id`, never `agent_type`** — Claude Code's shipped hook-input
  schema documents the second as present on the main thread of an `--agent` session, so keying on it
  would refuse the orchestrator in exactly that configuration. Second, **the cost is per tool call and
  not per session**, which makes it a different animal from the seven SessionStart checks below: 8089
  of the 9084 `Bash`/`PowerShell` calls in this project's transcripts are the main thread's, and they
  pay the hook while never being judged by it. That is why the `agent_id` question is asked as a
  string test on the raw payload *before* any lib is dot-sourced — 675 ms to 437 ms on that 89%, of
  which ~397 ms is the bare `powershell` launch a command hook cannot avoid. Third, **the
  false-positive rate is 0 of those 995 subagent calls**, and the one refusal that had to be
  answered was a test engineer working in its own fixture repo under `/tmp` — which is why the
  judgement takes a project root at all, and why `.claude/worktrees/agent-<id>` is carved out of it:
  an agent granted worktree isolation owns that tree, and the harness puts it *inside* the repo.

  **The corpus is reproducible and is not in the tree.** Dispatched-subagent turns are not in the
  session transcript: they live in `~/.claude/projects/<project>/<session>/subagents/agent-<id>.jsonl`
  and carry `isSidechain: true` plus `agentId`, which is the same distinction the guard gates on. A
  measurement that walks only `*.jsonl` at the top of the project directory reads **zero** subagent
  calls and looks complete while answering the wrong question.
- **The `statusLine` in [`.claude/settings.json`](../../settings.json), and the progress mechanism behind
  it** — `scripts/task/show-progress.ps1` renders, `scripts/lib/run-progress-lib.ps1` is what a
  long-running script publishes to, and the three producers wired up so far are the test gate (both lane
  events in `Invoke-TestSuiteGate`), `ship-pr`'s CI wait
  ([#2101](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2101), September 18, 2026) and the
  lint gate ([#2173](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2173), September 20,
  2026), which publishes from `Invoke-WorkflowGates` around its child call — **a label and a start, no
  counts and so no bar**, because `check-plugin-integrity.ps1` has no total number of checks to publish
  and a fraction of its uneven checks would sit still for most of the 78 seconds. It publishes only at
  gate depth 1: the same `DKJ_TEST_GATE_DEPTH` that marks a nested gate keeps every suite's fixture lint
  from repainting the test gate's bar.
  **A run this repo does not own still publishes nothing** — a backgrounded `npm test`, a `gh run watch`,
  a dispatched subagent — so the bar covers the long waits of this workflow rather than everything a
  session backgrounds; the gap, and the `PreToolUse` shape that would close it, are parked as
  [#2104](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2104).

  **Why a published record rather than a printed line, which is the whole reason this exists.** A run
  this session backgrounds prints to nobody: a `Bash` call made with `run_in_background` streams no
  stdout to any surface a person can see, in the terminal CLI and in the VS Code extension alike, and
  the output is only retrievable afterwards. So `Format-GateProgressLine` (#1717) and `ship-pr`'s watch
  were both written for a reader who, in the one case they were needed for, is not there. The statusline
  is the one surface that keeps rendering while that is true, and **`refreshInterval` is not optional
  decoration**: Claude Code's own documentation says the event-driven triggers "can go quiet when the
  main session is idle", which is exactly the state a backgrounded run leaves a session in. There is no
  native progress UI to hook instead and no marker a script can emit that becomes one — measured on
  2.1.276 against the shipped docs.

  **Four decisions in it are worth knowing before touching it.** First, **liveness is the writer's
  process, never the record's age** — a healthy `gh pr checks --watch` publishes once and then blocks
  for twelve minutes, and #1941's gate sat for 141 minutes printing nothing, so an age test would hide
  precisely the run a reader most wants to see. The record carries the run's START and the renderer
  derives the elapsed, which is what keeps the readout moving across a producer that is blocked. Second,
  **the pid is paired with that process's start time**, so a pid the OS has handed on cannot resurrect a
  finished run's bar. Third, **the glyphs are ASCII** — a block-character bar would have to survive
  PowerShell 5.1's stdout encoder, whose only repair is the console-wide `[Console]::OutputEncoding`
  that [`language-layers.md`](../../rules/language-layers.md) forbids outright, and mojibake in the one
  line that is always on screen is not a cosmetic defect. Fourth, **no bar without counts and no ETA
  ever**: a fraction nobody measured is an invention, which is #1717's own argument carried over intact.

  **What it costs, measured:** 206 ms per refresh on DAVE-KOK-BWJ, nearly all of it the bare `powershell`
  launch a command statusline cannot avoid — the same floor the `PreToolUse` guard above pays. At the
  2-second interval set here that is about a tenth of one core while a session is open. The script reads
  the branch out of `.git/HEAD` as a **file** rather than calling git for exactly that reason, and at
  this cadence it never throws and always exits 0: a failure here is not an error report, it is a broken
  status line repeated forever.

  **`refreshInterval` is in SECONDS, and for its first day it was set in milliseconds**
  ([#2163](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2163), September 19, 2026). The
  value was `2000`, which Claude Code reads as 33 minutes, so the timer this section calls "not optional
  decoration" never fired inside any real run and the bar redrew only on the event-driven triggers — a
  message sent, a turn ending. Measured on a backgrounded gate: `34 / 118` while about 114 suites had
  finished, then `113` the instant the operator typed, with nothing in the run having changed. The
  cost figures above were per-refresh and stay true; what was never true was the cadence they were
  multiplied by. The documentation states the unit and a minimum of `1`
  (<https://code.claude.com/docs/en/statusline>, the `refreshInterval` field), and **this file's own
  "2,000 ms" was the second place the wrong unit was written down**, so a reader trusting either one
  would have re-derived it. `adopt-statusline.tests.ps1` now pins the unit itself, not only the value:
  it refuses a figure above 60, which nothing sensible in seconds ever is.

  **The dot-source into `native-capture-lib.ps1` is guarded, and that is what keeps that file
  byte-identical to its two mirrors.** `run-progress-lib.ps1` is not mirrored into the plugins, so in a
  consumer the `Test-Path` fails and the gate behaves exactly as it did. Shipping the bar to consumers is
  therefore one more mirrored file plus an `adopt-dkj-policy` seam for the settings entry, not another
  edit to the gate — parked as
  [#2103](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2103).
- **`scripts/lint/check-plugin-integrity.ps1`** — the PR lint gate: validates `marketplace.json` +
  every `plugin.json` and the agent-def/manual frontmatter (`name`/`id`/`group` + filename match),
  scans for dead links (in `README.md`, `CHANGELOG.md`, the manuals, `SKILL.md`s, and `releases/**`),
  checks that every `scripts/**/*.ps1` parses without errors (catching syntax errors in the
  orchestration that would only break at runtime), and guards (check 7) that every shared-block
  region in an agent def still equals its source in `subagent-shared/`. **Check 28 reads that same
  scan set a second time for `@`-imports** (August 26, 2026, issue #874), because an import is a
  different syntax and the link scan matched none of it. It is worth separating from its sibling by
  what being wrong costs: a dead link costs a reader one click, a dead import costs the session **the
  whole document** — Claude Code drops one it cannot resolve without erroring, and this repo's
  always-on path is assembled entirely out of three of them, so the layer that vanishes is the one
  carrying the safety rules or the roster. It reuses `measure-context-lib.ps1`'s parser rather than
  restating the three resolution rules, so the gate and `measure-always-on.ps1` cannot drift on what an
  import means; a target outside the repo is counted, never refused, because a `~/`-relative import
  points into the marketplace clone and CI is a machine without one. **Checks 9 and 17 were retired on
  August 8, 2026** with the documents they guarded — the per-plugin `RELEASE.md` card and
  `CHANGELOG.md`. Both were the right repair for a real defect (a version stated twice, and a
  write-once intro that drifted), and both dissolved rather than being weakened: with the second copy
  gone there is nothing left to hold against the first. **The general shape is worth keeping: a check
  that compares two statements of one fact is made unnecessary by deleting one of them, and that is a
  better outcome than a better check.** **Check 11 is the one that guards a
  doc against reality rather than against itself:** every printed `claude plugin
  install`/`update`/`uninstall` — recognised by its `@`-target, which is what separates an instruction
  from prose discussing the command — must carry `--scope project`, and `install`/`update` must name
  the marketplace refresh nearby. Both fail *silently* when missing, which is why three adoption
  rounds in a row found this same class and four doc fixes only ever closed the instances. History
  (`CHANGELOG.md`, `releases/**`, root entry files) is excluded permanently: it records
  what was true then. Since #315 the scope rule is **verb-specific** — `uninstall` also accepts
  `--scope local`, because that is the only command that removes a record a session start left at that
  scope, and a gate demanding `project` there would have rejected the correct instruction and enforced the
  assumption round v8 disproved. **Check 12 is check 11's sibling, the same idea one level up:** a fenced
  block that reads `installed_plugins.json` *in code* must select `projectPath`, `scope`, `version` **and**
  `gitCommitSha`. It came out of round v8, whose three findings (#313/#314/#315) read as unrelated and were
  one class — the family's own verification query printed a green that could not distinguish the release
  from `main` after it, one record from two, or `project` from `local`. Closing those three by hand would
  have been the fourth round in a row to close *instances* of a class that kept coming back. Both checks
  answer the same **mention vs. use** question with a positional discriminator (check 11 the `@`-target,
  check 12 "does the block actually parse the file"), which makes this the third instance of that reasoning
  in this file. **Check 18 guards the shared source against its own documentation:** every parameter of a
  mirrored entry point must be named in the skill that documents it, because a consumer has only the mirror
  and that page — so a parameter the page never names does not exist for them, escape valves included. It
  is a repair with a measured cause (August 4, 2026): the `fold-changelog` skill told consumers to commit
  the fold *by hand* for two days after the script gained `-Commit`/`-Push`, since that improvement was
  written into this repo's lens. Four more surfaced immediately, `-Bump` and `-NoPush` among them — the
  latter being the only step where a human sees the assembled release before it is public. Two design notes
  worth keeping: the mapping and the per-parameter exemptions are declared **in the registry beside the
  registration**, the same reasoning `LibOnly` already carries, so a newly shared script cannot fall out of
  the check silently; and parameters are read via the **PowerShell parser**, because the regex first used
  for it missed a `[Parameter(...)]`-attributed parameter and would have given the gate the exact blind
  spot it exists to close. An entry point declaring *no* skill is reported in the coverage line rather than
  as an error — `ship-pr`, `fix-mojibake`, `verify-resolved-issues` and `check-script-contract` are in that
  state today, and the first three are real gaps rather than deliberate ones. This is the safety guard that
  [Derek #05](specialist-05-05-lens.md)'s `open-pr.ps1` runs before every push — and that `cut-release.ps1`
  runs before a release. **Check 23, `[plugin-kind]`, added August 9, 2026, and its reason was replaced on
  August 26, 2026 rather than left standing:** every published plugin must be `team-*` under
  `plugins/dkj-subagents/` or a way of working by name, and a name carrying neither shape is an
  error rather than a style note. Since
  [#1467](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1467) only `*-policy` /
  `*-policy-*` still carry a directory rule on the workflow side — `plugins/dkj-policy/`, the government,
  with the prime ministry at its root and each ministry a level inside it; `workflow-*`,
  `contributing-*` and `*-codex` are accepted by name and held to no location. It used to have teeth because the core team's `workflow-sessioncheck`
  hook decided what counted as a workflow by that prefix alone — that hook was retired with
  `workflow-default` under [#886](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/886), so the
  borrowed justification is gone. **What replaced it is internal to the check and stronger for it:** the
  directory half is *derived* from the name, so a plugin matching neither prefix falls through both
  branches and has its location held against nothing at all. An unprefixed name does not read untidily —
  it switches the check off for itself, silently.
- **`.github/workflows/ci.yml`** — the CI gate on GitHub: runs the lint gate and all test suites
  (`scripts/tests/*.tests.ps1`) on every PR, every push to `main` and every `merge_group` event, as the
  required check `lint-en-tests`. Before changing it, know:
  - **"The same gate" is not "the same answer".** The local gate runs on your branch, CI on the *merge*
    of your branch with the trunk, and the suite list is a glob — so a suite the trunk gained meanwhile
    does not exist locally. Read the suite count; `git fetch` and merge the trunk **before** the gates.
  - **One gate function.** The step calls `Invoke-TestSuiteGate` (`native-capture-lib.ps1`), the same one
    `open-pr.ps1` and `cut-release.ps1` call; asserts in `cut-release-guardrail.tests.ps1` keep an inline
    copy from returning. It passes `-MaxParallel ([Environment]::ProcessorCount)` deliberately (a
    four-core runner nobody sits at should not hold half its cores back). `open-pr`/`ship-pr` take the
    same parameter; the default is unchanged (#1443).
  - **Concurrency.** Pushes to `main` key their group on `github.sha`, PRs as before — never one group
    per ref, which cancelled merge-commit runs behind fold commits (#1294). It costs runner minutes on
    purpose; whether the fold commit needs a full run is left open (#1300).
  - **`merge_group` trigger** is pinned by `merge-queue-prereq.tests.ps1`: without it a merge queue would
    be a total merge outage. The fold-commit shortcut is gated on `push`, so queue entries run in full.
  - **Decisions are argued in comments directly above the key they decide** (~80% of the file is
    comment). No shared banner above `jobs:` — it is a shared append point that conflicts pairwise (#2314);
    `ci-shard.tests.ps1` holds the run above `jobs:` to a 40-line ceiling. Two branches adding different
    keys under one `runs-on:` still collide; that is accepted.
  - **The ruleset `main-ci-gate`** (GitHub → Settings → Rules) makes `lint-en-tests` required. It is
    GitHub-side state: nothing in the tree records it, `repo-settings.yml` compares it daily
    (see its bullet below). Rules: `deletion`, `non_fast_forward`, `required_status_checks`; `strict` stays
    `false`, and so do `allow_auto_merge` and `allow_update_branch`.
  - **Bypass is by actor and both bypass actors are people** (`OrganizationAdmin`, `RepositoryRole 5`).
    GitHub Actions cannot be added (422), so a workflow that pushes to `main` borrows an org owner's token
    (`FOLD_PUSH_TOKEN`, only for the push; #1506, #1507). A transfer can drop `bypass_actors` while the
    ruleset still reads `active` (#1244, #1239): check the sub-field
    (`gh api repos/DKJ-Solutions/dkj-claude-plugins/rulesets/19008062 --jq .bypass_actors`), and read the push's own answer
    (`GH013 ... is expected` = list empty, `Bypassed rule violations` = list works). A commit's author does
    not name its pusher; `gh api "repos/DKJ-Solutions/dkj-claude-plugins/activity?ref=refs/heads/main"` does
    (#1278). A blocked fold is waited out, never committed locally (#1244). A direct push that works from
    an account proves the admin bypass, not a Write role; the bypass rests on org ownership, which covers
    every repo in the org and shows on no settings page here (#1284).
  - **A conflict on a branch document: never resolve it in favour of the incoming side** — it destroys an
    unfolded DEPLOY entry, the only copy of that changelog text (PR #1249 / #1250). Per-branch document
    names removed the situation (#1255); an unfolded entry left on the trunk is reported by
    `check-unfolded-entry.ps1` (#1270, its own bullet below).
  - **`ship-pr.ps1` reads the PR's state after `gh pr merge`** rather than trusting the exit code (a queue
    exits 0 having only enqueued; #1325). An unreadable state is deliberately not a refusal.
  - **Declined: a per-decision pointer plus an argument in this lens, or one file per decision under
    `.github/workflows/ci-decisions/`** (#2314) — both buy conflict-freedom by moving the reasoning away
    from the line it explains.
  - **Declined: `strict` + auto-merge + update-branch** (#1325) — GitHub does no server-side base sync
    outside a merge queue, so they only add a block with no valve. **Declined: a merge queue** (#1355) —
    the sharding of #1351 cut the stale-certificate cost to ~37 s per merge; reopen if the fire rate passes
    ~25% or CI passes ~10 minutes. If it is ever switched on, `ship-pr.ps1` step 3b refuses before the
    queue is reached (recorded, deliberately unbuilt), whether `--merge` is accepted under a queue is
    unestablished, and `allow_auto_merge` probably needs flipping too. A queue is unavailable to a private
    repo outside Enterprise Cloud (#1546).
  - **Decided in:**
    [#932](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/932),
    [#1239](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1239),
    [#1244](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1244),
    [#1255](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1255),
    [#1278](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1278),
    [#1284](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1284),
    [#1292](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1292),
    [#1294](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1294),
    [#1300](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1300),
    [#1325](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1325),
    [#1351](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1351),
    [#1355](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1355),
    [#1443](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1443),
    [#1499](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1499),
    [#1506](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1506),
    [#1507](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1507),
    [#1540](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1540),
    [#1546](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1546),
    [#1720](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1720),
    [#1726](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1726),
    [#2314](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2314). The dated measurements are in
    this file's history (`git log -p -- .claude/specialists/lenses/specialist-05-15-lens.md`).

- **`.github/workflows/claude.yml` + `.github/workflows/claude-code-review.yml`** — the two Claude Code
  workflows: the first answers an `@claude` mention in a comment, the second reviews every PR under the
  job id `claude-review`, which is **advisory** (the ruleset names `lint-en-tests` and nothing else).
  Before changing either, know:
  - **Both `uses:` are pinned by commit SHA**, not by the moving tags: this is a public plugin source, and
    whoever can move a tag reaches every consumer through its CI.
  - **`claude.yml` runs on a read-only tool allowlist**, including the three `mcp__github_ci__*` tools the
    `actions: read` permission exists to enable. **Do not "restore" Edit/Write/Bash to make
    `@claude fix this` work** — that it only answers is the decision, not a defect.
  - **The `issues: [opened, assigned]` trigger is deliberately absent.** The action gates who triggers,
    never who wrote the text it then reads, and this repo publishes inbound issue templates, so external
    prose is a designed-for input.
  - **The `permissions:` block is not the boundary.** `id-token: write` lets the action mint an App token
    with read **and** write; the read-only scopes bound `GITHUB_TOKEN` alone. Never audit by scopes.
  - **The plugin marketplace is unpinned on purpose**: no documented ref syntax exists, and none is to be
    guessed (#566). If it ever matters, drop the plugin and write the review prompt inline.
  - **The App is not a bypass actor** of `main-ci-gate` (both actors are people; see the `ci.yml` bullet),
    so it can open a PR but not push to `main`. The knob to watch is who owns the `DKJ-Solutions` org.
  - **`claude-review` stays red on a 429**: a green tick would hide that the PR got no review (#966). The
    headline states only what the *status* proves; anything the `result` string says is attributed to
    upstream (#974, #1055, #1112). An over-claiming sentence is repaired in the workflow that wrote it,
    never in the generic relay `Get-AuthoredFailureNote` (`pr-issues-lib.ps1`), which `ship-pr.ps1` uses to
    print a failing check's titled annotation (#1103). The relay selects only a **titled** failure
    annotation.
  - **Two diagnostic steps, complementary gates**: *Why the review failed* on `execution_file != ''`, and
    a second on `execution_file == ''` (the action died before the SDK; #1245). The second may claim only
    what an empty output proves and may not mention 429, 529, quota or a reset. Every emission site keeps
    the `${headline//%/%25}` escape (#1118). `pr-issues.tests.ps1` pins both gates, the emission-site
    count, and the three lengths the 500/300/headline arithmetic rests on (#1116).
  - **After a repo transfer verify the capability, not the artefact**: the Claude Code GitHub App is an
    account-level install on the org, and the Actions secret surviving proved nothing (#1245; the spend
    limit is the same shape, #1164). A session can make the failure legible, not stop it.
  - **Declined:** letting the relay fall back to untitled annotations (#1245) — it would relay "Process
    completed with exit code 1" in every consumer. **Declined:** lowering the workflow's 300-character
    reason cap so the sum fits the relay's 500 (#1116) — the operator's console shows the same 203
    characters whichever end cuts.
  - **Decided in:** [PR #658](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/658),
    [#566](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/566),
    [#966](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/966),
    [#974](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/974),
    [#1055](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1055),
    [#1103](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1103),
    [#1112](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1112),
    [#1116](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1116),
    [#1118](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1118),
    [#1164](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1164),
    [#1244](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1244),
    [#1245](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1245),
    [#1251](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1251) (no shipped page states the
    titled-annotation contract). Measurements are in this file's history.

- **`.github/workflows/unfolded-entry.yml` + `scripts/lint/check-unfolded-entry.ps1`** — the
  skipped-fold gate (issue #1270). The workflow runs the check on every `push` to `main`; the check is
  mirrored into the workflow plugin and also driven by `unfolded-entry-sessioncheck.ps1`. Advisory, not
  in `main-ci-gate` (a required check cannot gate a push anyway). The reasoning is in
  [#1244](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1244) and #1270; the detector is
  `Get-UnfoldedTrunkEntry` in `entry-scaffold-lib.ps1`, one definition for both callers. It runs from CI
  and from the SessionStart hook because neither reaches the whole population alone, and neither calls
  `gh`. Its one false positive is the ship window (`ship-pr` pushes the merge commit, then seconds later
  the fold commit), which **this workflow's own** `cancel-in-progress: true` swallows; `ci.yml` keys every
  push on its own commit since #1294 and swallows nothing.

  **Since [#1585](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1585) the check tells a
  SKIPPED fold from a checkout that is merely BEHIND**, and that distinction is invisible from the working
  copy alone: a stale checkout still has the document on disk and still has a `CHANGELOG.md` without the
  entry, so the detector reported a fold that `fold-on-merge.yml` had already pushed. The extra question
  costs no network — `Get-TrunkGap -NoFetch` names `refs/remotes/origin/<trunk>`, and each leftover is then
  asked whether **its branch's entry is already in `CHANGELOG.md` on that ref**, via `Test-BranchFoldedOnRef`
  in `entry-scaffold-lib.ps1`.

  **It asked the OTHER half of the fold commit until
  [#1601](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1601), and that half was
  guessable rather than decisive.** The fold removes the document and adds the entry in one commit, so
  #1585 asked the cheap half — `git cat-file -e origin/<trunk>:<rel>`, is the document gone upstream — and
  fenced off absence's other causes with a gap gate: ask only when the gap is non-zero. **A gap is not a
  direction.** `HEAD..origin/<trunk>` is non-zero in a **diverged** checkout too, and there a document
  committed locally and never pushed is also absent on origin — so a fold that was still owed was reported
  as already landed, with `git pull --ff-only` as the remedy, a pull that cannot fast-forward. Filed from a
  pre-merge review as inferred rather than measured; reproduced on a fixture one commit ahead and one behind
  before the repair. The entry's presence has exactly one cause whichever way a checkout has drifted, so the
  gate is **gone rather than widened** — it was sufficient and never necessary — and the gap is still
  measured, for the wording alone.

  **The match lives in the lib and not in the check, deliberately**: `Get-FoldedEntryForBranch` is this
  tree's one definition of a folded heading, and a regex in the check would be free to disagree with it —
  the drift `Get-UnfoldedTrunkEntry` exists to prevent for the sibling question. That is exactly why #1585
  named the state instead of guarding it: doing it properly meant a lib function, which was more than that
  repair was. **`Test-BranchFoldedOnRef` returns `$null` for a question it could not ask**, and the check
  reads that as *not folded* rather than as *folded* — an unanswerable question leaves the `[ERROR]`
  standing.

  **Nothing in CI changed, and the reason is no longer the gate**: on a push to `main` the pushed commit
  **is** `origin/<trunk>`, its `CHANGELOG.md` does not carry the entry, and the leftover is reported exactly
  as before — so `fold-on-merge.yml`'s `'\[ERROR\] the trunk carries'` match is still the exact headline the
  stranded case prints.
- **`.github/workflows/fold-on-merge.yml` + `FOLD_PUSH_TOKEN`** — the fold that survives a merge the
  shipping session never sees (a queue merge or a UI merge), by running the same fold this repo
  otherwise only runs from `ship-pr.ps1`'s own next step, on every `push` to `main` (issue #1493, PR
  #1507). It re-uses `check-unfolded-entry.ps1`'s own detector and adds no second one; the workflow's
  own header comment carries the full mechanism and is the more detailed of the two.

  **It pushes as an org owner, not as the GitHub Actions app, and that is structural rather than a
  setting nobody flipped.** The default `GITHUB_TOKEN` authenticates as that app (integration_id
  15368), which is not on `main-ci-gate`'s bypass list and cannot be added to it: the app is owned and
  administered by `anthropics`, merely installed on this org, so there is no private key here it
  could authenticate as. The bypass list already carries `OrganizationAdmin` with
  `bypass_mode: always` (see the `ci.yml` bullet above), so the checkout step wires
  in `secrets.FOLD_PUSH_TOKEN` instead — a fine-grained personal access token, created by an org owner,
  scoped to **this repository only** and to **`Contents: Read and write` only** — and that identity
  clears the ruleset with no ruleset change at all.

  **It is a standing credential with an expiry, and nothing in this repo renews it.** The org caps a
  fine-grained PAT's lifetime at 366 days, so the token lapses on its own schedule whatever this repo
  does. When it does, the job keeps folding but its `git push` starts failing again — the same rejected
  shape #1499 measured, where the ruleset names both `lint-en-tests` and the merge-queue rule together,
  so read the run's own last lines rather than assume which of the two it is — and nothing else
  announces the expiry; there is no reminder ahead of it. Renewal is manual: **an org owner of
  `DKJ-Solutions`** (measured September 3, 2026: DaveKJohn, davekokbwj, maikel-bwj) **creates a new
  fine-grained PAT with the identical scope — this repository only,
  `Contents: Read and write` only — and overwrites the secret**,
  `gh secret set FOLD_PUSH_TOKEN --repo DKJ-Solutions/dkj-claude-plugins`. Today that renewal is
  tribal knowledge held by whoever created the token (Dave); this paragraph is what keeps it from
  staying that way if the 366 days run out while he is not the one reading a red run.
- **`.github/workflows/verify-resolved.yml` + `scripts/release/verify-pushed-merges.ps1`** — the
  resolves gate's second half surviving the same merge (issue
  [#1511](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1511), September 6, 2026), one
  step further down `ship-pr.ps1` than the fold above. `verify-resolved-issues.ps1` is that script's
  step 6 and ran only from the shipping session, right after its own `gh pr merge` returned; since
  [#1506](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1506) enqueues instead of
  merging, that step never runs. **What was lost is narrower than it sounds and is worth stating
  exactly**: GitHub honours the body's closing keywords on a queue merge like any other — measured on
  PR #1509, where #1506 closed on the merge and a later `-ReportOnly` run reported `every declared issue
  was already closed by the merge` — so what went missing is the *verification*, plus the repair when a
  keyword misses. That repair is the case the script was built for: eight issues across PRs #341–#343
  stayed open because those bodies carried plain mentions.

  **It repairs rather than only reporting, and that is a decision rather than a consequence** (Dave,
  September 6, 2026, answering the question #1511 raised in as many words). Report-only was the cheaper
  option and does not close the gap: `verify-resolved-issues.ps1` exits 0 whatever it finds, so a
  still-open issue would be one yellow line inside a green run, and the repair would stay the manual
  step the enqueue arm already prints. So `issues: write` is granted — the first such grant in this
  repo's workflows.

  **It is its own workflow rather than a step in `fold-on-merge.yml`, and that is what makes the grant
  narrow.** #1511 named that workflow as the obvious home and flagged the cost in the same breath:
  `issues: write` beside a job that checks out with `FOLD_PUSH_TOKEN` puts a year-long standing
  credential and issue-write in one job, and `actions/checkout`'s `persist-credentials: true` leaves
  that PAT in the workspace for every step. Here they never meet — this job checks out with the default
  hour-lived `GITHUB_TOKEN`, with `persist-credentials: false` because it never pushes. Widening the PAT
  instead would have been the other way to reach a repair, and the worse one: `Contents: Read and write`
  is where its scope stops today, and adding Issues to it would have made the standing token the one
  that closes issues.

  **The second reason for its own file is coverage, not permissions.** `fold-on-merge.yml` acts only
  when a leftover entry is found, because an entry is what a fold needs; this check has to run for every
  merge, including one carrying no changelog entry and one whose entry an earlier run already folded
  away. So it resolves its PRs from the **push** — `compare/{before}...{sha}` for the commits, then
  `commits/{sha}/pulls` for each — and reads the whole range rather than the head commit, because a
  merge queue can land a batch of PRs in one push. Neither call needs git history, which matters: the
  runner checks out at depth 1.

  **Two defects were live on its first smoke test, both exiting 0 in a way that read as working**, and
  `scripts/tests/verify-pushed-merges.tests.ps1` pins each by name. A `return ,@($shas)` guard combined
  with `@()` at the call site wrapped the result in a second array, so a six-commit range printed
  `examining 1 commit` — only the count said so. And a double-quoted jq filter does not survive the
  native-argument round trip on Windows: `.[] | "\(.number)\t..."` reaches `gh` as three arguments and
  it answers `accepts 1 arg(s), received 3`, with nothing about quoting in it. The bracket-plus-`@tsv`
  form says the same thing in characters that survive, and a suite assert reads the *recorded arguments*
  for a quote rather than the behaviour, since a fake `gh` would answer either form happily.

- **`.github/workflows/repo-settings.yml` + `scripts/lint/check-repo-settings.ps1`** — the one runner
  here whose subject is **not** this tree: daily (06:30 UTC, plus `workflow_dispatch`) it reads **GitHub**
  and compares it against `Get-ExpectedRepoSettings` in
  [`scripts/repo-config.ps1`](../../../scripts/repo-config.ps1) — seven declared facts, each carrying the
  document in this tree that states it and the date it was last measured. Before changing it, know:
  - **Scheduled, not a SessionStart hook**, because a scheduled run leaves a *dated* record (#1720);
    `workflow_dispatch` also survives GitHub suspending a schedule after 60 days of inactivity (#1726).
  - **Not in `main-ci-gate`**: a check whose subject is the ruleset, required by that ruleset, is
    self-referential and would stop the trunk over a switch only the owner can flip. **It writes nothing
    to GitHub, ever** (settings are the owner's surface; `adopt-ci-floor.ps1` follows the same rule, #1972),
    holds `contents: read` and borrows no standing credential.
  - **`bypass_actors` reads as unreadable in CI** (admins only), which is a third verdict `[?]`, not a pass
    and not a failure: compare that one field by running the script locally. Everything else comes from
    `repos/<repo>/rules/branches/main` and the repo object, not `rulesets/<id>` (no admin, no id to go
    stale, and it reports the rules *effective* on the trunk).
  - **An undeclared field is not checked.** `scripts/tests/repo-settings-gate.tests.ps1` holds the
    declaration to shape, not values: every `Field` is one the check can read, every record carries its
    `Recorded`, `Where` and `Why`.
  - **It cannot cover the session about to cause the drift** (`allow_auto_merge` was enabled live against a
    record declaring `false`, #2265). So: read the declaration before proposing a GitHub-side setting change
    (hard rule in [Sylvester's manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-05-15-manual.md#sylvesters-hard-rules),
    #1843), and `ship-pr.ps1`'s CI-wait invitation is *derived* from `Get-ExpectedRepoSettings`, never
    asserted, so a consumer declaring nothing gets no line.

  - **The fold and verify-resolved runners have a consumer-shaped twin** (#1516):
    [`scripts/task/adopt-ci-floor.ps1`](../../../scripts/task/adopt-ci-floor.ps1) carries derived copies of
    both as generated line arrays. They differ in exactly two ways (the `.workflow-scripts` plugin clone
    path, and `CLAUDE_PROJECT_DIR`); nothing else may. Nothing gates the two in sync, so **change either
    workflow and read `scripts/tests/adopt-ci-floor.tests.ps1` in the same movement**; the script itself
    refuses to run here, so the tooling will not remind you.
  - **Live rules of those two runners** (four corrections from a consumer, applied to both this repo's
    files and the twins: #1539, #1542, #1543, #1544):
    the merge stamp is **UTC**, because it is a sort key (#1542); the fold runner checks out
    `ref: main`, not the event SHA (#1543), but the ref is read once, so the trunk-gap guard can still trip
    — that refusal exits **2** and the job exits 0 on that code alone (#1586); the redundant-commit verdict
    exits **3**, which `ship-pr.ps1` reads as a stood-down success and follows with step 5c's realign
    commands (#1792) — `2` and `3` are never merged; the concurrency group is constant per trunk with
    `cancel-in-progress: false`, and a fold-only push takes a per-commit group (#1544, #2813); the red-run
    triage names **three** causes, and an absent or under-scoped `FOLD_PUSH_TOKEN` is the one to rule out
    first (#1539) — a fine-grained PAT lists repositories one by one, so a repo *created* rather than
    transferred falls outside an existing token's selection silently.
  - **Declined: `git fetch` + `--ff-only` before the fold** (#1586) — it narrows the race without closing
    it, leaving the job red rarely, which is worse than predictably red. **Declined: a session-side
    guard** (#1726) — the two pointers under "It cannot cover the session" are the repair.
  - **Decided in:**
    [#1244](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1244),
    [#1499](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1499),
    [#1516](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1516),
    [#1539](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1539),
    [#1542](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1542),
    [#1543](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1543),
    [#1544](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1544),
    [#1586](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1586),
    [#1720](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1720),
    [#1726](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1726),
    [#1730](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1730),
    [#1792](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1792),
    [#1843](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1843),
    [#1972](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1972),
    [#2265](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2265),
    [#2813](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2813). Measurements are in this
    file's history.

- **`.github/workflows/merge-on-green.yml` + `scripts/ci/pick-merge-on-green.ps1` + `scripts/lib/merge-on-green-lib.ps1`**
  — the merge that survives the *session* (the two runners above survive the *merger*): a sweep that
  picks one open PR carrying the label `merge-when-green` and runs `ship-pr.ps1` on it, so a PR whose CI
  turned green after the shipping session ended still merges. Before changing it, know:
  - **It runs `ship-pr.ps1` and re-derives no gate** (step 3b, the step-list gate, the DEPLOY lock, the
    fold and the resolves check all come with the script). Never add a gate predicate to the workflow.
  - **The arming label is the authorisation and `ship-pr` is its only writer**: it is set once the PR is
    open and before the CI wait (#2393), so it records that a session had *already begun shipping*, which
    is what the visible-result and irreversible exceptions withhold. A PR kept back for the owner never has
    it. The label creates itself on first use (`gh pr edit --add-label` fails on a missing label).
  - **The merge is made with `FOLD_PUSH_TOKEN`**: a push caused by the job-scoped `GITHUB_TOKEN` starts no
    workflow runs, which would silence `ci.yml`, `fold-on-merge.yml` and `verify-resolved.yml` on the trunk.
    The secret therefore needs `Pull requests: write`, the owner's act; until then the job fails loudly
    with a 403.
  - **`repo.allow_auto_merge` stays `false`** (#2265, #1292); this runner is the legitimate place for the
    impulse to stop waiting, and it keeps the step-3b staleness check.
  - **It ships with `-SkipLint -SkipTests`.** Omitting them re-runs the whole local suite pool (~43 min,
    #2317) inside a 45-minute cap. The green required check on the same head *is* that gate.
  - **A sweep, not an event-derived PR**: three triggers (`workflow_run`, a 30-minute schedule,
    `workflow_dispatch`) wake it and none is read for *which* PR; `pick-merge-on-green.ps1` reads the
    tracker, one PR per sweep, lowest number first. The concurrency group is a **constant** with
    `cancel-in-progress: false` (two sweeps would race to ship the same PR).
  - **`workflow_run` runs the default branch's copy** of the file, so it cannot be proved on its own PR,
    **and runs with secrets for a fork's PR**, so the job reads nothing out of the event and the picker
    refuses a cross-repository head outright.
  - **The trusted-tree shape (#2437, from #2338)**: two checkouts, `trusted-main` and `pr-branch`, both
    `persist-credentials: false`; `ship-pr.ps1` runs from `trusted-main`, with `CLAUDE_PROJECT_DIR` on
    `pr-branch`. `-TrustedRoot` (forwarded as `-SeamRoot`) forces `-SkipLint`/`-SkipTests` structurally,
    uses no worktree, and the push credential is the `GIT_CONFIG_KEY_n`/`_VALUE_n`/`_COUNT` env triplet,
    in memory only. A PR editing the two repo-owned seams ships under the trunk's answer to them;
    `Get-MergeOnGreenExecutedPathHit` refuses exactly those two files, and `.workflow-scripts/`
    permanently. `ship-pr` itself checks out the one candidate branch from a clean trunk (#1620); that
    block is a named test gap, held structurally by `merge-on-green-lib.tests.ps1`.
  - **Its consumer twin is `adopt-ci-floor.ps1`'s fourth runner** (#2329, #2449): three sibling
    checkouts (pinned `.workflow-scripts`, token-free `trusted-main`, token-free `pr-branch`); the picker
    resolves its root dual-context, and the test pins `trusted-main` as its `CLAUDE_PROJECT_DIR`. A re-run
    of the scaffolder never rewrites an existing runner of the old shape (#2553).
  - **Declined:** a runner that merges on "required check green and staleness zero" by itself (#2319) — it
    would skip gates `ship-pr` holds. **Declined:** a `GITHUB_TOKEN` merge (silences the trunk's runs).
  - **Decided in:**
    [#2319](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2319),
    [#2393](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2393),
    [#2317](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2317),
    [#2265](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2265),
    [#1292](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1292),
    [#1620](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1620),
    [#2338](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2338),
    [#2437](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2437),
    [#2329](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2329),
    [#2449](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2449),
    [#2553](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2553). Measurements are in this
    file's history.

- **`timeout-minutes` on every job — the runner-level cap, which is a DIFFERENT LAYER from the
  in-process suite bound** ([#2296](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2296),
  September 22, 2026). Until that issue no job in `.github/workflows/` declared one, so a wedged job ran
  to GitHub's **six-hour** default. Measured: run 35728958033's `suites (2)` sat `in_progress` for 38
  minutes on a commit whose other three shards were green in ~6 minutes each and whose shard 2 ran all
  29 of its own suites locally in 344s; the cancel request itself took ~8 minutes to land.

  **The failure mode is not a red check, and that is the whole reason this is worth a guard.**
  `lint-en-tests` `needs:` the shards, so it never registered at all — and a required check that never
  registers reads as *still running* to `ship-pr`, to the ruleset and to a person looking at the PR.
  `ship-pr` spent its entire 1800s registration wait and refused correctly, with the right diagnosis and
  nothing behind it; the branch still needed somebody to go and cancel the job by hand.

  **`$script:GateSuiteTimeoutSeconds` cannot cover this, and it is not the same repair.** That bound is
  1800s *per suite* inside the gate process and it reaps a wedged child **with an attribution** — #1941
  records it doing exactly that, three times, on a local machine. At 38 minutes it should have fired and
  did not, so whatever wedged sat **below** the level a bound inside the process can reach. That is the
  one class a runner-level cap exists for, and it is why this is a different layer from
  #1941/#2233/#2255/#2263 rather than a fifth argument about the same constant.

  **The numbers are read off run history, and the one on `suites` is picked against `ship-pr` rather
  than against the suites.** Over the 19 most recent successful runs the shards measure (1) max 9.2m,
  (2) max 13.4m, (3) max 7.4m, (4) max 8.5m — so any cap in the twenties is ~2x the worst ever observed.
  What decides the upper end is that `ship-pr`'s registration wait is **also** 1800s
  (`$maxRequiredWaitSec`): a cap of 30 or more times the job out at the same moment the shipping session
  gives up, so the session learns nothing and the incident repeats *with a cap in place*. At **25** the
  shard goes red, the summary concludes seconds later, and `ship-pr` — still listening — reads a failed
  required check with a job log naming which shard. `lint` is 10, the summary 5, every short runner 10,
  and the two agent jobs 60, because their runtime is the model's work rather than a script of ours.

  **And the consumer half is the one no gate here could ever see.** Every runner this workflow scaffolds
  carries a cap too — `adopt-ci-floor.ps1`'s four, `adopt-workflow-folder.ps1`'s two,
  `adopt-shopify-floor.ps1`'s theme check, and (until October 5, 2026, when the template was retired)
  the `asana-mirror.yml` template — because a wedge there
  blocks a *consumer's* required check with nobody watching at all. The skeleton `ci.yml` is deliberately
  the loosest of them at 30, and says in its own comment that it is the one number you re-size when you
  replace the placeholder step with real work. [`scripts/tests/workflow-timeouts.tests.ps1`](../../../scripts/tests/workflow-timeouts.tests.ps1)
  holds all four properties, including the `suites`-versus-`$maxRequiredWaitSec` inequality, which it
  derives from both files rather than hard-coding either.

- **`scripts/lint/check-git-identity.ps1`** — the split-identity check (issue
  [#1315](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1315), September 3, 2026): does
  this checkout commit as the same account it acts as on the tracker? The claim rule's `@me` resolves
  through the GitHub API, so it writes whichever account `gh` holds, and nothing compared that against
  `git config user.name`. Measured on DAVE-KOK-BWJ, where `gh` is `DaveKJohn` and `git` is `davekokbwj`:
  the documented idiom put the wrong account on #1314, and the cross-device tell in
  [Derek's lens](specialist-05-05-lens.md#branch--repo-hygiene) — a branch whose commits name a different
  account than the checkout — fires there **by construction**, so it reads "built elsewhere" off a branch
  that never moved.

  **It has ONE caller and deliberately no CI half**, which is where it differs from every other check on
  this page: the finding is a fact about the *machine*, not about the tree, and a runner authenticates as
  a bot and commits as one — a mismatch by design that would fire on every push. The moment that matters
  is a session's start, just before it claims an issue and begins committing, so
  `git-identity-sessioncheck.ps1` (workflow plugin) is the whole delivery. It is in no gate and never
  will be.

  **Two design points that look arbitrary and are not.** It compares *names*, not emails, although GitHub
  attributes a commit by email — because `gh api user` returns a null email for an account with no public
  one and `gh api user/emails` needs the `user` scope, which this family's tokens do not carry; widening a
  token scope to print an advisory line is the wrong trade, and `gh auth status` reads the active account
  from the keyring with no network at all. And it fires **only when `user.name` is a valid GitHub username
  by GitHub's own rule** — 39 characters, single hyphens, none at either end. That guard is the whole
  reason the check is shippable: `user.name` is free text and usually holds a person's name, so an
  unconditional comparison would fire forever in every consumer that spells its name normally, which is
  precisely the shape of the stale-path check
  [declined further down this page](#how-the-gate-checks-got-their-shape-and-the-measurements-behind-them-august-15-2026)
  at 124 findings all false. The three accounts in this family are all login-shaped, so the measured case
  is still caught. `git-identity-gate.tests.ps1` walks both edges of that rule, and passes both identities
  in explicitly — a suite that read the machine's own would assert something different on every checkout.
- **`scripts/lint/check-consumer-prose.ps1`** — the consumer-prose check: **two detectors over one
  corpus, read once** (merged from two scripts and two hooks, #1421), delivered at session start by
  `consumer-prose-sessioncheck.ps1` (workflow plugin). One flags a consumer's always-on prose that still
  names a *retired* name of the branch's development document (#1389); the other flags prose declaring the
  consumer's own `CLAUDE.md` the winner over `dkj-policy/CONTRIBUTING.md`, inverting the rank order
  (#1415). Both are the narrow literal greps the declined prose-contract framework recorded as the
  proportionate alternative. Before changing it, know:
  - **Both detectors always run**; the first finding never short-circuits the second.
    `consumer-prose-gate.tests.ps1` pins it (only the rename: one block; only the inversion: the other;
    both: exactly two `[ERROR]` markers from one invocation).
  - **One caller, no CI half, and it skips the publishing repo** (the source-repo guard's condition 2).
    The skip is a *repair* for the retired-name half (this repo narrates the rename history on purpose) and
    only a *guard* for the supremacy half (zero hits here).
  - **The corpus has one definition**, `Get-ConsumerProseDocuments` in `entry-scaffold-lib.ps1`: the
    always-on closure plus the workflow folder's permanent pages, minus the changelog, `releases/`,
    plugin-shipped payload and a per-branch document. Each exclusion is load-bearing; a new one goes there,
    never into a second copy.
  - **Retired names are derived** (`Get-RetiredDocNameMention`, names from `Get-BranchFileLegacyNames`), so
    there is no second list to maintain. Stated gap: the `development-<slug>.md` *shape* is not a token
    and is not matched, because matching a shape needs a wildcard (#1389).
  - **The supremacy detector reads ADJACENCY, not co-occurrence**: `CLAUDE.md` beside `wins`/`wint`. The
    three-term test scored 0 recall because the real sentence names the contributing page by a prose noun,
    and only adjacency reads *direction* (#1415). Its one suppression, a hit wholly inside a `"…"` span,
    rests on one instance and is pinned from both sides by the suite. Paragraph joining stays, because it
    closed a wrapping false negative.
  - **Measure a pair, never a figure**: durations run double or half depending on box load, so a duration
    assert compares against its queue rather than a fixed ceiling (#1401).
  - **Declined:** a prose-contract framework or any wildcard/fuzzy matching (see
    [the gate-checks index](#how-the-gate-checks-got-their-shape-and-the-measurements-behind-them-august-15-2026)).
  - **Decided in:**
    [#1380](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1380),
    [#1389](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1389),
    [#1401](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1401),
    [#1415](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1415),
    [#1421](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1421). The measurements (the
    ~457 ms saved per session start by the merge, the per-hook figures) are in this file's history.
- **`scripts/lint/check-consumer-drift.ps1`** — the read-only drift check against a consuming repo
  (`MISSING`/`IDENTICAL`/`DRIFTED`).
- **`scripts/lib/plugin-tree-lib.ps1`** — the one answer to *which plugins does this repo publish, and
  where does each one's folder sit*, read from `.claude-plugin/marketplace.json`. Five scripts used to
  answer that themselves, each by encoding the layout: a hand-written list of four directories in the
  drift check, a `^plugins/<name>/` regex with an exception for the one sibling that is not a plugin, a
  path-segment index in the shared-scripts registry, three `Split-Path`s upward from a `plugin.json`,
  and a `Join-Path <plugins root> <name>`. None of those is a fact about plugins; they are facts about
  one layout, and this tree has moved twice. Dependency-free on purpose: one caller runs at
  SessionStart (`check-connectors.ps1`, via `connector-sessioncheck`) and another is the fold, which
  runs straight after a merge on the trunk. Mirrored, because `release-lib.ps1` dot-sources it.
- **`scripts/lib/branch-info.ps1`** — the prefix→label→changelog-type table (shared with the
  release scripts). Deliberately no `release` prefix: a release does not go via a branch/PR but
  directly on `main`.
- **`scripts/lib/pr-issues-lib.ps1`** — the pure decision table of the **resolves gate**: which issues
  a text mentions, which a body actually *closes*, and whether a PR may open without declaring either.
  Deliberately pure (no `git`, no `gh`, no filesystem) so [Tycho #18](specialist-04-18-lens.md) can assert
  every branch of it offline; the one impure part — asking GitHub which issues are open — stays in
  `open-pr.ps1`. Shared/mirrored, since `open-pr.ps1` dot-sources it. The rule it enforces and the
  incident behind it are [Derek #05](specialist-05-05-lens.md#opening-a-pull-request)'s.
  **Two traps that cost real debugging while building this lib**, both measured and both now pinned by
  asserts:
  - **`powershell -File` cannot bind an `[int[]]`.** `-Resolves 332,340` arrives as the string
    `'332,340'` and is cast to the single number **332340** — the comma read as a *thousands
    separator*. No error, just a wrong issue. Hence a `[string]` parameter parsed by
    `ConvertTo-IssueNumberList`, and hence the fixture passes it over that same `-File` hop.
  - **`@(… | ConvertFrom-Json)` does not flatten a JSON array in PowerShell 5.1.** 5.1 emits the
    parsed array as *one* pipeline object, so `@()` collects a single element that IS the array, and
    `$_.number` then does member enumeration and hands `[int]` an `Object[]` that throws. Assign
    first, then wrap: `$parsed = … | ConvertFrom-Json; @(@($parsed) | …)`. That throw was swallowed by
    a `catch` that degrades the gate to "cannot check" — so the gate silently never blocked **while
    every pure unit test stayed green**. Only the wiring fixture caught it, which is the general
    lesson: a pure decision table proves the decision, never that it is reached.

    **IT HAS NOW FIRED TWICE, IN TWO UNRELATED SCRIPTS, SO TREAT IT AS A CLASS RATHER THAN AS THIS LIB'S
    INCIDENT** (August 14, 2026). The open-issues block of `session-status.ps1` — the reporter behind
    `/lock` and `/handover`, removed with them by #957 — carried the same one-liner and
    printed `#System.Object[]  System.Object[]` for three open issues — in this repo *and* in every
    consumer's mirror, since both those skills told a consumer to run it. Grep for
    `@(` immediately followed by a command piping into `ConvertFrom-Json` before adding another.
    **Two things that measurement added, neither of which the original write-up had:**
    - **At exactly ONE record the broken form is correct**, because member enumeration over a
      one-element array yields that element's own value. So the defect is invisible at 0 or 1 and only
      shows at 2+ — which is how it survived in a repo that usually had one open issue or none. A test
      that covers the populated case with a single record proves nothing; use three.
    - **`.Count` is `1` whether the array holds zero items or thirty**, so an `if ($x.Count -eq 0)`
      guard behind this pattern is **unreachable**, and the empty case falls into the populated branch.
      Here that printed a bare `#` with two empty fields. Fix and test *both* branches: the visible
      symptom is the populated case, the silent one is the empty case.
- **Two lessons that outlived the file they were measured in.** `scripts/task/session-status.ps1` — the
  reporter behind `/lock` and `/handover` — was removed with both skills on August 27, 2026
  ([#957](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/957), Dave). Its open-issues block
  had been repaired on **August 14, 2026**, and that repair cost two lessons beyond the
  `ConvertFrom-Json` trap above. Neither is about the deleted script, so both are kept:
  - **A `2>$null` on a native command makes its `catch` unreachable, so check `$LASTEXITCODE` instead.**
    The older of the two defects: an unauthenticated or offline `gh` throws nothing and prints nothing,
    so `ConvertFrom-Json` never ran, the pipeline yielded nothing, and the block reported **`none`** —
    *"we could not ask"* printed as *"there are none"*. The wrong answer that looks like a right one, and
    it had quietly disabled the degrade line that script's own docstring promised for **every** optional
    source. The redirect is still correct (a stderr dump is not a status report); what it costs is the
    throw, so the exit code is read explicitly and the `catch` kept only for a payload that arrives and
    does not parse.
  - **No `return` inside a reporter's section blocks.** They sit at **script scope**, where `return` exits
    the whole script — so an early return in the middle of one silently drops every block below
    it while still exiting `0`. Caught during the fix above, before it shipped: the degrade path is an
    `else`, and an assert pinned that a block *after* the failing one still printed.
- **`scripts/lib/release-lib.ps1`** — the pure release helpers (version bump, emptying `CHANGELOG.md` down
  to its intro, and the assembly of the changelog notes under `dkj-policy/releases/changelog/`)
  that [`cut-release.ps1`](../../../scripts/release/cut-release.ps1) dot-sources; deliberately
  pure so [Tycho #18](specialist-04-18-lens.md) can test them in isolation. The release *process* is
  [Rendall #06](specialist-05-06-lens.md)'s domain; Sylvester guards the script mechanics underneath.
- **`scripts/agents/build-agent-defs.ps1` + `scripts/lib/subagent-shared-lib.ps1`** — the generator
  that fills the verbatim-shared bullets from
  `plugins/dkj-subagents/subagent-shared/<name>.md` into all agent defs (between
  `<!-- BEGIN/END shared:… -->` sentinels). Change a shared block →
  run `build-agent-defs.ps1` → all agent defs updated; `-Check` (and the lint gate, check 7) fails
  on drift. The pure expansion logic lives in the lib, so [Tycho #18](specialist-04-18-lens.md) can test
  it in isolation — mirroring the `release-lib` setup. **Never edit between the sentinels by hand.**
- **`.claude/settings.json`** — this repo's harness config: the `extraKnownMarketplaces` (the
  `github` source `DKJ-Solutions/claude-code-specialists`) and `enabledPlugins` with which the repo enables
  its own `dkj-subagents-alpha` plugin (the core team).
- **The manifests** `.claude-plugin/marketplace.json` and every `<plugin>/.claude-plugin/plugin.json`
  (structure + `version`) — their *structure/config*; the descriptive *texts* he coordinates with
  [Tessa #16](specialist-06-16-lens.md).

#### And therefore: here Sylvester is the author who runs `simplify`

The **`simplify`** skill applies quality fixes — reuse, simplification, efficiency — and applying is the
**author's** act, never the reviewer's: [Victor #19](specialist-06-19-lens.md) may report those same findings
and is forbidden from applying them, which is why the portable layer gives the skill to
[Cody #13](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-04-13-manual.md) rather than to a reviewer. Here
the code is `scripts/**` and **those are Sylvester's**, so here he is that author: he runs the tidy pass
over what he changed before the diff goes to review, and never over somebody else's change.

**Why this line exists in his lens and not only in Chris's** — Sylvester does not read Chris's lens, so a
routing line alone would name an owner who is never told. And why it is not in his *portable* playbook:
his shipped scope is the **harness** (`.claude/`, settings, hooks, MCP, skills, marketplaces), while
`scripts/**` is an extension this lens gives him. Writing the skill into his agent def would claim script
authorship for him in consumers that never granted it.

### The sibling check, and the one axis this repo's checks never looked along (September 11, 2026, #1869)

Every check in `connectors/` ran **source → consumer**: `check-consumer-drift.ps1` compares a consumer's
agent-def copies against this source, `check-connectors.ps1` asks whether a consumer's register record is
true. [`check-consumer-siblings.ps1`](../../../scripts/sync/check-consumer-siblings.ps1) is the first that
runs **consumer → consumer**, and the gap it closes is not a missing check so much as a missing *question*.

**The measurement.** Of the 48 tooling paths the two BWJ stores share, 47 have diverged, and the one that
has not is a verbatim template this marketplace ships. The load-bearing instance is `prune-merged.ps1`:
inbound [#815](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/815) asked for it centrally,
`dkj-policy` 4.21.0 shipped it, one store converged on August 28 and the other still carried its own
120-line copy three weeks later. **The inbound route worked and nothing propagated the result to the
second consumer** — so *"shipped centrally"* and *"used centrally"* are different facts, and no check here
held both at once.

**Why it could not be seen from inside a consumer, which is why it is a source-side script.** Their own
rule asks *"does the plugin provide this?"* — a one-repo question. The sibling is a repo that session never
opens, and by the time it would matter the **names have drifted apart**, so no grep finds the pair:
`market-domains.ps1` against `market-urls.ps1`, both exporting `Get-MarketPreviewUrls`.

**Three design decisions worth not re-litigating:**

- **The grouping is declared (`siblingGroup`), never inferred.** Every consumer of this marketplace shares
  `dkj-policy`, so a plugin-set inference groups `life-hub` with a Shopify store and reports a
  personal-life repo as missing a theme-archive mechanism. The reasoning is in
  [the register's page](../../../connectors/README.md#the-manifest-format); the assert that keeps it that
  way is case 4 of [`sibling-divergence.tests.ps1`](../../../scripts/tests/sibling-divergence.tests.ps1),
  and it is the one a later "just group by plugin set" change would delete first.
- **The exclusions are the difference between a report and a wall.** Lenses, `SPECIALISTS.md`, the seam,
  `.claude/memory/` and the GitHub boilerplate are repo-specific **by design** — agreement there would be
  the defect. They remove 27 of the 48, leaving 21 actionable. **The test suites are deliberately kept
  in**, and that assert exists because excluding them is the plausible next move: they are noisy, and they
  are also mechanism.
- **One read route per group, always.** A blob sha (the `gh` route) and a content hash (the disk route) are
  not comparable, so a group whose members cannot all be read the same way is reported unreadable rather
  than compared. A mixed vocabulary would report *every* path as drifted — a false alarm shaped exactly
  like the finding the check exists to make, which is the worst possible failure for a detector nobody is
  obliged to believe.

**`Test-GitHubOwnerNameSlug` moved to `check-report-lib.ps1` in the same branch**, from inside
`check-connectors.ps1`. Its own docstring had already argued the case — it was factored out *within* that
script so two call sites could hold one field to one bound rather than keep "a second, silently drifting
copy of the regexes" — and a third caller outside the file is that argument one step further on. The rule
this follows is the repo's own: a semantic decision gets one source (#309).

**It reports and never prevents, and that was Dave's call** on September 11, 2026, choosing the
detector-first shape over moving ownership immediately. `-FailOnFinding` exists; nothing passes it. The
converging — which of `dkj-policy` and `bwj-development` should own `test-lib.ps1`, `lint-brain.ps1` and the
market/theme mechanisms — is the follow-up, and it is an ownership decision rather than a repair a script
can make.

#### The ruling that followed, and the first thing moved under it (September 11, 2026, #1881)

**Anything the two stores share goes to `bwj-development`, unless it is obviously universal** (Dave, on
[#1881](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1881)). The portable statement, the
price it accepts and the second question a store has to ask before building anything are in
[that plugin's own README](../../../plugins/dkj-policy/bwj-development/README.md#what-this-plugin-owns),
because they are read in a store repo rather than here. What belongs in this lens is the part that is
this repo's:

- **The ruling widened a plugin that said it carried no mechanism.** `bwj-development`'s README opened with
  *"policy, never mechanism"*, written when its only non-prose payload was `templates/`, which a consumer
  **copies**. A lib a consumer **dot-sources** is a second kind of payload, so the line was widened rather
  than quietly broken — the distinction that survives is copy-vs-dot-source, not prose-vs-code.
- **The first increment is [`scripts/tests/test-lib.ps1`](../../../plugins/dkj-policy/bwj-development/scripts/tests/test-lib.ps1)**,
  and it was chosen because it is the case where merging is a *decision* rather than a diff: each store's
  copy was ahead of the other. One had `ConvertTo-CapturedText` and `Add-SuiteFault`, both born from a
  **false green in the gate these suites are read by**; the other had `Assert-PluginLoadedForProject`, born
  from a plugin administration pointing at a folder that no longer existed; and the second was still in the
  language the first had been translated out of a month earlier. What ships is the superset, in English.
- **It has a suite here even though nothing here uses it** —
  [`bwj-test-lib.tests.ps1`](../../../scripts/tests/bwj-test-lib.tests.ps1). Shipping it without one would
  put the file straight back in the position #1881 was filed about: a mechanism with no owner watching it,
  one edit away from drifting again, this time *inside* the plugin where no consumer-to-consumer check can
  see it. The suite holds three things, each a way the convergence comes undone: the superset, the
  behaviour of the two false-green mechanisms, and the language.
- **The suite runs the lib in a CHILD PROCESS, and that is load-bearing rather than stylistic.** The lib
  sets `$script:Pass`/`$script:Fail` and defines `Assert-True` in the scope of whoever dot-sources it, and
  PowerShell names are case-insensitive — so dot-sourcing it into a suite here would silently replace that
  suite's own counters and its own `Assert-True` with the ones under test, and a broken lib could report
  itself green.
- **One class the ruling does not cover, found while reading for it:** `dkj-subagents-shopify` already ships
  `push-preview.ps1`, `sync-main.ps1`, `preview-theme.ps1` and `sync-rules.ps1`, and one store still carries
  its own full copy of three of them. That is an **adoption gap**, not an ownership question — and no check
  here reports it, because `check-consumer-drift.ps1` compares agent defs and personas only, while the
  sibling check compares consumer to consumer and never against what the marketplace already ships. Filed
  as [#1885](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1885); the remaining convergence
  candidates, each with its verdict under the ruling, are
  [#1886](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1886).

### Repo-specific rules

- **NEVER ROUND-TRIP A MARKDOWN FILE THROUGH POWERSHELL TO EDIT IT — USE THE EDITOR'S OWN EDIT.**
  Measured twice in one session, August 15, 2026, both times on a lens. `Get-Content -Raw` reads with the
  **ANSI codepage** in Windows PowerShell 5.1, so every em dash, `·` and emoji in a repo whose documents
  are full of them comes back as mojibake; writing that back produced **127 corrupted sequences** in
  `specialist-06-25-lens.md` in a single command. The second failure is quieter and has no lint behind it: a
  **double-quoted** PowerShell string eats backticks as escapes, so a line containing `` `v1.0.0` ``
  silently became a **vertical tab** plus `1.0.0` — valid UTF-8, invisible in a diff, and past every
  check here.
  - **The repair for the first is already built**:
    [`fix-mojibake.ps1`](../../../scripts/maintenance/fix-mojibake.ps1) peels the inverse round trip and
    repaired all 127 in one run. Verify by diff afterwards — `111 insertions(+), 0 deletions(-)` is what
    proves nothing else moved.
  - **The second has no gate, deliberately not proposed as one.** A vertical tab is legal in markdown and
    a rule against control characters would be a check written for one careless afternoon. The answer is
    not to write the file that way: use the harness `Edit` tool, or single-quoted strings and
    `[System.IO.File]::ReadAllText/WriteAllText` with an explicit
    `New-Object System.Text.UTF8Encoding($false)` when a script genuinely must do it.
  - **Why it belongs here rather than in the language rule.** This is not a language-layer question — it
    is the mechanism by which any specialist edits any document in this repo, and it fires hardest on the
    files that carry the most prose. It cost nothing both times only because the lint's mojibake check
    caught the loud half within minutes.
- **The shared-scripts registry spans TWO plugins since August 8, 2026, and the plugin is read off the
  mirror path rather than declared.** `Get-SharedScriptPairs` maps each source to a mirror in either
  `plugins/dkj-subagents/dkj-subagents-alpha/` (the core: `check-roster-sync`, `check-report-lib`) or
  `plugins/dkj-policy/` (everything branch- and release-shaped). Three things to
  know before touching it:
  - **`SkillRel` is derived from `MirrorRel`, not stored.** Check 18 and `shared-scripts.tests.ps1`
    both used to look for a script's documenting page at a hardcoded `plugins\teams\team-alpha\skills\…`,
    and the moment nine entry points moved, the gate reported every one of their existing skills as a
    typo. A second field naming the plugin would have been free to disagree with the path beside it;
    deriving it means a script that moves takes its page lookup with it.
  - **`check-report-lib` is registered TWICE on purpose** — one source, two mirrors — because
    `check-roster-sync` stayed in the core while `check-script-contract` went to the workflow. The
    alternative, a mirror reaching into the other plugin's cache, was rejected on sight: separately
    versioned, separately installed, so a version mismatch breaks it silently. **A duplicate entry
    needs a distinct `Name`**: the suite looks pairs up with `Where-Object { $_.Name -eq … }` in
    eleven places and would get an array back.
  - **The thing that parked this work for days was a MENTION read as a USE — the fifth instance in
    this file.** The note that stopped it said `check-report-lib` and `native-capture-lib` each had
    readers in both halves. Neither did: `open-pr`/`fold-changelog-entry` name the first only in a
    comment, and `check-report-lib` names the second to say it *needs none of* its EAP dance. Both
    rows dissolved on being read. The assert that now refuses any mirror dot-sourcing a lib from the
    other plugin is in `shared-scripts.tests.ps1` — write the check that would have caught the
    misreading, not just the fix.
- **A scaffold with nothing to fill in is invisible to a placeholder test.** The same split gave a
  core-only consumer a `repo-config.ps1` holding just the roster pair — complete as generated, so no
  `VUL-IN` value anywhere. `specialists-teardown` classifies by placeholder VALUE (the #333 lesson),
  so it read that file as authored and would have kept it forever, making adoption exactly as
  irreversible as that skill promises it is not. The second recognised shape keys on "still exactly
  what the bootstrap wrote", which is conservative in the right direction: every way an owner can
  touch that file ADDS something. **General rule: when a generator gains a mode that emits no
  placeholder, check every consumer that classifies its output by one.**
- **The agent-def frontmatter and the `plugin.json` `version` land here first**, never in a consuming
  repo — those pull them in. An agent-def config change is Sylvester's side; the agent-def *text* is
  Tessa's side.
- **The lint gate may never become quieter than the risks.** As the repo grows (more plugins, more
  complex manifests), Sylvester extends the checks — with [Tycho #18](specialist-04-18-lens.md) building
  tests alongside.
- **The test gate is bound by its SLOWEST SINGLE SUITE, not by their sum — so the next second saved is
  bought inside one file.** Measured August 7, 2026 on the same machine within one session, all 27 suites
  green every time: **510s one at a time, against 128–263s parallel over six runs (median 159s)**
  ([#512](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/512)). **That spread is the mechanism,
  not noise** — a sum averages its own variance out, a maximum does the opposite, so a gate bound by its
  slowest suite is inherently less predictable than one bound by the total. Quote the range rather than the
  best run: the first parallel measurement taken was the 128s one, and on its own it would have promised a
  4× improvement the gate delivers only sometimes. **CI gains less, and for a stated reason:** its runner
  has four cores against this machine's eighteen, so the throttle is four wide and the `lint-en-tests` job
  went from about eleven minutes to **7m2s**. What made that safe rather than
  lucky was checked before it was built, not after: no suite writes into the repo tree (every `$RepoRoot`
  reference is a read, or a `Copy-Item` *out of* it into a fixture), and no two suites share a fixture path
  — the fixed-name ones each own their name, the rest key on `$PID`. **Re-check both before adding a suite
  that touches either.** The remaining half of #512 is now the whole critical path:
  `check-plugin-integrity.tests.ps1` spends its ~154s on **86** `Invoke-Integrity` calls, each a fresh
  `powershell` start (~0.18s) plus a full lint over its fixture (~1.6s) — real work, not waste, and it
  cannot be parallelised the way the gate was, because all 86 scenarios mutate **one** fixture directory in
  sequence. `-MaxParallel 1` is the valve, and it is worth reaching for before believing a suite that only
  fails with 30 siblings competing for the disk.

  **THE LAST CLAIM IN THAT PARAGRAPH WAS WRONG, AND IT IS KEPT ABOVE SO THE CORRECTION HAS SOMETHING TO
  CORRECT** (August 16, 2026, [#714](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/714)).
  "It cannot be parallelised the way the gate was" reasoned from the wrong unit: the scenarios do all
  mutate one directory in sequence, but the gate schedules **files**, not scenarios — so the suite could
  be given the idle lanes by becoming four files, each with its own fixture, without touching the
  sequence inside any of them. It now is: `check-plugin-integrity-{links,commands,entries,docs}.tests.ps1`
  over a shared `check-plugin-integrity-fixture.ps1`, same 110 invocations, **~51s across four lanes
  instead of ~160s in one**, asserts unchanged at 234. By then the paragraph above had been measured
  again and was worse than it read: the gate's total EQUALLED this suite to a tenth of a second, four runs
  out of four, with 15 of 16 lanes idle for its last 70-86 seconds. **The generalisation worth keeping:
  when a gate's cost is one file, ask whether the work has to be one file before asking whether it has to
  be done.** The convention for the four is in [Tycho #18](specialist-04-18-lens.md#the-lint-gate-suite-is-more-than-one-file-august-16-2026-split-again-september-22-2026).
- **Do not hand-roll a second parallel runner — and re-run a red suite alone before believing its assert.**
  Measured August 12, 2026: a `Start-Job` fan-out over all **31** suites reported **6** failures —
  `subagent-shared`, `bootstrap-drift`, `config-blueprint`, `fix-mojibake`, `roster-sync`,
  `verify-resolved-issues` — two of them asserting *"lint gate green on the repo"* in as many words, which
  reads like a finding about the repo rather than about the runner. **Every one of the six passes when run
  alone**, and `open-pr` then ran all 31 green in **218s**. What the six share is that they scan the **live
  repo**: three (`subagent-shared`, `bootstrap-drift`, `fix-mojibake`) by invoking the lint gate over it, the
  other three by running their own repo-wide scanner — `build-config-blueprint.ps1`,
  `check-roster-sync.ps1`, `verify-resolved-issues.ps1`. So 31 at once collide over one tree, which is the
  same collision the paragraph above describes, in its strongest form to date. **Read that list before
  adding a suite that touches the tree**, and note that the shared condition is the tree rather than the
  gate — keying the lesson on the lint gate alone would exempt half the affected suites. The lesson is
  **not** "never run the suites in parallel": `open-pr` parallelises
  them, is the tested runner, and was checked against exactly the two conditions above before it did — no
  suite writes into the tree, no two share a fixture path. A hand-rolled runner is checked against neither,
  so its red is evidence about the runner, not about the suite.

  **And the tested runner has now done it too, three times — so the second half of that lesson stands on
  its own.** *Re-run a red suite alone before believing its assert* was written for a hand-rolled runner;
  the reds of August 16 (`bootstrap-drift`, `fix-mojibake`, post-split pool) and the **11 of 54** reported
  out of the `v4.22.0` cut in
  [#1033](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1033) both came out of
  `Invoke-TestSuiteGate` itself. Neither reproduces: five full runs on that tree were all green, and the
  release's 443s "green" figure turns out to be a **2x-load** reading rather than the gate's cost — the
  numbers are in [Nolan #25](specialist-06-25-lens.md#a-gate-verdict-that-moves-is-a-load-reading--n5-and-the-caller-is-not-a-variable-august-28-2026).
  Six of those eleven scan the live tree and five do not, so the collision above explains part of it and
  nothing explains the rest. Do not read a lone red from the pool as a finding about the tree until it has
  been run alone.
- **A count in these documents is either DATED or LIVE, and the two are maintained in opposite directions.**
  The 27 above is a dated measurement and stays 27 — the 510s-vs-159s figure beside it means nothing when
  paired with any other count. The 30 in the paragraph above is live advice about what to try next, so it
  tracks the tree. Where a sentence is dated **and** the count carries none of its argument, the count is *removed*
  rather than refreshed: that is why [`CLAUDE.md`](../../rules/this-repo.md)'s *"`open-pr` runs the lint and every
  test suite"* now states no number under its August 7 stamp. It read `26` there for five days — wrong on the
  day it was written, since there were 27, and wronger every suite since. **And a bare `26` is still correct
  in two other senses**: the lint's own checks (`CHANGELOG.md`) and the agent-def count
  ([`plugins/dkj-subagents/README.md`](../../../plugins/dkj-subagents/README.md), [Ravi's lens](specialist-06-24-lens.md#why-each-circle-is-the-width-it-is)). Establish
  which noun a `26` governs before touching it; a find-and-replace here breaks correct statements to repair
  one.
- **Renaming or moving this checkout unlinks its own plugin install — plan the re-install into the same
  move.** Because this repo consumes itself, it is a consumer like any other, and the install record is
  keyed on `projectPath`. Measured August 3, 2026: after the directory was renamed from
  `davekjohns-workshop` to `claude-code-specialists`, `.claude/settings.json` still enabled
  `specialists@claude-code-specialists` correctly while the machine's only record named the old folder,
  so the session loaded no subagent, skill or hook at all. Recognize it by a **deliberate** run of
  [`check-roster-sync.ps1`](../../../scripts/sync/check-roster-sync.ps1) reporting
  `[NOT-INSTALLED-HERE]` — the session-start hook cannot report it, because that hook ships in the
  plugin that did not load. The repair is `claude plugin marketplace update dkj-claude-plugins`
  followed by `claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project` from the new
  root, after which a leftover record naming the old folder is expected and inert. The mechanism, the
  other two ways a record goes missing, and why that leftover is not a stray duplicate were in the
  family's root `INSTALL.md`, retired on September 24, 2026; its release notes carry them.
- **The marketplace clone follows a REFRESH, not a push — and no version check can tell you it is
  behind.** The clone is what a document named by an absolute `@`-import reads — the orchestrator's
  body, in every repo here — and it advances only on
  `claude plugin marketplace update dkj-claude-plugins`. Measured August 23, 2026
  ([#845](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/845)): after four PRs merged and
  pushed, the clone still stood on the previous day's `3e46b3de` while `main` was at `86f1a6c8` — the
  cached manual missing a section added that morning, the cached shared block missing a rule added that
  afternoon — and **every check reported OK**. `/plugin` had nothing to do, and
  [`check-connectors.ps1`](../../../scripts/sync/check-connectors.ps1) reported `[OK] machine record is
  on the source version (v4.18.0)`. Both compare **version strings**, and between two releases the
  version is unchanged by definition, so a clone any number of commits behind `main` is
  indistinguishable from a current one. This is the failure check 11 in
  [`check-plugin-integrity.ps1`](../../../scripts/lint/check-plugin-integrity.ps1) already names in its
  own comment — *"a stale cache reports success with a plausible version number"* — reaching the source
  repo rather than a consumer. The repair is that one refresh, which moved the clone immediately.

  **Detection is deliberately left as it is, and that is the answer rather than a postponement**
  (Dave, August 24, 2026). Having `check-connectors.ps1` compare **commits** instead of versions was on
  the table and was declined on mechanism: its version verdicts are per **consumer checkout**, and a
  consumer's clone is *supposed* to follow the releases rather than `main`, so between two cuts a commit
  comparison would report a gap on every consumer where nothing is wrong — the same shape as the
  stale-path check this repo declined at 124 findings all false. Nothing was damaged here either: a
  session read payload a few hours older than `main` carried, which for content merged the same day is
  the ordinary state. What was wrong was the **expectation** — [`CLAUDE.md`](../../rules/this-repo.md) promised
  the "last pushed" version — and that sentence is what the repair changed.

  **The same property makes this the one channel on which a file RENAMED here reaches a consumer with no
  version behind it** (September 19, 2026,
  [#2128](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2128)). A consumer's
  `SPECIALISTS.md` names the orchestrator's body by absolute literal path, `bootstrap.ps1` never rewrites
  that line once written, and the clone it resolves against tracks `main` — so a rename on `main` kills
  the import on their next refresh, with no release and no bump in between.

  **And a dead `@`-import is SILENT, which had been asserted since #874 but never measured.** Measured
  here in an isolated checkout, because upstream documents none of it: the rest of the file **loads
  normally** — a broken import is not fatal — and **nothing is reported**, not on stdout, not on stderr,
  not under `--debug`. The consumer loses the whole imported document and the session carries on as
  though it were there. **One detail of check 28's own wording was wrong and is corrected**: it said
  Claude Code *drops* the import, and the line is not dropped — the raw `@path` survives in context as
  inert text. That is worse rather than merely different, because a reader inspecting the assembled
  context sees the line and concludes the import happened. Nothing else about check 28 changes; the half
  it exists for is now measured rather than asserted.

  **The measurement check 11's comment relies on had never reached this boundary. It has now, and the
  answer is worse than the guess** (September 10, 2026, Claude Code 2.1.267, on a second machine of Dave's,
  [#1812](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1812)). What check 11 records,
  correctly and with a date, is that a bare project-scoped `update` advanced the clone during the run
  (July 31, 2026, CLI 2.1.220, 3.0.3 → 3.0.4) — taken while the **version number was changing**.
  Identical version, new content, nothing moved was the untested case. Measured, in this order:

  - `claude plugin marketplace update claude-code-specialists` advanced the clone **104 commits**,
    `0711d417` → `37f72f76`. Every extracted payload was left byte-identical — no new tree, no
    changed mtime — and `installed_plugins.json` came back byte-identical too.
  - `claude plugin update dkj-policy --scope project` then answered *"already at the latest version
    (4.33.0)"* and extracted nothing, with the clone's payload for 4.33.0 by then carrying a skill
    (`tidy-machine`) the installed payload does not.
  - `claude plugin install dkj-policy@claude-code-specialists --scope project` answered *"already
    installed"* and extracted nothing either.

  **So both documented commands decide on the version STRING, and a payload that changed without a
  bump is unreachable by either.** Not "a few hours older than `main`", as the August 24 reading had
  it — arbitrarily old, until the next cut. That reading was taken on the clone, which is the copy the
  refresh does move, and nobody looked at the copy underneath it.

  **The copy underneath it is the one a session loads, and this is the measurement that settles it.** A
  record in `installed_plugins.json` carries an `installPath`, always into
  `~/.claude/plugins/cache/<marketplace>/<plugin>/<version-or-sha>/`, and the running process writes a
  lease at `<installPath>/.in_use/<pid>` holding `{"pid":…,"procStartFt":…}` for the life of the
  session. Measured live: pid 51988 (`claude`, started 19:51:42) held one in `dkj-policy/4.33.0` and
  `bwj-development/4.33.0` and in no other tree, and the clone held none. Two corroborations, both from
  the same run: `claude plugin details dkj-policy` reported `Skills (17)` while the clone's copy of the
  same 4.33.0 carried 18 — so that command prices the payload, not the clone — and a checkout enabling
  `dkj-subagents-alpha/-ecomm/-shopify` with no install record for its own path loaded none of them,
  which is [#1802](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1802) seen from the
  other end.

  **Neither account in the tree was complete, and that is why #1810 could not be designed.** This lens
  said the clone is what a session reads; #1802 said a dead consumer survives because its *cache*
  survives. Both are half of one mechanism: **plugin components — skills, hooks, agent defs, the
  plugin's own scripts — load from the payload, and a document named by an absolute `@`-import loads
  from wherever that path points**, which in this family is the clone. That is the whole of it, and it
  is why a refresh visibly repaired #845's `@`-imported document while leaving every hook and skill on
  the same bytes as before.

  **What follows for a fleet, since that was the question underneath.** One `marketplace update` per
  machine moves nothing that a plugin ships; the unit that moves a payload is a **release**, and it has
  to be pulled per checkout, on every machine, with the version bump as its only trigger. Between two
  cuts there is no command in the CLI that will hand a session new plugin content — measured above,
  three times.

  **And the payload is never reaped, only marked.** The harness writes `.orphaned_at` (Unix
  milliseconds) into a tree no record points at and stamps `~/.claude/plugins/.last_inuse_sweep`, but
  on this machine 30 of 41 trees carried that mark — 22.2 MB of 32.6 MB — the oldest six days old, and
  every one was still on disk. `claude plugin uninstall` was measured on
  `dkj-team-lifehub@claude-code-specialists`: the record went, the payload stayed. **That last one
  refines rather than discovers, and the report that asked for it had it as untested** — the reason a
  report gives is checked before it is repaired, and here
  the since-retired `UNINSTALL.md` had already established that the
  cache directory follows the marketplace and not the install
  ([#339](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/339)). What was genuinely open
  was the per-plugin case, and that is what was run. That is the gap
  [lane 12 of `tidy-machine.ps1`](../../../scripts/maintenance/tidy-machine.ps1) reports — and reports
  only, because there is no plugin-cache verb to hand over and a recursive delete under a user's home
  is the primitive #1659 exists to prevent.
- **Always read `$LASTEXITCODE` before you pipe a native command through a cmdlet.** A construct like
  `& git … | Select-Object -First 1` cuts the upstream (git) short as soon as the first item is in;
  if the process has not yet exited cleanly at that point, it ends with a non-zero exit code —
  purely timing-dependent. Whoever reads `$LASTEXITCODE` afterwards therefore gets a flaky value and
  builds a non-deterministically red CI. The rule: capture the full output first, record
  `$code = $LASTEXITCODE` immediately, and only then filter (`Select-Object`, `Where-Object`, …) on
  the fixed array. It took three PRs on the git derivation in `bootstrap.ps1` (`Get-DerivedRepoName`) — #94
  (regex coverage), #95 (`insteadOf` rewriting), and #96 — before this pitfall was recognized as the
  root cause; the rule applies to every `scripts/**/*.ps1` that calls a native command.
- **A native command's stderr under `$ErrorActionPreference = 'Stop'` becomes a *terminating*
  error — even when the command exits 0.** `git push` writes its `remote:` progress to stderr, so
  under `Stop` PowerShell 5.1 aborts the script on the push before the `$LASTEXITCODE` check can run
  (this bit `open-pr.ps1`'s push step). Sibling of the rule above: don't lean
  on stderr-as-failure. Run the call with `$ErrorActionPreference = 'Continue'` around it, capture
  `2>&1` (or `2>$null` when you only want stdout, e.g. `gh ... --json`), record `$LASTEXITCODE`,
  restore the preference, and only then judge. Applies to every native call whose stderr is normal
  chatter — `git push`/`git fetch` (`remote:`), **`git add` (the autocrlf LF↔CRLF warning — this
  broke `cut-release.ps1` while cutting v1.12.0)**, `gh` (auth/update notices), … Query commands
  (`git rev-parse`, `git status`) write results to stdout and only real errors to stderr, so `Stop`
  is correct there — don't wrap those. Swept across all release scripts after the v1.12.0 break.
- **Never name a local variable after a `$script:` variable a dot-sourced repo lib owns.** PowerShell
  variable names are case-insensitive, and at script top-level the local scope *is* the script scope
  — so `$changelogHeading = '<default>'` in a script that has dot-sourced `repo-config.ps1`
  overwrites that file's `$script:ChangelogHeading` **before** the `Get-…` accessor is ever called.
  The accessor then dutifully returns the default, and the configured value silently disappears: no
  error, no warning, just the fallback everywhere. This bit the `Get-ChangelogHeading` work for
  inbound #178; the fix is a distinct local name (`$foldHeading`). Sibling of the `$RepoRoot`/
  `$repoRoot` collision already documented at the top of `fold-changelog-entry.ps1`. Rule: when you
  read an optional repo-config value into a local, give the local a name that is not the backing
  variable's — and prove it with a test that sets a *non-default* value, since a test using the
  default passes either way.
- **Never dot-source a consumer's repo-owned lib under `Set-StrictMode`.** A check or hook that
  dot-sources `scripts/lib/branch-info.ps1` or `scripts/repo-config.ps1` to probe it (e.g.
  `check-script-contract.ps1`, `check-roster-sync.ps1`) must load it in a child scope with
  `Set-StrictMode -Off` (`& { Set-StrictMode -Off; . $lib; ... }`), because the real workflow scripts
  that consume those libs (`open-pr.ps1`, `new-branch.ps1`, `fold-changelog-entry.ps1`, …) never
  enable StrictMode, and both libs are explicitly written on that no-strict-mode assumption. Probe the
  functions (`Get-Command`) inside that same block so the dot-sourced definitions stay visible while
  nothing leaks into the check's own strict scope. Load under strict mode instead, and a consumer copy
  carrying harmless pre-strict-mode loose top-level code (an `if` on an unset variable, say) throws on
  the dot-source — a false `[ERROR]`, or under `$ErrorActionPreference = 'Stop'` a full crash — at
  every session start, for exactly the older consumer repos these checks exist to serve. A genuine
  load failure (a real syntax error) should degrade to a sane default or a reported `[ERROR]`, not
  abort the check. Recognized while building the script-contract check for inbound #147 (#148) and
  immediately found in its sibling `check-roster-sync.ps1` (#149).
- **Mask fenced code blocks before you pair inline backticks — a fence silently shifts every span
  after it.** A `` `[^`]+` `` pattern cannot open a span on the first two backticks of a ``` `` ``` run,
  opens one on the third, and closes it on the *first* backtick of the closing fence; from there every
  real inline span in the file pairs one position out. Nothing errors, so a scan built on those spans
  reads the wrong text and reports a plausible answer. Measured on July 31, 2026 while building check
  11: a command whose flag sat on the next line of its own span came back looking **flagless**, i.e.
  the gate under-reported rather than raising. `Get-FenceMaskedText` in
  [`check-plugin-integrity.ps1`](../../../scripts/lint/check-plugin-integrity.ps1) already solves this
  and keeps offsets and newline positions identical, so a span found in the mask indexes straight back
  into the real text — reuse it rather than writing a second fence walker. Sibling rule for the same
  scan: judge one command's own arguments, not the whole span, or two commands in one span let the
  second borrow the first one's flags (Victor, same build).
- **`return @($x)` does not return an array when `$x` is one item — and indexing the result then yields
  a character.** PowerShell unrolls a single-element array on return, so a helper written as
  `return @(...)` hands back a bare `[string]`; `$result[0]` is then its first *letter*, and
  `$result.Count` is `1` either way, so the length guard that was supposed to protect the index passes.
  Measured the same day in `teardown-protocol.tests.ps1`, where a check-ignore line's first field read
  as `.` instead of `.gitignore:2:`. Rule: wrap at the **call site** too — `$r = @(Get-Thing ...)` —
  whenever you are going to index or slice, and do not rely on `@()` inside the function. Same family
  as the two rules above: the wrong answer arrives as a plausible value instead of an error, which is
  the failure mode this repo's gates exist to catch and therefore the one its own tooling must not
  have.
- **A check's `[ERROR]` text is a consumed interface, not just prose.** `skills/sync-roster/sync-roster.ps1`
  does not re-implement detection — it *parses* `check-roster-sync.ps1`'s finding lines with a regex
  (`\[ERROR\]\s+(?:agent|persona) '(?<id>\d{2}-\d{2})' \(...\) has no (roster row|repo-lens)`). So
  rewording or widening a finding silently changes what the recovery skill can act on. Inbound #204
  hit exactly that: extending the check to persona-only specialists made it emit
  `persona '01-01' ... has no roster row`, which the then-`agent`-only pattern did not match — while
  both the check's own report *and* the session hook point the reader at that skill to stage the
  catch-up. Left alone it would have shipped advice that looks helpful and does nothing, for precisely
  the findings the change introduced. The rule: when you touch a finding's wording or scope, grep for
  who parses it before you touch the message. The integration tests in
  `scripts/tests/sync-roster.tests.ps1` drive the REAL check (not a stub) for exactly this reason, so
  they do fail on a wording change — treat that failure as the coupling reporting itself, not as a
  test to patch.
- **Verify a diagnosability fix against real data, not against the diff.** A report that "names the
  thing" reads correct in review and can still be useless in practice. The #203 fix made
  `check-connectors` label each finding with its connector — provably right, fully tested, and still
  producing two word-for-word identical lines when run against this repo's own register, because that
  consumer registers *two* plugins and both were behind on one outdated install. The distinguishing
  `-- plugin:` header was the very thing the hook filters away. Only running it surfaced that; the
  label now carries `<repo> / <plugin-id>`. For any change whose whole purpose is "make the output
  actionable", run it against the real register/repo before calling it done — a fixture proves the
  mechanism, not the usefulness.
- **A documented rule is not a mechanism, and a silent signal is not a signal.** The connectors README
  had carried "after a refresh, also update the manifest" for days when a deliberate run of
  `check-connectors.ps1` found eleven inventory-drift findings at once — six in this repo's own
  register, where the lenses had landed with PR #212 and the inventory was never updated alongside. The
  rule was on the books and had been followed exactly zero times, because the finding is an `[INFO]` and
  the session hook surfaces only `[ERROR]`: nothing ever reported the omission, so nothing ever
  prompted anyone. Writing the rule down more firmly would have changed nothing. What changed it was the
  non-counting `[INVENTORY]` marker (July 29, 2026) — the third instance of the
  `[UNREGISTERED]`/`[ORPHANS]` shape. **When a rule depends on someone remembering a follow-up step, ask
  what would report the omission; if the answer is "a deliberate run nobody has a reason to make",
  the rule needs a mechanism, not a sharper sentence.**
- **`Write-Host` output is invisible to a same-process pipeline, so an in-process assertion about it
  silently passes.** While verifying the `[INVENTORY]` marker by hand, `$out = .\check-connectors.ps1;
  @($out | Where-Object { $_ -cmatch '\[INVENTORY\]' }).Count` returned 0 for the case that *should*
  emit it — the line was plainly visible on the console, but `Write-Host` writes to the host and never
  enters the pipeline. Both the positive and the negative case therefore "passed", which is the
  dangerous half: a scoping test that can only ever read 0 proves nothing. The checks use `Write-Host`
  throughout (deliberately — it carries `-ForegroundColor`), and the hook only captures it because it
  runs the check as a **child process**, whose stdout *is* captured. So: verify these scripts the way
  the hook consumes them, via `& powershell -File …`, and treat a negative assertion that cannot
  distinguish "absent" from "uncapturable" as no assertion at all. The suite in
  `scripts/tests/connectors.tests.ps1` already does this correctly through `Invoke-Ps`.
- **Run a suite from the tree it is meant to judge — `$PSScriptRoot` follows the file, the working
  directory does not.** `roster-sync.tests.ps1` asserts that the git-root fallback lands on the repo the
  test runs inside. Invoked by absolute path out of a linked worktree while the shell's CWD was still
  the main checkout, it failed on exactly that assertion: `git rev-parse --show-toplevel` answers for
  the *process's* directory, not for the script's. 125 pass, 1 fail — a red suite caused entirely by
  where it was launched from, and the temptation is to read it as a real regression in the branch under
  test. `Push-Location <worktree>` around the run (or `git -C`) is the whole fix. **Sibling of the
  `Write-Host` trap above, and the same underlying mistake: verifying from the wrong vantage point.**
  One produced a false pass, this one a false failure — so the rule is not "distrust green" or
  "distrust red" but: before believing either verdict, confirm the check was observed from the same
  place its real consumer observes it. Both instances happened on July 29, 2026, within one session.
- **The non-counting marker is a standing pattern now, not a series of exceptions.** Five instances:
  `[ORPHANS]` (inbound #204), `[UNREGISTERED]` (#208), `[INVENTORY]` (#220), `[BOOTSTRAP]` (#225) and
  `[RECORD-SHAPE]` (#314/#315 — reached for rather than invented, which is this bullet working as intended).
  Each solves the same problem — a finding that is **real, actionable, and about the repo the session is
  in**, but that would be wrong as an `[ERROR]` because nothing is broken and a red line plus exit 1
  would be a lie. Each is also the answer to a specific failure: an `[INFO]` the session hook suppresses
  is, from the reader's seat, indistinguishable from no finding at all. **The recipe:** emit a dedicated
  bracketed token with `Write-Host` (never through `Write-Failure`/`Write-Info`, so the summary count
  and the exit code stay untouched), have the hook match it with its own `-cmatch` outside the
  `$signals` list, and give it **its own verdict line** rather than folding it under an existing one —
  `[BOOTSTRAP]` arrives on an exit-0 run, so without that branch it would have fallen through to
  "roster in sync", which for a repo with no roster is a flat untruth. When a fifth case appears, reach
  for this shape before inventing a new one, and ask the classification question first: if the finding
  could indicate tampering or a genuine breach it must be an `[ERROR]`, per the connectors README rule.
- **A repo-wide verdict must be computed where the evidence is complete, not where it is convenient.**
  The first `[BOOTSTRAP]` implementation short-circuited *before* the plugin-resolution loop, since that
  is where the predicate (no lenses, no roster rows) is cheapest to evaluate. It shipped a regression
  immediately: a repo whose plugin is enabled but **not present in the cache** was told to run
  `specialists-init`, when the real cause was that the plugin is not installed on that machine at all —
  two states that look identical from outside the loop and need opposite advice. The fix was to let the
  loop run, suppress only the two findings the marker replaces, count them, and emit the marker
  afterwards; everything else the check knows (not-in-cache, orphans, off-path lenses) still reports.
  `roster-sync.tests.ps1` caught this within one run, which is the argument for adding the guard case in
  the same commit as the feature rather than after it.
- **`Select-Object -First N` kills a child process mid-run; `-Last N` cannot.** The `$LASTEXITCODE`
  rule above says not to pipe a native command through a cmdlet — this is the sharpest instance and
  the discriminator that makes it predictable. `-First N` tears the pipeline down the moment N items
  are in, and the still-running upstream process dies with it; `-Last N` has to drain the entire
  stream to know what the last N are, so it is harmless. Measured on July 29, 2026 while measuring the
  fresh-consumer install: piping `bootstrap.ps1` into `-First 1` created **zero** lenses and reported
  nothing wrong, and into `-First 20` it wrote 19 lenses and exited **255** — while `-Last 25` on the
  identical command completed normally with exit 0. Both truncations look like display choices in the
  diff. The consequence was worse than a crash: the harness went on to measure an *unbootstrapped*
  repo and label the numbers "after bootstrap", and the first explanation reached for was a bug in
  `Get-DerivedRepoName` — a real hypothesis, tested across three git states (no repo / repo without
  remote / repo with remote), all exit 0. **So: capture a child process's output into a variable in
  full, then slice the variable — and when setup runs before a measurement, check its exit code and
  abort rather than measuring past it.**
- **MENTION vs USE — the day's recurring defect, and the rule that covers all three.** Three separate
  checks were satisfied by text that merely *named* the thing they look for, rather than *using* it:
  `check-roster-sync` counted an `@`-import path as a roster row because the path contains the id
  (#227); the lint gate's check 10 read a marker quoted in changelog prose as a real enumeration, on
  `main`, where no PR gate could see it (#235); and `specialists-teardown` classified a fully configured
  `repo-config.ps1` as an unfilled scaffold because the scaffold's own **docstring** still says "fill in
  the remaining VUL-IN values" — which is the *normal* state of a filled-in scaffold, not an edge case.
  That third one would have **deleted** the file `open-pr`, `fold-changelog`, `new-branch` and
  `check-roster-sync` all depend on, and only a dry run against a real consumer
  (`davekokbwj/smartwatchbanden`, July 29, 2026) surfaced it — every fixture had scaffolds that were
  either untouched or rewritten, never the real-world middle state.
  **The rule: when a check's evidence is "this string appears in the file", ask what else in that file
  legitimately contains it — docstrings, prose, links, paths — and key on the string in a POSITION that
  only real use produces.** A placeholder in an assignment's *value*, an unfilled slot *heading*, an
  empty table. And for a script that deletes, resolve every remaining doubt toward keeping: a false
  keep leaves clutter, a false remove destroys someone's work.
- **A gate can only fail on the files it scans — and a *transient* file is where that goes wrong.** The
  lint gate's scan set (`$linkFiles`, feeding both check 4's link scan and check 10's skill spans) listed
  every permanent doc but not the root changelog **entry** files. So an entry's text was invisible while
  the PR was open and became visible only at **fold** time — directly on `main`, in one of the two
  sanctioned direct-on-`main` actions, past every PR gate. The error then surfaced at the next full gate
  run, `cut-release.ps1`, which is why v2.13.0 was blocked by a changelog sentence. Note the shape: no
  check was wrong, the *timing* was — the gate's verdict was "green so far", not "green" (#234, closed
  July 29, 2026 by adding root entry files to the set, keyed on the entry format's `###` heading, so a
  permanent root doc with its `#` heading never joins). **The rule: when a gate checks file A and some
  other step copies text into A, the gate must also check where that text was authored.** Ask which file
  the content was *written* in, not which file it ends up in.
- **A check that scans a file for a token can be satisfied by a *path* containing that token.**
  `check-roster-sync` looks for each `<group>-<id>` in the roster file, and the bootstrap wrote
  `@.claude/plugins/claude-specialists/dkj-subagents-alpha/01-01-extension.md` into `CLAUDE.md` (the pre-seam
  lens path of the time; since #253 it writes the one seam line instead). That import
  line contains `01-01`, so Chris counts as rostered without a roster row ever existing — measured
  July 29, 2026: 18 ids reported missing after a bootstrap, not 19, with `01-01` the one silently
  passing. It is the worst possible id to lose, because a persona appears in no always-on listing at
  all and the roster row is the *only* thing that makes him exist for a session. Same class as the
  roster token-boundary fix in v2.6.0, so treat that fix as incomplete rather than done: **when a
  check's evidence is "the token appears in the file", ask what else in that file legitimately
  contains the token — a path, a link, a changelog line — before trusting a pass.**
- **Restoring a file with `Set-Content -Encoding utf8` is not a restore.** PowerShell 5.1's `utf8`
  means *with BOM*, so writing a captured `$orig` back leaves a byte-level diff (`M-oM-;M-?{`) on a
  file that was BOM-less — a "clean" restore that shows up as a modified file. When a probe needs to
  mutate a tracked file temporarily, undo it with `git checkout -- <path>` rather than rewriting the
  captured content.
- **`claude plugin marketplace remove` rewrites the *project* `settings.json` of the working directory you
  run it from — not only the scope the marketplace was declared in.** Measured on July 29, 2026 while
  cleaning up the two throwaway plugins of the [#215](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/215)
  experiment: it emptied the test consumer's `enabledPlugins` **and** `extraKnownMarketplaces`. So run it
  from a throwaway directory, never from a repo whose `.claude/settings.json` you want to keep. The full
  account, including how the damage was spotted, is in
  [PR #256](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/256)'s changelog entry.
  **And the lookup lesson that came with it:** the first version of this bullet declared the mechanism
  unrecorded and left it at an operating rule, because it went looking in the lenses and the manuals. It
  was on record all along — in that PR's entry, folded into `CHANGELOG.md` one commit earlier. Before
  writing "this was never captured", grep `CHANGELOG.md` and `releases/**` too: an entry body is where
  this repo's findings land *first*, and a lens is usually the second home, not the first.
- **And the quieter sibling of that: every `claude plugin install`/`uninstall --scope project` rewrites
  this repo's tracked `.claude/settings.json` and strips the blank lines that group
  `permissions.allow`.** Measured September 10, 2026 over nine such commands
  ([#1774](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1774)): `enabledPlugins` came
  back byte-identical, and the three blank lines separating the git / gh / scripts / release blocks of a
  60-entry allowlist were gone. The mechanism is the CLI's own settings writer — a JSON parse and
  re-serialise — so it is not this repo's code and there is nothing here to fix. The portable rule, with
  the remedy and the reason a gate is the wrong answer, is in
  [Sylvester's manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-05-15-manual.md#sylvesters-hard-rules);
  what is local is why it is met so often and what it costs here:
  - **This repo consumes its own marketplace and names all six plugins in `enabledPlugins`** (two
    `true`, four `false`), so plugin administration is
    routine maintenance rather than a one-off — the rename of #1698 alone needed nine commands.
  - **The grouping is deliberate authorship**, and it is what is lost: four labelled blocks in a
    60-entry list, gone in one command, quietly.
  - **The trunk rule makes the stray diff worse than untidy.** Nothing here may be committed directly on
    `main`, so a session that ends with an unintended modification to a tracked file has to recognise it
    as the CLI's and not its own. `git checkout -- .claude/settings.json` after plugin administration,
    and read `git status` before staging.
  - **Deliberately no check.** A gate refusing a whitespace-only diff on one file is the same shape as
    the control-character rule declined above — a rule written for one careless afternoon — and seeding
    an ungrouped list to make the file round-trip-stable would pay for it with the readability the
    blocks exist for.
- **When a tool refuses with "auto mode cannot determine the safety", retry it — do not route around it
  via the Bash tool.** A recurring platform fault on July 29, 2026 made PowerShell and Edit calls refuse
  intermittently; it comes and goes, and a plain retry clears it. That the Bash tool can usually do the
  same work is exactly the trap, because it makes the workaround feel like resourcefulness: reaching for
  it converts a transient refusal into a deliberate bypass of the safety decision that produced the
  refusal. The refusal is not the obstacle to route around — it is the mechanism working. Wait it out.
- This repo is **public**: config never contains secrets.

### Repo layout

**Moved here from the root `README.md` on September 24, 2026, when that document was retired** — kept
verbatim rather than retold, since it is a repo-only fact rather than craft. The full picture, top-level
folder by folder:

- **`.claude-plugin/marketplace.json`** — the marketplace definition: the plugins (teams and workflow alike) with their `source`.
- **[`plugins/`](../../../plugins/)** — the plugin source, split by kind (the split, and the naming rule that
  holds it, are under
  [Teams and workflows — what's the difference?](../../../plugins/dkj-subagents/README.md#teams-and-workflows--whats-the-difference)): the teams under
  [`plugins/dkj-subagents/`](../../../plugins/dkj-subagents/) (`dkj-subagents-alpha`, `dkj-subagents-lifehub`, `dkj-subagents-shopify`, `dkj-subagents-ecomm`) and
  the policy at [`plugins/dkj-policy/`](../../../plugins/dkj-policy/) — the prime ministry's own files at that
  root, and its one ministry `bwj-development` a level inside it — each of those two directories carrying
  its own README for what belongs in it
  and the rules that govern it. One folder per plugin, each carrying
  `agents/`/`manuals/`/`personas/`/`skills/` plus its own `plugin.json` — and beside the four teams
  **[`plugins/dkj-subagents/subagent-shared/`](../../../plugins/dkj-subagents/subagent-shared/)**, the canonical source of the shared
  agent-def blocks described under
  [Shared agent-def blocks](../../../plugins/dkj-subagents/README.md#shared-agent-def-blocks--one-source-for-the-verbatim-boundaries). See
  [Manuals — the split model](../../../plugins/dkj-subagents/README.md#manuals--the-split-model) for the manual/agent-def/persona split.
  `subagent-shared/` belongs under `plugins/` rather than at the root because it is plugin *source*: its
  generator writes those blocks into plugin agent defs. It sits under `dkj-subagents/` rather than one level
  up because **every** file carrying a shared block is a team's — 30 agent defs and personas across the
  four teams, none in either workflow — so a level up described a reach it does not have. It is a
  directory inside a kind directory that is not a plugin, and nothing has to be told so: a script asks
  the marketplace which plugins exist, and this folder is in no marketplace.
- **[`connectors/`](../../../connectors/)** — the register of which repos have each plugin installed and whether
  they are in sync (see its own [README](../../../connectors/README.md)). At the root, deliberately **not** under
  `plugins/`: it is maintenance data read by `scripts/sync/check-connectors.ps1`, not payload, and it
  must not travel along with the plugin cache.
- **[`assets/`](../../../assets/)** — material that is neither code nor documentation, one subfolder per kind;
  today that is [`assets/avatars/`](../../../assets/avatars/), the profile images of the GitHub accounts this
  repo is worked on under, one PNG per account and named after it; nothing in the tree reads them. At the root for the same
  reason as `connectors/` and with one extra property: **the marketplace clone is the whole
  repository**, so anything here is on every machine at
  `~/.claude/plugins/marketplaces/dkj-claude-plugins/assets/…` after a
  `claude plugin marketplace update` — no release, no version bump. Under `plugins/` the same files
  would wait for a cut and then land in the payload of every consumer, none of which has any use for
  them.
- **`scripts/lib/`, `scripts/lint/`, `scripts/release/`, `scripts/sync/`, `scripts/agents/`,
  `scripts/task/`, `scripts/tests/`** — the shared helpers (`branch-info.ps1`, `release-lib.ps1`,
  `subagent-shared-lib.ps1`, and `plugin-tree-lib.ps1`, which answers which plugins this repo publishes
  and where each folder sits, so no other script has to encode the layout), the lint gate + drift
  check, the changelog/PR/release scripts (incl.
  `cut-release.ps1`), the connectors check (`check-connectors.ps1`), the agent-def generator
  (`build-agent-defs.ps1` — fills in the shared blocks from `plugins/dkj-subagents/subagent-shared/`), and the tests.
  What each script does is on the page of the skill that runs it; the conventions for the directory
  itself are in [the section right below](#the-scripts-directory-is-the-source). A
  mirrored copy for consumers lives inside the plugins — the sync/check scripts in `dkj-subagents-alpha`, the
  branch/release workflow in `dkj-policy` — see its own
  [README](../../../plugins/dkj-policy/scripts/README.md).
- **`dkj-policy/`** — the workflow's own root folder (named `contributing-davekjohn/` from August 27
  until September 5, 2026, #1437), and since August 27, 2026 the home of
  every document the contribution cycle produces or governs. **It carries no prose pages of its own**
  — a `CONTRIBUTING.md` and a `README.md` sat here until
  [#2171](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2171), September 20, 2026, when a
  per-repo restatement beside
  [`CONTRIBUTING-portable.md`](../../../plugins/dkj-policy/CONTRIBUTING-portable.md) was retired and this repo's
  own answers moved into the specialist lenses. What is here is
  [`CHANGELOG.md`](../../../dkj-policy/CHANGELOG.md), the open branch's
  `<branch>.md` while one is open, and `releases/` — what a cut *generated*
  (`changelog/<X>.x/<X.Y.Z>.md`, the complete note per version, and `github/<X>.x/<X.Y.Z>.md`, that
  version's GitHub Release body), the hand-written note per version under `audience/`, the dated list of
  every release ever cut in
  [`releases/history.md`](../../../dkj-policy/releases/history.md). **The folder carries no prose page of its
  own** — this repo's seam answers sat in a `releases/README.md` until #2196 retired it, and they are in
  the lenses of the specialists who own them:
  [Rendall](specialist-05-06-lens.md#versioning--releases) for the release
  decisions, [the release-notes section below](#the-release-notes-page-and-the-worker-that-serves-it)
  for the hosted notes page. The cutting process itself travels
  with the plugin as
  [`RELEASES-portable.md`](../../../plugins/dkj-policy/RELEASES-portable.md).
- **`.claude/`** — the repo layer: `specialists/SPECIALISTS.md` (the inclusion carrying the
  body import, the lens import and the roster), `specialists/lenses/` (this repo's own repo lenses),
  `rules/` (path-scoped rules), and
  `settings.json` (harness config).
- **The root documents** — `README.md` was retired on September 24, 2026 (this section is the
  proof of where its content went); what remains at the root is `CLAUDE.md` and `SECURITY.md` — and
  **`.github/`** (`pull_request_template.md`, the issue templates + three workflows: `workflows/ci.yml`,
  the CI gate that runs the lint + test suites on every PR and push to `main`, plus
  `workflows/claude.yml` and `workflows/claude-code-review.yml`, which answer an `@claude` mention and
  review each PR. Only `ci.yml`'s job blocks a merge).

### What lives here and what doesn't

**Moved here from the root `README.md` on September 24, 2026, condensed rather than moved verbatim**:
its hook-by-hook detail already lived a second time in
`plugins/dkj-policy/README.md`'s `hooks/` row (a genuine duplicate — the root page and the plugin page
described the same set in the same words), so that duplicate is dropped here and only the frame is kept.
That plugin page was retired in turn on October 2, 2026.

**Does live here:** the plugin folders under `plugins/` with subagent definitions and the portable
playbook per specialist, plus — core team only — the persona templates of the main-loop specialists and
the repo-neutral bootstrap skill `specialists-init`. Full detail:
[`plugins/dkj-subagents/README.md`](../../../plugins/dkj-subagents/README.md#manuals--the-split-model).

**Doesn't:** governance (`CLAUDE.md`, the workflow rules), safety hooks, or MCP config. Those stay at
repo level deliberately, because they differ per repo (or are safety-critical). The plugins carry **no
safety/guardrail hooks** and **no repo-specific skills**, with a few named, repo-neutral exceptions:
`specialists-init`, and a set of informational SessionStart hooks that never block, read-only with one
stated exception (`claude-home-sessioncheck`, which snapshots a healthy `~/.claude` plugin
administration so a clobber is restorable, #1609, and touches nothing in any repo). **One of them is the
core team's own**: `roster-sessioncheck` (roster-drift signalling), which ships with
`dkj-subagents-alpha` rather than with the workflow, because it audits the roster against the plugin
cache rather than against a way of working — everything else in the read-only set
(`connector-sessioncheck`, `script-contract-sessioncheck`, `consumer-prose-sessioncheck`) and the two
hooks that go beyond reporting (`cycle-autopark`, which commits and pushes a branch's development
document until a PR publishes it, #900; `closeout-gate`, which blocks a close-out past this repo's
stated band, #2050) ship with `dkj-policy`. **The set is not enumerated in full anywhere**: it was, as three, and went stale twice inside two
days as hooks were added; each plugin's own `hooks/hooks.json` is the one place that cannot.

### Updating the plugins — in every other checkout of this repo

This procedure was `dkj-policy/README.md`'s until #2179 retired that page and the `CONTRIBUTING.md`
beside it ([why, and where the rest of it went](specialist-06-16-lens.md#the-two-pages-the-workflow-folder-used-to-carry-and-why-they-are-gone)).
It landed in the specialists handbook (`.claude/specialists/README.md`), and moved here when that page
was folded into [`SPECIALISTS.md`](../SPECIALISTS.md): it is a procedure about the harness this repo
**consumes itself**, which is Sylvester's field.


**This repo consumes itself**, so the system a session here runs is the *installed* copy, not the tree
you are standing in. [`settings.json`](../../settings.json) enables two of the marketplace's six
plugins ([which, and why](#the-plugins-enabled-here-and-what-that-costs)) from a `github` marketplace
source pointing at this repo itself, as [the seam section of Tessa's lens](specialist-06-16-lens.md#the-seam-and-the-two-kinds-of-lens) records.
That is what makes the update a step of its own rather than something a merge does for you, and the
whole reason the procedure is written down here.

**First, whether an update is even due in this checkout.** The
[`plugin-versions`](../../../plugins/dkj-policy/skills/plugin-versions/SKILL.md) skill — run
`scripts/task/plugin-versions.ps1` from a checkout of this repo, or invoke the skill by name — prints,
per enabled plugin, the version and commit *this* checkout installed against the version and HEAD of
the local marketplace clone, with a per-plugin verdict — up to date, update this plugin, or refresh
the marketplace clone — and the exact command for each. It compares the installed and clone
**commits**, so it surfaces a lag the `version` string cannot show between two releases. It does
**not** lift the limit stated below: it reads the marketplace clone this checkout already has and
cannot tell you whether that clone itself trails `origin`. Read-only, no arguments, runs on any
machine.

Two commands, from the root of the checkout you want to move — the refresh once, the update once per
enabled plugin:

```powershell
claude plugin marketplace update dkj-claude-plugins                            # 1. refresh the clone
claude plugin update dkj-subagents-alpha@dkj-claude-plugins --scope project         # 2. then update, per plugin
claude plugin update dkj-policy@dkj-claude-plugins --scope project
```

**The set step 2 walks is [`settings.json`](../../settings.json)'s own, and a plugin left off it simply
stays on its old commit — no error, no verdict, nothing that reads as behind.** That is why the block
names every enabled plugin rather than only the two with real work here: read the enabled set from that
file when the two disagree, and let `plugin-versions` above say which of them actually need the command.
The `update-plugins` skill walks that set for you in one command.

Then **restart the session** — a skill or a hook that arrived with the update is not in a session that
started before it.

**A push does not do it, and neither does a merge — nor, on its own, the refresh.** This paragraph
used to say a session reads the plugins from the local marketplace clone. It does not, and the
correction below moved here from `.claude/rules/this-repo.md` under
[#2448](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2448), which is also when this
paragraph stopped contradicting it.

**A session loads neither this tree nor the marketplace clone.** It loads an extracted copy under
`~/.claude/plugins/cache/`, named by the `installPath` of this checkout's install record and frozen at
the moment that record was last written — the clone is the catalogue, and the source that copy was
extracted from. Measured September 10, 2026
([#1812](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1812)): a
`claude plugin marketplace update` advanced the clone by 104 commits and left every payload
byte-identical, and both `plugin update` and `plugin install` then declined on the **version string**
alone. So a change that lands without a version bump reaches no session at all, and an agent def you
modify on a branch takes effect after merge, push *and a release* — not after a refresh. **The one
thing that does load from the clone is a document named by an absolute `@`-import**, which is why the
orchestrator's body (imported via the root `CLAUDE.md`) advances on that refresh alone and everything
else waits for the cut. Between two releases **no version check can tell you either copy is behind**.

**That describes ONE channel, and there are two — the second reaches a consumer's CI with no version
behind it at all** ([#1851](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1851),
September 11, 2026). Everything above is the **plugin payload**: agent defs, hooks, skills, manuals,
personas, gated by a release and a version bump, landing in a *session* after `plugin update`. But the
runners `adopt-dkj-policy` scaffolds into a consumer do not travel that way. They check this repository
out beside the consumer's own tree and run a path into it — the read-only gates at `ref: main`, so a
change to `check-branch-entry.ps1` is live in **every adopted consumer's next CI run**: no tag, no bump,
no refresh, no session restart. The write runners pin a release commit instead (#2333). Strictly the
release doctrine stays true, because CI is not a session; the trap is that it reads as the whole
propagation model, so a reader reasoning from it concludes that a shared gate script cannot reach a
consumer before a cut — which is the opposite of what happens.

**Neither the pin nor the release doctrine is the defect; the missing sentence was.** `ref: main` is
argued by name in [`adopt-dkj-policy`'s skill page](../../../plugins/dkj-policy/skills/adopt-dkj-policy/SKILL.md):
a pinned gate goes on enforcing the shape it was pinned at, and since the entry's own path has moved
twice, a stale pin does not fail loudly — it refuses branches that *do* carry an entry at the current
path. That reasoning stands, and
[#1805](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1805) sharpened it by naming the
half it had never weighed: tracking the tip protects a consumer from a stale convention and exposes them
to a moved *script*. The writing rule that came out of it — **name the two channels together or name
neither** — holds wherever either is stated, because a release doctrine stated alone is read as covering
everything, and the layer it does not cover is the one that can change a consumer's required check
without anybody bumping anything.

**Everything the second command touches is per-checkout state, which is why every machine runs it
itself.** The install record is keyed on the checkout's **folder path**, so renaming or moving a
checkout unlinks the plugin there with no error, and a machine that never ran `claude plugin install …
--scope project` carries no record at all — nothing to unlink and nothing to update
([#1449](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1449)).

**What tells you a machine is behind is its own install record, not the connector register.** No
manifest in [`connectors/`](../../../connectors/README.md) stores a version — that bookkeeping was removed
deliberately (July 20, 2026, see
[`connectors/README.md`](../../../connectors/README.md#the-manifest-format)): the check reads the version
actually installed from that machine's own `installed_plugins.json` and compares it to the source
checkout's `plugin.json`, and the register's only part in that is `localCheckout`, i.e. which machine
record to read. `connector-sessioncheck` still reports every consumer that lags the source at session
start, and `scripts/sync/check-connectors.ps1` is still the deliberate full run — that comparison is
the only place the answer exists, because the lagging checkout itself reports a plausible version and
works. And it exists only where a verified source checkout sits beside the consumer on that machine:
with none found the check is skipped outright
([#1587](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1587)), so silence there is not
"up to date" — it is no verdict at all.

**And two things can need catching up after the update.** `script-contract-sessioncheck` reports a
repo-owned seam function the newer shared scripts call and this checkout has never had; a specialist
that arrived with the update needs a roster row and a lens, which `sync-roster` stages — and which the
repo owner types, because that skill is reserved for explicit invocation. The measurements behind the
two commands are on the adoption page,
[Installing it yourself](../../../plugins/ADOPTION.md#installing-it-yourself), rather than repeated here.

### The plugins enabled here, and what that costs

Moved here from `.claude/rules/this-repo.md` under
[#2448](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2448); the rule keeps the one-line
fact of which plugins are enabled, and this is the harness consequence behind it.

**Three of the seven are enabled: the core team, `dkj-policy` and `dkj-solutions`.** The last since
October 13, 2026 (Maikel, [#2976](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2976)),
for its dev-preview hook, which since
[#3198](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3198) is `dkj-policy`'s; it stays enabled
for the house style, its session check and the hub's DKJ-Solutions card. The hook starts the connector dashboard
(`scripts/dashboard/serve-connector-dashboard.ps1`) through this repo's `Get-DevPreview` at session start, and the general pages server beside it (Artifacts, Issues, Release notes, SessionStart; [#3119](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3119)), the second port per checkout, and the root `CLAUDE.md` imports the
extension, as the constitution requires of an installed one. The three add-on teams are set to
`false` since September 30, 2026, and the BWJ extension (then `dkj-policy-bwj`) since October 1 (both Dave). From September 8 to
September 30 all six were on, for validation (see below). **`false`, not absent, and that is
load-bearing**: the harness and every check here read the settings chain user file →
`.claude/settings.json` → `settings.local.json`, and the last layer that names a plugin wins
(`Get-EnabledPlugins`, `scripts/lib/check-report-lib.ps1`). A machine's own `~/.claude/settings.json` can
enable any of them, and a deleted key would let it through. Each change removed the plugins' blocks from
[`connectors/dkj-claude-plugins.json`](../../../connectors/dkj-claude-plugins.json), because
`connectors.tests.ps1`'s self-manifest case fails on a registered plugin that is not enabled. The first
also removed the add-on teams' 11 empty lenses and roster rows, which would otherwise print an
`[ORPHANS]` line at every session start. The second removed the root `CLAUDE.md`'s `@`-import of the
bwj extension, because the constitution has a repo import that extension only where it is installed.

**`figma@claude-plugins-official` is set to `false` here too** (Dave, October 1, 2026), although it is
none of the six. It is enabled in the machine's own `~/.claude/settings.json`, so it loaded into every
session here: 14 skill descriptions, 2,150 tokens measured by `measure-session-start`, and no frontend
for them to work on. This needs the same `false`-not-absent rule as the six. It is not registered in the
connector manifest, so no block had to go. **The key is not redundant, even though nothing in this repo
enables figma**: it was once removed as redundant (commit `c747cb88`, October 2), and the user layer
switched figma back on in every session until it was restored (Maikel, October 13, 2026,
[#2978](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2978)).

**Only three of the seven describe this repo outright.** The core team and `dkj-policy` have real
work here, and `dkj-solutions` its house style; the three add-on teams have none — this repo is not a webshop, not a Shopify store and not a
personal-life repo. Three of `bwj-development`'s four chapters are about a Shopify store too. **Its
ticket-handling chapter admits this repo as a third permitted target** at `report-issue`'s and
`adopt-bwj-development`'s own gate (then `adopt-dkj-policy-bwj`; Dave, September 14, 2026, commit `b9b2a65a`; the per-chapter reach
closed [#1982](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1982)). That permission stays
in the plugin source. **This repo does not use it since October 1**, when the plugin was switched off
here, and an issue here is filed with a plain `gh issue create`, carrying the `prio-N` label and, where
it applies, `minor` ([Chris's lens](specialist-01-01-lens.md)). `adopt-bwj-development` was never run
here, so no Asana seam had to be removed (the `asana-mirror` workflow itself was retired in the plugin
on October 5, 2026). To use that chapter again, set
the plugin to `true`, restore the import and the connector block, and run `adopt-bwj-development`.

**Why they were on, and why they are off.** From September 8 the three add-on teams were enabled so that
the repo that ships a plugin is also a repo that loads it: an agent def, a manifest, a frontmatter or a
hook that stops resolving then surfaced at this repo's own session start instead of in somebody else's.
Validation was the whole reason. It cost every session here roughly 2.9k tokens (11 agent descriptions
plus 6 Shopify skill descriptions, measured with `measure-skill` on September 30, 2026) for three teams
with no work here, and Dave switched them off that day. **What is given up is that early warning**: a
broken add-on plugin now surfaces in a consumer that runs it, or in this repo's own gates, which read the
plugin trees directly rather than through a session. To validate one again, set it to `true`, run
`sync-roster` for its rows and lenses, and re-add its block to the connector record.

**What enabling them cost while they were on, so a re-enable does not read the noise as breakage.** Two
things came with it; one stood and one was answered. First, every specialist an enabled plugin ships
needs a roster row and a repo lens, which for the three teams meant eleven lenses kept empty on purpose.
Second, `dkj-subagents-shopify`'s floor check asks which theme is live, and a repo with no
store has no truthful answer, so it reported an `[ERROR]` at every session start until
[#1570](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1570) gave the check a third
state to be told that in. **This repo declares `Get-ShopifyRepoHasNoStore` in
[`scripts/repo-config.ps1`](../../../scripts/repo-config.ps1) because it has no store, and the check
honours that since #1570** ([#1579](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1579))
— but still **do not silence it by seeding a theme id**, which would arm a guard over a revenue-serving
theme on a number nobody verified. The two are not the same act and the seam exists to keep them apart:
the declaration says there is no store, an id says there is one and names it. The seam is verified
against #1570's own hook rather than against the cached copy: with it the check is silent, without it the
`[ERROR]` returns.

### Repo citation — the two renames behind the one owner name

Moved here from `.claude/rules/this-repo.md` under
[#2448](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2448); the rule keeps the canon
itself — cite this repo as `DKJ-Solutions/dkj-claude-plugins` — and this is the history and the
machinery behind it.

**Two renames sit behind that one line, and they retired different halves of it on different days** —
which is why both old spellings still appear in the tree and why neither may ever be recreated:

- **The owner**, September 2, 2026: transferred from the personal account `DaveKJohn` into the
  `DKJ-Solutions` organisation, so `DaveKJohn/…` resolves only through a redirect.
- **The name**, September 10, 2026: `claude-code-specialists` became `dkj-claude-plugins` (fase 3 of
  [#1769](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1769)), so
  `DKJ-Solutions/claude-code-specialists` resolves only through a redirect too.

Both redirects are **transfer redirects this repo does not control**, and each holds just as long as
nothing is created at its old path — which is why neither `DaveKJohn/claude-code-specialists` nor
`DKJ-Solutions/claude-code-specialists` may ever be recreated (the canonical-channel note in
[`README.md`](../../../README.md#consumption)). The machine layer states the current answer once, in
`scripts/repo-config.ps1`, and a fresh marketplace install uses it.

**And the retired NAME is data the tooling reads, not only prose to correct.** Three of this workflow's
CI runners are scaffolded into a consumer and check this repository out by name, so every consumer
scaffolded before September 10 still names `claude-code-specialists` — the runner keeps working on the
redirect, while the guard over it matches on the name half and would see nothing. So
`Get-RetiredRepoNames` in [`scripts/repo-config.ps1`](../../../scripts/repo-config.ps1) states the
retired names and `check-connectors.ps1` matches them alongside the current one. **The list only
grows.**

**Existing citations are corrected when a file is edited for other reasons, not swept.** Both spellings
resolve today, so nothing is broken and the dead-link gate is right not to flag the mix; the cost is that
new writing copies whichever example sits nearest, and the tree held 133 `.md` files on the old owner
against 28 on the new when this was measured
([#1526](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1526)). The same holds for the
~830 slug citations the second rename left: a sweep buys prose consistency at the price of a diff nobody
can review. The one layer left exactly as written is the archived release history under
`dkj-policy/releases/**`, the same carve-out
[`language-layers.md`](../../rules/language-layers.md) makes. **What was NOT left to drift is every place
the name is read rather than displayed**: `Get-RepoName`, the `repository:` line the consumer
scaffolders write, the matcher that finds it again, and the marketplace source in
`.claude/settings.json`. **The test is whether something RESOLVES the name or merely prints it** — a
citation may lag, a lookup may not.

**A checkout's own `origin` remote is this same citation in a place the tree cannot reach.** It is
per-checkout git config, not tracked, so no gate sees it. A checkout cloned before the transfer still
pushes to `https://github.com/DKJ-Solutions/dkj-claude-plugins.git` and lands only because GitHub
answers `remote: This repository moved`; every push of the `v4.32.0` cut did exactly that
([#1562](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1562)). Repoint such a checkout
in one command — `git remote set-url origin https://github.com/DKJ-Solutions/dkj-claude-plugins.git` —
and the redirect stops being load-bearing there. A checkout can be behind on either half or both, and
the one command repairs all three states, because it writes the whole URL rather than patching a part of
it.

### How the plugin tree got its current address

Moved here from `.claude/rules/this-repo.md` under
[#2448](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2448); the current layout itself is in
[`README.md`](../../../README.md#repo-layout).

Since August 3, 2026 the plugins sit **one** level down in `plugins/<plugin>/` instead of two in
`claude-code-plugins/claude-specialists/<plugin>/`: that second level existed to hold several product
families side by side, which the
[one-product rule](../../../README.md#one-product-one-repository) retired. `connectors/` moved **to the
root** in the same movement, deliberately — it is the consumer register read by `scripts/sync/`, not
plugin payload, and must not travel along in the plugin cache. `agent-shared/` (as it was named then)
stayed **inside** `plugins/` for the mirror-image reason: it *is* plugin source.

**On August 17, 2026 it moved one level further in, to `plugins/dkj-teams/agent-shared/`** (Dave): every
file carrying a shared block is a team's, so sitting beside `teams/` and `workflows/` claimed a reach the
folder does not have. **Nothing in the tooling had to learn the new address** — every script that asks
which plugins exist reads `marketplace.json` through
[`plugin-tree-lib.ps1`](../../../scripts/lib/plugin-tree-lib.ps1), so a directory in no marketplace is not
a plugin wherever it sits. **On September 9, 2026 the team-side rename carried it to its current home at
`plugins/dkj-subagents/subagent-shared/`**, under
[#1698](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1698). The workflow folder
`dkj-policy/` was `contributing-davekjohn/` until September 5, 2026 (#1437).

### Why `Get-RosterIgnoredIds` is empty

Behind *"Adopting a specialist that arrives with a plugin update is the default and needs no
approval"* in [`SPECIALISTS.md`](../SPECIALISTS.md#the-team-roster--routing).

Five of the six specialists who rarely have work here were left off the roster and registered in
`Get-RosterIgnoredIds` instead (Bianca joined them briefly on July 28, 2026). That list turned out
never to have been a decision: it was introduced by the same commit that built the roster check,
pre-populated to keep that new check quiet, and justified in the code as *"a documented choice in
`CLAUDE.md`"* while `SPECIALISTS.md` only ever said those specialists had no lens **yet**. Dave, asked
about it on July 28, 2026, did not recognise the list as his — so the six were adopted and the list is
empty.

The shape is worth keeping separately from the outcome: a check was made quiet by a list, and the list
then cited a document that did not say what it was cited for. Neither half is visible from the other,
which is why the entry survived until somebody asked whose decision it was.

### The scripts directory is the source

**`scripts/` is the canonical source of everything this repo runs, and everything under
`plugins/*/scripts/` is a generated copy of it.** The authoritative list of what is mirrored where is
`Get-SharedScriptPairs` in [`shared-scripts-lib.ps1`](../../../scripts/lib/shared-scripts-lib.ps1);
[`build-shared-scripts.ps1`](../../../scripts/sync/build-shared-scripts.ps1) generates from it and lint
check 8 holds the mirrors to it. **No count of it is stated here, deliberately** — a prose tally of a
machine-held list is wrong when typed and wrong again after the next entry (#897). The consumer-facing
page for the copy is [`plugins/dkj-policy/scripts/README.md`](../../../plugins/dkj-policy/scripts/README.md).
This section is what `scripts/README.md` carried until September 23, 2026, when that page was removed
as rarely read; its directory map and entry-point table were dropped rather than moved, because each
script's skill page is where a reader actually looks for it, and each plugin's `hooks/hooks.json` is the
only list of hook-invoked scripts that cannot go stale. `scripts/repo-config.ps1` sits at the top level
rather than in a directory because it is **data, not machinery**: this repo's own answers to the seams
the shared scripts read.

- **Never *run* a shared script from the plugin cache while you are in this repo — run the copy here.**
  The cache holds the last *released* mirror, so it lags this directory by however many merges have
  landed since. Every shared entry point refuses outright
  ([`source-repo-guard-lib.ps1`](../../../scripts/lib/source-repo-guard-lib.ps1)) and names the local
  path instead — except the few the **harness** invokes from the plugin (a SessionStart or Stop hook),
  where a refusal would fire every session or every turn. **The exempt scripts are named only in
  [`source-repo-guard.tests.ps1`](../../../scripts/tests/source-repo-guard.tests.ps1)**, so adding one is
  argued in a file that fails when it is wrong; that suite also derives the entry points from the
  registry and fails on any that lacks the guard, reading the parsed syntax rather than the text
  ([#1321](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1321)) — a whole-file match
  on the lib's name could not tell loading the guard from a comment explaining its absence.
  **Why it needs saying, measured August 12, 2026 against mirror `4.5.0`:** every skill page prints
  `${CLAUDE_PLUGIN_ROOT}/scripts/…`, which the harness expands to your own cache before you read it, so
  the command looks authoritative and points at a release. That mirror lacked `Get-ReleaseAudienceTier`
  and `Get-ReleaseNoteRoot`: `new-branch` scaffolded the retired three-tier ladder and `session-status`
  printed an empty "still open" block, neither with an error. **Re-syncing or bumping is not the
  repair** — between releases this directory is ahead of the cache by definition.
- **Never edit a file under `plugins/*/scripts/`.** Change the source here and run
  `build-shared-scripts.ps1`; check 8 reports a hand-edited mirror as drift.
- **CI runs from a bare checkout with no plugin cache**, so anything the lint gate or a suite reaches
  has to resolve from `scripts/` alone — which is why a few files
  [deliberately cannot move](../../../plugins/dkj-policy/scripts/README.md#what-deliberately-stays-in-the-consumers-root-cannot-move-here)
  into a plugin.

#### Temp paths in a shipping script: New-ScratchPath

**A shipping script composes no temp path — it calls `New-ScratchPath`**
([`native-capture-lib.ps1`](../../../scripts/lib/native-capture-lib.ps1)), which returns
`<temp>/<label>-<pid>-<guid>`, creates it with `-Directory`, and refuses a label that is not one safe
path segment. A fixed leaf is a name somebody else can reach first: `New-Item -ItemType Directory
-Force` and `[System.IO.File]::WriteAllText` follow a symlink or junction, so a pre-planted link
redirects the write, and a later recursive delete there becomes a delete primitive elsewhere. Measured
September 8, 2026 ([#1659](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1659)):
**seven** sites composed `<label>-$PID` by hand. A guid removes the target instead of checking for one —
a reparse-point check has a window, and cannot apply to the temp root at all, since on macOS `/tmp` *is*
a symlink. `native-capture.tests.ps1` enforces this over `scripts/**` outside `tests/`; the suites have
their own equally strict rule, in [Tycho's lens](specialist-04-18-lens.md#a-suites-fixture-path-carries-the-pid-and-a-fresh-guid).

#### A leftover under the temp directory is an aborted run

Measured September 8, 2026 ([#1668](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1668))
over twelve days of gate runs: 107 `fold-test-*` and 96 `new-branch-test-*` entries were standing, and
**both suites leaked zero** when run to completion — every leftover was registered after a suite's last
completed sweep, the signature of an interrupted run. The fix that would reach them is a sweep by name
pattern in a shared temp directory, i.e. the same delete primitive `New-ScratchPath` exists to remove.
**So those trees are left standing on purpose**: `$PID` in the leaf attributes one to a run that is no
longer alive, and a person can clear it by hand. `tidy-machine`'s lane 10 attributes and never deletes
for this reason.

**Attribute before you count.** That measurement first read 413 entries as leaked fixtures; of the
directory, 546 were `sync-pr-body-*`, written deliberately by `task/sync-main.ps1` to outlive the run
(the same retained-on-purpose class as the gate's capture directories,
[#1636](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1636)), and 162 were an
unrelated tool's logs.

### How the gate checks got their shape, and the measurements behind them (August 15, 2026)

**This section is an index.** The full reasoning and the measurements behind each check, guard and
declined proposal live in the issue or pull request that decided it, and in this file's history, where
the former write-ups (about 111 KB, dated August 7 to September 11, 2026) can be read whole:
`git log -p -- .claude/specialists/lenses/specialist-05-15-lens.md`. **Open the issue in a check's row
before changing that check.** A row marked **DECLINED** was measured and refused: bring a new measurement
or do not re-propose it.

| Check or rule | What it enforces | Decided in | Why, or why declined |
|---|---|---|---|
| Entry-format section count | Prose describing the changelog entry shape is held to the scaffolder's section COUNT, not its section names | [#508](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/508), [#538](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/538) | Name matching gave 6 findings, all false, and is one rename from silence; the count needs no exemptions |
| Stale path in backticks, **DECLINED** (Aug 9) | Would have required a backticked path to resolve in the tree | no issue cited | Five variants over 120 docs gave 124 to 736 findings, 0 true: most paths describe a consumer's repo, which the line never says. Unbuilt: a title claiming a path must name its own location (4 subjects) |
| Check 16 on line counts, **DECLINED** | Would have held "`<file>` is N lines" against the file | [#1784](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1784), from [#1779](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1779) | The motivating defect read "three thousand lines" (no digit); wide form 16 findings, 1 real. The adjacency variant is green but unbuilt (1 subject; revisit at 3 or 4). The unit list stays byte-shaped |
| Check 16 on `.ps1` comments, **DECLINED** | Would have read script comments for stale byte figures | [#1790](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1790), [#1775](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1775) | 49 hits, 26 flagged, 0 real (design ceilings, codepoint prose, no fence to tell prose from code). Needs a PowerShell-aware comment extractor first |
| PR template is one section; check 24 | Shipped reference held byte for byte, this repo's own template to the placeholder contract only | [#538](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/538), [#573](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/573), [#865](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/865) | Over 60 PRs each box was always or never ticked; `open-pr.ps1` still fills the old sections for consumers |
| `CHANGELOG.md` intro read (checks 11, 12) | The intro is scanned, level marker optional across the intro only | [#525](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/525) (PR) | Every cut copies it verbatim; dropping the marker tree-wide gives 50 findings against 4 |
| Check 30, plugin-link | A relative link in plugin payload resolves at the plugin root, which is what the installed cache holds | [#1066](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1066) | 17 escapes in 5 files, all dead once installed, all passing check 4; scenario 37 pins plugin root against `plugins/` |
| Name paired with an older version, **DECLINED** | Would have flagged a plugin name beside a version older than its first release | [#2144](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2144), [#2139](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2139) | 54 pairings, 3 swept quotations, 14 correct attributions that stay forever. Replaced by the marking convention; unbuilt: check the *marking* against history. Untested: fenced blocks only |
| Prose contract check, **DECLINED** | Would have held always-on consumer documents against a manifest of 11 laws | [#1380](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1380), [#1379](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1379), [#1378](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1378) | Best candidate 12.5% precision, recall 1 of 3; a strict pointer match hides the one real contradiction; the declaration form was born red (88 of 88). The manifest table is in git history |
| Retired doc name | Literal `development.md` outside changelog and history, in consumer prose | [#1389](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1389), [#1421](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1421) | Built the day of the decline; merged into `check-consumer-prose.ps1`; stated gap: `development-<branch>.md` |
| Supremacy declaration | `CLAUDE.md` and `wins`/`wint` adjacent in one sentence | [#1415](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1415) | The three-term same-sentence test scored 0 and missed its own defect; adjacency scored 2 true of 3 raw |
| Check 32, `shared-scripts:mirror` | A marked document's table rows match the mirrors under its own folder | [#1491](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1491), [#1480](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1480) | Folder scope, first-cell claim; walk extracted to `Invoke-MarkedSpanWalk`; a heredoc splice once emptied both sets and the gate stayed green |
| Check 34, ascending section numbers | Column-0 `# --- <n>.` headers are unique and strictly ascending in every script | [#1494](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1494), [#1500](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1500), [#2740](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2740) | Renumber, not disambiguate; gaps 9, 17, 19 are legal. Making it skippable and sharing check 27's read were both **DECLINED** (too small a saving) |
| Template self-containment (a suite, not a check) | Every Verb-Noun call in a `plugins/**/templates/*.ps1` is defined there, built in, or `Get-Command`-guarded | [#1556](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1556), [#2818](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2818) | Only a parse-time check catches it; retired October 5 with its one template, back the same day with the next |
| `~/.claude` pollution check | `check-claude-home.ps1`: a record whose `projectPath` is under a scratch tree; snapshot only after a clean read | [#1609](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1609), [#1449](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1449), [#1591](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1591) | A write-guard helper and a stand-alone orphan-marketplace scan were **DECLINED** (no in-tree writer; ordinary residue, [#294](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/294)) |
| Check 35, discarded fixture git result | A fixture `git` call whose output is discarded and whose exit code is not read next | [#1655](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1655), [#1635](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1635) | 182 findings before the sweep, 0 after; widening to any unjudged call was 20 of 20 false; AST-based |
| Nested-worktree exclusion, **DECLINED** | The gate refuses a nested worktree ([#1673](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1673)) rather than excluding it from its walks | [#1678](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1678), [#1665](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1665), [#1667](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1667) | Lint runs first and refuses, so the doubled walks never run; a remembered predicate at ~20 sites is the shape #1665 was filed against; lanes live outside the tree |
| Check 37, `.DESCRIPTION` list | Every column-0 header has an entry in the gate's marked list | [#1680](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1680), [#1494](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1494) | One direction and opt-in, so born green with 0 exemptions; the stale-entry gap is named in the check's header |
| Check 38 removal, **DECLINED** | Check 38 keeps every def in its manifest's `agents` key | [#1771](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1771), [#1764](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1764) | A dispatch control showed the loader honours the key exclusively; `Agents (0)` in `plugin details` is inventory only. `measure-skill` was repaired instead ([#1628](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1628)) |
| Retired-id `continue` | `check-connectors.ps1` asks the install-record question for a retired id too | [#1802](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1802), [#533](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/533), [#1773](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1773) | The report's "no check makes this comparison" was false; the real defect was a `continue` skipping a check that needs no source folder |
| Check 39, mirror depth | A shared entry point whose `$PSScriptRoot` climb differs by copy declares a suite that runs the mirror | [#1857](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1857), [#275](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/275), [#331](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/331) | Check 8's byte equality proves text, not behaviour; 3 of 34 entry points cross; the gate requires the declaration, not the assertion |

**Live rules, read before changing a check**

- A new check is measured against the trunk (CI tests the merge commit) and probed with shapes the tree lacks: a measurement says what it catches here, only a probe says what it waves through.
- Born green with 0 exemptions, and shown firing on the pre-repair file. No exemption lists; no hand-kept list a machine could ask.
- A new numbered check takes the number after the last header, and a retired number is never reused.
- A new check is not skippable; `$script:SkippableChecks` (eight since #2740) widens only for a saving that clears that bar.
- A verdict never travels without its count: a coverage line prints both sides of a comparison, because 0 against 0 reads as no findings.
- Splice code into a `.ps1` with the editor tools, never through a shell heredoc.
- Local green and CI red: read the merge commit (`git log origin/main`) before theorising; a fixture asks the registry for plugin paths and hard-codes none.
- Batch fixture scenarios by expected verdict (each spawns about 1.1 s of PowerShell), with the shape in the probe's file name.
- A quoted old name or version is frozen and marked at its line; an illustration stays true; an attribution keeps today's name.
- A report's reason, and any "nothing makes this comparison" claim, is checked against the tree and the loader before the repair ([`triage-inbound`](../../skills/triage-inbound/SKILL.md)).
- A `continue` or guard is only as narrow as its condition: ask whether every check inside the block depends on the reason it is skipped.
- A count of siblings in prose is named, not counted (one sibling named beats "four").
- Session checks sanitise every value read out of JSON, and their suites never touch the real `~/.claude`.
- Isolation goes through `worktree-lane.ps1`, outside the tree; the gate refuses a worktree inside it.
- Any consumer-prose check skips the source repo and plugin-shipped payload (`Source -eq 'external'`), and never counts "the source is mentioned nearby" as deference.

#### The retired-id `continue`, and the block it silently skipped (September 10, 2026, #1802)

Kept as an anchor. See the table row above and [#1802](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1802): a `continue` that skipped a whole `'retired'` block also silenced the one check in it that needed no source folder.

### The development document, as this repo writes it

**This was `dkj-policy/CONTRIBUTING.md`'s DEVELOPMENT step until #2179 retired that page and the folder
README beside it**
([why, and where the rest of it went](specialist-06-16-lens.md#the-two-pages-the-workflow-folder-used-to-carry-and-why-they-are-gone)).
What survived the retirement is what that page held and the portable one does not: **this
repo's own answers, and the measurements behind them**. The cycle itself — the four phases, the three step
marks, what a DEPLOY section is for — travels with the plugin and is not restated here.

#### The document and its name

`new-branch` creates the branch **and** its document in one move: a branch is never entry-less, so there is
no moment at which the branch exists and its document does not. The document belongs to the **current
branch** and exists only while one is open — the fold removes it at the merge, so on the trunk it is simply
not there. That absence is the trunk's normal state, not a file somebody deleted.

**The name IS the branch** — `fix/thing-v1` gets `dkj-policy/fix-thing-v1.md`, slashes flattened and nothing
else. **One per branch since September 3, 2026**
([#1255](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1255)), where it was a single shared
`development.md`, and **without the `development-` prefix since later that same day**
([#1335](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1335)). The prefix bought a reader
nothing the folder does not already say; what it quietly bought the tooling was a glob that could not reach
this folder's own pages, and that narrowing is now stated as an exclusion instead — see `ReservedNames` in
`Get-BranchFilePaths`. That shared path did not collide on checkout, which is what the old reasoning said,
but it collided on *merge*, and the measurement is the one already recorded above under `main-ci-gate`: every
merge to `main` left every other open PR conflicting on it, and a conflicting PR gets **no check suite at
all**, so `lint-en-tests` could never go green and the PR could never merge. The full write-up — including
why the fold is not the fix and why a `.gitattributes` merge strategy would not have worked either — is in
[`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md#why-the-name-carries-the-branch).
**Nothing identifies a document by its filename**, then or now: the fold and every gate that needs to know
which branch a document belongs to read it out of the document's own heading, which is what keeps a `-v2`
suffix free.

**Four `###` headings and never a fifth**, and nothing branch-specific above `### PLAN` (Dave,
August 26, 2026). PLAN, CREATE, TEST and DEPLOY are the whole top level; a section needing its own heading
goes in as a `####` under whichever of the four owns it, and everything between the title and `### PLAN` is
the scaffolder's generic guidance. **Both were conventions a writer kept, and now a gate refuses both here** —
measured the day they were stated, when `check-branch-entry.ps1` gave byte-identical output at four headings
and at five. That day closed the measurement; the **shape gate** in the next section is what closed the gap
it left, and it carries which half holds in a consumer and which is this repo's own. Recorded — both rules,
and the reasoning behind each, though not the measurement itself — in
[`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md).

**Pick the prefix by what actually changes**, not by which files move along: `docs/` is purely text, `feat/`
is a capability that is new or larger than it was, even when documentation comes with it. The three prefixes,
the GitHub label and changelog type each maps to, and why `Test-BranchName` refuses `chore/` outright are
[Derek's](specialist-05-05-lens.md#classifying-naming-and-creating-a-branch) and are not copied here.

**A `-v<N>` suffix is optional and typed by hand — `new-branch` no longer completes it** (it did, from
August 23 to September 3, 2026; dropped because in 209 branches carrying it none was ever bumped to `-v2`,
and it broke a consumer wrapping the script for a branch whose name it does not own — inbound #1224). A
second cycle on the same subject is `docs/thing-v2`, typed deliberately; a rerun of `new-branch` on the same
name resumes that branch rather than opening the next one. The refusal on `final` in
[`branch-info.ps1`](../../../scripts/lib/branch-info.ps1) is the same rule from the other end: a name claiming
to be the last word is a prediction, and a hand-typed number is the honest form.

**Re-read the file after `new-branch` has written it.** It is the only file here written out of band, and an
editor tracking what it last read refuses the next write until it has read again — one read fixes it and
nothing is lost. The fold no longer joins that list: it removes the document rather than rewriting it, so
there is nothing left to re-read. The portable statement, with the measurement, is in
[`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md#the-file-is-written-under-you-once-per-cycle).

**The HTML comments are the form, not somebody's notes.** They say what a good answer looks like, and the
fold strips them on the way to [`CHANGELOG.md`](../../../dkj-policy/CHANGELOG.md), so leaving one standing is
not a defect. There is no template beside the file and no empty copy on the trunk — the portable page is
where the whole form can be read without a branch open. **There is no `branch/templates/` any more either**
(Dave, August 23, 2026): two generated reference copies sat there because the working files were deliberately
bare, and the merged document carries its own guidance, so the reference and the file you write in are the
same page.

#### What does NOT go into the phases as a step

**The repo's standing gates are NOT written as steps** (issue
[#1060](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1060), August 29, 2026). TEST carries
what proves *this branch*; the lint gate, the test gate and the link gate fire on their own at the push and
refuse on their own, so a step reading *"all suites green"* duplicates a gate rather than adding one. And the
duplicate is not free: `open-pr` **refuses to push while any step above DEPLOY is open**, so such a step can
only be ticked by running the suites by hand *before* the run that was going to run them anyway. Measured in
the session that filed #1060 — the hand-run exceeded the 120s foreground timeout and had to be backgrounded
twice, while `open-pr`'s own gate ran the same 54 suites in **59s** and **60s** immediately afterwards. The
gate is the faster of the two because it schedules the suites across lanes, not because it skips anything —
the mechanism, and why the spread is inherent rather than noise, is in the slowest-single-suite paragraph
above.

**Nothing in the checkbox pass is on your memory.** `open-pr` and `ship-pr` both refuse while a step above
DEPLOY is still open, and there is no `-Force`; reading the list before the push is the moment to catch a
missed step rather than the moment to discover one, and the step-list gate below is the same question asked
by a machine.

#### DEPLOY: folder-relative links, and audience tier 2

**Its links are written folder-relative to `dkj-policy/`, the whole document**, because the DEPLOY section
folds into [`CHANGELOG.md`](../../../dkj-policy/CHANGELOG.md), which sits there — and so did the page this
material came from, so a link that resolved there resolved in the changelog too. `../scripts/x.ps1`, never
`scripts/x.ps1` — the second resolves to `dkj-policy/scripts/x.ps1`, which does not exist, so it reads
correctly on the branch and is dead once it lands, and `open-pr`'s link gate refuses it. This is what
`<branch>.md`'s own header boilerplate means by *"Relative links in that text resolve FROM THIS DIRECTORY."*
(It was root-relative until issue
[#1041](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1041), which moved the gate's base to the
changelog's own directory when `CHANGELOG.md` moved off the repo root.)

**This repo's audience tier — the seam table below answers it, and the answer is what shapes the entry:
two questions rather than four.** Tier 0 needs no heading —
the `### DEPLOY: <branch>` line is its section and its answer goes directly underneath — and the one
audience tier gets `#### What makes this deploy extra special`. Both sit at the entry's own section level,
beside `#### Pull Request`. A repo that has stated *no* audience tier gets the older shape instead, a
`##### Tier N` sub-section per tier, nested one level deeper; that is the portable half's fallback and not
what you will see here.

**In each tier, the reason goes ABOVE the `**Score:**` line** — anything below it is discarded.

### The gates on the branch document, and the ones that fire beside them

**This was `dkj-policy/CONTRIBUTING.md`'s PULL REQUEST step until #2179 retired that page**, on the same
reasoning as the section above
([why, and where the rest of it went](specialist-06-16-lens.md#the-two-pages-the-workflow-folder-used-to-carry-and-why-they-are-gone)):
the portable page states the cycle, and what stays here is this repo's own answers plus the measurement
behind each gate.

`open-pr.ps1` is the one entry point: it runs the lint and test gates first, then pushes, then opens the PR.
On an error or a failing suite **nothing is pushed and no PR is opened** — `-SkipLint` / `-SkipTests` are the
escape valves, and using one is a decision rather than a convenience. **A gate that will not *finish* is a
third case, and `-SkipTests` is the wrong answer to it**; `-MaxParallel` is, and the numbers behind that —
716s against 888s, and why the default was deliberately left alone — are in the `#1443` paragraph above
rather than repeated here.

`open-pr.ps1` composes the PR body from the document, and **the gates below read it on the way**. All but
the last run locally, before the push and before the merge; that one runs in CI, and it exists because the
local gates are escapable by not using the scripts. The repo's own lint and test gates are separate and
stated in [`this-repo.md`](../../rules/this-repo.md): `open-pr.ps1` runs
[`check-plugin-integrity.ps1`](../../../scripts/lint/check-plugin-integrity.ps1) and then every
`scripts/tests/*.tests.ps1`, refusing to push on any error or failing suite.

#### The label gate, which reads nothing on the branch at all

**One gate fires at the push and looks only outward: the PR's label has to exist.** The label comes from the
branch prefix via the repo-owned seam table, and it used to go straight to `gh pr create --label` — so a
label that had been renamed or retired killed the create *after* every gate had run and the branch was on
`origin`, leaving a pushed branch with no PR. One `gh label list` now answers it ahead of the lint and test
gates. It refuses rather than falling back to a default label, because a repo whose own workflow gates on the
label would otherwise go green on a label that says nothing; the refusal names the label, the prefix, the
seam file and the labels that do exist. Measured in a consumer on September 1, 2026 (inbound
[#1221](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1221)), where two labels were deleted
org-wide because the issue **type** now carries that classification — the seam table was correct the day
before. Full mechanics on the
[`open-pr` skill page](../../../plugins/dkj-policy/skills/open-pr/SKILL.md#the-label-gate-does-the-label-your-seam-names-still-exist).

#### Before any gate, one thing that is not a gate: the document commit

**`open-pr.ps1` COMMITS the development document if it differs from `HEAD`**
([#1269](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1269), September 3, 2026).
Every gate below reads the working tree; the push ships `HEAD`; and the fold, the DEPLOY lock and the CI
check all read the committed copy. Measured on PR #1267: the run passed every gate against a filled-in
working copy, pushed the empty scaffold, published the filled-in body, and CI failed on arrival. It commits
that one file and nothing else — never `git add -A`, and anything else you had staged stays staged. Why it
commits rather than refusing, and why neither the dirty-tree warning nor the backing gate covered it, are on
the
[`open-pr` skill page](../../../plugins/dkj-policy/skills/open-pr/SKILL.md#the-document-commit-what-the-pr-says-is-what-the-branch-carries).

#### the entry gate, on whether there is an entry at all

**September 8, 2026 ([#1632](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1632)).** Before
any of the gates below reads the entry, `open-pr.ps1` asks whether there *is* one:
`Test-DevelopmentEntryMissing` refuses a `dkj-policy/<branch>.md` whose DEPLOY section is gone.

**It is a separate gate rather than a widened scaffold gate, and that is the part only the code explains.**
The scaffold gate below refuses an entry still carrying the scaffolder's wording — so it works by *matching*
strings. Delete the section that carried them and there is nothing left to match: `Get-DevelopmentEntryText`
falls back to the whole document, hands the scaffold gate the guidance **preamble**, and that preamble
carries no scaffold marker because nobody scaffolded it. **So the scaffold gate passes by ABSENCE**, and the
branch ships with no entry text whatsoever — with the PR title and description composed out of the guidance.
The fallback cannot simply be narrowed, either: a legacy entry-only file *is* an entry from its first line,
which is why this is a second predicate beside it and not a stricter version of it.

**How a document reaches that state is not a deliberate deletion.** It is an edit that anchors on the first
phase heading as a plain string and truncates the file there. In a document scaffolded before
[#1654](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1654) that string occurs **twice** —
once as the real heading, and once inside the guidance blockquote describing it, which comes first — so the
cut lands on the wrong one and the body glues onto a sentence cut in half. Two documents shipped that way
(#1632 and #1644) before the gate existed. The guidance names that heading by position now, so a document
scaffolded since carries it once; every branch open across that change still carries both, which is why the
gate's own refusal keeps naming the literal as a diagnosis.

**`-Force` is honoured**, matching the scaffold gate below rather than being absolute. There is no document
this house wants pushed in this state, but the predicate reads a *shape*, and a consumer holding one nobody
here has seen must have a way past a gate that is wrong about them. The refusal names the file, says the fold
would otherwise paste the guidance into the changelog as the change description, and points at `new-branch`,
which is idempotent and restores the section.

**The same predicate runs in CI**, ahead of the same scaffold check in
[`check-branch-entry.ps1`](../../../scripts/lint/check-branch-entry.ps1) — one definition in
[`entry-scaffold-lib.ps1`](../../../scripts/lib/entry-scaffold-lib.ps1) rather than two free to disagree.

#### the scaffold gate, on the changelog entry itself

**August 3, 2026.** `open-pr.ps1` refuses to push a branch whose entry still carries the wording
`new-branch.ps1` scaffolded it with — the placeholder title, the "to do / where I left off" heading, or the
fallback body. **Measured, after it had already shipped:** three of v3.2.0's twenty-one entries kept that
heading with a status appended behind it, and it reached the release notes *and* the per-plugin `CHANGELOG.md`
files that travel to consumers in the plugin cache. The window closes at the merge and closes **invisibly** —
the fold moves the entry into [`CHANGELOG.md`](../../../dkj-policy/CHANGELOG.md), the next release moves it on
into `releases/`, so by then the place a reviewer would look is the one place it no longer is. Fenced code is
excluded, so an entry documenting this mechanism is not accused of it; the escape valve is deliberately
separate from the lint and test skips, because it overrules a judgement about content rather than skipping a
tool. The wording lives in **one** shared source
([`entry-scaffold-lib.ps1`](../../../scripts/lib/entry-scaffold-lib.ps1)) read by both the script that writes
it and the gate that refuses it — a copy in each would make the gate silently miss whatever the writer
changed.

**Two of those three strings are now recognised without being written** (August 6, 2026). The `branch/` split
moved the step list out of the entry, so the entry is no longer scaffolded with a to-do heading over a to-do
placeholder — its placeholder asks what the change *does*. The gate keeps refusing the retired wording, and
that is not politeness towards history: every branch in flight, here and in every consumer, carries an entry
with those strings right now, and consumers receive the new scripts through a plugin update rather than by
choosing to. A gate that forgot them would wave exactly those entries through. **Recognise both, write one** —
the same rule the tier line gets, and the same rule the `dkj-policy/` folder rename got.

#### the step-list gate, on the branch's own plan

**Dave, August 6, 2026.** A branch reaches a PR when its own plan is finished, so `open-pr.ps1` refuses to
push and `ship-pr.ps1` refuses to merge while the step half of `<branch>.md` has an unresolved step.
**Both**, deliberately: the requirement Dave gave is about the *merge*, and `open-pr` has an escape valve — a
PR opened through it, or by hand on github.com, would otherwise land with an unfinished plan.

**Three marks, not two.** `- [x]` is done, `- [~]` is dropped with the reason kept on the line, and a step
still carrying the scaffold's placeholder is refused whether or not it is ticked. The third mark is what makes
the gate safe to leave with no override at all: without it the only way past a step that turned out not to be
needed is to tick it, which teaches people to report work they did not do — and a gate that then says success
is worse than no gate. **A branch with no step list at all is not refused**: that is the one-commit typo fix,
and refusing it would make the mechanism ceremony.

**At the merge, this gate and the DEPLOY lock below read the branch's own commit — `refs/heads/<branch>` — and
not the checkout** (issue [#970](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/970),
August 27, 2026). `ship-pr` waits on CI, 10m57s on the run that measured this, and a session that backgrounds
the ship and starts the next piece of work has moved `HEAD` by the time the gates look. Measured then: the gate
refused PR #969 over `- [ ] TODO: the first step of this branch`, the scaffold TODO of a branch created *during*
the wait, while the PR's own document had no open step at all. **That instance failed safe and the inverse is
why it was repaired**: reverse the two documents — the shipping PR carries an unresolved step, the checkout has
since moved to a branch whose steps are all ticked — and the gate passes on somebody else's document and merges.
A gate with no `-Force`, satisfied by a file the PR does not contain, reports the requirement as met while
nothing checked it.

**The remedy is a different read, not a new refusal.** The other shape on the table was to refuse once `HEAD`
has moved since the run started, and it was declined: a backgrounded ship beside the next piece of work is the
ordinary shape of that window, so that guard would break the ordinary case in order to protect it. The commit
is also *provably* what merges — step 1 pushes the branch on every path through the script, a fresh PR and a
resumed one alike — and it needs no network, which matters in a gate that must not refuse because a token
expired. **The path is resolved against that same commit**, not merely read out of it: `Resolve-BranchFilePath`
chooses between the candidate names by reading each one, and resolving against the checkout would fail in the
silent direction — a name the branch does not carry reads as *no document at all*. One consequence worth
knowing: **a step ticked in the editor and not committed no longer satisfies the merge gate**, which is what
its own message has always asked for.

#### the backing gate, on whether anything is behind the plan

**Dave, issue [#1026](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1026),
August 28, 2026.** The step-list gate above asks whether the plan is *finished*. It cannot ask whether
anything was actually built, and nor can the three gates beside it: **all four read this document, and none
reads the diff**. So `open-pr.ps1` asks the second question — a plan reading as finished with **nothing
committed on the branch besides this document** does not become a PR.

**What it was measured on.** PR #1025 merged an entry describing two new rules in a manual whose edit was
never committed. The branch's whole diff was `<branch>.md`; the fold then *removes* that file, so the merge
delivered a changelog entry and no content at all. Every gate was green.

**The measurement is not new — its delivery is.** `park-cycle`'s backing note
([#960](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/960), repaired by #976) had already named
the count, named the state and given the instruction that would have prevented the merge. It wrote it into a
**commit body**, which is exactly right for the reader that note exists for — a session on a second device
picking the branch up from origin — and invisible to the session that is holding the uncommitted file and
about to open the PR. Both readers now ask one function, `Get-BranchBackingFinding`, so a park that alarms and
a gate that stays silent cannot disagree over one tree.

**Two shapes, two answers, and the split is by whose fault it is.** Work sitting uncommitted **in this working
copy** is this session's own omission and one `git commit` from repaired — that one is **refused**. **Nothing
uncommitted here either** means the work is not on this machine at all, which from here cannot be told apart
from a branch legitimately shipping its entry alone — that one is **said out loud and allowed**, because
refusing it would wedge the cross-device flow #960 exists to serve.

**It is `-Force`-able, unlike the step-list gate above.** The valve exists because a branch whose whole
deliverable really is the changelog entry is rare rather than impossible, and `-Force` still prints the warning
— a gate whose escape valve falls silent is a gate that quietly stopped existing.

**And the gates now say when they ran against a dirty tree.** This is the other half of the same measurement,
and it is a sentence rather than a refusal. The lint gate and the suites judge the **working tree**; the push
ships **HEAD**. On a clean tree those are the same thing and a green result is evidence about the PR; on a
dirty one they are not, and nothing said so — #1025's lint run walked the manual *with* both new rules in it
and reported zero errors. `Get-GateFingerprint` cannot answer this: it hashes the dirty list away, so it knows
*same tree as last time* and never *is this tree HEAD*. A dirty tree mid-flight is ordinary, so it is never
refused here; what was missing was only the line that stops a green result from being read as proof.

#### the DEPLOY lock, on the section the PR published

**Dave, issue [#884](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/884), August 25, 2026.** The
DEPLOY section travels four times — this document, the PR body,
[`CHANGELOG.md`](../../../dkj-policy/CHANGELOG.md), the developer release notes — and it has to be the same
thing at every stop. So it is **fixed at the moment the PR opens**: `ship-pr.ps1` refuses the merge when the
document has since diverged from what the PR carries. No override, like the step-list gate beside it.

**What it closes is a window that shuts invisibly.** An edit made after the review lands in `CHANGELOG.md` and
from there in the release notes having been seen by nobody — and the fold *removes* this document at the
merge, so the place a reviewer would compare the two is the one place it no longer is. The same shape as the
scaffold gate's own measurement, one document further along.

**The PR is the recorded copy, so the lock stores nothing.** Three mechanisms were weighed and Dave chose this
one: compare against the open PR. A fingerprint stamped into the document would add an artefact to the file
the fold consumes and have to be stripped again on the way out; a silent re-sync at merge time refuses nothing
and is therefore not a lock. `open-pr` already publishes the section, and reading it back *is* the comparison.

**It is checkable at all only because the section now travels verbatim.** Until the same issue,
`Get-PrDescription` dropped the `### DEPLOY:` heading and promoted every remaining one — so body and document
were two *renderings* of one section, and a comparison would have had to reproduce that transform to make
sense. The heading travels now, which reverses the August 9, 2026 promotion **on today's shape only**; the
legacy path keeps promoting, because there the H2 genuinely stays behind. The reasoning sits at both branches
in `pr-body-lib.ps1`. **An unreadable body is not a finding** — `gh` failing says something about the token or
the network, not about the section, and a gate that refused on that would be refusing on no evidence.

**Which copy of the document it compares is the last paragraph of the step-list gate above**, and it matters
more here than there: this section is what the fold puts verbatim into `CHANGELOG.md`, so a lock satisfied by
a stray checkout's document would be approving the fold of a section it never read.

#### the shape gate, on the document around the entry

**September 8, 2026**
([#1650](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1650)). Two rules Dave enforced by
reading on August 26, 2026 — **four `###` headings and never a fifth**, and **nothing branch-specific above
`### PLAN`**, both stated in the section above — were checked in exactly one place: the CI gate below, which
*reports* rather than refuses. So none of the gates above ever saw them, and nothing refused a malformed
document before the push.

**What that cost, measured on this repo's own PR #1644.** Its document lost its `### PLAN` heading and most
of its guidance block to a splice that anchored on the string `### PLAN` — which occurs inside the guidance
blockquote as well, in the very line forbidding branch-specific content above it. Push, PR, the required
check, the merge and the fold all completed. Each gate above was right on its own terms: every step above
DEPLOY was resolved, DEPLOY matched what the PR published, and there was committed work behind the plan.

**And an advisory red is the wrong instrument here, for a reason peculiar to this document.** The fold
**removes** `dkj-policy/<branch>.md` on success, so after the ship the red check points at a path that no
longer exists and a reader following it finds nothing to open. The evidence is destroyed by the thing whose
success it was warning about — a far weaker signal than an ordinary advisory failure, where the file is still
there to inspect.

**The repair was the seam, not a new rule.** Both rules are one function now,
`Get-DevelopmentShapeFindings` in `entry-scaffold-lib.ps1`, so `open-pr` refuses on them while the file is
still on disk and the author is still holding it, and the CI gate below reports exactly what it reported
before, on the same text, from the same code. **It fires between the scaffold gate and the step-list gate** —
the numbering here is reading order, and the run order asks three questions about one document: is there an
entry, has it been written, does the document around it still hold its form.

**`-Force`-able, like the scaffold gate above** and for its reason: the predicate reads a shape rather than
words, and a consumer holding a document nobody here has seen must have a way through a gate that is wrong
about them.

**The scoping is asymmetric, and that is the design rather than an inconsistency.** The heading count is the
source repo's own rule — [`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md)
states heading-blindness as a *feature*, because a consumer may keep headings of their own in a document they
adopted — so it runs behind `Test-IsWorkflowSourceRepo`, and the caller passes that answer in. The preamble
rule holds **everywhere**, because it reads the shape and not the text: the guidance block is blockquoted in
whatever language it was translated into.

**Two things this deliberately did not do.** `branch-entry` was **not** made a required check — that is a
ruleset change and the owner's own act, and it would put a check that *reports* significance in front of every
merge. And the CI half still reports rather than refuses, which is the design stated immediately below.

#### the CI gate, because the gates above are local

**August 20, 2026** (inbound
[#789](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/789)). The gates above live in
`open-pr` and `ship-pr`, so every one of them is escapable by not using them: a branch pushed by hand, or a PR
opened in the GitHub UI, meets none of them. The convention was therefore enforced by whoever remembered the
scripts — and a convention that enforces nothing rots quietly, which matters here because `CHANGELOG.md` is
the only readable answer to "what is merged but not yet released".

**It re-checks every one of them but the backing gate, and that exclusion is deliberate** (August 28, 2026).
That gate's whole subject is what sits **uncommitted in a working copy**, and a CI runner has no working copy
— it checks out the commit, so its tree is clean by construction and the measurement there would always read
zero. A check that cannot fail is not a check, and adding one would state a guarantee CI is in no position to
make. The half of it that *is* visible from a commit — a branch whose diff is its development document alone
— stays local on purpose too: it is a judgement about whether a change was finished, which belongs where the
author can still act on it.

[`check-branch-entry.ps1`](../../../scripts/lint/check-branch-entry.ps1) closes that, and
[`.github/workflows/branch-entry.yml`](../../../.github/workflows/branch-entry.yml) is the handful of lines
that call it on every PR. **It adds no rule of its own** — it calls the same `Test-BranchChangelogIsFilled`,
`Get-EntryScaffoldFindings` and `Get-DevelopmentShapeFindings` that `open-pr` calls, and, given the PR
number, the same `Test-DeployLock` that `ship-pr` calls. So there is one definition of "written" in the
system, one of "in shape" and one of "diverged", rather than a second set in CI. **That claim only became
exact on September 8, 2026**: the shape rules were this script's own until #1650 moved them out, which is
the whole of that issue — a sentence promising no rule of its own, standing over the one rule that lived
nowhere else. **Reading a PR body is why the workflow carries read access to pull requests** — the entry
checks themselves need no token, no network and no PR, so the lock is opt-in by parameter and the gate stays
runnable on a branch that has none.

**Two consumers had already written this gate by hand, and both had drifted from the convention** — that is
the measurement behind shipping it rather than documenting it. Each refuses a merge over a missing significance
score, justified in one of them by *"tier 0 can never legitimately stay empty"*, while
`entry-scaffold-lib.ps1` reads **TIER 0 OWES NOTHING** and Dave placed that refusal at the release cut on
August 5, 2026, precisely so an author who has not settled a score is not blocked from merging over it. So the
shipped gate **reports** the significance and names the cut as where the refusal lives. It is simpler than the
hand-written version, not more complex: `Get-EntryScaffoldFindings` already catches the case those gates
reached for the score to catch — a freshly scaffolded entry, which carries an H2 and a title and so passes any
heading test.

**Its own workflow file, not a job in `ci.yml`**, and the trigger is the reason: `ci.yml` also runs on a push
to `main`, where there is no branch document at all. A job there would be red on the trunk after every merge.
The script answers the trunk case gracefully as well, but a gate should not need that grace to be pointed
correctly. **It is not in the `main` ruleset** — making a check required is a repo-settings change and
therefore the owner's, so today it reports on every PR and blocks nothing.

#### the always-on budget gate, on what every session pays before any of this

**Dave, issue [#2037](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2037), September 16, 2026:**
*"find a durable way for ALL consumers to keep CLAUDE.md under 100.0k chars, because I notice it goes over
150k everywhere."* Every gate above judges the branch — its code, its entry, its plan. This one judges the
**always-on document path**: `CLAUDE.md` plus everything it `@`-imports, which every future session in this
repo reads before a single assignment is given.

**The finding is that measurement alone had already failed.** `measure-always-on.ps1` has reported this
figure since August 2026 and reaches no verdict by design
([#861](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/861)) — and all four measurable repos
went over 100,000 B anyway: 199,253 B, 150,202 B, 117,014 B, and this repo at **109,385 B**, the smallest of
them. A report that is portable, correct and ignored is the whole argument for a bound.

**The unit is the path and not the root file**, because `wc -c CLAUDE.md` misses the 30,267 B of orchestrator
persona that `SPECIALISTS.md` imports from the marketplace clone — 27.7% of this repo's total, and invisible
to the obvious check.

**A ratchet, not a cliff, and that is the choice it lives or dies on.** Every measurable repo was over on day
one, so a hard refusal is a gate that is `-Force`d once and never obeyed again. Instead the limit is
`max(budget, baseline)`: over the ceiling the recorded baseline holds and **growth** is refused, at or under
it the ceiling holds and **crossing** is refused. The baseline falls on its own whenever a branch measures
less — `open-pr` writes it and commits it with the branch's own document — and rises only under
`-Raise -Reason "<why>"`, which puts the reason in a tracked file where a reviewer can argue with it.

**The refusal names where the weight goes**, in the order the four classes pay: procedure a plugin already
ships on demand; layer-specific detail into `.claude/rules/*.md` with `paths:`; evidence, measurement and
declined-option history into the owning specialist's lens or a skill page; repo-specific craft detail into
that lens. A ceiling with no destination is a red check nobody can clear.

**Three carriers, one verdict, and only one of them writes.** `open-pr` before the push (with `-Record`),
`.github/workflows/always-on-budget.yml` on every PR, and the `always-on-sessioncheck` SessionStart hook,
which prints the headroom so the number is in front of whoever is about to add to it rather than discovered
at a red check. Every decision sits in `always-on-budget-lib.ps1`; the check script is the printing and the
exit code. CI and the hook never pass `-Record`: a read-only carrier that rewrote the ratchet's own memory
would be the one thing able to raise it with nothing in any diff to say so.

**And one premise the issue never weighed, which would have made the whole thing flap.** A CI runner has no
marketplace clone, so that 30,267 B persona import does not resolve there — the same commit would measure
109,385 B locally and 79,118 B in CI. The baseline therefore records every document's size **keyed by its
import target**, and a run that cannot resolve one carries the recorded figure and says so. A document that
is neither resolvable nor recorded is reported as **unmeasured** and never counted as zero: a path that looks
healthier than it is would be this mechanism failing in the direction nobody notices. For the same reason the
arithmetic is in **LF bytes** rather than on-disk bytes — a CRLF checkout is one byte per line above what the
repository stores, which is ~1.4% on a 1,346-line file: plausible, wrong, and enough to refuse a branch that
changed nothing.

**Like `branch-entry`, it is not in the `main` ruleset** — a required check is the owner's act, not a script's.

### The `dkj-policy/` folder, and this repo's answers to the portable seams

**This was `dkj-policy/README.md` until #2179 retired it together with the CONTRIBUTING page beside it**
([why, and where the rest of it went](specialist-06-16-lens.md#the-two-pages-the-workflow-folder-used-to-carry-and-why-they-are-gone)).
Everything portable about the `dkj-policy` workflow gathers in that folder, so the workflow occupies one
folder in the repo root instead of scattering through it (Dave, August 14, 2026); the conventions themselves
travel with the plugin, and what follows is **this repo's own set of answers** to them.

#### What the folder holds

| here | what it holds | portable half |
|---|---|---|
| [`CHANGELOG.md`](../../../dkj-policy/CHANGELOG.md) | what is pending for the next release: one `##` entry per merged branch, folded in at the merge and emptied by a cut. Here since August 27, 2026, stated in `Get-ChangelogPath` | *(the format travels in [`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md))* |
| `<branch>.md` | the branch's own document, one per branch and present only while that branch is open: its plan, and the DEPLOY section that folds into the changelog | [`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md) |
| [`releases/`](../../../dkj-policy/releases/) | the dated list of every release ever cut ([`history.md`](../../../dkj-policy/releases/history.md), here since August 27, 2026), the published audience notes, and the generated changelog and GitHub-Release trees. **The seam answers that sat here in a `README.md` of its own are gone** — #2196 retired that page with the two above it, and they are split between [Rendall's lens](specialist-05-06-lens.md#versioning--releases) and the two sections below | [`RELEASES-portable.md`](../../../plugins/dkj-policy/RELEASES-portable.md) |

**A fourth row sat at the top of that table until #2179** — the folder's own `CONTRIBUTING.md`, which held the
standard branch + PR workflow and the working rules a session needs here on one page. Two of those three
merged on August 26, 2026 (#886) and the standard workflow arrived from the repo root on August 27; all of it
is now either in [`CONTRIBUTING-portable.md`](../../../plugins/dkj-policy/CONTRIBUTING-portable.md) or in the
two sections above.

**The last three documents moved in on August 27, 2026** (Dave), and the seam answers below are what say so
rather than the computed defaults doing it silently: `CHANGELOG.md`, the contributing page's own
standard-workflow half, and the release list — which became `releases/history.md` rather than a second
`README.md`. From that day the folder stopped being *the workflow's belongings beside the repo's own* and
became every document the contribution cycle produces or governs. **Nothing about a consumer changed with
it**: the computed defaults have pointed at this folder since #885, and this repo was the one holdout
answering otherwise — which is the shape to watch for whenever the source repo sets a seam by hand.

In this repo the portable pages resolve as relative links because this is the plugin's **source**; in a
consumer they live in the plugin install instead, which is why the consumer version of the folder's own README
named them in code rather than linking them. **`adopt-dkj-policy`'s Part 1 scaffolded those pages into a
consumer until [#2171](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2171) and
[#2196](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2196) stopped it**, so a repo adopted
since gets none of the three and one adopted before keeps whatever it has, reported as legacy and left
untouched. **The scaffold refuses a repo that publishes
plugins**, so this folder's pages were hand-written for as long as they existed: a **scaffolded** page was
the one thing a consumer's folder had that this one never did. The generated
`releases/changelog/` and `releases/github/` trees sat at this repo's root until August 26, 2026 and now sit
in the folder too, so on that point the two match (#914).

#### The seam, answered — the whole table in one place

This is [`scripts/repo-config.ps1`](../../../scripts/repo-config.ps1) read as prose: every question the
portable half leaves open, this repo's answer, and the `Get-*` function that declares it.

| the portable half says | this repo's answer | declared in |
|---|---|---|
| your lint gate | [`scripts/lint/check-plugin-integrity.ps1`](../../../scripts/lint/check-plugin-integrity.ps1) | `Get-LintScript` |
| your branch prefixes | `feat/` · `fix/` · `docs/` — and **no `chore/`** | [`scripts/lib/branch-info.ps1`](../../../scripts/lib/branch-info.ps1) |
| the type an unknown prefix falls back to | `Chore` | `Get-EntryFallbackType` |
| your audience tier | **2** — a service, not a product | `Get-ReleaseAudienceTier` |
| your entry's section headings | the English defaults — nothing is overridden | *(no override defined)* |
| the wording inside the development document | the English defaults | `Get-BranchFileWordingOverrides` *(none)* |
| your significance rubric | the shared default, 1–5 | *(no override defined)* |
| your permanent root docs | `CHANGELOG` · `CLAUDE` · `README` · `LICENSE` · `CONTRIBUTING` · `SECURITY` · `INSTALL` · `UNINSTALL` — **`CHANGELOG` and `CONTRIBUTING` left this repo's root on August 27, 2026 and stayed on the list**: it names a permanent document, not one this repo holds at its root today, and the portable `cut-release` reads it, so taking them off the same day broke the cut (the comment above `$script:ReservedRootMd` in [`repo-config.ps1`](../../../scripts/repo-config.ps1) has the reasoning; `ReservedNames` in [`Get-BranchFilePaths`](../../../scripts/lib/entry-scaffold-lib.ps1) records the same rule for the workflow folder's (`dkj-policy/`) own pages) | `Get-ReservedRootMd` |
| where your changelog lives | `dkj-policy/CHANGELOG.md` — the consumer default, which this repo adopted on August 27, 2026 (the folder renamed on September 5, #1437) | `Get-ChangelogPath` |
| where the release list lives | `dkj-policy/releases/history.md` | `Get-ReleaseHistoryPath` |
| where the generated internal note goes | `dkj-policy/releases/internal` | `Get-ReleaseInternalNotesRoot` |
| your merge method | `merge` — a merge commit, not a squash | `Get-PrMergeMethod` |
| whether you have a plugin tier | yes — the `Plugins:` line is derived | `Get-ReleasePluginTier` |
| whether you have a separate live stage | **no** — which is what makes the cycle's live step a no-op here | `Get-LiveStage` |
| how release notes are foldered | per **major** (`3.x`) | `Get-ReleaseNotesGrouping` |
| where the hand-written notes live | `dkj-policy/releases/audience` | `Get-ReleaseNoteRoot` |

All of them live in [`scripts/repo-config.ps1`](../../../scripts/repo-config.ps1) except the prefix table,
which is its own repo-owned lib. Where the table says *no override defined*, this repo deliberately runs on
the shared default — that is an answer, not an omission.

#### The release-notes page, and the worker that serves it

**This block was `dkj-policy/releases/README.md`'s until #2196 retired that page** together with the two
beside it ([why, and where the rest of it went](specialist-05-06-lens.md#versioning--releases) — the
release *answers* are Rendall's; the hosting is machinery and is therefore here).

The hand-written notes are also readable as one hosted page (Dave, August 15, 2026).
[`build-release-notes-page.ps1`](../../../plugins/dkj-policy/scripts/release/build-release-notes-page.ps1)
builds every document under `audience/` into one page with a picker per release; the portable half — what
the page is, why it is generated rather than edited, and what hosting it decides — is in
[`RELEASES-portable.md`](../../../plugins/dkj-policy/RELEASES-portable.md#giving-that-note-a-reader-shaped-home--the-release-notes-page).
This repo's answers:

| | |
|---|---|
| `Get-ReleasePageTitle` | `Claude Specialists` — the **product's** name, not the repository's and not what the page is. It is the masthead eyebrow and half the window title; the heading is the template's own *Release notes*. Without it the fallback would head the page `claude-code-specialists`, which is a true answer and not one to send anybody. It carried `-- release notes` until 2026-08-21, which printed those words twice |
| `Get-ReleasePageWorkerName` | `''` — hosted nowhere since October 17, 2026 (below) |
| where the output lands | `dkj-policy/releases/page/`, derived from `Get-ReleaseNoteRoot` rather than configured — the note root already says where this repo keeps its release documents |
| where it is read | the dkj-policy general pages server serves it at `http://localhost:<port>/release-notes` (a port from 4890 to 4899; the Repo hub the session start prints links it from its General card, and the repo's own server redirects `/release-notes` there), which opens in VS Code's Simple Browser |
| what is committed | **nothing from that directory.** The page is a derivative of the tracked documents, and a 400 KB file changing every release would dirty the tree `cut-release.ps1` refuses to run on |

**Only BWJ-Development hosts its release notes on Cloudflare** (Maikel, October 17, 2026,
[#3083](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3083)): colleagues there read them from
any device. A DKJ repo's notes are read by the owners on their own machine, so this repo answers the worker
seam with `''`, and `cut-release` no longer prints the redeploy step. From August 15, 2026 until then the
page was served by the `ccs-release-notes` worker, whose path token was local, gitignored state, so a cut on
any machine without that file stopped at the redeploy
([#2868](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2868), #3083). The worker itself was
deleted from the DKJ-Solutions Cloudflare account on October 17, 2026
([#3086](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3086)), so an old link to it no longer
shows stale notes.

#### Where the rest lives

- The document a branch works in, its four phases and the three step marks:
  [`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md).
  **This repo keeps no local half of it** (Dave, August 23, 2026), which is the one place the portable/local
  split is not followed, and deliberately: that page was `branch/README.md`, and once the two branch files
  merged its prose would have had to be reproduced byte-for-byte by a *portable* formatter inside every
  branch's own document — repo-specific prose generated by a portable formatter cannot be right. Its answers
  moved to the pages that already own them: the file rules to the development section above, the seam answers
  to the table above.
- **The lint gate holds the document's shape here, which a consumer's repo typically cannot.** Three checks in
  [`check-plugin-integrity.ps1`](../../../scripts/lint/check-plugin-integrity.ps1) do it: **no document
  declaring the trunk survives a fold** anywhere in the tree, which is what replaced holding an empty copy
  byte-for-byte to the formatter once that copy stopped existing; the **entry-shape** claims in prose are held
  against the section count the scaffolder writes; and the **heading-level** rules are enforced against the
  DEPLOY section, read out of the document with its line offset so a finding names the line you can find. In a
  consumer none of that runs — the plugin ships no `scripts/lint/` — so there, the document is the only
  statement of its own shape. That is also why the guidance lives inside it.
- The cycle as a portable page, with the seams named:
  [`CONTRIBUTING-portable.md`](../../../plugins/dkj-policy/CONTRIBUTING-portable.md) — and the reason the
  split exists at all is
  [inbound #566](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/566), from a consumer who tried
  to adopt this repo's own page and measured why it could not be done.

In short: the **how** (managing the harness, scripts, config, safety guards) is portable; the **what**
(the plugin lint + drift lint, `branch-info.ps1`, `.claude/settings.json` with the github source, and
the marketplace/plugin manifests) belongs to this repo.
