## feat/3174-release-day-app-deploy

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

Inbound #3174 from smartwatchbanden: a store that also ships a Shopify app (under `extensions/`) has no
release-day step that takes an app change live, because only `shopify app deploy` does. Verified: no
`app deploy` or `extensions` anywhere in `prepare-release` or `live-preflight`, and `Get-LivePushRows`
holds those files as `not-a-theme-path`. The seam is named `Get-ShopifyAppRoot` (the issue's
`Get-AppExtensionRoot` was "a seam such as"), after the plugin's other `Get-Shopify*` seams. The
optional `notify-live` point is filed as #3176.

### CREATE

- [x] `live-push-rules.ps1` (source, mirrored to both plugins): `Test-ShopifyAppRoot`,
  `Get-ShopifyAppDeployPaths`, `Format-ShopifyAppDeployCommand` -- pure, print only
- [x] `live-preflight.ps1` (source + mirror): reads the seam, lists `app` files at step 3, an `app deploy`
  step, an app-only release is a note, and a green run prints the command
- [x] `prepare-release.ps1` + `Format-ReleaseRunbook`: the same listing at step 4 and a runbook step 2b
- [x] Docs: shopify README seam table, `live-preflight` and `prepare-release` skill pages
- [x] Filed #3176 for the `notify-live` half

### TEST

- [x] `live-push-rules.tests.ps1`: 201 pass (root validation, path selection, command, the throw)
- [x] `bwj-development.tests.ps1`: 722 pass (the runbook's 2b, its absence, app-only, unprintable root)
- [x] The full gate runs in `ship-pr`

### DEPLOY: feat/3174-release-day-app-deploy

A store repo that also ships a Shopify app can name its folder with a new optional seam,
`Get-ShopifyAppRoot` (e.g. `extensions`). `live-preflight` then lists the release's files under it,
reports them as their own step, treats an app-only release as a note instead of "nothing to push", and
ends a green run with `shopify app deploy --path <folder>`; `prepare-release` puts the same command in
the runbook as step 2b. The command is printed for a person to run and never run (#3174).

**Score:** 3

#### What makes this deploy extra special

A BWJ store with a Shopify app beside its theme gets its app changes onto release day: answer
`Get-ShopifyAppRoot` in `scripts/repo-config.ps1`, and the preflight and the runbook print the
`shopify app deploy` the owner runs, so a merged `extensions/` change no longer waits with no route live.
Unanswered, nothing changes.

**Score:** 3

#### Pull Request

The release-day skills list a store's app changes and print the shopify app deploy for the owner

