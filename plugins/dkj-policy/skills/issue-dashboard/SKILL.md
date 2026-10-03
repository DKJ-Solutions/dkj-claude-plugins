---
name: issue-dashboard
description: >-
  OPTIONAL. Set up a live dashboard of this repo's open GitHub issues, or of every repo of one GitHub
  organization, on a Cloudflare Worker -- each issue with a status (In review, In progress, Waiting,
  Blocked, Claimed, Filed) and a pick-up order derived from its blocked-by dependencies, served at an
  unguessable path. Needs a Cloudflare account and
  node/npx; a repo that does not want it never runs it. The script creates the path token and the worker
  bundle and PRINTS the wrangler commands -- it deploys nothing and never sees a secret.
disable-model-invocation: true
---

# issue-dashboard -- a live view of the open issues

This is the **plugin mirror** of `issue-dashboard.ps1`: the same tested source as in the source repo.
**Optional by design**: nothing else in the workflow depends on it, and it costs a Cloudflare account.

**Why it exists.** The tracker lists issues; it does not say which are being worked, which wait on a
decision, or which to take next. This renders that from the tracker itself, live, for whoever holds the
link -- and the worker holds no content, so there is nothing to rebuild after a release.

## What you need first

- A **Cloudflare account** (the free plan is enough) and **node/npx** for `wrangler`.
- A **fine-grained personal access token** for `GITHUB_TOKEN`, scoped to **this one repository** with
  exactly: Issues (read), Pull requests (read), Contents (read), Metadata (read). Nothing that writes.
  An org dashboard needs a PAT whose **resource owner is that organization**, with access to the
  repositories the page should show (all of them, or a selection -- see the lock section below) and the
  same four read permissions. A fine-grained PAT has exactly one resource owner,
  so every organization needs a PAT of its own.
- **Logged in to the right Cloudflare account.** wrangler deploys to whichever account it is logged in
  to. Where your dashboards belong to different Cloudflare accounts, check `npx wrangler whoami` before
  every deploy, and switch with `npx wrangler logout` / `npx wrangler login`. Run these commands in your
  own terminal: `wrangler login` and `wrangler secret put` prompt interactively.

## Setup

Run from the **root of the consuming repo** (in the source repo, run its own `scripts/task/issue-dashboard.ps1`
instead -- `${CLAUDE_PLUGIN_ROOT}` resolves into the cache, which lags the source, and the script refuses
to run as a released copy in the source repo.):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/issue-dashboard.ps1" -InitToken -EmitWorker
```

For a dashboard over a whole organization, add `-Org <login>`, once per organization:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/issue-dashboard.ps1" -Org <login> -InitToken -EmitWorker
```

It writes into **`dkj-policy/dashboard/`** (or `dkj-policy/dashboard/org-<login>/` with `-Org`) (add `/dkj-policy/dashboard/` to your `.gitignore`; the source
repo already has it), then **prints**, for you to run from that directory:

```powershell
cd <repo>/dkj-policy/dashboard
npx wrangler secret put GITHUB_TOKEN      # paste the PAT at the prompt
npx wrangler secret put DASHBOARD_TOKEN   # paste the contents of dashboard-path-token.txt at the prompt
npx wrangler deploy
```

