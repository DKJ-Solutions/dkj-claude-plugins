# `dkj-policy/scripts/` — the shared workflow scripts (mirror for consumers)

This folder is what a **consumer** of this workflow actually runs. It is a **mirror**, not the source:
the canonical copy of every script here lives in [`scripts/`](https://github.com/DKJ-Solutions/claude-code-specialists/tree/main/scripts/) at the root of this
repository, and that is where development and testing happen. The point of the arrangement is that
consumers (life-hub, smartwatchbanden, …) no longer keep a duplicate of these scripts per repo. The
rationale is in [issue #81](https://github.com/DaveKJohn/claude-code-specialists/issues/81).

**The model — mirror, not a move:**
- The **workshop root copy is the canonical, tested source** (`scripts/…` in this repo). CI runs it from
  a bare checkout.
- The copy **here in the plugin is an LF-identical mirror** — that is what a consumer runs, via a skill.
  The workshop itself keeps using its root copy.
- A **drift lint** (`check-plugin-integrity.ps1`, check 8) guards that mirror and source stay equal, and
  the generator `scripts/sync/build-shared-scripts.ps1` updates the mirror. This way the mirror inherits
  the root copy's test coverage without our having to run it live in the workshop (which is impossible:
  the workshop consumes the last-pushed plugin, not your branch).

**Do not edit a file in this folder.** A change lands in the root source first and travels here through
the generator; the lint reports a hand edit as drift.

## The shared set

The registry is `Get-SharedScriptPairs` in
[`scripts/lib/shared-scripts-lib.ps1`](https://github.com/DKJ-Solutions/claude-code-specialists/blob/main/scripts/lib/shared-scripts-lib.ps1), and it is the
only place that knows the answer. **This page deliberately states no count of it**, and the root
`scripts/README.md` made the same choice on the same day (#897): a prose tally of a machine-held list is wrong
when typed and wrong again after the next entry. Ask the registry instead — and note the pairs do **not** all
land here, because a script travels to whichever plugin owns the surface that calls it.

| where the mirror lands | why there |
|---|---|
| `dkj-policy` (this folder) | the branch/PR/release way of working, which is what this plugin *is* |
| `dkj-subagents-shopify` | the store-facing scripts, whose surface belongs to the platform team |
| `dkj-subagents-alpha` | `sync/check-roster-sync.ps1`, `lib/check-report-lib.ps1` and `lib/hook-check-lib.ps1` — the roster check belongs to the core team, since the roster does, and it carries the one SessionStart hook in this family that ships outside the workflow plugin |

*A fourth destination, `workflow-default`, held one pair — `lib/check-report-lib.ps1` again — until
[#886](https://github.com/DaveKJohn/claude-code-specialists/issues/886) removed that plugin on
August 26, 2026.*

**The table below is hand-maintained beside a registry that can be asked, which is the shape that goes
stale** — three times over, so far. Three rows were missing when the count was last checked (August 15,
2026 — `adopt-workflow-folder`, `session-status` and `source-repo-guard-lib`, each registered but never
listed), re-measuring on August 26 found the header, the destination split and the row list all wrong at
once, the split not even naming `dkj-subagents-shopify` as a destination, and a third re-measurement
([#1486](https://github.com/DaveKJohn/claude-code-specialists/issues/1486), September 6, 2026) found 21
more rows absent — every row from `task/claim-issue.ps1` down through `lib/claim-issue-lib.ps1` in the
table above, now added. `session-status` has since gone the other way: it was removed along with `/lock`
and `/handover` ([#957](https://github.com/DaveKJohn/claude-code-specialists/issues/957), Dave), so its
row went with it.

**There is no fourth, because the table is now gated**
([#1491](https://github.com/DaveKJohn/claude-code-specialists/issues/1491), September 6, 2026). The
`shared-scripts:mirror` markers around it are read by check 32 (`[shared-script-list]`) in
`check-plugin-integrity.ps1`, which holds each row's first cell against the mirrors `Get-SharedScriptPairs`
lands in this folder and reports both directions — a registered script with no row, and a row the registry
no longer mirrors. Registering a pair without writing its row now turns the gate red on the PR that
registers it, where all three misses above were merged green and found months later. **The check reports
rather than writes**, which is the half that has not changed: a row still needs a description and a Skill
answer, and neither is a figure a script could produce on its own.

Not every script here is reached through a skill, and the **Skill** cell says so rather than linking one, so
an absent link is a fact rather than an oversight.

<!-- shared-scripts:mirror -->
| Script | What it is | Skill |
|---|---|---|
| `task/new-branch.ps1` | creates the branch AND writes its `dkj-policy/<branch>.md`, in one move — a branch is never entry-less | [`new-branch`](../skills/new-branch/SKILL.md) |
| `task/park-branch.ps1` | commits all outstanding work + `git push -u` — no PR, no live action | [`park`](../skills/park/SKILL.md) |
| `task/adopt-config.ps1` | reads the config blueprint and places or proposes each seam answer | [`adopt-dkj-policy`](../skills/adopt-dkj-policy/SKILL.md) (Part 2) |
| `task/adopt-workflow-folder.ps1` | scaffolds `dkj-policy/` — the folder docs, the releases root and the branch dossier | [`adopt-dkj-policy`](../skills/adopt-dkj-policy/SKILL.md) (Part 1) |
| `task/adopt-merge-queue.ps1` | reports whether this repo would survive a GitHub merge queue on its trunk, places the runners a queue takes away from the shipping session plus a scheduled repo-settings check, and prints the ruleset command without running it | [`adopt-dkj-policy`](../skills/adopt-dkj-policy/SKILL.md) (Part 3) |
| `task/adopt-triage-labels.ps1` | reports which of the four canonical `prio-1`..`prio-4` triage labels this repo's tracker is missing and prints a paste-ready `gh label create` line for each — never creates one itself | none — see [`CONTRIBUTING-portable.md`](../CONTRIBUTING-portable.md#1-new-issue-or-task--where-the-work-comes-from) |
| `task/claim-issue.ps1` | claims a GitHub issue for this checkout by the account its commits will name, not `@me` — refuses on a closed issue or one already held by someone else | [`claim-issue`](../skills/claim-issue/SKILL.md) |
| `task/worktree-lane.ps1` | opens a branch in its own git worktree — a "lane" — so one branch can be built while another ships, and hands a lane's branch back to the primary checkout when it is ready | [`worktree-lane`](../skills/worktree-lane/SKILL.md) |
| `task/park-cycle.ps1` | the automatic half of parking: pushes the branch's development document to origin, unless a PR has already published it | documented on the [`park`](../skills/park/SKILL.md) page; run only by the `cycle-autopark` Stop hook, never by hand |
| `task/prune-merged.ps1` | fast-forwards the trunk and deletes local branches that are provably merged; a branch without that proof is left alone | [`prune-merged`](../skills/prune-merged/SKILL.md) |
| `maintenance/tidy-machine.ps1` | the whole-machine tidy in eleven lanes — stale worktree lanes, branches whose PR was CLOSED without merging, expired `backup/*` branches, old stashes, install records naming a checkout or a plugin name that is gone, fixture trees under the scratch root. A conductor: six lanes call a script already in this table, and it deletes only through `prune-merged`'s own two proofs | [`tidy-machine`](../skills/tidy-machine/SKILL.md) |
| `lib/tidy-lib.ps1` | the pure classification behind it: which local clutter is provably finished, which is merely finished-looking, and which is live work. Dot-sourced, no side effects | documented on the [`tidy-machine`](../skills/tidy-machine/SKILL.md) page |
| `task/plugin-versions.ps1` | per enabled plugin: the version installed in THIS checkout (from the install record for this path) against the marketplace clone's `plugin.json` version + git HEAD, with a verdict on whether a plugin update is due | [`plugin-versions`](../skills/plugin-versions/SKILL.md) |
| `task/update-plugins.ps1` | refreshes the marketplace clone once, runs `claude plugin update <id> --scope project` for every plugin this checkout enables, then prints `plugin-versions.ps1`'s own receipt — the 1 + N commands `plugin-versions` would otherwise hand over one at a time, run as one | [`update-plugins`](../skills/update-plugins/SKILL.md) |
| `task/check-fanout.ps1` | `-Capture` before a fan-out and `-Compare <path>` after it: reports only what SHRANK in the working copy — a changed path that is now unchanged, a reverted worktree edit, a stash entry gone by its own id. Growth is expected and stays silent | [`check-fanout`](../skills/check-fanout/SKILL.md) |
| `task/check-policy-drift.ps1` | lists every law-bearing document in rank order — the installed plugins' portable pages against this repo's own — so a session can read the two against each other; locates and hands over, decides nothing | [`check-policy-drift`](../skills/check-policy-drift/SKILL.md) |
| `release/open-pr.ps1` | the gates, the push and the PR; lint gate via `Get-LintScript` in `repo-config` | [`open-pr`](../skills/open-pr/SKILL.md) |
| `release/ship-pr.ps1` | open → wait for CI → merge → fold, in one motion | [`ship-pr`](../skills/ship-pr/SKILL.md) |
| `release/verify-resolved-issues.ps1` | checks that a merged PR closed what it declared | [`ship-pr`](../skills/ship-pr/SKILL.md) |
| `release/verify-pushed-merges.ps1` | the check above, run from a push to the trunk instead of from the shipping session: resolves the pull requests that push carried and verifies each | none — invoked by a `verify-resolved.yml` CI workflow, which [`adopt-dkj-policy`](../skills/adopt-dkj-policy/SKILL.md) (Part 3) places |
| `release/fold-changelog-entry.ps1` | folds the entry into `CHANGELOG.md` at the top of the list and removes the branch document | [`fold-changelog`](../skills/fold-changelog/SKILL.md) |
| `release/cut-release.ps1` | the lockstep version bump, the release notes and the tag | [`cut-release`](../skills/cut-release/SKILL.md) |
| `release/new-internal-note.ps1` | the tier-1 note's skeleton, which needs the development notes as input | [`cut-release`](../skills/cut-release/SKILL.md) |
| `release/build-release-notes-page.ps1` | builds the hand-written notes into one browsable page, and with `-Worker` the Cloudflare Worker that serves it — it publishes nothing | [`release-notes-page`](../skills/release-notes-page/SKILL.md) |
| `release/release-notes-page-template.html` | the page that script fills in — the one shared file here that is not a script, mirrored for the same reason a lib is: its script reads it as a sibling | none — read by the script above |
| `lint/check-branch-entry.ps1` | gate: does this branch carry a written changelog entry? | [`check-branch-entry`](../skills/check-branch-entry/SKILL.md) |
| `lint/check-unfolded-entry.ps1` | gate: does the trunk carry an unfolded changelog entry — a per-branch development document a merge left behind because its fold never ran? | none — invoked by the `unfolded-entry-sessioncheck` SessionStart hook and by CI on every push to `main` |
| `lint/check-consumer-prose.ps1` | gate: does this consumer's own law-bearing prose contradict the plugin? | none — invoked by the `consumer-prose-sessioncheck` SessionStart hook |
| `lint/check-git-identity.ps1` | gate: can this checkout commit at all, and does it commit as the same account it acts as on the tracker? | none — invoked by the `git-identity-sessioncheck` SessionStart hook |
| `lint/check-claude-home.ps1` | gate: has a fixture written into the real `~/.claude` plugin administration? Reports the records naming a scratch tree and any marketplace clone they left behind, and keeps a snapshot of that administration while it reads healthy — so a clobber is restorable rather than merely re-installable | none — invoked by the `claude-home-sessioncheck` SessionStart hook |
| `lint/check-repo-settings.ps1` | advisory: does GitHub-side repo state still match what `scripts/repo-config.ps1` declares (`Get-ExpectedRepoSettings`) — a bypass actor, `allow_auto_merge`, which check is required? Reads and reports only, never writes to GitHub | none — invoked by a scheduled `repo-settings.yml` workflow (placed by `adopt-merge-queue`) and by a person running the one command in its `.SYNOPSIS` |
| `maintenance/fix-mojibake.ps1` | repairs encoding damage in the markdown the repo names | [`fix-mojibake`](../skills/fix-mojibake/SKILL.md) |
| `maintenance/measure-skill.ps1` | what a skill costs: token cost per skill and the wall-clock of the script it drives | [`measure-skill`](../skills/measure-skill/SKILL.md) |
| `maintenance/measure-always-on.ps1` | what the always-on document path costs — `CLAUDE.md` plus everything it `@`-imports — per document and per section | [`measure-skill`](../skills/measure-skill/SKILL.md) |
| `sync/check-script-contract.ps1` | read-only script-contract drift check | none — invoked by the `script-contract-sessioncheck` SessionStart hook |
| `lib/release-lib.ps1` | the pure release logic: version bump, changelog transformation, notes construction, `Test-ReleaseBumpEarned` | none — dot-sourced lib |
| `lib/entry-scaffold-lib.ps1` | the one definition of the entry format, read by the script that writes it and the gates that refuse it | none — dot-sourced lib |
| `lib/plugin-tree-lib.ps1` | which plugins this repo publishes and where each folder sits | none — dot-sourced lib |
| `lib/script-contract-lib.ps1` | the contract registry the check above reads | none — dot-sourced lib |
| `lib/pr-body-lib.ps1` | composes and refreshes the PR body from the entry | none — dot-sourced lib |
| `lib/pr-issues-lib.ps1` | reads the issues a PR declares it closes | none — dot-sourced lib |
| `lib/park-lib.ps1` | `Invoke-GitPark` — the one stage/commit/push behind both parking entry points | none — dot-sourced lib |
| `lib/closeout-lib.ps1` | `Write-CloseOutReceipt` — the close-out receipt shape: what happened, where to read it, whether the session can be cleared, and the clause a run that skipped a gate owes the PR body. Printed as the last line of four of the five scripts that end a work chain, and just above the hand-written-note reminder in the fifth (`cut-release.ps1`), so it is not read as the last item on a to-do list. A conductor that spawns another of them suppresses the child's copy, so one chain prints one receipt. The one thing here addressed to the READER of a run rather than to the run | none — dot-sourced lib |
| `lib/fanout-lib.ps1` | the working-copy snapshot and the whole shrinkage judgement as a pure function — `Get-WorkingCopySnapshot`, `Compare-WorkingCopySnapshot`, `Format-WorkingCopyShrinkage` | none — dot-sourced lib |
| `lib/command-guard-lib.ps1` | the false-positive machinery a `PreToolUse` command guard needs — `Get-HookCommandPayload` (the payload contract, and `agent_id` as the one field that says "dispatched subagent"), plus heredoc/here-string stripping, the segment split, the text-tool exemption and the interpreter-wrapper re-scan under `Get-GuardSegments`. Carries no knowledge of git or of any CLI, so a second guard can adopt it | none — dot-sourced lib |
| `lib/working-copy-guard-lib.ps1` | `Get-WorkingCopyViolation` — the whole working-copy judgement as a pure function: which git subcommand mutates the dispatching session's tree, index or refs, and which read-only sibling shares its verb. Split off from `hooks/guard-working-copy.ps1` so it can be tested and measured over a real command corpus without a payload and a process per case | none — dot-sourced lib |
| `lib/source-repo-guard-lib.ps1` | `Assert-OwnCopy` — refuses a released copy running in the repo that maintains it | none — dot-sourced lib |
| `lib/native-capture-lib.ps1` | `Invoke-NativeCapture`, the stderr-safe native-command wrapper | none — dot-sourced lib |
| `lib/check-report-lib.ps1` | the `[OK]`/`[INFO]`/`[ERROR]` report helper | none — dot-sourced lib |
| `lib/hook-check-lib.ps1` | `Invoke-CheckScript` — the in-process sibling of `native-capture-lib`: it runs a session check in the hook’s own interpreter instead of spawning a second one, which is the interpreter the harness had already paid for | none — dot-sourced lib |
| `lib/session-cache-lib.ps1` | the other half of the same cost: a verdict a SessionStart hook may compute ONCE per session instead of at every firing of the `startup|resume|clear|compact` matcher, keyed on the `session_id` the harness writes to the hook’s stdin | none — dot-sourced lib |
| `lib/measure-skill-lib.ps1` | the parsing/formatting half of `measure-skill.ps1`: turns `claude plugin details` output into figures, with no I/O of its own | none — dot-sourced lib |
| `lib/measure-context-lib.ps1` | the shared helpers for measuring the always-on document path: the `@`-import walk, the byte-exact section split, and the calibrated chars-per-token factor | none — dot-sourced lib |
| `lib/consumer-check-lib.ps1` | the two things every consumer-facing lint check opens with: which tree it is operating on, and which always-on documents it may read | none — dot-sourced lib |
| `lib/merged-pr-lib.ps1` | the merged-PR proof, as one source: was this ref merged, or only a branch that once wore its name? | none — dot-sourced lib |
| `lib/seam-lib.ps1` | `Get-SeamValue` — reads an optional repo-config seam, falling back to a default when the repo does not define one | none — dot-sourced lib |
| `lib/gate-lib.ps1` | records what the gates proved, against which exact working state, and notices when that state moved while they ran | none — dot-sourced lib |
| `lib/fetch-attempt-lib.ps1` | records which remote was fetched, at which scope and how it went, so two scripts meeting seconds apart do not each buy the same network call — and an unreachable one is not waited out twice | none — dot-sourced lib |
| `lib/remote-ahead-lib.ps1` | composes the "behind the remote" sentence a caller prints when a local ref has fallen behind its own remote-tracking ref | none — dot-sourced lib |
| `lib/worktree-lib.ps1` | reads `git worktree list --porcelain`: who holds which branch, and which tree is the primary one | none — dot-sourced lib |
| `lib/git-identity-lib.ps1` | the identity a checkout acts as on the tracker, the identity it commits as, and whether it can commit at all -- read once for every caller that needs one of them | none — dot-sourced lib |
| `lib/git-porcelain-lib.ps1` | the one reading of a git path: the `git status --porcelain` command with its two flags, the line parse into `{Path, Index, Worktree, From}`, and `Convert-GitQuotedPath`, which decodes git's C-quoted form. Dot-sourced by `park-lib` for its uncommitted count, by `fanout-lib` for its per-path snapshot, and — through a second mirror in `dkj-subagents-shopify` — by `sync-main` for the decoder | none — dot-sourced lib |
| `lib/claim-issue-lib.ps1` | the two decisions `claim-issue.ps1` makes: which account this checkout claims under, and whether the issue in front of it may be claimed at all | none — dot-sourced lib |
| `lib/ref-print-lib.ps1` | `Get-PasteableRef` — may this branch name go into a printed command a reader will run verbatim? Returns the placeholder and the explaining line when it may not, because git accepts shell metacharacters in a ref and no quoting closes that | none — dot-sourced lib |
| `lib/command-probe-lib.ps1` | `Test-FunctionDefined` — is a function of this name defined? Reads the function table directly, where `Get-Command` parses the name as a wildcard pattern and pays a full `PATH` scan on every miss — and a miss is the normal case for an optional seam | none — dot-sourced lib |
| `lib/document-newline-lib.ps1` | `Get-DocumentNewline` — the newline style a document is already written in, read off the document rather than assumed, so a block composed for it neither reads as drifted on a CRLF checkout nor leaves the page mixed. One definition for a reading that was hand-typed at nine sites (issue #1832); its banner carries the whole-file limit of it | none — dot-sourced lib |
<!-- /shared-scripts:mirror -->

## How the mirror works

1. **Dual-context repo root.** A shared script resolves its repo root as `${CLAUDE_PROJECT_DIR}` (for a
   consumer running the mirror) or the git root (workshop root / outside a session). This way the same
   file works in both locations and the mirror stays byte-identical.
2. **Repo data stays local.** The script reads its repo-specific bit from the **consumer's root**:
   `scripts/repo-config.ps1` (the seam) and `scripts/lib/branch-info.ps1` (branch/type derivation).
   `${CLAUDE_PLUGIN_ROOT}` resolves only within plugin-owned components, so that injection runs via
   `${CLAUDE_PROJECT_DIR}`, not via the plugin root.
3. **The consumer invokes via a skill** (`/fold-changelog`) that runs the script with
   `${CLAUDE_PLUGIN_ROOT}/scripts/release/…`. A skill is the only docs-confirmed mechanism that both a
   human and Claude can invoke (`bin/` is only on the Bash tool's PATH and is not directly invokable by
   a human).

To add a script to the shared set: register the pair (source → mirror) in
`scripts/lib/shared-scripts-lib.ps1`, run `scripts/sync/build-shared-scripts.ps1`, and add a skill if
needed.

## What deliberately stays in the consumer's root (cannot move here)

- Everything **CI** invokes from a bare checkout without a plugin cache (the lint gate, the test suites
  and their libs). CI does not see the plugin cache.
- **`branch-info.ps1` cannot move.** It is riveted to the root by two independent callers:
  `release-lib.ps1` dot-sources it (for the branch types, `Get-BranchTypes`) and runs in **CI** from a
  bare checkout — and the root scripts dot-source it. As long as `release-lib` depends on `branch-info`,
  moving it would break the CI gate.
- **`repo-config.ps1`** is by definition repo data (repo name, blob URL, the release seam) and belongs
  locally per repo. The `specialists-init` bootstrap places `repo-config.ps1` + `branch-info.ps1` as a
  `VUL-IN` scaffold, so that a clean consumer does not crash the shared skills on a missing file; the
  scripts moreover pre-flight on it
  ([#86](https://github.com/DaveKJohn/claude-code-specialists/issues/86)).

## Precedent

The plugin runs `hooks/connector-sessioncheck.ps1` via `hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}` in
every repo that enables **this** plugin, without registration in the consumer's `settings.json`. (It ran
in every consumer until August 8, 2026, when it moved out of the core team along with the rest of this
way of working — see the [connectors README](https://github.com/DKJ-Solutions/claude-code-specialists/blob/main/connectors/README.md).)
That hook mechanism is proven; the shared-scripts mirror + skill above extends that same SSOT principle
to standalone-invokable workflow scripts.
