## fix/3083-release-notes-local-only

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

#3083: the v5.22.0 cut could not redeploy the `ccs-release-notes` worker, because its path token is
local state on another machine. Maikel's answer (October 17, 2026): only BWJ-Development's release notes
are hosted on Cloudflare; a DKJ repo's notes are read locally, in VS Code's Simple Browser. The seam for
that already exists, since `Get-ReleasePageWorkerName = ''` makes `cut-release` skip the redeploy step, and
the connector dashboard already runs at every session start, so it serves the page.

### CREATE

- [x] `Get-ReleasePageWorkerName` answers `''` here, with the reason in its comment
- [x] The connector dashboard serves `dkj-policy/releases/page/release-notes.html` at `/release-notes`, a 404 naming the build step while it is not built
- [x] The config blueprint regenerated from that answer
- [x] Sylvester's lens: the release-notes block says where the page is read and why it is no longer hosted
- [x] The leftover worker filed for removal as an owner's act: #3086

### TEST

- [x] `connector-dashboard.tests.ps1`: 119 passed, 0 failed, including the new route before and after the page is built

### DEPLOY: fix/3083-release-notes-local-only

This repo's release-notes page is no longer hosted on Cloudflare, so a cut no longer stops at a redeploy
that needs a token only one machine had
([#3083](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3083)). The page is still built at
every cut, and the connector dashboard serves it at `/release-notes`, for VS Code's Simple Browser. Only
BWJ-Development hosts its release notes, so colleagues can read them from any device.

**Score:** 2

#### What makes this deploy extra special

N/A. A consumer's own `Get-ReleasePageWorkerName` answer is untouched, and the blueprint already offered
`''` as the default.

**Score:** N/A

#### Pull Request

Release notes: read locally in this repo, no Cloudflare worker

