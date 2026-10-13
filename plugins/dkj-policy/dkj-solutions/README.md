# dkj-solutions — DKJ-Solutions' codex

The binding rules every DKJ-Solutions app shares, written once instead of rebuilt in each repo. It is
the counterpart of `bwj-development` (BWJ-Development's codex) for the other organisation: an
**additive** add-on to `dkj-policy` that contradicts nothing that workflow decides, and that carries
no specialists.

## Chapters

| Chapter | Where | What it holds |
|---|---|---|
| The house style | [`skills/house-style/`](skills/house-style/SKILL.md) | A pointer to [DKJ-Solutions/dkj-brandbook](https://github.com/DKJ-Solutions/dkj-brandbook), which holds the design tokens, the twelve themes and the base stylesheet, plus the rules a session needs before it fetches them |

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
        Ports        = 5173..5180       # required: one port, or a list tried in order (at most 32)
        Path         = '/'              # optional: the URL path (default '/')
        Requires     = 'node_modules'   # optional: path(s) under the root that must exist before a start
        Name         = 'Showcase'       # optional: the word the line opens with (default 'dev-preview')
        WaitSeconds  = 20               # optional: how long to wait until it listens (1-45, default 20)
        OpenInVsCode = $false           # optional: also hand the URL to VS Code (see below)
    }
}
```

- **Bind to `127.0.0.1` in the `Command`** wherever the server shows something private, e.g.
  `python -m http.server {port} --bind 127.0.0.1` or `next dev -H 127.0.0.1 -p {port}`. The hook cannot
  know what a server exposes.
- **A running server is reused, never doubled.** A listener counts as this checkout's when its own
  command line, or one of its four nearest ancestors' command lines, names this checkout's root at a path
  boundary. The hook starts every server under a `cmd.exe` that changes into the root first, which is how
  a server whose own command line names no path is still recognised. A foreign app, another clone, a
  `worktree-lane` sibling or a Claude Code worktree under `.claude/worktrees/` is never mistaken for it:
  its port is skipped and the next one tried.
- **The server outlives the session.** It runs hidden and detached, logging to
  `%TEMP%\dev-preview-<repo>-<hash>.log`, and is stopped like any process.
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

The plugin is listed as `false` in this repo's `.claude/settings.json`: there is no app here that
renders anything.

The house style itself is maintained in `dkj-brandbook`. Only the skill's pointer is maintained here.
