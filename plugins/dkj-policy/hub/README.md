# The Repo hub — the dev-preview hook and the general pages server

**Every repo that runs `dkj-policy` gets a Repo hub at session start**, with the General pages linked
from it: Artifacts, Issues, Release notes and SessionStart. That covers BWJ-Development's repos too.
Until [#3198](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3198) (the owner's decision,
October 20, 2026) all of this shipped with `dkj-solutions`, which BWJ-Development never enables, so a
General page reached only the DKJ-Solutions repos. **"General" means what every repo has, whichever
organisation it belongs to**, so the machinery moved here. Only the DKJ-Solutions card and its Brandbook
stay in [`dkj-solutions`](../dkj-solutions/README.md).

| Part | Where |
|---|---|
| The SessionStart hook | [`../hooks/dev-preview-sessionstart.ps1`](../hooks/dev-preview-sessionstart.ps1) |
| Its rules (the seam, the ports, the ownership rule, the state file) | [`lib/dev-preview-rules.ps1`](lib/dev-preview-rules.ps1), [`lib/general-pages-state.ps1`](lib/general-pages-state.ps1) |
| The placeholder | [`preview/serve-placeholder.ps1`](preview/serve-placeholder.ps1), its page in [`lib/dev-preview-placeholder.ps1`](lib/dev-preview-placeholder.ps1) |
| The general pages server | [`pages/serve-general-pages.ps1`](pages/serve-general-pages.ps1), its pages in [`lib/general-pages-lib.ps1`](lib/general-pages-lib.ps1) |
| The request rules both servers share | [`lib/loopback-server-lib.ps1`](lib/loopback-server-lib.ps1) |

These are plugin-only files, like [`../worker/`](../worker/): no root copy in the source repo mirrors
them. They are tested there by `dev-preview-sessionstart.tests.ps1`, `dev-pages.tests.ps1` and
`connector-dashboard.tests.ps1`.

## One look in every repo

**The pages render in the DKJ-Solutions house style everywhere, BWJ-Development's repos included.** They
are this plugin's own tooling, not a repo's product, so they keep one look wherever they run, the way any
tool's own screens do. The stylesheet and theme script come from the `dkj-solutions` folder inside this
plugin's payload (`Get-HouseStyleDir`, `dkj-solutions/assets/house-style/`). Every install of
`dkj-policy` carries that folder, whether or not the repo enables `dkj-solutions`. A repo's own pages are
another matter: BWJ-Development styles those itself.

**What a repo gets from enabling `dkj-solutions` is the DKJ-Solutions card**, after the General one, and
the Brandbook page it links. Both are read from `.claude/settings.json` and `.claude/settings.local.json`
(`Test-DkjSolutionsEnabled`; the local file wins where it names the plugin too) when each server starts.
Without it, `/brandbook` is a plain 404 and the hub shows the General card alone.

## The dev-preview hook

[`hooks/dev-preview-sessionstart.ps1`](../hooks/dev-preview-sessionstart.ps1) runs at session start
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
[`dkj-solutions/assets/house-style/README.md`](../dkj-solutions/assets/house-style/README.md), section
"The Repo hub". The blocks, their order and the `h1` are fixed; the slug, the lead, the lists, the facts and
the data source are the repo's own. The placeholder below follows that form too.

