## docs/3013-connected-live-duplicate

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

#### Scope, checked against the tree

- #3013 names `archive-theme` as a third script that duplicates live. It does not: it refuses the live
  theme and archives with `theme pull`, so it is out of scope. The duplicating callers are
  `backup-live-theme` (also through `live-preflight`) and `push-preview`.
- `Get-CutOrderWarning` did need a connected-mode wording: its line said "pushed", a step a connected
  store never runs.

### CREATE

- [x] `Get-CutOrderWarning -DeployBranch`: promote-then-cut wording; `backup-live-theme` reads `Get-ShopifyLiveDeployBranch` and passes it (both mirrors)
- [x] `theme-lifecycle-rules.tests.ps1`: five asserts on the connected wording
- [x] `theme-lifecycle` skill: a Git-connected section on the detached backup
- [x] `push-preview` skill: what a detached copy means for a preview
- [x] `THEME-LIFECYCLE-portable.md`: promote-then-cut and the detached copy

### TEST

- [x] `theme-lifecycle-rules.tests.ps1` standalone: 139 pass, 0 fail

### DEPLOY: docs/3013-connected-live-duplicate

The theme-lifecycle pages now say what a `shopify theme duplicate` of a Git-connected live theme is: a detached copy that does not follow later commits on the deploy branch and can drop files silently (measured in `BWJ-Development/smartwatchbanden#943`). For `backup-live-theme` that is what a backup should be, and its verify step catches the drop. For `push-preview` it means a preview shows live as it was when it was created. `THEME-LIFECYCLE-portable.md` states the order as promote-then-cut for such a store. `backup-live-theme`'s order warning reads `Get-ShopifyLiveDeployBranch` and speaks of a promotion instead of a push there ([#3013](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3013), part of [#2998](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2998)).

**Score:** 2

#### What makes this deploy extra special

A store whose live theme deploys from a branch reads, on the pages it already uses, why its preview does not follow `live` and why its backup is still sound. A store that has not set the seam sees no difference.

**Score:** 2

#### Pull Request

theme-lifecycle pages: a duplicate of a connected live theme is a detached copy

