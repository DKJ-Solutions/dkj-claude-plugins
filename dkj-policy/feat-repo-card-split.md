## feat/repo-card-split

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

- [x] Split `Format-DkjRepoCardHtml` into a GitHub card and a This machine card, side by side in the `grid-2`
- [x] Drop the `Repo` group head and the description; each card carries its own `h2`
- [x] Every fact one line: a detail follows its value after a dot, cut off with an ellipsis, whole on hover
- [x] `.dr-card { min-width: 0; }` so the pair never scrolls the page sideways (house-style cause filed as #3614)

### TEST

- [x] `dev-pages.tests.ps1` green (482 passed), asserts updated for the two cards, the h2s and the one-line facts
- [x] The owner looked at the page on the dev server and gave the go-ahead ("goed genoeg zo. Ship it")

### DEPLOY: feat/repo-card-split

A DKJ repo's own page in the hub (`/connectors/dkj/<name>`) no longer shows one wide Repo card. It shows two cards side by side, each titled with its own `h2`. **GitHub** holds visibility, open issues and PRs, the last push and the link. **This machine** holds the register check's status, the checkout, the last commit, the plugins, the checks, the drift, the manifest, the findings and the session command. The description line and the `Repo` group head are gone. Every fact now sits on one line: the last commit reads `<age> · <subject>`, cut off with an ellipsis, with the whole text on hover. A `min-width: 0` on the cards keeps the pair from widening the page into a horizontal scroll. The underlying `.grid-2` track shape is filed as #3614.

**Score:** 2

#### What makes this deploy extra special

N/A -- the hub is this repo's own dev server, so nobody who takes a release sees this page.

**Score:** N/A

#### Pull Request

A DKJ repo's page splits its Repo card into a GitHub card and a This machine card

