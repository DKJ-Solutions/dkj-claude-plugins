## feat/2683-rename-dossier-label-to-record

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

Rename the dossier label to record everywhere it is read or prescribed, keeping dossier as a recognised legacy name so a consumer whose tracker still carries it stays protected.

### CREATE

#### Scope

Only the LABEL is renamed. "Dossier" also names the branch document in older prose and code ("branch
dossier", "pre-dossier entry", "the dossier form"); that is a different concept and is untouched.

- [x] `pr-issues-lib.ps1`: `Get-DossierLabelName` returns `record`; new `Get-DossierLabelNames` adds the
  legacy `dossier`, and `Get-DossierClosingFindings` matches every name, so `open-pr`'s refusal holds on a
  tracker that has not renamed yet. The refusal text says `record` and names the former name.
- [x] `claim-issue.ps1`: the single-issue route's default parking labels gain `record`, keeping `dossier`.
  The sweep command lines in `claim-issue` and `sweep-issues` pass both.
- [x] `adopt-triage-labels.ps1` and `repo-config.ps1` `Get-TriageLabels`: the canonical label is `record`.
  Where a tracker still has `dossier`, the script prints `gh label edit 'dossier' --name 'record'` instead
  of a create, so every issue moves with the label rather than splitting the kind across two names.
- [x] Issue dashboard: `PARKING_LABELS` and the parked-because text read `record` and the legacy name.
- [x] Docs: `CONTRIBUTING-portable.md` (the label section and the `awaiting-recurrence` cross-references),
  the `claim-issue`, `sweep-issues` and `issue-dashboard` skills, `scripts/README.md`, and Derek's lens
  (which also corrects "`dossier`, which stays sweepable", stale since September 30).
- [x] Mirrors and blueprint regenerated (`build-shared-scripts.ps1`, `build-config-blueprint.ps1`).
- [~] Renaming this tracker's own label (`gh label edit dossier --name record`) is not a branch step: it
  runs right after the merge, because until then the trunk's gate matches only `dossier`.

### TEST

- [x] Suites run locally, all green: `pr-issues`, `claim-issue`, `adopt-triage-labels` (new case 4b: a
  tracker carrying `Dossier` gets the rename line and no create), `repo-config`, `issue-dashboard` (the
  each-label-parks assert now follows the list's length), `script-contract`, `shared-scripts`.
- [x] Review: Victor (code), Edith (copy), Sebastian (security). No correctness or security finding.
  Applied: the legacy-name paragraph no longer splits the list it introduces; the remaining label prose in
  `repo-config.ps1`, `pr-issues-lib.ps1`, `open-pr.ps1` and `claim-issue.ps1` says `record`; the
  former-name map in `adopt-triage-labels.ps1` is built once, from `Get-DossierLabelNames`, instead of a
  second literal inside the loop. Two pre-existing findings filed: #2687 (typographic quotes in
  `Format-SingleQuotedArg`) and #2688 (case-sensitive parking labels on the dashboard).

### DEPLOY: feat/2683-rename-dossier-label-to-record

Repo-internal half: this tracker's collecting issues carry `record` instead of `dossier`, and every
gate and pickup route reads both names.

**Score:** 2

#### What makes this deploy extra special

A consumer's collecting-issue label is now called `record`. Nothing breaks on update: `open-pr` still
refuses to close an issue carrying `dossier`, and both pickup routes still skip it. Running
`adopt-triage-labels` prints the one `gh label edit` that renames the label in place, issues and all.

**Score:** 3

#### Pull Request

The collecting-issue label is renamed from dossier to record

