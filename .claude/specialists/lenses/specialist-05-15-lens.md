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
  [#1669](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1669): a dispatched subagent
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
  [#1467](https://github.com/DaveKJohn/claude-code-specialists/issues/1467) only `*-policy` /
  `*-policy-*` still carry a directory rule on the workflow side — `plugins/dkj-policy/`, the government,
  with the prime ministry at its root and each ministry a level inside it; `workflow-*`,
  `contributing-*` and `*-codex` are accepted by name and held to no location. It used to have teeth because the core team's `workflow-sessioncheck`
  hook decided what counted as a workflow by that prefix alone — that hook was retired with
  `workflow-default` under [#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886), so the
  borrowed justification is gone. **What replaced it is internal to the check and stronger for it:** the
  directory half is *derived* from the name, so a plugin matching neither prefix falls through both
  branches and has its location held against nothing at all. An unprefixed name does not read untidily —
  it switches the check off for itself, silently.
- **`.github/workflows/ci.yml`** — the CI gate on GitHub: runs the same lint gate + all test suites
  (`scripts/tests/*.tests.ps1`) on every PR and every push to `main`, so the guard also applies to
  work that comes about outside `open-pr.ps1`.

  **AND "THE SAME GATE" IS NOT "THE SAME ANSWER", BECAUSE THE TWO RUN ON DIFFERENT TREES**
  (measured September 9, 2026, on this lens's own branch). The local gate runs on **your branch**; CI
  runs on the **merge** of your branch with the trunk. The suite list is a glob, so a suite the trunk
  gained while your branch was open **does not exist locally** — the local gate cannot run it, reports
  green, and CI then runs it against your change and fails. Measured exactly here: `feat/1726-…` passed
  all 86 suites locally twice, and `lint-en-tests` went red on
  `command-probe-lib.tests.ps1` — a rule (#1729, *no `Get-Command` function probe*) that landed on `main`
  hours earlier and that the new script broke three times over. After `git merge origin/main` the same
  command reported **87** suites, and the count is the only thing that said anything was different.

  **Read the count, then: a local gate pass is evidence about your branch and NOT a prediction about CI.**
  This is not what ship-pr's staleness guard is for — that dates a CI certificate against commits the
  trunk gained *after* the run (#1292), and it fires at the merge, which is well after the red run has
  already happened. The cheap habit is the fix: `git fetch` and merge the trunk **before** the gates, so
  the tree you prove is the tree CI will build. **"The same" is literal since August 7, 2026** — the step
  dot-sources `native-capture-lib.ps1` and calls `Invoke-TestSuiteGate`, the one function `open-pr.ps1`
  and `cut-release.ps1` also call. It held its own inline `foreach` until then, which is how a gate
  improvement can land in both local callers and miss the only one that actually blocks a merge; the
  asserts that keep it from coming back are in `cut-release-guardrail.tests.ps1`. It passes
  `-MaxParallel ([Environment]::ProcessorCount)` deliberately: the lib's default holds two cores back so a
  developer's machine stays usable, and on a four-core runner nobody is sitting at, that reservation would
  cost half the box.

  **AND SINCE [#1443](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1443) CI is no longer
  the only caller that can choose** (September 5, 2026). `open-pr.ps1` and `ship-pr.ps1` take the same
  `-MaxParallel` and hand it down through `Invoke-WorkflowGates`, which had been the missing hop: the
  parameter existed at the bottom of the chain and at the top of CI's, and nowhere in between. Measured on
  this machine — 18 cores, so 16 lanes — the default passed once at 716s and was then **killed twice by
  the harness for running out of memory**, where `-MaxParallel 4` passed in 888s. The reservation formula
  reasons about cores; what ran out was memory. **The default is unchanged**, deliberately: one machine is
  not a measurement of the formula, and what #1443 was actually about is that the only way past a gate
  that would not finish was `-SkipTests` — a skip and a smaller run leaving the same trace afterwards.
  The consumer-facing half is in the `open-pr` skill page, which is where a session reads it.

  **EVERY PUSH TO `main` IS ITS OWN CONCURRENCY GROUP, and before
  [#1294](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1294) half of them were never
  gated at all.** The block used to key one group on `github.ref`, i.e. one group for the whole trunk,
  and leaned on `cancel-in-progress: ${{ github.event_name == 'pull_request' }}` to keep the fold commit
  from cancelling the merge commit's run. It did not, and could not — the portable half of why is a hard
  rule in [Sylvester's manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-05-15-manual.md#sylvesters-hard-rules):
  the field governs the *in-progress* run, while a group also drops a **pending** one when a third
  arrives. **What made it bite here is this repo's own trunk rhythm**, which is the repo-specific half:
  `ship-pr` pushes twice per branch 6s apart, a run takes ~15 minutes, and `windows-latest` queues for
  seconds — so the merge commit's run had not started when the fold displaced it. Measured
  September 3, 2026 over the last 28 `merge:` commits: **14 `success`, 14 `cancelled`**, the cancelled
  ones with zero jobs allocated. And it was never only folds displacing merges — `0ab47d2d`, `2c54de74`
  and `e0175372` went down in one chain, so on a busy day only the **last push of each ~15-minute
  window** ran. The tip was always gated; nothing between it and the previous tip was, which is why that
  day's two `failure` runs on `main` named no commit. The repair keys pushes on `github.sha` and leaves
  the PR half exactly as #932 measured it. **It costs runner minutes on purpose** — 27 runs where 13 ran
  — and whether the *fold* commit needs a full run of its own is deliberately left open
  ([#1300](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1300)).

  Since July 15, 2026, the repo ruleset
  **`main-ci-gate`** (renamed from `main-ci-poort` by Dave on July 26, 2026; found at GitHub →
  Settings → Rules) enforces that gate as a **required status check**: a PR to `main` only merges
  on a green `lint-en-tests` job. The bypass list is what keeps the direct fold/release commits on
  `main` possible, and it is not a convenience: a required status check **cannot** be satisfied by a
  direct push, because the check has to be green before the push is accepted and a push is what would
  trigger it. Until September 2, 2026 it held *Repository admin + the Write role, "Always allow"*. The
  Write entry was there because the work account `davekokbwj` **then** held write rights and not admin —
  that pairing is what identified the role at all (the August 14 reading further down this bullet) — and
  the caveat attached to it was that a Write bypass is safe only while there are no external
  collaborators.

  **BOTH HALVES OF THAT SENTENCE ARE NOW DATED, AND THE ROLE TABLE IS THE PART TO READ**
  ([#1284](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1284)). Measured
  September 3, 2026, after the move into the `DKJ-Solutions` org:

  ```
  $ gh api orgs/DKJ-Solutions/memberships/<user> --jq .role   -> DaveKJohn, davekokbwj, maikel-bwj: all admin
  $ gh api repos/DKJ-Solutions/claude-code-specialists/collaborators?affiliation=outside   -> empty
  $ gh api repos/DKJ-Solutions/claude-code-specialists/rulesets/19008062
      bypass_actors  [ {OrganizationAdmin, always}, {RepositoryRole 5, always} ]
  ```

  All three accounts are **org owners**, which is why each also reads `role_name: admin` on this repo, and
  the restored list carries **no Write role**. Two consequences, the first being the one a reader takes
  from the old sentence and gets wrong: **a direct push that succeeds from `davekokbwj` proves the admin
  bypass works and says nothing about the Write role.** That is precisely the mis-attribution the #1244
  thread had to retract, and this lens is the document that retraction cites as its pre-transfer baseline.
  The second: the external-collaborator caveat no longer guards what it was written to guard, because the
  bypass now rests on **org ownership** rather than a repo role — a wider grant, since an org owner
  bypasses on every repo in the org, and one that nothing on this repo's settings page shows.

  **AND THE RULE LIST GAINED A FOURTH ENTRY ON SEPTEMBER 6, 2026 — `merge_queue`, which refuses a direct
  push on its own** ([#1499](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1499)). The
  bypass list is unchanged; what changed is how many rules a non-bypassed actor has to get past. Measured
  the same way, on the same ruleset id:

  ```
  $ gh api repos/DKJ-Solutions/claude-code-specialists/rulesets/19008062 --jq '[.rules[].type]'
      ["deletion","non_fast_forward","required_status_checks","merge_queue"]
  ```

  **Why this is worth a row rather than a silent update to the list above.** Every record in this lens
  names `required_status_checks` as *the* rule the direct-on-`main` exceptions have to be bypassed for,
  and that was a complete answer while it was the only one that refused a push. It is not any more: the
  `fold-on-merge` workflow's rejected push (run 34020828593, 2026-09-06 08:04) came back naming **both**
  rules, one line each —

  ```
  remote: - Required status check "lint-en-tests" is expected.
  remote: - Changes must be made through the merge queue
  ```

  — so a reader holding the three-rule list reads the second line as an unexplained extra and starts
  hunting for a second cause. **The bypass answers both in one move**, because a bypass actor bypasses the
  ruleset rather than a rule, so nothing about the remedy changes. What changes is the diagnosis, and that
  is the half a session actually reads a red run with.

  **AND THE FOURTH ENTRY IS GONE AGAIN — THE LIST IS BACK TO THREE** (measured September 9, 2026,
  [#1720](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1720)). The same command on the
  same ruleset id:

  ```
  $ gh api repos/DKJ-Solutions/claude-code-specialists/rulesets/19008062 --jq '[.rules[].type]'
      ["deletion","non_fast_forward","required_status_checks"]
  ```

  So the three-rule list above is the live one again, `required_status_checks` is once more the only rule
  a direct push has to be bypassed for, and a rejected push reports **one** line rather than two. The
  September 6 block stays exactly where it is: it is what a reader needs the day a run from that window is
  being read back, and deleting it would leave run 34020828593's two-line refusal unexplained. **Read this
  pair as the shape of the whole section** — each block is what was true on its date, and the newest one is
  the answer to "what does the ruleset hold *now*".

  **AND THE ONE THING TO CHECK BEFORE TRUSTING ANY OF THEM: a ruleset is GitHub-side state, so nothing in
  this tree changes when it changes.** No commit records it, no gate reads it, and no session is told. That
  is why every block here carries the command rather than only its output — the record is a dated
  measurement, not a fact the repo maintains, and the way to know which block is current is to run the
  command again. The removal above has no date of its own for exactly that reason — September 9 is when it
  was *measured*, not when it happened, and nobody can now say which. That gap is why the always-on
  sentence in [`this-repo.md`](../../rules/this-repo.md#claude-code-specialistss-safety-implementation) went on
  handing out the wrong answer for a stretch nobody can now put a length on (#1720).

  **EVERY SENTENCE ABOVE STILL HOLDS, AND SINCE SEPTEMBER 9, 2026 SOMETHING ACTS ON IT**
  ([#1726](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1726)):
  `.github/workflows/repo-settings.yml` runs `check-repo-settings.ps1` daily against
  `Get-ExpectedRepoSettings`, so a change to this ruleset now produces a dated red run within 24 hours
  instead of nothing at all. **It does not make these blocks maintained facts, and reading them as such
  is the one mis-reading to avoid** — each is still what was true on its date, and the way to know
  which is current is still to run the command. What the detector adds is narrower and is the half that
  was missing: it says *when* a block stopped being current, which is precisely what the `merge_queue`
  removal above has no answer for. Its own bullet is further down, under
  [what Sylvester owns here](#what-sylvester-owns-here); the three-rule list above is one of the seven
  facts it now compares, so a fourth entry appearing is reported rather than discovered.

  **AND THE BYPASS THAT ANSWERS BOTH CANNOT BE GRANTED TO THE ACTOR THAT NEEDS IT** (September 6, 2026,
  [#1506](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1506)). The paragraph above is
  right that a bypass actor bypasses the *ruleset* rather than a rule, so one grant would answer both
  refusals. What it leaves open — and what `fold-on-merge.yml`'s own header then recorded as a plan — is
  *which* actor. The workflow pushes with the default `GITHUB_TOKEN`, i.e. as the GitHub Actions app
  (`integration_id` 15368, the id `lint-en-tests` already reports under, confirmed against
  `gh api apps/github-actions`). Adding it:

  ```
  PUT repos/DKJ-Solutions/claude-code-specialists/rulesets/19008062
  422 Validation Failed
  Actor GitHub Actions integration must be part of the ruleset source or owner organization
  ```

  An `Integration` bypass actor has to be an app **installed on the org**, and GitHub Actions is not an
  installable app — `gh api orgs/DKJ-Solutions/installations` lists exactly one, `claude` (app_id
  1236702). So that route does not exist, and the plan was never a measurement. **Bypass is by actor, and
  both bypassing actors are people** (`OrganizationAdmin`, `RepositoryRole 5`), so the only way a workflow
  pushes to this trunk is with a token belonging to one of them. That is what
  [#1507](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1507) landed, the same day and
  from a second session: `actions/checkout` authenticates with `FOLD_PUSH_TOKEN`, an org owner's
  fine-grained PAT, and the fold's `git push` reuses that credential.

  **Read the split it makes, because it is the part worth copying.** Only the PUSH gets the standing
  token. The fold step still reads with the job-scoped `GITHUB_TOKEN`, which expires in about an hour and
  is useless outside its own run, and the workflow's `permissions:` are down to `contents: read` because
  the default token is no longer the pusher. The checkout is pinned to a commit SHA rather than a tag for
  the same reason: the step that handles a 366-day standing write token is the one where a retagged
  action would be worth someone's while. None of that was tested when it landed; the asserts are in
  `merge-queue-prereq.tests.ps1`, added by #1506, and each one covers a property that fails silently.

  **The generalisation worth keeping, because it will come up again:** a workflow that must write past a
  ruleset cannot be granted the exception itself. Either it borrows a person's token, or the rule stops
  applying to the branch it writes to. There is no third door, and reaching for one costs a round trip
  through a 422 every time.

  **Inferred, not measured: why the roles changed** — an elevation, or the transfer's own member mapping.
  `orgs/DKJ-Solutions/audit-log` needs `admin:org` and answers 404 from a session, so the cause is not
  readable here. The roles themselves are, and nothing above depends on the cause.

  **THAT LIST WAS EMPTY FOR ONE DAY, AND THE TRANSFER WAS WHY** (September 2–3, 2026,
  [#1244](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1244)). Moving the repo into
  the `DKJ-Solutions` org carried the ruleset across **intact** — active, `~DEFAULT_BRANCH`,
  `deletion` + `non_fast_forward` + `required_status_checks` on `lint-en-tests` — and dropped only its
  bypass list: `bypass_actors: null`, `current_user_can_bypass: never`, which meant nobody could push to
  `main` directly, `DaveKJohn` as repo admin included. All three direct-on-`main` exceptions were dead
  until Dave restored it on September 3 at Settings → Rules → `main-ci-gate` → Bypass list.

  **The paragraph is kept rather than deleted, because the failure is a property of the ruleset and not
  of that one move.** The bypass list is the only thing standing between a green `main-ci-gate` and three
  exceptions that cannot satisfy it, and nothing in GitHub's UI says so — a transfer, an org policy, or
  somebody tidying the list all produce the identical symptom. What identifies it is the push's own
  answer: `GH013 ... Required status check "lint-en-tests" is expected` when the list is empty,
  `Bypassed rule violations for refs/heads/main` when it is not. Read that line rather than the ruleset
  page; it is the one measurement that distinguishes the two states without admin rights.

  **It does not stop at the three exceptions — it blocks MERGES too, by a chain reaction**, and that is
  the part worth reading before anybody concludes the damage is bounded. A PR still merges; its fold
  cannot push; so the merged branch's development document **stays on `origin/main`**. The trunk then
  carries a live branch document that should have been deleted, and while the fold stays blocked they
  accumulate.

  **The second half of this chain reaction is fixed as of September 3, 2026, and the sentence that used
  to be here is dated rather than swept.** It read: *"That path is fixed by design — the design's safety
  argument being that the fold removes it at the merge — so ... every open branch has its own file at that
  same path, and every subsequent PR conflicts on it."* That was true, and it was the shared-path design's
  defect rather than this ruleset's: the conflict happened on **every** merge, blocked fold or not, and a
  conflicting PR gets no check suite at all, so it could never go green and never merge
  ([#1255](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1255)). The document is named
  per branch now, so two branches never write the same path and a leftover on the trunk collides with
  nobody. **What this ruleset still costs is the leftover itself** — an unfolded entry sitting on `main`
  with nothing saying so — which was the half #1244 owned and the per-branch rename did not repair.

  **That half is no longer silent as of September 3, 2026**
  ([#1270](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1270)). `check-unfolded-entry.ps1`
  reports a written per-branch document on the trunk whose declared branch is not the
  one under HEAD — the invariant being that the fold removes it at the merge, so on `main` there should be
  none. It runs from two places, because neither reaches the whole population on its own: a CI workflow
  (`.github/workflows/unfolded-entry.yml`, `push` to `main`, **not** in `main-ci-gate` — the same
  Dave's-call reasoning as `branch-entry.yml`, and a required check cannot gate a push anyway) catches it
  regardless of who merged or how, and a SessionStart hook (`unfolded-entry-sessioncheck.ps1`, workflow
  plugin) tells the next specialists session at start rather than leaving it to Chris's manual
  `verify-stand-against-repo` check. Neither calls `gh`: a written entry on the trunk is folded or it is a
  defect, whatever the branch's PR state, and the fold is local. The one false positive it can raise is the
  ship window — `ship-pr` pushes the merge commit and then, seconds later, the fold commit — which **this
  workflow's own** `cancel-in-progress: true` swallows and a session reads as a finding that resolves
  itself. Read *this* workflow's, not `ci.yml`'s: since
  [#1294](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1294) `ci.yml` keys every push to
  the trunk on its own commit, so it swallows nothing. The
  detector is `Get-UnfoldedTrunkEntry` in `entry-scaffold-lib.ps1`, one definition for both callers.

  **#1244 IS OPEN AGAIN, AND WHAT REOPENED IT IS THE MIS-READING DIRECTLY ABOVE** — so the cost is still
  being paid, and the response to it is the part to get right. It *was* closed on September 3, 2026 on the
  strength of a fold commit that pushed cleanly; that commit carried `davekokbwj` as author because that is
  the git identity on the machine it was made on, while the **pusher** was `DaveKJohn` (admin). A commit's
  author does not name its pusher and
  `gh api "repos/DKJ-Solutions/claude-code-specialists/activity?ref=refs/heads/main"` does — read that
  before concluding anything about which role got past the gate. The mechanism half therefore runs on as
  [#1278](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1278). Both leftovers #1244
  stranded (#1253 and #1261) *did* fold unchanged the moment the list came back, and that half is
  untouched by the reopening — it is the evidence for the rule: a blocked fold is **waited out, not
  committed locally**.

  **What settles #1278 is a reading no admin session can take** — `current_user_can_bypass` on the ruleset,
  from the account that will actually push. It reads `always` from this one because it is an org owner, and
  that says nothing about any other account. Measured September 3, 2026, all three accounts are now org
  owners and the list bypasses `OrganizationAdmin`, so on the face of it the gap #1278 reports is closed;
  **that is an inference from the role table, not the measurement**, and the account itself has to confirm
  it. Committing it makes a `main` commit that exists on one machine, and `main` is what every
  other machine syncs — measured September 3, 2026, where a held fold met the same fold landing from
  elsewhere and produced a duplicate entry and an unmerged `CHANGELOG.md` with no `MERGE_HEAD` to abort.
  The trunk leftover is visible and cheap; the duplicate commit is neither. Rendall's lens carries the
  fold-side statement of this. `check-unfolded-entry.ps1` above is what makes "visible" literal.

  **The hazard that made it urgent is worth keeping, because it is what a reader would otherwise
  rediscover.** Resolving that conflict in favour of the incoming branch **destroys an unfolded DEPLOY
  entry**, the only copy of that change's changelog text — and *keep mine* is exactly what a session hits
  this reaches for. Measured on PR #1249, where the trunk's conflicting file turned out to belong to
  PR #1250 and `deleted by us` meant *"our fold deleted a different document at the same path"*. It was
  untangled by keeping theirs, running #1250's pending fold, and letting both held folds ride out through
  the open PR. Per-branch names remove the situation rather than the hazard's teeth: there is no longer a
  resolution in which one branch's document can stand in for another's.

  **The generalisable half, beside the one below it: a setting that is present and active is not proof
  that the thing you depend on inside it survived.** [#1239](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1239)
  made *"does `main-ci-gate` still exist"* the post-transfer check, and it existed — enforcement, target,
  rules and required check all unchanged. What does not survive a transfer is the **sub-field**, and a
  ruleset reporting `active` reads as a clean bill of health while the one array the fold model runs on
  is gone. So check the field you actually rely on, not the object that contains it.

  **AND ON SEPTEMBER 3, 2026 A DIFFERENT SUB-FIELD OF THAT RULESET WAS MOVED AND MOVED BACK THE
  SAME DAY — `strict`, ON FOR ABOUT 45 MINUTES**
  ([#1325](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1325)). The stale-CI
  certificate gate in `ship-pr.ps1` step 3b
  ([PR #1316](https://github.com/DKJ-Solutions/claude-code-specialists/pull/1316)) detects a real
  race it cannot win on this trunk — `lint-en-tests` runs ~13m47s–16m09s while `main` gains a merge
  every ~15–25 min, with ~44% of branches behind at the merge — so re-running CI to refresh the
  certificate is a chase the operator keeps losing. The first verdict (~14:45 UTC) rejected every
  script-side change and turned three knobs with `gh api`: ruleset `main-ci-gate` →
  `required_status_checks` rule `strict_required_status_checks_policy` `false` → `true`, and repo
  `DKJ-Solutions/claude-code-specialists` `allow_auto_merge` + `allow_update_branch` both `false` →
  `true` (~15:10). #1325 was closed as "option 1 applied". Research on the thread (~15:29) showed
  the option is measurably worse; #1325 was reopened on Dave's instruction (~15:34) and all three
  fields reverted to `false` (~15:55). Readback confirms all three `false`.

  **Why it does not converge — the load-bearing fact.** GitHub performs **no server-side base-sync
  of a PR branch** outside a merge queue. `allow_update_branch` ("Always suggest updating pull
  request branches") only shows a UI button to a human with write access — it acts on nothing.
  Auto-merge flips the merge switch only once *every* requirement, **including "up to date"**, is
  already satisfied; it never syncs the base itself. So `strict` converts the ~44% behind-at-merge
  rate into a hard, repeating, server-side block with **no automatic resolution and no valve** —
  `-SkipStaleCheck` lives in `ship-pr.ps1` and cannot touch a refusal that is now GitHub's.
  Confirmed live in the 45-minute window: PR #1316 itself had to be landed with
  `gh pr merge --admin` while `strict` was on. Sources are cited on #1325.

  **Strict-off with auto-merge on is not a fallback**, which is why `allow_auto_merge` was reverted
  too and not only `strict`: without the "up to date" requirement, auto-merge would merge on a
  stale-but-green certificate, unattended — reintroducing exactly
  [#1292](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1292)'s defect, which
  step 3b exists to catch. #1292 (the red-trunk mechanism issue) stays open and assigned in its own
  right; the keep-`strict`-or-adopt-a-merge-queue decision is where #1325 now sits.

  **The strongest fix is a GitHub merge queue**, which tests each PR against the projected merge
  (target-branch tip + the PRs already queued), so staleness is gone by construction. It **is**
  available to this repo (public + org-owned; the earlier "Enterprise only" reading was wrong).
  `ship-pr.ps1` step 3b is unchanged: its detection is correct and it stays the mechanism and the
  portable net for consumers, whom a repo-settings change never reaches, with `-SkipStaleCheck` the
  valve for a known-harmless window. **The generalisable half: a repo-settings "fix" for the
  staleness race that is not a merge queue does not converge** — `strict` + `allow_auto_merge` +
  `allow_update_branch` look like the unattended loop, but the base never moves under the PR on its
  own, so all they add is the block.

  **THAT "the earlier reading was wrong" CORRECTION WAS RIGHT ABOUT THIS REPO AND WRONG AS A RULE, and
  the difference cost a policy** (September 7, 2026, [#1546](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1546)).
  GitHub's terms are: merge queue on a **private** repo only under Enterprise Cloud, and otherwise only
  on a **public** repo owned by an organization. This repo is public on plan `free`, so it qualifies
  through the *public* clause — the Enterprise reading was wrong **here** and is exactly right for a
  private consumer. Re-measured: `DKJ-Solutions` plan `free` + this repo `public` (eligible);
  `BWJ-Development` plan `team` + its repo `private` (the "Require merge queue" checkbox is not
  rendered at all — GitHub hides it rather than disabling it, which is why it reads as a UI mystery).
  So step 3b is not the "portable net" beneath a policy any more; **it is the policy**, and the queue is
  one option for the repos that can have one.

  **The lesson is about where a capability check is performed, not about queues.** The claim was
  verified in the one repo whose own answer could not reveal the constraint, and a capability that is
  *present* announces nothing about why. `adopt-ci-floor` then carried the generalisation outward as
  a closable `[gap]`, so a consumer built the whole floor before meeting a checkbox that does not exist
  ([#1540](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1540)). Where a finding will
  travel to a consumer, measure it on the axis the consumer differs on — here `private`/`public` and the
  org plan — before writing it down as a rule.

  **BOTH PREREQUISITES ARE NOW IN THE TREE, AND THE SWITCH IS STILL DAVE'S** (September 3, 2026,
  #1325). Enabling the queue is a repo-settings change; making the repo survive one is not, and the
  two things that had to be true first are both the same shape — **inert today, catastrophic on the
  day the queue is switched on, and silent in between**. Both are pinned by
  [`scripts/tests/merge-queue-prereq.tests.ps1`](../../../scripts/tests/merge-queue-prereq.tests.ps1),
  because nothing in this repo's behaviour today would notice either being removed:
  1. **`.github/workflows/ci.yml` now triggers on `merge_group`.** A required workflow without it
     never runs for a queue entry, so `lint-en-tests` never reports and GitHub's own warning is that
     the merge fails — a **total merge outage on `main`**, not a degradation. The suites run in full
     for a queue entry: the #1300 fold-commit shortcut is gated on the `push` event, so it does not
     reach one, and it must not — a queue entry *is* the projected merge being certified. The
     concurrency key needed no change: its `|| github.sha` arm already gives each entry its own group.
  2. **`ship-pr.ps1` reads the PR's state after `gh pr merge` instead of trusting the exit code.**
     `gh pr merge --help` states it outright — under a queue the PR is *"added to the merge queue"*,
     and gh exits **0** having enqueued. Step 5 folds onto the trunk on the strength of that exit
     code, so an ordinary ship would have written a fold commit for a PR that had not landed: the
     changelog entry on `main` ahead of its own merge, with nothing in the run saying so. **This one
     is also right with no queue anywhere** — "merged" had been an inference from an exit code, on
     the one script that writes to the trunk. A state that cannot be *read* is deliberately **not** a
     refusal (same shape as the DEPLOY lock): only a state positively read as non-`MERGED` refuses,
     because turning a network blip into a refusal between the merge and the fold would manufacture
     the trapped-entry state (#1270) the fold exists to prevent. The refusal hands the wait back
     rather than guessing a timeout — waiting a queue out is a separate decision, not taken here.

  **The generalisable half of the prerequisites, beside the one above: a settings switch that is
  somebody else's to flip does not make the code it will break somebody else's problem.** The queue
  decision sat on #1325 for a day as "Dave's", and both defects that would have fired on the first
  merge after it were in the tree the whole time, reachable and fixable without touching a setting.

  **AND THE ANSWER IS NO — THE QUEUE'S CASE WAS DISCHARGED, NOT REJECTED** (Dave, September 3, 2026,
  [#1355](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1355), the decision split out
  of #1325 so it would not be buried in a closed thread). No merge queue is switched on for `main`, and
  the three settings above stay `false`. **What settled it was the same day's CI sharding**
  ([#1351](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1351)): the stale-certificate
  event went from **31.9% at ~13 min** to **12.3% at ~5 min**, which is an expected **~37 seconds per
  merge**. The queue's throughput objection had *also* been discharged by the same change — ~4 merges/hour
  serial at 15-minute CI, against an observed trunk cadence of 2.4–4/hour, became ~12/hour — so this is a
  no on price rather than on feasibility. Against ~37 seconds a yes buys a repo-settings change, a step-3b
  rebuild that is dead code until the day of the flip, and a GitHub-side mechanism in the middle of a chain
  `ship-pr.ps1` currently owns end to end.

  **The generalisable half: an option whose case rests on a measured cost has to be re-argued the day that
  cost is measured away, and the argument does not survive on its own momentum.** The queue was the
  standing answer for a week because the number behind it was 31.9% at ~13 min. Nothing about the queue
  changed on September 3; the problem it was sized against shrank by a factor of nearly seven in expected
  cost — 31.9% × ~13 min is ~4.1 minutes per merge, against 12.3% × ~5 min for ~0.6 — and an option
  carried forward without re-reading its own premise would have been built anyway.

  **The third prerequisite is therefore recorded and deliberately NOT built** — the one #1355 exists to
  keep out of a closed thread. `ship-pr.ps1` step 3b (`:885`) refuses before `gh pr merge` (`:1268`) is
  ever reached, and nothing in `scripts/**` detects a queue: under one the staleness predicate still fires
  at its normal rate, and the refusal is then **wrong**, because enqueueing *is* the converging remedy. The
  queue subsumes the predicate while the predicate blocks the path to the queue, and the operator's only
  way through would be `-SkipStaleCheck` on every ship. It stays unbuilt on this repo's
  no-pre-emptive-fixes rule, and it is written here so a future yes inherits it rather than rediscovering
  it at the first refusal. Its shape is still open: skip 3b when a queue is detected on the base branch,
  drop the predicate here entirely (the queue is strictly stronger), or gate it on the flipped setting.

  **And two things a future flip should not learn the hard way**, both read from `gh pr merge --help` on
  the day of the decision. *"When targeting a branch that requires a merge queue, no merge strategy is
  required"* — **not required is not rejected**, so whether `$mergeMethod`'s `--merge` (`ship-pr.ps1:304`)
  is accepted against a queue-backed branch is still unestablished, and is the first thing to check on the
  first ship after a flip. And the sentence beside it — *"If required checks have not yet passed,
  auto-merge will be enabled"* — means a yes is plausibly **two** settings, because `allow_auto_merge` is
  `false` here. `ship-pr` waits for green and should land on the straight-enqueue branch instead, so this
  is the path the happy case never exercises, which is exactly why it is written down.

  **What would reopen it:** the fire rate climbing back above ~25%, or CI cost past ~10 minutes. Until
  then the queue is a priced-and-declined option, not an open question.

  **WHERE A DECISION IS ARGUED IN THAT FILE: DIRECTLY ABOVE THE KEY IT DECIDES** (September 22, 2026,
  [#2314](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2314)). `ci.yml` is ~80% comment, and
  that is the property this repo wants — a decision argued where it lives. What it had grown alongside it
  is a **shared append point**: the comment run above `jobs:` belonged to no key, so a paragraph about
  *any* job landed there, and git cannot merge two appends at one anchor. Two branches obeying the
  convention correctly therefore conflicted **pairwise, by construction**.

  **Measured, and the cost is not where it looks.** Three CI branches in one afternoon each appended to
  that banner and each inserted a key under `runs-on:` in the `suites` job — #2296 (`timeout-minutes`),
  #2303 (a job-scoped `permissions:` block) and #2304. `ship-pr` on #2300 found it at forward lap 3, as
  `PUT .../pulls/2300/update-branch -> 422 merge conflict between base and head`, after roughly forty
  minutes of CI waits across three laps. **Resolving it took about five minutes** — both sides were purely
  additive and both were kept verbatim. The conflict was cheap; finding it was not.

  **This is [#1255](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1255) one file over**, which
  is what settles that it is a shape rather than an accident: a single fixed `dkj-policy/development.md`
  made every merge to the trunk conflict every *other* open PR, the answer was one document per branch, and
  the reasoning is quoted in `CLAUDE.md` to this day. A banner is that same shared anchor wearing a
  different name.

  **The answer is per-anchor placement, chosen by Dave over two alternatives that were priced.** Every
  paragraph moves to sit above the one key, step or job it argues, so a new decision brings a **new**
  anchor rather than another paragraph on an existing block. It strengthens *argue it where it lives*
  rather than trading it away, which is why it beat the candidate the issue itself named — a one-line
  pointer per decision with the argument moved into this lens — and a third option, one file per decision
  under `.github/workflows/ci-decisions/`. Both of those buy conflict-freedom by moving the reasoning away
  from the line it explains, and that property is the whole reason the file is ~80% comment.

  **Nothing was rewritten: 301 comment lines, of which twelve changed, and every one of those twelve was a
  cross-reference that the move made false** — *"see the banner above `jobs:`"* pointing at a paragraph now
  sitting on the same key, and *"the shortcut below"* where the shortcut had become the paragraph above.
  The move was verified by diffing the sorted comment bodies before and after rather than by reading the
  diff, because a 156-line reshuffle is exactly the diff a reviewer cannot read.

  **AND THAT METHOD HAS ONE BLIND SPOT, WHICH IT FOUND THE HARD WAY.** A sorted-comment-body diff proves
  no line was **lost** and is structurally silent about a line that was **kept when it should have gone** —
  a superseded clause left standing beside its replacement is an addition on one side and nothing at all on
  the other, so it never appears in the comparison. Measured on this branch: the old *"See the banner above
  `jobs:` for why the"* survived directly above its own replacement, leaving a stuttered clause and a
  continuation pointing nowhere, and the verification reported clean. It was [Edith #17](specialist-06-17-lens.md)
  reading the diff in place who caught it — so the sorted comparison answers *"is anything missing"* and a
  human read of the new position answers *"does it still parse"*, and a relocation of this size needs both.

  **What stays above `jobs:` is what is true of the FILE** — why there are three jobs (#1351), and that
  every job declares a timeout at all (#2296). The per-job *numbers* moved to the keys they cap. The run
  went 87 lines → 32, and `ci-shard.tests.ps1` now holds it to a **40**-line ceiling: the post-change
  reading plus one paragraph of headroom, still under half of what it had reached. The ceiling is paired
  with an assert that the convention is stated in the file's own head, because a ceiling that fires without
  saying what to do instead sends the next author to raise the ceiling — the one repair that reopens the
  class.

  **The half the issue did not name, and the reason writing the convention down is part of the repair
  rather than a note beside it:** #2296 had already half-adopted the answer. It wrote a two-line pointer
  above `timeout-minutes:` in the `suites` job **and** a 31-line banner above `jobs:` — so the convention
  was not merely unstated, it was stated by example in both directions at once, and a later author copying
  whichever sat nearest had even odds of recreating the anchor.

  **What this does NOT fix, deliberately:** two branches adding different keys under one `runs-on:` still
  collide. That half is irreducible, took thirty seconds to resolve, and engineering it away would cost
  more than it saves.

- **`.github/workflows/claude.yml` + `.github/workflows/claude-code-review.yml`** — the two Claude Code
  workflows, added August 14, 2026 via
  [PR #658](https://github.com/DaveKJohn/claude-code-specialists/pull/658). The first answers an
  `@claude` mention in a comment; the second reviews every PR under the job id `claude-review`, which is
  **advisory** — the ruleset names `lint-en-tests` and nothing else. Four hardening decisions sit in
  those files and each one reads as arbitrary without its reason, so they are recorded here:
  - **Both `uses:` are pinned by commit SHA**, not by the moving `v4`/`v1` tags. This repo is a public
    plugin source: whoever can move a tag reaches every consumer through its CI.
  - **`claude.yml` runs on a read-only tool allowlist**, because upstream's configuration doc states the
    default set covers *"reading, committing, editing files"*. Without it, an `@claude` mention could
    produce a branch and a commit that passed no gate here. The three `mcp__github_ci__*` tools are named
    explicitly: the `actions: read` permission exists to enable exactly them, and an allowlist omitting
    them would switch that capability off in silence. **Do not "restore" Edit/Write/Bash to make
    `@claude fix this` work** — that it only answers is the decision, not a defect.
  - **The `issues: [opened, assigned]` trigger is deliberately absent** from the upstream template's set.
    The action's write-access gate governs who *triggers*, never who *wrote* the text a run then reads,
    and this repo publishes two inbound issue templates — external prose is a designed-for input here.
  - **The `permissions:` block is NOT the boundary, and both files say so.** `id-token: write` lets the
    action mint a GitHub App token documented as Contents/Pull Requests/Issues at read **and** write; the
    read-only scopes bound `GITHUB_TOKEN` alone. Audit either file by its scopes and you conclude the
    opposite of what is true.

  **The plugin marketplace is unpinned, and that was checked rather than skipped.** `plugin_marketplaces`
  takes *"Git URLs to install from"* and neither the action's own `action.yml` nor `docs/usage.md`
  documents a ref, tag or commit syntax — so no syntax was invented, per the
  [#566](https://github.com/DaveKJohn/claude-code-specialists/issues/566) rule about a proposal naming a
  mechanism that does not exist. The remedy if it ever matters is to drop the plugin and write the review
  prompt inline, not to guess at a `#<sha>`.

  **The App is NOT in `main-ci-gate`'s bypass list, and the method is the part worth keeping** (August
  14, 2026). The question decides whether that App token can reach the trunk past the required check, and
  the REST endpoints all refuse: `bypass_actors` is returned to admins only, and the work account
  `davekokbwj` **then held** `admin: false, maintain: false, push: true` (it holds admin today — the role
  table on the `ci.yml` bullet above). It was answered anyway, from three measurements that survive a
  redacted field.

  **All three readings below are from before the transfer and none of them reproduces today** — the list
  was emptied by the transfer and refilled on September 3 with a *different* pair, so `bypass_actors` no
  longer resolves to Repository admin + Write, `current_user_can_bypass` no longer discriminates from this
  account (it is an org owner now, so it reads `always` whatever the roles say), and `updated_at` is the
  restore's stamp rather than July 26's. The conclusion still holds — the current pair is
  `OrganizationAdmin` + a repository role, and neither is an App — and **the method is what this entry is
  for**: it is how a question about a field you cannot read gets answered instead of guessed at.
  - **GraphQL redacts the entries but not the array.** `repository.rulesets.bypassActors` came back as
    `nodes: [null, null]` — the contents are hidden from a non-admin, the **count** is not. Exactly two
    actors.
  - **`current_user_can_bypass: "always"`** on the REST ruleset, for an account that at the time held
    nothing but `push`, means the **Write role** is one of the two — it was the only thing that account
    had which could grant bypass. **The inference is only as good as the role it rests on**, which is why
    the same reading proves nothing once that account holds admin.
  - **`updated_at` dates the list.** The ruleset was last modified `2026-07-26T20:58`, and the Claude App
    arrived `2026-08-14T08:46`. A list untouched for nineteen days cannot name an actor that did not
    exist when it was written. The July 26 field-by-field re-check recorded in
    [`language-layers.md`](../../rules/language-layers.md) names both actors as *Repository admin + the
    Write role*, which matches the count of two and leaves no room for a third.

  GitHub's own documentation closes the implicit route: roles and GitHub Apps are **separate** bypass
  categories, so an App gets nothing from the Write role being listed. **The generalisable half: when an
  API hides a field, check whether a sibling representation leaks its shape (a count, a length, a
  timestamp) — three partial reads answered a question no single endpoint would.**

  **What this bounds.** The App cannot push to `main`, delete it, or force-push. It *can* create a branch
  and open a PR — which then merges only on a green `lint-en-tests`, like everyone else's. So the residual
  is the ordinary route, and the read-only allowlist above closes the other end. The knob this turned on
  was the **Write-role bypass** and its external-collaborator condition; since September 3, 2026 there is
  no Write role in the list and the bypass rests on org ownership instead, so the knob to watch is **who
  is an owner of `DKJ-Solutions`** — see the role table on the `ci.yml` bullet above.

  **A RED `claude-review` HAS ALWAYS NAMED ITS OWN REASON, AND NOBODY WAS READING IT** — issue
  [#1103](https://github.com/DaveKJohn/claude-code-specialists/issues/1103), August 29, 2026. The
  **Why the review failed** step in that workflow prints `api_error_status`, writes it as a titled
  annotation and repeats it in the job summary, and has done so since
  [#966](https://github.com/DaveKJohn/claude-code-specialists/issues/966). The same class of report kept
  arriving anyway — eight threads about this check red on every PR, every one of them since #966 the same
  quota state, and #966 itself filed against a log already reading `429` and concluding that a secret
  needed rotating. #1103 was filed with *"the actual cause: not measured"*, pointing at the marketplace
  step, which is where the run happened to be when the error surfaced and not where it came from.

  **The diagnosis was reachable and the reader was not, so the repair moved the sentence rather than
  writing another one.** `ship-pr.ps1` now reads the failing check's annotations on the path where the
  merge PROCEEDS and prints what that workflow said about itself, beside the warning naming the check
  (`Get-FailedCheckRunRefs` + `Get-AuthoredFailureNote`, `scripts/lib/pr-issues-lib.ps1`). The selection
  rule is **a failure annotation carrying a title**: the Actions runner writes its own with an empty one
  (*"Process completed with exit code 1"*), while `::error title=X::Y` is a sentence an author left for
  exactly this reader — so it needs no maintenance and works in a consumer repo whose workflows this repo
  has never seen, where a rule keyed on the name `claude-review` would report nothing at all. Only the
  **not-required** failures are asked about: a required one is a refusal, and its gate runs locally where
  the reader meets the reason first-hand.

  **And the check STAYS RED on a 429** — that decision is unchanged and recorded in the workflow itself. A
  green tick would hide that this PR got no review, which is exactly what #966 asked not to be silent.
  What was wrong was the legibility, not the colour.

  **AND THE RELAYED SENTENCE IS ONLY AS GOOD AS ITS AUTHOR** — issue
  [#1112](https://github.com/DaveKJohn/claude-code-specialists/issues/1112), the day after. The relay works
  and is the right shape; what was wrong was the sentence going through it. That headline told the reader the
  reason line names *"when it comes back"*, and on August 29, 2026 run `33267175141` failed at 18:02 UTC
  reading *"resets Aug 31, 7am (UTC)"* while runs `33268549172` and `33269512129` reviewed successfully at
  18:43 and 18:55 the same evening — roughly **2.5 days early**, both of them real 1–3 minute reviews rather
  than the nine-second workflow-validation skip.

  **The repair went into the workflow, not into `Get-AuthoredFailureNote`, and that is the reusable part.**
  The relay is generic on purpose: it repeats what an author wrote and cannot know which authors are reliable,
  so a caveat added there would caveat every workflow in every consuming repo — including the ones whose
  timings are exact. An over-claiming sentence is repaired where it is written. The lib now says so in the
  comment beside its 500-character bound, which had itself asserted the reset time was *"the only actionable
  word in the whole note"*.

  **The standing rule that comment block now carries**, after three corrections from measurement —
  [#974](https://github.com/DaveKJohn/claude-code-specialists/issues/974) (a tally of red runs, wrong by ~3x
  when typed), [#1055](https://github.com/DaveKJohn/claude-code-specialists/issues/1055) (session versus
  weekly window) and #1112 (the reset time): **the headline states only what the STATUS proves, and everything
  the `result` STRING says is attributed to upstream rather than asserted.** The status proves the account is
  out of quota and that a re-run adds none; it proves nothing about when the quota returns. *Why* it returned
  early was deliberately not investigated — a rolling window, a session window clearing, an account change are
  all plausible and none was measured — and the headline reports the discrepancy rather than a mechanism.

  **AND THE SENTENCE HAS TO FIT THE PIPE THAT CARRIES IT** —
  [#1116](https://github.com/DaveKJohn/claude-code-specialists/issues/1116), and it sits beside the three
  above rather than among them: they corrected what the headline CLAIMS, this one asked how much of it
  SURVIVES. Two caps bound the same string and neither owner can see the other: this workflow caps the
  reason it appends at 300, `Get-AuthoredFailureNote` caps the whole message it relays at 500, and the
  296-character headline puts the sum at 597. Because the relay cannot see where the headline stops, the
  half it drops is the **tail of the reason** — where *"resets Aug 31, 7am (UTC)"* lives.

  **Both numbers were left exactly where they were, and that is the finding.** The obvious repair —
  lower the workflow's 300 so the sum fits — was built and then withdrawn on its own arithmetic:
  `500 - 296 - 1 = 203` is what the operator's console shows **whichever end owns the cut**, so capping
  here hands that reader the same 203 characters, drops the `...` that marks the loss, and costs the
  GitHub annotation — read in the checks UI, where no 500-character bound applies — up to 97 characters
  it currently keeps. Cutting from the *front* in the relay is the only change that would give the
  console more, and it is not free either: the relay carries workflows it has never seen, and for one
  whose message is all content and no preamble the front is the part worth keeping.

  **What the coupling lacked was an owner, not a tighter number**, so `scripts/tests/pr-issues.tests.ps1`
  now pins all three figures the arithmetic rests on — the relay's 500, the workflow's 300, and every
  literal headline's length — and mutation-testing confirms each movement goes red naming the right one.
  The headline is the one most likely to move: it is prose, and #974, #1055 and #1112 each rewrote it.

  **The sampling that decided it, since #1116 explicitly asked for one before a repair.** All 54 red runs
  available on August 29, 2026, carrying 45 titled failure annotations: every one a 429, upstream's
  `result` first line **51 to 55** characters against 203 of room, longest message actually emitted
  **341**. A reason must reach 204 characters — nearly four times the longest ever seen — before a reader
  loses a word. **The same pass caught the comment defending the 500 citing run `33267175141` as a 460-character
  note when it is 400** (title 55 + separator 4 + message 341). A comment that names a run id is inviting
  that check, which is the argument for naming one.

  **The transferable half: an overlap between two bounds is not automatically a defect, and the change
  that removes the overlap is not automatically the fix.** Here it would have moved the loss from a marked
  truncation in one reader's view to an unmarked one in another's, and delivered the same text to the
  reader it was meant to help.
  **AND THE RELAY IS ONLY AS GOOD AS THE WORKFLOW HAVING SPOKEN AT ALL** — issue
  [#1245](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1245), September 2, 2026, and it is
  the first entry in this narrative about a failure the diagnostic step never *saw*. Every measurement
  above describes a run the SDK lived long enough to report on. The **Why the review failed** step is
  gated on `execution_file != ''`, so when the action dies before the SDK is reached that step is
  **skipped**, the workflow writes no titled annotation, and `Get-AuthoredFailureNote` — correctly —
  selects nothing. The operator meets a red tick with a blank reason line: the #966 silence again, in the
  one class all of the 429 work could not reach.

  **Measured rather than reasoned about.** Run `33663986438` (PR #1249): step *Run Claude Code Review*
  `failure` after 16s, step *Why the review failed* `skipped`, and the job's annotations were a Node-20
  warning plus two **untitled** failures — *"Process completed with exit code 1"* and *"Action failed with
  error: Claude Code is not installed on this repository"*. The reason was in the API the whole time, in
  the one field the relay does not read. The cause was #1245's own subject: the Claude Code GitHub App did
  not follow the transfer into `DKJ-Solutions`, so the app-token exchange returned 401.

  **The repair is the second diagnostic step, and its placement is the #1112 rule applied again.** The
  tempting change is to let the relay fall back to an untitled annotation — and it is the wrong one, for
  the reason its own asserts already state: it would relay *"Process completed with exit code 1"* in every
  consuming repo, which is the reassuring-looking note that says nothing. A workflow that wants to be heard
  writes a title. So the workflow now has the **complementary** gate, `execution_file == ''`, and
  `pr-issues.tests.ps1` pins that both halves of `failure()` exist — a class cannot fall between them
  again.

  **What that second sentence may CLAIM is the interesting constraint**, and it is the standing rule of
  that file rather than a new one. It states only what an **empty output** proves: the SDK produced no
  result, so the failure is in the setup around it and not in the diff, and no `api_error_status` exists —
  a 429 or 529 arrives *with* a result message and is therefore the other step's business. It does **not**
  name the cause, because it cannot: the cause is in the runner's untitled annotation and in the step log,
  and the step can read neither. Naming today's cause in the sentence would be #966's mistake with the sign
  flipped — an assertion the run never proved — so the app installation is cited in the job summary as *the
  measured instance*, not as the diagnosis. The asserts pin that too: the headline may not mention 429,
  529, quota or a reset.

  **And the escape went in even though every character of that headline is a literal**, which is the
  #1118 lesson taken at face value rather than re-learned. On literals `${headline//%/%25}` is a no-op —
  but #1118 was precisely the branch nobody escaped because nobody had interpolated into it *yet*, and it
  was then the only branch without the guard. So the test pins the emission-site **count** rather than a
  `-ge`: a new site raises the number deliberately, and cannot slip in unescaped.

  **The transferable half, and it is #1245's own sentence: after a transfer, verify the CAPABILITY, not
  the artefact that represents it.** The post-transfer checklist checked that the Actions secret survived,
  and it had — so the check came back clean while both workflows depending on it were dead anyway, because
  the dependency that broke was one layer further out than the check reached. Its sibling
  [#1244](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1244) is the same shape on the same
  day: `main-ci-gate` present and active while the bypass list it depended on was gone. **Both failure
  modes are silent by design** — one check is advisory, the other's absence only shows when somebody tries
  to use it — which is why *"the artefact is still there"* is the one form of verification a transfer
  defeats.

  **What is NOT in this repo's gift**, stated because the temptation is to close the loop: the app install
  is an **account-level** action on the `DKJ-Solutions` organisation, like the spend limit #1164 turned out
  to need. A session can make the failure legible and cannot make it stop. The consumer-facing half — that
  no shipped *page* states the titled-annotation contract, only the code enforcing it — is
  [#1251](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1251), deliberately not folded in
  here.

- **`.github/workflows/unfolded-entry.yml` + `scripts/lint/check-unfolded-entry.ps1`** — the
  skipped-fold gate (issue #1270). The workflow runs the check on every `push` to `main`; the check is
  mirrored into the workflow plugin and also driven by `unfolded-entry-sessioncheck.ps1`. Advisory, not
  in `main-ci-gate`. The full reasoning is in the `#1244` chain-reaction passage on the `ci.yml` bullet
  above; the detector is `Get-UnfoldedTrunkEntry` in `entry-scaffold-lib.ps1`.

  **Since [#1585](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1585) the check tells a
  SKIPPED fold from a checkout that is merely BEHIND**, and that distinction is invisible from the working
  copy alone: a stale checkout still has the document on disk and still has a `CHANGELOG.md` without the
  entry, so the detector reported a fold that `fold-on-merge.yml` had already pushed. The extra question
  costs no network — `Get-TrunkGap -NoFetch` names `refs/remotes/origin/<trunk>`, and each leftover is then
  asked whether **its branch's entry is already in `CHANGELOG.md` on that ref**, via `Test-BranchFoldedOnRef`
  in `entry-scaffold-lib.ps1`.

  **It asked the OTHER half of the fold commit until
  [#1601](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1601), and that half was
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
  `bypass_mode: always` (see the role table on the `ci.yml` bullet above), so the checkout step wires
  in `secrets.FOLD_PUSH_TOKEN` instead — a fine-grained personal access token, created by an org owner,
  scoped to **this repository only** and to **`Contents: Read and write` only** — and that identity
  clears the ruleset with no ruleset change at all.

  **It is a standing credential with an expiry, and nothing in this repo renews it.** The org caps a
  fine-grained PAT's lifetime at 366 days, so the token lapses on its own schedule whatever this repo
  does. When it does, the job keeps folding but its `git push` starts failing again — the same rejected
  shape #1499 measured, where the ruleset names both `lint-en-tests` and the merge-queue rule together,
  so read the run's own last lines rather than assume which of the two it is — and nothing else
  announces the expiry; there is no reminder ahead of it. Renewal is manual: **an org owner of
  `DKJ-Solutions`** (today DaveKJohn, davekokbwj, maikel-bwj — the same role table) **creates a new
  fine-grained PAT with the identical scope — this repository only,
  `Contents: Read and write` only — and overwrites the secret**,
  `gh secret set FOLD_PUSH_TOKEN --repo DKJ-Solutions/claude-code-specialists`. Today that renewal is
  tribal knowledge held by whoever created the token (Dave); this paragraph is what keeps it from
  staying that way if the 366 days run out while he is not the one reading a red run.
- **`.github/workflows/verify-resolved.yml` + `scripts/release/verify-pushed-merges.ps1`** — the
  resolves gate's second half surviving the same merge (issue
  [#1511](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1511), September 6, 2026), one
  step further down `ship-pr.ps1` than the fold above. `verify-resolved-issues.ps1` is that script's
  step 6 and ran only from the shipping session, right after its own `gh pr merge` returned; since
  [#1506](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1506) enqueues instead of
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
  here whose subject is **not** this tree (issue
  [#1726](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1726), September 9, 2026). Every
  other check on this page reads the repo or a machine-local record; this one reads **GitHub**, and
  compares it against `Get-ExpectedRepoSettings` in
  [`scripts/repo-config.ps1`](../../../scripts/repo-config.ps1) — seven declared facts, each carrying the
  document in this tree that states it and the date that statement was last measured.

  **The gap it closes is the one the ruleset bullet above states in prose and could not act on**:
  *"a ruleset is GitHub-side state, so nothing in this tree changes when it changes."* That sentence is
  still exactly right, and it is now the only half that was ever missing — a detector.

  **THREE DRIFTS IN EIGHT DAYS, which is why this was built rather than written down.** #1726 was filed
  arguing for doing nothing, on this repo's own no-pre-emptive-fixes rule and the words *"one occurrence
  is not a rate"* — and that premise did not survive the tree. `bypass_actors` emptied by the transfer
  (#1244): every direct-on-`main` exception dead, every fold blocked, found by a failing push a day
  later. `merge_queue` added and removed with no trace (#1499, #1720). And `allow_auto_merge` live
  `true` against four records here saying `false`
  ([#1730](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1730)) — **found by this check's
  own first run**, while that premise was being checked. Two of the three had mechanical consequences,
  not merely a session reading a wrong sentence.

  **SCHEDULED, NOT A SessionStart HOOK, and the reason is the date** (Dave's call on #1726's menu). A
  hook reaches a drift sooner and costs a `gh api` round trip at every session start. What decided it is
  the half a hook cannot do at all: a scheduled run leaves a **dated** record. #1720's own complaint is
  that the removal has no date anywhere, *"because September 9 is when it was measured, not when it
  happened"* — a hook reports to whoever happens to open a session, and if nobody does, nothing is
  written down. Daily at 06:30 UTC bounds every future answer to 24 hours; `workflow_dispatch` is how
  the answer is had on the day a setting is changed on purpose, and the one trigger that survives
  GitHub suspending a schedule after 60 days of repo inactivity.

  **NOT in `main-ci-gate`**, like `unfolded-entry.yml` and `branch-entry.yml` — the two that state that
  reasoning for themselves — and for a sharper version of it: a
  check whose subject *is* the ruleset, required *by* that ruleset, would be self-referential — and it
  would stop the trunk over a switch only the owner can flip, so a drift would block every merge instead of
  reporting one. **And it writes nothing to GitHub**, ever: repo settings are the owner's surface, the same
  rule `adopt-ci-floor.ps1` follows when it composes its required-check ruleset command and refuses to
  run it ([#1972](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1972)) — its merge-queue
  instruction stays a UI pointer instead, since that switch is scheduling policy nobody here has
  chosen. It holds `contents: read` and borrows no standing credential, which is the whole difference
  from `fold-on-merge.yml` two bullets up.

  **ONE FIELD READS AS UNREADABLE IN CI, AND THAT IS A THIRD VERDICT RATHER THAN A PASS.**
  `bypass_actors` is returned to repo administrators only, so the job-scoped `GITHUB_TOKEN` cannot see
  the one field whose emptying was #1244 — collapsing that into "matches" would make the check silent
  about the drift with the worst consequences. So it prints `[?]`, says why, and does not fail the run;
  run the script locally to compare that one. Everything else comes from
  `repos/<repo>/rules/branches/main` and the repo object, both readable with `contents: read` — and the
  branch endpoint is deliberately preferred over `rulesets/<id>` for the rest: no admin, no id to go
  stale when a ruleset is re-created, and it reports the rules **effective** on the trunk, which is what
  every document here is actually about.

  **What it costs to add a fact, and what it costs not to.** An unstated field is not checked, so
  nothing in the declaration can go stale for a fact nobody chose to declare — but the converse is that
  a load-bearing setting nobody declares stays exactly as invisible as all seven of these were before
  September 9. `scripts/tests/repo-settings-gate.tests.ps1` holds the declaration to shape rather than
  to values (68 asserts, re-counted September 22, 2026 — this figure read 46 against an actual 64,
  having been left behind by asserts added after it was written): every `Field` must be one the check
  knows how to read, and every record must carry its `Recorded`, `Where` and `Why`, because a `Field`
  typo is this check's own failure mode arriving from the inside — a declared fact silently ceasing to
  be watched.

  **AND THE ONE MOMENT IT STRUCTURALLY CANNOT COVER IS THE SESSION THAT IS ABOUT TO CAUSE THE DRIFT**
  ([#2265](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2265), September 22, 2026).
  Measured while landing #2255: `ship-pr` was waiting on `lint-en-tests` for PR #2262 with three of the
  four CI shards still queued on GitHub runners, and the session offered enabling `allow_auto_merge` as
  the way to stop waiting. It was enabled and auto-merge was armed — against the record above declaring
  it `false`, whose reason is that *with strict off, "up to date" is not a merge requirement, so
  auto-merge lands a stale-but-green certificate unattended* — with `origin/main` nine commits ahead of
  that branch at that very moment, which is that reason live rather than theoretical, and with step 3b
  blind to it because an auto-merge happens without a shipping session (#1730). Both the setting and the
  armed auto-merge were reverted in the same session; the check reads 7 of 7 `[OK]` again, re-measured
  September 22, 2026, so nothing persisted.

  **The schedule is not the defect and #1726 is not reversed.** Dave's call there was about detecting
  drift *somebody else* caused, where a dated daily record is exactly the right instrument. This is the
  other shape: the session is the one about to cause it, and at that moment these seven declared facts
  are the most relevant thing in the repo and the least visible — machine-readable, about a second
  away, and pointed at by nothing in a session. So the repair is two **pointers** and not a third
  runner; the session-side guard #1726 weighed and declined stays declined.
  - **The portable half** is a hard rule in
    [Sylvester's manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-05-15-manual.md#sylvesters-hard-rules):
    read the declaration before proposing a GitHub-side setting change, because the check's earliest
    catch is *after* the change and after whatever the change let through. It travels, because a
    consumer's GitHub-side state drifts the same way and `check-repo-settings.ps1` is theirs too
    (#1843).
  - **The local half is at the measured moment**, in `ship-pr.ps1`'s CI-wait invitation — the block that
    already answers *"this wait is long, what do I do about it"* now also answers *"not that"*: it says
    how many GitHub-side settings this repo declares, names auto-merge among them where that field is
    one of them, and points at the check. **Derived from `Get-ExpectedRepoSettings`, never asserted**,
    so a consumer who declares nothing gets no line at all — the same rule that keeps step 3 from naming
    a check (*"naming one here would be a claim about the consumer's CI that this script cannot keep"*),
    applied to a repo's settings.

  **BOTH RUNNERS ABOVE NOW HAVE A CONSUMER-SHAPED TWIN, AND NOTHING HOLDS THE TWO IN SYNC** (issue
  [#1516](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1516), September 6, 2026).
  The queue became this workflow's policy for every repo running it, and a queue reaches a consumer as
  a *policy* rather than as a release: the setting is theirs to flip, and neither runner is plugin
  payload — a plugin install writes nothing into a repo. So
  [`scripts/task/adopt-ci-floor.ps1`](../../../scripts/task/adopt-ci-floor.ps1) carries derived
  copies of both, as generated line arrays, and places them on `-Apply`. They differ from the originals
  in exactly two structural ways: they reach their scripts through a checked-out `.workflow-scripts`
  clone of the plugin tree instead of through this repo's in-repo paths, and they set
  `CLAUDE_PROJECT_DIR` so those mirrored scripts judge the consumer's tree. Everything else — the
  `FOLD_PUSH_TOKEN` checkout, the `contents: read` block, the two-outcome check step, the
  `issues: write` split — is the same decision, restated.

  **That restatement is the drift risk, and it is stated here rather than gated because no gate fits.**
  A byte comparison would be wrong (the two paths genuinely differ), and a property gate would be a
  third statement of the same rules. What holds today is
  [`scripts/tests/adopt-ci-floor.tests.ps1`](../../../scripts/tests/adopt-ci-floor.tests.ps1),
  which pins the properties that would break a consumer silently — the plugin paths, the
  `CLAUDE_PROJECT_DIR`, and the credential split in both directions. **So: change either workflow on
  this page and read that script in the same movement.** The script itself refuses to run here, which
  is right and is also why nobody editing these two files is reminded of it by the tooling.

  **FOUR CORRECTIONS LANDED TOGETHER, ALL MEASURED IN A BWJ CONSUMER ON 2026-09-07** (inbound
  [#1539](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1539),
  [#1542](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1542),
  [#1543](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1543),
  [#1544](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1544)), and all four applied
  to both this repo's own two workflows and the `adopt-ci-floor.ps1` twins:
  - **#1542 — the merge stamp is UTC.** `Format-EntryMergeStamp` rendered it with `.ToLocalTime()`,
    which was a display string until #1280 made `Get-EntryInsertOffset` derive the entry's *insert
    position* from it. A sort key cannot be local time: a repo that folds from both a UTC GitHub runner
    and a maintainer's laptop then writes stamps offset by the maintainer's UTC offset, dropping entries
    out of the chronological TIER 0 order #1280 fixed. `.ToUniversalTime()` in `entry-scaffold-lib.ps1`
    and the `FallbackNow` in `fold-changelog-entry.ps1`. Stamps written before this stay local; the
    insert walk stops at the first older stamp, so the skew is bounded to neighbours across that
    boundary until they age out at the next cut.
  - **#1543 — the fold runner checks out the trunk tip, not the event SHA.** `actions/checkout` on a
    `push` defaults to `github.sha`; in a queueless consumer `ship-pr` folds locally and pushes on top
    within seconds, so the slower runner read a tree one commit behind origin and the fold's trunk-gap
    guard (#1405) refused — a false red on every `ship-pr` merge. `ref: main` (here) / `ref: <trunk>`
    (the template) makes the job read "does the trunk carry a leftover NOW", which is the question it
    exists for. `verify-resolved` keeps the event SHA — it resolves *this push's* PRs and has no
    trunk-gap guard.
  - **#1586 — and `ref: main` did NOT make the trunk-gap guard unreachable, which is what #1543's repair
    claimed and what both workflow headers said until this was measured.** The ref is read **once**, at
    the checkout; the guard measures the same trunk again from inside the fold, about eleven seconds
    later. So a second merge landing in that gap still trips it — run `34206684361`, 2026-09-08: the
    checkout took `e8ca4cb7` (`merge: … (#1576)`) at 08:50:31, so the leftover was genuinely on the trunk
    and correctly found, and by 08:50:42 the shipping session had pushed *that branch's own fold*, leaving
    this checkout 1 behind. The guard was right, the trunk ended correct, and the job went red for a state
    that no longer existed. **The repair is the stand-down, not a fetch:** the fold's trunk-freshness
    refusal now exits **2** — the only thing in that script that does — and the job exits 0 on that code
    alone, because the push that moved the trunk queues its own run of the same job behind this one
    (that is #1544's group, above, doing load-bearing work) and the guard fires in a **pre-pass**, so
    nothing was written. **`git fetch` + `--ff-only` before the fold was the candidate and was declined**:
    it narrows the window from ~11s to ~1s without closing it, leaving the job red *rarely*, which is
    worse than predictably red and is still the fourth self-healing meaning #1539's triage exists to keep
    out. The list below therefore stays **three**: a stand-down is this job declining to answer a question
    a successor run is already queued to answer, not a way of failing.

    **AND THE SAME RACE RUN THE OTHER WAY LANDS ON `ship-pr`, WITH A CODE OF ITS OWN** (issue
    [#1792](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1792), measured here on
    2026-09-10, shipping PR #1789). With the queue retired (#1720) both runners fold on the ordinary
    path, so the loser is sometimes the **session** — and the two losses were never equally cheap: a red
    CI job is read once and closed, while `ship-pr`'s `-ne 0` ended a *correct* ship by reporting a
    failure and leaving the session's local `main` diverged 1/1, which `CLAUDE.md` reserves every obvious
    way out of (`reset --hard`, a rebase on a shared branch) to the owner. The fold's redundant-commit verdict
    now exits **3** — its second and last code of its own — and `ship-pr` reads it as a stood-down
    success, carries on through steps 5b/6, and prints in a step 5c the two commands that realign this
    checkout: a `backup/fold-<branch>` ref, then `reset --keep origin/main` (trunk checked out here) or
    `branch -f main origin/main` (nothing holds it). **`2` and `3` are not merged**, because after `2`
    nothing was written and after `3` a commit is on the local trunk — and neither script repairs it, so
    conflating them would either invent a leftover or hide one. **Both codes have one testable end each
    in `fold-changelog.tests.ps1`**: `exit 3` from exactly one place, and `ship-pr.ps1`'s own reading
    pinned as source text, because that orchestrator has no suite of its own and `-ne 0` is precisely
    what stayed the tested behaviour on the caller side through #1586.
  - **#1544 — the concurrency group is constant per trunk.** Keyed on `github.sha` it was its own group
    every run and serialised nothing, so two trunk pushes close together raced — and this job *pushes*.
    `github.ref` keeps `cancel-in-progress: false` (no *running* fold dropped) and adds queueing (no
    race). Same change to `verify-resolved.yml`. **That field never protected a *pending* run**, and
    #2813 measured the cost: a skipped fold-only push displaced a merge's pending run in both files, so
    a fold-only push now takes a per-commit group of its own (the measurement is in `fold-on-merge.yml`'s header).
  - **#1539 — the red-run triage names three causes, not two.** An absent or under-scoped
    `FOLD_PUSH_TOKEN` fails `actions/checkout` and leaves every later step `skipped`, with no fold step
    to read — the cause a consumer meets first, on adoption day, and the one to rule out first. The
    workflow headers, `adopt-dkj-policy`'s SKILL, and `adopt-ci-floor.ps1`'s own console note now say
    so; a fine-grained PAT lists repositories one by one, so a repo *created* rather than transferred
    (an org move with no GitHub transfer) falls outside an existing token's selection silently.

- **`.github/workflows/merge-on-green.yml` + `scripts/ci/pick-merge-on-green.ps1` + `scripts/lib/merge-on-green-lib.ps1`**
  — the merge that survives the *session*, where the two runners above survive the *merger*
  ([#2319](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2319), September 23, 2026).
  `ship-pr` refusing on a red required check leaves the merge owed to three things at once: a session
  still alive, a person who notices CI turned green, and a checkout standing on the branch. Measured on
  PR #2316: `gh run rerun --failed` turned every check green and nothing merged it, because the run that
  had been watching exited at step 3 — and re-running `ship-pr` then refused *again*, on a checkout its
  own step 2b (#1073) had put on the trunk.

  **IT RUNS `ship-pr.ps1`; IT DOES NOT RE-DERIVE A SINGLE GATE.** #2319 proposed a runner that merges
  "only when the required check is green on the exact head and the staleness count is zero" — and that
  second predicate is step 3b, with the step-list gate and the DEPLOY lock two more the issue's list
  leaves out. So the job checks the branch out and runs the script that holds all of them, which also
  means it folds (step 5) and verifies the resolves (step 6) exactly as a live session would. Every
  later repair to `ship-pr` reaches this runner with no edit here. The same restraint
  `ci-merge-skip-lib.ps1` shows one file over, taken one step further: that one re-asks step 3b's
  question from CI by calling the identical pure functions; this one does not ask it twice at all.

  **THE ARMING LABEL IS THE AUTHORISATION, AND `ship-pr` IS ITS ONLY WRITER.** The constitution
  `CLAUDE.md` imports holds two
  kinds of PR back for the owner's own word — a visible result, and anything irreversible or outward-facing —
  and a runner merging every green PR would merge those too. `merge-when-green` is set once the PR is
  open and before `ship-pr` starts waiting on CI (#2393; until then only when its CI verdict
  refused, which left a ship that died mid-watch or refused at step 3b unarmed), so it is a record
  that a session had *already begun shipping*, which is precisely what those two exceptions
  withhold. A PR kept back for the owner never had `ship-pr` run on it. The label creates itself on first use
  rather than needing an adoption step, because
  `gh pr edit --add-label` fails outright on a label the repo does not have and this script travels to
  every consumer.

  **THE MERGE IS MADE BY `FOLD_PUSH_TOKEN`, AND THAT IS NOT A CONVENIENCE.** A push *caused by* the
  job-scoped `GITHUB_TOKEN` starts no workflow runs — the fact `verify-resolved.yml`'s header already
  records from the other side. So a `GITHUB_TOKEN` merge would land the PR and silence `ci.yml` on the
  trunk, `fold-on-merge.yml` and `verify-resolved.yml` all three: the unobserved-merge state those two
  runners exist to close, reintroduced by the mechanism meant to help. The cost is that the secret needs
  `Pull requests: write` added to it, which is the owner's act and not a branch's; until it is made this job
  fails loudly with a 403 on the merge and can never merge without folding.

  **IT IS THE PRINCIPLED ANSWER TO THE TEMPTATION #2265 MEASURED**, and it does not reverse that
  record. `repo.allow_auto_merge` stays `false`: GitHub's own auto-merge cannot perform step 3b, so with
  `strict` off it lands a stale-but-green certificate unattended, which is #1292 exactly. What #2265
  measured was a session reaching for that switch to stop waiting. This runner gives that impulse
  somewhere legitimate to go — the wait ends without a person in it, *and* the staleness check is kept
  rather than skipped.

  **IT SHIPS WITH `-SkipLint -SkipTests`, AND OMITTING THAT PAIR WOULD BE THE EXPENSIVE MISTAKE.**
  `ship-pr`'s step 1 calls `open-pr.ps1` even for a pull request that is already open — it skips only
  the `gh pr create` and still runs the gates and the push (#457's repair, deliberately made in
  `open-pr` rather than in the orchestrator). So a runner that just ran `ship-pr.ps1` would re-run the
  whole local suite pool, ~43 minutes (#2317), inside a job whose cap is 45. Skipping it is not a gate
  bypassed: the sweep picked this pull request *because* the required check is green on its own head,
  and that check **is** this same gate, run on GitHub, on this same commit — the certificate is what the
  merge is allowed on, not the local copy.

  **A SWEEP, NOT AN EVENT-DERIVED PR.** Three triggers wake one sweep — a CI `workflow_run`, a
  30-minute schedule, `workflow_dispatch` — and none of them is read for *which* PR is owed a merge;
  `pick-merge-on-green.ps1` reads the tracker instead. The schedule is what makes it durable: #2319's own
  incident was repaired with `gh run rerun --failed`, and whether a partial re-run re-emits
  `workflow_run` is not a contract worth resting this on. The concurrency group is a **constant** with
  `cancel-in-progress: false`, which is the opposite choice from the two push-triggered runners and for a
  reason they do not have — those answer a question about one push, while two concurrent sweeps would
  race to ship the *same* PR. One PR per sweep, lowest number first; the merge is itself a push to the
  trunk, so the next sweep is already queued behind it and the backlog drains by construction.

  **`workflow_run` RUNS THE DEFAULT BRANCH'S COPY OF THIS FILE**, whatever branch the CI run was for —
  so this workflow cannot be proved on its own pull request, and its first live proof is its own first
  sweep after the merge. Read alongside `check-repo-settings.ps1`'s own `[?]` verdict above: both are
  places where the honest answer is *this cannot be checked from here*.

  **AND `workflow_run` IS THE TRIGGER THAT RUNS WITH SECRETS FOR A FORK'S PULL REQUEST**, which is its
  standard hazard and the reason this job reads **nothing** out of the event. Everything it acts on comes
  from the tracker: an open pull request carrying a label only `ship-pr` writes, whose head is a branch of
  *this* repository — `pick-merge-on-green.ps1` refuses a cross-repository one outright rather than letting
  it fail at the checkout. This repo is public, so a fork's pull request can start the job and reach none of
  its decisions. Both guards are asked because neither is load-bearing alone: today the label is out of a
  stranger's reach, and "is the head ref in this repo" does not depend on that staying true.

  **THE THIRD PRECONDITION IS REMOVED IN `ship-pr` ITSELF.** #1620 turned the on-the-trunk refusal from
  a rule into a diagnosis; it still handed a person a command the script had already worked out. Now,
  on **exactly one** candidate, a **clean** tree and a name `ref-print-lib.ps1` would already put on a
  command line, it performs the checkout and carries on. The widening is over which branch gets *read*,
  never over what may merge — a parked branch is still refused by the step-list gate a few steps down.
  **It is a test gap and named as one**: the block reads HEAD, the tracker and the working tree and
  drives `git checkout`, so there is no pure function to hand a payload to;
  `scripts/tests/merge-on-green-lib.tests.ps1` holds the three conditions structurally and asserts the
  #1620 refusal survived, which is not the same as covering the behaviour.

  **ITS CONSUMER TWIN IS `adopt-ci-floor.ps1`'s FOURTH RUNNER**
  ([#2329](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2329)). `ship-pr.ps1` is a shared
  script, so a consumer got the labelling and the sentence promising a sweep a release before it got
  the sweep — the same order `fold-on-merge.yml` landed in, built here under #1493 and derived
  afterwards. The derived copy reaches `pick-merge-on-green.ps1` and `ship-pr.ps1` out of the plugin
  checkout and runs both against the consumer's workspace via `CLAUDE_PROJECT_DIR`. **That needed one
  repair to the picker, not only a template**: it resolved its root as `$PSScriptRoot\..\..`, which in a
  consumer is the checkout of *this* tree, so its `Get-RepoName` read would have come off this repo's
  own `repo-config.ps1` and swept this repo's pull requests from a consumer's runner. It now resolves
  dual-context like every other mirrored script, and is mirrored itself. Its `workflow_run` list is read off the consumer's own pull_request workflows' top-level
  `name:`, and left out rather than guessed where none declares one.

  **AND SINCE #2437 THIS REPO'S OWN COPY SHIPS FROM A TRUSTED TRUNK, NOT FROM THE PR BRANCH.** Until
  then this runner checked `main` out once with `FOLD_PUSH_TOKEN` persisted into the workspace, then
  `git checkout <branch>` **in that same workspace** — so `ship-pr.ps1` and everything it dot-sources ran
  as the branch's own PowerShell, in a process holding a standing write credential
  ([#2338](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2338), measured: ~80% of merged
  PRs here touch `scripts/`, `.github/`, `.workflow-scripts/` or a plugin's `scripts/`, so
  `Get-MergeOnGreenExecutedPathHit` refused the sweep on almost every ship). The design (Sebastian #23's
  review, four conditions, all built before anything shipped):

  - **Two checkouts, two `.git` directories, `persist-credentials: false` on both.** `trusted-main` (the
    trunk) and `pr-branch` (the picked PR's head) share nothing but the runner's disk. `ship-pr.ps1` —
    and every sibling lib it loads via `$PSScriptRoot` — runs from `trusted-main`; `CLAUDE_PROJECT_DIR`
    points `$repoRoot` at `pr-branch`, so the merge, the step-list gate, the DEPLOY lock and the branch's
    own push still act on that tree's actual commit.
  - **`ship-pr.ps1`'s new `-TrustedRoot` parameter** (forwarded to `open-pr.ps1` as `-SeamRoot`)
    repoints the *one* thing `$PSScriptRoot` cannot supply for free: the two REPO-OWNED seams
    (`scripts/repo-config.ps1`, `scripts/lib/branch-info.ps1`) both scripts read from `$repoRoot` rather
    than from beside themselves, because a repo's own name and its own branch-prefix table are not
    portable code. **Named limitation, not silently accepted**: a PR editing either seam ships under the
    TRUNK's answer to it, not its own — a staleness cost, never a safety one, and
    `Get-MergeOnGreenExecutedPathHit` still refuses such a PR to the sweep for exactly this reason.
  - **`-TrustedRoot`/`-SeamRoot` structurally force `-SkipLint`/`-SkipTests`** rather than merely
    documenting "always pass both together with this" — `gate-lib.ps1`'s `Invoke-WorkflowGates` runs the
    lint script and every suite from `$RepoRoot` (the branch tree), which is exactly what trusted-tree
    mode exists to stop trusting, so a future edit to the workflow dropping the flag pair can no longer
    reopen the hole silently.
  - **No `git worktree add` in trusted-tree mode.** `$repoRoot` (the branch checkout) is never given a
    token, so it cannot push a fold commit either — `$TrustedRoot` already stands on `main` and carries
    the credential, so the fold step uses it directly (bringing it up to date with the same
    fetch-plus-ff-only-merge every other fold arm already runs) instead of spinning up a worktree off a
    repo that could never push it. `Remove-ShipFoldWorktree`'s new `-NotOwned` switch keeps this run from
    ever deleting a tree it did not create.
  - **The push credential is ephemeral, not persisted, and applied uniformly.** Neither checkout writes
    `FOLD_PUSH_TOKEN` into its own `.git/config`; the Ship-it step instead sets git's documented
    `GIT_CONFIG_KEY_n`/`GIT_CONFIG_VALUE_n`/`GIT_CONFIG_COUNT` environment triplet, which authenticates
    every git call the step's process tree makes — both directories, in-memory only, gone when the step
    ends. **This is a deliberate departure from Sebastian's own literal wording** ("token-bearing
    checkout only for the trusted main tree"), named in the workflow's own comment rather than silently
    substituted, because his design still leaves the raw token on `trusted-main`'s disk for the step's
    duration (his own residual-exposure #3) — one credential applied the same way to both trees removes
    that residue everywhere instead of only where his wording named. **Unproven by anything but a live
    run**: `workflow_run` runs the default branch's own copy of this file, so #2437 cannot be proved on
    its own pull request, and the two-checkout layout plus this exact credential mechanism is verified
    for the first time by this workflow's first sweep after the PR that built it merges.
  - `Get-MergeOnGreenExecutedPathHit`'s rule shrank from four path prefixes to an enumerated two-file
    list (the seams above, exact match); the merge-on-green-lib and stranded-sweep-gate suites assert
    the shrink positively (every OTHER path that used to refuse is now eligible) rather than only
    asserting what still refuses.
  - **The scaffolded consumer template (`adopt-ci-floor.ps1`'s fourth runner) got the same shape later,
    under its own issue** ([#2449](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2449)):
    a different file, every adopted consumer as blast radius, and #2333's SHA pin to reconcile with.
    Until then it checked the consumer's trunk out once with the token persisted, nested the plugin tree
    inside that workspace in `.git/info/exclude`, and switched it to the picked branch in place. That
    ran the consumer's own seams beside the token, and #2437's shrink briefly let a branch overwrite the
    trusted plugin copy (#2553). It now uses **three** sibling checkouts: the pinned `.workflow-scripts`
    plugin tree (the code), a token-free `trusted-main` (the seams via `-TrustedRoot`, and the fold) and
    a token-free `pr-branch`, with the same ephemeral credential. Sebastian's review on #2449 set three
    conditions. The runner's own header argues the one-credential trade. The test pins the literal
    `trusted-main` as the picker's `CLAUDE_PROJECT_DIR`, because pointed at the plugin tree it would
    read *this* repo's `repo-config.ps1`. And a re-run of `adopt-ci-floor` names an existing runner of
    the old shape, since the scaffolder never rewrites one. For that last reason the `.workflow-scripts/`
    refusal in `Get-MergeOnGreenExecutedPathHit` is permanent: the lib cannot see which shape a given
    consumer runs.

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
  [#1315](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1315), September 3, 2026): does
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
  corpus, read once**, merged from two scripts and two hooks by issue
  [#1421](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1421) (September 5, 2026). Both
  halves are the narrow literal greps the declined prose-contract framework recorded as the proportionate
  alternative; each keeps its own detector function, its own measurement and its own report block, and
  what merged is the plumbing around them — the process, the root resolution, the skip, the lib loads and
  the always-on walk.

  **What the merge cost a consumer: nothing, and that is why it happened now rather than later.** #1421
  deferred it on the ground that it renames a consumer-facing hook one release after introducing it.
  Checked before building, and the reason had expired: **neither hook had ever been released** — both
  landed after the `v4.29.0` tag and both sat in `CHANGELOG.md`'s `[Unreleased]` section, so
  `consumer-prose-sessioncheck` is the first name any consumer ever sees. **That check is the general
  lesson here**: a deferral's reasoning is a fact about a moment, and the moment it names is the one thing
  a standing issue cannot re-measure for itself.

  **Measured, on a consumer fixture carrying both defects, three passes each** (this machine,
  September 5, 2026): `retired-doc-name-sessioncheck` 492 / 492 / 493 ms plus
  `supremacy-declaration-sessioncheck` 498 / 494 / 503 ms = **990 ms for the pair**, against
  **541 / 527 / 530 ms** for the merged hook reporting the same two blocks — **~457 ms saved per session
  start**, in every consumer, indefinitely. That is slightly *above* the ~350-450 ms #1421 inferred from
  the component costs, which is worth recording because that issue was honest that no merged version had
  been built to measure. A bare `powershell -NoProfile` hook launch that finds no check script is
  **~155 ms** here, which fixes the shape of it: one of the two outer launches goes, one of the two nested
  spawns goes, one of the two dot-source-plus-walk passes goes. **It is not the largest item on that
  bill** — measured in the same batch as #1421, all 7 SessionStart hooks came to ~6.8 s here, of which
  `connector-sessioncheck` alone was ~4.9 s (~72%).

  **The first half — the retired-name detector** (issue
  [#1389](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1389), September 4, 2026):
  does a consumer's own always-on prose still name a *retired* name of the branch's development
  document? The first of the two narrow literal greps the declined prose-contract framework recorded
  ([below on this page](#how-the-gate-checks-got-their-shape-and-the-measurements-behind-them-august-15-2026)),
  and its whole licence is that sentence — the detector is `Get-RetiredDocNameMention` in
  `entry-scaffold-lib.ps1`, the names come from `Get-BranchFileLegacyNames`, and nothing here reads what
  a sentence *means*.

  **Three things separate it from the framework that was declined**, and all three are asserted rather
  than described. The names are **derived**, so the next rename adds this token by the same row it always
  adds and there is no second list to leave at seven names. The corpus is stated as an **inclusion**
  list — the always-on closure plus the workflow folder's own permanent pages, minus its changelog,
  because a folded entry correctly names the file of its day and a check that read it would be born red
  on its own past. And it **skips the publishing repo**, on the source-repo guard's own condition 2, for
  the reason #1380's first pass measured the hard way: this repo's pages narrate the rename history on
  purpose, so without the skip the source reads as consumer drift.

  **Its stated gap, so nobody rediscovers it as a bug.** `development-<slug>.md` (pre-#1335) is *not* a
  token: a prose page names the shape, and matching a shape needs a wildcard, which is the step toward
  fuzzy the decline rules out. `development-cycle.md` is a real literal and is covered, so the
  `development-` era is not wholly absent — but a consumer restating only the shape is missed, and that
  is what the precision costs.

  **The second half — the supremacy-declaration detector** (issue
  [#1415](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1415), September 4, 2026):
  does a consumer's own always-on prose declare *its* `CLAUDE.md` the winner over
  `dkj-policy/CONTRIBUTING.md`, inverting `LAW-THIRD-RANK-ORDER`? The **second** of the two
  narrow literal greps the declined framework recorded, and the one that entry measures every candidate
  as **structurally blind** to: a pointer test flags only sections that cite nothing, so
  cites-then-contradicts can live nowhere but among the findings it suppresses.

  **The two share their corpus, and that was true before the merge** — it is the point of
  `Get-ConsumerProseDocuments` in `entry-scaffold-lib.ps1`: which documents a consumer-prose check may
  read is one question with one answer, and each of its exclusions (the changelog, `releases/`,
  plugin-shipped payload, a per-branch document) is load-bearing for a measured reason. Two copies would
  drift on the day a third exclusion is found, and the copy that missed it would report what the other
  correctly ignores. **Sharing the corpus is what left the runtime duplication visible**: the pair had one
  definition of *which* documents and two of everything else, which is exactly the residue #1421 removed.

  **The detector is ADJACENCY, not co-occurrence, and that departs from the sentence this page
  recorded** — measured, with the numbers, [further down](#how-the-gate-checks-got-their-shape-and-the-measurements-behind-them-august-15-2026).
  Short version: the recorded three-term test scores 0 findings and 0 recall on its own target, because
  the real sentence names the contributing page by a Dutch prose noun rather than by its filename;
  requiring `CLAUDE.md` and `wins`/`wint` to sit *beside* each other scores 3 raw / 2 reported / 2 true /
  100%, and reads **direction**, which is the whole defect — *"this page wins"* is the rank order stated
  correctly and a term list cannot tell the two apart.

  **Its one suppression rests on one instance, and is written down as such** rather than presented as a
  principle: a hit wholly inside a `"…"` span is skipped, the instance being a consumer quoting the
  closing line of a page it retired. Kept because precision is 67% without it and 100% with it; the
  suite pins it from both sides, including that an unrelated quotation elsewhere on the line does *not*
  suppress a real finding.

  **ONE CALLER, no CI half, and the publishing-repo skip** — three answers that now hold for the merged
  script as a whole. Where `check-git-identity` has no CI half because a runner is a bot by design, this
  one has none because there is nothing for a CI leg to check: in the only repo whose CI this repo
  controls, the check skips. So `consumer-prose-sessioncheck.ps1` (workflow plugin) is not a convenience
  on top of another route — it *is* the route, which is the whole point of #1389 and #1415 alike.

  **The skip means something different per detector, and one script must say so rather than inherit it.**
  For the retired-name half it is a **repair** — this repo narrates the rename history on purpose and
  would read as consumer drift without it. For the supremacy half it is only a **guard**: measured at zero
  hits here on the day it was written, because every supremacy sentence this repo carries names the
  plugin's page as the winner and adjacency reads that correctly. It is kept for sibling consistency and
  because this is the repo where such sentences get written about consumers.

  **BOTH DETECTORS ALWAYS RUN — the first finding does not short-circuit the second.** A check that
  stopped at the first block would hand a session start the worse half of the two-hook arrangement (one
  defect reported, the other hidden) without the saving that motivated merging them, so
  `consumer-prose-gate.tests.ps1` pins it from three sides: a tree with only the rename produces one
  block, a tree with only the inversion produces the other, and a tree with both produces exactly two
  `[ERROR]` markers from one invocation.

  **The pre-merge per-hook figures, kept because they are what the saving is measured against** (5 runs
  each, median, this machine, September 4, 2026): `retired-doc-name-sessioncheck` **365 ms** through the
  hook in this repo where it skips, against **544 ms** for `unfolded-entry-sessioncheck` beside it;
  `supremacy-declaration-sessioncheck` **728 ms** through the hook here, its check alone **387 ms** where
  it skips and **1,484 ms** against a consumer with findings — against **1,312 ms** for the sibling on
  that same consumer in that same run, so the paragraph joining cost roughly **13%** over a detector that
  still read physical lines. That was the price of the wrapping false negative being closed, and it was
  worth it.

  **The re-measurement is itself the lesson.** The supremacy figures were first taken before review found
  the wrapping defect, and the repair makes the check do strictly more work per document — so the
  paragraph would have shipped as a current, dated fact about code that no longer existed. Caught by the
  copy edit, not by any gate: **a measurement taken before the last repair is stale, and nothing goes red
  when it is.**

  **Compare the pair, never the figure.** Every absolute on this page runs roughly double or half its
  neighbour depending on nothing but how busy the box was — which is why the #1421 before/after above was
  taken as six runs in one sitting on one fixture rather than by subtracting two dated numbers. Same load
  sensitivity [#1401](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1401)
  closed by making a duration assert compare against its queue instead of a fixed ceiling.
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
  ([#957](https://github.com/DaveKJohn/claude-code-specialists/issues/957), Dave). Its open-issues block
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
  ([#512](https://github.com/DaveKJohn/claude-code-specialists/issues/512)). **That spread is the mechanism,
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
  CORRECT** (August 16, 2026, [#714](https://github.com/DaveKJohn/claude-code-specialists/issues/714)).
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
  [#1033](https://github.com/DaveKJohn/claude-code-specialists/issues/1033) both came out of
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
  ([#845](https://github.com/DaveKJohn/claude-code-specialists/issues/845)): after four PRs merged and
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
  [#1812](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1812)). What check 11 records,
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
  which is [#1802](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1802) seen from the
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
  ([#339](https://github.com/DaveKJohn/claude-code-specialists/issues/339)). What was genuinely open
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
  cleaning up the two throwaway plugins of the [#215](https://github.com/DaveKJohn/claude-code-specialists/issues/215)
  experiment: it emptied the test consumer's `enabledPlugins` **and** `extraKnownMarketplaces`. So run it
  from a throwaway directory, never from a repo whose `.claude/settings.json` you want to keep. The full
  account, including how the damage was spotted, is in
  [PR #256](https://github.com/DaveKJohn/claude-code-specialists/pull/256)'s changelog entry.
  **And the lookup lesson that came with it:** the first version of this bullet declared the mechanism
  unrecorded and left it at an operating rule, because it went looking in the lenses and the manuals. It
  was on record all along — in that PR's entry, folded into `CHANGELOG.md` one commit earlier. Before
  writing "this was never captured", grep `CHANGELOG.md` and `releases/**` too: an entry body is where
  this repo's findings land *first*, and a lens is usually the second home, not the first.
- **And the quieter sibling of that: every `claude plugin install`/`uninstall --scope project` rewrites
  this repo's tracked `.claude/settings.json` and strips the blank lines that group
  `permissions.allow`.** Measured September 10, 2026 over nine such commands
  ([#1774](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1774)): `enabledPlugins` came
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
([#1812](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1812)): a
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
[#1805](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1805) sharpened it by naming the
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
for its dev-preview hook: this repo's `Get-DevPreview` starts the connector dashboard
(`scripts/dashboard/serve-connector-dashboard.ps1`) at session start, and the hook starts the plugin's own general pages server beside it (Artifacts, Issues, Release notes, SessionStart; [#3119](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3119)), the second port per checkout, and the root `CLAUDE.md` imports the
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
work here, and `dkj-solutions` its hook; the three add-on teams have none — this repo is not a webshop, not a Shopify store and not a
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
[#1570](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1570) gave the check a third
state to be told that in. **This repo declares `Get-ShopifyRepoHasNoStore` in
[`scripts/repo-config.ps1`](../../../scripts/repo-config.ps1) because it has no store, and the check
honours that since #1570** ([#1579](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1579))
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
  [#1769](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1769)), so
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
([#1526](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1526)). The same holds for the
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
pushes to `https://github.com/DaveKJohn/claude-code-specialists.git` and lands only because GitHub
answers `remote: This repository moved`; every push of the `v4.32.0` cut did exactly that
([#1562](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1562)). Repoint such a checkout
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
[#1698](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1698). The workflow folder
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
  ([#1321](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1321)) — a whole-file match
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
September 8, 2026 ([#1659](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1659)):
**seven** sites composed `<label>-$PID` by hand. A guid removes the target instead of checking for one —
a reparse-point check has a window, and cannot apply to the temp root at all, since on macOS `/tmp` *is*
a symlink. `native-capture.tests.ps1` enforces this over `scripts/**` outside `tests/`; the suites have
their own equally strict rule, in [Tycho's lens](specialist-04-18-lens.md#a-suites-fixture-path-carries-the-pid-and-a-fresh-guid).

#### A leftover under the temp directory is an aborted run

Measured September 8, 2026 ([#1668](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1668))
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
[#1060](https://github.com/DaveKJohn/claude-code-specialists/issues/1060), August 29, 2026). TEST carries
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
[#1041](https://github.com/DaveKJohn/claude-code-specialists/issues/1041), which moved the gate's base to the
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
[#1221](https://github.com/DaveKJohn/claude-code-specialists/issues/1221)), where two labels were deleted
org-wide because the issue **type** now carries that classification — the seam table was correct the day
before. Full mechanics on the
[`open-pr` skill page](../../../plugins/dkj-policy/skills/open-pr/SKILL.md#the-label-gate-does-the-label-your-seam-names-still-exist).

#### Before any gate, one thing that is not a gate: the document commit

**`open-pr.ps1` COMMITS the development document if it differs from `HEAD`**
([#1269](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1269), September 3, 2026).
Every gate below reads the working tree; the push ships `HEAD`; and the fold, the DEPLOY lock and the CI
check all read the committed copy. Measured on PR #1267: the run passed every gate against a filled-in
working copy, pushed the empty scaffold, published the filled-in body, and CI failed on arrival. It commits
that one file and nothing else — never `git add -A`, and anything else you had staged stays staged. Why it
commits rather than refusing, and why neither the dirty-tree warning nor the backing gate covered it, are on
the
[`open-pr` skill page](../../../plugins/dkj-policy/skills/open-pr/SKILL.md#the-document-commit-what-the-pr-says-is-what-the-branch-carries).

#### the entry gate, on whether there is an entry at all

**September 8, 2026 ([#1632](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1632)).** Before
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
[#1654](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1654) that string occurs **twice** —
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
not the checkout** (issue [#970](https://github.com/DaveKJohn/claude-code-specialists/issues/970),
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

**Dave, issue [#1026](https://github.com/DaveKJohn/claude-code-specialists/issues/1026),
August 28, 2026.** The step-list gate above asks whether the plan is *finished*. It cannot ask whether
anything was actually built, and nor can the three gates beside it: **all four read this document, and none
reads the diff**. So `open-pr.ps1` asks the second question — a plan reading as finished with **nothing
committed on the branch besides this document** does not become a PR.

**What it was measured on.** PR #1025 merged an entry describing two new rules in a manual whose edit was
never committed. The branch's whole diff was `<branch>.md`; the fold then *removes* that file, so the merge
delivered a changelog entry and no content at all. Every gate was green.

**The measurement is not new — its delivery is.** `park-cycle`'s backing note
([#960](https://github.com/DaveKJohn/claude-code-specialists/issues/960), repaired by #976) had already named
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

**Dave, issue [#884](https://github.com/DaveKJohn/claude-code-specialists/issues/884), August 25, 2026.** The
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
([#1650](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1650)). Two rules Dave enforced by
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
[#789](https://github.com/DaveKJohn/claude-code-specialists/issues/789)). The gates above live in
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
([#861](https://github.com/DaveKJohn/claude-code-specialists/issues/861)) — and all four measurable repos
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
| where it is read | the dkj-solutions general pages server serves it at `http://localhost:<port>/release-notes` (a port from 4890 to 4899; the Repo hub the session start prints links it from its General card, and the repo's own server redirects `/release-notes` there), which opens in VS Code's Simple Browser |
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
  [inbound #566](https://github.com/DaveKJohn/claude-code-specialists/issues/566), from a consumer who tried
  to adopt this repo's own page and measured why it could not be done.

In short: the **how** (managing the harness, scripts, config, safety guards) is portable; the **what**
(the plugin lint + drift lint, `branch-info.ps1`, `.claude/settings.json` with the github source, and
the marketplace/plugin manifests) belongs to this repo.
