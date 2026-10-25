## feat/3422-close-parked-recurrences

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

Issue #3422: closing an issue parked on a recurrence label was prose only. Verified: nothing under
`.github/` or the hooks closes such an issue. Built as a CI-floor runner that checks nothing out, so the
consumer's copy is the source's own file.

### CREATE

- [x] `.github/workflows/close-parked-recurrences.yml`: on `issues: [opened, labeled]`, never `reopened`;
  a job-level `if:` admits only an open issue whose added label (or, on `opened`, any label) is a
  recurrence label, former names included; adds `[RECORD]`, closes as not planned with one comment.
- [x] `adopt-ci-floor.ps1` (both copies): the same text as a fifth target, with the cost note and header.
- [x] `adopt-ci-floor.tests.ps1`: the placed runner equals the source file; both label lists equal
  `pr-issues-lib.ps1`'s names; no action, no secret, `issues: write` only, no expression in the run body.
- [x] Docs: `CONTRIBUTING-portable.md` (both recurrence rules, the CI-floor section), the
  `adopt-dkj-policy` Part 3 page, Sylvester's lens.

### TEST

- [x] Review: Sebastian #23 found no blocking issue; Victor #19 found that a per-issue concurrency group
  let a skipped label event cancel the pending closing run. The group is gone, a title too long for the
  prefix is closed without it, the `record`/`dossier` collision is documented, and the `if:` structure
  is pinned in test 2f.
- [x] `adopt-ci-floor.tests.ps1` 309/309 and `workflow-timeouts.tests.ps1` 74/74, run alone while
  building; the full gate is `ship-pr`'s.

### DEPLOY: feat/3422-close-parked-recurrences

An issue filed with, or given, `awaiting-recurrences` or `awaiting-recurrences-first` is now closed as not
planned automatically, with its `[RECORD]` title prefix added where missing and the label kept
([#3422](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3422)). The rule in
[`CONTRIBUTING-portable.md`](../plugins/dkj-policy/CONTRIBUTING-portable.md) was prose only, and #3410 stayed
open after it was filed parked. The new `close-parked-recurrences.yml` runner does it on `opened` and
`labeled`, never on `reopened`, so a recurrence can reopen and unlabel in either order. Every other label
event is skipped at the job level. `adopt-ci-floor` places the same file in a consumer as its fifth runner;
it checks nothing out and needs no secret.

**Score:** 3

#### What makes this deploy extra special

A consumer who re-runs `adopt-ci-floor -Apply` gets parked recurrence issues closed for them, instead of
the open list filling with issues that wait on their next instance.

**Score:** 2

#### Pull Request

Close parked recurrence issues as not planned automatically

