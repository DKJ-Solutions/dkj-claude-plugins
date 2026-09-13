---
id: 15
group: 05
---

# Sylvester ⚙️ · claude-code-specialists addendum

> Repo-lens (claude-code-specialists) accompanying the portable playbook in the `dkj-subagents-alpha` plugin (`plugins/dkj-subagents/dkj-subagents-alpha/manuals/05-15-manual.md`). This file does not describe the craft, but what Sylvester does in this repo.

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
  [Derek #05](05-05-extension.md)'s `open-pr.ps1` runs before every push — and that `cut-release.ps1`
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
  rule in [Sylvester's manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/05-15-manual.md#sylvesters-hard-rules):
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
  sentence in [`CLAUDE.md`](../../../CLAUDE.md#claude-code-specialistss-safety-implementation) went on
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
    and this repo publishes an `inbound` issue template — external prose is a designed-for input here.
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
  would stop the trunk over a switch only Dave can flip, so a drift would block every merge instead of
  reporting one. **And it writes nothing to GitHub**, ever: repo settings are Dave's surface, the same
  rule `adopt-ci-floor.ps1` follows when it composes its ruleset command and refuses to run it. It
  holds `contents: read` and borrows no standing credential, which is the whole difference from
  `fold-on-merge.yml` two bullets up.

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
  to values (46 asserts): every `Field` must be one the check knows how to read, and every record must
  carry its `Recorded`, `Where` and `Why`, because a `Field` typo is this check's own failure mode
  arriving from the inside — a declared fact silently ceasing to be watched.

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
    way out of (`reset --hard`, a rebase on a shared branch) to Dave. The fold's redundant-commit verdict
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
    `github.ref` keeps `cancel-in-progress: false` (no fold dropped) and adds queueing (no race). Same
    change to `verify-resolved.yml`.
  - **#1539 — the red-run triage names three causes, not two.** An absent or under-scoped
    `FOLD_PUSH_TOKEN` fails `actions/checkout` and leaves every later step `skipped`, with no fold step
    to read — the cause a consumer meets first, on adoption day, and the one to rule out first. The
    workflow headers, `adopt-dkj-policy`'s SKILL, and `adopt-ci-floor.ps1`'s own console note now say
    so; a fine-grained PAT lists repositories one by one, so a repo *created* rather than transferred
    (an org move with no GitHub transfer) falls outside an existing token's selection silently.
- **`scripts/lint/check-git-identity.ps1`** — the split-identity check (issue
  [#1315](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1315), September 3, 2026): does
  this checkout commit as the same account it acts as on the tracker? The claim rule's `@me` resolves
  through the GitHub API, so it writes whichever account `gh` holds, and nothing compared that against
  `git config user.name`. Measured on DAVE-KOK-BWJ, where `gh` is `DaveKJohn` and `git` is `davekokbwj`:
  the documented idiom put the wrong account on #1314, and the cross-device tell in
  [Derek's lens](05-05-extension.md#branch--repo-hygiene) — a branch whose commits name a different
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
  Deliberately pure (no `git`, no `gh`, no filesystem) so [Tycho #18](04-18-extension.md) can assert
  every branch of it offline; the one impure part — asking GitHub which issues are open — stays in
  `open-pr.ps1`. Shared/mirrored, since `open-pr.ps1` dot-sources it. The rule it enforces and the
  incident behind it are [Derek #05](05-05-extension.md#opening-a-pull-request)'s.
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
  pure so [Tycho #18](04-18-extension.md) can test them in isolation. The release *process* is
  [Rendall #06](05-06-extension.md)'s domain; Sylvester guards the script mechanics underneath.
- **`scripts/agents/build-agent-defs.ps1` + `scripts/lib/subagent-shared-lib.ps1`** — the generator
  that fills the verbatim-shared bullets from
  `plugins/dkj-subagents/subagent-shared/<name>.md` into all agent defs (between
  `<!-- BEGIN/END shared:… -->` sentinels). Change a shared block →
  run `build-agent-defs.ps1` → all agent defs updated; `-Check` (and the lint gate, check 7) fails
  on drift. The pure expansion logic lives in the lib, so [Tycho #18](04-18-extension.md) can test
  it in isolation — mirroring the `release-lib` setup. **Never edit between the sentinels by hand.**
- **`.claude/settings.json`** — this repo's harness config: the `extraKnownMarketplaces` (the
  `github` source `DKJ-Solutions/claude-code-specialists`) and `enabledPlugins` with which the repo enables
  its own `dkj-subagents-alpha` plugin (the core team).
- **The manifests** `.claude-plugin/marketplace.json` and every `<plugin>/.claude-plugin/plugin.json`
  (structure + `version`) — their *structure/config*; the descriptive *texts* he coordinates with
  [Tessa #16](06-16-extension.md).

#### And therefore: here Sylvester is the author who runs `simplify`

The **`simplify`** skill applies quality fixes — reuse, simplification, efficiency — and applying is the
**author's** act, never the reviewer's: [Victor #19](06-19-extension.md) may report those same findings
and is forbidden from applying them, which is why the portable layer gives the skill to
[Cody #13](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/04-13-manual.md) rather than to a reviewer. Here
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
converging — which of `dkj-policy` and `dkj-policy-bwj` should own `test-lib.ps1`, `lint-brain.ps1` and the
market/theme mechanisms — is the follow-up, and it is an ownership decision rather than a repair a script
can make.

#### The ruling that followed, and the first thing moved under it (September 11, 2026, #1881)

**Anything the two stores share goes to `dkj-policy-bwj`, unless it is obviously universal** (Dave, on
[#1881](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1881)). The portable statement, the
price it accepts and the second question a store has to ask before building anything are in
[that plugin's own README](../../../plugins/dkj-policy/dkj-policy-bwj/README.md#what-this-plugin-owns),
because they are read in a store repo rather than here. What belongs in this lens is the part that is
this repo's:

- **The ruling widened a plugin that said it carried no mechanism.** `dkj-policy-bwj`'s README opened with
  *"policy, never mechanism"*, written when its only non-prose payload was `templates/`, which a consumer
  **copies**. A lib a consumer **dot-sources** is a second kind of payload, so the line was widened rather
  than quietly broken — the distinction that survives is copy-vs-dot-source, not prose-vs-code.
- **The first increment is [`scripts/tests/test-lib.ps1`](../../../plugins/dkj-policy/dkj-policy-bwj/scripts/tests/test-lib.ps1)**,
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
  `06-25-extension.md` in a single command. The second failure is quieter and has no lint behind it: a
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
  complex manifests), Sylvester extends the checks — with [Tycho #18](04-18-extension.md) building
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
  be done.** The convention for the four is in [Tycho #18](04-18-extension.md#the-lint-gate-suite-is-four-files-august-16-2026).
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
  numbers are in [Nolan #25](06-25-extension.md#a-gate-verdict-that-moves-is-a-load-reading--n5-and-the-caller-is-not-a-variable-august-28-2026).
  Six of those eleven scan the live tree and five do not, so the collision above explains part of it and
  nothing explains the rest. Do not read a lone red from the pool as a finding about the tree until it has
  been run alone.
- **A count in these documents is either DATED or LIVE, and the two are maintained in opposite directions.**
  The 27 above is a dated measurement and stays 27 — the 510s-vs-159s figure beside it means nothing when
  paired with any other count. The 30 in the paragraph above is live advice about what to try next, so it
  tracks the tree. Where a sentence is dated **and** the count carries none of its argument, the count is *removed*
  rather than refreshed: that is why [`CLAUDE.md`](../../../CLAUDE.md)'s *"`open-pr` runs the lint and every
  test suite"* now states no number under its August 7 stamp. It read `26` there for five days — wrong on the
  day it was written, since there were 27, and wronger every suite since. **And a bare `26` is still correct
  in two other senses**: the lint's own checks (`CHANGELOG.md`) and the agent-def count
  ([`README.md`](../../../README.md), [`subagent-shared`](../../../plugins/dkj-subagents/subagent-shared/README.md)). Establish
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
  other two ways a record goes missing, and why that leftover is not a stray duplicate are in the
  family's [INSTALL.md](../../../INSTALL.md#staying-up-to-date);
  don't restate them here.
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
  the ordinary state. What was wrong was the **expectation** — [`CLAUDE.md`](../../../CLAUDE.md) promised
  the "last pushed" version — and that sentence is what the repair changed.

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
  `dkj-policy-bwj/4.33.0` and in no other tree, and the clone held none. Two corroborations, both from
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
  [UNINSTALL.md](../../../UNINSTALL.md#what-is-left-behind-honestly) had already established that the
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
  [Sylvester's manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/05-15-manual.md#sylvesters-hard-rules);
  what is local is why it is met so often and what it costs here:
  - **This repo consumes its own marketplace and enables all six plugins**, so plugin administration is
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

### How the gate checks got their shape, and the measurements behind them (August 15, 2026)

*Moved here verbatim from [`CLAUDE.md`](../../../CLAUDE.md)'s lint-gate bullet, where it was 9,440 B
over 102 lines — 26% of the always-on document, paid by every session before a word of work. The
operative rule stayed there; this is the evidence for it, and the second half of the same split that
moved the release craft to [Rendall #06](05-06-extension.md) the day before. Nothing was reworded:
the passages below still speak in the constitution's voice, and the dates and issue numbers are the
point of keeping them.*

**The entry format is described in about ten hand-maintained places, and the answer is a check rather
than a clear-out** (Dave, August 7, 2026;
[#508](https://github.com/DaveKJohn/claude-code-specialists/issues/508)). Two of those descriptions were
measured stale during a sweep that was looking for exactly that, one of them consumer-facing. The
alternative — deleting the shape from every document and pointing at
the generated reference under `dkj-policy/branch/templates/`, a directory the merged development
cycle has since retired — was weighed and declined: the prose costs every reader on
every read, while a check costs nothing per read. **What is checked is the section COUNT, not the
section names**, and that was settled by measuring four candidate rules against the tree rather than by
argument. A name-matching rule produced **six** findings on the tree, **all six false**: `What does this
change do?` and `Type of change` are retired entry sections *and*, at the time of that measurement, were
live headings of the PR template, so it accused **two** correct documents of being stale for describing
that template accurately — and would have been born red behind an exemption list, the shape this repo was
already bitten by. The count is a fact the scaffolder owns, both recorded drifts stated it, and holding it
needs no exemptions at all.

**That collision is gone since August 9, 2026, and the conclusion does not move with it**
([#538](https://github.com/DaveKJohn/claude-code-specialists/issues/538)). Both headings were removed from
the PR template, so the six false findings can no longer be reproduced from the tree. The measurement is
kept in the past tense rather than deleted, because a superseded measurement is worth something only while
it says *when* it was taken. Two reasons the count still wins: name-matching also lost on its narrowed
variant (3 findings, 2 false, against 4 claims with 3 correct), and a rule keyed on names is one rename
away from going silent — which is exactly what just happened to this collision, and would as easily happen
to a match the check depended on.

**A check on stale PATH references in prose was measured and declined** (August 9, 2026), and the reason
generalises past this one rule, which is why it is recorded rather than forgotten. The proposal came out of
a README sweep that found a title naming `specialists/scripts/`, a directory the plugin reorganisation had
removed — a defect no gate sees, since check 4 reads markdown **links** and this was a path in inline code.
The obvious rule is "a path in backticks must resolve against the tree". Five candidates were measured over
120 documents (history excluded as in checks 11 and 12), each with the most generous resolver a checker
could honestly use — repo root, the document's own directory, and every ancestor between:
requiring a separator **and** an extension gave **124** findings, a separator alone **349**, an extension
alone **621**, either **736**. **Not one of the 124 was a true finding**, and the narrowest rule does not
even reach the measured defect — `specialists/scripts/` carries no extension — so catching the one real
instance means adopting a rule born with 349.

**The reason is structural, and it is about what this repo is.** Being a plugin source, most paths it
names correctly describe *somebody else's* repo: `.claude/extensions/…` is the legacy lens location this
family deliberately still documents for unmigrated consumers, `config/settings_data.json` is a Shopify
store's file named in `dkj-subagents-shopify`'s manual, `PRETTY/[Emotie]/README.md` is a life-hub folder. All three
answer "no such file here", exactly as the stale title does — and **the difference is whose repo the line
is about, which the line never says**. An existence check reads "describes a consumer" as "stale", and no
regex recovers that distinction. Do not revive it behind an exemption list: that is the shape this repo has
already been bitten by, and the list would need to hold the entire consumer-facing vocabulary.

**What survived, unbuilt and deliberately so:** a title claiming a path must name its own location. It
sidesteps the anchor question entirely, because a document knows where it sits — 4 subjects tree-wide,
0 findings today, and verified against `33a41a2` to fire on the real defect. Not built, because four
subjects is close to nothing to guard; worth revisiting when per-directory READMEs multiply.

**Extending check 16 to LINE COUNTS was measured and declined** (September 10, 2026,
[#1784](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1784)). It came out of
[#1779](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1779), which found seven
docstring sentences across five libs sizing `entry-scaffold-lib.ps1` at "three thousand lines" where
it measured 8,289 — and each figure sat in the sentence that carried a layer or dependency decision, so
the stale number argued for that decision at a third of its real strength. Check 16 misses the class twice over and
both misses are structural: `lines` is not in its unit list (`$figurePattern`,
[`check-plugin-integrity.ps1:2426`](../../../scripts/lint/check-plugin-integrity.ps1)), and a `.ps1`
comment is not in its `$consumerDocs` file set — that second gap is real and is where both recorded
instances of the class happened. It was filed on its own as
[#1790](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1790) — measured and declined in
its own right, write-up below.
The proposal was a check of its own: a sentence naming a repo file and giving a line count for it, held
against that file's actual length.

**THE REASON THAT SETTLES IT COMES FIRST, BECAUSE IT IS NOT THE ONE THE PROPOSAL ARGUES ABOUT: the
reported defect carries no digit.** #1779's seven sites read **"three thousand lines"**, spelled out in
words — `release-lib.ps1:706` records it in those terms (*"It read 'three thousand lines' from the day
this function moved"*). Every candidate in this family is anchored on `\d`, check 16's own
`$figurePattern` included, so **not one of them can see the defect that motivated the proposal**, however
precisely it is tuned. That is the whole argument, and the measurement below is only about the figures a
digit-anchored rule *can* see.

**It is not born green, and the shape of the failure is the point.** Measured against `main` at
`69264276`, over every tracked `.md` and `.ps1` outside the archived release history, pairing each count
with the nearest file token to its left and resolving by path then basename: **19 pairings on the wide
pattern, 16 on a narrowed one that requires a word boundary before the digit — and under a ±5% tolerance
band, every single one is a finding.** Exactly **one** is a real defect. The other fifteen fall into six
classes no regex separates from it:

| class | sites | why it is not a defect |
|---|---|---|
| a deliberate historical record | 6 | the figure **is** the past state and is the whole point — `CLAUDE.md` "328 → 282 lines", the July 28 measurement table, `cut-release.ps1` "was 284 lines" under a paragraph that says "the finding as it stood then", and `teardown.tests.ps1:469`'s "instead of 43 lines scattered through `CLAUDE.md`" (history *of* a section, which is why it counts here and not in the row below) |
| a delta, not a length | 4 | "`CLAUDE.md` +4 lines from a round trip that should have returned to zero" — the teardown round-trip assert, in three mirrored copies plus `teardown.ps1` |
| a section, not the file | 1 | "the roster/routing table (53 lines)" inside `CLAUDE.md` |
| another repo's file | 2 | `teardown.tests.ps1:574` records life-hub's `repo-config.ps1` (55 lines) and `branch-info.ps1` (88) — the same "whose repo is this line about" failure that sank the stale-path rule above |
| a **correctly bound** historical measurement | 1 | `README.md:1254`'s "101, across 492 lines" sits under *"measured against the `life-hub` consumer on July 29, 2026"* — it already does what check 16 asks, and a re-measurement check flags it anyway. This is the class that decides the remedy question below |
| a pairing failure | 1 (+3 wide-only) | see below. The three are counted per **site**, as the delta row is: two kinds of artifact, one of which sits in two mirrored copies — which is also why wide − narrow is 3 |

**The pairing failure is the one worth reading, because its victim is the best-behaved figure in the
tree.** `check-connectors.ps1:119` reads *"release-lib dot-sources entry-scaffold-lib behind it
(release-lib.ps1:113), and that file is 8,289 lines (measured: `wc -l scripts/lib/entry-scaffold-lib.ps1`)"*.
The figure is accurate, present-tense, and states its own method — it is #1779's repair done right. Its
subject is an antecedent two clauses back, so the nearest file token is `release-lib.ps1` at 1,776 lines
and the check flags it 4.7× over. The wide pattern adds three more sites of the same kind, from digits
that were never counts — `entry-scaffold-lib.ps1 line by line` yields "1 line" off the `1` of `.ps1`
(twice, once per mirrored copy), and `the pre-#1591 line` yields "1591 line" off an issue number.

**A resolver DOES fix that one, and the honest record says so.** Requiring the filename to sit in
backticks immediately before a present-tense copula — `` `<file>` is/are/measures/stood at N lines `` —
never has to resolve an English subject at all, because it refuses to fire unless the two are adjacent.
Measured against `main` at `69264276`: **1 finding, and it is the real one. Born green, 1 of 1.** So this
family is not impossible to gate, and the claim that it was — which stood in this paragraph until Marlowe
red-teamed it — was an overclaim. **It is left UNBUILT rather than declined**, which is the same verdict
and the same shape as the title-path rule two paragraphs up, on three measured prices:

1. **One subject tree-wide.** The same "close to nothing to guard" bar that left the title rule unbuilt.
2. **Blind to the motivating defect**, per the digit argument above — so building it would answer #1779
   with a check that could not have caught #1779.
3. **It still penalises citation, just less.** On the branch that records this decline the same narrow
   pattern goes from **1 finding to 3**, and both new ones are this write-up quoting the defect verbatim
   — the repaired site's own history sentence, and the paragraph above. Two thirds of its findings are
   then the documentation doing what this repo requires of it.

**Revisit condition**, stated so this is a priced option rather than a closed door: if a present-tense
`` `<file>` is N lines `` claim ever reaches three or four live subjects, the adjacency variant is
buildable in an afternoon and is green today. What must not be revived is the wide form.

**And the tolerance band is not a tuning knob, it is mandatory — which is itself the argument.**
`entry-scaffold-lib.ps1` went **8,289 → 8,290 during this branch's own `git pull`, eight commits**. So
the tree's single self-citing, method-stating, correctly-measured line count went stale inside one
fast-forward. Under an exact compare the check nags it; under a band it passes and every real finding
smaller than 5% passes with it. A figure that decays that fast is one a reader must re-run, not one a
gate can pin.

**The remedy is the wrong shape too, and in the opposite direction from the one #1784 predicted.** The
issue argued that check 16's binding would wrongly *pass* a stale line count. Measured, the reverse is
what happens: the tree's bound figures are bound correctly — `README.md:1254`'s "101, across 492 lines"
sits under *"measured against the `life-hub` consumer on July 29, 2026"* — so a re-measurement check
flags **history that already did what it was asked**, while the one real defect
(`06-25-extension.md:264`, "`CLAUDE.md` is 875 lines in 9 sections", against 526 in 3) is unbound and
present-tense. Adopting the check therefore means writing `<!-- unbound-figure: … -->` onto fifteen
correct sites to catch one, which is the exemption list this repo has already been bitten by.

**And the wide form has one more price, which is the one that generalises.** Recording this decline honestly — citing each instance
verbatim, as this repo requires of a measurement — took the same rule from **16 findings to 26** on the
branch that declines it. Ten fresh sites, every one a correctly-attributed count in a sentence that
argues from it, several of them the figures in the table above. So the rule does not merely mis-fire on
history: **it penalises the act of measuring and writing the result down**, which is the one habit this
gate's other rules exist to encourage. A check whose findings grow fastest in the documents that do
their job is aimed at the wrong thing, and the narrow variant inherits a third of that.

**Check 16's own docstring reached the same place a month earlier, for the wide form.** Its gateability
argument is that *"there is no authored, non-measured reason to write '939,860 bytes' — so the haystack
needs no heuristic to identify"*. A line count fails exactly that test: the same characters are a
snapshot, a delta, a section size, another repo's file, or a historical record, and telling them apart
is the heuristic the sentence rules out. The unit list is byte-shaped **deliberately**, and this
measurement is why it stays that way.

**What is left holding this class is the writing rule — and it is worth being exact about how strong
that is, because it is weaker than "already covered".** *"A re-derivable figure states its method, so
the next reader re-runs it instead of trusting it"* is in
[Tessa's portable manual](../../../plugins/dkj-subagents/dkj-subagents-alpha/manuals/06-16-manual.md)
and describes #1779 exactly. But it **predates** #1779, and #1779 is seven sites that did not follow it
— so it is a rule already measured failing, not one shown to suffice. Two things keep it as the answer
anyway, and neither is that it works reliably: no digit-anchored gate can see the form the failure took,
and the one enforcement gap that *looked* addressable — a figure gate reaching script docstrings at all —
was measured under [#1790](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1790) and
declined too (below). What the rule
demonstrably buys is legibility after the fact: `check-connectors.ps1:119` followed it, went stale by a
line inside one fast-forward, and is **still correct to read**, because the sentence says how to
re-derive it. That is the property worth insisting on, and it is not the same thing as prevention.

**Extending check 16's file set to `.ps1` COMMENTS was measured and declined** (September 10, 2026,
[#1790](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1790)). This is the second gap
#1784 named — not `lines` as a unit, but the byte-shaped pattern check 16 already runs, pointed at
script comments, where both recorded instances of the class ([#1779](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1779),
[#1775](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1775)) actually happened. The
narrow question was: should `$figurePattern` read `scripts/**` and `plugins/**/scripts/**` comments as
well as `$consumerDocs`?

**THE REASON THAT SETTLES IT: check 16's gateability claim is true of consumer prose and false of a
`.ps1`.** Its docstring argues the byte-shaped haystack needs no heuristic because *"there is no
authored, non-measured reason to write '939,860 bytes'"*. In a script there are two. **A design ceiling
is an authored byte figure** — `script-contract-lib.ps1:459` and `build-release-notes-page.ps1:215`
both write "32 KB per mark and 64 KB in total", beside the literals `$maxPerMark = 32KB` /
`$maxTotal = 64KB` that enforce them. **And a `.ps1` has no fence**, which is the markup boundary check
16 leans on to tell prose from code: in a script "everything outside a fence" is the whole file, so the
pattern reads numeric literals, `Write-Host "... / 1KB)) KB"` interpolation and
`Assert-Equal 0 $deadRow.Bytes 'a missing import costs 0 bytes'` as prose.

**Measured against `main` at `130a4794`, over `scripts/*.ps1` with check 16's own pattern and window
logic: 49 pattern hits, 26 flagged, and not one is a real defect.** The plugin mirrors under
`plugins/dkj-policy/scripts/` and `plugins/dkj-subagents/dkj-subagents-shopify/scripts/` add 26 more raw
hits — the triple-report the issue predicted — but the source-tree number sinks it on its own. The
flagged sites fall into classes no regex separates from a defect:

| class | why it is not a defect |
|---|---|
| encoding / mojibake prose | "the two UTF-8 bytes of U+00B7", "Windows-1252 bytes", "middot (U+00B7, bytes C2 B7)" — the digit-then-`bytes` shape fires on codepoint arithmetic, which this repo's script comments carry in a dozen places (the BOM / code-page trap) |
| an ANSI escape in a test string | `"fix/a$([char]0x1B)[31mb"` yields "1mb" off `\x1B[31m` + a following `b`, and `-match` is case-insensitive — three sites in `ref-print-lib.tests.ps1` alone |
| an authored design ceiling | `32 KB per mark`, `64 KB in total`, and the `32KB` / `64KB` literals beside them — the "no authored reason" premise, false here |
| code read as prose | numeric literals, `Write-Host` size interpolation, `Assert-*` message strings — no fence, so no prose/code line |
| check 16's own test fixtures | `check-plugin-integrity-entries.tests.ps1` holds "288 bytes" eight times as deliberate fixture data for this very check |
| check 16's own docstring | "939,860 bytes" and "~/.claude/settings.json at 22 bytes" are cited there as illustrations of the class |
| a degenerate constant | "0 bytes" meaning empty output (`native-capture-lib.ps1`, `ship-pr.ps1`) — it cannot drift |
| a one-time historical delta | `subagent-shared-lib.ps1:38` — "dropping it takes those 178 lines from 17,332 to 13,027 bytes", a past-tense record of what one edit did |
| a hedged approximate size | "~203 KB of portable prose", "~72MB of heap" — `~` is not in `$figureBinding` |

**The one script comment that already does what the check would ask is
`verify-resolved-issues.ps1:98`** — "measured September 9, 2026, 0 bytes at exit 0" — which carries a
date and passes. That is the writing rule working, not a gate.

**Same verdict and same shape as #1784.** The digit-anchored pattern cannot see #1779's actual form,
it penalises the comments that measure and say so, and the mirror multiplication triples every finding.
The unit list stays byte-shaped **and** the file set stays `$consumerDocs`-only; both are deliberate,
and this measurement is why. **Revisit condition**: if a present-tense `` `<file>` is N KB `` claim
carrying a decision ever reaches three or four live sites in script comments, revisit — but a file-set
extension needs a PowerShell-aware comment extractor first, not `.ps1` bolted onto `$consumerDocs`,
because the classes above are what "no fence" costs.

**The PR template that caused the collision is itself the change** (Dave, August 9, 2026). It now carries
one section — the changelog entry — because `open-pr.ps1` composes the body from
the DEPLOY section of `dkj-policy/<branch>.md`, so everything else it asked was already answered four lines lower. Measured
over 60 PRs before removing anything: `Type of change` had exactly **one of four** boxes ticked every
single time, a fact the entry states under `### Branch type` and which the GitHub label takes from
`Get-BranchInfo` rather than from the tick; of the checklist, `Requested by Dave` and
`Changelog entry written` were ticked **60/60** — both by the script itself — while the two items the
docstring called "human judgement checks" were ticked **0/60**, by anyone, ever, though both were already
enforced by gates that block the PR. A box that is always ticked and a box that is never ticked carry the
same information. The template also still offered a `chore/` row, four days after
`Test-BranchName` began refusing that prefix outright — the one line in the form that could actively
mislead. **`open-pr.ps1` keeps filling all of it in**: a consumer's PR template is their file, every one of
them still has those sections, and they receive the script through a plugin update rather than by choosing
to. Recognise both, write one.

**What travels from that decision is the MEASUREMENT, not the two-line answer** (August 10, 2026;
[#573](https://github.com/DaveKJohn/claude-code-specialists/issues/573)). The rule is *"keep what is
neither restated by the entry nor proven by a gate"*, and in this repo nothing survived it — which is a
fact about this repo, not about the form. The consumer who reported that issue re-ran the same
measurement over their own 60 PRs and found **one box of eight that genuinely varied**: a preview-URL
approval, on a repo whose result has to be judged by eye and which no gate can prove. They kept it and
dropped the other seven, and that is #538 applied rather than #538 ignored. So the portable half — the
`open-pr` skill and the reference template the plugin now ships — states *why* the default is two lines
and asks the next repo to run the measurement, instead of shipping "the portable template has no
checkboxes" as a conclusion. Their same pass confirmed the failure this repo predicted when it removed
the prefix checklist: **5 of their 60 PRs ticked two rows and 2 ticked none**, while the label came from
`Get-BranchInfo` in all 60.

**The template's shape is shipped, and the placeholder list moved so a gate could reach it** (same
issue). `.github/pull_request_template.md` cannot live in the plugin — GitHub reads it only from that
path in the consumer's own repo — so what ships is a reference to copy and diff against, at
`plugins/dkj-policy/templates/pull_request_template.md`, held byte for byte to
`Get-PrTemplateReference`. The three recognised placeholder strings were three literals inside
`open-pr.ps1`, which meant **nothing outside that script could read them**: the reference could not be
held against the list that has to recognise it, and that gap is the defect the issue reported. They now
live in `pr-body-lib.ps1`, and lint check 24 holds both files — the shipped reference byte for byte,
this repo's own template only to the contract, which since #865 is a recognised placeholder line and
nothing else: `open-pr` reads where the placeholder sits rather than the first heading, so a heading-less
template — the shape this repo actually ships — is supported and the gate must not refuse one. The second
file is held weakly because it is genuinely repo-owned, and a byte rule would refuse a correct change the
day it grows a section.

**The gate reaches `CHANGELOG.md`'s intro, and getting it there took two independent repairs** (August 8,
2026; [#525](https://github.com/DaveKJohn/claude-code-specialists/pull/525)). The check was born
excluding that file whole, on the history grounds it shares with checks 11 and 12 — but only the entries
below the intro are history. The intro is a live statement about the present mechanism that every cut
copies through **verbatim**, so it is the one piece of prose here that no release rewrites and no reviewer
opens; measured on the day it was repaired, it had promised *three* named sections for two days, with one
release and a consumer-facing release page in between. **Repairing either half alone changes nothing**:
the file was unread, *and* the pattern would have walked past the sentence anyway, because it carried no
`###` marker and ran across a line break. So the intro gets its **own pass with the level marker
optional**, and matching runs over the whole text instead of per line. Both relaxations were chosen by
measuring: whole-text matching finds the same **4** claims in the scanned tree as per-line, while dropping
the marker tree-wide would find **50** — which is why it is dropped only across the dozen lines of the
intro, where it was the whole difference between catching the drift and not.

**A link check that WAS built, and the neighbour it had to be told apart from** (August 29, 2026;
inbound [#1066](https://github.com/DaveKJohn/claude-code-specialists/issues/1066), lint check 30). The
declined stale-path rule above is the one this had to be measured against, because it looks like the
same proposal: another rule about paths in plugin-shipped prose, in a repo whose paths mostly describe
somebody else's tree. It is not the same, and the difference is the whole reason it was built — a path in
backticks is a *heuristic* about what a string means, while this is a **path comparison** with a
mechanical answer.

**The gap check 4 cannot close, and is right not to.** The dead-link scan resolves every link against the
tree it runs in, and for plugin payload that is the source repo — the one tree where the link is
guaranteed to work. It is correct about where the file *is* and has no notion of where the file will be
*read*. So the single class of link defect that reaches consumers is the one class it is structurally
blind to.

**The mechanism, read off disk rather than reasoned about.** Every `installPath` in
`~/.claude/plugins/installed_plugins.json` has the shape
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. The plugin's own directory is the root, and
the `plugins/` level, the family level (`teams/`, `workflows/`) and every sibling plugin are all gone —
a sibling is a separate versioned directory, not a neighbour. Worth knowing because the **marketplace
clone** is a full checkout of this repo, `.claude/` included, so a link verified there resolves and
teaches you the wrong lesson; the clone is where the catalog lives, the cache is where an installed
plugin is read.

**The report's own boundary was wrong, and its size was wrong in the direction that mattered.** #1066
proposed the rule as *"must resolve to a target also under `plugins/`, because that is the subtree the
plugin cache contains."* The cache contains no such subtree, and the weaker rule passes the one link that
had **already shipped dead** — `cut-release/SKILL.md:123` pointing at
`../../../../teams/dkj-subagents-alpha/manuals/06-25-manual.md`, verified against the installed v4.22.0 copy. So
the boundary is the **plugin root**, not `plugins/`, and scenario 37 of
`check-plugin-integrity-links.tests.ps1` exists to pin exactly that difference. The report also argued
from an expected count of **zero** (*"which is itself the reason not to build it yet"*) and stated that
nothing had shipped; the real count was **17 escapes in 5 files**, every one passing check 4, and
resolved inside the installed copies (`dkj-team-alpha` 4.21.0, `dkj-policy` 4.22.0) **all 17 are
dead**. That inverted its conclusion rather than qualifying it: the repo's name-a-risk-and-leave-it rule
holds until something bites, and this had bitten seventeen times in released payload.

**The two counts are different measurements and both are worth keeping**, because conflating them is how
the report went wrong in the first place. *17 escapes* is a property of the source tree, found by asking
where each link would land. *17 dead* is a property of the plugin cache, found by resolving those same
links inside `~/.claude/plugins/cache/` — the tree a consumer actually reads. They happen to be equal
here; nothing guarantees they are, and the second is the one that describes what a consumer meets.

**What it cost to hold to the same bar the declined rule was held to:** 98 relative links read across 83
markdown files in 5 plugin roots, 17 findings, **17 of them real** — against the stale-path rule's 124
findings, none real. Personas are excluded for check 4's reason and not a new one (their links are meant
to resolve at the consumer's `.claude/extensions/`, where check 4 already validates them), and three
forms are passed over: a `${...}` target is the plugin-relative form, a `~/` one points at the
marketplace clone deliberately, and an absolute URL is the repair being asked for.

**A prose contract check — the pointer-test analogue of `check-script-contract.ps1`, applied to law
instead of code — was measured and declined** (Dave, September 4, 2026;
[#1380](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1380)). Inbound
[#1379](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1379) asked for the two-sided
mechanism it names: a manifest of the laws `dkj-policy` legislates, and a consumer-side
check reporting any always-on consumer document that answers a listed law without declaring itself a
seam answer.

**The two facts that carry the decline, stated first because they are stronger than the structural
argument below on their own.** First, **the law the check was written to catch has zero standing true
positives.** `LAW-RELEASE-ORDER` was the acceptance test because
[#1378](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1378) had just made it the one
known-real defect in the corpus. #1378 was then repaired (commit `1db93328`) — Block 2's cut-then-push
became a default a live stage may answer differently, so the consumer's push-then-cut is now a
sanctioned answer the plugin actively invites, not a divergence. All 3 of that law's true positives were
in the English co-occurrence candidate and all 3 reclassify as sanctioned: the check's own reason for
existing was repaired out from under it while it was being measured. Second, **the detector found 1 of
the 3 defects that actually stand in the corpus.** The three: the stale `development.md` restatement in
each BWJ consumer (2, filed as #1389) and `smartwatchbanden`'s supremacy inversion (1, see below). Only
the `xoxowildhearts` `development.md` instance was ever flagged. The other two are false negatives —
`smartwatchbanden`'s stale instance was missed because the term list wanted a word that section does not
use, and the supremacy inversion was suppressed by the strict pointer match, the failure mode described
next. Recall on the real defects is 1 in 3, alongside the precision below.

**The corpus, corrected.** The original count of 13 documents counted this repo's own 4 always-on
documents (root `CLAUDE.md`, `SPECIALISTS.md`, Chris's persona, Chris's lens) as if they were a
consumer's, when this repo is the plugin's source and not a consumer at risk of drift — and it counted
Chris's persona three times, once per repo, when it is a single external file `@`-imported from the same
marketplace-clone path by all three repos, so 3 repos × 4 documents each collapses to 10 unique
documents, not 12, before any exclusion is applied. Applying the source-repo guard and excluding
plugin-shipped payload (`Source -eq 'external'`) removes this repo's 3 repo-specific always-on documents
(`CLAUDE.md`, `SPECIALISTS.md`, the lens) and the shared persona entirely, leaving **8 consumer-only
documents**: 6 always-on (`CLAUDE.md`, `SPECIALISTS.md`, the lens — 3 per repo × 2 BWJ consumers) plus 2
non-always-on `dkj-policy/CONTRIBUTING.md` (one per BWJ consumer).

**Four candidates measured (raw findings / true positives / precision), over the 8 consumer-only
documents:** a verbatim distinctive cue found **1 / 1 / 100%**; subject-term co-occurrence found
**21 / 1 / 4.8%** in English and **3 / 2 / 67%** in Dutch, **24 / 3 / 12.5%** combined; the same test
with a normative marker added found **13 / 1 / 8%** in English and **2 / 1 / 50%** in Dutch, **15 / 2 /
13%** combined; a declaration-based check — does the section say it is a seam answer — found **88**
(11 laws × 8 documents), zero declarations in any repo. The English and Dutch precisions move in
opposite directions between C2 and C3, but the combined figures, 12.5% against 13%, are indistinguishable
— the earlier apparent gap was an artifact of where three particular hits happened to sit, not a real
effect of adding the marker.

**The load-bearing structural reason: a strict pointer match suppressing a real contradiction is a
demonstrated failure mode, measured at 1 in 4 — not a coin flip and not "almost always."** By
construction a *flagged* finding is a section carrying no citation, so cites-then-contradicts can never
appear among flagged findings; it can only appear among **suppressed** ones, and the full census there
is 4 sections: 1 cites-then-contradicts, 3 cites-and-correctly-defers. The one is
`smartwatchbanden`'s own preamble: it names `CONTRIBUTING-portable.md` as a pointer into the plugin and,
four lines later, overrides it — the clause reads `wint` directly beside `` `CLAUDE.md` `` and names the
contributing page by a Dutch prose noun, `de contributor-pagina` (`smartwatchbanden/CLAUDE.md:22`).
Every candidate suppresses that finding, because the portable page's
filename sits right there. It is the cleanest real instance in the corpus and the detector is
structurally blind to it — a pointer test built on "is the source mentioned nearby" cannot distinguish
correct deference from restatement-with-citation-and-override, and 1 suppressed contradiction against 3
suppressed correct deferrals is the demonstrated rate, not an assumption. The parallel to the stale-path
decline above is exact, down to the shape of the failure: there the difference was *whose repo the line
is about*, which the line never says; here the difference is *whether the sentence agrees with or
contradicts the source it cites*, which no regex or term list reads.

**The verdict, at any of the three modes the inbound item proposed.** No candidate is shippable as a
gate, a SessionStart hook, or a deliberately-run `[INFO]`-only audit — the middle ground was measured
too, because #1380 explicitly asked about "a session-start check rather than a manually-run audit," and
the in-tree precedent exists (`check-script-contract.ps1`'s reachability half is always `[INFO]`, and
the hook passes `-SkipReachability`). It fails on its own terms: a human triaging 24 sections by hand to
find 3 real ones, at 1-in-8, with the flagship law gone, is not worth the run.

**The declaration-based check (C4) keeps its own, separate reason.** It is the structurally sound
design — a declaration is checkable the way a function signature is — and it reports 88/88 undeclared
because no consumer has adopted the convention: born red, in exactly the shape this repo already names
as a smell in itself. If it is ever revived it needs the convention bootstrapped first, the same way
`Get-LiveStage` and its siblings existed as real, populated seams before the script contract's
reachability half meant anything. Opt-in, per repo, `[INFO]` only, never `[ERROR]` against a convention
that does not exist yet.

**A third legitimate case surfaced that the third-rank corollary above does not name, and it is exactly
why "consumer prose answers a listed law" cannot be the trigger on its own.** Sometimes the plugin
*asks* for the answer to be written out: `cut-release`'s Block 2 declines the seam deliberately —
*"No seam, deliberately"*, `Get-LiveStageCutOrder` exists nowhere — and tells a consumer running the
non-default order to state it in its own `CLAUDE.md`. That case is filed as
[#1388](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1388) rather than resolved here.

**Record the alternative that IS proportionate, because a decline that names no better route invites the
same proposal again.** Two narrow, literal, high-precision one-off greps, each aimed at one law instead
of one framework carrying eleven at 12%: one for the literal string `development.md` outside the
changelog and history paths, one for a supremacy declaration — `wins`/`wint` plus `CLAUDE.md` plus the
contributing page's own filename, all three in the same sentence.

**The first of the two was built the same day** ([#1389](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1389),
September 4, 2026): `check-retired-doc-name.ps1`, driven by a SessionStart hook in every consumer and
[described above on this page](#what-sylvester-owns-here) — both greps live in
`check-consumer-prose.ps1` since #1421 merged them, one day later and before either had shipped. It kept the three constraints this entry
imposes — literal names, derived rather than listed; the corpus as an inclusion list with the changelog
out; and the publishing-repo skip — and it carries one stated gap, the shape `development-<branch>.md`,
which has no literal form.

**The second was built later that same day** ([#1415](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1415),
September 4, 2026): `check-supremacy-declaration.ps1`, its own SessionStart hook, and
`Get-ConsumerProseDocuments` — the corpus enumeration lifted out of the first check so both read one
definition of which documents a consumer-prose check may look in. **And the sentence above it, the one
this entry recorded as the alternative, did not survive its own measurement.** That is worth stating in
the entry that wrote it rather than quietly correcting: it had never been run as a check, #1415 asked for
it to be measured before it shipped, and over the same 8-document corpus the three-term same-sentence
test scores **0 raw findings and 0 recall** — on the single defect it was named to catch. Loosened to a
paragraph it finds **1**, and that one is a false positive.

**The reason is exact and is the useful part.** The instance is
`smartwatchbanden/CLAUDE.md:22`, whose clause carries `wint` beside `` `CLAUDE.md` `` and names the
contributing page by a Dutch **prose noun**, `de contributor-pagina`, not by its filename — so the third
term is precisely the one absent. The filename sits two lines up, in a different sentence. Nothing about
the sentence is unusual; what was wrong was inferring a term list from a defect that had been read
rather than grepped.

**What ships instead is ADJACENCY, and it is the same literalness arriving at a different rule.**
`CLAUDE.md` and `wins`/`wint` must sit next to each other, either order, nothing between them but
markdown — which answers the question co-occurrence cannot: *which page is being declared the winner*.
Direction is the entire defect. *"this page wins"* over `CLAUDE.md` is `LAW-THIRD-RANK-ORDER` stated
**correctly** and a term list scores it identically to the inversion. Measured on the same corpus:
**3 raw / 2 reported / 2 true / 100%**, one hit suppressed for sitting inside a `"…"` quotation (a page
narrating a rule it retired). Against this page's own bar — the accepted dead-link check at 17/17, the
declined stale-path check at 124/0 — it lands on the accepted side, where the recorded shape landed
below the declined one.

**And it found one more standing defect than this entry's census knew about.** The census above counts
the suppressed sections as 4: 1 contradiction, 3 correct deferrals. The contradiction is
`smartwatchbanden`'s `CLAUDE.md` preamble — but the same inversion is stated a second time, from the
other side, in that repo's own `dkj-policy/CONTRIBUTING.md`, and no candidate measured here
ever counted it. Two standing instances, one repo.

**One inheritance was asked for and turns out to be a guard rather than a repair, which is worth saying
plainly.** #1415 required the publishing-repo skip on the ground that this repo's pages *"discuss
supremacy declarations at length, so without it the source reads as consumer drift"*. Measured: this
repo's own always-on pages produce **zero** hits without the skip, because every supremacy sentence here
names the plugin's page as the winner and adjacency reads that correctly. The skip is kept — this is
where sentences about a consumer's rank order get written, and one future line would fire — but it is
sibling consistency and cheap insurance, not the repair it is for the retired-name grep. Since #1421 the
two share **one** skip, so that difference is stated once, in `check-consumer-prose.ps1`, instead of
being inherited by a copy that would not know it had changed meaning.

**The manifest survives the decline** — a later revisit should not have to re-derive 11 laws from
scratch:

| Id | Canonical statement | Source | Seam |
|---|---|---|---|
| `LAW-RELEASE-ORDER` | Block 1 (cutting) always runs first; Block 2 (going live) only follows it, where a live stage exists. | `cut-release/SKILL.md` — "Order matters" | `Get-LiveStage` |
| `LAW-NO-TRUNK-DEVDOC` | The branch's development document exists only for the branch's lifetime; the trunk carries no copy. | `DEVELOPMENT-portable.md` | none |
| `LAW-BRANCH-DOC-PER-BRANCH` | One development document per branch, named after it — not a single shared `development.md`. | `CONTRIBUTING-portable.md` — "2. Branch" | none |
| `LAW-SIGNIFICANCE-NOT-FROM-PREFIX` | Never infer significance/tier from the branch prefix — the prefix predicts nothing about impact. | `CONTRIBUTING-portable.md` — "Significance" | none |
| `LAW-TIER0-NOT-NA` | Tier 0 can never be N/A; its floor is a score of 1. | `CONTRIBUTING-portable.md` — "Significance" | none |
| `LAW-NOTREQUIRED-CHECK-DOES-NOT-BLOCK` | A failing not-required check never blocks the merge; `ship-pr` merges past it and relays its reason. | `CONTRIBUTING-portable.md` — "5. Merge" | none |
| `LAW-SHIP-IN-BACKGROUND` | Run the merge step in the background — the required check waits regardless. | `CONTRIBUTING-portable.md` — "5. Merge" | none |
| `LAW-PR-TITLE-COMPOSED` | No PR title is passed by hand — it is composed as `<branch type>: <Branch title>`. | `CONTRIBUTING-portable.md` — "4. Open the PR" | none |
| `LAW-CLAIM-ISSUE-BEFORE-WORK` | Claim an issue before working it, and read the claim as well as write it. | `CONTRIBUTING-portable.md` — "1. New issue or task" | none |
| `LAW-DOCCOMMIT-BEFORE-PUSH` | `open-pr` commits the development document alone, never `git add -A`, before anything is pushed. | `CONTRIBUTING-portable.md` — "4. Open the PR" | none |
| `LAW-THIRD-RANK-ORDER` | The plugin's portable pages/skills outrank `dkj-policy/CONTRIBUTING.md`, which outranks the floor. | `CONTRIBUTING-portable.md` — "A third rank sits above both" | none |

**Any future attempt still needs the source-repo guard plus the exclusion of plugin-shipped payload
(`Source -eq 'external'`)**, or this repo's own pages and the shared persona read as consumer drift,
exactly as they did before the correction above. Do not revive this behind a rule that reads nearby text
for the source and calls that deference — that is the exact test this entry measures as structurally
blind to the one real contradiction it has to catch.

#### Check 32, and the extraction that came with it (September 6, 2026, [#1491](https://github.com/DaveKJohn/claude-code-specialists/issues/1491))

**The check is the ordinary shape** — a hand-maintained list beside a registry that can be asked, gated
by an opt-in sentinel. What is worth recording here is the two decisions that were *not* obvious, and one
defect the branch produced and caught.

**The scope is the marked document's own FOLDER, not its plugin**, which is where it parts company with
check 29. `skills:plugin` resolves a plugin and holds the span to that plugin's whole `skills/` tree;
`shared-scripts:mirror` narrows `Get-SharedScriptPairs` to the mirrors landing at or below the directory
the marked document sits in, and relativizes against it. That is not a refinement of the same idea but a
different question, and it is what makes the rows comparable **as written**: the page's own table says
`task/new-branch.ps1`, because that is where the reader stands. A plugin-scoped implementation passes
every scenario in the suite except 48, which is why 48 exists.

**The claim is the row's first cell**, and this is the third distinct claim rule in three span checks —
check 10 reads every backtick, check 29 reads link targets, this one reads the first backticked token of
each table row. That is not drift: the subject picks the rule. This table's second column is running prose
carrying `-Worker`, `Get-LintScript` and `Invoke-GitPark`, and its third links a `SKILL.md` rather than the
script, so under either sibling's rule the correct page reports phantom rows. Check 10's answer to that is
an author condition — *wrap tightly* — which this table cannot meet without being rewritten to satisfy a
checker, and check 29's own comment already refuses that trade for the same reason.

**AND THE EXTRACTION, which is the part to read before touching any of the three.** Checks 10 and 29 were
the same forty-five-line walk written twice — fence masking, the forward scan, the unpaired-BEGIN error,
the orphan-END sweep, the nested-BEGIN sweep — and they had **diverged**. The nested-BEGIN case was silent
in check 10 from the day it was written, was found only while walking into it on check 29's branch, and had
to be repaired in both places on August 26, 2026. A third hand-written copy would have been the third place
to repair and the one most likely to be missed, so the walk became `Invoke-MarkedSpanWalk` and all three
checks now call it. The suites are what made that safe to do: 108 asserts across checks 4/10/28/29/30
passed unchanged before a line of check 32 was written.

**The defect the branch produced, because it is the exact failure this gate exists to prevent.** Splicing
the rewritten check 29 into the file through a shell heredoc silently ate the doubled backslashes in two
regex literals: `'\\skills\\[^\\]+\\SKILL\.md$'` landed as `'\skills\[^\]+\SKILL\.md$'`, which matches
nothing. Both the canonical set and the claim set then came back **empty**, the comparison of empty to
empty produced no findings, and the whole gate reported **0 errors** — green, with check 29 asserting
nothing at all. Nothing in the findings could have shown this. What showed it was the **coverage line**
(`Write-Coverage`, issue #221): `with 0 claim(s)` against a baseline of `17`, which is precisely the
argument for why a verdict never travels without the count behind it. Three consequences, all acted on:
the suite's scenario 42 asserts the derived canonical set is **non-empty** before any comparison is
trusted; check 32's coverage line prints **both** sides — rows read *and* mirrors registered — because a
claim count alone cannot tell `0` against `0` from `45` against `45`, and both of those report *no
findings*; and a code splice into a `.ps1` is written with the editor tools rather than through a shell
heredoc — the mangling class is the one already documented in the manual's PowerShell traps, arriving by
a different route.

**The middle one came out of the code review rather than out of the failure**, which is worth noting: the
defect was in check 29, and the reviewer's question was whether the *new* check could fail the same way on
a real run, where the suite's guard does not reach. It could — silence needs only both sets empty — and
the answer was not a runtime assertion but the missing figure, which is the same answer #221 gave.

**AND THE SECOND FAILURE, which is the one worth reading, because the guard worked and the diagnosis did
not.** The suite went red on CI and green on three local runs. The non-empty guard above fired exactly as
designed — `matched=0` — so the branch could not ship a vacuous check. What went wrong was the *reason*:
the obvious mechanism was a path-form mismatch (a GitHub Windows runner's `GetTempPath()` returns the 8.3
short form, `C:\Users\RUNNER~1\…`, and `GetFullPath` expands one where a string compare does not), it was
plausible, it was cheap to fix, and it was **wrong**. The runner's own diagnostic printed the long form.

The actual cause: **CI tests the pull request's MERGE commit, not the branch.** While this branch was
open, [#1480](https://github.com/DaveKJohn/claude-code-specialists/issues/1480) renamed
`plugins/teams/team-alpha` to `plugins/dkj-subagents/dkj-subagents-alpha` on the trunk. The suite's fixture builds
its marketplace to match the real one, so on the merge commit the mirrors landed under the new name while
the test's **hardcoded** `plugins\teams\team-alpha\scripts` pointed at a directory that no longer existed.
Locally, on a base predating the rename, both agreed. A branch open across a rename sees this and a branch
opened after it never does.

**Three things to carry forward.** First, the irony is the lesson: a test for a check whose whole subject
is *a hand-maintained path list going stale* was itself carrying a hand-maintained path. It now asks the
registry which plugin receives mirrors and uses that plugin's folder, so the next rename moves it for
free. Second, when local and CI disagree, **the merge commit is the first thing to check** — `git log
origin/main` costs one command and would have ended this in a minute, where three rounds of reasoning
about path forms did not. Third, the `GetFullPath` normalisation was kept even though it fixed nothing:
the mismatch it prevents is real, it costs nothing, and its comment says plainly that it has never fired,
so no later reader cites an unfired guard as a measurement.

#### Check 34, and the number that was prose (September 6, 2026, [#1494](https://github.com/DaveKJohn/claude-code-specialists/issues/1494))

**The defect is the gate's own.** Two unrelated checks in `check-plugin-integrity.ps1` both carried the
number **30** — `[plugin-link]` and `[barred-skill]` — and both were already load-bearing in *published*
prose, pointing at different checks: release note `4.23.0` means the first, `4.24.0` the second. A reader
who grepped for the number a finding came from got two answers, and a released document was the source of
one of them. The numbers were hand-assigned, cited in a lens, a plugin hook, nine test scenario names and
two release notes — and read back by nothing, in the one file whose whole purpose is refusing a
hand-maintained list a machine could ask about.

**Renumbering was chosen over disambiguating in prose**, which was the cheaper option the report
preferred. Writing ``check 30 (`[barred-skill]`)`` everywhere answers the grep and leaves two sections
numbered 30, so the next hand-assigned number can collide again and the disambiguation has to be
remembered at every new citation. The barred-skill check — the later of the two, the one that took an
already-taken number — became **33**. The archived notes are history and are not rewritten, so `4.24.0`
still says 30 and stands as the record of when that was true, which is how this repo already treats a
superseded measurement.

**ASCENDING is the property that prevents the collision; uniqueness is only what broke.** A check for
uniqueness alone still permits inserting a section anywhere and hand-picking its number, which is the act
that produced the duplicate. Requiring each column-0 header to sit strictly above the one before it leaves
a new check exactly **one** legal number — the one after the last header in the file — so the number stops
being a choice. That is why check 33 was *moved* below 32 rather than left sitting between 30 and 31: a
renumbering that satisfies uniqueness without moving the block lands on the ascending rule instead, and
the suite's scenario 54 is that exact case.

**Gaps are legal and there are three** (9, 17, 19). A retired check leaves its number behind; reusing one
would silently repoint every older citation, which is the same defect arriving by the other door. Two of
the three carry a retirement note where the check stood, and that note is the convention.

**The second spelling is a finding, not a skip** — and it is why the duplicate stayed invisible. Four
headers read `# --- Check <n>: ` where the other twenty-nine read `# --- <n>. `, so no single pattern
listed them all and the collision showed up in a grep of neither. Passing over an unrecognised spelling
would let a file opt out of the numbering rule by spelling its headers differently.

**Column 0 only, and that bound is measured rather than tidy.** The same `# ---` marker is used *indented*
inside the four lint suites to separate scenarios within a function, under its own numbering that restarts
and repeats freely. Those are not file sections, and holding them to this rule would be the gate inventing
a convention the repo never had — the narrowing check 26 had to make for the same reason. Scenario 57 is a
purpose-built fixture for that bound rather than an assert on the suites' own headers, so it says what it
proves instead of depending on this file staying shaped as it is.

**Born green, and demonstrably firing.** Measured across this repo's script set before the check was
written: **19** files carry a column-0 numbered header, **123** headers in all, **0** exemptions. After the
#1494 repair the gate reports 0 findings over 124 (the check adds its own header). Run against the
pre-repair file the same reader reports **5** — the one duplicate and the four headers in the other form —
so it fires on what it was written for rather than merely passing. The check is repo-wide rather than
scoped to the gate, because the convention is: 19 files use it, not one.

**What it costs, and the two savings DECLINED** (measured September 6, 2026, on this repo's 205-file
script set). The check adds **~110 ms** to a full gate run — 10.03 s against 9.91 s over three reps each,
a **1.2%** delta. Two ways to get some of that back were measured and both were declined:

- **Making it skippable** — adding `section-number` to `$SkippedForSpeed` in
  [`check-plugin-integrity-fixture.ps1`](../../../scripts/tests/check-plugin-integrity-fixture.ps1), so
  the ~60 ms it costs *per `Invoke-Integrity` call* stops being paid by the 175 scenarios across the four
  lint suites that are not about it. Worth **~10.5 s of CPU**, or up to **~3.6 s** off the slowest CI lane
  once the four suites' parallelism is accounted for. **Declined**, because it buys that by widening
  `$script:SkippableChecks`, which the gate holds at exactly the three its own suites need and whose
  comment says in so many words that a fourth is a deliberate act and the narrow list is the safety
  property. Check 31's comment records the same answer for the same reason — *"NOT SKIPPABLE, like every
  check added since the `-SkipCheck` list was fixed"*. Three-and-a-half seconds on one lane does not buy
  a wider surface for switching a check off by accident.
- **Sharing the read with check 27** — the pure-ASCII check reads the *same* 205 files unconditionally,
  through `ReadAllText` where this one uses `ReadAllLines`, at **84–92 ms**. One pass would save roughly
  one of the two reads. **Declined as premature**, on #1358's own bar: that extraction was worth doing
  because the *walk* cost 1.16 s and the parse only 0.26 s, and this whole check does not clear a tenth of
  that. The AST cache is not a candidate backing store either — it retains `CommandAst` nodes, so
  recovering line text from it would cost more than reading the file again.

Recorded rather than left implicit so the next reader does not re-derive either number: the saving is real
and small, and the reason for not taking the first one is a safety property rather than the arithmetic.

**Adjacent and deliberately NOT repaired here:** the gate's own comments cite `check 19` and `check 20b`,
neither of which exists as a header — the same class one layer over, a citation nothing reads back. Filed as
[#1500](https://github.com/DaveKJohn/claude-code-specialists/issues/1500) rather than folded in, because
holding every `check <n>` citation to an existing header needs its own false-positive decision about
legitimately citing a *retired* check, which two of this file's comments do correctly — the retirement notes
naming checks 9 and 17. The repo has paid for this class once already in the other direction: `4.12.0`
records a lens citing check 19 for what the lint implements as check 20.

#### The template self-containment gate, which is a SUITE and not a numbered check (September 7, 2026, [#1556](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1556))

**It lives in [`scripts/tests/template-selfcontained.tests.ps1`](../../../scripts/tests/template-selfcontained.tests.ps1), so do not go looking for a check number.**
The section above is about `check-plugin-integrity.ps1`; this one is a test suite, and the placement is
the point rather than an accident. The subject is a **PowerShell AST**, which the lint gate reads nowhere
else, and the property is per-file rather than repo-wide — while the lint gate is what every consumer's
adoption runs, and check 34's own measurement above is the record of what an extra ~110 ms there is
argued over. Both run inside `lint-en-tests`, so a suite catches this at exactly the same moment a check
would.

**What it guards.** A template under `plugins/**/templates/` is copied wholesale into a consumer's
`.github/` and run by *their* CI. It dot-sources none of this repo's libraries — it cannot, since none of
them travel with it — so every Verb-Noun name it calls must be one it defines, one PowerShell provides, or
one it declares external. Today that is one file, `asana-mirror.ps1`.

**The `Get-Command` guard IS the declaration, and reading it is what keeps the check allowlist-free.**
That template legitimately calls `Get-AsanaStageMap` and `Get-GithubStatusMap`, which live in the
*consumer's* `scripts/repo-config.ps1` and are dot-sourced at run time — and it tests for each with
`Get-Command -Name '<name>'` before calling it, because a consumer defining neither must still get a
working run. The check believes that guard. A hand-maintained exemption list was the obvious alternative
and is the same defect one layer up: it goes stale the first time a seam is added, silently, which is the
answer check 34 above reaches for the same reason.

**File-wide rather than paired**, deliberately: the guard and the call it protects are routinely in
different functions, and matching them would be a dataflow analysis buying no extra safety.

**Only hyphenated names are judged.** `gh` and `git` are external executables whose presence says nothing
about the template's correctness, and resolving them would fail the suite on a machine that merely lacks
the CLI. Every function this defect class can produce is Verb-Noun.

**Born green and demonstrably firing** — the bar check 34 set. Against the repaired template it reports
0 over 65 hyphenated call sites and 49 definitions; run against the pre-repair file it reports exactly
`Get-IssueClosure`, measured by dropping that copy into `templates/` and running the suite unmodified.
The two seams above are what made the naive version report three, and finding them is what settled the
guard rule rather than an allowlist.

**Two PowerShell traps are pinned by fixtures rather than left to be rediscovered**, because both fail in
the direction that reads as success: a returned empty `@()` is unrolled to `$null` (so `,@(...)` is
returned, or a clean template is indistinguishable from an unparseable one), and `$null -ne @()` *filters*
instead of comparing (so the parse assert reads `$null -eq` and negates). The suite also asserts that it
found at least one template at all — a renamed `templates/` folder would otherwise turn the whole thing
into a no-op reporting green.

**Why a parse-time check is the only thing that could have caught #1556 here.** Nothing executes the
template end to end during its own release, and the crash was in `Update-MirroredTask`, which the sweep
reaches only when it has something to say — so the consumer's Actions tab filled with green event runs and
green empty sweeps, and the first sweep with real work to do died on it, taking the prio-label and stage
sweeps with it.

#### The `~/.claude` pollution check, and the guard that was measured and DECLINED (September 8, 2026, [#1609](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1609))

**It is [`scripts/lint/check-claude-home.ps1`](../../../scripts/lint/check-claude-home.ps1), driven by
the `claude-home-sessioncheck` SessionStart hook in `dkj-policy`** — a sixth machine-fact check beside
`git-identity`, and in no gate for the same reason: a CI runner has no plugin administration at all, so a
workflow leg would report the empty state on every push.

**What happened.** While working #1591 an exploratory debug script — throwaway, written
mid-investigation, never committed — ran without redirecting `$env:USERPROFILE`, so every path it built
from the user home resolved to the real one. It overwrote `~/.claude/plugins/installed_plugins.json` with
two fixture records naming a `%TEMP%` `projectPath`, and left a fixture marketplace clone at
`~/.claude/plugins/marketplaces/ccs-fixture/`. Every real per-checkout record was gone — this checkout and
both registered consumers — with no backup beside the file and no error anywhere. What a session *saw*
was `roster-sessioncheck` and `plugin-versions` reporting every plugin as *"not installed in this checkout
(enabled declaratively only)"*, which by then was literally true and is indistinguishable from the
ordinary state [#1449](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1449) describes. It
was found by reading the file.

**The guard #1609 proposed does not fit, and that was measured before anything was built.** The report
asked for a helper that refuses to write under `~/.claude` unless the resolved home is a scratch path.
Two things rule that shape out here:

- **Nothing in the committed tree writes under `~/.claude` — every reference in `scripts/` is a READER.**
  So the helper would ship with no in-tree caller, enforced only by a one-off script's author remembering
  to call it: the same unenforced instruction #1609 correctly criticises `Get-InstallRecord`'s docstring
  for being. And the lint gate could not hold anyone to it either, there being no committed writes to
  check.
- **A command-string guard cannot see it.** The `PreToolUse` shape that works for
  [`guard-live-theme.ps1`](../../../plugins/dkj-subagents/dkj-subagents-shopify/hooks/guard-live-theme.ps1) reads
  the command a session is about to run; here that command was `powershell -File <temp>/dbg.ps1` and the
  write lived inside the file. Inspecting the **heredoc that wrote the script** is a real vector and is
  the one worth revisiting if this recurs — but the false-positive surface is exactly the one
  `guard-live-theme` spent a release learning, and worse here: this repo writes *about*
  `installed_plugins.json` constantly (check 12 is entirely about printed queries against it), so the
  first thing such a guard blocks is the fixture that tests it.

So the harness is the only thing that reaches a throwaway script, and it reaches it twice — detect, and
recover. **Decision by Dave, September 8, 2026**, on those two measurements.

**The signature is ONE thing: a record whose `projectPath` sits under a scratch tree.** No checkout lives
in `%TEMP%`, so such a record was written by a fixture. It is a signature no existing reader can see, which
is why `Get-InstallRecord` gained an `AllRecords` field: the three fields it already returned are all
filtered — to this repo's path, or to the pathless — and a fixture record is dropped **twice**, once for the
path mismatch and again because a deleted fixture root no longer resolves (#301).

**The orphan marketplace directory is reported only as part of that finding, never as a scan of its own,
and that is the declined half.** An independent *"a directory under `marketplaces/` that
`known_marketplaces.json` does not reference"* check fires on ordinary residue: measured the same day,
`~/.claude/plugins/marketplaces/claude-plugins-official/` is exactly that — left behind by removing a
marketplace, nothing to do with any fixture. Reporting it forever is the cry-wolf failure #294 spent a
release removing, and the stale-path check was already declined here at 124 findings all false. So a
polluted **record** names its marketplace and the check then says whether that clone is also sitting in the
real tree, which is the actionable half and is how `ccs-fixture/` would have been named.

**The snapshot is the recovery half, and the ORDER is what makes it safe.** On a healthy read the check
copies the administration to `installed_plugins.snapshot.json` beside it — after the verdict, only on a
clean one, and only when the content differs. A polluted file can therefore never become the snapshot, and
restoring it puts the previous records **back**, where re-installing writes new ones and changes what is
installed. That distinction is why #1609 was left unrepaired at filing rather than fixed in a minute.

**It is the only session check in the family that WRITES**, and that is a change in kind rather than an
oversight — every other session check states in as many words that it changes nothing. The write is bounded to one path it
owns, never happens on a finding, and is switched off by `-NoSnapshot`. It also has no `MeasureArgs` in the
registry, deliberately: the no-argument form reads the real administration, and a timing harness must not
write to it as a side effect of measuring.

**A missing administration is a finding only when a snapshot sits beside it.** On its own, absent is the
ordinary state of a machine that has never installed a plugin into a project — so the snapshot is the one
thing that separates that from a file something deleted, and the verdict turns on it rather than on the
missing file. Without that the check would cry wolf on every fresh machine and be switched off before it
ever caught anything.

**Every value it prints out of that JSON file is sanitized, and this check is the place in the tree
that needed it most.** The hook forwards the whole output into session context and decides how loudly by
matching `[ERROR]` over it, so an id carrying a newline can forge a line and one carrying a bracket can
be *counted* — the vector #309 and #414 were filed for. The check's own premise is that this file may
hold whatever a stray script wrote, and the first draft printed the record fields raw. So `Id` goes
through `Format-SuspectToken` (the record is the complaint, and a sanitized id shown as clean would hide
what is wrong with it), `ProjectPath` and the clone directory through `Format-SafePathToken`, and
**`$record.Error` through `Format-SafeProseToken`** — that last one is the widest of the three and does
not look like it: `ConvertFrom-Json`'s message **embeds the offending document**, so on an unparseable
administration it carries the file's whole raw text, and a file that parses would never reach that
branch.

**The boundary is stated so it is not over-applied: values out of the JSON are sanitized, paths this
script builds from the environment are not.** `$record.Path` and the snapshot path come from the
resolved home, and two of the lines printing them are a `Copy-Item` command the reader **pastes** —
`Format-SafePathToken` truncates at 200 characters with an ellipsis, so sanitizing there would hand
somebody a command that silently does not work.

**And the sibling hooks are NAMED rather than counted, which this branch proved the hard way.** The
draft said *"its four siblings all state that they change nothing"*; two reviewers checked that sentence
and returned two different numbers, four and five, because one counted `dkj-policy`'s hooks and the
other counted every plugin's. **Both were wrong** — eight hook files across three plugins carry that
line. It is the same failure the plugin README's own hooks cell already records ("this cell said *two*
and went stale twice inside two days") and the same answer: name one, count none. Worth keeping because
the count was wrong in a *docstring*, where no gate looks, and it was load-bearing — it is the sentence
justifying the write.

**Its suite may never touch the real `~/.claude`, and that is the defect under test rather than a
courtesy.** [`scripts/tests/claude-home-gate.tests.ps1`](../../../scripts/tests/claude-home-gate.tests.ps1)
passes `-HomeOverride` into a fixture tree for every case, and `-NoSnapshot` for every case that is not
about the snapshot. It also passes `-ScratchRootOverride` everywhere, for a reason particular to this
check: the fixture trees live under `%TEMP%`, which is what the check calls scratch, so without the
override every record a fixture writes reads as polluted and the **clean** case cannot be expressed at
all. The machine's own resolution — `$env:TEMP` and a literal `\temp\` path segment — is therefore a
**named test gap**: a suite asserting on it would be asserting about the machine it happens to run on.
What is pinned instead is the boundary logic those roots feed, including that a sibling directory whose
name merely *begins* with a scratch root's name is not inside it.

#### Check 35, and the sweep that reported itself finished (September 8, 2026, [#1655](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1655))

**The check exists because a sweep is not an enforcement**, and this one is the cleanest instance of that
this repo has. [#1635](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1635) moved the
judging of a test fixture's own git commands into
[`scripts/lib/fixture-git-lib.ps1`](../../../scripts/lib/fixture-git-lib.ps1) and converted seventeen
suites onto it — and left nothing that refuses the next copy of the idiom it removed. The idiom was never
a mistake somebody made once; it was the **house style**, copied from suite to suite for as long as
`scripts/tests/` has existed, and the next fixture builder is written by copying the nearest neighbour.

**What the measurement actually found, and it is not what the report predicted.** #1655 asked for the
matcher to be run over the swept tree, expecting zero, and over the pre-sweep tree, expecting the fifteen
suites it had counted. The first number came back **27, in four files** — `find-specialist-mentions`,
`shared-scripts`, `source-repo-guard` and `fresh-consumer.measure`, whose spellings the sweep's own search
never reached: `git ... 2>&1 | Out-Null` with no `&`, and `& $git @(...)` over a scriptblock. So the
branch that added the check also finished the sweep, and the check is born green with **0 exemptions**.
The pre-sweep tree read **182 findings across 18 files** — the house style, measured.

**The reason #1635 did not just add the check was a good one, and answering it was the work.** This repo
has scar tissue from checks born needing an exemption list (the stale-path check declined at 124 findings
all false, above), and there is a real false-positive class here: a git call that is a **question** rather
than a mutation. A `rev-parse --verify --quiet` on a ref *expected* to be absent answers with exit 1 and
is judged on the very next line; counting it would report every negative case as a defect, and #1635's own
conversion hit that class twice.

**What separates the two classes is cheap, and it is not a list of git verbs**: a question's exit code is
**read, and read immediately**. So a call is cleared when `$LASTEXITCODE` or `Assert-FixtureGitOk` appears
in the same statement or the next one. Over both trees that rule produced **zero probe false positives** —
not one `rev-parse`, `ls-remote` or `show-ref` call appears in either finding set — and it also clears
`publish-to-business.tests.ps1`'s deliberately failing probe, which reads `$probeCode = $LASTEXITCODE`.

**The subject is a DISCARDED result, not every unjudged call, and that bound was measured too.** Widening
it to a bare statement pipeline (`git log --oneline` with no `Out-Null`) yields **20 findings on this tree
and 20/20 are false** — every one a value-returning question, a helper's implicit return or
`return @(& git ...)`. Discarding the output *and* ignoring the exit code is the combination meaning
nothing git said was read; either alone is ordinary.

**And the check's own stated boundary was probed rather than trusted, which is what found the gaps the
measurement could not.** Running contrived shapes past it turned up a third way to throw a result away —
a `[void]` cast — that this tree simply does not contain, so no amount of measuring it would have
surfaced. Leaving it out would not have stopped the idiom; it would have renamed it, and the finding's
own message would have become advice on how to get past the check. The rule generalises: a measurement
tells you what a check catches *here*, and only a probe tells you what it would wave through.

**The code review then found the same class one level deeper, and that one is the more instructive
half.** Adding the `[void]` arm meant walking out of the `(...)` a cast requires — and only that arm did
it, so `$null = (& git ...)` and `(& git ...) | Out-Null` were both silently skipped: the exact call the
check exists to catch, wearing one pair of brackets. Neither spelling exists in this tree, so the probe
above did not reach them either; what found it was noticing that three arms of one check disagreed about
wrapping. **The repair is that the unwrap is now shared rather than written per-arm** — climbed once, so
every discard spelling is judged on the same node. A guard whose arms disagree about a detail teaches
whichever shape the weakest arm accepts.

**The clearing condition moved onto the AST in the same pass**, for the reason check 31 already states —
*through the parser, not by line matching* — and it applies with extra force to a condition that
**clears** a finding: a text match on `$LASTEXITCODE` is satisfied by the name sitting in a single-quoted
string or a trailing comment, and a wrongly cleared miss leaves nothing behind to notice. A
`VariableExpressionAst` is a read; a comment is not in the AST at all.

**Two invocation spellings are in scope, because a check written BECAUSE spellings vary must not repeat
the sweep's mistake**: a command named `git`, and `& $git` where the variable is named exactly `git`. A
wrapper under any other name is out of reach, and the check's own comment says so rather than implying
coverage it does not have.

**The check is free on a gate run; its TESTS were not, and that is where the cost review earned its
place.** Check 35 rides the `Get-PsScriptCommandAsts` cache checks 31 and 33 already populate, so the
gate measures 11.21s with it against 11.26s without — noise. But each scenario asserting on gate output
spawns a fresh PowerShell over the ~4,000-line script, ~1.1s of interpreter start and parse whatever it
asserts, and written the obvious way — one rewrite-and-reinvoke per shape — the scenarios cost **12
invocations, taking the docs suite from 54.5s to 63.7s (+17%)** on a file that runs on every push and
again in CI. The shapes are independent, so they batch by **expected verdict**: everything that must fire
in one run, everything that must stay silent in the next. Same asserts, **3 invocations, +2.8s instead of
+9.2s**. What pays for it is that each probe carries its shape in its file name, so one run's output still
says which shape failed — batching scenarios that could not be told apart afterwards would trade a real
diagnostic for the seconds, which is a different and worse deal.

**And the probe that took this measurement carried the defect it was measuring for.** Its first run
reported 36 findings including nine `rev-parse` probes that the next-statement rule should have cleared —
because `@($i, $i + 1)` is `@($i, $i) + 1` in PowerShell, the comma binding tighter than the addition, so
it silently checked statements `$i`, `$i` and `1`. Nine false positives from a two-character omission, in
the pass whose whole job was deciding whether the false-positive rate was acceptable. The parenthesised
form is now in the check with a comment saying why, and it belongs beside the other traps that produce
well-formed wrong output.

#### The nested-worktree exclusion, measured and DECLINED (September 9, 2026, [#1678](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1678))

**The tree walks in this gate are FILESYSTEM walks, not git walks**, so a worktree registered inside the
repo is a second complete copy of the tree the gate is standing in. Measured here with one probe at
`.claude/worktrees/probe-1678`: every recursive count from the root doubles exactly — `*-agent.md` 26 to
52, `plugin.json` 6 to 12, `*.ps1` 233 to 466 — and the gate then fails with **26 errors, one per
specialist id, each naming the REAL file as the offender** and the worktree's copy as the legitimate
claimant, because that path sorts first. The coverage lines report the doubled sets as normal
(`checked 52`), so nothing in the run says the *set* is wrong rather than the files. That symptom is
[#1673](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1673)'s, and its named finding is
the accurate sentence an operator now reads instead of the 26.

**What #1678 left open was the fork after that, and this is the answer: the gate REFUSES, and is not made
to work through a nested worktree.** The alternative was real — roughly twenty `Get-ChildItem -Recurse`
sites here plus the suites that walk the root, behind one shared predicate — and it is declined on four
grounds, each measured rather than argued:

1. **The gate is the only chokepoint anyone passes, so the walks below it never run.**
   `Invoke-WorkflowGates` ([`gate-lib.ps1`](../../../scripts/lib/gate-lib.ps1)) runs the lint half
   **first** and `return $false`s on its failure, several dozen lines above the test gate. So on the
   documented route a nested worktree is named once and the two suites that would double never execute.
   Excluding the path from them buys nothing a caller can reach — and what is past the refusal is
   `-SkipLint`, the switch that already means *this run did not measure*.
2. **The price was quoted one suite too high.** #1678 names three root-walking suites; measured, there are
   two. `subagent-shared.tests.ps1` (the `*-agent.md` and `*-persona.md` walks) and `shared-scripts.tests.ps1`
   (the `*.ps1` scan) do walk `$RepoRoot` and do double. `template-selfcontained.tests.ps1` walks
   `Join-Path $RepoRoot 'plugins'`, and a worktree under `.claude/` is not inside that subtree: its
   templates count stayed at 1 with the probe standing. This does not change the verdict, but a declined
   option should be declined at its real price.
3. **The exclusion is the enforced-by-memory shape [#1665](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1665) was filed against.**
   A predicate every walk must remember to call, in a four-thousand-line file that has grown to 36
   numbered checks, is reintroduced silently by the next walk somebody adds — so it needs a meta-check
   policing the whole file, forever, to hold. That is a permanent cost bought for an arrangement this repo
   steers away from anyway, which is ground 4.
4. **The repo has already decided where a worktree belongs.**
   [`worktree-lane.ps1`](../../../scripts/task/worktree-lane.ps1) places lanes **outside** the tree and
   says why in as many words — *"a worktree inside the tree would be walked by the lint gate's link scan
   and by the test suites."* Both halves of that sentence are correct, and the lane is the supported route
   for a session that wants isolation. Making the gate work through a nested worktree would endorse the
   one arrangement the lane exists to avoid. The harness's own `isolation: "worktree"` does not get that
   choice — the path is `.claude/worktrees/agent-<id>` and nothing here selects it — but
   [#1667](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1667) has already decided the
   review chain is not dispatched that way, so what remains is a caller who opted in and is one
   `git worktree remove` from the gate, or one lane from never meeting it.

**The residual is stated rather than left to be discovered.** With `-SkipLint` a standing nested worktree
still hands those two suites a doubled set in silence. That is not a hole this decision opens — it is what
`-SkipLint` means everywhere in this repo — and it is one more reason the refusal lives in the gate rather
than being spread across the walks: one place to state it, one place that can go stale. Worth keeping
beside it: `git worktree remove` leaves the empty `.claude/worktrees/` parent behind, so the directory
outlives the worktree it held and the next `git worktree list` is the honest check, not the directory's
existence.

#### Check 37, and the second hand-maintained list this file was keeping (September 9, 2026, [#1680](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1680))

**Check 34 reached half of the problem it was filed for.** It reads the column-0 `# --- <n>.` headers back
and holds them to each other, which is what stopped two checks sharing a number. What it has no opinion
about is the **prose list in the gate's own `.DESCRIPTION`** — the summary a reader who has not opened a
four-thousand-line file consults, and the one a lens, a hook, a test-scenario name or a released note
quotes a number from. That list was read by nothing, in the one file whose purpose is refusing a
hand-maintained list a machine could check.

**It had drifted in three directions at once, and only two were reported.** #1680 named the first two: the
list stopped at **30** while the code ran to **36**, and its own item `30.` described the barred-skill
check that #1494 had renumbered to **33** a month after the list was written — so a reader who grepped the
list for "check 30" was told about a check answering to a different number, which is precisely the
confusion #1494 was filed to end, one layer up. The third was older and quieter: items **9** and **17**
still described checks **retired on August 8, 2026**, reading as live ones. They are tombstones now,
keeping their numbers for the reason the code keeps the gaps — reusing one silently repoints every older
citation.

**And the check found a seventh missing entry on its first run, which is the whole argument for building
it rather than repairing the list by hand.** `13b` — no branch document left behind between branches — has
a real header and had no line in the list; no report had noticed, including the one that counted the
others. A hand pass resets the clock, exactly as [check 32](#check-32-and-the-extraction-that-came-with-it-september-6-2026-1491)'s
own header says about the three hand repairs of the mirror table before it.

**ONE DIRECTION, AND THAT IS WHAT LET IT BE BORN GREEN.** Every header must have an entry; an entry need
not have a header. The reverse direction is where the exemptions live, and there are three legitimate
entries with no header of their own — the two tombstones, and the consumer-doc guard the suites already
call check 19, which carries no column-0 header at all (check 20's comment says why in as many words). A
rule asserting both directions would have arrived needing exactly those three exemptions on the day it was
written, which is the shape this repo declined at 124 findings all false and has refused since. Measured
after the seven entries were written back: **1 span, 37 headers, 37 claimed, 0 findings, 0 exemptions.**

**OPT-IN, through the same `Invoke-MarkedSpanWalk` checks 10, 29 and 32 use.** A blanket rule keyed on "a
script carrying numbered headers" would be born with a finding for each of the **19 files** check 34
measured, none of which claims to enumerate anything: the marker is what turns a list into a claim, and it
is the only thing that does. Reusing the walk also inherits its three refusals for free — an unpaired
opener, a stray closer, and a second opener inside an open span — each of which would otherwise read as
"no list here", the one failure mode that turns a gate green by silencing it.

**The header pattern is check 34's own literal, deliberately.** Two readers disagreeing about what a
section header is would let a header satisfy one and not the other, which is the divergence this tree has
extracted libs to prevent elsewhere.

**And the suite had to be kept OUT of its own subject, which is scenario 57's trap arriving through the
other door.** `check-plugin-integrity-commands.tests.ps1` is a `.ps1` in the set check 37 walks, so a
literal marker in a fixture line would open a span in the *suite* — a file with no numbered headers — and
the real gate run would report the test file. The scenarios compose the marker from a variable instead.
Where check 34 needed the suite to *be* its fixture for the indented-header bound, this one needs it to
stay outside the walk entirely.

**One measured trap worth keeping, because it produced a well-formed wrong answer.** The count assert in
scenario 58 read 2 where 1 was right: this check's own coverage line contains the words *"claims to
enumerate them"*, so a pattern matching finding *phrases* counted the coverage line as a finding — the
same trap three patterns in that suite already document, met again by the check that was added to it. The
assert now matches the finding's leading path, which the coverage line does not have.

**The review round moved four things, and three of them are the same defect wearing different clothes: a
rule read off the happy path.** The claim reader matched *any* indented line opening with `N. `, so a
nested enumeration inside an entry's prose would have registered claims — and drop those entries later
and the nested pair keeps satisfying their headers with the gate green, which is the drift this check
exists to refuse. The repair is that an entry must **start inside the list's gutter**, whose width is the
narrowest number prefix in the span. The first attempt required the exact prefix width, which is what a
*perfectly* right-aligned list would have; this one is not — `3b` and `3c` sit one column out — and it
reported two real entries as missing. The weaker rule is the true one: however ragged the alignment,
every entry begins inside the gutter and a line indented past it is prose. Second, the header comparison
ran **inside** the span callback, so a file with two spans counted its headers twice and named one gap
twice; it now runs once per file over the union of its spans, which also makes a split list legal. Third,
the coverage note keyed on the span count, so a **broken** marker printed *"the marker is opt-in, so zero
is a pass and not a gap"* in the same run that raised an error about that very file — the two zero states
are now said separately.

**And the shape of the fourth is worth more than the fix.** The nested-enumeration hole was found by
**probing** the check, not by measuring the tree: the list contains no such line today, so no amount of
measuring would have surfaced it. That is
[check 35](#check-35-and-the-sweep-that-reported-itself-finished-september-8-2026-1655)'s own lesson —
*a measurement tells you what a check catches here, and only a probe tells you what it would wave
through* — arriving at its neighbour one day later. The same round also found the branch document citing
`.SYNOPSIS` where the list lives in `.DESCRIPTION`, in an entry whose whole subject is a citation being
wrong, and which travels verbatim into `CHANGELOG.md` and then a release note.

**Two bounds are named rather than closed, and the reason is the same in both.** A **stale** entry still
satisfies its number: renumber a check, add the new entry, and the abandoned line — still describing what
moved — keeps the old header satisfied. That is #1680's second drift recurring, and reaching it means
reading an entry's text against a header's, which is a fuzzy rule, and a fuzzy rule on a gate arrives
with an exemption list. Check 34's ascending rule limits the blast radius to a lingering line rather than
a wrong live one. And the two zero-state coverage notes **cannot be asserted from the suite**: every
fixture run invokes a copy of this script inside the fixture, and that copy carries the list, so one
valid span always exists there. Both are written into the check's own header, because an unstated gap
reads as coverage.

#### Check 38 was proposed for removal, and the proposal was DECLINED on a measurement (September 10, 2026, [#1771](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1771))

**The report asked for the opposite of what the gate does, and was wrong on its central claim.** #1771
concluded that the manifest's `agents` key *"registers nothing, in every form the validator passes"*, that
the four team plugins therefore ship no specialists at all, that `subagents/` must be renamed back to
`agents/` across 44 occurrences with the key dropped, and that check 38 should additionally **refuse the
key existing at all**. Its evidence was `claude plugin details` reporting `Agents (0)` for each of the
four, reproduced against a two-plugin control.

**That measurement is real and it answers a different question.** `plugin details` reports what its own
inventory counts, and the inventory counts only defs found by convention in a plugin's default `agents/`
directory. What it cannot tell you is what a **session** loads — and the session filing the report had
all 26 subagents in its own agent list, from these four plugins, out of `subagents/`, named by the key.
Nothing in the report's evidence contradicted that, because none of it looked there.

**The evidence that needs no rig at all, and it was in the room.** The specialist who red-teamed this
conclusion is `06-29-agent.md`, and in the resolved plugin cache that def is reachable **only** through
`dkj-subagents-alpha`'s `agents` key: the cache holds `subagents/` and **no** `agents/` directory, so no
convention scan could have found him. A subagent arguing about whether subagents load is a primary
measurement, and it costs nothing to take.

**The control that settles the exclusivity half, and the shape worth reusing.** A throwaway local
marketplace, one plugin, two agent defs in one non-default directory with only **one** of them named in
the `agents` key — installed **fresh** into a scratch project, then each one **actually dispatched**
through `claude -p`:

| def | in the `agents` key | in the resolved cache | `plugin details` | dispatched |
|---|---|---|---|---|
| `zebrafish` | yes | yes | not counted | **`ok ZEBRAFISH`** |
| `quokka` | no, same directory | yes | not counted | **`Agent type 'keyed:quokka' not found`** |

**Both columns on the right are the point, and the first version of this control had neither.** It asked
a session to *list* the `subagent_type` values it had, which a model can answer from belief rather than
from the harness — so the run above **invokes** instead, and a returned `ZEBRAFISH` is a dispatch that
happened. And it installed at 1.0.0 and then *updated in place* to add the second def, against a CLI that
had just printed `Restart to apply changes` — which makes `quokka` absent for a reason that has nothing
to do with the key. Both defs are present from the first version now, and the cache is listed before the
dispatch, so *"named loads, unnamed does not"* is the only reading left. Marlowe caught both holes in
review; the conclusion survived, its proof did not, and a conclusion resting on a control this repo
would not accept is one bad rerun away from being wrong.

So the key **is** honoured by the loader, and honoured **exclusively** — which is the very sentence
check 38's completeness rule already states (*"once the key is present it REPLACES convention discovery,
so the list is the only way in"*), inferred from the validator in #1764 and now measured against the
loader. Refusing the key would have forbidden the mechanism that works and un-guarded the one that
does not. The rename was not built, and #1764's repair 1 stays declined.

**And that leaves a standing cost, which is a trade rather than a repair.** Check 38's own header names
it: this repo carries a hand-maintained list of 26 paths across four manifests, *"which is the shape this
file exists to refuse"*. A specialist whose def ships without its manifest entry loads for nobody, and
check 38 is the only thing in the tree that looks. That tax was accepted in exchange for not renaming a
directory a fifth time; it is worth re-reading whenever the list grows, because the alternative did not
become wrong, only unnecessary.

**What DID need repairing was the instrument, and it had gone red without anyone reading it.**
`measure-skill.ps1` refused two of the six enabled plugins with *"the output of `claude plugin details`
did not parse as expected"* — `-ecomm` and `-lifehub`, the two that ship only agents — because the CLI
prints no per-component table at all for a plugin whose inventory is all zeroes, and an empty table was
read as a format change. The emptiness is now judged against the inventory's own counts: nothing owed is
an `[INFO]` naming why, something owed is still the `[ERROR]`, and an inventory that could not be read
**stays** the `[ERROR]` this check exists for — the three-state lesson `claim-issue`'s read-back learned
in [#1628](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1628), where one boolean
carried two opposite facts and printed the wrong one. The report's own second half is why it matters that
the tool was believed: `Agents (0)` was read as *ships none*, and a share computed over a skills-only
total was reading as *the skills are effectively all of this plugin's cost* while ~2,260 tokens of agent
descriptions sat outside it. Both are now stated in the output;
[Nolan's lens](06-25-extension.md#how-to-measure-it--claude-plugin-details-july-28-2026) carries the
measurement half.

**The transferable lesson is the one this repo's constitution already states** — *a reported finding's
reason is verified before it is repaired, not just its symptom.* #1771's symptom reproduced exactly, on
the first command; the reason behind it did not survive the second one. Had the reason been taken at its
word, the repair would have moved 44 occurrences, reversed a rename decided the day before, and turned a
working guard into one that refuses the working configuration — a change that satisfies the report, is
wrong, and now carries a citation. The report's own author named the hazard in its last section and did
not apply it to itself: *"that choice was made on my measurement of what the validator accepts, and I did
not measure whether an accepted form loads."* The measurement missing at the top was the same one.

#### The retired-id `continue`, and the block it silently skipped (September 10, 2026, #1802)

**#1802's proposed repair rests on a premise that was false when filed, and the tree already falsifies it
three times over.** It reported three findings about the `~/.claude` plugin administration on Dave's
machine and proposed: *"a check that compares a repo's `enabledPlugins` keys against the install records
for that `projectPath` and reports a key with no matching record. That is the one comparison nothing
currently makes."* Grepped rather than taken on faith: three readers already make it.
[`plugin-versions.ps1`](../../../scripts/task/plugin-versions.ps1) prints exactly that verdict — its
`not-installed` code's own line, `cannot determine -- not installed in this checkout (enabled
declaratively only)`, with `claude plugin install <id> --scope project` as its action. Check 4 of
[`check-connectors.ps1`](../../../scripts/sync/check-connectors.ps1)'s no-install-record branch makes
the same comparison for a different vantage point and states the consequence in prose: a session in
that checkout loads none of that plugin, "and that repo cannot report it -- the hook that would is
inside the plugin that is not loading," plus a `[NOT-INSTALLED-HERE]` promotion for the session's own
repo (#533). And
[`tidy-machine.ps1`](../../../scripts/maintenance/tidy-machine.ps1) lane 11 (#1773) — landed the same day
#1802 was filed — cleans up install records under a retired plugin name, which is #1802's own finding 3;
lane 8 (#1449) covers its orphan-record sibling. **A report's claim that "nothing currently makes this
comparison" is a claim about the tree, and it is checked against the tree** — the same discipline the
`triage-inbound` skill already applies to a proposed repair's mechanism or a symptom's currency, applied
here to an assertion of absence, and worth an entry there in its own right (below).

**The wider shape the report implied was also already declined, by name, in the tree it was filed
against.** `tidy-machine.ps1`'s own docstring, in its "IT VISITS NO OTHER CHECKOUT" paragraph: *"Dave's
second answer on September 10, 2026 was 'this checkout plus the machine-wide lanes' rather than 'every
checkout the machine knows about'"*. A mechanism that walked every consumer checkout to answer #1802's
question directly was on the table the same day and was the reverse of what got built.

**What did stand, underneath the false premise, was a real and narrow defect: a `continue` that skipped a
whole block silenced every check inside it, including the one check whose subject did not depend on the
reason for skipping.** In `check-connectors.ps1`'s `'retired'` branch, a plugin id the marketplace no
longer declares hits `continue` before check 4 ever runs. The reason for the block being unreachable is
that two of its three checks — the extension inventory and the version comparison — read the plugin's
*source folder*, which a retired name has none of. **Check 4's install-record question needs no source
folder at all**: it asks whether this machine holds a record for that `projectPath`, and the answer is as
available for a retired id as for a current one. The `continue` did not distinguish the two, so it
silenced a check whose vantage point had nothing to do with the reason the other two were skipped. For a
consumer enabling nothing but retired ids — both of #1802's worst-measured cases, life-hub and
thumbnail-generator — the one check with a vantage point on "this checkout loads nothing" was exactly the
one that never ran, and the register reported them as "correct as it stands." Sylvester's repair asks the
install-record question inside that same `'retired'` switch arm too, and splits `plugin-versions.ps1`'s
one actionable indeterminate verdict out to its own `not-installed` code — the marker split in its
`-Brief` block — so it reads as `[ERROR]` there rather than riding quietly in the same bucket as every
other "cannot determine" line that is genuinely bookkeeping.

**The generalisable half: guarding a block on one condition is only as narrow as the condition, and a
block can hold checks that do not all share it.** `continue` inside a `switch` arm reads as "this whole
case is inapplicable," which is true of two thirds of what it was skipping and false of the third. The
question worth asking before writing one is not "does this block apply" but "does *every* check inside
it depend on the reason it does not" — the same shape as the mention-vs-use question checks 11/12/18
already ask of a printed command or a mirrored parameter, arriving here as a skipped branch instead of an
unheld one.

**Byte-equality is necessary and not sufficient for a mirrored script, and the gap is exactly one class
wide** (September 11, 2026,
[#1857](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1857)). Check 8 holds every shared
script byte-identical to its plugin mirror, which proves the two copies are the same **text** and says
nothing about them **behaving** the same — and the thing that makes the difference invisible is the
equality itself: the characters are identical, so there is nothing to diff. What differs is where the
two files sit. A shared entry point lives at `<x>\scripts\<area>\<name>.ps1` in both copies, where `<x>`
is the repo root for the source and the **plugin root** for the mirror, so a `$PSScriptRoot` resolution
ascending **two** levels lands on a different folder in each.

**One hop cannot, and that bound is what makes a gate worth having here.** `..\lib\...` reaches
`<x>\scripts\` — the same folder relative to the file in both copies — so the overwhelming majority of
resolutions in the tree are depth-invariant by construction. Measured when check 39 was written: **3 of
34** entry points cross the boundary — `adopt-config`'s `..\..\blueprint\config-blueprint.json`,
`check-policy-drift`'s `Split-Path (Split-Path $PSScriptRoot -Parent) -Parent`, and
`adopt-workflow-folder`'s `..\..\templates\pull_request_template.md` — and **all three were already
correct**. A rule that flagged one hop would have buried those under the thirty-odd that cannot differ,
which is the shape this section already records being declined at 124 findings.

**The third one is the best argument for the check there is, and it is worth keeping for how it
arrived.** The branch measured **two**; `adopt-workflow-folder`'s PR-template reference merged to `main`
while the gate was being built, and check 39 caught it on its **first CI run** — because CI tests the
branch merged with the trunk and the branch's own working copy cannot see what landed beside it. It is
also the exact resolution #1857 was filed about, so the issue's subject was reachable by the gate and
not by the session that wrote it. Two things follow. A count taken from a branch base is a **snapshot**,
and this one went stale inside a day, which is why the live figures belong in the coverage line and the
number in prose is dated. And a gate whose subject is *"what nobody has thought about yet"* is measured
correctly only against the trunk — the local run said the tree was clean, and it was right about the
tree it could see.

**What was actually wrong was the proof, not the code.** Both crossings had been verified by hand, and
hand verification is what this repo keeps replacing with gates. Worse, the copy that fires in **every
released install** is the mirror — the source copy exists for this repo and its suites — so the
candidate nobody executed was the only one a consumer ever reaches. One suite did run a mirror
(`git-identity-gate.tests.ps1`, four weeks earlier, with a comment stating this reasoning in full), and
it covered a script with no crossing at all.

**The repair is split deliberately, and the split is the reusable part.** The gate refuses an
**undeclared** crossing and holds the declaration to something real — the named suite must exist and
must name the mirror — while whether that suite **asserts** anything is the suite's job. That is the
same line check 18 draws between this gate and a skill page, and trying to prove assertion statically
from the gate would only produce a check that is confidently wrong. The declaration lives in the
registry beside `LibOnly`, `Skill` and `MeasureArgs`, for the reason all three moved there: a
hand-written list somewhere else is one a newly shared script falls out of silently (#275/#331), and
catching the script nobody has thought about yet is this check's whole job.

**And the detector's own first draft is the cautionary half.** It climbed to the *nearest* enclosing
statement, which is correct for a literal and silently halves the second form: a `PipelineAst` is itself
a statement, so `Split-Path (Split-Path $PSScriptRoot -Parent) -Parent` stops the climb at the **inner**
pipeline, where one hop is in scope and the ascent reads as one level. It reported `adopt-config`
correctly and found nothing in `check-policy-drift` — a gate that looks green and covers half its
subject, which is worse than one that covers none. Climbing to the statement that sits directly in a
block fixes it, and both forms are pinned in `shared-scripts.tests.ps1` rather than only through the
gate's fixture.

In short: the **how** (managing the harness, scripts, config, safety guards) is portable; the **what**
(the plugin lint + drift lint, `branch-info.ps1`, `.claude/settings.json` with the github source, and
the marketplace/plugin manifests) belongs to this repo.
