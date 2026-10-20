## feat/brandbook-heading-overview

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

### CREATE

- [x] Brand book Tokens section: a Headings demo, h1 to h6 rendered by the house style, each with its font family, colour token and hex, size token and weight read off the rendered element
- [x] Headings demo reshaped into a plain list, Heading 1 to Heading 6, one line of facts under each (owner's ask)
- [x] One brand book (owner's ask): the hub's PowerShell /brandbook page is retired; its themes table and class list move into the React app (`HouseStyle.tsx`), which is built for the base `/brandbook/`
- [x] The hub serves `brandbook/dist` under `/brandbook/` and rebuilds it when its sources or the house style are newer (`Update-BrandbookBuild`; `-NoBrandbookBuild` for the tests)
- [x] Suites updated (`dev-pages`, `connector-dashboard`), stale house-style exemptions dropped, `brandbook/README.md` rewritten
- [x] `npm run gate`, `check-house-style`, `check-plugin-integrity` and the three touched suites green; a hub on a spare port built and served the app end to end

### TEST

- [x] The owner has looked at the brand book on the hub and said "ship it" (visible result)

### DEPLOY: feat/brandbook-heading-overview

There is one brand book now, on the Repo hub at `/brandbook/`. Before this there were two: the hub's own PowerShell
Brandbook page and the `brandbook/` React app on its Vite port. The hub now serves the React app's build and rebuilds
it whenever `brandbook/` or the house style has changed, so it always shows the tree. The PowerShell page is gone. Its
themes table (each of the twelve themes with its own twelve steps and the house defaults) and its list of every
house class by section are now in the app, under Foundations. The app's Tokens section also gains a Headings list,
Heading 1 to Heading 6 as the house style renders them, each with its font family (the serif `--font-serif` for h1
and h2, the body sans for h3 to h6), the `--primary-*` step and hex its colour resolves to, and its size and weight,
all read off the rendered heading. The app's routes moved under `/brandbook/`: the showcase is its index, the Repo hub
pattern is `/brandbook/repo-hub`. Whether that second hub page should stay is #3202.

**Score:** 2

#### What makes this deploy extra special

The brand book sits outside `plugins/` and is installed by no consumer, so nobody who takes a release sees it.

**Score:** N/A

#### Pull Request

The brand book shows every heading with its font family and colour

