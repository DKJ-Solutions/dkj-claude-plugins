## fix/2803-fold-head-check

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

Inbound [#2803](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2803), verified: `fold-changelog-entry.ps1`
commits with `git commit -- <paths>` and pushes with a plain `git push`, and reads neither the branch nor HEAD
in between, so a tree another session switches mid-run takes the fold commit with it. The guard is in the
fold rather than in ship-pr, because the fold is the step that writes. The temporary-worktree idea from the
issue is not built: the three reads close the race this report measured, and a worktree for every fold is a
larger change than the defect needs.

### CREATE

- [x] The fold reads branch + HEAD at the start, before the commit, and before the push (with `-Commit`/`-Push`), and refuses on any movement
- [x] New `-ExpectBranch`: refuses before folding when the checkout is on another branch
- [x] ship-pr passes `-ExpectBranch main`; both scripts mirrored into `plugins/dkj-policy/scripts/release/`
- [x] Fixture cases and source pins in `fold-changelog.tests.ps1`

### TEST

- [x] `fold-changelog.tests.ps1`: 289 pass, the raced-push cases among them

### DEPLOY: fix/2803-fold-head-check

`fold-changelog-entry.ps1` now refuses to write a fold commit anywhere but where it started. With `-Commit`
or `-Push` it reads the branch and HEAD three times: at the start, before the commit, and before the push.
It refuses on any movement, so a second session switching a shared working tree mid-run no longer takes the
fold commit onto its own branch. A new `-ExpectBranch` parameter refuses before anything is folded when the
checkout is not on the named branch, and `ship-pr` passes `main`.

**Score:** 3

#### What makes this deploy extra special

When another session switches the working tree under `ship-pr`, the fold now stops with the merge done and
the fold still owed, and it says why. Before, the `fold:` commit was written and pushed onto that session's
branch, and `ship-pr` still reported "folded on main".

**Score:** 2

#### Pull Request

The fold refuses to commit or push off the trunk

