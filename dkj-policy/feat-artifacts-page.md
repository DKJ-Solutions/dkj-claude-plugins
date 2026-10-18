## feat/artifacts-page

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

Requested by the owner: a dev-server page listing every claude.ai Artifact ever made for this repo. The
claude.ai account holds Artifacts from several repos, so the list is taken from this repo's own session
transcripts (Artifact publish calls and Claude Docs creates) rather than from the account listing, and
recorded in a committed register so both owners see the same list.

### CREATE

- [x] `scripts/dashboard/artifacts.json`: the register, five Artifacts found in the transcripts
- [x] `scripts/lib/dev-pages-lib.ps1`: `Test-ArtifactUrl`, `ConvertFrom-ArtifactRegister`, `Format-ArtifactsPageHtml`, and the hub's Pages card links it
- [x] `scripts/dashboard/serve-connector-dashboard.ps1`: the `/artifacts` route

### TEST

- [x] `scripts/tests/dev-pages.tests.ps1`: link check, model, page and the register in the tree (72 passed)
- [x] `connector-dashboard.tests.ps1` still green (126 passed)
- [x] Served on a spare port: `/artifacts` answers 200 with five links, and the hub links it

### DEPLOY: feat/artifacts-page

The dev server gains an Artifacts page (`/artifacts`), linked from the Repo hub: every claude.ai
Artifact a session in this repo has published -- pages, decks and documents -- newest first, each with
its kind, its dates and one line on what it shows. The list is a committed register,
`scripts/dashboard/artifacts.json`, seeded from this repo's session transcripts; a url that is not a
claude.ai Artifact link is shown without an href, so a register edit cannot inject a link.

**Score:** 2

#### What makes this deploy extra special

N/A -- the dev server is this repo's own maintenance tool; nothing a plugin user installs changes.

**Score:** N/A

#### Pull Request

The dev server lists every Artifact made for this repo

