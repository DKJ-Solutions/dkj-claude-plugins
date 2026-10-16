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
- [x] The h1 is the repo's name, `dkj-claude-plugins`; an h2 "Connected repos" card holds the tables
- [x] A table per non-empty group, naming its group in its first column head (BWJ repos, DKJ repos, Other repos), with no heading above it
- [x] The tables share one fixed column set, so their columns line up
- [x] The Errors and Notes columns are gone; the tiles and the Issues cards still carry both
- [x] The Checkout column is gone, with no replacement: Dave tried a Main column (trunk against origin, after a fetch) and dropped it as unimportant here, so nothing fetches
- [x] The repo card shows only the trunk's last commit: no checked-out branch, uncommitted count or ahead/behind
- [x] A second card beside it, headed Issues (h2), with an h3 per group and a house `mini-card` per repo with its name as an h4

### TEST

- [x] `connector-dashboard.tests.ps1`: the owner mapping, the group order, the heading structure and the two cards, the column heads, the five-column set, the card's trunk-only last commit, and an empty group left out (108 passed)
- [x] The live server on port 4871 restarted and shows BWJ 2, DKJ 3, Other 1; an uncached load takes about 5.5 s

### DEPLOY: feat/dashboard-owner-groups

The connector dashboard (`scripts/dashboard/serve-connector-dashboard.ps1`) now groups its repos as
**BWJ repos**, **DKJ repos** and **Other repos**. A repo's group is read from the owner in its connector
manifest's `repo` slug (`BWJ-Development`, `DKJ-Solutions`, anything else), so a newly registered repo
lands in the right group without an edit; inside a group the order is unchanged, worst status first,
then by name, and a group with no repos is left out.

The page's h1 is the repo's name, `dkj-claude-plugins`. A card headed **Connected repos** holds a table
per group, the group named in the first column head, all sharing one fixed column set so their columns
line up. A second card headed **Issues** carries an h3 per group and a house `mini-card` per repo with its
details.

The Overview's **Errors** and **Notes** columns are gone: the tiles at the top count both, and each repo's own lines are in its Issues card. So is its **Checkout** column. What a checkout is checked out on and whether it holds
uncommitted work said nothing about the repo, so the card no longer shows it either: it shows the last
commit on the checkout's trunk, read from local refs. Nothing is fetched.

**Score:** 2

#### What makes this deploy extra special

N/A: the dashboard is a local tool for this repo's maintainers and is not shipped in any plugin.

**Score:** N/A

#### Pull Request

Connector dashboard groups repos by owner: BWJ, DKJ and other

