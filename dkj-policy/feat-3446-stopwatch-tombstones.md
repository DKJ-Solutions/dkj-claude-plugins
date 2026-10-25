## feat/3446-stopwatch-tombstones

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

A tombstone list in the deleting machine's own stopwatch ref, honoured by every reader, undoable, written by a script in a skill.

The design was decided on the issue thread (October 25, 2026): tombstones live in the deleting
machine's **own** ref (one writer per ref holds), name a run id or a whole label, are undoable, and are
written by a script in a skill while the pages stay read-only (#3323).

Undo has to work from any machine, not only from the one that hid the run, so an entry carries a time
and a hide/show flag, and per run id or label the newest entry across all machines wins.

### CREATE

- [x] `scripts/lib/stopwatch-sync-lib.ps1`: hide entries (parse, bound, read/save `stopwatch-hidden.json`, newest-wins state, `Select-StopwatchVisibleRuns`), carried in the payload only when there are any, read back from every other machine's ref
- [x] `scripts/dashboard/stopwatch-sync.ps1`: publishes this machine's entries; a hide file that does not read stops the publish
- [x] `scripts/dashboard/serve-connector-dashboard.ps1`: the pages leave out what any machine hid, this machine's own entries before they are synced
- [x] `scripts/dashboard/stopwatch-hide.ps1` (`-RunId`, `-Label`, `-Show`, `-List`, `-NoSync`) and the repo-local `stopwatch-hide` skill

### TEST

- [x] `stopwatch-sync.tests.ps1`: newest-wins, label vs. run, exact label match, a running run never hidden, the payload round trip and its bounds, the unchanged payload without entries, and the script end to end between two clones (hide, read by the recording machine, show again, refusal): 64 passed
- [x] `stopwatch.tests.ps1`: 210 passed; `check-plugin-integrity.ps1`: 0 errors

### DEPLOY: feat/3446-stopwatch-tombstones

A Stopwatch run, or every run of a label, can now be hidden from every machine's `/stopwatch` pages,
whichever machine recorded it, and shown again from any machine:
`scripts/dashboard/stopwatch-hide.ps1 -RunId <id>` or `-Label "<label>"`, `-Show` to undo, `-List` to
see what is hidden (the `stopwatch-hide` skill). The entry goes into the hiding machine's own
`refs/stopwatch/<machine id>`, so one writer per ref still holds, and nothing is erased from any store.

**Score:** 3

#### What makes this deploy extra special

N/A -- the Stopwatch is this repo's own dev server and ships to no consumer.

**Score:** N/A

#### Pull Request

Stopwatch: delete a run or a label from any machine

