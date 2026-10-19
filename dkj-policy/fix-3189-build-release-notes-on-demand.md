## fix/3189-build-release-notes-on-demand

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

#### Issue #3189

The general pages server served `/release-notes` only from a gitignored snapshot that nothing built, so the
hub's link was a 404 on every fresh clone and second machine, and the page went stale after each release.
The cause was verified in `serve-general-pages.ps1` before the repair. The issue proposed two repairs; this
branch takes the first one, building on demand, because the page builds in about a second.

### CREATE

- [x] `general-pages-lib.ps1`: `Get-DkjPolicyScriptCandidates` (the always-on lib's lookup, generalised;
  `Get-AlwaysOnBudgetLibCandidates` is now a thin wrapper) and the pure rule `Get-ReleaseNotesPageNeed`
- [x] `serve-general-pages.ps1`: `Update-ReleaseNotesPage` builds the page in a bounded child process where
  it is absent or older than a file under `dkj-policy/releases`. A failed build is held for 30 s, an older
  page stays served, and the 404 names why
- [x] README table row and trust paragraph updated

### TEST

- [x] `dev-pages.tests.ps1`: the candidate list and the need rule (239 passed)
- [x] `dev-preview-sessionstart.tests.ps1`: the live server names why an absent page cannot be built, and
  keeps serving a stale page whose rebuild fails (182 passed)
- [x] Live check in this repo: page moved aside, server started, `/release-notes` answered 200 with 800 KB
  and the page was back on disk

### DEPLOY: fix/3189-build-release-notes-on-demand

The Repo hub's Release notes link here works on a fresh clone. The general pages server builds the gitignored
page itself when it is missing or older than a release document, so nobody has to run
`build-release-notes-page.ps1` by hand any more (#3189).

**Score:** 2

#### What makes this deploy extra special

In a DKJ-Solutions repo with `dkj-solutions` enabled, the hub's Release notes card opens the notes instead
of a 404, and shows the latest release without a manual rebuild. Where the page cannot be built, the 404
now says why.

**Score:** 2

#### Pull Request

Repo hub's Release notes link 404s: the general pages server builds the page on demand

