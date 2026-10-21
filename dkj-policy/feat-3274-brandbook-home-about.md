## feat/3274-brandbook-home-about

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

Issue #3274, step 2 of #3270: bring the brand book app's Repo hub specimen to the two-page form. Built first as
two React specimens; at the review the owner asked why the Repo hub sits in the brand book at all, and chose
(October 21, 2026) to **remove the specimen and the hub previews**: the house-style README and its two
stylesheet-only patterns are the only reference to the hub's form. That reverses #3202's *keep it as a
specimen*, whose reason was a component reference for repos with React; the patterns carry the form without
one, and two renderings of one form is the drift #3202 itself was about.

### CREATE

- [x] Removed `brandbook/src/dashboard/` (the specimen, its shell, the seven hub previews and their CSS) and the
  showcase's Repo hub section; `main.tsx` renders the showcase alone, `routes.ts` keeps `HUB_PATH` and
  `SHOWCASE_PATH`, and the Apps group in `App.tsx` and the `Section` ids lose `repo-hub`.
- [x] The brand book's crumb back to the hub reads Home (`App.tsx`), as every hub page's does since #3270.
- [x] `house-style/README.md`: the two patterns are the only reference; `brandbook/README.md` says the app drew
  a specimen until #3274.
- [x] `.claude/specialists/lenses/specialist-04-13-lens.md`: Cody's lens, filled (his first work here).

### TEST

- [x] `npm run gate` in `brandbook/`: eslint (0 problems: the two warnings went with the removed file), CSS
  syntax, custom properties, colour tokens, build.
- [x] The full gate (`open-pr.ps1 -GatesOnly`), before the park: green.
- [ ] The owner looks at `/brandbook/` and approves.

### DEPLOY: feat/3274-brandbook-home-about

The brand book app no longer draws a Repo hub specimen or previews of other repos' hubs (#3274):
`/brandbook/repo-hub` and `/brandbook/dashboards` are the showcase now, like any other path under it. The hub's
form is laid down once, in the house-style README and its two stylesheet-only patterns. The brand book's crumb
back to the hub reads Home.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo's brand book loses its Repo hub section; a repo building its own hub starts from the
house-style README and `patterns/repo-dashboard.html` plus `patterns/repo-about.html`.

**Score:** 2

#### Pull Request

Brand book app: remove the Repo hub specimen and the hub previews
