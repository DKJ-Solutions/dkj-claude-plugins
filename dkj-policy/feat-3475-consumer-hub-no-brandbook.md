## feat/3475-consumer-hub-no-brandbook

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

#### The three open points #3475 handed to this repo

- **Does the DKJ-Solutions card keep anything?** No. Its one page was the Brandbook, and no hub called
  `Format-DkjSolutionsPagesCardHtml` any more, so the card and the whole `dkj-solutions-pages-lib.ps1` go.
- **Does `dkj-solutions/assets/brandbook/` still need to ship?** Nothing reads it after this branch. Removing
  it changes the release machinery (`Get-ReleaseBuilds`, its cut tests), so it is its own issue, not this one.
- **What do the docs say afterwards?** That no hub shows or serves the Brandbook, and since when.

### CREATE

- [x] `serve-general-pages.ps1`: no `/brandbook` routes, and no `dkj-solutions` read at start
- [x] `repo-hub-page.ps1`: no Brand book card, and no `-DkjSolutions` switch
- [x] `dkj-solutions-pages-lib.ps1` removed, with `Get-DkjSolutionsPagesLibPath` and the unused `brandbook` icon
- [x] Tests flipped to pin the absence, in a fixture that enables `dkj-solutions` too
- [x] Docs: `hub/README.md`, `dkj-solutions/README.md`, the house-style README, skill and hub pattern,
  `this-repo.md`, Sylvester's lens and the `repo-session` skill

### TEST

- [x] The owner has looked at a consumer hub served from this branch: no Brandbook card, `/brandbook` a 404

### DEPLOY: feat/3475-consumer-hub-no-brandbook

No hub shows or serves the Brandbook any more, whether or not the repo enables `dkj-solutions`
([#3475](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3475)). The brand book is a product of
`dkj-claude-plugins`, and only that repo shows it, on its own product port. A consumer hub's home page loses its
Brand book card, and `/brandbook` on its general pages server is now a plain 404. The extension's
`dkj-solutions-pages-lib.ps1`, which existed only to draw that card and serve the build, is removed.

**Score:** 2

#### What makes this deploy extra special

A maintainer of a DKJ-Solutions repo no longer finds the Brandbook card on that repo's hub after the update.
The brand book stays reachable from `dkj-claude-plugins`.

**Score:** 1

#### Pull Request

Consumer hubs no longer show or serve the Brandbook

