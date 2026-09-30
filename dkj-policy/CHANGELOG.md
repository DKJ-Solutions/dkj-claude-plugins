# Changelog

## [Unreleased]

**1 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2647-dashboard-toml-backtick · 20260930-090915Z

`issue-dashboard.ps1 -EmitWorker` now writes a `wrangler.toml` that wrangler accepts. A PowerShell
escape had split one comment line and left a bare `px wrangler ...` line in the file. The suite now
checks every line of the emitted file, so this class of break is caught before the file reaches wrangler.

**Score:** 3

#### What makes this deploy extra special

The issue dashboard can now actually be deployed. Until now, a first `npx wrangler deploy` of the
dashboard stopped with `Invalid TOML document: illegal character in key`. A `wrangler.toml` written
by the old version stays broken, because the script never rewrites it. In that file, put `#` back at
the start of the line that begins with `px wrangler secret put`, or delete the file and re-run
`-EmitWorker`.

**Score:** 3

#### Pull Request

issue-dashboard writes a wrangler.toml that wrangler accepts

Plugins: dkj-policy

[PR #2648](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2648)

---

### DEPLOY: fix/2644-shared-stray-token-finder · 20260930-075243Z

The release-notes page and the issue dashboard now share one stray path-token finder
([#2644](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2644)), and neither script behaves
differently. The failure it prevents has not happened yet: a repair to the orphaned-token guard (#1444)
landing in one script and not the other.

**Score:** 1

#### What makes this deploy extra special

N/A -- nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

One shared stray path-token finder for the release-notes page and the issue dashboard

Plugins: dkj-policy

[PR #2646](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2646)

---

