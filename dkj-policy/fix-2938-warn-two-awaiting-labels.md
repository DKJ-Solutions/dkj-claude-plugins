## fix/2938-warn-two-awaiting-labels

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

Print one advisory line when an issue's labels match two or more of the -SkipLabel set, on the claim route and on -Candidates.

### CREATE

- [x] `Format-ParkingLabelConflict` in `claim-issue-lib.ps1`: one advisory line when two or more distinct parking labels matched, empty otherwise
- [x] Single-issue route prints it under the `PARKED:` verdict; `-Candidates` appends it to the skip reason
- [x] Plugin mirrors synced; the `claim-issue` skill page documents it

### TEST

- [x] `claim-issue.tests.ps1`: 590 passed, 0 failed -- the pair is named, one label and a case-only repeat stay silent, tracker text is stripped, the sweep still skips and names the pair, and the single-issue arm calls it without refusing

### DEPLOY: fix/2938-warn-two-awaiting-labels

`claim-issue` now reads the rule [#2936](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2936)
wrote down, that an issue carries at most one `awaiting-*` label. Where an issue carries two or more
parking labels, the single-issue claim prints a `TWO PARKING LABELS:` line under its `PARKED:` verdict,
and `-Candidates` adds the same sentence to the skip reason. It is advisory only, refuses nothing, and
makes no extra `gh` call ([#2938](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2938)).

**Score:** 2

#### What makes this deploy extra special

A session claiming or sweeping an issue with two parking labels now gets told which ones they are,
instead of having to spot the second label itself. The failure this prevents is the lapsed label that
nobody takes off.

**Score:** 1

#### Pull Request

claim-issue warns when an issue carries two awaiting-* labels

