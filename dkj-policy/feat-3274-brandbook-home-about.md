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

Issue #3274, step 2 of #3270: the brand book app's React specimen of the Repo hub takes the two-page form the
house-style README and the PowerShell hubs took in #3279 -- the home page and About this repo.

#### Choices made where the issue left them open

- **The previews show each repo's About this repo page.** `PlaceholderDashboard` is the About form now, and
  the seven hub previews keep passing their own cards as its children, between In flight and Facts. Drawing a
  home page per preview would show the same three sections seven times; the cards are what each preview is for.
  A repo's `product` label feeds the Products row of the home specimen.
- **The README gets one sentence naming the React components, not a column back in its two tables**: the column
  would read `PageLinks` on nearly every row, and the sentence names the two specimens' routes as well.
- **Cody's lens is filled in on this branch**, because the brandbook app is his first work here
  (`SPECIALISTS.md`: a lens is filled the day its specialist first has work, before it is deployed).

### CREATE

- [x] `routes.ts` and `main.tsx`: `ABOUT_PATH` (`/brandbook/repo-hub/about`) and its page, `RepoAbout`.
- [x] `PlaceholderDashboard.tsx`: `PlaceholderHome` (the repo's name as `h1`, Products, About this repo, Brand
  book) and `PlaceholderDashboard` as About this repo (eyebrow, tiles, In flight, the repo's cards, Facts).
- [x] `RepoDashboard.tsx`: the home specimen, and `RepoAbout` with the trail Brand book > Repo hub pattern >
  About this repo.
- [x] `DashboardShell.tsx`: the intro's eyebrow is optional; `Navigation.tsx`: `PageLinks` takes a `subtitle`.
- [x] The "Repo hub" texts: the app's Home crumb (`App.tsx`), the previews' About title and intro, the showcase
  section (with a button to the About specimen), and `brandbook/README.md`.
- [x] `house-style/README.md`: the React sentence replaces "still shows the one-page form".
- [x] `.claude/specialists/lenses/specialist-04-13-lens.md`: Cody's lens, filled.

### TEST

- [x] `npm run gate` in `brandbook/`: eslint (0 errors; the two warnings are the `pull`/`issue` exports that
  were there before), CSS syntax, custom properties, colour tokens, build.
- [ ] The full gate (`open-pr.ps1 -GatesOnly`), before the park.
- [ ] The owner looks at `/brandbook/repo-hub`, `/brandbook/repo-hub/about` and a hub preview, and approves.

### DEPLOY: feat/3274-brandbook-home-about

The brand book's Repo hub pattern is two pages too (#3274, step 2 of #3270): `/brandbook/repo-hub` is the
home page specimen (the repo's name, its products, one link to About this repo, the Brand book) and
`/brandbook/repo-hub/about` the About this repo specimen (in flight, the repo's own cards, its facts). The hub
previews show each repo's About page, and the brand book's crumb back to the hub reads Home.

**Score:** 2

#### What makes this deploy extra special

The brand book a DKJ-Solutions repo opens from its hub shows the new form from this release on.

**Score:** 2
#### Pull Request

Brand book app: the Repo hub specimen is a Home page and an About this repo page

