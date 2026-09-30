# Changelog

## [Unreleased]

**3 / 4 minor entries** <!-- pending-tally -->

### DEPLOY: feat/dossier-parks-issue · 20260930-114905Z

A `dossier` issue is now parked like `needs-decision` and `awaiting-recurrence`. `sweep-issues` skips it,
`claim-issue <n>` warns that it is parked, and the issue dashboard shows it as Waiting.

**Score:** 2

#### What makes this deploy extra special

A repo that sweeps its issues no longer spends a pickup on a dossier that cannot be finished in one repair.

**Score:** 2

#### Pull Request


A dossier is parked, so the sweep and the claim skip it

Plugins: dkj-policy

[PR #2652](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2652)

---

### DEPLOY: feat/2649-dashboard-org-mode · 20260930-100945Z

The dashboard worker and `issue-dashboard.ps1` gain an org mode. The logic now keys issues on repo and
number, and its rows carry `repo`. `blocking` is now a list of `{number, repo}`, and nothing outside
the worker reads it. Repo mode's pages, order and output are unchanged, and the suite pins that.

**Score:** 3

#### What makes this deploy extra special

The issue dashboard can now cover a whole GitHub organization instead of one repository. Run
`issue-dashboard.ps1 -Org <login> -InitToken -EmitWorker` once per organization. Each organization gets
its own worker, token and directory, so several dashboards can be deployed from one checkout. A blocker
in another repository of the same organization now orders normally instead of sinking to the bottom.
Each organization needs a fine-grained PAT of its own, with that organization as resource owner. Setup
is in [the `issue-dashboard` skill](../plugins/dkj-policy/skills/issue-dashboard/SKILL.md).

**Score:** 3

#### Pull Request

The issue dashboard gains an org mode: one worker for every repo of a GitHub org

Plugins: dkj-policy

[PR #2650](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2650)

---

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

