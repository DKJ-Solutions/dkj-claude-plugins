# dkj-solutions — DKJ-Solutions' codex

The binding rules every DKJ-Solutions app shares, written once instead of rebuilt in each repo. It is
the counterpart of `bwj-development` (BWJ-Development's codex) for the other organisation: an
**additive** add-on to `dkj-policy` that contradicts nothing that workflow decides, and that carries
no specialists.

## Chapters

| Chapter | Where | What it holds |
|---|---|---|
| The house style | [`skills/house-style/`](skills/house-style/SKILL.md) | The canonical house style in [`assets/house-style/`](assets/house-style/) (the design tokens, the twelve themes, the base stylesheet and the rules), the skill with what a session needs before it fetches them, and the `check-house-style` gate that holds a repo to them |
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
(`startup`, `resume`, `clear`; not `compact`, which is mid-work) and does one thing: it starts the repo's
local dev server, or reuses the one already running, and hands the owner a clickable
`http://localhost:<port>/...` link, with the same line in the session's context. It replaced a
copy per repo in `dkj-brandbook`, `dkj-etf-tracker` and `life-hub`
([#2967](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2967)).

**The page it opens is the repo's `Repo hub`, in every repo** (the owner's term, October 16, 2026,
[#3064](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3064), called `Repo dashboard` until
`dkj-brandbook` v0.3.0, [#3097](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3097)): the
way to every page about this repo, in one place. The line opens with `Repo hub:`, the placeholder's
included, and a repo cannot choose another word. A `Name` a repo still states in `Get-DevPreview` is
ignored, so delete it at your next edit. "dev-preview" names the mechanism, which is why the hook's lines
about its own setup (skipped, config unreadable, a config it cannot run) still open with it.

**And it has one form, in every repo** (the owner's decision, October 16, 2026,
[#3066](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3066)): the one laid down in
[`assets/house-style/README.md`](assets/house-style/README.md), section "The Repo hub", the version
the [`house-style` skill](skills/house-style/SKILL.md) pins. The blocks, their order and the `h1` are fixed;
the slug, the lead, the lists, the facts and the data source are the repo's own. The placeholder below
follows that form too.

**Every DKJ-Solutions repo has a dev preview, and the placeholder is the floor** (decided October 15,
2026, [#3047](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3047), reversing #2967's
silent no-op). A repo states its own server with `Get-DevPreview` in its `scripts/repo-config.ps1`.
**A repo that states none gets a placeholder page**: a plugin-shipped server
([`scripts/preview/serve-placeholder.ps1`](scripts/preview/serve-placeholder.ps1)) on the first free port
from **4880 to 4889**, built on the house style, that names the repo and shows how to add a preview of
its own. It runs under the same rules as a repo's own server (loopback only, reused and never doubled), so
what a repo without a server pays is one small server per checkout. A `Get-DevPreview` that answers
nothing stays silent.

**To open it in VS Code's Simple Browser, route the range once** in the repo's `.vscode/settings.json`.
With a route for the port it got, the placeholder opens there by itself. Without one, the session-start
line names the route to add:

```json
"workbench.externalUriOpeners": {
    "localhost:4880": "simpleBrowser.open",
    "localhost:4881": "simpleBrowser.open"
}
```

List as many of the ten ports as the repo needs. A repo opened beside others takes a later port.

A repo with a server of its own states it like this:

```powershell
function Get-DevPreview {
    @{
        Command      = 'npm run dev -- --port {port} --strictPort'   # required; {port} is filled in
        Ports        = 5173..5180       # required: one port (1024-65535), or a list tried in order (at most 32)
        Path         = '/'              # optional: the URL path (default '/')
        Requires     = 'node_modules'   # optional: relative path(s) inside the repo that must exist first
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

### The general pages server

**Four pages are the same in every DKJ-Solutions repo, so the plugin serves them, not the repo**
(the owner's decision, October 18, 2026, [#3119](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3119)).
Beside the repo's own server the hook starts the plugin's
[`scripts/pages/serve-general-pages.ps1`](scripts/pages/serve-general-pages.ps1) on the first free port
from **4890 to 4899**, under the same rules as every server here: loopback only, reused and never doubled
(its `cmd.exe` names the checkout), started hidden and detached, with its output in
`%TEMP%\dev-preview-general-<repo>-<hash>.log`. The hook does **not wait** for it to listen: the line it
prints is the repo's own link, unchanged. Placeholder repos get it too. **The price is a second port per
checkout**, and a second origin: a theme picked on the repo's hub is picked again on these pages.
It is a PowerShell server whatever the repo's own server is, which is why a repo on Vite or Next.js gets
the same four pages without touching its server.

| Page | Reads, from the repo it was started in | When it is absent |
|---|---|---|
| `/artifacts` | `scripts/dashboard/artifacts.json`, on every request | The page says the file is not there |
| `/issues` | `gh issue list`, three calls (the open issues, and those opened and closed in the last 28 days), for `--repo <owner/name>` taken from the `origin` remote when it is on github.com, else for the repo `gh` finds in the working directory; kept for five minutes | A `gh` that fails or is missing is a warning on the page |
| `/release-notes` | `dkj-policy/releases/page/release-notes.html`, dressed in the house style on the way out | A plain 404 text saying it is not built |
| `/sessionstart` | The always-on path, measured in a child process (bounded at 60 s) by `always-on-budget-lib.ps1`, found in the repo's own `scripts/lib`, else in the plugin's source tree, else in the highest `dkj-policy` version in the plugin cache; kept for a minute | The reason it could not measure, on the page |

**Two things to know about what these pages read and who can read them.** `/sessionstart` runs a child
process that first dot-sources the repo's own `scripts/repo-config.ps1`, and the repo's own
`scripts/lib/always-on-budget-lib.ps1` where it has one: the same trust the dev-preview hook already gives
`scripts/repo-config.ps1`, so enable the plugin only in repos you own. And the pages are **unauthenticated on
loopback**: any process on the machine can read them, so a private repo's issue titles are readable by
every local process, not only by the browser of whoever started the session.

`/hub` (and `/`) send the visitor on to the repo's own hub, and every page's first crumb is that link. A hub
may instead **relay** these pages from its own origin with `Copy-LoopbackUpstream` (in
`scripts/lib/loopback-server-lib.ps1`) and link them by bare path (`Format-GeneralPagesCardHtml -SameOrigin`),
answering `/hub` itself. The pages then share the hub's `localStorage`, and with it the theme and width
choice under their key, `general-pages`. The source repo's own hub does this
([#3168](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3168)). The pages carry the repo's name, `owner/name` from the `origin` remote, else the folder's. Each issue links to
the `url` `gh` returned for it, and only when that is a GitHub issue link.

**How the two servers find each other: one state file per checkout**,
`%TEMP%\dkj-repo-hub-<folder>-<hash>.json`, which the hook writes at every session start:
`{ "root": "<repo root>", "hub": "<the repo hub's url>", "pages": "<http://localhost:489x, or empty>" }`.
The hash is the one the hook's log paths use (SHA1 of the lowercased root). A reader believes the file only
when `root` names its own checkout and each url is a plain `http://localhost:<port>` one, so the file is
never a way to send a hub's links elsewhere: `pages` is believed only on a port of 4890-4899. **An open port
does not say whose server it is** (two checkouts race for the same ports, and a stale file can name a port
another checkout has taken), so the server answers `/whoami` with the hash of the root it was started in,
and a hub links it only when that is its own root's hash. **A hub links the pages in a "General" card**: the
repo's own hub reads the file and asks `/whoami` on every request, as does the placeholder's. Where the file
is absent, or nothing answers as this checkout's within 500 ms, the card says the general pages server is not
running and starts at the next session start. A hook that ends before there is a hub (the repo's ports all
taken, a `Requires` path missing) **removes the state file** rather than leave last session's.
A repo's own server that cannot dot-source PowerShell (Vite, Next.js) reads the same file in its own
language, and a request for one of the four paths on the repo's own server is best answered with a redirect
to `<pages><path>`, as this repo's does; **this repo's server answers a short 404 text naming the general
pages server when no server answers as this checkout's.**

**Ports do not count toward "site", so the links between the two servers are same-site navigations.** The
Fetch Metadata check both plugin servers (and this repo's) apply refuses `cross-site` always, and `same-site`
unless it is a top-level `GET` navigation (`Sec-Fetch-Mode: navigate`): the hub's General link, the 303 hop
and the "Repo hub" crumb back are served, a same-site fetch or image request is not.

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
this repo's `Get-DevPreview` starts its `Repo hub`, whose own pages are the **connector dashboard** (every
repo registered under `connectors/` and what `check-connectors.ps1` reports for it), the specialists and
their context cost, the test-gate durations and the **Brandbook** (the house style's themes, tokens and
components, read from `assets/house-style/`,
[#3132](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3132)), served on `127.0.0.1` by `scripts/dashboard/serve-connector-dashboard.ps1` with the plugin's
own copy of the house style. The release notes, the SessionStart measurements, the Artifacts and the Issues are the
general pages above, which the hub's General card links, and `dev-pages-lib.ps1` reads the plugin's
`general-pages-lib.ps1` from this tree. That server
uses a `TcpListener` rather than an `HttpListener`: under the latter the socket belongs to `http.sys`
(PID 4), and the hook could never recognise the server as this checkout's.

The house style itself is maintained here, in `assets/house-style/`, since
[#3130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3130) (October 18, 2026) moved it in
from `dkj-brandbook`. A consuming repo asks for a change through an inbound issue on this repo.
