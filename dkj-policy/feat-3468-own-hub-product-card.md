## feat/3468-own-hub-product-card

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

Issue #3468: this repo's own hub (`OwnHub`, `scripts/lib/dev-pages-lib.ps1`) has no Product card, while the
plugin's hub (`hub/lib/repo-hub-page.ps1`) opens its grid with one. The hook already writes the product url
(`product`) into the state file in `ownhub` mode, so the hub only has to read it and link it.

#### A visible result

The hub's home page changes, so the PR waits for the owner's look before the merge.

### CREATE

- [x] `Format-RepoAboutBodyHtml` / `Format-RepoHubHtml` take `-ProductUrl`: the first card links it, believed by
  the plugin hub's own `Test-RepoHubLocalUrl`, and says the server is not running where none is named
- [x] `serve-connector-dashboard.ps1` passes the state file's `product` url
- [x] `dev-pages-lib.ps1`'s header no longer says the hub never links the brand book

### TEST

- [x] `dev-pages.tests.ps1`: the Product card comes first, the not-running form, and five urls that are no plain
  loopback url are not linked (340 passed)
- [x] `connector-dashboard.tests.ps1`: the served hub links the product the state file names; the repo-session
  fixture copies `dev-preview-rules.ps1`, which the page lib now loads (215 passed)
- [x] The live hub on 4871 serves the Product card linking `http://localhost:5174/`

### DEPLOY: feat/3468-own-hub-product-card

This repo's own hub now opens its grid with a Product card linking the brand book's dev server, as the plugin's
hub does in every consumer ([#3468](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3468)). The url
comes from the dev-preview hook's state file and is believed only as a plain loopback url, the plugin hub's own
rule. Where the file names none, the card says the server is not running.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

The source repo's own hub links its product, as the plugin's hub does

