## feat/2784-awaiting-event-label

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

Inbound #2784 (Dave, from a consumer): a fifth purple parking label, `awaiting-event`, for an issue that
waits on an external event with a known date. Verified on pickup: the tracker carries four parking
labels and none of them fits. Built on the same touch set as `awaiting-pull` (#2757), placed right after it.

### CREATE

- [x] Add `awaiting-event` (`5319E7`) to `Get-TriageLabels` and adopt-triage-labels' built-in list, right
  after `awaiting-pull`, with the reasoning in repo-config's header.
- [x] Add it to the claim and sweep skip defaults (both copies of claim-issue, claim-issue-lib's
  docstring, the two skill pages) and to the issue dashboard's `PARKING_LABELS` and `PARKED_BECAUSE`.
- [x] Document it in `CONTRIBUTING-portable.md`, the scripts README, the issue-dashboard skill and the
  05-05 lens; regenerate the config blueprint. Also correct two counts that were already stale before
  this branch: the contract record's "the same seven labels" (and the script-contract assert that
  pinned it) and CONTRIBUTING's "seven typed by hand".

### TEST

- [x] adopt-triage-labels (106), claim-issue (560), repo-config (82), issue-dashboard (416) and
  pr-issues (1144) all green, including a new assert that `awaiting-event` parks on the dashboard and
  the fallback and the seam now agree on nine literals.

### DEPLOY: feat/2784-awaiting-event-label

New parking label `awaiting-event`, purple like the rest of the awaiting-* family, for an issue that
waits on an external event or date, such as a launch or a third party's release
([#2784](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2784)). The claim and sweep routes
skip it by default and the issue dashboard shows it as parked. The issue states the event or date, and
the label comes off once it has happened.

**Score:** 2

#### What makes this deploy extra special

For a consumer who runs `adopt-triage-labels`: it now offers one more `gh label create` line, for
`awaiting-event`. A sweep no longer has to hold a date-bound issue out by hand with `-SkipIssue`.

**Score:** 2

#### Pull Request

A fifth parking label: awaiting-event

