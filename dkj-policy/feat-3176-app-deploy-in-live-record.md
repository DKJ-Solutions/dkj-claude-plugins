## feat/3176-app-deploy-in-live-record

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

Design chosen by the owner in the sweep session (October 19, 2026): app files become ordinary `live`
lines in the live-push record, a skipped deploy is marked `hold` by hand like a held theme file, and
notify-live reads the same record through a mirrored live-record-lib.

### CREATE

- [x] live-record-lib: `Format-LivePushRecord -AppPaths` writes one `live` line per app file, with a header line
- [x] live-preflight: the record is written for an app deploy too, app-only included, and names notify-live
- [x] notify-live: `-LivePushRecord`, an issue whose PR changed a `hold` path is held, an unreadable merge is UNREAD
- [x] live-record-lib mirrored into bwj-development (`live-record-lib-bwj`), prepare-release's step 7 names the record
- [x] the live-preflight and notify-live skill pages

### TEST

- [x] live-record-lib.tests.ps1: app lines, header, held app-only entry is not-live and storefront (103 pass)
- [x] bwj-development.tests.ps1: a fixture repo run reads a record, refuses a bad one, notes a missing one (783 pass)

### DEPLOY: feat/3176-app-deploy-in-live-record

live-preflight writes one `live <path>` line per file under `Get-ShopifyAppRoot` into the live-push
record, and writes the record for an app-only release too. A deploy that is not run is marked `hold` by
hand, like a held theme file. `notify-live -LivePushRecord <path>` reads the same record through a
mirrored `live-record-lib`. It holds an issue whose PR changed a `hold` path, and it refuses a record it
cannot parse. prepare-release's step 7 tells you to pass the record (#3176).

**Score:** 2

#### What makes this deploy extra special

A store that ships a Shopify app no longer has an app-only change announced as live to its requester,
or listed as landed by the cut, before `shopify app deploy` has run. Pass the record to notify-live.

**Score:** 3

#### Pull Request

notify-live treats an app-only change as live before the shopify app deploy has run

