# Changelog

## [Unreleased]

**1 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: fix/3619-merge-on-green-actions-read · 20261028-160541Z

The merge-on-green runner that `adopt-ci-floor` places now also grants its job token `actions: read`
([#3619](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3619)). `checks: read` and `statuses: read`
(#3491) were not enough: `gh pr checks --required` also reads the workflow run behind each check run, so a
private repo's picker still could not read its required checks and still merged nothing. A re-run of
`adopt-ci-floor` now names a runner without the scope under `[scope]`. When the required-check read
fails, the picker now prints the first line of the error instead of only "could not be read".

**Score:** 3

#### What makes this deploy extra special

In a private repo, merge-when-green had still never merged anything, and this release is the one that fixes it.
Add `actions: read` under `permissions:` in `.github/workflows/merge-on-green.yml`, or delete that file and run
`adopt-ci-floor -Apply` again. A re-run of `adopt-ci-floor` tells you whether your runner needs it.

**Score:** 3

#### Pull Request

merge-on-green: the job token also reads actions, so a private repo's picker can read its required checks

Plugins: dkj-policy

[PR #3624](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3624)

---

### DEPLOY: fix/3620-suite-servers-owner-watch · 20261028-155416Z

A hub server that a test suite starts through the dev-preview hook is now stopped once that suite's process
has ended ([#3620](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3620)). The suite sets
`DKJ_DEV_PREVIEW_OWNER_PID` to its own pid, and `dev-preview-watch` stops the server's tree when that process
is gone. Until now a killed gate never reached the suite's own cleanup, and one kill left 26 servers and
watchers holding about 2.3 GB. A real session never sets the variable, so its hub still outlives the session
for the next one to reuse.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

a hub server a test suite starts is stopped when that suite's process ends, even when the gate was killed

Plugins: dkj-policy

[PR #3625](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3625)

---

