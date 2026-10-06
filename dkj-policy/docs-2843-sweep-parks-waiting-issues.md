## docs/2843-sweep-parks-waiting-issues

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

The sweep page tells a session to hold a waiting issue out with `-SkipIssue`. That writes nothing, so
every later sweep judges the same issue again. The page now has it set the matching `awaiting-*` label
plus a one-line comment instead, and keeps `-SkipIssue` for a hold-out that is not a wait.

### CREATE

- [x] `skills/sweep-issues/SKILL.md`: a waiting `free` issue is parked with its label (step 1); the end
  condition and the close-out name that outcome

### TEST

- [x] No suite pins the changed text (`held out` / `SkipIssue` searched in `scripts/tests`); the gate
  runs in `ship-pr`

### DEPLOY: docs/2843-sweep-parks-waiting-issues

The `sweep-issues` page now says what to do with a `free` issue that turns out to be waiting on a live
push, a release, another issue's pull request, an external event or the owner's choice. Set the
matching `awaiting-*` label and leave a one-line comment saying what it waits on. Until now the page
held such an issue out with `-SkipIssue`, which lasts one run, so every sweep judged it again.
`-SkipIssue` remains for a hold-out that is not a wait.

**Score:** 3

#### What makes this deploy extra special

If you run sweeps, an issue that waits on you is now labelled the first time a sweep meets it, and the
next sweep skips it instead of judging it again and listing it in its close-out once more.

**Score:** 3

#### Pull Request

sweep-issues parks a waiting issue with its awaiting-* label instead of holding it out with -SkipIssue

