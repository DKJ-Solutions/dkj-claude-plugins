## fix/3547-freshness-restart-after-update

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

Inbound #3547: `release-freshness-sessioncheck` said `[CURRENT]` after `update-plugins` had rewritten
every install record inside a running process, followed by `/clear`, while an older payload still ran.
Verified: the hook reads only the records, and a record names what the NEXT process loads. Repair: hold
each relevant record's `lastUpdated` against the Claude Code process's start (`CLAUDE_PID`, else the
nearest `claude(.exe)` ancestor) and answer `[RESTART]` ahead of every other verdict.

### CREATE

- [x] `release-freshness-sessioncheck.ps1`: the restart check, `[RESTART]` outranking `[MIXED]`, `[CURRENT]`
  and `[BEHIND]`; record collection shared by the mix and restart checks; `-ProcessStartOverride` for tests.
- [x] `release-freshness-sessioncheck.tests.ps1`: the measured shape, updated-before-start, restart over
  mixed, and an absent or unparseable `lastUpdated`; every run pins the process start.

### TEST

- [x] The suite: 45 asserts green.
- [x] Live in this session without an override: `CLAUDE_PID` resolved, records older than the process
  start, `[CURRENT]` as before -- no false restart.

### DEPLOY: fix/3547-freshness-restart-after-update

A session whose dkj plugins were updated after Claude Code started -- `update-plugins` inside the
session, then `/clear` -- is no longer told it is up to date while older copies still run. The release
check now says which plugins were updated after the start, and that only restarting Claude Code loads
them ([#3547](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3547)).

**Score:** 2

#### What makes this deploy extra special

N/A: a corrected session-start line; nothing a consumer runs or configures changes.

**Score:** N/A

#### Pull Request

release-freshness-sessioncheck: say [RESTART] when install records were updated after the process started

Plugins: dkj-policy

