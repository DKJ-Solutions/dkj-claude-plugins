# The hub — the dev-preview hook and the general pages server

**Every repo that runs `dkj-policy` gets a hub at session start**, served by the plugin, with the
General pages linked from it: Artifacts, Issues, Release notes and SessionStart. That covers
BWJ-Development's repos too. Until [#3198](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3198)
(the owner's decision, October 20, 2026) all of this shipped with `dkj-solutions`, which BWJ-Development
never enables, so a General page reached only the DKJ-Solutions repos. **"General" means what every repo
has, whichever organisation it belongs to**, so the machinery moved here. Only the DKJ-Solutions card and
its Brandbook stay in [`dkj-solutions`](../dkj-solutions/README.md).

| Part | Where |
|---|---|
| The SessionStart hook | [`../hooks/dev-preview-sessionstart.ps1`](../hooks/dev-preview-sessionstart.ps1) |
| Its rules (the seam, the ports, the ownership rule, the state file) | [`lib/dev-preview-rules.ps1`](lib/dev-preview-rules.ps1), [`lib/general-pages-state.ps1`](lib/general-pages-state.ps1) |
| The general pages server, which is the hub | [`pages/serve-general-pages.ps1`](pages/serve-general-pages.ps1), its pages in [`lib/general-pages-lib.ps1`](lib/general-pages-lib.ps1), the hub's page in [`lib/repo-hub-page.ps1`](lib/repo-hub-page.ps1) |
| The request rules the servers share | [`lib/loopback-server-lib.ps1`](lib/loopback-server-lib.ps1) |

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

**What a repo gets from enabling `dkj-solutions` is the home page's Brand book card** (#3270; one card in
the grid since #3383) and the Brandbook page it links. Both are read from `.claude/settings.json` and
`.claude/settings.local.json` (`Test-DkjSolutionsEnabled`; the local file wins where it names the plugin too)
when each server starts. Without it, `/brandbook` is a plain 404 and the home page has no Brand book card.

## The hub and the product

**The plugin serves the hub in every repo, whether or not the repo states `Get-DevPreview`** (the
owner's decision, October 21, 2026,
[#3245](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3245), replacing the placeholder of
[#3047](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3047)). The hub is the general pages
server itself, on the first free port from **4890 to 4899**, so the hub and its General pages share one
origin and one stored theme choice. A server a repo states in `Get-DevPreview` is its **product**: one
link on that hub, not the hub itself.

**The hub has one form, in every repo** (the owner's decision, October 16, 2026,
[#3066](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3066)): the one laid down in
[`dkj-solutions/assets/house-style/README.md`](../dkj-solutions/assets/house-style/README.md), section
"The hub": one page on `/`, under the site header (#3289, which ended #3270's separate About this repo
page; an old link to `/about` is sent to `/`), and since #3383 a grid of card links with a separate
**Repository** page. The blocks and their order are fixed. The site header names the repo, and under the
breadcrumb bar and the banner the home page carries one `.grid-3` of card links, with no heading above them:

- the **product**, where the repo states a server: its link, or a card saying it is not running;
- **Repository**, the page on `/repository` holding the facts (the GitHub repo where the `origin` remote is
  on github.com, the folder, the dev preview, where it is stated and who serves the hub) and a card for
  **Issues** and, on GitHub, for the pull requests and the CI runs;
- the **General** pages but Issues, by bare path;
- the **Brandbook**, where the repo enables `dkj-solutions`, by bare path.

Under the grid, only where the repo states no `Get-DevPreview` at all, two **setup cards**: how to add one,
and which port to route to VS Code's Simple Browser. A footer names the serving script.

Both pages are built per request from the state file below, and the repo's name, its `origin` slug and the
product url, the only values from outside, are HTML-escaped. The line the hook prints opens with `Hub:`, and a repo cannot
choose another word. A `Name` a repo still states in `Get-DevPreview` is ignored, so delete it at your next
edit. "dev-preview" names the mechanism, which is why the hook's lines about its own setup (skipped) still
open with it.

**A repo that wants a hub of its own opts out with `OwnHub = $true`** in `Get-DevPreview`. Its server is
then the hub, as it was before #3245: the line is `Hub: <its url>`, and the general pages server
still starts beside it and answers `/hub` and `/` with a 303 to that hub. This repo's connector dashboard
is such a hub, which relays the general pages from its own origin
([#3168](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3168)).

**A repo with its own hub can still state a product** beside it, with a nested `Product = @{ ... }` in
the same `Get-DevPreview` ([#3283](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3283)). The
`Product` takes the fields the server itself takes (`Command`, `Ports`, `Path`, `Requires`,
`WaitSeconds`), under the same rules, and its ports may not overlap the hub's. It is refused without
`OwnHub = $true`, because there the server itself is already the product. Any other fault in it costs the
product alone: the own hub still starts, and the line says `product not started: the Product: <why>`. This repo uses it: the
connector dashboard is the hub, and the brand book's Vite dev server is the product.

## The dev-preview hook

[`hooks/dev-preview-sessionstart.ps1`](../hooks/dev-preview-sessionstart.ps1) runs at session start
(`startup`, `resume`, `clear`; not `compact`, which is mid-work). It replaced a copy per repo in
`dkj-brandbook`, `dkj-etf-tracker` and `life-hub`
([#2967](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2967)). In order:

1. It reads `Get-DevPreview` from `scripts/repo-config.ps1`, then takes one snapshot of the listening sockets
   and the process table.
2. **It starts or reuses the hub first, before anything that can end the hook early** (the product's ports
   taken, a `Requires` path missing, a `%` or `^` in the repo root, a config that does not parse or cannot
   be read), so the General pages always run, also where the repo's own server cannot
   ([#3244](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3244)). Only the hub's own problems
   stop it: ports 4890-4899 all taken, a `%` or `^` in the plugin or repo path, a plugin install without
   the hub's libraries. The line then names that instead of a link.
3. Where the repo states a server and has not opted out, it reuses this checkout's product or starts the
   `Command` on the first free port, then waits until each server it started listens: **a dead link is worse
   than none.** Both waits run in one loop, so the common case costs the longer of the two, not their sum.
   The hub's own deadline is 12 seconds; the product's is `WaitSeconds`.
4. It writes the state file, and prints **one line**, which hands out both links:

| The repo | The line |
|---|---|
| states no `Get-DevPreview` (or one that answers nothing) | `Hub: http://localhost:4890/ (started) -- this repo states no Get-DevPreview yet; route localhost:4890 to simpleBrowser.open in .vscode/settings.json to open it in VS Code` |
| states a server | `Hub: http://localhost:4890/ -- product: http://localhost:4321/dkj-recipes/ (started)`; `(already running)` where it is reused |
| states a server that cannot start | `Hub: http://localhost:4890/ -- product not started: port 3000 taken by other processes: 3000 by dkj-lifehub (pid 19544)` |
| states `OwnHub = $true` | `Hub: http://localhost:4870/ (started)`, as before #3245 |
| states `OwnHub = $true` and a `Product` | `Hub: http://localhost:4870/ (started) -- product: http://localhost:5173/brandbook/ (started)` |
| and the hub cannot start | `Hub: not started -- <why>`, then the product's clause where there is one |

The route hint appears only where the repo states no server and does not route the hub's port; with the
route, the hub opens in VS Code by itself. Routing the port is done once in the repo's
`.vscode/settings.json`, and a repo opened beside others takes a later port, so list as many of the ten as
the repo needs:

```json
"workbench.externalUriOpeners": {
    "localhost:4890": "simpleBrowser.open",
    "localhost:4891": "simpleBrowser.open"
}
```

A repo with a server of its own states it like this:

```powershell
function Get-DevPreview {
    @{
        Command      = 'npm run dev -- --port {port} --strictPort'   # required; {port} is filled in
        Ports        = 5173..5180       # required: one port (1024-65535), or a list tried in order (at most 32)
        Path         = '/'              # optional: the URL path (default '/')
        Requires     = 'node_modules'   # optional: relative path(s) inside the repo that must exist first
        WaitSeconds  = 20               # optional: how long to wait until it listens (1-45, default 20)
        OpenInVsCode = $false           # optional: also hand the hub's URL to VS Code (see below)
        OwnHub       = $false           # optional: $true when this server IS the repo's hub (default: the plugin's)
        DefaultTheme = 'teal'           # optional: the theme the plugin's hub and general pages open in (default lilac)
    }
}
```

- **Trusted repos only.** The hook runs the repo's own `Command` at every session start, the same trust
  the repo's `scripts/repo-config.ps1` already gets from every hook that reads it. Enable this plugin only
  in repos you own.
- **`OwnHub` is a real boolean.** Anything else is a problem the line names, not a silent default.
- **`DefaultTheme` is the theme the plugin's pages open in while the visitor has picked none**
  ([#3390](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3390)): a house theme id, such as
  `teal`. A repo whose own product or hub opens in its own theme states it here, so the hub and the general
  pages it links do not open in another. Unstated, they keep lilac (#3162). It must have a theme id's shape
  (a lowercase letter, then lowercase letters, digits or hyphens); anything else is a problem the line
  names. It belongs to the hub alone, so a `Product` may not state it. The hook writes it into the state
  file, and the general pages server reads it per request, so a change reaches the next page after a
  session start without a restart.
- **The `Command` runs under `cmd.exe`:** it expands `%VAR%`, and where it chains commands with `&&` the
  log captures the last one's output only. A `Write-Host` in the config is harmless.
- **Bind to `127.0.0.1` in the `Command`** wherever the server shows something private, e.g.
  `python -m http.server {port} --bind 127.0.0.1` or `next dev -H 127.0.0.1 -p {port}`. The hook cannot
  know what a server exposes. A server you started by hand in the checkout is reused as well, without
  your `Command`, so when the `Command` names a loopback host and the reused server listens on every
  interface, the product's part of the line says `LISTENING ON ALL INTERFACES`. Restarting it is up to you.
- **A running server is reused, never doubled.** A listener counts as this checkout's when its own
  command line, or one of its four nearest ancestors' command lines, names this checkout's root at a path
  boundary. The hook starts every server under a `cmd.exe` that changes into the root first, which is how
  a server whose own command line names no path is still recognised. A foreign app, another clone, a
  `worktree-lane` lane (a sibling `<repo>-lanes/` folder) or a Claude Code worktree under `.claude/worktrees/` is never mistaken for it:
  its port is skipped and the next one tried.
- **The servers outlive the session.** They run hidden and detached, logging to
  `%TEMP%\dev-preview-<repo>-<hash>.log` (the product) and `%TEMP%\dev-preview-general-<repo>-<hash>.log`
  (the hub). Under `OwnHub` the first is the repo's own hub, and a product beside it logs to
  `%TEMP%\dev-preview-product-<repo>-<hash>.log`. Each log is overwritten when its server
  starts, and the servers are stopped like any process. A server that exits at start is reported at once,
  with that log's path. **The price of the hub is one small PowerShell server per
  checkout**, whatever the repo's own server is: a repo on Vite or Next.js gets the same pages without
  touching its server.
- **`OpenInVsCode`** runs `code --open-url <hub url>` (the repo's own server's under `OwnHub`), only when
  the session runs in VS Code's terminal. A repo that states no server needs no setting: it is on where the
  repo routes the hub's port. To land in VS Code's Simple Browser rather than the system browser, the
  repo routes the URL as above.
- **It never fails the session.** Every path exits 0 with at most one line. It runs on Windows only, like
  the copies it replaced; elsewhere it prints nothing.

## The general pages server

**Four pages are the same in every repo, so the plugin serves them, not the repo** (the owner's decision,
October 18, 2026, [#3119](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3119)).
[`pages/serve-general-pages.ps1`](pages/serve-general-pages.ps1) runs on the first free port from **4890 to
4899**, under the same rules as every server here: loopback only, reused and never doubled (its `cmd.exe`
names the checkout), started hidden and detached.

**In a DKJ-Solutions repo it serves a fifth, the Brandbook, which is not a general page** (the owner's
split, October 20, 2026). The house style belongs to every DKJ-Solutions repo and to no other, so the page
is not one repo's own; but "General" means what *every* repo has, so it is not general either. A hub
therefore lists it in a third card, **DKJ-Solutions**, after General, and both the page and the card are
the `dkj-solutions` extension's ([`dkj-solutions-pages-lib.ps1`](../dkj-solutions/scripts/lib/dkj-solutions-pages-lib.ps1)).
**The page is the source repo's `brandbook/` React app** (the owner's decision on
[#3210](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3210), October 20, 2026): its cut builds
the app and copies the build into `dkj-solutions/assets/brandbook/`, and this server serves that folder
under `/brandbook/`. The PowerShell Brandbook page it replaces is retired, so there is one brand book.

| Page | Reads, from the repo it was started in | When it is absent |
|---|---|---|
| `/`, `/index.html`, `/hub` | The state file below, on every request: the home page of this plugin's hub; `/about` answers 303 to `/` (#3289). Under `OwnHub` a 303 to the repo's own hub instead | Under `OwnHub` with no hub known, a short 404 text |
| `/repository` | The state file and the `origin` remote: the hub's Repository page, its facts and a card for Issues and, where the remote is on github.com, its pull requests and CI runs (#3383) | Always answers; with no github.com remote the facts carry no GitHub row and the page no GitHub cards |
| `/artifacts` | `scripts/dashboard/artifacts.json`, on every request | The page says the file is not there |
| `/brandbook/` | Only where the repo enables `dkj-solutions`: the brand book app's build in the `dkj-solutions/assets/brandbook/` this server runs from, its own routes answered with its `index.html`; `/brandbook` is a 303 to it | A plain 404 in a repo without `dkj-solutions`; a plugin copy that ships no build gets a page saying so |
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

Every page's first crumb is `/hub`, the hub on the same origin. A repo's own hub (`OwnHub`) may instead
**relay** these pages from its own origin with `Copy-LoopbackUpstream` (in
[`lib/loopback-server-lib.ps1`](lib/loopback-server-lib.ps1)) and link them by bare path
(`Format-GeneralPagesCardHtml -SameOrigin`), answering `/hub` itself. The pages then share that hub's
`localStorage`, and with it the theme and width choice under their key, `general-pages`. The source repo's
own hub does this ([#3168](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3168)). The pages
carry the repo's name, `owner/name` from the `origin` remote, else the folder's. Each issue links to the
`url` `gh` returned for it, and only when that is a GitHub issue link.

**How the servers find each other: one state file per checkout**,
`%TEMP%\dkj-repo-hub-<folder>-<hash>.json`, which the hook writes at every session start, whatever it found:

```json
{ "root": "<repo root>", "hub": "<url>", "pages": "<http://localhost:489x, or empty>", "product": "<url, or empty>", "mode": "none|product|ownhub" }
```

`mode` is what the repo states: `none` (no `Get-DevPreview`, so the hub shows the setup cards), `product`
(a server of its own, one link on the plugin's hub) or `ownhub` (the repo opted out). `hub` is the general
server's own base plus `/` where the plugin serves the hub, and the repo's own server where it opted out;
`product` is the repo's own server url, and under `ownhub` the url of the product beside that hub, or empty
where it states none (#3283). The hash is the one the hook's log paths use (SHA1 of the lowercased
root). A reader believes the file only when `root` names its own checkout. `hub` and `product` are believed
only as `http://localhost:<port>` plus an optional path of the characters `Path` allows (at most 240
characters: no other host, no other scheme, no control character), `pages` only on a port of 4890-4899, and
`mode` only as one of its three words, so the file is never a way to send a link elsewhere. A file written
before #3245 has no `mode` and no `product`, and reads as `none`.

**An open port does not say whose server it is** (two checkouts race for the same ports, and a stale file
can name a port another checkout has taken), so the server answers `/whoami` with the hash of the root it
was started in, and a repo's own hub links it only when that is its own root's hash
(`Get-GeneralPagesUrl`). A repo's own hub that is not PowerShell (Vite, Next.js) reads the same file in its
own language; a request for one of the four paths on its own server is best answered with a redirect to
`<pages><path>`, and the source repo's server answers a short 404 text naming the general pages server when
no server answers as this checkout's.

**Ports do not count toward "site", so the links between the servers are same-site navigations.** The
Fetch Metadata check both plugin servers (and the source repo's) apply refuses `cross-site` always, and
`same-site` unless it is a top-level `GET` navigation (`Sec-Fetch-Mode: navigate`): the product's link on
the hub and the 303 to an opted-out repo's hub are served, a same-site fetch or image request is not.

**After updating the plugin from a version before #3245:** a general pages server that the old plugin
started is reused until it exits, and it answers `/` with its old 303 or 404 until then. Stop it (or restart
the machine) once. And a product's `Ports` must not overlap 4890-4899, which the hub takes first.

## In the source repo

This repo's `Get-DevPreview` states `OwnHub = $true`: its own hub, whose pages are the **connector
dashboard** (every repo registered under `connectors/` and what `check-connectors.ps1` reports for it), the
specialists and their context cost and the test-gate durations, is served on `127.0.0.1` by
`scripts/dashboard/serve-connector-dashboard.ps1` with the house style from this tree. The General pages
are the ones above, relayed through that hub, and `scripts/lib/dev-pages-lib.ps1` reads
`lib/general-pages-lib.ps1` and the DKJ-Solutions pages lib from this tree. That server uses a
`TcpListener` rather than an `HttpListener`: under the latter the socket belongs to `http.sys` (PID 4), and
the hook could never recognise the server as this checkout's.
