## feat/dashboard-owner-groups

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

Dave asked for the dashboard index to separate BWJ repos, DKJ repos and other repos (djcylow-react).
The group is read from the owner in each manifest's `repo` slug, so a new repo needs no edit here.

### CREATE

- [x] `Get-ConnectorOwnerGroup` and `Get-DashboardOwnerGroups` in `scripts/lib/connector-dashboard-lib.ps1`
- [x] One "Connected repos" overview card (h2) with an h3 and a table per non-empty group, then the repo cards under an h2 per group
- [x] The h1 is the repo's name, `dkj-claude-plugins`
- [x] The overview tables share one fixed column set, so their columns line up
- [x] The Checkout column becomes Main: the trunk against origin's, after a `git fetch origin <trunk>` per checkout (Dave chose fetching over the last-fetch reading)
- [x] Only the trunk is shown, in the Main cell and on the repo card: the checked-out branch, uncommitted work and the branch's own ahead/behind are gone, and the card's last commit is the trunk's
- [x] In the Main column a trunk named `main` is not named again; any other trunk name stays
- [x] A checkout not on this machine reads N/A in the Main column

### TEST

- [x] `connector-dashboard.tests.ps1`: the owner mapping, the group order, the heading structure, the shared column set, the Main cell and card showing the trunk only, and an empty group left out (112 passed)
- [x] The live server on port 4871 restarted and shows BWJ 2, DKJ 3, Other 1, with each present checkout's main measured after a fetch (first load about 19 s)

### DEPLOY: feat/dashboard-owner-groups

The connector dashboard (`scripts/dashboard/serve-connector-dashboard.ps1`) now splits its index into
three groups, **BWJ repos**, **DKJ repos** and **Other repos**. Its h1 is the repo's name,
`dkj-claude-plugins`, and the one overview card, now headed **Connected repos**, carries an h3 and a
table per group, followed by the repo cards under an h2 per group. The tables share one fixed column
set, so their columns line up. The Overview's Checkout column is now **Main**: it says whether each
checkout's trunk is up to date with origin's or how many commits it is behind, measured after a
`git fetch origin <trunk>` (with prompts off), so the number is GitHub's rather than the last fetch's.
In that column a trunk named `main` is not named again, so a cell reads `24 behind`; a trunk with another name keeps it, and a repo not checked out here reads N/A. The repo card states the same, trunk named, with the trunk's last commit. The branch a checkout stands on and its
uncommitted work are no longer shown at all, since they say nothing about the trunk; the one note left
is a fetch that failed, when the count is against the last fetch. That fetch is the
dashboard's one network call and makes an uncached load slower, about 19 s here. A repo's group is read from the owner in its connector manifest's `repo`
slug (`BWJ-Development`, `DKJ-Solutions`, anything else), so a newly registered repo lands in the right
section without an edit. Inside a group the order is unchanged: worst status first, then by name. A
group with no repos is left out.

**Score:** 2

#### What makes this deploy extra special

N/A: the dashboard is a local tool for this repo's maintainers and is not shipped in any plugin.

**Score:** N/A

#### Pull Request

Connector dashboard groups repos by owner: BWJ, DKJ and other

