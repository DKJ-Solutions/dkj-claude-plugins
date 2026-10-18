## fix/3108-release-notes-page-house-style

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

The fix dresses only the copy this repo's dev server serves, not the template (#3108's open question).
`scripts/release/release-notes-page-template.html` is dkj-policy's, shared with every consumer --
BWJ-Development repos included, which do not take the house style -- and it is deliberately
self-contained for the Worker. This repo hosts the page nowhere but the dev server (#3083), so the
server is where the house style belongs.

The crumb reads "Repo dashboard", as every other page on `main` does today. #3097's step 2
(`feat/3097-repo-hub`, unmerged) renames that crumb to "Repo hub". Whichever of the two lands second
renames this crumb as well, as noted on #3097.

### CREATE

- [x] `scripts/lib/dev-pages-lib.ps1`: `Format-ReleaseNotesDevPage` puts the house stylesheet and theme
  script after the template's own style, then a layer pointing the template's tokens at house tokens,
  then the breadcrumb bar and the settings button
- [x] `scripts/dashboard/serve-connector-dashboard.ps1`: `/release-notes` leaves the static map and is
  served through that function, with the same 404 while the page is unbuilt

### TEST

- [x] `dev-pages.tests.ps1`: ten asserts against the real template (order of the house file and the
  token layer, the bar first in `<body>`, the trail, the settings mount, content untouched, an
  unshaped page served as it came) -- 49 passed
- [x] `connector-dashboard.tests.ps1`: the running server dresses a page of the template's shape --
  126 passed
- [x] Served by the restarted dev server on port 4870: `/release-notes` returns 200 with the bar and
  the house link

### DEPLOY: fix/3108-release-notes-page-house-style

The release-notes page on this repo's dev server now carries the house style and opens with the
breadcrumb bar back to the Repo dashboard, like the other pages under it
([#3108](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3108)). The page is dressed as
it is served. The shared template and the page a Worker publishes are untouched.

**Score:** 2

#### What makes this deploy extra special

N/A -- this repo's own dev server only; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

The release-notes page carries the house style and the breadcrumb bar
