## feat/2996-dashboard-version-column

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

The version comes from the check's own per-plugin machine-record line, read by its text whatever its
tag, so the dashboard still reads no install records itself and no tag list is hard-coded again (the
issue's note on #2995). A visible result: parked for the owner's look, no PR until then.

#### Parked for the owner's eye

Look at the Overview table on the connector dashboard (http://localhost:4872/, served from this
branch): the new `Installed` column between `Plugins` and `Errors`.

### CREATE

- [x] `scripts/lib/connector-dashboard-lib.ps1`: `Get-ConnectorInstalledVersion` and
  `Format-DashboardInstalledVersion`, and the `Installed` column in the Overview table
- [x] `scripts/tests/connector-dashboard.tests.ps1`: group 1b2, the version cases

### TEST

- [x] `connector-dashboard.tests.ps1` standalone: 78 passed, 0 failed
- [x] The page served from this branch on this machine: four checkouts here read `v5.18.0`, the two
  not on this machine read `-`
- [x] `open-pr.ps1 -GatesOnly` before the park

### DEPLOY: feat/2996-dashboard-version-column

The connector dashboard's Overview table now has an `Installed` column: the plugin version each
repo's checkout runs on this machine, read from the check's machine-record line. Where a repo's
plugins differ, the cell shows the lowest version and the plugin it belongs to. A repo not on this
machine shows `-`, and a checkout with no install record says `no record`. A lagging repo is now
visible across all registered repos at a glance, without opening each card
([#2996](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2996)).

**Score:** 2

#### What makes this deploy extra special

N/A: the dashboard is a local maintenance view of this repo, and no consumer receives it.

**Score:** N/A

#### Pull Request

Connector dashboard shows each repo's installed plugin version

