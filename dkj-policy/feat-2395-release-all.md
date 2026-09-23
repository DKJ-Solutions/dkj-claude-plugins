## feat/2395-release-all

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
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

#2395: the owner proposed a skill that clears every marker and assignee before a device switch; the
red-team verdict was a scoped version instead. `claim-issue.ps1 -Tag -ReleaseAll` releases only THIS
tag's own markers (and this account's assignee beside them), dry-run unless `-Apply`. The optional
`DKJ_OWN_ACCOUNTS` widening depends on #2394, which is still open, so it is left out of this branch.

### CREATE

- [x] `Get-OwnTagClaims` in `claim-issue-lib.ps1`: from one `gh issue list` payload, the open issues
      carrying this tag's markers -- only this tag's records, and whether this account is assigned
- [x] `claim-issue.ps1 -Tag -ReleaseAll [-Apply] [-Limit]`: its own parameter set, refused without
      `-Tag` and with `-Apply -DryRun`; warns when the read hit `-Limit`
- [x] `Remove-ClaimMarkerComments` moved ahead of every mode; `-Release`'s assignee removal became the
      shared `Remove-ClaimAssignee` helper
- [x] Plugin mirrors synced; `claim-issue` and `sweep-issues` skill pages state the bound
- [x] Review (Sebastian): a marker counts as this tag's only where its comment AUTHOR is the tag's
      account half -- a planted marker could otherwise make `-Apply` drop an assignee. The same gap in
      `-Release`, the verdict and the race predates this branch: filed as #2399
- [x] Review (Victor): the `-Limit` warning counted 1 on every payload (5.1 pipeline wrap) and could
      never fire; now the two-statement form
- [x] Review (Edith): "-Release only mean something" -> "means" for the singular refusal

### TEST

- [x] `claim-issue.tests.ps1`: 485 passed, including the new #2395 block and the planted-marker case
- [x] `native-capture.tests.ps1`: bounded-site count moved 79 -> 80 with its audit note; 352 pass
- [x] Live dry run on this repo: `[OK] no open issue carries a claim of this tag`; both refusals fire

### DEPLOY: feat/2395-release-all

`claim-issue.ps1 -Tag -ReleaseAll` releases every open issue this tag holds in one command: its own
claim markers, and this account's assignee where one of those markers sits beside it. Without `-Apply`
it only lists what it would release. Markers written by any other tag are never touched, including
another machine under the same account, and an assignee with no marker of this tag stays in place. A
marker only counts as this tag's when the comment was actually written by this tag's account, so a
comment somebody else posts with your tag in it cannot trigger a release.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

claim-issue -Tag -ReleaseAll

