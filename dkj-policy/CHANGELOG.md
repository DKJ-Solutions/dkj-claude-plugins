# Changelog

## [Unreleased]

**0 / 1 patch entry** <!-- pending-tally -->

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

