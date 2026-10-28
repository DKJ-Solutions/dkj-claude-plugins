## feat/3629-house-style-specimens-in-dkj-policy

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

#### A visible result -- this branch waits for the owner's look before it merges

The page moves under `dkj-policy`'s plugin page, so the move is judged on the running hub:
`/plugins/dkj-policy` shows the House style card, `/plugins/dkj-policy/house-style` the specimens, and
`/plugins/dkj-solutions/house-style` redirects there.

### CREATE

- [x] `Resolve-PluginsPageRequest` resolves `/plugins/dkj-policy/house-style[/<section>]`, and answers the old `/plugins/dkj-solutions/house-style[/<section>]` with a redirect to it
- [x] `serve-general-pages.ps1` sends that redirect as a 301 before the enabled-plugin lookup, so the old link lands in a repo without `dkj-solutions` too
- [x] The House style card and the specimens' crumbs move from `dkj-solutions` to `dkj-policy`
- [x] The docs naming the route follow: `hub/README.md`, `dkj-solutions/README.md`, `assets/house-style/README.md`, Gwen's lens

### TEST

- [x] `dev-pages.tests.ps1`: the new route, the two redirects, an old non-page that is no redirect, the card on `dkj-policy` and none on `dkj-solutions` -- 488 passed, 0 failed

### DEPLOY: feat/3629-house-style-specimens-in-dkj-policy

The house style's specimens page moved from `/plugins/dkj-solutions/house-style` to
`/plugins/dkj-policy/house-style`, beside the files it documents
([#3629](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3629)). Every repo running the toolbox now
reaches it, BWJ-Development's included, where `dkj-solutions` is never enabled. The House style card sits on the
`dkj-policy` plugin page, and the old address redirects to the new one.

**Score:** 2

#### What makes this deploy extra special

A BWJ-Development repo's toolbox now has a House style page under Plugins > dkj-policy, showing every token,
theme and component of the stylesheet that toolbox renders with. A bookmark to the old address still lands.

**Score:** 1

#### Pull Request

The house style specimens page moves to dkj-policy, so every repo running the toolbox reaches it

