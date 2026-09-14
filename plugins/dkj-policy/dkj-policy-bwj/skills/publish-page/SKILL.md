---
name: publish-page
description: >-
  Publish a built HTML page -- the release notes, or the minor backlog -- to the ONE Cloudflare
  Worker both BWJ store repos share, where it is served at an unguessable path. Use it after a page
  has been built, when a colleague outside the development work has to read something that lives as
  markdown in a private repository. The worker holds no page content of its own: the pages sit in
  KV, one key per kind and token, which is what lets two repos deploy the same worker without
  either one erasing the other's page. It publishes an existing file and never builds one, and it
  verifies by reading the bytes back rather than by believing the upload.
disable-model-invocation: true
---

# publish-page — the shared reading copy for both BWJ stores

**One Cloudflare Worker, two store repos.** `smartwatchbanden` and `xoxowildhearts` publish through
the same deployment, and this is the step that puts a page there.

## Why it exists, and why dkj-policy's worker could not be it

`dkj-policy` already ships a worker: `build-release-notes-page.ps1 -Worker` writes the page into
`worker.js` **as a literal** and names `npx wrangler deploy`. That is right for one repo and cannot be
shared by two — `wrangler deploy` replaces the whole script, so whichever store deploys last erases
the other store's page. Silently: both runs report success, and the loss is found by whoever opens a
link that used to work.

**So the shared worker carries no content at all.** The pages live in Cloudflare KV, one key per
`<kind>:<token>`, and the worker's whole job is to look one up. A redeploy from either store
re-uploads byte-identical code and cannot disturb what the other store published. That is what makes
"the same worker" a true statement rather than a race, and it is the property the suite in the source
repo (`scripts/tests/bwj-page-publish.tests.ps1`) exists to keep.

## What the skill does

