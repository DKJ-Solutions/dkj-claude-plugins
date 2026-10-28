## fix/3619-merge-on-green-actions-read

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

#3619 (inbound, measured in smartwatchbanden#1033): #3496's `checks: read` and `statuses: read` did not make
`gh pr checks --required` readable in a private repo. gh resolves the workflow run behind every check run, and
the explicit permissions block leaves `actions` at none. A probe with `actions: read` added read the list.
Add that scope where #3491 added the other two, teach the `[scope]` advisory to name it, and make the picker
print why a required-check read failed, since the bare "unreadable" verdict hid the cause through two fixes.

### CREATE

- [x] `adopt-ci-floor.ps1`: the merge-on-green template grants `actions: read`, and `Write-MergeOnGreenScopeVerdict`
  names it when an existing runner lacks it
- [x] `.github/workflows/merge-on-green.yml`: this repo's own runner grants `actions: read` too
- [x] `pick-merge-on-green.ps1`: a failed required-check read re-asks once without discarding stderr and prints
  its first line, on the failure path only
- [x] Both scripts copied to their `plugins/dkj-policy/scripts/` mirrors

### TEST

- [x] `adopt-ci-floor.tests.ps1`: the placed template carries `actions: read`; the advisory names all three
  scopes on a bare block, the missing two on a checks-only block, and `actions: read` alone on a #3491-era block

### DEPLOY: fix/3619-merge-on-green-actions-read

The merge-on-green runner that `adopt-ci-floor` places now also grants its job token `actions: read`
([#3619](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3619)). `checks: read` and `statuses: read`
(#3491) were not enough: `gh pr checks --required` also reads the workflow run behind each check run, so a
private repo's picker still could not read its required checks and still merged nothing. A re-run of
`adopt-ci-floor` now names a runner without the scope under `[scope]`. When the required-check read
fails, the picker now prints the first line of the error instead of only "could not be read".

**Score:** 3

#### What makes this deploy extra special

In a private repo, merge-when-green had still never merged anything, and this release is the one that fixes it.
Add `actions: read` under `permissions:` in `.github/workflows/merge-on-green.yml`, or delete that file and run
`adopt-ci-floor -Apply` again. A re-run of `adopt-ci-floor` tells you whether your runner needs it.

**Score:** 3

#### Pull Request

merge-on-green: the job token also reads actions, so a private repo's picker can read its required checks

