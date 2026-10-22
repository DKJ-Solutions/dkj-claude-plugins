## feat/3297-hub-banner-every-page

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

#### Status

A visible result: parked for the owner's eye, with no pull request until they have looked.

### CREATE

- [x] `Format-GeneralPageHtml` writes `Format-RepoHubBanner` under the intro, above the page's own blocks, so every page drawn through that shell carries it
- [x] `Format-ReleaseNotesDevPage` writes it under the bar, in a page column of its own, outside the template's own layout
- [x] `Format-RepoHubBanner`'s docstring names every place it now appears

### TEST

- [x] `dev-pages.tests.ps1`: the banner appears once, in place, on a shell page and on the release notes. The SessionStart page's "no warning" assert ignores the banner's own hidden warning line (294 passed)
- [x] `open-pr.ps1 -GatesOnly` before the park

### DEPLOY: feat/3297-hub-banner-every-page

The hub's general banner ([#3297](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3297)), with the
countdown to the next full hour and the airsquats box, was on the home page only. It now stands on every hub page:
under the intro of every page `Format-GeneralPageHtml` draws (Artifacts, Issues, SessionStart, the Brandbook
page, and this repo's own pages), and under the bar of the release notes.

**Score:** 2

#### What makes this deploy extra special

Every page of a repo's hub shows the airsquats countdown, so it stays in view whichever page is open.

**Score:** 2

#### Pull Request

The hub's banner on every hub page, not only the home page

