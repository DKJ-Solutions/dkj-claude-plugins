## feat/3270-home-and-about

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

Issue #3270 (inbound from dkj-lifehub, the owner's words of October 21, 2026): the Repo hub stops being one
page on `/`. `/` becomes the repo's home page, a portal; everything about the repo itself moves to an
**About this repo** page.

#### Step 1 of 2 -- the brand book specimen is #3274

This branch carries the spec (the house-style README's "The Repo hub"), the two stylesheet-only patterns
and both PowerShell hubs, the plugin's and this repo's. The brand book app's React specimen is #3274, its
own visible change, because this branch was already eight files of hub and spec before it.

#### The defaults chosen where the issue left a choice open

- **The route is `/about`**, on both servers.
- **The first crumb on every page is Home** (it read Repo hub), still linking `/` (or `/hub` on the general
  server, which is the home page there).
- **No eyebrow on the home page**: its `h1` is the repo's name already. About keeps `<owner>/<repo>` as its
  eyebrow, as every page below the home page does.
- **Products is one row from the existing `Get-DevPreview` seam**: no multi-product seam yet, since no repo
  states more than one server. The plugin hub keeps its two setup cards in that place for a repo that states none.
- **An open issue is listed once**: About links the general Issues page and, in a repo with in-flight lists,
  those lists stay About's; neither hub here has any.
- **The hook's line keeps `Repo hub:`**: it names the whole hub, not its first page, and changing it moves
  many hook-line asserts for no visible gain.
- **Facts is the facts card's `h2`** on About, because the page itself is titled About this repo.

### CREATE

- [x] `hub/lib/general-pages-lib.ps1`: the first crumb reads Home; `Format-RepoHomeHeadHtml` (bar, settings,
  intro with the repo's name, banner) and `Format-RepoAboutLinkHtml` are shared by both hubs; a card standing
  alone takes `-Title`.
- [x] `hub/lib/repo-hub-page.ps1`: `Format-PluginRepoHubHtml` is the home page (Products or the setup cards,
  About this repo, Brand book), `Format-PluginRepoAboutHtml` the About page (General pages, Facts, footer).
- [x] `hub/pages/serve-general-pages.ps1` answers `/about`, under `OwnHub` with the same 303.
- [x] `dkj-solutions-pages-lib.ps1`: the DKJ-Solutions card, standing alone, is titled Brand book.
- [x] This repo: `scripts/lib/dev-pages-lib.ps1` (`Format-RepoHubHtml` the home page, `Format-RepoAboutHtml`
  new), `serve-connector-dashboard.ps1` answers `/about`, and the Connectors page's crumb reads Home.
- [x] `house-style/README.md` ("Every page: the breadcrumb bar", "The Repo hub"), `patterns/repo-dashboard.html`
  (the home page), new `patterns/repo-about.html`, the `house-style` skill (its paragraph and the
  `house-style.css` sha256, whose example comment names the Home crumb), `hub/README.md` and the
  dkj-solutions README.
- [x] Tests: `dev-pages`, `connector-dashboard` and `dev-preview-sessionstart` assert the two pages, `/about`
  on both servers, and the Home crumb.

### TEST

- [x] `dev-pages` 286/0, `connector-dashboard` 198/0, `dev-preview-sessionstart` 282/0, standalone.
- [ ] The full gate (`open-pr.ps1 -GatesOnly`), before the park.
- [ ] The owner looks at the home page and About this repo on this repo's hub (`/`, `/about`) and on the
  patterns, and approves the form.

### DEPLOY: feat/3270-home-and-about

The Repo hub is two pages now (#3270). **`/` is the repo's home page**, a portal: its `h1` is the repo's
name, then its Products, one link to **About this repo**, and in a DKJ-Solutions repo the **Brand book**.
**`/about` holds the repo itself**: its own pages, the general pages (Artifacts, Issues, Release notes,
SessionStart) and its facts. The first crumb on every page reads **Home**. The plugin's hub and this
repo's own both take the form, and the house-style README and its two patterns lay it down; the brand
book's React specimen follows in #3274.

**Score:** 4

#### What makes this deploy extra special

Every repo's hub opens on a page with the repo's name and its products, and the general pages move one
click further, to About this repo. A repo that serves its own hub (`OwnHub`) takes the new form from the
house-style README and `patterns/repo-dashboard.html` plus `patterns/repo-about.html`.

**Score:** 4
#### Pull Request

Repo hub: '/' becomes the home page, the repo itself moves to 'About this repo'