Run the shared script from the **root of the store repo**:

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/publish-page.ps1" -Kind notes
```

It reads the built page out of the page directory, checks it against Cloudflare's KV value ceiling,
uploads it under this repo's own path token, **reads the value back and compares SHA-256**, and
prints the link.

**It does not build the page.** Building stays somebody else's step:

| kind | what it carries | who builds it |
|---|---|---|
| `notes` | the release notes for a reader outside the development work | `dkj-policy`'s `build-release-notes-page.ps1`, run **without** `-Worker` — it leaves `release-notes.html` in the page directory |
| `backlog` | the minor backlog — the open issues carrying the reach label, shown with their mirrored Asana tasks' colleague-facing text | [`build-backlog-page`](../build-backlog-page/SKILL.md) (issue #1979) — it leaves `minor-backlog.html` in the page directory |

Adding a third kind means adding it in **both** `scripts/lib/page-publish-rules.ps1` and
`worker/bwj-pages-worker.js`, then redeploying. A kind known to only one of the two publishes
successfully to a key nothing ever serves — a green run and a 404 somebody else finds. Nothing but
the suite holds those two files together, which is why it asserts they agree.

## The one-time setup

**1. Answer the seam** in the store's own `scripts/repo-config.ps1`:

```powershell
function Get-BwjPagesConfig {
    return @{
        Worker      = 'bwj-pages'
        AccountId   = '<32 hex>'
        NamespaceId = '<32 hex>'
        BaseUrl     = 'https://bwj-pages.<your subdomain>.workers.dev'
    }
}
```

**All four are the SAME in both store repos, and that identity is what "one worker" means.** They
are a seam rather than literals in the plugin for a reason that is not configurability: this plugin
ships from a **public** repository, and an account id, a namespace id and a workers.dev origin
written here would be published to everyone who can read the marketplace. A store repo is private,
so answered there they are not. That is the opposite of `Get-StorefrontMarkets` one folder over,
where the seam exists because the two stores genuinely differ.

**2. Create the KV namespace and deploy the worker, once, from either repo:**

```powershell
npx wrangler kv namespace create BWJ_PAGES     # the id goes into the seam above
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/publish-page.ps1" -EmitWorker
cd <note root>/../page
npx wrangler deploy
```

`-EmitWorker` copies the worker out of the plugin unchanged and writes a `wrangler.toml` **only when
one is absent** — after that the file is yours and is never overwritten, the same doctrine
`build-release-notes-page.ps1` states for its own. A name or a namespace id that has drifted from the
seam is **reported**, never corrected: which of the two is wrong is not the script's to decide, and
deploying the wrong name puts a *second* worker up, which is the one thing this design exists to
avoid.

**3. Mint a path token per kind:**

```powershell
... /publish-page.ps1 -Kind notes   -InitToken
... /publish-page.ps1 -Kind backlog -InitToken
```

## The path token is an input, never invented

The script **does not make one up** when the file is missing, and that refusal is the whole design:

> A token invented on the fly does not mean *"a new path"*. It means **every link you have already
> sent now 404s** — while the publish reports success.

`-InitToken` is the separate, explicit way to create the **first** one, and it refuses to replace an
existing token. A missing token is an error naming three ways back, in the order worth trying:
restore the 32 hex characters from the URL you have; read them off the namespace's key list in the
Cloudflare dashboard, which holds `<kind>:<token>` for every page ever published; and only once both
are exhausted, `-InitToken` for a fresh path.

**And here the token is also what separates the two stores.** Both repos answer the same four seam
values, so the token is the only thing that makes one store's URL not the other's — which is why
there is one per kind per repo, and why two stores can share a namespace without being able to reach
each other's pages by accident.

**Commit the token files.** A store repo is private, and a tracked token is what survives a lost
machine; without one, nothing anywhere remembers the URL. That is the opposite of the answer
`dkj-policy` gives its own token in a public repo, and it is the same rule read in a different
repository: the token is the lock, so it goes wherever only your people can read it.

**Which means `.gitignore` needs the exception written out, and the obvious spelling of it does not
work.** `release-notes-page` tells every consumer to ignore this whole directory — correctly, since
everything else in it is a derivative that dirties the tree on each release — so the tokens are
caught by that blanket rule unless you say otherwise:

```gitignore
releases/page/*
!releases/page/page-token-*.txt
```

**`releases/page/` followed by a negation does not work**, because git does not descend into an
excluded *directory* and never sees the file the exception names. It fails silently, which is the
worst shape this can take: the commit reports success, nothing is tracked, and the miss surfaces on
the machine that no longer has the file.

## The path is the only lock

The worker serves at `/<kind>/<32 hex>`. **There is no login: anyone with the link can read.** The
page carries `noindex` in the response header and in its own meta tag, because a link nobody can
guess is worth nothing once a crawler has published it.

Read that against what you are publishing. `dkj-policy` can point at its own notes being public in a
public repository, so there the path guards the route and not the content. **A BWJ store repo is
private, so here the path is guarding content that is not public anywhere else.** Publish only what
is safe in the hands of whoever receives the link.

Every miss answers the same 404 — a wrong kind, a wrong token, an unknown path, a key never written
— so nothing about the response says which stores publish, which kinds exist or which tokens are
live.

## The API token, and where it may not live

Read from the environment and from nowhere else:

```powershell
$env:CLOUDFLARE_API_TOKEN = '<a token with Workers KV Storage: Edit on this account>'
```

**There is deliberately no seam function for it.** A seam answer is committed by construction, and a
committed write token to a Cloudflare account is a different class of thing from an id that only
identifies one. It needs `Workers KV Storage: Edit` and nothing more — not Workers Scripts, which is
the deploy's permission and belongs to the person running `wrangler`, not to a publish.

## How you know it worked

The script **reads the value back out of KV and compares SHA-256** against the file it uploaded, and
fails naming both hashes when they differ. That is the automatable half of the lesson
`build-release-notes-page.ps1` states one layer up — *verify the bytes the URL serves, never the
deploy command's output* — and it settles the question the upload's `"success": true` cannot.

Two limits it does not pretend to cover:

- **KV is eventually consistent.** An edge that already held the previous page can go on serving it
  for up to a minute. A stale first read is therefore **not** a failed publish — the read-back has
  already settled that — so fetch again before concluding anything from one request.
- **It proves what KV holds, not what the URL serves.** Those are the same thing while the worker is
  deployed and bound to the namespace the seam names, which is exactly what `-EmitWorker`'s two
  drift warnings are about.

## Parameters

| parameter | what it does |
|---|---|
| `-Kind <notes\|backlog>` | which page. Defaults to `notes` |
| `-Html <path>` | the file to publish, instead of the kind's own default in the page directory |
| `-InitToken` | create this kind's path token when there is none; refuses to replace one |
| `-EmitWorker` | write `worker.js` and (only when absent) `wrangler.toml` for the one-time deploy |
| `-ShowUrl` | print this kind's link and stop |
| `-DryRun` | resolve the seam, read the page, name the key and the URL — upload nothing |
| `-RootOverride <path>` | the repo root, when the run does not start inside the checkout |

## Requirements in the store repo

- `scripts/repo-config.ps1` answering `Get-BwjPagesConfig`. **Required** — every other value here has
  a fallback and this one cannot: a default account id does not exist, and a default worker name
  would point a publish at somebody else's deployment, which is the one class of wrong value that is
  only discovered by the person who receives the link.
- `Get-ReleaseNoteRoot` (`dkj-policy`'s own seam) decides where the page directory sits:
  `<note root>/../page`, the same directory the release-notes builder already writes into. Derived
  rather than configured, because a second seam would be the same decision written twice.
- `node`/`npx` only for the namespace creation and the deploy, neither of which is this script's step.
- `CLOUDFLARE_API_TOKEN` in the environment for a publish. `-ShowUrl`, `-DryRun`, `-InitToken` and
  `-EmitWorker` need none.

## Important

- **It is not model-invocable**, deliberately, like `dkj-policy`'s `release-notes-page` beside it.
  Publishing is outward-facing: the content leaves the private repository and lands behind a link
  anyone holding it can read, so the line is typed by a person. The flag decides who types it, not
  whether it may run.
- **This script is maintained in the source repo**; do not modify it locally in a store. A change
  lands there first and then travels to both stores via a release, which is the whole point of it
  living in this plugin rather than being written twice.
