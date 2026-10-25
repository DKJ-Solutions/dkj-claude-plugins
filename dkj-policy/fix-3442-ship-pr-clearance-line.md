## fix/3442-ship-pr-clearance-line

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

#3442: a backgrounded `ship-pr` never says the session can be cleared, although an armed PR is finished
by the merge-on-green sweep if the run dies. Verified: arming happens before the wait (#2319/#2393), the
sweep runs ship-pr itself and folds, and nothing runs between arming and the wait block.

### CREATE

- [x] `Get-ShipClearanceVerdict` in `merge-on-green-lib.ps1`: clearable only where the PR is armed, the repo has `merge-on-green.yml`, the sweep does not refuse the diff and the checkout is back on the trunk; otherwise names the first fact that fails
- [x] `ship-pr.ps1` records whether arming succeeded and prints the verdict right under the wait line; the second-terminal advice prints only where the clearance is withheld
- [x] Plugin mirrors of both scripts updated
- [x] `ship-pr` skill page: the unmeasured-`/clear` paragraph replaced by the two lines, and a backgrounding session closes out on the line as shape A

### TEST

- [x] `merge-on-green-lib.tests.ps1`: the clearable shape, each of the five withheld shapes naming its reason, and the wiring in `ship-pr.ps1` (251 pass)

### DEPLOY: fix/3442-ship-pr-clearance-line

`ship-pr` now says, seconds after it starts waiting on CI, whether the session can be cleared:
`Session can be cleared: PR #N is armed and this checkout is back on the trunk` where the merge-on-green
sweep would finish the ship if the run died, or `Session can NOT be cleared yet:` naming what holds it.
A session that backgrounds the ship waits for that line and closes out on it, rather than on a progress
note.

**Score:** 3

#### What makes this deploy extra special

Whoever ships with `ship-pr` is told plainly when they can clear the session and start the next thing,
instead of being left to guess while CI runs.

**Score:** 3

#### Pull Request

ship-pr says when the session can be cleared during the CI wait

