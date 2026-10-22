## feat/site-header-everywhere

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

The owner: the site header on ALL pages, not only the homes. Missing were the four general pages (built by the
dkj-policy plugin's hub server for every repo) and the brand book app (whose build the plugin ships to every
DKJ-Solutions repo). Chosen from a menu: in the plugin, for every repo; and in the app, under a neutral name.

### CREATE

- [x] `Format-GeneralPageHtml`: a page that names its site gets the header (the repo's short name via `ConvertTo-SiteHeaderName`, `hub` after it), so Artifacts, Issues, SessionStart, About and the Brandbook-missing page carry it
- [x] `Format-ReleaseNotesDevPage -RepoName`: the header above the release notes' bar; the general server passes it
- [x] The plugin hub's home (`repository-page.ps1`): the header, so the intro goes there too
- [x] The brand book app: `SiteHeader` (`DKJ brand book`, home `/`) in place of the `Toolbar`, holding the preview settings; its bar under the header on the paper, as the house bar
- [x] The house-style README: every hub page and the brand book carry the header

### TEST

- [x] `dev-pages` (292), `connector-dashboard` (198), `dev-preview-sessionstart` (309) green; `npm run gate` green; `check-house-style` OK
- [~] Looked at in the browser -- the extension was not connected; the owner looks at it before the merge

### DEPLOY: feat/site-header-everywhere

The site header now stands on every hub page in every DKJ-Solutions repo, not only on this repo's own pages: the
dkj-policy hub server draws it on the home page, About, Artifacts, Issues, Release notes and SessionStart, with the
repo's name and `hub` after it, the settings button in it and no eyebrow or intro under it. The brand book app
carries it too, as *DKJ brand book*, holding its preview settings.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions repo that takes the release sees its hub pages open with the site header, and its hub home
without the h1 and lead it had.

**Score:** 3

#### Pull Request

The site header on every page: the general pages in every repo, and the brand book app

