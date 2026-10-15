# Changelog

## [Unreleased]

**1 / 2 minor entries** <!-- pending-tally -->

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

