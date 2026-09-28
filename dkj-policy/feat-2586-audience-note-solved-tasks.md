## feat/2586-audience-note-solved-tasks

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

#2586 and #2570 in one branch (Dave's choice, September 28, 2026). One input decides both documents:
**the live-push record**, which says which of the release range's theme files are on live after the
push.

- `live-preflight` writes the record beside its push command: one `live <path>` or `hold <path>` line per
  theme file in the range, with deletions written as `hold` because a `--only` push cannot carry them. A
  person who holds a file back edits `live` to `hold`. The file goes to the temp directory, because the
  cut needs a clean trunk.
- `cut-release -LivePushRecord <file>` reads it. Each entry's own changed paths come from its
  `merge: <branch> (#n)` commit. If an entry touched a `hold` path, it is **not live**.
  - **#2570**: the GitHub body moves not-live entries from `## What landed` to `## Not live yet`, and names
    the held paths.
  - **#2586, criterion 3**: not-live entries leave the audience draft.
- **#2586, criteria 1+2**: a new optional seam `Get-ReleaseNoteTaskLink` (marker, URL format, label)
  switches the audience section to *solved tasks*. It keeps an entry only if it touched a path in the
  record (storefront) and is live, and only the issues it closed that carry the marker. Each issue becomes
  `### <issue title>` plus the task link, and the entry's PR is not linked. This form needs `gh`, and a
  live-stage repo that runs it without a record refuses unless `-NoLivePushRecord` is passed.
- Pure rules in a new shared lib `live-record-lib.ps1`, mirrored into dkj-policy and dkj-subagents-shopify.

### CREATE

- [ ] `scripts/lib/live-record-lib.ps1`: record format/parse, merge-commit lookup, per-entry live state, task-item rendering
- [ ] `live-preflight.ps1` writes the record and prints its path
- [ ] `cut-release.ps1`: `-LivePushRecord` / `-NoLivePushRecord`, per-entry paths, `Not live yet`, audience filtering, task form
- [ ] `release-lib.ps1`: `Build-GitHubReleaseBody -NotLive`, `Build-ReleaseNoteDraft` task-item body
- [ ] seam `Get-ReleaseNoteTaskLink`: contract record, blueprint, source repo-config
- [ ] mirrors registered and rebuilt
- [ ] docs: cut-release SKILL, RELEASES-portable, live-preflight SKILL, dkj-policy-bwj proposal of the seam
- [ ] tests: lib suite, cut-release drive case with a record, contract count

### TEST

### DEPLOY: feat/2586-audience-note-solved-tasks

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

The audience note drafts from solved Asana tasks, and the GitHub body separates what is not live yet

