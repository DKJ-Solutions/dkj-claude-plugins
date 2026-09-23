## fix/2375-boardless-status-map-line

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
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

#2375: `Resolve-GithubStatusMap` in the `asana-mirror` template accepted #1536's board-less declaration and
then printed it as `field '', .`. Verified in the template: the only print line interpolates `FieldName`
and the status pairs unconditionally. Give the declaration its own sentence, worded as the stage-floor
line already words it.

### CREATE

- [x] `asana-mirror.ps1`: an empty `FieldName` prints "this repo has no project board, so stage floors
  derive from the issue itself"; the board path is unchanged

### TEST

- [x] `dkj-policy-bwj.tests.ps1`: two asserts against a temp repo-config declaring no board -- red without
  the fix, green with it (383 pass)
- [x] Gates run by `ship-pr` itself

### DEPLOY: fix/2375-boardless-status-map-line

The `asana-mirror` run printed a repo's deliberate "no project board" declaration as an empty field and a
dangling comma, so its CI log could not tell that answer from a broken map. It now says the repo has no
project board and that stage floors come from the issue itself.

**Score:** 1

#### What makes this deploy extra special

Visible in a board-less store's `asana-mirror` CI log once its template copy is refreshed (xoxowildhearts
declared itself board-less the day this was filed); nothing it does changes.

**Score:** 1

#### Pull Request

asana-mirror: a board-less repo's status-map line says there is no board

