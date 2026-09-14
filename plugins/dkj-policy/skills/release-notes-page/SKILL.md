---
name: release-notes-page
description: >-
  Build the hand-written release notes into one browsable page -- a picker per release, the document
  rendered -- and, optionally, into a Cloudflare Worker that serves it at an unguessable path. Use
  this when the people a release is written for are not developers: the note is markdown in a
  repository, which is the right home for it and the wrong place to read it. The page is a SNAPSHOT,
  so it is rebuilt and redeployed after a release rather than following one. The script builds and
  never publishes -- `npx wrangler deploy` is a separate, deliberate step, because publishing is
  outward-facing. Needs no configuration to build the page; hosting needs two optional seam values.
disable-model-invocation: true
---

# release-notes-page — the reading copy of your release notes

This is the **plugin mirror** of `build-release-notes-page.ps1`: the same tested source as in the
source repo, shared here so consumers do not each write their own.

**Why it exists.** The hand-written note per release is the one release document written for somebody
*outside* the development work — management, a commissioner, a subscriber. It lives as markdown under
your note root, which is the right home for it and the wrong place to read it: that reader has to find
a directory, pick a version out of a filename, and read raw markdown in a code host. This turns the
same documents into one page they can open.

## What the skill does

Run the shared script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/build-release-notes-page.ps1"
```

**In the source repo, run its own copy instead — `scripts/release/build-release-notes-page.ps1`.**
`${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last *released* mirror and so
lags its own source by however many merges have landed since. The script refuses outright when it is a
released copy running in the repo that maintains it.

It reads:

- **the release list at `Get-ReleaseHistoryPath`** — for the order, the date, the type, the title and
  the live marker. Not the filenames under your note root: a directory listing knows none of those, and
  sorts `4.10.0` before `4.9.0`.
- **the note per release**, at `<Get-ReleaseNoteRoot>/<folder>/<X.Y.Z>.md`, where the folder shape is
  `Get-ReleaseNotesGrouping`'s answer (`4.x` or `4.11`).

A release with no note is skipped, and the report tells the two kinds of absence apart: one *inside*
the covered range is named (either a bump you write no note for, or a note nobody wrote — both are
answers you can check), while releases older than your first note are counted. Naming all of them
printed **seventy** versions when this was measured, which reads as a defect list and is history.

## Where the output goes, and why none of it is committed

A `page/` directory beside your note root — derived rather than configured, because the note root
already says where this repo keeps its release documents:

```text
<note root>/../page/
  release-notes.html      the page                        (generated)
  worker.js               the worker bundle, with -Worker  (generated)
  wrangler.toml           written ONCE, then yours
  worker-path-token.txt   the path token -- see below
```

**Add that directory to your `.gitignore`.** The page and the worker are derivatives of documents that
are already tracked, rebuildable in a second, and large enough that a tracked copy dirties the working
tree on every release — which is a problem, because `cut-release.ps1` refuses to run on a dirty tree.

**The token is the exception, and which way it goes depends on your repository.** In a **public** repo
it must stay out: the token *is* the lock (see below), so committing it publishes the key beside the
door — and the consequence is that nothing in git remembers your URL, so whoever creates it records it
elsewhere. In a **private** repo, commit it: a tracked token is what survives a lost machine, and it is
already inside a repository only your people can read.

**`wrangler.toml` is gitignored too, and unlike the page and the worker beside it, nothing can rebuild
what you put in it.** The script writes it only when it is absent and never again, precisely so an
account id, a custom domain or a route you added survives — but that promise cannot cover the write
itself, because there was nothing there to overwrite. Lose the page directory and the next `-Worker`
run hands you a freshly generated file carrying none of it. So the run **says so** whenever it writes
one, and the note is not evidence that anything went wrong: a first-ever deploy looks identical from
there, which is why it reports rather than refuses. Read it against what you had before you deploy.
Measured on issue #1479.

## Making it yours: four seam values, and one of them has a consequence outside your repo

All four live in your own `scripts/repo-config.ps1`, all four optional:

| function | what it answers | absent |
|---|---|---|
| `Get-ReleasePageTitle` | **whose** releases the page carries — the product's name, rather than the repository's and rather than what the page is. It is the masthead's eyebrow and half the window title; the heading is the template's own *Release notes*, so a title repeating those words prints them twice. The source repo's own answer did exactly that until it was read on the built page | falls back to the name half of `Get-RepoName` |
| `Get-ReleasePageTheme` | the page's colours — custom-property overrides, as a map | no overrides; the page keeps its shipped palette in light and dark |
| `Get-ReleasePageMasthead` | your own wordmark(s), above the title | no marks; the masthead is the eyebrow, the title and the subtitle |
| `Get-ReleasePageWorkerName` | the Cloudflare Worker that serves it | `''` — the page is built and hosted nowhere, and `-Worker` refuses while naming this function |

**The palette exists because this page often reports to people outside engineering**, and it then has to
look like the product it is about rather than like the tool that generated it. Answer it with the
overrides you want and nothing else:

```powershell
function Get-ReleasePageTheme {
    return @{
        '--accent'     = '#FF4F01'
        'color-scheme' = 'light'
    }
}
```

Three things to know before you write one:

- **`color-scheme` is accepted as a name**, alongside the `--custom-properties`. That is how a brand with
  no dark variant says so: pin `light` and the page keeps its colours on any background. Without it the
  seam could say *these colours* but not *no dark mode*.
- **The overrides are written after the dark-mode block**, so they beat both the light and the dark
  defaults. You do not need to restate a colour twice to make it stick.
- **Values are validated, not escaped**, because they land in a `<style>` element where escaping a `#`
  would stop it being a colour. Names must be `--something` or `color-scheme`; values may carry letters,
  digits, `#`, parentheses, commas, dots, percent, spaces and hyphens. Anything else — braces,
  semicolons, colons, quotes, angle brackets, comment markers, `url(` — is **dropped with a warning
  naming the key**, and the page is still built. So a typo costs one colour, never the report. A gradient
  or a web font is outside this seam by design.

### The masthead marks

`Get-ReleasePageMasthead` puts your own wordmark(s) above the title. It exists because a consumer whose
hand-edited page was replaced by this one lost the imagery it carried, and restyling the template in one
repo would fork the core's visual identity while leaving every other consumer without it.

```powershell
function Get-ReleasePageMasthead {
    return @(
        @{ Src = 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0i...'; Alt = 'Acme UK' },
        @{ Src = 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0i...'; Alt = 'Acme NL' }
    )
}
```

A bare `data:` string is accepted too, for the one-mark case. Four things to know:

- **Data-URIs only, and base64 only.** The page is deliberately self-contained — a request to a third
  party would leak who is reading it — so a URL is dropped with a named warning rather than fetched. A raw
  `data:image/svg+xml,<svg ...>` is refused for a second reason: that payload is markup inside an
  attribute, and not having to reason about whether the escaping is complete beats escaping it.
- **Three ceilings, all enforced with a warning and never with a build failure:** at most **two** marks,
  **32 KB** per mark, **64 KB** in total, measured as the length of the data URI, which is what the reader
  actually pays. A bad or oversized value costs that image and nothing else — the page is a reading copy
  of documents that are already correct, so refusing to build it over a logo would be the wrong trade.
- **Two, not five.** The cap is a measurement rather than a technical bound: the consumer this came from
  tried five and cut back to two, because five read as a page about the brands rather than about the
  releases.
- **`Alt` defaults to empty**, which is the correct answer for a mark beside a title that already names
  the product: an empty alt tells a screen reader the image is decorative, and inventing text would make
  it read the same fact twice. Pass `Alt` where the mark says something the title does not.

**Read this before answering the last one.** The worker serves the page at `/notes/<32 hex>`, and
**that path is the only lock on it**: there is no login, so anyone with the link can read. The page
carries `noindex` in both the response header and the meta tag, because a link nobody can guess is
worth nothing once a crawler has published it. Answer this only where the notes are safe in the hands
of whoever receives the link — in the source repo they already are, since that repository is public and
the notes are in it.

## The path token is an input, never invented

The script **does not make one up** when the file is missing, and that refusal is the whole design:

> A token invented on the fly does not mean *"a new path"*. It means **every link you have already sent
> now 404s** — while the build and the deploy both report success.

So a missing token is an error with a recovery instruction: restore the 32 hex characters from the URL
you have. `-InitToken` is the separate, explicit way to create the **first** one, and it refuses to
replace an existing token.

**And the way you actually lose it is a folder move.** The page directory is derived from your note
root and gitignored, which is two good decisions that meet badly: rename or repoint the folder holding
your release documents and every *tracked* file travels with it, while the token stays behind in a
directory nothing points at any more. `git mv` cannot see an ignored sibling by construction, so
nothing reports the miss — and what is left reads like rename debris, one `Remove-Item` away from
404ing every link you have sent.

So **both refusals ask whether a token exists anywhere in the tree, never whether one exists here**
(source repo issue #1444, September 5, 2026, after its own `contributing-davekjohn/` → `dkj-policy/`
rename left exactly that orphan). A copy found elsewhere is **named and never adopted** — the script
tells you which folder to move, because a token silently read from a path nobody configured would be a
second kind of surprise. `-InitToken` refuses on it too: its guard used to read the expected path
alone, which answers *"no token here"* on precisely the day that answer is wrong.

**Move that folder rather than rebuilding it.** Everything else in it regenerates in a second; the
token is the one file that cannot.

**And when there is no copy anywhere in the tree, the deployment is still one** — the step worth taking
before you conclude the URL is gone. The script writes the route into the bundle as a **literal**
(`const ROUTE = "/notes/<token>"`), so a worker that is still up *is* a copy of its own token, held by
Cloudflare rather than by any machine of yours: read it off the worker's code view in the dashboard, or
from the Workers script API, both of which return the deployed source. So the refusal names three ways
back, in the order worth trying — the URL you have, then the deployment, and only then `-InitToken` for
a fresh path.

That ordering was learned the expensive way (source repo issue #1453, September 5, 2026): a token that
was genuinely absent from every local path was read as *"every link already sent is unrecoverable"*,
which does not follow while the worker is up. **"The token is lost" and "the URL is lost" are different
findings**, and only the first one is answered by looking at your own disk.

## Publishing, and how to tell whether it worked

The script **deploys nothing**. It writes the bundle and names the command:

```powershell
cd <note root>/../page
npx wrangler deploy
```

**Verify a redeploy against the bytes the URL serves, never against the deploy command's output.**
Measured in the consumer this was ported from: once wrangler has created a deployment on a worker, an
API-side upload only creates **inactive versions** — with no error, while the live page stays the old
one.

**And fetch twice, because that check has a false negative of its own** (measured August 21, 2026, on the
`v4.18.0` redeploy in the source repo). Seconds after a `wrangler deploy` that reported success, the URL
answered **HTTP 200 with the old body** — 265 KB against the 352 KB just built, carrying none of the new
release's rows. A second request with `Cache-Control: no-cache` and a throwaway query string came back
**byte-identical to the built file**, and three plain fetches after that agreed. Nothing was wrong with the
deploy; the first read was a cached response.

That matters because of what the paragraph above tells you to conclude from exactly this observation. A
reader following it in good faith sees the old bytes, believes the documented silent-inactive-version
failure has just happened, and reaches for a second deploy — or worse, for `-InitToken`, on the theory that
the route is wrong. **So the check is: fetch, and if the bytes are stale, fetch again cache-busted before
believing it.** Compare against the built file with `cmp` rather than by eye — the honest question is
whether the served body *is* the file you built, and a size that merely looks plausible is how a
half-updated page passes.

**The ordering is the whole lesson: a stale read and a failed deploy are indistinguishable from one
request.** Both give a 200 and old content, and only one of them is a problem — so a single fetch cannot
tell you which you have, in either direction.

## It is a snapshot, not a mirror

The page is built from the files as they are at that moment and does not move with them. After a
release: **rebuild and redeploy**, in that order. Nothing reminds you — the page carries its build date
in the footer so a reader can see how current it is, which is the honest version of a guarantee nobody
can make.

## Parameters

| parameter | what it does |
|---|---|
| `-OutFile <path>` | where the page lands, instead of `release-notes.html` in the page directory |
| `-Worker` | also write `worker.js`, and `wrangler.toml` if it is not there yet |
| `-InitToken` | create the path token when there is none; refuses to replace one |

## Requirements in the consumer

- `scripts/repo-config.ps1` — **optional for the page**, like `new-branch`'s: every value it reads has
  a working fallback, and a repo without the file still gets a page. Required for `-Worker`, which
  needs `Get-ReleasePageWorkerName`.
- A release list at `Get-ReleaseHistoryPath` with at least one release whose note exists. Both are
  named in the error when they are not there.
- `node`/`npx` only for the deploy, which is not this script's step.

## Important

- **The page is generated, not edited.** If your notes are per-PR records that need summarising for
  their reader, that is a different, hand-written page — not a mode of this script. Here the note is
  already written for that reader, so summarising it again would be a second thing to keep true.
- **This script is maintained in the source repo**; do not modify it locally in the consumer.
  A change lands first in the source and then travels via a release to the plugin mirror, guarded by
  the shared-scripts drift lint. The page template beside it travels the same way.
