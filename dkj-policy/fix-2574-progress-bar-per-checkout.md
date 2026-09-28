## fix/2574-progress-bar-per-checkout

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

Inbound #2574 (dkj-music-library, 5.9.0): a ship running in another repo's window drew its bar in this
session's statusline.

#### The reason, verified

Read in the tree: `Get-RunProgressRoot` is one per-user directory, the record written by
`Write-RunProgress` has no checkout field, and `show-progress.ps1` drew every live record without looking
at the payload's workspace (which it read only afterwards, for the context line).

#### The two choices the issue left to the source

- **Scope is the checkout, not the repo.** A lane is a separate worktree at its own path, so its runs
  draw in the lane's window. Matching on the remote URL would need a git call per write or per read, and
  this lib exists to avoid exactly that cost.
- **A record without the field is shown, as before.** Hiding it would make a run from an older writer
  invisible, and it disappears after the next release anyway.

### CREATE

- [x] `Write-RunProgress` stamps `workspace`, defaulting to the writer's current directory (no subprocess).
- [x] `Test-RunProgressInWorkspace`: path containment in either direction, case-insensitive; either side
      empty matches.
- [x] `Get-LiveRunProgress -Workspace` filters what it returns and still reaps every dead record.
- [x] `show-progress.ps1` reads the payload before the bars and scopes them to `workspace.project_dir`,
      then `current_dir`, then `CLAUDE_PROJECT_DIR`, and never to its own file location.
- [x] Mirrors copied: `plugins/dkj-policy` (lib and statusline) and `plugins/dkj-subagents/dkj-subagents-shopify` (lib).

### TEST

- [x] `run-progress.tests.ps1` section 13b: the matcher, the default workspace, the filter, the legacy
      record, and an end-to-end statusline run that draws this checkout's run and not the other one.
      76/76 green; exits 1 against the old lib and statusline.
- [x] The helper now clears `CLAUDE_PROJECT_DIR` for its child and escapes the payload's quotes (5.1
      strips a bare `"` from a native argument), so the existing asserts do not depend on where the
      gate runs.
- [x] Neighbours green: `shared-scripts`, `source-repo-guard`, `adopt-statusline`.

### DEPLOY: fix/2574-progress-bar-per-checkout

The statusline's progress bar now shows only the runs of the checkout the session is in (inbound
[#2574](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2574)). Records sit in one directory
per machine, so a ship in another repo's window used to draw in every session, and read as a gate running
in the repo in front of you. Each record now carries its writer's working directory, and the statusline
draws a record only when that path and the session's workspace contain each other. A record from an
older writer, or a session whose payload names no workspace, is shown as before.

**Score:** 2

#### What makes this deploy extra special

Anyone working in two repos at once sees only their own repo's gate and ship in each window, instead of a
bar that looks like work running where it is not.

**Score:** 2

#### Pull Request

The statusline draws only the progress of runs in this session's own checkout

