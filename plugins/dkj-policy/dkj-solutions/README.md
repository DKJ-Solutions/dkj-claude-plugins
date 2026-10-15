# dkj-solutions — DKJ-Solutions' codex

The binding rules every DKJ-Solutions app shares, written once instead of rebuilt in each repo. It is
the counterpart of `bwj-development` (BWJ-Development's codex) for the other organisation: an
**additive** add-on to `dkj-policy` that contradicts nothing that workflow decides, and that carries
no specialists.

## Chapters

| Chapter | Where | What it holds |
|---|---|---|
| The house style | [`skills/house-style/`](skills/house-style/SKILL.md) | A pointer to [DKJ-Solutions/dkj-brandbook](https://github.com/DKJ-Solutions/dkj-brandbook), which holds the design tokens, the twelve themes and the base stylesheet, plus the rules a session needs before it fetches them, and the `check-house-style` gate that holds a repo to them |
| The tracker labels | [below](#the-tracker-labels--feature-and-bug-in-every-repo) | `feat/` is labelled `feature` and `fix/` `bug`, in every DKJ-Solutions repo, and how a repo still on `enhancement` moves over |

## The tracker labels — `feature` and `bug`, in every repo

**Every DKJ-Solutions repo labels a `feat/` pull request `feature` and a `fix/` one `bug`, and files its
issues under the same two names**, as the source tracker does (decided October 13, 2026,
[#2961](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2961)). An issue is always a
feature or a bug ([#2783](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2783)), and
`feature` is GitHub's default `enhancement` renamed
([#2764](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2764)). A `docs/` branch carries no
label. The name used to be left to each repo's own branch table, and the `specialists-init` scaffold
suggested `enhancement`, so the repos that copied it diverged from the source.

**A repo whose `scripts/lib/branch-info.ps1` still maps `feat` to `enhancement` moves over in two steps,
in this order.** `open-pr` refuses a label the tracker does not carry, so the tracker goes first:

1. Rename the label on the tracker. A rename keeps it on every issue and PR that already carries it:
   `gh label edit enhancement --name feature --color a2eeef --repo DKJ-Solutions/<repo>`
2. Then point the table at it, `feat = @{ Label = 'feature'; Type = 'Feat' }`, in the repo's own
   `scripts/lib/branch-info.ps1`, on an ordinary branch.

Measured on October 13, 2026, five repos needed it: `dkj-brandbook`, `dkj-etf-tracker`,
`djcylow-react`, `dkj-music-library` and `dkj-recipes`.

Beside its chapters, the plugin ships two SessionStart hooks (below). A hook is tooling the harness runs,
not a rule a session has to follow, so it is no chapter and `CLAUDE.md` does not name it.

## The house-style session check

[`hooks/house-style-sessioncheck.ps1`](hooks/house-style-sessioncheck.ps1) runs the `check-house-style`
gate at session start (`startup`, `resume`, `clear`) and reports what it finds: a vendored copy that is not
the pinned one, a redefined house token or class, a retired token name. It is read-only and never fails
the session. In a repo with no house style at all it prints one line saying there is nothing to check.
The gate itself, its allowlist and the CI caller are on the
[`house-style` skill page](skills/house-style/SKILL.md#the-gate-check-house-style)
([#3035](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3035)).

## The dev-preview hook

[`hooks/dev-preview-sessionstart.ps1`](hooks/dev-preview-sessionstart.ps1) runs at session start
(`startup`, `resume`, `clear`; not `compact`, which is mid-work) and does one thing for a repo that has
a local dev server: it starts that server, or reuses the one already running, and hands the owner a
clickable `http://localhost:<port>/...` link, with the same line in the session's context. It replaced a
copy per repo in `dkj-brandbook`, `dkj-etf-tracker` and `life-hub`
([#2967](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2967)).

**A repo opts in by stating `Get-DevPreview` in its `scripts/repo-config.ps1`.** Without it the hook
prints nothing at all.

```powershell
function Get-DevPreview {
    @{
        Command      = 'npm run dev -- --port {port} --strictPort'   # required; {port} is filled in
        Ports        = 5173..5180       # required: one port (1024-65535), or a list tried in order (at most 32)
        Path         = '/'              # optional: the URL path (default '/')
        Requires     = 'node_modules'   # optional: relative path(s) inside the repo that must exist first
        Name         = 'Showcase'       # optional: the word the line opens with (default 'dev-preview')
        WaitSeconds  = 20               # optional: how long to wait until it listens (1-45, default 20)
        OpenInVsCode = $false           # optional: also hand the URL to VS Code (see below)
    }
}
```

- **Trusted repos only.** The hook runs the repo's own `Command` at every session start, the same trust
  the repo's `scripts/repo-config.ps1` already gets from every hook that reads it. Enable this plugin only
  in repos you own.
- **The `Command` runs under `cmd.exe`:** it expands `%VAR%`, and where it chains commands with `&&` the
  log captures the last one's output only. A `Write-Host` in the config is harmless.
- **Bind to `127.0.0.1` in the `Command`** wherever the server shows something private, e.g.
  `python -m http.server {port} --bind 127.0.0.1` or `next dev -H 127.0.0.1 -p {port}`. The hook cannot
  know what a server exposes. A server you started by hand in the checkout is reused as well, without
  your `Command`, so when the `Command` names a loopback host and the reused server listens on every
  interface, the session-start line says `LISTENING ON ALL INTERFACES`. Restarting it is up to you.
- **A running server is reused, never doubled.** A listener counts as this checkout's when its own
  command line, or one of its four nearest ancestors' command lines, names this checkout's root at a path
  boundary. The hook starts every server under a `cmd.exe` that changes into the root first, which is how
  a server whose own command line names no path is still recognised. A foreign app, another clone, a
  `worktree-lane` lane (a sibling `<repo>-lanes/` folder) or a Claude Code worktree under `.claude/worktrees/` is never mistaken for it:
  its port is skipped and the next one tried.
- **The server outlives the session.** It runs hidden and detached, logging to
  `%TEMP%\dev-preview-<repo>-<hash>.log` (overwritten at each start, and holding whatever the server
  prints), and is stopped like any process. A server that exits at start is reported at once, with that
  log's path.
- **`OpenInVsCode`** runs `code --open-url <url>`, only when the session runs in VS Code's terminal. To
  land in VS Code's Simple Browser rather than the system browser, the repo also routes the URL with
  `workbench.externalUriOpeners` in its `.vscode/settings.json`.
- **It never fails the session.** Every path exits 0 with at most one line. It runs on Windows only, like
  the copies it replaced; elsewhere it prints nothing.

## Who enables it

**DKJ-Solutions repos only.** BWJ-Development has its own styling, so this plugin is never enabled in
BWJ's repos. It requires `dkj-subagents-alpha` and `dkj-policy`.

## Installing it in a DKJ-Solutions repo

1. Refresh the marketplace clone first (`claude plugin marketplace update dkj-claude-plugins`). A stale
   clone reports success with the previous version. Then enable the plugin in the repo's
   `.claude/settings.json` (`"dkj-solutions@dkj-claude-plugins": true`) and install it with
   `claude plugin install dkj-solutions@dkj-claude-plugins --scope project`.
2. Run the `adopt-dkj-policy` skill's Part 1 (`adopt-workflow-folder.ps1 -Apply`). It writes the
   extension import into the repo's `CLAUDE.md`, on the line directly below the `dkj-policy` import:
   `@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/dkj-solutions/CLAUDE.md`

That run writes the line for every `dkj-policy` extension the repo enables, so this plugin needs no
adopt step of its own. While the line is missing, the `consumer-prose-sessioncheck` hook warns at
session start ([#2697](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2697)).

## In this source repo

The plugin is enabled here since October 13, 2026
([#2976](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2976)), for the dev-preview hook:
this repo's `Get-DevPreview` starts the **connector dashboard**, a page with every repo registered under
`connectors/` and what `check-connectors.ps1` reports for it, served on `127.0.0.1` by
`scripts/dashboard/serve-connector-dashboard.ps1` with a vendored copy of the house style. That server
uses a `TcpListener` rather than an `HttpListener`: under the latter the socket belongs to `http.sys`
(PID 4), and the hook could never recognise the server as this checkout's.

The house style itself is maintained in `dkj-brandbook`. Only the skill's pointer is maintained here.
