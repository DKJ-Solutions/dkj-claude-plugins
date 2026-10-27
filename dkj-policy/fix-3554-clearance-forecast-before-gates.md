## fix/3554-clearance-forecast-before-gates

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

#3554: `ship-pr` prints its clearance verdict only after the local gate, so a session that backgrounds it
closes with "I'm waiting". Verified against the code: the verdict is computed in the wait block, after
step 1. **One half of the issue's proposal does not hold**: at launch the session is never clearable,
because the local gate runs in this process and the PR does not exist until it passes. What IS known
from the diff is whether the run will BECOME clearable (no -NoMerge, a sweep runner, no seam-file
refusal), so the early line is a forecast, and both close-out forms say to leave the window open, for
how long, and that nothing waits on the owner.

### CREATE

- [x] `Get-ShipClearanceForecast` in `merge-on-green-lib.ps1`, built on the picker's own `Get-MergeOnGreenExecutedPathHit`, fail-closed on an unreadable diff.
- [x] `ship-pr.ps1` step 0d prints the forecast and the close-out to relay before step 1's gates.
- [x] Both mirrors under `plugins/dkj-policy/scripts/` copied byte-identical.
- [x] Chris's persona: a backgrounded run relays the forecast's close-out, never "I'm waiting".

### TEST

- [x] `merge-on-green-lib.tests.ps1`: the clearable forecast, the four held cases (seam, -NoMerge, no runner, unreadable diff), no close-out form saying it waits, and the forecast wired before step 1 -- 269 pass, 0 fail.

### DEPLOY: fix/3554-clearance-forecast-before-gates

`ship-pr` now prints a **clearance forecast** before its gates
([#3554](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3554)): whether this run will become
clearable once its PR is armed, or stays needed until the merge and the fold have run, for example because
the diff touches a repo-owned seam the merge-on-green sweep will not ship. It also prints the close-out a
session should relay when it backgrounds the run. That close-out opens with "Nothing waits on you" and
says how long to leave the window open. The later "Session can be cleared" verdict is unchanged.

**Score:** 3

#### What makes this deploy extra special

When you hand `ship-pr` to the background, the session can now tell you straight away whether you will
be able to close it once the PR is open, or must keep the window open until the merge, and it no longer
says it is "waiting".

**Score:** 3

#### Pull Request

ship-pr says before its gates whether this run will become clearable, with the close-out to relay

