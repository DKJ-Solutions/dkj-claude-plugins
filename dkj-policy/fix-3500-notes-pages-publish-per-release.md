## fix/3500-notes-pages-publish-per-release

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

Issue #3500: the builder's per-release pages could not be published. The design choice the issue left
to the plugin: the shared worker and `publish-page` learn the set (one KV key per release page), rather
than a single-file builder mode, because the owner chose a page per release on October 25.

### CREATE

- [x] The worker routes `/<kind>/<token>/v<x.y.z>` for a paged kind and reads `<kind>:<token>/v<x.y.z>`
- [x] `page-publish-rules.ps1`: `Paged`, release keys, `Convert-BwjPageLinks`, `Find-BwjDeadPageLinks`
- [x] `publish-page.ps1` uploads the whole notes set, pages first and index last, after a dead-link guard
- [x] The `publish-page` skill page describes the set and the one-time redeploy

### TEST

- [x] `bwj-page-publish.tests.ps1`: route, the PAGED seam, keys, link mapping, dead links, a set through
      the wrangler shim, and the real builder's output against the worker's own route (153 pass)

### DEPLOY: fix/3500-notes-pages-publish-per-release

`publish-page -Kind notes` now publishes the release notes as the set the builder writes: the index of
cards and one page per release, each under a KV key of its own (`notes:<token>/v<x.y.z>`), and the
shared BWJ pages worker serves those pages at `/notes/<token>/v<x.y.z>`
([#3500](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3500)). The builder's
`/release-notes/...` links are mapped onto the worker's route in the published copy. A link the
published set would not serve stops the run before anything is uploaded.

**Score:** 3

#### What makes this deploy extra special

Both BWJ stores can publish their release notes again. Until now every card on a freshly built page led
to a 404, so neither store had published this week's release. **Redeploy the shared worker once**
(`publish-page.ps1 -EmitWorker`, then `wrangler deploy`) before the first publish: a worker deployed
before this release serves the index and 404s every release page.

**Score:** 4

#### Pull Request

publish-page and the shared worker serve the per-release notes pages
