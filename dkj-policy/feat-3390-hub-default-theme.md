## feat/3390-hub-default-theme

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

Inbound #3390 from dkj-lifehub: the plugin's hub and general pages hard-code `data-theme-default="lilac"`
at three sites, so a consumer whose own product opens in another theme shows two defaults. Verified in
the tree: `general-pages-lib.ps1` (the page shell and the release-notes dressing) and `repo-hub-page.ps1`.
The issue's own proposal: an optional `DefaultTheme` key in `Get-DevPreview`, lilac where unstated.

No visible change here: this repo states no `DefaultTheme`, so every page keeps lilac; in a consumer the
change shows only once it opts in. The attribute's value is held by the suites.

### CREATE

- [x] `ConvertTo-DevPreviewConfig` takes `DefaultTheme`, refused unless it has a theme id's shape, and hub-alone (a `Product` may not state it)
- [x] the state file carries it as `theme`, believed only in that shape; the hook writes it
- [x] the general pages server reads it per request and hands it in with `Set-GeneralPagesThemeDefault`; the three sites write `Get-GeneralPagesThemeDefault`, escaped
- [x] the hub README documents the key

### TEST

- [x] `dev-preview-sessionstart.tests.ps1`: config, refusals, state round-trip, legacy file, hub attribute (329 passed)
- [x] `dev-pages.tests.ps1`: the release notes and the page shell take the theme, escaped (313 passed)

### DEPLOY: feat/3390-hub-default-theme

A repo can now state the theme the plugin's hub and its general pages (Artifacts, Issues, Release notes,
SessionStart) open in, with an optional `DefaultTheme` in its `Get-DevPreview`, for example `'teal'`.
Until now they always opened in lilac, so a repo whose own product opens in another theme showed two
defaults depending on the port. A repo that states nothing keeps lilac, and a visitor's own theme choice
still wins ([#3390](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3390)). The key is
documented in [the hub's README](../plugins/dkj-policy/hub/README.md).

**Score:** 2

#### What makes this deploy extra special

A consumer repo's maintainer who runs its own themed product beside the plugin's hub can now make the
hub and its pages open in the same theme, with one line in `scripts/repo-config.ps1`.

**Score:** 2

#### Pull Request

Let a repo state the default theme of the plugin's hub and general pages
