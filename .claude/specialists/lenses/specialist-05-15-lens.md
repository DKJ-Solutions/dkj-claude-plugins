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
  marketplace (#1669): a dispatched subagent may not run the git commands that discard the checkout it
  was dispatched into. Its judgement is `scripts/lib/working-copy-guard-lib.ps1` and its
  false-positive machinery `scripts/lib/command-guard-lib.ps1`, both mirrored into the plugin. Before
  changing it, know:
  - **The gate is `agent_id`, never `agent_type`**: the latter is present on the main thread of an
    `--agent` session, so keying on it would refuse the orchestrator there.
  - **The cost is per tool call, not per session.** The main thread pays the hook and is never judged by
    it, so the `agent_id` question is a string test on the raw payload *before* any lib is dot-sourced.
  - **The judgement takes a project root**, and `.claude/worktrees/agent-<id>` is carved out of it: an
    agent granted worktree isolation owns that tree and the harness puts it inside the repo (the one
    false positive measured was a test engineer in its own fixture repo under `/tmp`).
  - **Measuring subagent calls**: their turns live in
    `~/.claude/projects/<project>/<session>/subagents/agent-<id>.jsonl` (`isSidechain: true` plus
    `agentId`), not in the session transcript. A walk of only the top-level `*.jsonl` reads zero subagent
    calls and looks complete.
  - **Decided in:** [#1669](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1669). The
    measured figures are in this file's history.
- **The `statusLine` in [`.claude/settings.json`](../../settings.json), and the progress mechanism behind
  it** — `scripts/task/show-progress.ps1` renders, `scripts/lib/run-progress-lib.ps1` is what a
  long-running script publishes to. The producers are the test gate (both lane events in
  `Invoke-TestSuiteGate`), `ship-pr`'s CI wait
  ([#2101](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2101)) and the lint gate
  ([#2173](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2173)), which publishes from
  `Invoke-WorkflowGates` around its child call: a label and a start, **no counts and so no bar**, because
  `check-plugin-integrity.ps1` has no total to publish. Before changing it, know:
  - **A published record, not a printed line**: a run a session backgrounds (`run_in_background`) prints
    to nobody, and the statusline is the one surface that keeps rendering. A run this repo does not own (a
    backgrounded `npm test`, `gh run watch`, a subagent) publishes nothing; parked as
    [#2104](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2104).
  - **`refreshInterval` is in SECONDS** and is not optional: the event-driven triggers go quiet while a
    session is idle. Set as `2000` it read as 33 minutes and the timer never fired
    ([#2163](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2163));
    `adopt-statusline.tests.ps1` refuses a figure above 60. The unit is stated at
    <https://code.claude.com/docs/en/statusline>.
  - **Liveness is the writer's process, never the record's age** (a healthy `gh pr checks --watch`
    publishes once, then blocks for minutes). The record carries the run's START and the renderer derives
    the elapsed; the pid is paired with the process's start time so a recycled pid cannot resurrect a
    finished run's bar.
  - **The glyphs are ASCII**: a block-character bar would need the console-wide
    `[Console]::OutputEncoding` that [`language-layers.md`](../../rules/language-layers.md) forbids.
  - **No bar without counts, and no ETA ever** — a fraction nobody measured is an invention (#1717).
  - **It publishes only at gate depth 1** (`DKJ_TEST_GATE_DEPTH`), so a suite's fixture lint does not
    repaint the test gate's bar.
  - **The script never throws and always exits 0**, and reads the branch out of `.git/HEAD` as a file: at
    a 2-second cadence a failure is a broken status line repeated forever, and each refresh already pays
    the bare `powershell` launch (~200 ms).
  - **The dot-source into `native-capture-lib.ps1` is guarded** (`Test-Path`), which keeps that file
    byte-identical to its two mirrors: `run-progress-lib.ps1` is not mirrored, so a consumer's gate
    behaves as before. Shipping the bar to consumers is parked as
    [#2103](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2103).
  - **Decided in:** #1717, #2101, #2103, #2104, #2163, #2173. The measurements are in this file's history.
- **`scripts/lint/check-plugin-integrity.ps1`** — the PR lint gate: validates `marketplace.json` +
  every `plugin.json` and the agent-def/manual frontmatter (`name`/`id`/`group` + filename match),
  scans for dead links (in `README.md`, `CHANGELOG.md`, the manuals, `SKILL.md`s, and `releases/**`),
  checks that every `scripts/**/*.ps1` parses without errors (catching syntax errors in the
  orchestration that would only break at runtime), and guards (check 7) that every shared-block
  region in an agent def still equals its source in `subagent-shared/`. It is the safety guard that
  [Derek #05](specialist-05-05-lens.md)'s `open-pr.ps1` runs before every push and that `cut-release.ps1`
  runs before a release. The checks worth knowing by number:
  - **Check 28 reads the same scan set a second time for `@`-imports** (#874): a dead link costs a reader
    one click, a dead import costs the session **the whole document** (Claude Code drops it without
    erroring). It reuses `measure-context-lib.ps1`'s parser, so the gate and `measure-always-on.ps1`
    cannot drift on what an import means; a target outside the repo is counted, never refused (a
    `~/`-relative import points into the marketplace clone, which CI does not have).
  - **Checks 9 and 17 are retired** (August 8, 2026) with the documents they guarded, the per-plugin
    `RELEASE.md` card and `CHANGELOG.md`'s intro. The shape to keep: a check that compares two statements
    of one fact is made unnecessary by deleting one of them.
  - **Check 11 guards a doc against reality**: every printed `claude plugin install`/`update`/`uninstall`
    (recognised by its `@`-target, which separates an instruction from prose about the command) must carry
    `--scope project`, and `install`/`update` must name the marketplace refresh nearby. History
    (`CHANGELOG.md`, `releases/**`, root entry files) is excluded permanently. The scope rule is
    **verb-specific** (#315): `uninstall` also accepts `--scope local`, the only command that removes a
    record a session start left at that scope.
  - **Check 12**: a fenced block that reads `installed_plugins.json` *in code* must select `projectPath`,
    `scope`, `version` **and** `gitCommitSha` (#313, #314, #315). Checks 11 and 12 answer the same
    **mention vs. use** question with a positional discriminator.
  - **Check 18 guards the shared source against its own documentation**: every parameter of a mirrored
    entry point must be named in the skill that documents it, since a consumer has only the mirror and
    that page. The mapping and the per-parameter exemptions are declared **in the registry beside the
    registration**, so a newly shared script cannot fall out silently; parameters are read via the
    **PowerShell parser**, because a regex missed `[Parameter(...)]`-attributed ones. An entry point
    declaring *no* skill is reported in the coverage line, not as an error.
  - **Check 23, `[plugin-kind]`**: every published plugin must be `team-*` under `plugins/dkj-subagents/`
    or a way of working by name. Only `*-policy` / `*-policy-*` carry a directory rule on the workflow
    side (`plugins/dkj-policy/`, see
    [#1467](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1467)); `workflow-*`,
    `contributing-*` and `*-codex` are accepted by name and held to no location. The directory half is
    *derived* from the name, so **an unprefixed name switches the check off for itself, silently**. Its
    older reason, the retired `workflow-sessioncheck` hook
    ([#886](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/886)), no longer holds.
  - **Decided in:** #315, #874, #886, #1467. The rounds and measurements behind 11, 12 and 18 are in this
    file's history.
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
  skipped-fold gate (#1270). The workflow runs the check on every `push` to `main`; the check is mirrored
  into the workflow plugin and also driven by `unfolded-entry-sessioncheck.ps1`. Advisory, not in
  `main-ci-gate` (a required check cannot gate a push anyway). Before changing it, know:
  - **One detector, two callers**: `Get-UnfoldedTrunkEntry` in `entry-scaffold-lib.ps1`. It runs from CI
    and from the SessionStart hook because neither reaches the whole population alone, and neither calls
    `gh`.
  - **Its one false positive is the ship window** (`ship-pr` pushes the merge commit, then seconds later
    the fold commit), which **this workflow's own** `cancel-in-progress: true` swallows; `ci.yml` keys
    every push on its own commit (#1294) and swallows nothing.
  - **It tells a SKIPPED fold from a checkout merely BEHIND** (#1585), with no network:
    `Get-TrunkGap -NoFetch` names `refs/remotes/origin/<trunk>`, and each leftover is asked whether **its
    branch's entry is already in `CHANGELOG.md` on that ref** (`Test-BranchFoldedOnRef`). It asks about
    the entry's presence, never the document's absence: **a gap is not a direction**, so a diverged
    checkout would read an unpushed document as a landed fold (#1601). The gap is measured for the wording
    alone.
  - **The match lives in the lib**: `Get-FoldedEntryForBranch` is the one definition of a folded heading,
    so a regex in the check cannot disagree with it.
  - **`Test-BranchFoldedOnRef` returns `$null` for a question it could not ask**, and the check reads that
    as *not folded*: an unanswerable question leaves the `[ERROR]` standing.
  - **In CI the pushed commit *is* `origin/<trunk>`**, so `fold-on-merge.yml`'s
    `'\[ERROR\] the trunk carries'` match is still the exact headline the stranded case prints.
  - **Decided in:**
    [#1244](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1244),
    [#1270](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1270),
    [#1294](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1294),
    [#1585](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1585),
    [#1601](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1601). Measurements are in this
    file's history.
- **`.github/workflows/fold-on-merge.yml` + `FOLD_PUSH_TOKEN`** — the fold that survives a merge the
  shipping session never sees (a queue merge or a UI merge), by running the same fold this repo
  otherwise only runs from `ship-pr.ps1`'s own next step, on every `push` to `main` (issue #1493, PR
  #1507). It re-uses `check-unfolded-entry.ps1`'s own detector and adds no second one; the workflow's
  own header comment carries the full mechanism and is the more detailed of the two. Before changing it,
  know:
  - **It pushes as an org owner, not as the GitHub Actions app, and that is structural.** The default
    `GITHUB_TOKEN` is that app (integration_id 15368), which is not on `main-ci-gate`'s bypass list and
    cannot be added (it is owned by `anthropics`, only installed here). The list carries
    `OrganizationAdmin`, so the checkout step uses `secrets.FOLD_PUSH_TOKEN`: a fine-grained PAT created
    by an org owner, scoped to **this repository only** and **`Contents: Read and write` only**.
  - **It is a standing credential with an expiry, and nothing renews it.** The org caps a fine-grained
    PAT at 366 days; when it lapses the job keeps folding but its `git push` fails, in the same rejected
    shape #1499 measured (the ruleset names `lint-en-tests` and the merge-queue rule together, so read
    the run's own last lines), and nothing announces it ahead of time.
  - **Renewal is manual**: **an org owner of `DKJ-Solutions`** creates a new fine-grained PAT with the
    identical scope and overwrites the secret:
    `gh secret set FOLD_PUSH_TOKEN --repo DKJ-Solutions/dkj-claude-plugins`.
  - **Decided in:** [#1493](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1493),
    [PR #1507](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1507),
    [#1499](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1499).
- **`.github/workflows/verify-resolved.yml` + `scripts/release/verify-pushed-merges.ps1`** — the
  resolves gate's second half surviving the same merge (issue
  [#1511](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1511)), one step further down
  `ship-pr.ps1` than the fold above. `verify-resolved-issues.ps1` is that script's step 6 and ran only
  from the shipping session; since
  [#1506](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1506) enqueues instead of merging,
  that step never runs. GitHub still honours closing keywords on a queue merge, so what went missing is
  the *verification* and the repair when a keyword misses. Before changing it, know:
  - **It repairs rather than only reporting** (Dave's decision on #1511): `verify-resolved-issues.ps1`
    exits 0 whatever it finds, so report-only would leave a still-open issue as one yellow line in a green
    run. So `issues: write` is granted, the first such grant in this repo's workflows.
  - **It is its own workflow, not a step in `fold-on-merge.yml`, to keep that grant narrow**: `issues:
    write` beside a job that checks out with `FOLD_PUSH_TOKEN` would put a year-long credential and
    issue-write in one job. This job checks out with the default `GITHUB_TOKEN` and
    `persist-credentials: false`. Never widen the PAT to Issues instead.
  - **The second reason is coverage**: `fold-on-merge.yml` acts only when a leftover entry exists, this
    check must run for every merge. It resolves its PRs from the **push** (`compare/{before}...{sha}`,
    then `commits/{sha}/pulls`) and reads the whole range, because a queue can land a batch in one push;
    neither call needs history, and the runner checks out at depth 1.
  - **Two defects once exited 0 looking like success**, and
    `scripts/tests/verify-pushed-merges.tests.ps1` pins each by name: a `return ,@($shas)` guard plus `@()`
    at the call site double-wrapped the array (a six-commit range printed `examining 1 commit`), and a
    double-quoted jq filter does not survive the native-argument round trip on Windows (use the
    bracket-plus-`@tsv` form; the suite reads the *recorded arguments*, since a fake `gh` answers either).
  - **Decided in:** [#1506](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1506),
    [#1511](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1511). Measurements are in this
    file's history.

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
  in-process suite bound** ([#2296](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2296)).
  Every job in `.github/workflows/` declares one; before #2296 a wedged job ran to GitHub's six-hour
  default. Before changing a number, know:
  - **A wedge is not a red check.** `lint-en-tests` `needs:` the shards, so it never registers, and a
    required check that never registers reads as *still running* to `ship-pr`, the ruleset and a person.
  - **`$script:GateSuiteTimeoutSeconds` cannot cover it**: that bound is 1800s *per suite* inside the gate
    process; what wedged sat below the level it can reach. That is why this is a different layer from
    #1941/#2233/#2255/#2263.
  - **The `suites` cap is picked against `ship-pr`, not against the suites**: its registration wait
    (`$maxRequiredWaitSec`) is also 1800s, so a cap of 30 or more times the job out when the session gives
    up. At **25** the shard goes red and `ship-pr`, still listening, reads a failed required check. The
    others: `lint` 10, the summary 5, every short runner 10, the two agent jobs 60 (the model's runtime).
  - **The consumer half is invisible from here**: every runner this workflow scaffolds
    (`adopt-ci-floor.ps1`'s four, `adopt-workflow-folder.ps1`'s two, `adopt-shopify-floor.ps1`'s theme
    check) carries a cap, because a wedge blocks a *consumer's* required check unwatched. The skeleton
    `ci.yml` is the loosest at 30 and says in its own comment that it is the number to re-size.
    [`scripts/tests/workflow-timeouts.tests.ps1`](../../../scripts/tests/workflow-timeouts.tests.ps1)
    holds the properties, including the `suites`-versus-`$maxRequiredWaitSec` inequality, derived from
    both files rather than hard-coded.
  - **Decided in:** #1941, #2233, #2255, #2263, #2296. The run-history figures are in this file's history.

- **`scripts/lint/check-git-identity.ps1`** — the split-identity check (issue
  [#1315](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1315)): does this checkout commit as
  the same account it acts as on the tracker? The claim rule's `@me` resolves through the GitHub API, so
  it writes whichever account `gh` holds, and nothing compared that against `git config user.name`. Where
  they differ, the cross-device tell in
  [Derek's lens](specialist-05-05-lens.md#branch--repo-hygiene) fires **by construction**. Before changing
  it, know:
  - **ONE caller, deliberately no CI half, in no gate and never will be**: the finding is a fact about the
    *machine*, and a runner authenticates and commits as a bot, a mismatch by design.
    `git-identity-sessioncheck.ps1` (workflow plugin) at session start, before a claim, is the whole
    delivery.
  - **It compares *names*, not emails**: `gh api user` returns a null email without a public one and
    `user/emails` needs the `user` scope, which this family's tokens do not carry. `gh auth status` reads
    the active account from the keyring with no network.
  - **It fires only when `user.name` is a valid GitHub username by GitHub's own rule** (39 characters,
    single hyphens, none at either end). `user.name` is free text, so an unconditional comparison would
    fire forever in every consumer that spells a person's name; that is the shape of the stale-path check
    [declined further down this page](#how-the-gate-checks-got-their-shape-and-the-measurements-behind-them-august-15-2026).
  - **`git-identity-gate.tests.ps1` walks both edges** of that rule and passes both identities in
    explicitly: a suite reading the machine's own would assert something different per checkout.
  - **Decided in:** #1315. The measured case is in this file's history.
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
  where does each one's folder sit*, read from `.claude-plugin/marketplace.json`. A script must not
  encode the layout itself: that is a fact about one layout, and this tree has moved twice
  ([how](#how-the-plugin-tree-got-its-current-address)). Dependency-free on purpose: one caller runs at
  SessionStart (`check-connectors.ps1`, via `connector-sessioncheck`) and another is the fold. Mirrored,
  because `release-lib.ps1` dot-sources it.
- **`scripts/lib/branch-info.ps1`** — the prefix→label→changelog-type table (shared with the
  release scripts). Deliberately no `release` prefix: a release does not go via a branch/PR but
  directly on `main`.
- **`scripts/lib/pr-issues-lib.ps1`** — the pure decision table of the **resolves gate**: which issues
  a text mentions, which a body actually *closes*, and whether a PR may open without declaring either.
  Deliberately pure (no `git`, no `gh`, no filesystem) so [Tycho #18](specialist-04-18-lens.md) can assert
  every branch of it offline; the one impure part — asking GitHub which issues are open — stays in
  `open-pr.ps1`. Shared/mirrored, since `open-pr.ps1` dot-sources it. The rule it enforces and the
  incident behind it are [Derek #05](specialist-05-05-lens.md#opening-a-pull-request)'s.
  **Two PowerShell traps cost real debugging in this lib**, both pinned by asserts:
  - **`powershell -File` cannot bind an `[int[]]`.** `-Resolves 332,340` arrives as `'332,340'` and is
    cast to the single number **332340**, with no error. Hence a `[string]` parameter parsed by
    `ConvertTo-IssueNumberList`, and the fixture passes it over that same `-File` hop.
  - **`@(… | ConvertFrom-Json)` does not flatten a JSON array in PowerShell 5.1**: `@()` collects one
    element that IS the array, and `$_.number` then hands `[int]` an `Object[]` that throws. Assign first,
    then wrap: `$parsed = … | ConvertFrom-Json; @(@($parsed) | …)`. The throw was swallowed by a `catch`
    that degrades the gate to "cannot check", so the gate silently never blocked **while every pure unit
    test stayed green**: a pure decision table proves the decision, never that it is reached.

    **It is a class, not this lib's incident** — it also fired in the open-issues block of the since-removed
    `session-status.ps1` ([#957](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/957)). Grep for
    `@(` immediately followed by a command piping into `ConvertFrom-Json` before adding another. Two
    properties of it: **at exactly ONE record the broken form is correct** (member enumeration over a
    one-element array yields the element), so it shows only at 2+ and a test needs three records; and
    **`.Count` is `1` whether the array holds zero items or thirty**, so an `if ($x.Count -eq 0)` guard
    behind it is unreachable. Test *both* the populated and the empty branch.
- **Two lessons that outlived `session-status.ps1`** (removed with `/lock` and `/handover` in #957):
  - **A `2>$null` on a native command makes its `catch` unreachable, so check `$LASTEXITCODE` instead.**
    An unauthenticated or offline `gh` throws nothing and prints nothing, so the block reported `none`:
    *"we could not ask"* printed as *"there are none"*. Keep the redirect, read the exit code explicitly,
    and keep the `catch` only for a payload that arrives and does not parse.
  - **No `return` inside a reporter's section blocks.** They sit at **script scope**, where `return` exits
    the whole script, silently dropping every block below it while still exiting `0`; the degrade path is
    an `else`.
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
  `github` source `DKJ-Solutions/dkj-claude-plugins`) and `enabledPlugins`, which plugins this repo loads
  ([which, and why](#the-plugins-enabled-here-and-what-that-costs)).
- **The manifests** `.claude-plugin/marketplace.json` and every `<plugin>/.claude-plugin/plugin.json`
  (structure + `version`) — their *structure/config*; the descriptive *texts* he coordinates with
  [Tessa #16](specialist-06-16-lens.md).

#### And therefore: here Sylvester is the author who runs `simplify`

The **`simplify`** skill applies quality fixes (reuse, simplification, efficiency), and applying is the
**author's** act, never the reviewer's: [Victor #19](specialist-06-19-lens.md) may report those findings
and may not apply them, which is why the portable layer gives the skill to
[Cody #13](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-04-13-manual.md). Here
the code is `scripts/**` and **those are Sylvester's**, so he runs the tidy pass over what he changed
before the diff goes to review, and never over somebody else's change.

The line is in his lens, not only in Chris's routing table, because Sylvester does not read Chris's lens.
It is not in his *portable* playbook because his shipped scope is the harness; `scripts/**` is an
extension this lens gives him, and the agent def would claim script authorship in consumers that never
granted it.

### The sibling check, and the one axis this repo's checks never looked along (September 11, 2026, #1869)

Every other check in `connectors/` runs **source → consumer** (`check-consumer-drift.ps1` against agent-def
copies, `check-connectors.ps1` against a consumer's register record).
[`check-consumer-siblings.ps1`](../../../scripts/sync/check-consumer-siblings.ps1) is the one that runs
**consumer → consumer**: *"shipped centrally"* and *"used centrally"* are different facts, and a session
inside one consumer cannot see the sibling repo it never opens, whose names have drifted apart. Before
changing it, know:

- **The grouping is declared (`siblingGroup`), never inferred.** Every consumer shares `dkj-policy`, so a
  plugin-set inference would group a personal-life repo with a Shopify store. The reasoning is in
  [the register's page](../../../connectors/README.md#the-manifest-format); case 4 of
  [`sibling-divergence.tests.ps1`](../../../scripts/tests/sibling-divergence.tests.ps1) holds it, and it
  is the assert a later "just group by plugin set" change would delete first.
- **The exclusions are the difference between a report and a wall.** Lenses, `SPECIALISTS.md`, the seam,
  `.claude/memory/` and the GitHub boilerplate are repo-specific **by design**. **The test suites are
  deliberately kept in**: excluding them is the plausible next move, and they are also mechanism.
- **One read route per group, always.** A blob sha (the `gh` route) and a content hash (the disk route)
  are not comparable, so a group that cannot be read one way is reported unreadable rather than compared;
  a mixed vocabulary would report every path as drifted.
- **It reports and never prevents** (Dave's call on #1869): `-FailOnFinding` exists and nothing passes it.
  Which plugin should own a shared mechanism is an ownership decision, not a repair a script can make.
- **`Test-GitHubOwnerNameSlug` lives in `check-report-lib.ps1`**, not `check-connectors.ps1`: a semantic
  decision gets one source (#309).
- **Decided in:** [#1869](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1869), #309,
  [#815](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/815). The 48-path measurement is in
  this file's history.

#### The ruling that followed, and the first thing moved under it (September 11, 2026, #1881)

**Anything the two stores share goes to `bwj-development`, unless it is obviously universal** (Dave, on
[#1881](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1881)). The portable statement, the
price it accepts and the second question a store has to ask before building anything are in
[that plugin's own README](../../../plugins/dkj-policy/bwj-development/README.md#what-this-plugin-owns),
because they are read in a store repo rather than here. What belongs in this lens is the part that is
this repo's:

- **The line "policy, never mechanism" was widened**, not broken: the distinction that survives in
  `bwj-development` is copy-vs-dot-source (a consumer **copies** `templates/`, **dot-sources** a lib), not
  prose-vs-code.
- **The first increment is [`scripts/tests/test-lib.ps1`](../../../plugins/dkj-policy/bwj-development/scripts/tests/test-lib.ps1)**,
  the superset of the two stores' diverged copies, in English.
- **It has a suite here though nothing here uses it**:
  [`bwj-test-lib.tests.ps1`](../../../scripts/tests/bwj-test-lib.tests.ps1), because a mechanism with no
  owner watching it drifts again, this time inside the plugin where no consumer-to-consumer check can see
  it. It holds the superset, the behaviour of the two false-green mechanisms (`ConvertTo-CapturedText`,
  `Add-SuiteFault`), and the language.
- **The suite runs the lib in a CHILD PROCESS, and that is load-bearing.** The lib sets
  `$script:Pass`/`$script:Fail` and defines `Assert-True` in the scope of whoever dot-sources it, so
  dot-sourcing it into a suite would replace that suite's own counters and `Assert-True` with the ones
  under test, and a broken lib could report itself green.
- **The ruling does not cover an adoption gap**: `dkj-subagents-shopify` already ships
  `push-preview.ps1`, `sync-main.ps1`, `preview-theme.ps1` and `sync-rules.ps1`, and no check reports a
  consumer carrying its own copy (`check-consumer-drift.ps1` compares agent defs and personas only).
  Filed as [#1885](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1885); the other convergence
  candidates are [#1886](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1886).

### Repo-specific rules

**One rule per line, with the issue or PR that measured it — the narrative lives there, not here**
([#3208](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3208)). The generic PowerShell
traps that already ship are in
[the portable manual's trap list](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-05-15-manual.md#fourteen-powershell-traps-that-produce-well-formed-wrong-output)
and are only pointed at below.

#### Editing files

- **Never round-trip a Markdown file through PowerShell to edit it — use `Edit`.** In 5.1
  `Get-Content -Raw` reads with the ANSI codepage, so every em dash and emoji comes back as mojibake
  (127 sequences in one write, August 15, 2026);
  [`fix-mojibake.ps1`](../../../scripts/maintenance/fix-mojibake.ps1) repairs it, and the diff proves
  nothing else moved. Where a script genuinely must write, use `[System.IO.File]::WriteAllText` with
  `New-Object System.Text.UTF8Encoding($false)`. The backtick half is in the manual's trap list.
- **Undo a temporary change to a tracked file with `git checkout -- <path>`, never by writing the
  captured content back with `Set-Content -Encoding utf8`**, which in 5.1 adds a BOM and leaves a diff.
- **After `claude plugin install`/`uninstall --scope project`, run `git checkout -- .claude/settings.json`
  and read `git status` before staging** — the CLI's settings writer strips the blank lines that group
  `permissions.allow` ([#1774](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1774)). The rule,
  and why it has no gate, is in
  [the manual's hard rules](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-05-15-manual.md#sylvesters-hard-rules);
  it bites here often because this repo administers its own plugins.
- **Run `claude plugin marketplace remove` from a throwaway directory**, never from a repo whose
  `.claude/settings.json` you want to keep: it empties that directory's `enabledPlugins` and
  `extraKnownMarketplaces` ([PR #256](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/256)). Its
  machine-wide reach over install records is in the manual's hard rules.

#### PowerShell in `scripts/**`

- **Capture a native command's output in full, read `$LASTEXITCODE`, then filter.** `& git … |
  Select-Object -First N` tears the pipeline down and kills the child, so the exit code is
  timing-dependent (#94–#96) and the run can stop silently half-done; `-Last N` drains and is safe. When
  setup runs before a measurement, check its exit code and abort rather than measure past it.
- **Wrap a native call whose stderr is normal chatter in `$ErrorActionPreference = 'Continue'` and judge
  `$LASTEXITCODE`** — `git push`/`fetch`, `git add`'s CRLF warning, `gh` notices. Under `Stop`, 5.1
  makes that stderr terminating even on exit 0 (`open-pr.ps1`'s push; `cut-release.ps1` at v1.12.0).
  Query commands (`git rev-parse`, `git status`) stay under `Stop`.
- **Never name a local after a `$script:` variable a dot-sourced lib owns** — the trap is in the manual;
  here, prove a seam with a test that sets a *non-default* value, since the default passes either way
  (#178).
- **Dot-source a consumer's `branch-info.ps1` or `repo-config.ps1` in a child scope with
  `Set-StrictMode -Off`** (`& { Set-StrictMode -Off; . $lib; Get-Command … }`). Both libs are written for
  no strict mode, and loading them under it turns an older consumer's loose top-level code into a false
  `[ERROR]` at every session start (#148, #149).
- **Wrap at the call site — `$r = @(Get-Thing …)` — whenever you index or slice.** `return @($x)` of one
  item unrolls to a scalar, so `$r[0]` is its first character and the `.Count` guard still passes.
- **Verify a `Write-Host` script as a child process** (`& powershell -File …`, `Invoke-Ps` in
  `connectors.tests.ps1`), the way the hook consumes it — in-process, `Write-Host` never enters the
  pipeline and a negative assert passes vacuously.
- **Run a suite from the tree it judges** — `Push-Location <worktree>` or `git -C`, because
  `git rev-parse --show-toplevel` answers for the process's directory, not the script's. With the rule
  above: confirm the vantage point before believing either a green or a red.
- **Mask fenced code blocks before pairing inline backticks — reuse `Get-FenceMaskedText`** in
  [`check-plugin-integrity.ps1`](../../../scripts/lint/check-plugin-integrity.ps1), and judge one
  command's own arguments, not the whole span.

#### Checks and gates

- **Key a check's evidence on a position only real use produces, never on the string merely appearing in
  the file** — a docstring, a path, a link or quoted prose contains it too (MENTION vs USE: #227, #235,
  the `specialists-teardown` near-delete of a filled `repo-config.ps1`, the `01-01` import path that
  passed as a roster row). For a script that deletes, resolve every doubt toward keeping.
- **A gate scans where text is *authored*, not only where it ends up** — root changelog entry files were
  outside the scan set and failed only at fold, on `main` (#234).
- **A scaffold with no placeholder is invisible to a placeholder test** — when a generator gains such a
  mode, check every consumer that classifies its output by placeholder.
- **A check's finding wording is a consumed interface** — `sync-roster.ps1` parses
  `check-roster-sync.ps1`'s lines (#204). Grep for parsers before rewording, and read a red
  `sync-roster.tests.ps1` on a wording change as the coupling reporting itself.
- **A finding that is real but not broken gets a non-counting marker** — a bracketed token via
  `Write-Host`, matched by the hook outside `$signals`, with its own verdict line: `[ORPHANS]` (#204),
  `[UNREGISTERED]` (#208), `[INVENTORY]` (#220), `[BOOTSTRAP]` (#225), `[RECORD-SHAPE]` (#314). Anything
  that could indicate tampering stays an `[ERROR]`.
- **A rule that depends on somebody remembering a follow-up step needs something that reports the
  omission**, not a sharper sentence (#220).
- **Compute a repo-wide verdict after the loop that gathers its evidence, not where it is cheapest**
  (#225), and add the guard case in the same commit.
- **Verify a diagnosability fix against the real register, not a fixture** (#203).
- **The lint gate may never become quieter than the risks** — Sylvester extends it as the repo grows,
  with [Tycho #18](specialist-04-18-lens.md) building the tests.

#### The suite pool

- **The test gate is bound by its slowest single file, so a file that is the cost is split into files
  with their own fixtures** (#512, #714) — the convention is in
  [Tycho #18](specialist-04-18-lens.md#the-lint-gate-suite-is-more-than-one-file-august-16-2026-split-again-september-22-2026).
- **Before adding a suite, re-check what the parallel gate rests on**: no suite writes into the repo
  tree, and no two share a fixture path.
- **Do not hand-roll a second parallel runner, and re-run a red suite alone before believing its
  assert** — suites that scan the live tree collide in a pool, and `Invoke-TestSuiteGate` itself has
  produced unreproducible reds (#1033; the load numbers are in
  [Nolan #25](specialist-06-25-lens.md#a-gate-verdict-that-moves-is-a-load-reading--n5-and-the-caller-is-not-a-variable-august-28-2026)).
  `-MaxParallel 1` is the valve.
- **A count is either dated or live**: a dated one stays as measured, or is removed when it carries no
  argument; a live one tracks the tree. Establish which noun a number governs before a find-and-replace.

#### Plugins and the marketplace

- **The agent-def frontmatter and the `plugin.json` `version` land here first** — agent-def config is
  Sylvester's, the text Tessa's.
- **`Get-SharedScriptPairs` spans two plugins and reads the plugin off `MirrorRel`; `SkillRel` is
  derived, never stored.** A duplicate registration (`check-report-lib`: one source, two mirrors) needs a
  distinct `Name`, and no mirror dot-sources a lib from the other plugin — `shared-scripts.tests.ps1`
  asserts it.
- **Renaming or moving this checkout unlinks its own install.** A deliberate `check-roster-sync.ps1` run
  prints `[NOT-INSTALLED-HERE]` (the hook cannot — it did not load); repair with
  `claude plugin marketplace update dkj-claude-plugins`, then
  `claude plugin install <plugin>@dkj-claude-plugins --scope project` from the new root.
- **A session loads the extracted payload; only an absolute `@`-import reads the clone** — the account
  is in [Updating the plugins](#updating-the-plugins--in-every-other-checkout-of-this-repo) (#845,
  #1812). Between two releases no command hands a session new plugin content, because `plugin update`
  and `plugin install` both decide on the version string; comparing commits instead of versions is declined because a consumer's clone is meant to
  follow releases (Dave, August 24, 2026). Three consequences:
  - A file **renamed** on `main` kills a consumer's absolute `@`-import on their next refresh, with no
    release in between (#2128).
  - A dead `@`-import is **silent**: the rest loads, nothing is reported, and the raw `@path` stays in
    context as inert text — check 28 exists for it.
  - The payload is **marked, never reaped** — `.orphaned_at`, and `uninstall` leaves it too (#339);
    [lane 12 of `tidy-machine.ps1`](../../../scripts/maintenance/tidy-machine.ps1) reports it and
    deletes nothing (#1659).

#### In the session

- **A refusal reading "auto mode cannot determine the safety" is retried, not routed around through
  another tool** — it is transient, and the detour turns a refusal into a bypass.
- **Before writing "this was never recorded", grep `CHANGELOG.md` and `dkj-policy/releases/**` too** —
  an entry is where a finding lands first.
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

**Three of the seven are enabled: the core team, `dkj-policy` and `dkj-solutions`.** `dkj-solutions` came
in on October 13, 2026 (Maikel, [#2976](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2976))
for its dev-preview hook, which is `dkj-policy`'s since
[#3198](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3198); it stays for the house style,
its session check and the hub's DKJ-Solutions card. The hook starts the connector dashboard
(`scripts/dashboard/serve-connector-dashboard.ps1`) through this repo's `Get-DevPreview`, and the general
pages server beside it
([#3119](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3119)). The root `CLAUDE.md` imports
the extension, as the constitution requires of an installed one. The three add-on teams are `false` since
September 30, 2026, and the BWJ extension (then `dkj-policy-bwj`) since October 1 (both Dave); from
September 8 all six had been on, for validation. Before changing this, know:

- **`false`, not absent, and that is load-bearing**: the harness and every check read the settings chain
  user file → `.claude/settings.json` → `settings.local.json`, the last layer naming a plugin wins
  (`Get-EnabledPlugins`, `scripts/lib/check-report-lib.ps1`), and a machine's own `~/.claude/settings.json`
  can enable any of them if the key is deleted.
- **`figma@claude-plugins-official` is `false` here too** (Dave, October 1, 2026) under the same rule: the
  machine's user file enables it, and it would load 14 skill descriptions (2,150 tokens) into every session
  with no frontend to work on. The key is not redundant: removing it as redundant switched figma back on
  everywhere until it was restored
  ([#2978](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2978)).
- **What switching a plugin off removes**: its blocks in
  [`connectors/dkj-claude-plugins.json`](../../../connectors/dkj-claude-plugins.json) (`connectors.tests.ps1`'s
  self-manifest case fails on a registered plugin that is not enabled), the add-on teams' 11 empty lenses
  and roster rows (else an `[ORPHANS]` line at every session start), and the root `CLAUDE.md`'s import of
  the BWJ extension.
- **Only the core team, `dkj-policy` and `dkj-solutions` describe this repo**; the add-on teams have no
  work here (not a webshop, a Shopify store or a personal-life repo). `bwj-development`'s ticket-handling
  chapter admits this repo as a permitted target (Dave, September 14, 2026; per-chapter reach closed
  [#1982](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1982)), and that stays in the plugin
  source, but this repo does not use it: an issue here is filed with a plain `gh issue create`, carrying
  `prio-N` and, where it applies, `minor` ([Chris's lens](specialist-01-01-lens.md)).
  `adopt-bwj-development` was never run here. To use the chapter again, set the plugin to `true`, restore
  the import and the connector block, and run `adopt-bwj-development`.
- **What is given up is the early warning.** The add-on teams were on so that a broken agent def,
  manifest, frontmatter or hook surfaced at this repo's own session start; it cost every session ~2.9k
  tokens for three teams with no work here. A broken add-on plugin now surfaces in a consumer that runs
  it, or in this repo's own gates, which read the plugin trees directly. To validate one again, set it to
  `true`, run `sync-roster` for its rows and lenses, and re-add its block to the connector record.
- **A re-enable should not read two known costs as breakage.** Every specialist an enabled plugin ships
  needs a roster row and a lens (eleven kept empty on purpose). And `dkj-subagents-shopify`'s floor check
  asks which theme is live: **this repo declares `Get-ShopifyRepoHasNoStore` in
  [`scripts/repo-config.ps1`](../../../scripts/repo-config.ps1) because it has no store**, which the check
  honours since [#1570](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1570)
  ([#1579](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1579)). **Never silence it by seeding
  a theme id**: the declaration says there is no store, an id says there is one and names it, and would arm
  a guard over a theme nobody verified.

### Repo citation — the two renames behind the one owner name

Moved here from `.claude/rules/this-repo.md` under
[#2448](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2448); the rule keeps the canon
itself — cite this repo as `DKJ-Solutions/dkj-claude-plugins` — and this is the history and the
machinery behind it.

**Two renames sit behind that one line, and they retired different halves of it**, which is why both old
spellings still appear in the tree and why neither may ever be recreated:

- **The owner**, September 2, 2026: transferred from the personal account `DaveKJohn` into the
  `DKJ-Solutions` organisation; `DaveKJohn/…` resolves only through a redirect.
- **The name**, September 10, 2026: `claude-code-specialists` became `dkj-claude-plugins`
  ([#1769](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1769)); the old
  `DKJ-Solutions/claude-code-specialists` resolves only through a redirect too.

Both are **transfer redirects this repo does not control**, and each holds only while nothing is created
at its old path (the canonical-channel note in [`README.md`](../../../plugins/ADOPTION.md#consumption)). The machine
layer states the current answer once, in `scripts/repo-config.ps1`. Before changing anything here, know:

- **The retired NAME is data the tooling reads.** Three of this workflow's CI runners are scaffolded into
  a consumer and check this repository out by name, so a consumer scaffolded before September 10 still
  names the old slug and the guard over it would see nothing. `Get-RetiredRepoNames` in
  [`scripts/repo-config.ps1`](../../../scripts/repo-config.ps1) states the retired names and
  `check-connectors.ps1` matches them alongside the current one. **The list only grows.**
- **Existing citations are corrected when a file is edited for other reasons, not swept**
  ([#1526](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1526)): both spellings resolve, and a
  sweep is a diff nobody can review. The archived release history under `dkj-policy/releases/**` stays as
  written, the carve-out [`language-layers.md`](../../rules/language-layers.md) makes too.
- **Every place the name is read rather than displayed must be current**: `Get-RepoName`, the
  `repository:` line the consumer scaffolders write, the matcher that finds it, and the marketplace source
  in `.claude/settings.json`. The test is whether something RESOLVES the name or merely prints it: a
  citation may lag, a lookup may not.
- **A checkout's own `origin` remote is this citation where no gate can see it** (per-checkout git config).
  One cloned before the transfer pushes only because GitHub answers `remote: This repository moved`
  ([#1562](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1562)). The one command repairs
  every state, because it writes the whole URL:
  `git remote set-url origin https://github.com/DKJ-Solutions/dkj-claude-plugins.git`.

### How the plugin tree got its current address

Moved here from `.claude/rules/this-repo.md` under
[#2448](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2448); the current layout itself is in
[`README.md`](#repo-layout).

Since August 3, 2026 the plugins sit **one** level down in `plugins/<plugin>/` instead of two in
`claude-code-plugins/claude-specialists/<plugin>/`; the
[one-product rule](specialist-06-16-lens.md#one-product-one-repository) retired the second level. `connectors/`
moved **to the root** in the same movement, deliberately: it is the consumer register read by
`scripts/sync/`, not plugin payload, and must not travel in the plugin cache. The shared-block source
stayed **inside** `plugins/` because it *is* plugin source, and was moved twice: to
`plugins/dkj-teams/agent-shared/` (August 17, 2026), then to its current home
`plugins/dkj-subagents/subagent-shared/` under
[#1698](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1698). **No tooling had to learn an
address**: every script that asks which plugins exist reads `marketplace.json` through
[`plugin-tree-lib.ps1`](../../../scripts/lib/plugin-tree-lib.ps1). The workflow folder `dkj-policy/` was
`contributing-davekjohn/` until September 5, 2026 (#1437).

### Why `Get-RosterIgnoredIds` is empty

Behind *"Adopting a specialist that arrives with a plugin update is the default and needs no
approval"* in [`SPECIALISTS.md`](../SPECIALISTS.md#the-team-roster--routing).

`Get-RosterIgnoredIds` is **empty**, and it is reserved for a deliberate, self-authored exception. It once
held the specialists who rarely have work here, but it turned out never to have been a decision: it was
pre-populated to keep the new roster check quiet and cited a `CLAUDE.md` choice that did not exist. Dave
did not recognise the list as his (July 28, 2026), so those specialists were adopted. The shape to avoid:
a check made quiet by a list that cites a document which does not say what it is cited for.

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

This was `dkj-policy/CONTRIBUTING.md`'s DEVELOPMENT step until #2179 retired that page
([where it went](specialist-06-16-lens.md#the-two-pages-the-workflow-folder-used-to-carry-and-why-they-are-gone)).
The cycle — phases, step marks, what DEPLOY is for — is in
[`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md); only this repo's own
answers stay here.

#### The document and its name

The document, its per-branch name (#1255, #1335, with the merge-conflict measurement), the `-v<N>` suffix
(inbound #1224), the re-read after `new-branch`, the HTML-comment guidance and the absence of any template are
all in [`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md#why-the-name-carries-the-branch).
This repo's own facts: **nothing identifies a document by its filename** — the fold and every gate read the
branch out of the document's own heading — and `ReservedNames` in `Get-BranchFilePaths` keeps the folder's
own pages out of the document glob. **Four `###` headings and never a fifth** (Dave, August 26, 2026) is
**refused here** by the shape gate below; in a consumer only the preamble half is. The prefix is picked by
what changes, not by which files move — [Derek's](specialist-05-05-lens.md#classifying-naming-and-creating-a-branch).

#### What does NOT go into the phases as a step

The repo's standing gates are not written as steps (#1060, August 29, 2026): the rule and its measurement
are in [`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md#the-four-phases-and-why-one-of-them-takes-no-steps).
Here the hand-run overran the 120s foreground timeout while `open-pr`'s own gate ran the same 54 suites in
59s and 60s; the mechanism is in the slowest-single-suite paragraph above.

#### DEPLOY: folder-relative links, and audience tier 2

**Links are written folder-relative to `dkj-policy/`**, because the changelog sits there: `../scripts/x.ps1`,
never `scripts/x.ps1`, which is dead once it lands, and `open-pr`'s link gate refuses it
([`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md#the-deploy-section--the-changelog-entry)).
**This repo answers audience tier 2**, so the entry is the `### DEPLOY: <branch>` section (tier 0, its answer
directly underneath) plus `#### What makes this deploy extra special`, both beside `#### Pull Request`
([the two tiers](../../../plugins/dkj-policy/DEVELOPMENT-portable.md#the-two-tiers)). **In each tier the
reason goes ABOVE the `**Score:**` line** — anything below it is discarded.

### The gates on the branch document, and the ones that fire beside them

This was `dkj-policy/CONTRIBUTING.md`'s PULL REQUEST step until #2179 retired that page
([where it went](specialist-06-16-lens.md#the-two-pages-the-workflow-folder-used-to-carry-and-why-they-are-gone)).
The cycle, the gates in run order and the escape valves (`-SkipLint`, `-SkipTests`, `-MaxParallel`) are in
[`CONTRIBUTING-portable.md`](../../../plugins/dkj-policy/CONTRIBUTING-portable.md#4-open-the-pr) and the
[`open-pr` skill](../../../plugins/dkj-policy/skills/open-pr/SKILL.md); the `-MaxParallel` measurement is in
[#1443](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1443) and this file's git history. This repo's own lint gate is
[`check-plugin-integrity.ps1`](../../../scripts/lint/check-plugin-integrity.ps1), followed by every
`scripts/tests/*.tests.ps1` ([`this-repo.md`](../../rules/this-repo.md)). Each gate below keeps only what this
repo adds or what the portable pages do not carry; all but the CI gate run locally.

#### The label gate, which reads nothing on the branch at all

Inbound [#1221](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1221), September 1, 2026. The
label comes from this repo's prefix table in
[`branch-info.ps1`](../../../scripts/lib/branch-info.ps1); the gate, its refusals and why it is not
`-Force`-able are on the
[`open-pr` skill page](../../../plugins/dkj-policy/skills/open-pr/SKILL.md#the-label-gate-does-the-label-your-seam-names-still-exist).

#### Before any gate, one thing that is not a gate: the document commit

[#1269](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1269), September 3, 2026 (PR #1267):
the mechanics, the bound and why it commits rather than refuses are on the
[`open-pr` skill page](../../../plugins/dkj-policy/skills/open-pr/SKILL.md#the-document-commit-what-the-pr-says-is-what-the-branch-carries).

#### the entry gate, on whether there is an entry at all

September 8, 2026, [#1632](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1632) (documents #1632
and #1644 shipped without a DEPLOY section). The gate (`Test-DevelopmentEntryMissing`), why it is separate
from the scaffold gate, `-Force` and the `new-branch` remedy are on the
[`open-pr` skill page](../../../plugins/dkj-policy/skills/open-pr/SKILL.md#the-entry-gate-is-there-an-entry-at-all);
the same predicate runs in CI from [`entry-scaffold-lib.ps1`](../../../scripts/lib/entry-scaffold-lib.ps1).

#### the scaffold gate, on the changelog entry itself

August 3, 2026 (measured on v3.2.0: three of twenty-one entries shipped the scaffold heading). The gate, the
invisible window and the fenced-code and `-Force` rules are on the
[`open-pr` skill page](../../../plugins/dkj-policy/skills/open-pr/SKILL.md#the-scaffold-gate-has-the-entry-actually-been-written).
The wording lives in **one** shared source,
[`entry-scaffold-lib.ps1`](../../../scripts/lib/entry-scaffold-lib.ps1), read by the script that writes it and
the gate that refuses it. **Two of the three strings are now recognised without being written** (August 6,
2026): the entry is no longer scaffolded with a to-do heading, but every branch in flight, here and in every
consumer, may still carry one, so the gate keeps refusing the retired wording. **Recognise both, write one.**

#### the step-list gate, on the branch's own plan

Dave, August 6, 2026; at the merge the gate reads `refs/heads/<branch>` and not the checkout, #970,
August 27, 2026. The gate, the three marks, the scaffold-placeholder case and the no-step-list case are on the
[`open-pr` skill page](../../../plugins/dkj-policy/skills/open-pr/SKILL.md#the-step-list-gate-is-the-branchs-own-plan-finished)
and in [`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md#rules); why the merge
reads the branch's commit, and why refusing once `HEAD` moved was declined, is on the
[`ship-pr` skill page](../../../plugins/dkj-policy/skills/ship-pr/SKILL.md#the-two-merge-gates-read-the-branchs-commit-and-why-they-used-to-read-the-tree).
One thing neither states: **the path is resolved against that same commit** — `Resolve-BranchFilePath`
chooses between candidate names by reading each, and resolving against the checkout would fail silently (a
name the branch does not carry reads as *no document at all*).

#### the backing gate, on whether anything is behind the plan

**Dave, issue [#1026](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1026),
August 28, 2026.** The step-list gate asks whether the plan is *finished*; **none of the paperwork gates
reads the diff**. So `open-pr.ps1` refuses a plan reading as finished with **nothing committed on the branch
besides this document**. The `open-pr` skill names this gate but has no section for it
([page](../../../plugins/dkj-policy/skills/open-pr/SKILL.md)); the park-commit `Backing:` note it shares a
function with is in
[`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md#the-park-commit-says-what-is-behind-the-plan--read-it-before-you-rebuild-anything).

- **Measured on PR #1025:** it merged an entry describing two new rules in a manual whose edit was never
  committed; the whole diff was `<branch>.md`, which the fold then removes, so the merge delivered no
  content. Every gate was green.
- **One function, `Get-BranchBackingFinding`**, serves the park note
  ([#960](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/960)) and this gate, so a park that
  alarms and a gate that stays silent cannot disagree over one tree.
- **Two shapes, split by whose fault it is.** Work uncommitted **in this working copy** is this session's own
  omission, one `git commit` from repaired: **refused**. **Nothing uncommitted here** means the work is not on
  this machine, which cannot be told from a branch legitimately shipping its entry alone: **said out loud and
  allowed**, so the cross-device flow #960 serves is not wedged.
- **`-Force`-able, unlike the step-list gate**, because a branch whose whole deliverable is the changelog
  entry is rare rather than impossible; `-Force` still prints the warning.
- **The gates say when they ran against a dirty tree.** The lint gate and suites judge the working tree and
  the push ships HEAD; #1025's lint run reported zero errors on a tree the PR did not carry.
  `Get-GateFingerprint` cannot answer this (it hashes the dirty list away). A dirty tree mid-flight is
  ordinary, so it is a sentence, never a refusal.

#### the DEPLOY lock, on the section the PR published

**Dave, issue [#884](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/884), August 25, 2026.** The
lock itself — the DEPLOY section is fixed when the PR opens, `ship-pr` refuses a diverged one, an unreadable
body is not a finding — is in the
[`check-branch-entry` skill](../../../plugins/dkj-policy/skills/check-branch-entry/SKILL.md#what-it-is-for-and-why-it-ships)
(the `-Pr` paragraph); which copy of the document it reads is
[`ship-pr`'s](../../../plugins/dkj-policy/skills/ship-pr/SKILL.md#the-two-merge-gates-read-the-branchs-commit-and-why-they-used-to-read-the-tree).
What neither page carries:

- **The PR is the recorded copy, so the lock stores nothing.** Three mechanisms were weighed and Dave chose
  comparing against the open PR: a fingerprint stamped into the document would add an artefact to the file
  the fold consumes and have to be stripped again; a silent re-sync at merge time refuses nothing, so is not
  a lock.
- **It is checkable only because the section travels verbatim.** Until #884 `Get-PrDescription` dropped the
  `### DEPLOY:` heading and promoted the rest, so body and document were two renderings of one section. The
  heading travels now on today's shape only; the legacy path keeps promoting. The reasoning sits at both
  branches in `pr-body-lib.ps1`.

#### the shape gate, on the document around the entry

The gate, its `-Force`, and why it fires before the push rather than only in CI (#1650, September 8, 2026;
the measured instance was this repo's PR #1644) are on the
[`open-pr` skill page](../../../plugins/dkj-policy/skills/open-pr/SKILL.md#the-shape-gate-does-the-document-around-the-entry-still-hold-its-form);
the two rules are in
[`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md#the-four-phases-and-why-one-of-them-takes-no-steps).
Here: both rules are one function, `Get-DevelopmentShapeFindings` in `entry-scaffold-lib.ps1`, which the CI
gate below reports from too. **The heading count is this source repo's own rule**, so it runs behind
`Test-IsWorkflowSourceRepo` (the caller passes that answer in), and **four `###` headings and never a fifth**
is refused here (Dave, August 26, 2026). The preamble rule holds everywhere. `branch-entry` was deliberately
**not** made a required check: that is a ruleset change and the owner's act.

#### the CI gate, because the gates above are local

Why it exists (inbound [#789](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/789)), that it
calls the same functions `open-pr` and `ship-pr` call, and why it reports significance instead of refusing
are in the [`check-branch-entry` skill](../../../plugins/dkj-policy/skills/check-branch-entry/SKILL.md#what-it-is-for-and-why-it-ships)
and [`CONTRIBUTING-portable.md`](../../../plugins/dkj-policy/CONTRIBUTING-portable.md#4-open-the-pr). Here:
[`check-branch-entry.ps1`](../../../scripts/lint/check-branch-entry.ps1), called on every PR by
[`.github/workflows/branch-entry.yml`](../../../.github/workflows/branch-entry.yml).

- **It re-checks every gate but the backing gate, deliberately** (August 28, 2026). That gate's subject is
  what sits **uncommitted in a working copy**, and a CI runner checks out the commit, so the measurement
  there would always read zero; a check that cannot fail states a guarantee CI cannot make. The half visible
  from a commit (a diff that is the document alone) stays local too: whether a change was finished is a
  judgement for where the author can still act.
- **Reading a PR body is why the workflow carries read access to pull requests**; the entry checks need no
  token, network or PR, so the lock is opt-in by parameter.
- **Its own workflow file, not a job in `ci.yml`**: `ci.yml` also runs on a push to `main`, where there is no
  branch document, so a job there would be red on the trunk after every merge.
- **It is not in the `main` ruleset** — making a check required is the owner's repo-settings act — so it
  reports on every PR and blocks nothing.

#### the always-on budget gate, on what every session pays before any of this

**Dave, issue [#2037](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2037), September 16, 2026.**
Where every gate above judges the branch, this one judges the **always-on document path** — `CLAUDE.md` plus
everything it `@`-imports. The ratchet (growth refused over the ceiling, crossing refused at or under it),
the unit being the whole import closure, the destinations the refusal names and `-Raise -Reason` are in
[`CONTRIBUTING-portable.md`](../../../plugins/dkj-policy/CONTRIBUTING-portable.md#4-open-the-pr); the three
carriers (`open-pr` with `-Record`, `.github/workflows/always-on-budget.yml`, the `always-on-sessioncheck`
hook) are in the
[scripts README](../../../plugins/dkj-policy/scripts/README.md). What the portable pages do not carry:

- **Only `open-pr` writes the baseline.** CI and the hook never pass `-Record`: a read-only carrier that
  rewrote the ratchet's own memory would be the one thing able to raise it with nothing in any diff to say
  so. All decisions sit in `always-on-budget-lib.ps1`.
- **A CI runner has no marketplace clone**, so this repo's 30,267 B orchestrator-persona import (27.7% of its
  path, invisible to `wc -c CLAUDE.md`) does not resolve there: the same commit measured 109,385 B locally
  and 79,118 B in CI, which would have made the gate flap. The baseline therefore records every document's
  size **keyed by its import target**, and a run that cannot resolve one carries the recorded figure and says
  so. A document neither resolvable nor recorded is **unmeasured**, never counted as zero.
- **The arithmetic is in LF bytes**, not on-disk bytes: a CRLF checkout is one byte per line above what the
  repository stores (~1.4% on a 1,346-line file), enough to refuse a branch that changed nothing.
- **Like `branch-entry`, it is not in the `main` ruleset** — a required check is the owner's act, not a
  script's.

### The `dkj-policy/` folder, and this repo's answers to the portable seams

The workflow occupies one folder in the repo root (Dave, August 14, 2026); the conventions travel with the
plugin, and what follows is **this repo's own set of answers** to them. The folder's `README.md` and
`CONTRIBUTING.md` are retired
([#2179](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2179),
[#2196](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2196); [where they went](specialist-06-16-lens.md#the-two-pages-the-workflow-folder-used-to-carry-and-why-they-are-gone)).

#### What the folder holds

| here | what it holds | portable half |
|---|---|---|
| [`CHANGELOG.md`](../../../dkj-policy/CHANGELOG.md) | what is pending for the next release: one `##` entry per merged branch, folded in at the merge and emptied by a cut (`Get-ChangelogPath`) | *(the format travels in [`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md))* |
| `<branch>.md` | the branch's own document, one per branch and present only while that branch is open: its plan, and the DEPLOY section that folds into the changelog | [`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md) |
| [`releases/`](../../../dkj-policy/releases/) | the dated list of every release ever cut ([`history.md`](../../../dkj-policy/releases/history.md)), the published audience notes, and the generated changelog and GitHub-Release trees. The release seam answers are [Rendall's](specialist-05-06-lens.md#versioning--releases) | [`RELEASES-portable.md`](../../../plugins/dkj-policy/RELEASES-portable.md) |

In this repo the portable pages resolve as relative links because this is the plugin's **source**; in a
consumer they live in the plugin install instead. The folder moved in whole on August 27, 2026 (Dave): every
document the contribution cycle produces or governs now lives in it, which is also what the computed
defaults had given every consumer since #885 — **a source repo that sets a seam by hand is the shape to
watch for.**

#### The seam, answered — the whole table in one place

This is [`scripts/repo-config.ps1`](../../../scripts/repo-config.ps1) read as prose: every question the
portable half leaves open, this repo's answer, and the `Get-*` function that declares it. The release rows
are Rendall's to explain ([lens](specialist-05-06-lens.md#versioning--releases)).

| the portable half says | this repo's answer | declared in |
|---|---|---|
| your lint gate | [`scripts/lint/check-plugin-integrity.ps1`](../../../scripts/lint/check-plugin-integrity.ps1) | `Get-LintScript` |
| your branch prefixes | `feat/` · `fix/` · `docs/` — and **no `chore/`** | [`scripts/lib/branch-info.ps1`](../../../scripts/lib/branch-info.ps1) |
| the type an unknown prefix falls back to | `Chore` | `Get-EntryFallbackType` |
| your audience tier | **2** — a service, not a product | `Get-ReleaseAudienceTier` |
| your entry's section headings | the English defaults — nothing is overridden | *(no override defined)* |
| the wording inside the development document | the English defaults | `Get-BranchFileWordingOverrides` *(none)* |
| your significance rubric | the shared default, 1–5 | *(no override defined)* |
| your permanent root docs | `CHANGELOG` · `CLAUDE` · `README` · `LICENSE` · `CONTRIBUTING` · `SECURITY` · `INSTALL` · `UNINSTALL` — **`CHANGELOG` and `CONTRIBUTING` no longer sit at the root and stay on the list**: it names permanent documents, not what the root holds today, and the portable `cut-release` reads it (the comment above `$script:ReservedRootMd` in [`repo-config.ps1`](../../../scripts/repo-config.ps1) has the reasoning; `ReservedNames` in [`Get-BranchFilePaths`](../../../scripts/lib/entry-scaffold-lib.ps1) is the same rule for the `dkj-policy/` folder's own pages) | `Get-ReservedRootMd` |
| where your changelog lives | `dkj-policy/CHANGELOG.md` — the consumer default | `Get-ChangelogPath` |
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

The hosting is machinery and so is here; the release *answers* are Rendall's
([lens](specialist-05-06-lens.md#versioning--releases)). What the page is, why it is generated, and what
hosting it decides are in
[`RELEASES-portable.md`](../../../plugins/dkj-policy/RELEASES-portable.md#giving-that-note-a-reader-shaped-home--the-release-notes-page);
[`build-release-notes-page.ps1`](../../../plugins/dkj-policy/scripts/release/build-release-notes-page.ps1)
builds it. This repo's answers:

| | |
|---|---|
| `Get-ReleasePageTitle` | `Claude Specialists` — the **product's** name, not the repository's; it is the masthead eyebrow and half the window title (the heading is the template's own *Release notes*) |
| `Get-ReleasePageWorkerName` | `''` — hosted nowhere (below) |
| where the output lands | `dkj-policy/releases/page/`, derived from `Get-ReleaseNoteRoot` rather than configured |
| where it is read | the dkj-policy general pages server serves it at `http://localhost:<port>/release-notes` (a port from 4890 to 4899; the Repo hub the session start prints links it from its General card, and the repo's own server redirects `/release-notes` there), which opens in VS Code's Simple Browser |
| what is committed | **nothing from that directory.** The page is a derivative of the tracked documents, and a 400 KB file changing every release would dirty the tree `cut-release.ps1` refuses to run on |

**Only BWJ-Development hosts its release notes on Cloudflare** (Maikel, October 17, 2026,
[#3083](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3083)): a DKJ repo's notes are read by
the owners on their own machine, so this repo answers the worker seam with `''` and `cut-release` prints no
redeploy step. The `ccs-release-notes` worker (August 15 – October 17, 2026) and its local path token are
history: [#2868](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2868), #3083,
[#3086](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3086).

#### Where the rest lives

- The document a branch works in, its four phases and the three step marks:
  [`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md). **This repo keeps no
  local half of it** (Dave, August 23, 2026): a portable formatter cannot generate repo-specific prose into
  every branch's document, so the file rules are in the development section above and the seam answers in
  the table above.
- **The lint gate holds the document's shape here, which a consumer's repo cannot** (the plugin ships no
  `scripts/lint/`). Three checks in
  [`check-plugin-integrity.ps1`](../../../scripts/lint/check-plugin-integrity.ps1): no document declaring
  the trunk survives a fold anywhere in the tree; the entry-shape claims in prose are held against the
  section count the scaffolder writes; and the heading-level rules are enforced against the DEPLOY section,
  read out of the document with its line offset.
- The cycle as a portable page, with the seams named:
  [`CONTRIBUTING-portable.md`](../../../plugins/dkj-policy/CONTRIBUTING-portable.md)
  (why the split exists: [inbound #566](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/566)).

In short: the **how** (managing the harness, scripts, config, safety guards) is portable; the **what**
(the plugin lint + drift lint, `branch-info.ps1`, `.claude/settings.json` with the github source, and
the marketplace/plugin manifests) belongs to this repo.
