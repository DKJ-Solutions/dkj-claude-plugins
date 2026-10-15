## feat/3047-dev-preview-placeholder

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

#### Why this stops for the owner's eye

The placeholder is a rendered page, so the branch parks for a look and opens no pull request (sweep
step 5). Issue #3047 lists four needs; this branch covers all four in the source. The per-repo adoption
(a Simple Browser route in each consumer) is the consumers' own issues.

### CREATE

- [x] Vendor the pinned house style (`house-style-v3`) into `plugins/dkj-policy/dkj-solutions/assets/house-style/`
- [x] `scripts/lib/dev-preview-placeholder.ps1`: the page and the request rules, with no I/O
- [x] `scripts/preview/serve-placeholder.ps1`: a loopback `TcpListener` server, taking the repo name from its working directory
- [x] `dev-preview-rules.ps1`: `Get-DevPreviewPlaceholder` (ports 4880-4889) and `Test-DevPreviewVsCodeRoute`
- [x] The hook: no seam means the placeholder; the line names the missing Simple Browser route, and a routed port opens in VS Code
- [x] README (the rule in prose and the route) and the house-style skill's repoint sentence (the second vendored copy)

### TEST

- [x] `dev-preview-sessionstart.tests.ps1`: group 1d (answer, route test, page, escaping, host rules, checksums of the plugin copy) and group 2 (placeholder started, served over HTTP, reused, routed, another checkout's not taken), 99 passed

### DEPLOY: feat/3047-dev-preview-placeholder

The dev-preview hook in `dkj-solutions` no longer stays silent in a repo that states no `Get-DevPreview`
([#3047](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3047)). It starts a plugin-shipped
placeholder page on the first free port from 4880 to 4889, built on the house style, that names the repo
and shows how to add a preview of its own. The placeholder is reused and never doubled, like any repo's
server. Where the repo's `.vscode/settings.json` routes that port to the Simple Browser, it opens there.
Otherwise the session-start line names the route to add. The plugin now carries its own vendored house
style, and a test holds it to the skill's checksums.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions repo now opens a dev preview at session start. A repo with nothing to serve yet gets
a placeholder page at `http://localhost:4880/` (or the next free port up to 4889) that says how to state
`Get-DevPreview`, instead of nothing. To see it in VS Code's Simple Browser, add
`"localhost:4880": "simpleBrowser.open"` under `workbench.externalUriOpeners` in the repo's
`.vscode/settings.json`. The line at session start tells you when that route is missing.

**Score:** 3

#### Pull Request

Open a placeholder dev preview when a DKJ-Solutions repo states no Get-DevPreview

