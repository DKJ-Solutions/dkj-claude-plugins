## fix/hub-without-brandbook

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

The owner: the brand book showed on the repo port (4870) and belongs on the product port (5173) alone.
Chosen from a menu: the hub's home keeps only the DKJ repos link, and /brandbook on the hub is a 404.
Then: the product port starts at the root, with a page that links the brand book (resolves #3286).

### CREATE

- [x] `serve-connector-dashboard.ps1`: drop the /brandbook routes, `Update-BrandbookBuild` and `-NoBrandbookBuild`
- [x] `dev-pages-lib.ps1`: the home page's section becomes DKJ-Solutions with DKJ repos only; drop `Format-BrandbookStatusHtml` and the dkj-solutions lib's dot-source
- [x] `general-pages-lib.ps1`: a card with no server rows says nothing about the general pages server
- [x] Docstrings and `brandbook/README.md` name the product port as the one place
- [x] `brandbook/root.html` + `productRoot` in `vite.config.ts`: the dev server answers `/` with a page linking `/brandbook/`, serves the two house files beside it, and sends `/brandbook` on to `/brandbook/`
- [x] `Get-DevPreview`: the product's `Path` is `/`, so the hook hands out the root

### TEST

- [x] `dev-pages.tests.ps1` (284 passed) and `connector-dashboard.tests.ps1` (196 passed)
- [x] `npm run gate` in `brandbook/` green; on the running dev server `/`, `/house-style.css`, `/house-theme.js` and `/brandbook/` answer 200, `/brandbook` 303

### DEPLOY: fix/hub-without-brandbook

This repo's Repository (the hub on port 4870) no longer shows the brand book: its home page drops the Brandbook
link, its section is now called DKJ-Solutions and holds the DKJ repos page alone, and `/brandbook` is a 404
there. The hub had served a build of the `brandbook/` app at `/brandbook/` since #3210, rebuilding it with npm
on a stale visit; since #3283 the same app runs as this repo's product on a port of its own, from the tree, so
one brand book was visible on two ports. The product port is now the one place, and it starts at the root:
in dev, `/` is a page of its own (`brandbook/root.html`) linking the brand book at `/brandbook/`, and the
dev-preview hook hands out that root. The brand book's Home crumb, which pointed at a `/` the Vite server did not
answer, now lands on it (#3286). The shared General card, in
dkj-policy's `general-pages-lib.ps1`, no longer says the general pages server is not running when it is
handed no server rows, since it links nothing of that server. Every other DKJ-Solutions repo still gets the
brand book from the dkj-solutions plugin, unchanged.

**Score:** 2

#### What makes this deploy extra special

N/A: the source repo's own hub; no consumer's hub or brand book changes.

**Score:** N/A

#### Pull Request

The brand book lives on the product port alone, which starts at a root page linking it

