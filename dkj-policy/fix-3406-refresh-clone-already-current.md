## fix/3406-refresh-clone-already-current

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

Inbound #3406. Verified in the code: step 1 counted every non-zero `marketplace update` as a failure,
whatever state the clone was in. The lock holder being the session itself is the reporter's inference and
stays one; the repair does not depend on it.

### CREATE

- [x] A failed refresh asks `git ls-remote origin HEAD` of the clone; at its own HEAD it is a `WARNING`, not
  a failure, and the summary says how many.
- [x] A `FAILED` refresh whose output carries `EBUSY` names the lock and its likely holder.
- [x] The plugin mirror synced; the skill page says both.

### TEST

- [x] `update-plugins.tests.ps1` 6b-6d, against a real local origin: at origin's HEAD exit 0, behind it
  exit 1, and the EBUSY line.

### DEPLOY: fix/3406-refresh-clone-already-current

`update-plugins` no longer exits 1 when a marketplace refresh fails while the clone is already at its
origin's HEAD ([#3406](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3406)). On Windows the refresh
can fail with `EBUSY` while a session holds the clone. Measured: the run exited 1 while its own receipt read
all plugins current. A failed refresh now asks the clone's origin for its HEAD. Where that matches the clone,
the refresh prints as a `WARNING` and the run can still exit 0. A refresh that really left the clone behind
stays `FAILED`, and an `EBUSY` one says to close the other sessions and rerun.

**Score:** 2

#### What makes this deploy extra special

A consumer running `update-plugins` from inside a session on Windows gets an exit code that agrees with its
receipt, instead of a red run after an update that went through.

**Score:** 2

#### Pull Request

update-plugins counts a failed refresh as a warning when the clone is already at its remote's HEAD