**Every repo has a dev preview, and the placeholder is the floor** (decided October 15, 2026,
[#3047](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3047), reversing #2967's silent no-op,
for the DKJ-Solutions repos then and for every repo since #3198). A repo states its own server with
`Get-DevPreview` in its `scripts/repo-config.ps1`. **A repo that states none gets a placeholder page**: a
plugin-shipped server ([`preview/serve-placeholder.ps1`](preview/serve-placeholder.ps1)) on the first free
port from **4880 to 4889**, built on the house style, that names the repo and shows how to add a preview of
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

## The general pages server

**Four pages are the same in every repo, so the plugin serves them, not the repo** (the owner's decision,
October 18, 2026, [#3119](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3119)). Beside the
repo's own server the hook starts [`pages/serve-general-pages.ps1`](pages/serve-general-pages.ps1) on the
first free port from **4890 to 4899**, under the same rules as every server here: loopback only, reused and
never doubled (its `cmd.exe` names the checkout), started hidden and detached, with its output in
`%TEMP%\dev-preview-general-<repo>-<hash>.log`. The hook does **not wait** for it to listen: the line it
prints is the repo's own link, unchanged. Placeholder repos get it too. **The price is a second port per
checkout**, and a second origin: a theme picked on the repo's hub is picked again on these pages.
It is a PowerShell server whatever the repo's own server is, which is why a repo on Vite or Next.js gets
the same four pages without touching its server.

**In a DKJ-Solutions repo it serves a fifth, the Brandbook, which is not a general page** (the owner's
split, October 20, 2026). The house style belongs to every DKJ-Solutions repo and to no other, so the page
is not one repo's own; but "General" means what *every* repo has, so it is not general either. A hub
therefore lists it in a third card, **DKJ-Solutions**, after General, and both the page and the card are
the `dkj-solutions` extension's ([`dkj-solutions-pages-lib.ps1`](../dkj-solutions/scripts/lib/dkj-solutions-pages-lib.ps1)).

| Page | Reads, from the repo it was started in | When it is absent |
|---|---|---|
| `/artifacts` | `scripts/dashboard/artifacts.json`, on every request | The page says the file is not there |
| `/brandbook` | Only where the repo enables `dkj-solutions`: the house style's themes, tokens and components, read from the `dkj-solutions/assets/house-style/` this server runs from, on every request; where the repo has a `brandbook/package.json`, a line naming `npm run dev` there | A plain 404 in a repo without `dkj-solutions`; a file that cannot be read is a warning on the page |
| `/issues` | `gh issue list`, three calls (the open issues, and those opened and closed in the last 28 days), for `--repo <owner/name>` taken from the `origin` remote when it is on github.com, else for the repo `gh` finds in the working directory; kept for five minutes | A `gh` that fails or is missing is a warning on the page |
| `/release-notes` | `dkj-policy/releases/page/release-notes.html`, dressed in the house style on the way out. Built first where it is absent or older than a file under `dkj-policy/releases`, by `build-release-notes-page.ps1` in a child process (bounded at 60 s), the repo's own copy else this plugin's: the page is a gitignored snapshot that nothing else builds (#3189) | A plain 404 text naming why it could not be built; where a rebuild fails, the older page is served |
| `/sessionstart` | The always-on path, measured in a child process (bounded at 60 s) by `always-on-budget-lib.ps1`, the repo's own copy else this plugin's; kept for a minute | The reason it could not measure, on the page |

**Two things to know about what these pages read and who can read them.** `/sessionstart` and
`/release-notes` run a child process that first dot-sources the repo's own `scripts/repo-config.ps1`, and
the repo's own `scripts/lib/always-on-budget-lib.ps1` or `scripts/release/build-release-notes-page.ps1`
where it has one: the same trust the dev-preview hook already gives
`scripts/repo-config.ps1`, so enable the plugin only in repos you own. And the pages are **unauthenticated on
loopback**: any process on the machine can read them, so a private repo's issue titles are readable by
every local process, not only by the browser of whoever started the session.

`/hub` (and `/`) send the visitor on to the repo's own hub, and every page's first crumb is that link. A hub
may instead **relay** these pages from its own origin with `Copy-LoopbackUpstream` (in
[`lib/loopback-server-lib.ps1`](lib/loopback-server-lib.ps1)) and link them by bare path
(`Format-GeneralPagesCardHtml -SameOrigin`), answering `/hub` itself. The pages then share the hub's
`localStorage`, and with it the theme and width choice under their key, `general-pages`. The source repo's
own hub does this ([#3168](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3168)). The pages
carry the repo's name, `owner/name` from the `origin` remote, else the folder's. Each issue links to the
`url` `gh` returned for it, and only when that is a GitHub issue link.

**How the two servers find each other: one state file per checkout**,
`%TEMP%\dkj-repo-hub-<folder>-<hash>.json`, which the hook writes at every session start:
`{ "root": "<repo root>", "hub": "<the repo hub's url>", "pages": "<http://localhost:489x, or empty>" }`.
The hash is the one the hook's log paths use (SHA1 of the lowercased root). A reader believes the file only
when `root` names its own checkout and each url is a plain `http://localhost:<port>` one, so the file is
never a way to send a hub's links elsewhere: `pages` is believed only on a port of 4890-4899. **An open port
does not say whose server it is** (two checkouts race for the same ports, and a stale file can name a port
another checkout has taken), so the server answers `/whoami` with the hash of the root it was started in,
and a hub links it only when that is its own root's hash. **A hub links the pages in the "General" card**
(`Format-GeneralPagesCardHtml`), and in a DKJ-Solutions repo in the "DKJ-Solutions" card after it
(`Format-DkjSolutionsPagesCardHtml`): the repo's own hub reads the file and asks `/whoami` on every request,
as does the placeholder's. Where the file is absent, or nothing answers as this checkout's within 500 ms,
each card says the general pages server is not running and starts at the next session start. A hook that
ends before there is a hub (the repo's ports all taken, a `Requires` path missing) **removes the state file**
rather than leave last session's.
A repo's own server that cannot dot-source PowerShell (Vite, Next.js) reads the same file in its own
language, and a request for one of the four paths on the repo's own server is best answered with a redirect
to `<pages><path>`; **the source repo's server answers a short 404 text naming the general pages server when
no server answers as this checkout's.**

**Ports do not count toward "site", so the links between the two servers are same-site navigations.** The
Fetch Metadata check both plugin servers (and the source repo's) apply refuses `cross-site` always, and
`same-site` unless it is a top-level `GET` navigation (`Sec-Fetch-Mode: navigate`): the hub's General link,
the 303 hop and the "Repo hub" crumb back are served, a same-site fetch or image request is not.

## In the source repo

This repo's `Get-DevPreview` starts its own `Repo hub`, whose pages are the **connector dashboard** (every
repo registered under `connectors/` and what `check-connectors.ps1` reports for it), the specialists and
their context cost and the test-gate durations. They are served on `127.0.0.1` by
`scripts/dashboard/serve-connector-dashboard.ps1` with the house style from this tree. The General pages
are the ones above, relayed through the hub, and `scripts/lib/dev-pages-lib.ps1` reads
`lib/general-pages-lib.ps1` and the DKJ-Solutions pages lib from this tree. That server uses a
`TcpListener` rather than an `HttpListener`: under the latter the socket belongs to `http.sys` (PID 4), and
the hook could never recognise the server as this checkout's.
