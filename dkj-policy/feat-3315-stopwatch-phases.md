## feat/3315-stopwatch-phases

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

The second half of #3315 (option 3, Maikel, October 23, 2026): each finished Stopwatch run is split into
phases read from this checkout's Claude Code session transcripts, shown beside the hand-set laps.

#### Design

- Every second of a run goes to the FIRST phase going at that moment: ship-pr (CI wait, merge, fold), the
  local gates and suites, subagents, branch and claim, any other tool call, then Claude's own turn. A second
  in which no session was busy is waiting on the person. So a backgrounded ship that Claude writes beside is
  the ship, and the phases always add up to the run. A script name counts only in a Bash or PowerShell
  command, so a subagent brief that names ship-pr is a subagent.
- The page and the cache carry phase names and seconds only, never transcript text (Sebastian).
- A backgrounded call ends at its `<task-notification>` (it carries the `tool-use-id`), not at the immediate
  "running in background" result. Measured on #3320's own session: the ship was 21:39 of 48:45.
- ship-pr prints no timestamps, so CI wait, merge and fold stay one phase; splitting them needs ship-pr to
  write its own step times, which is a change to that script rather than to this page.
- A run's window is closed once it stops, so its phases are read once and cached beside the store
  (`stopwatch-phases.json`, outside the tree), each transcript in one pass for every run the cache lacks.
  Nothing is cached when no transcript was read. Reading the 49-minute window took 0.3 s.
- The existing "Phases" column is now "Laps", so "phases" means the transcript split only (Edith).
- The issue's plan named "the transcript reader in `closeout-lib.ps1`"; that lib has none. The readers are
  in `measure-closeouts.ps1` and `artifact-harvest-lib.ps1`, and this one follows the latter's cheap,
  line-filtered read.

### CREATE

- [x] `stopwatch-lib.ps1`: the transcript dir, the phase table, the event reader, the phase split, the cache
  and the table cell; the page gets a "From the transcripts" column
- [x] `serve-connector-dashboard.ps1`: reads the cache for `/stopwatch`; `-TranscriptDir` for tests

### TEST

- [x] `stopwatch.tests.ps1`: a fixture transcript (prompt, new-branch, a backgrounded ship-pr ended by its
  notification, a sidechain line, a cut-off line, a second prompt) split into exact phases; clipping; the
  cache written, reused, re-read when the end moves, recomputed when it does not read, and not written when
  no transcript was read (69 green)
- [x] Smoke test on a throwaway server: `/stopwatch` with a run over #3320's session renders its six phases,
  Waiting on you among them
- [x] `check-plugin-integrity.ps1`: 0 errors
- [x] Review: Victor, Sebastian and Edith. Applied: a background call is recognised only from a shell or
  agent call's own answer (a Read saying "in the background" ran to the end of the run), the timeout's "moved
  to the background" counts too, a notification counts only as its own record, a script name only in a shell
  command, one pass per transcript, no cache without a transcript read, and the header, the purity note and
  the Laps column brought in line

### DEPLOY: feat/3315-stopwatch-phases

A finished Stopwatch run now shows where its time went, read from this repo's session transcripts: the ship
(CI wait, merge and fold), the local gates and tests, subagents, branch and claim, other tool calls, Claude's
own thinking and writing, and the time it waited on you, each with its share of the run. Every second counts
once, so the phases add up to the run. The hand-set laps stay beside them, in a column now called Laps.

**Score:** 2

#### What makes this deploy extra special

The hub is this repo's own dev server, so nothing a consumer takes changes.

**Score:** N/A

#### Pull Request

Stopwatch phases read from the session transcripts

