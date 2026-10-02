## feat/2723-awaiting-label-family

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

Issue #2723 (Dave, October 2, 2026): the three purple labels each mark an issue that WAITS on something,
so they become one family. By colour on this tracker (`5319E7`, `d4c5f9`) they are:

| was | becomes |
|---|---|
| `needs-info` | `awaiting-more-info` |
| `awaiting-recurrence` | `awaiting-first-recurrence` |
| `record` (`dossier` until #2683) | `awaiting-more-recurrences` |

`needs-decision` is light blue and stays. Same shape as #2683: the new name is the only one prescribed,
and every former name stays matched wherever a label is read, because a consumer's tracker keeps its old
names until somebody renames them there. The noun *record* and the `[RECORD]` title prefix are unchanged.

### CREATE

- [x] `pr-issues-lib.ps1`: the record label is `awaiting-more-recurrences`, with `record` and `dossier` as
      matched former names; a new `Get-FormerTriageLabelNames` is the one rename table.
- [x] `adopt-triage-labels.ps1` + `repo-config.ps1` (and the regenerated blueprint): the canonical set
      uses the new names, and a tracker carrying a former name gets a `gh label edit` rename, not a create.
- [x] `claim-issue.ps1` default parking list, `sweep-issues`' `-SkipLabel` line, and the dashboard worker's
      `PARKING_LABELS`: all eight names, current first.
- [x] `open-pr.ps1`'s record gate message names both former names.
- [x] `dkj-policy-bwj` Asana mirror: default `NeedsInfoLabel` is `awaiting-more-info`; under that default
      `needs-info` still parks the card (`Test-NeedsInfoLabelPresent`), an explicit map is untouched.
- [x] Docs (Tessa): CONTRIBUTING-portable, the claim-issue / sweep-issues / issue-dashboard skills,
      scripts/README, Derek's lens, and the dkj-policy-bwj WORKFLOW, README and two skills; one heading
      anchor renamed with its one inbound link.
- [~] `dkj-policy/dashboard/org-*` deployed worker copies: refreshed by the dashboard deploy, not by hand
      -- they already lagged #2683 the same way.
- [~] Renaming the three labels on this tracker (`gh label edit`, so its issues keep them) is not a branch
      step: it runs right after the merge, so a session's pickup routes already know the new names when it does.

### TEST

- [x] Suites green: pr-issues, repo-config, adopt-triage-labels, claim-issue, dkj-policy-bwj,
      issue-dashboard, config-blueprint, script-contract, shared-scripts. New asserts: the `record` former
      name is caught by the record gate; the rename table; adopt prints renames for `record` and
      `awaiting-recurrence`; the Asana mirror parks on `needs-info` under the default map only.
- [x] `check-plugin-integrity.ps1`: 0 errors.

### DEPLOY: feat/2723-awaiting-label-family

This tracker's three purple labels become one family named for what each one waits on:
`awaiting-more-info`, `awaiting-first-recurrence` and `awaiting-more-recurrences`. Every gate and pickup
route reads the old names too.

**Score:** 2

#### What makes this deploy extra special

The three waiting labels a consumer's tracker carries are renamed: `needs-info` -> `awaiting-more-info`,
`awaiting-recurrence` -> `awaiting-first-recurrence`, `record` -> `awaiting-more-recurrences`. Nothing
breaks on update. `open-pr` still refuses to close an issue carrying `record` or `dossier`, both pickup
routes and the dashboard still skip every old name, and a dkj-policy-bwj board still parks a `needs-info`
card in its blocked column. `adopt-triage-labels` prints the `gh label edit` that renames each label in
place, issues and all.

**Score:** 3

#### Pull Request

