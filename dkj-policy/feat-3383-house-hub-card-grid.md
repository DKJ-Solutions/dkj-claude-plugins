## feat/3383-house-hub-card-grid

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

Owner decision on #3383 (Maikel, October 24, 2026): the source repo's `.grid-3` card-link hub with a
separate Repository page is the house hub form. The README, the patterns and the plugin's hub follow it.

### CREATE

- [x] `general-pages-lib.ps1`: `Format-HubCardLinkHtml`, the one hub card both hubs draw
- [x] `repo-hub-page.ps1`: the home page as one `.grid-3` of card links; `Format-PluginRepoRepositoryHtml` for `/repository`
- [x] `serve-general-pages.ps1`: the `/repository` route; the hub README's route table and home-page list
- [x] `dev-pages-lib.ps1`: the source hub draws its cards through the shared helper
- [x] House-style README "The hub", the `house-style` skill, `patterns/repo-dashboard.html` and the new `patterns/repo-repository.html`

### TEST

- [x] `dev-preview-sessionstart.tests.ps1` (326/0) and `dev-pages.tests.ps1` (311/0) green with the new asserts

### DEPLOY: feat/3383-house-hub-card-grid

The house hub's form is now the one the source repo's own hub already had, in the README, the patterns and the
dkj-policy plugin's hub alike (#3383): the home page is one `.grid-3` of card links with no heading, and the
facts and Issues sit on a separate Repository page on `/repository`. The two hubs draw their cards through one
helper, `Format-HubCardLinkHtml`, and `patterns/repo-repository.html` is the new reference for that page.

**Score:** 3

#### What makes this deploy extra special

Every repo's hub the dkj-policy plugin serves changes shape at the next update: the products and pages become
cards in one grid, and the facts move to a Repository page. A repo that built its own hub from the README
now has a reference that matches the plugin's hub it sees beside it.

**Score:** 3

#### Pull Request

The house hub is a grid of card links with a separate Repository page

