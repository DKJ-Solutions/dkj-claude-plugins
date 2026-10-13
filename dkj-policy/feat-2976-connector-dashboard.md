## feat/2976-connector-dashboard

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

#### The request

Maikel, October 13, 2026: run the dev-preview SessionStart hook in this repo too, and serve a dashboard
with an overview of every connected repo. Issue #2976.

#### Shape

- Enable `dkj-solutions` here, import its extension in the root `CLAUDE.md`, and register it in this
  repo's own connector record.
- State `Get-DevPreview` in `scripts/repo-config.ps1`, ports 4870-4879.
- A dependency-free PowerShell server on `127.0.0.1` (`TcpListener`, so the hook can recognise it as
  this checkout's), which parses `check-connectors.ps1 -SkipDrift` rather than re-implementing it.
- The page uses a vendored copy of the house style at `house-style-v1`, checksums verified.

### CREATE

- [x] `scripts/lib/connector-dashboard-lib.ps1`: parse, status, Host guard, escaping, the page
- [x] `scripts/dashboard/serve-connector-dashboard.ps1` and the vendored house style beside it
- [x] `Get-DevPreview` in `scripts/repo-config.ps1`
- [x] `dkj-solutions` enabled and installed at project scope; `CLAUDE.md` import; connector record
- [x] Docs that named the enabled set: `this-repo.md`, `SPECIALISTS.md`, Sylvester's lens, the plugin README

### TEST

- [x] `scripts/tests/connector-dashboard.tests.ps1`: 57 asserts -- the rules, a real server on a free port, and the page from a fixture tree (a checkout with no upstream, one outside the scope root, no check)
- [x] Reviews: Victor (code) and Sebastian (security); every finding repaired -- git stderr under `Stop` blanked the page, one deadline and an 8 KB cap per request, HEAD without a body, checkouts held to the scope root, cross-site requests refused and `/refresh` throttled
- [x] The tree's hook run twice against this checkout: `started` on 4870, then `already running`
- [x] The live page: 200 with six repos; a foreign Host 403, POST 405, `/refresh` 303
- [x] The owner's look at the page (visible result): approved by Maikel, October 13, 2026

### DEPLOY: feat/2976-connector-dashboard

This repo now runs the `dkj-solutions` dev-preview hook, and what it starts is a **connector dashboard**
([#2976](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2976)): one page on
`http://localhost:4870/` with every repo registered under `connectors/`, its status, its plugins, its
local checkout's branch and state, and every error and note `check-connectors.ps1` reports for it, worst
first. It reads the check's own report rather than a second copy of its rules, binds to `127.0.0.1` only
and refuses a foreign `Host`. The hook itself is still unreleased, so it starts the dashboard from the
first session after the next release; until then it starts by hand
(`scripts/dashboard/serve-connector-dashboard.ps1 -Port 4870`).

**Score:** 3

#### What makes this deploy extra special

Nothing a consumer runs changes: the dashboard and its seam are this repo's own.

**Score:** N/A

#### Pull Request

Connector dashboard served through the dev-preview hook

