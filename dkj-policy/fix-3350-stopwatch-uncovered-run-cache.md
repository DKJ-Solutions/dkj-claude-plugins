## fix/3350-stopwatch-uncovered-run-cache

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

#### Covered means a transcript spans the start, with a minute's slack

The issue proposes caching a run only when a transcript whose first event is at or before the run's start
was read. The start is stamped by the prompt hook (`Invoke-StopwatchHookEvent -Hook Prompt`), which can run
before the prompt's own record reaches the transcript, so the first record of a session that opens with
the marked prompt can be a few moments *after* the start. A transcript therefore covers a run when its first
event is no later than one minute after the start and it was last written at or after the start.

An uncovered run is also left out of the transcripts read, so a run pruned long ago does not stretch the
read window back to its start on every page load. It costs one first-line read per candidate file.

`feat/3349-stopwatch-shared-runs` (no PR yet) publishes these cached phases to other machines. This branch
fixes the cache it publishes, and touches none of that branch's sync code.

### CREATE

- [x] `stopwatch-lib.ps1`: `Get-StopwatchTranscriptFirstStamp`; `Get-StopwatchTranscriptCache` reads, caches and returns only runs a transcript covers, re-judges a cached entry with no session, and drops one nothing covers from the cache file

### TEST

- [x] `stopwatch.tests.ps1`: a pruned run beside a newer transcript is neither returned nor cached, an entry cached as all waiting before this change is dropped, a transcript starting 30 s after the start still covers the run, and the existing cache asserts are updated to the new rule (131 passed, 0 failed)

### DEPLOY: fix/3350-stopwatch-uncovered-run-cache

The Stopwatch no longer files a run as 100% "Waiting on you" when the transcripts that covered it are gone
([#3350](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3350)). It used to cache a finished
run's phases as soon as any transcript was read, so an old run whose transcripts had been pruned was
computed from nothing and kept that way. Now a run is read and cached only when a transcript spans its
start. A run with no such transcript shows "No phases read for this run yet", and an entry already cached
with no session is checked again and dropped when nothing covers it.

**Score:** 2

#### What makes this deploy extra special

N/A: the Stopwatch is this repo's own dev page, and no consumer runs it.

**Score:** N/A

#### Pull Request

Stopwatch: a run no transcript covers is no longer cached as all waiting

