## feat/3202-repo-hub-specimen

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

#3202, decided by the owner on October 20, 2026: `RepoDashboard` stays as a **pattern specimen**. It gets no live
GitHub data and no "this repo" or "single source" claims, and it is placed in the showcase. `/brandbook/dashboards`
stays. A visible result, so the branch parks for the owner's eye with no PR.

### CREATE

- [x] `RepoDashboard.tsx`: rebuilt on `PlaceholderDashboard` with an invented `example-repo`. The GitHub fetch, the
  repo table and the brand claims are gone, and a note at the top names it a specimen and links the real hub on `/`.
- [x] The showcase gains a **Repo hub** section under Apps (nav item and section), linking the pattern and the hub
  previews.
- [x] Breadcrumbs on the pattern and the previews now read Brand book > Repo hub pattern > Hub previews.

### TEST

- [x] `npm run gate` in `brandbook/` green (eslint, the CSS checks, `tsc -b`, `vite build`); the hub serves the new
  build at `/brandbook/repo-hub`.
- [~] Judged by eye: that is the owner's look, which this branch is parked for.

### DEPLOY: feat/3202-repo-hub-specimen

The brand book no longer carries a second Repo hub. Its page at `/brandbook/repo-hub` is now a specimen of the Repo
hub pattern. It shows an invented example repo, says so at the top, and links this repo's real hub on the dev server's
`/`. It reads nothing from GitHub and claims to be no repo's hub. The showcase gains a Repo hub section under Apps that
opens the pattern and the hub previews, and the breadcrumbs of both lead back through the brand book.

**Score:** 2

#### What makes this deploy extra special

The brand book sits outside `plugins/` and is installed by no consumer, so nobody who takes a release sees it.

**Score:** N/A

#### Pull Request

The brand book's Repo hub page is a specimen of the layout, not a second hub

