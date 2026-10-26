## fix/3491-merge-on-green-checks-scope

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

#3491 (inbound, from a private consumer): the merge-on-green template declares `contents: read` and
`pull-requests: read` only, and an explicit block sets every other scope to none. The pick step reads the
required checks with `gh pr checks --required` under that job token, so in a private repo the list is never
readable and nothing is ever picked, while every run concludes success. Verified in the tree: the pick step's
`GH_TOKEN` is `secrets.GITHUB_TOKEN`. A public repo reads check runs without the scope, which is why the source
repo never showed it. The template is never rewritten in a consumer that already has it, so a re-run of
`adopt-ci-floor` also has to name an old block, as it already does for the #2449 shape and the #2813 group.

### CREATE

- [x] `adopt-ci-floor.ps1` (and its plugin mirror): the merge-on-green template grants `checks: read` and
  `statuses: read`
- [x] `adopt-ci-floor.ps1`: `Write-MergeOnGreenScopeVerdict` names an existing runner whose block lacks either
  scope as `[scope]`, and a runner without a block as unread
- [x] `.github/workflows/merge-on-green.yml`: this repo's own runner gets the same two scopes
- [x] `adopt-ci-floor.tests.ps1`: the placed template carries both scopes; an old block draws `[scope]` naming
  both, a block missing one names only that one, and a block-less runner is said to be unread

### TEST

- [x] The gates run in `ship-pr`

### DEPLOY: fix/3491-merge-on-green-checks-scope

The merge-on-green runner that `adopt-ci-floor` places now grants its job token `checks: read` and
`statuses: read` ([#3491](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3491)). Without them a
private repo's picker could not read the required checks, so it never merged anything and every run still
concluded success. A re-run of `adopt-ci-floor` names a runner placed earlier with `[scope]` and the line(s) to
add.

**Score:** 2

#### What makes this deploy extra special

In a private repo, a pull request armed with merge-when-green now merges itself once its checks are green, where
before it waited forever with no error. A runner already placed has to be changed by hand: add the two lines
under `permissions:`, or delete the file and re-run `adopt-ci-floor -Apply`. A re-run says which.

**Score:** 4

#### Pull Request

merge-on-green: grant the pick step checks and statuses read

