## fix/dashboard-house-style-v2

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

#2986 repointed the `house-style` skill to `house-style-v2`, but the connector dashboard vendors its own
copy under `scripts/dashboard/house-style/` and that copy stayed on v1 (both sha256 values matched the v1
row), with a hand-built Theme card around `DKJTheme.picker`. So the new settings button never appeared.

### CREATE

- [x] Vendor `house-style.css` and `house-theme.js` from tag `house-style-v2`, sha256 checked against the skill's table and the pre-inline rules scanned
- [x] `connector-dashboard-lib.ps1`: the Theme card goes, `DKJTheme.settings` sits in the header controls beside "Re-run the check", English labels
- [x] `connector-dashboard.tests.ps1`: assert the page uses `DKJTheme.settings` and no longer `DKJTheme.picker`

### TEST

- [x] `connector-dashboard.tests.ps1` green (58 passed); the dashboard on :4870 restarted and serves `DKJTheme.settings`
- [x] The owner has looked at the dashboard (visible result) -- the settings button works (Dave, October 13, 2026)

### DEPLOY: fix/dashboard-house-style-v2

The connector dashboard now runs on `house-style-v2`: its vendored stylesheet and theme script were
still the v1 copies after #2986 repointed the skill. The theme choice moved from a card at the bottom of
the page to the house settings button in the header.

**Score:** 2

#### What makes this deploy extra special

N/A -- the dashboard is served only on this repo's own checkout; no consumer receives it.

**Score:** N/A

#### Pull Request

Connector dashboard on house-style-v2, with the settings button

