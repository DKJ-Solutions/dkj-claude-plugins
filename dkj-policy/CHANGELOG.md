# Changelog

## [Unreleased]

**5 / 8 minor entries** <!-- pending-tally -->

### DEPLOY: docs/3059-act-only-issue-closes · 20261016-104312Z

`bwj-development`'s ticket-handling page now says that an issue stays open only while it will still change
code in the repo ([#3059](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3059), Maikel,
October 16, 2026). An issue whose remaining work is only an act outside the repo (a release, a publish in
the Shopify admin, an owner's decision) closes as completed with a research block naming that act. The
page gives the test, "does any step still change a file in the repo?", and says to move a lone code step
into the issue that already carries the related code work. The core still parks such an issue under
`awaiting-action-dev`, and which of the two yields is filed as
[#3062](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3062). The same page's description of
the go-live guard's fail-open is brought in line with #3058.

**Score:** 2

#### What makes this deploy extra special

In a store repo running `bwj-development`, a session closes an issue whose only remaining step is a store
act or a release, with a research block naming that act, instead of parking it. The open issues and the
`In Progress` column then show only work that can still be built.

**Score:** 3

#### Pull Request

An issue stays open only while it will still change code

Plugins: bwj-development

[PR #3063](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3063)

---

### DEPLOY: fix/3058-guard-fail-open-visible · 20261016-102909Z

`guard-stale-paste-block` now tells the session when it let a command through unchecked
([#3058](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3058)). Each fail-open path used to
write its warning to stderr and exit 0, which Claude Code never shows the model, so a close with no go-live
block went through in smartwatchbanden#946 and nothing in the session said the check had been skipped.
The hook now prints PreToolUse JSON whenever something was not checked: `additionalContext` for the model,
and `permissionDecision: "ask"` when the unchecked command is a `gh issue close`, because a close has no
later check that can still stop it.

**Score:** 3

#### What makes this deploy extra special

In a store repo running `bwj-development`, a hand close of an Asana-linked issue that the guard could not
check now stops at a permission prompt that names the issue, instead of quietly posting the bare closed
line to the Asana task. A ship the guard could not check still runs, and the session is now told so.

**Score:** 3

#### Pull Request

guard-stale-paste-block makes a fail-open visible to the session

Plugins: bwj-development

[PR #3061](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3061)

---

### DEPLOY: fix/3056-one-retired-extension-repair · 20261016-101309Z

The repair for an enabled plugin id under a retired extension name (`dkj-policy-bwj`,
`dkj-policy-dkjs`) is now composed by one helper, `Get-RetiredExtensionRepair` in
`scripts/lib/claude-md-import-lib.ps1`
([#3056](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3056)).
`consumer-prose-sessioncheck`, `plugin-versions` and `update-plugins` had each written that sentence out
for themselves, so a change to the command in one would drift from the other two. The tests for all three
now assert the helper's sentence itself. The session check's warning also gains the settings step and the
repo's own marketplace name in place of a `<marketplace>` placeholder.

**Score:** 2

#### What makes this deploy extra special

A consumer still enabling a retired extension name sees the same repair as before, now worded alike in
all three places. Nothing changes in how they work.

**Score:** N/A

#### Pull Request

One helper composes the retired-extension repair

Plugins: bwj-development, dkj-policy

[PR #3060](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3060)

---

### DEPLOY: fix/3055-retired-plugin-id-in-update-tools · 20261016-095331Z

`update-plugins` and `plugin-versions` now recognise a retired plugin id
([#3055](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3055)). A checkout still enabling
`dkj-policy-bwj` or `dkj-policy-dkjs` (renamed in #2788) made `update-plugins` call
`claude plugin update` on a name the marketplace no longer declares and count it as `FAILED`, which
turned the whole checkout red in an `-AllCheckouts` sweep. The `plugin-versions` receipt printed at
the end of the run then advised a marketplace refresh that step 1 of the same run had just done. Now
`update-plugins` skips that id and names its successor, and `plugin-versions` reports it as `retired`
with the real repair: enable the successor and install it.

**Score:** 2

#### What makes this deploy extra special

An `update-plugins` run in a repo that has not migrated off a retired extension name no longer reports
failure. It names the one change that fixes it, instead of advising a refresh that cannot help.

**Score:** 1

#### Pull Request

update-plugins and plugin-versions recognise a retired plugin id

Plugins: dkj-policy

[PR #3057](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3057)

---

### DEPLOY: fix/3053-trusted-root-guard-exemption · 20261016-092814Z

`merge-on-green` can ship a PR in this repo again
([#3053](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3053)). The runner runs
`ship-pr.ps1` from a `trusted-main` checkout of the trunk while `CLAUDE_PROJECT_DIR` names `pr-branch`,
and the source-repo guard refused that as a released copy, because the two are separate clones and
`pr-branch` carries both the marketplace and its own copy. So PR #3051 sat green and armed through
every sweep. `-TrustedRoot` (and `open-pr`'s `-SeamRoot`) now declares that tree in
`DKJ_GUARD_TRUSTED_ROOT`, the guard exempts a script inside it, and the fold and
`verify-resolved-issues` children inherit the declaration. The plugin cache is still refused.

**Score:** 2

#### What makes this deploy extra special

A consumer has no marketplace, so the guard never refused it and nothing changes for it.

**Score:** N/A

#### Pull Request

merge-on-green can ship in the source repo: the own-copy guard exempts the declared trusted tree

Plugins: dkj-policy, dkj-subagents-shopify

[PR #3054](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3054)

---

### DEPLOY: fix/3049-update-plugins-conflicting-scopes · 20261015-214246Z

`update-plugins` now updates every install record a checkout holds for a plugin, at each scope those
records name ([#3049](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3049)). Where a
checkout's records disagreed on scope (a `project` and a `local` record side by side, a state a
session start can produce), the run fell back to one `--scope project` call and left the other record
behind, under `0 failed`, while its own receipt said `CONFLICTING`. A path-less `user` record beside
them was skipped as well. Now each scope gets its own `claude plugin update`, `managed` excepted, and the
disagreement is named before step 1.

**Score:** 2

#### What makes this deploy extra special

`update-plugins` no longer leaves a second copy of a plugin behind in a checkout that holds two install
records for it, so a session there stops loading the older version after a run that reported success.

**Score:** 2

#### Pull Request

update-plugins updates every disagreeing checkout record, one call per scope

Plugins: dkj-policy

[PR #3051](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3051)

---

### DEPLOY: fix/3038-connector-dashboard-test-windows · 20261015-201744Z

`connector-dashboard.tests.ps1` failed on loaded CI shards and passed on a rerun
([#3038](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3038)), first in group 3's page
asserts, then in group 2's stalled-connection assert. Its 3s read window held about a 3x margin over
the measured unloaded latency, so it now reads for 15s and waits up to 30s for the server to start. A
passing run costs nothing extra, and a stalling server still fails, because the stalling client stays
open until after its assert. Group 3 now asserts its start-up on its own, so a recurrence says which
window it overran.

**Score:** 1

#### What makes this deploy extra special

A test suite of this repo's own CI only; nothing a plugin user installs or runs changes.

**Score:** N/A

#### Pull Request

connector-dashboard tests: widen the read and start-up windows that a loaded CI runner overran

[PR #3052](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3052)

---

### DEPLOY: feat/update-plugins-all-checkouts · 20261015-192917Z

`update-plugins` takes a new `-AllCheckouts` switch that runs the update in every checkout on the
machine holding a plugin install record, in one command. The checkouts are read off
`~/.claude/plugins/installed_plugins.json`, so no folder list is kept. A checkout that is not on its
trunk, or that has uncommitted changes under `.claude/`, is skipped, so a mid-work branch is never
touched ([#1890](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1890)'s concern). Each
checkout is handed its own root explicitly, because a session's `CLAUDE_PROJECT_DIR` would otherwise
send every child run to the session's repo. Records whose folder is gone are counted in one line.

**Score:** 3

#### What makes this deploy extra special

Updating the plugins in every repo on a machine is now one command instead of one run per repo:
`update-plugins.ps1 -AllCheckouts`, or ask for "update all repos". Repos on a feature branch or with
uncommitted `.claude/` changes are skipped and listed, and `-DryRun` shows every command first.

**Score:** 3

#### Pull Request

update-plugins -AllCheckouts: update every checkout on this machine in one run

Plugins: dkj-policy

[PR #3050](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3050)

---