**On Windows it prints `npx.cmd` instead of `npx`**, and every `npx` on this page reads that way there:
in PowerShell `npx` resolves to node's `npx.ps1` shim, which the default execution policy refuses to
load, while `npx.cmd` beside it is not subject to the policy (#2651).

It also prints the URL **shape** `https://<name>.<your-subdomain>.workers.dev/issues/<contents of dashboard-path-token.txt>`.
The full URL is deliberately **not printed** (terminal output lands in transcripts and logs); the file content
is the only lock, so never paste it into a chat or an issue. **Never run wrangler from
the repository root** (issue #2581): it finds no `wrangler.toml` there and deploys or asks about the
wrong thing. The script warns if a `wrangler.toml` stands at the root.

## Parameters

| parameter | what it does |
|---|---|
| `-InitToken` | create the 32-hex path token in `dkj-policy/dashboard/dashboard-path-token.txt`; refuses to replace one, and refuses when a token stands anywhere else in the tree, and refuses when the file is not gitignored (`git check-ignore -q`; add `/dkj-policy/dashboard/` to `.gitignore`), only warning where git cannot answer |
| `-EmitWorker` | copy the two worker files from the plugin, write `wrangler.toml` if it is absent, and print the secret and deploy commands; needs the token, and refuses likewise when the token file is not gitignored |
| `-Org <login>` | org mode: prepare a dashboard over **every repository of that organization** instead of this repo, in `dkj-policy/dashboard/org-<login>/` with its own token and `wrangler.toml` (`[vars] GITHUB_ORG`, worker `<login>-issue-dashboard`). Combine with `-InitToken` and `-EmitWorker` as above; several org dashboards and this repo's can stand side by side |
| `-RepoRoot <path>` | test seam -- the repo root to work in instead of the one git names; a consumer never types it |

## What is written, and what is yours

```text
dkj-policy/dashboard/
  dashboard-path-token.txt        the path token (written once, never replaced)
  issue-dashboard-worker.js       copied from the plugin, overwritten each run
  issue-dashboard-logic.js        copied from the plugin, overwritten each run
  wrangler.toml                   written ONCE, then yours: name, main, [vars] GITHUB_REPO
  org-<login>/                    the same four files for an -Org dashboard, [vars] GITHUB_ORG
```

`wrangler.toml` is never rewritten; a `name` or `GITHUB_REPO` that has drifted from what the script would
write is **warned about, not corrected**. `wrangler.toml` carries `[observability] enabled = false`: request
URLs contain the token, and Workers Logs would record them. An absent one is reported too -- it may mean the gitignored
directory was rebuilt from nothing, and whatever you had added (an account id, a route) is not in the
fresh file. After a plugin update, re-run `-EmitWorker` and `npx wrangler deploy` to refresh the worker.

**The optional seam** `Get-IssueDashboardWorkerName` in your `scripts/repo-config.ps1` names the worker;
absent, it is `<repo name>-issue-dashboard`. `GITHUB_REPO` comes from `Get-RepoName`, else `gh repo view`.

## The path token is the only lock

The worker answers `GET|HEAD /issues/<token>` and gives every other request the same 404; there is no
login, so **anyone holding the link reads your open issues**. Do not use it where issue titles must stay
private from link holders. The response carries `noindex` and `no-store`. The token is also set as the
`DASHBOARD_TOKEN` secret, which cannot be read back from Cloudflare -- keep the token file and record the
URL. A missing token is an error, never silently replaced: a fresh one 404s every link already sent.

**An org dashboard is a wider disclosure.** Its link shows the open issues of **every repository the PAT
can read**, private ones included: titles, labels, assignee logins, blocker links and PR numbers. What
it shows follows the PAT, not any setting here. A PAT on "all repositories" therefore also shows a
private repository created later. Where only some repositories belong on the page, give the PAT
**only those repositories**. The worker lists what the token can see, so that choice is the scope.

## What it never does

- Deploy, publish, or run `wrangler` -- it prints the commands.
- Read, write or print a secret. The PAT and the `DASHBOARD_TOKEN` value are pasted at wrangler's prompt,
  not put on a command line.
- Change anything on GitHub. The token is read-only and the worker only reads.
- Overwrite the path token or an existing `wrangler.toml`.

## Status and order, in short

Status is the first match of: **In review** (an open non-draft PR closes it), **In progress** (a draft PR,
or a `<prefix>/<n>-` branch under `feat/`, `fix/`, `docs/`), **Waiting** (label `awaiting-more-info`,
`awaiting-decision`, `awaiting-first-recurrence` or `awaiting-more-recurrences`, or any former name: `needs-info`, `needs-decision`,
`awaiting-recurrence`, `record`, `dossier`), **Blocked** (an open `blockedBy`), **Claimed** (an assignee),
**Filed**. Order is topological over open in-repo blockers, ties by issue number; priority labels and age
do not order. An open blocker outside the repo sinks an issue, and any issue behind a sunk one, below every issue without one; a cycle is
flagged on the page and broken by issue number; a truncated GitHub connection is reported, never dropped.
**The page itself lists the issues newest first** (by creation date, ties by the higher number), each led by its issue number, and it answers the sweep question per row (Dave, September 30, 2026): only a Filed issue is sweepable, and every other row is **tinted red**, with a tooltip saying what it waits on (in review, in progress, the parking label, its open blockers, or who claimed it). The counts are Sweepable and Skip. A sweep claim-tag comment is not read, so an issue a sweep has just tagged reads as sweepable until it is assigned or gets a branch. The pick-up order above still decides the cycle and circular-chain warnings. The rules are `issue-dashboard-logic.js` (`deriveDashboard`), copied into `dkj-policy/dashboard/` -- read it
for the exact semantics.

**In org mode** the worker lists the organization's non-archived repositories that have issues enabled
and that the token can read, then reads them in batches. An issue is identified by its repo **and** its
number, so a blocker in another repo of the same organization orders normally instead of sinking. Ties
go by issue number, then by repo name. Each row leads with its issue number and shows its repo name beside the title. The request budget is 40 GitHub
requests per refresh (under the free plan's 50 subrequests), and a list cut short by it is reported on
the page.

## Important

- **This script is maintained in the source repo**; do not modify it locally. A change lands there first
  and reaches the plugin mirror via a release. The two worker files travel with the plugin.
