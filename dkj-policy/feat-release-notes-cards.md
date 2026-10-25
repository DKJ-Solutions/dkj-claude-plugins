## feat/release-notes-cards

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

Index becomes a card grid; the builder writes one page per release under page/release-notes/v<semver>.html; hubs and worker serve /release-notes/v<semver>; old #v<semver> fragments redirect.

### CREATE

- [x] Builder: the index as a grid of cards, and one page per release in `page/release-notes/v<semver>.html`, with a `-LinkBase` for the address the links carry
- [x] Worker bundle: every page, keyed under the route, built again for the worker's own address
- [x] Template: card grid, release page (back link, heading, older/newer), old `#v<semver>` links forwarded
- [x] Hubs: both servers serve `/release-notes/v<semver>` through `Resolve-ReleaseNotesRequest`, with a crumb back to the index; an index built before release pages existed counts as not built
- [x] Plugin mirror of the builder and template kept byte-identical
- [ ] Review: Victor (code) and Sebastian (security) on the diff
- [ ] Owner looks at the cards and a release page in the hub (visible result)

### TEST

- [x] `release-notes-page.tests.ps1`, `dev-pages.tests.ps1`, `connector-dashboard.tests.ps1` green
- [ ] The full gate through `open-pr`

### DEPLOY: feat/release-notes-cards

The release-notes page is now an index of cards, one per release, and every release has a page of its
own: `/release-notes/v5.30.0` on both hubs and `/notes/<token>/v5.30.0` in the Worker, with older/newer
links between them. The builder writes them all in one run, so a cut release gets its page without anyone
adding it. A link to the old page with a `#v5.30.0` fragment is forwarded to the release's own page.

**Score:** 3

#### What makes this deploy extra special

Whoever reads the release notes can now open and send one release on its own address, instead of a
fragment on one long page, and sees every release as a card. A consumer takes it with the plugin update;
its hub rebuilds the page on first visit.

**Score:** 3

#### Pull Request

Release notes: every release a card, with a page of its own

