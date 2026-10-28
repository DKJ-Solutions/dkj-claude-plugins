## fix/3620-report-orphan-hub-processes

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

#3620's second half. #3625 tied a suite's servers to the suite; what is still missing is something that
REPORTS a hub process that has outlived the run that started it, which the owner asked to be watched far
better to save memory. One check script, `check-hub-processes.ps1`, judged by a pure verdict in
`tidy-lib.ps1`, run by a new SessionStart check and by a new `tidy-machine` lane 13. A missing parent is
not the test, because the healthy session hub has none either; the verdict reads each process's own
command line. It reports and stops nothing. The 5.34.0 watcher's cause is not established here; such a
watcher is now named (its server has ended).

### CREATE

- [x] `tidy-lib.ps1`: `Get-HubProcessVerdict` (orphan watcher, owner gone, stale cache version, working-tree
  server whose launcher ended, unreadable command line)
- [x] `scripts/lint/check-hub-processes.ps1`: reads the process table once, reports each finding with its
  memory and a `Stop-Process` line, and counts the processes it cannot read
- [x] `hooks/hub-processes-sessioncheck.ps1`: runs that check at session start, through the dispatcher
- [x] `tidy-machine.ps1`: lane 13 delegates to the same check
- [x] Registered in `shared-scripts-lib.ps1`, mirrored, listed in the scripts README and the skill page

### TEST

- [x] `tidy-lib.tests.ps1`: the verdict asserts, and a lane-13 run on a pinned process table
- [x] Review (Victor, Sebastian) taken in: a suite's server is judged by its watcher, since its hook launcher
  has always exited; a launcher born after the server is a reused pid; no stale verdict without a readable
  register; the match anchored to the `-File` invocation; a cache segment is named only when it has a
  plugin-name or version shape
- [x] The session check by hand on a fixture table (report shown, `[INFO]` left out) and on this machine
- [x] `check-plugin-integrity.ps1` 0 errors; `shared-scripts`, `sessioncheck-dispatch`, `tidy-lib` suites green

### DEPLOY: fix/3620-report-orphan-hub-processes

A session now starts with a line naming every hub server and `dev-preview-watch` process that has outlived
the run that started it, with its memory and the `Stop-Process` line that ends it
([#3620](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3620)). `tidy-machine` lists the same
thing as its lane 13. One killed gate had left 26 such processes holding about 2.3 GB, and nothing said
so. The healthy session hub is left alone, and nothing is stopped for you.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

name every hub process that outlived the run that started it, at session start and in tidy-machine
