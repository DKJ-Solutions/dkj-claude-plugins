## feat/2877-asana-default-assignee

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

Inbound #2877 from smartwatchbanden: a task report-issue creates arrives unassigned and gets lost on
the board. Verified against the tree: step 2's `create task` sets no assignee, and the optional Asana
seams (`Get-AsanaIssueFieldGid`, `Get-AsanaTypeFieldGid`) are read only by the procedure, with no
script and no contract entry, so a new optional seam is a three-page doc change.

### CREATE

- [x] report-issue: read `Get-AsanaDefaultAssignee` in "Before you start"; step 2 passes it as
  `assignee` on the create call, and only on a task it creates
- [x] adopt-bwj-development step 2: propose `Get-AsanaDefaultAssignee { $null }` beside the field seams
- [x] bwj-development README: list the seam with the other Asana answers

### TEST

- [~] no automated test: the seam is read by a procedure page, not by a script, so no suite reaches it

### DEPLOY: feat/2877-asana-default-assignee

`report-issue` can now assign the Asana task it creates. A new optional seam,
`Get-AsanaDefaultAssignee` in `scripts/repo-config.ps1`, names an Asana user GID, and step 2 passes
it as `assignee` on the same `create task` call
([#2877](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2877)). It applies only to a task
the procedure creates. A colleague's own ticket that is moved into `Filed` keeps its assignee.
`$null` is the default and creates the task unassigned, as before. `adopt-bwj-development` proposes the
seam, and the bwj-development README lists it.

**Score:** 2

#### What makes this deploy extra special

A store whose owner wants every new card on their own desk answers one function. The card then lands
in that person's *My Tasks* instead of waiting unseen on the board. Nothing changes until the seam is
answered.

**Score:** 3

#### Pull Request

report-issue: assign the created Asana task to a configured person

