## fix/2518-claim-issue-reads-parking-label

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

#### Scope

Inbound #2518, half 1: the single-issue route of `claim-issue` reads the issue's labels and warns on a
parking label (`needs-info` by default, the label `sweep-issues` skips on). Half 2 -- which label an
owner's choice gets at filing -- is split out as #2519, because `needs-info` already means *blocked on
the submitter* in `dkj-policy-bwj` and prescribing it is a decision, not a sentence.

### CREATE

- [x] `claim-issue-lib.ps1`: `Get-IssueLabelNames`, `Select-ParkingLabels` (now also used by
  `Get-SweepCandidates`), `Format-ParkingLabelNote`, and `Format-ClaimOpening` (the closing headline,
  moved out of the script's if-chain now that there are three verdicts to name).
- [x] `claim-issue.ps1`: `labels` on the issue read, `-SkipLabel` bound on the single-issue route with
  a `needs-info` default, the `PARKED:` verdict on claim and resume, and the headline / forward line
  pointing at it. Warns, never refuses (#1485).
- [x] Plugin mirrors of both files synced.
- [x] `claim-issue/SKILL.md`: the step list, the parameter, and a section on the parking label.

### TEST

- [x] `claim-issue.tests.ps1`: 534 passed, 0 failed -- new asserts for the label reader, the
  case-insensitive match, the stripped label name, the three-verdict headline, the wiring and the
  no-`exit` bound; the old headline asserts rewritten behaviourally against `Format-ClaimOpening`.
- [x] Live dry run on #2518 with `-SkipLabel inbound`: the `PARKED:` verdict and the resume line print;
  without it the run is unchanged.

### DEPLOY: fix/2518-claim-issue-reads-parking-label

`claim-issue` on a single issue now reads the issue's labels. Where one parks the issue with somebody
else -- `needs-info` by default, the label `sweep-issues` already skips on; `-SkipLabel` replaces the
default -- it prints a `PARKED:` verdict, and the closing `[OK]` points at that verdict instead of
saying *the work starts here*. It still claims: a label can be stale, so this warns and never refuses
([#2518](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2518)). Which label an owner's
open choice should carry when it is filed is
[#2519](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2519).

**Score:** 3

#### What makes this deploy extra special

N/A -- a pickup step inside the workflow; no subscriber of a service sees it.

**Score:** N/A

#### Pull Request

claim-issue warns when the named issue carries a parking label
