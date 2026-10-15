# Changelog

## [Unreleased]

**1 / 1 minor entry** <!-- pending-tally -->

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

