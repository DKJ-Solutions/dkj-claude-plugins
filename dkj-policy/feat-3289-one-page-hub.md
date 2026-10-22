## feat/3289-one-page-hub

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

A visible result: parked for the owner's eye, with no pull request until they have looked. It builds the
decision recorded on #3289: the house form follows this repo's hub, so every repo's hub becomes one page.

### CREATE

- [x] `Format-PluginRepoHubHtml` carries what `Format-PluginRepoAboutHtml` did, and takes `-Folder`: the General pages, the Facts and the footer note, after Products and before the Brand book; `Format-PluginRepoAboutHtml` and `Format-RepoAboutLinkHtml` are gone
- [x] `serve-general-pages.ps1` answers `/about` with a 303 to `/`
- [x] The house-style README's "The hub" becomes one table for one page; `patterns/repo-dashboard.html` takes `repo-about.html`'s blocks under a site header, and `repo-about.html` is removed
- [x] The hub README, the `house-style` skill and `dev-pages-lib.ps1`'s header follow

### TEST

- [x] `dev-preview-sessionstart.tests.ps1`: About's asserts run against the home page, plus the block order and the `/about` redirect on a live server (308 passed)
- [x] `open-pr.ps1 -GatesOnly` before the park

### DEPLOY: feat/3289-one-page-hub

The hub ([#3289](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3289)) is one page in every repo
now, not a home page that links an About this repo page. The plugin's hub home page holds the Products section
(or the setup cards), the General pages, the facts, the Brand book in a DKJ-Solutions repo, and a footer note.
`/about` answers 303 to `/`, so an old link still lands. The house-style README's "The hub" lays the one page
down as one table, and its stylesheet-only reference is the single
[`patterns/repo-dashboard.html`](../plugins/dkj-policy/dkj-solutions/assets/house-style/patterns/repo-dashboard.html),
under a site header. `repo-about.html` is gone.

**Score:** 3

#### What makes this deploy extra special

The hub that every repo's session start links is one page: the General pages and the facts are on it, so they
no longer sit one click away on About this repo. A repo that copied the two stylesheet-only patterns now has one
pattern to follow.

**Score:** 3

#### Pull Request

Every repo's hub is one page: About this repo folds into the home page

