## feat/3168-hub-proxies-general-pages

> **How this file is read.** A step is `- [ ]` until it is resolved -- `- [x]` done, or
> `- [~]` dropped with the reason, which exists so nobody ticks a box for work they did not do.
> open-pr and ship-pr both refuse while one is still open, and there is no `-Force`.
>
> **FOUR `###` HEADINGS, AND NEVER A FIFTH** -- PLAN, CREATE, TEST, DEPLOY are the whole top
> level. A section needing its own heading goes in as a `####` UNDER whichever of the four owns
> it. No gate in YOUR repo reads a heading, so this half is on you -- only the repo that authors
> this workflow refuses a fifth (Dave, August 26, 2026).
>
> **AND NOTHING BRANCH-SPECIFIC ABOVE THE FIRST OF THOSE FOUR HEADINGS** -- everything between the
> title and it is this guidance, which is identical in every branch document. A status line, a note about
> THIS branch or an instruction to a session belongs under one of the four, normally as a `####`
> in PLAN. THIS half open-pr refuses, in every repo, before the push -- it reads the shape, so a
> guidance block in your own language passes and your own paragraph here does not (Dave,
> August 26, 2026; refused since #1650).
>
> **DEPLOY takes no steps of its own, and it is WRITTEN LAST** -- it is what the branch DID, once
> TEST says so. Written while steps above it are still open it states an INTENTION, and no gate
> holds it against what landed: the step gate splits this file at that heading and counts only
> above it. The PR title is the one exception -- new-branch -Title writes it at creation, because
> open-pr composes the PR title from it. It is the one part of this file that travels verbatim
> into `CHANGELOG.md` at the merge. In each tier, write the reason
> ABOVE the Score line -- anything below it is discarded.
>
> Relative links in that text resolve FROM THIS DIRECTORY -- `CHANGELOG.md` sits here too, so
> write each path exactly as it reads in this file.
>
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

#3168, as the owner decided it on October 19, 2026: the repo hub relays the four general routes from the
dkj-solutions general pages server instead of a 303, and hub and general pages share one theme key, so one
choice holds on every page. The key is `general-pages`, the one the plugin's pages already carry in every
repo: the hub's own pages move to it, which drops only this machine's stored hub choice once, where the
reverse would drop the general pages' choice in every consumer.

A visible result, so it is parked for the owner's look, with no PR.

### CREATE

- [x] `loopback-server-lib.ps1`: `Copy-LoopbackUpstream` relays one request to a loopback port and writes
  its whole answer back as it came, or returns `$false` with nothing written
- [x] `serve-connector-dashboard.ps1`: the four general routes and `/refresh?page=issues|sessionstart` are
  relayed (a 502 when the server stops answering mid-request, the 404 text as before when none is known);
  `/hub` is a 303 to `/`
- [x] `Format-GeneralPagesCardHtml -SameOrigin` links by bare path; the hub's card uses it
- [x] The hub's pages carry `data-theme-key="general-pages"` (`dev-pages-lib.ps1`, `connector-dashboard-lib.ps1`)
- [x] Docs: the hub's synopsis, the general page shell's `-HubHref`, the plugin README

### TEST

- [x] `connector-dashboard.tests.ps1` (164 passed): relayed 200, relayed 404, relayed HEAD, relayed refresh,
  `/hub`, the same-origin card; group 2 pinned off the machine's real general pages server
- [x] `dev-pages.tests.ps1` (230 passed): the shared key, the same-origin card, `-SameOrigin`
- [~] The owner's look in a browser: dropped from this branch's steps -- it is the review this branch is parked for

### DEPLOY: feat/3168-hub-proxies-general-pages

The repo hub now serves Artifacts, Issues, Release notes and SessionStart from its own origin: it relays
each from the dkj-solutions general pages server instead of redirecting to that server's port (#3168). The
hub's pages also take the general pages' theme key, `general-pages`. A theme or width picked on any page
now holds on all of them; before, the hub and the general pages were two origins with two keys, so a choice
made on one did not exist on the other, and moving between them read as two different hubs. The General
card links the pages on the hub's own origin, and the pages' "Repo hub" crumb (`/hub`) is answered by the
hub. A theme picked on the hub before this change is not carried over once.

**Score:** 3 -- the maintainer sees one theme hold across the hub and every general page, the moment they click between them.

#### What makes this deploy extra special

The plugin's `loopback-server-lib.ps1` gains `Copy-LoopbackUpstream`, and `Format-GeneralPagesCardHtml`
gains `-SameOrigin`: a repo whose own hub is a PowerShell loopback server can relay the general pages the
same way. Nothing changes for a repo that does not.

**Score:** 1 -- nothing changes for a consumer until its own hub relays; the failure it prevents is the split theme the owner saw here.

#### Pull Request

Repo hub serves the general pages from its own origin, with one shared theme key

