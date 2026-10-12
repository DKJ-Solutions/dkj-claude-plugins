## fix/2923-tier0-na-names-the-score-line

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

Inbound #2923, verified: `Read-EntryTierSections` said "under tier 0" with no heading, and `open-pr` ended every impact refusal with "Correct the table", including on the section shape, which has no table.

### CREATE

- [x] `entry-scaffold-lib.ps1` (+ mirror): the tier-0 N/A error names the heading its Score line sits under, and adds a swap diagnosis when an audience tier carries a number
- [x] `open-pr.ps1` (+ mirror): "Correct the Score line(s) named above" on the section shape; the table wording stays for the table shape
- [~] the optional scaffold cue: dropped, because the refusal now names the heading, which is the cheap half the issue asked for first

### TEST

- [x] `entry-scaffold.tests.ps1`: the refusal names the DEPLOY heading, a scored audience tier is diagnosed as a swap, and an all-N/A entry is not; 901/901, and `branch-entry-gate.tests.ps1` 82/82

### DEPLOY: fix/2923-tier0-na-names-the-score-line

The refusal for a tier-0 `N/A` now names the heading its Score line sits under, so the reader no longer has to work out which line "tier 0" means. When the audience tier carries a number at the same time, the refusal says the two answers look swapped and how to move them. `open-pr` no longer says "Correct the table" for an entry that has no table
([#2923](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2923)).

**Score:** 2

#### What makes this deploy extra special

A session that put its two scores in each other's slot gets one refusal that names the fix, not a retry loop. Measured in smartwatchbanden, where the loop ran across most of an hour.

**Score:** 2

#### Pull Request

The tier-0 N/A refusal names the Score line it means and spots a swapped pair
