## feat/3044-awaiting-pull-external

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

Issue [#3044](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3044), built to the owner's
proposal in its comment: a separate label `awaiting-pull-external`, rather than stretching
`awaiting-pull` or `awaiting-action-external`. Done in the shape of #2977 (commit 9aded751), which added
the review pair to the same family.

### CREATE

- [x] The label in `adopt-triage-labels.ps1`'s fallback and `repo-config.ps1`'s `Get-TriageLabels`, the contract's Default/Returns, and the regenerated config blueprint.
- [x] Every skip list: `claim-issue`'s default, the `-Candidates` examples, `sweep-issues` step 1, the dashboard's parking set and its label text.
- [x] `CONTRIBUTING-portable.md`'s definition (comes off once the upstream work is available here), the count of the family, and the lenses and skill pages that list it.
- [x] The label created on this tracker (a description over 100 characters is refused by GitHub, so it is the short one).

### TEST

- [x] `adopt-triage-labels` 186, `repo-config` 106, `claim-issue` 590, `pr-issues` 1153, `issue-dashboard` 451, `script-contract` 421, `config-blueprint` 228: all green.

### DEPLOY: feat/3044-awaiting-pull-external

A new parking label, `awaiting-pull-external`, for an issue whose blocker is a pull request in another
repo ([#3044](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3044)). Unlike `awaiting-pull`,
it does not come off at the upstream merge but once that work is released and taken here. Both pickup
routes skip it, `claim-issue` warns on it, the issue dashboard shows it as waiting, and
`adopt-triage-labels` prints the line that creates it.

**Score:** 3

#### What makes this deploy extra special

An issue that waits on work in another repo, such as a consumer waiting on a new `dkj-brandbook` token,
now has its own label: `awaiting-pull-external`. Sweeps skip it until the upstream work has been
released and picked up here, where `awaiting-pull` came off at the upstream merge, two steps too early.
Run `adopt-triage-labels` to get the `gh label create` line for your tracker.

**Score:** 3

#### Pull Request

awaiting-pull-external: a parking label for a blocker outside this repo

