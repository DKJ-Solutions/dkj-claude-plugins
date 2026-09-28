## fix/2572-roster-sync-child-stderr

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

The diagnostic #2572's pickup comment names, and nothing more. There is one instance, and two reasons fit
it: a line lost from stdout, or a child that threw on stderr before it printed the finding. So this adds
no repair, only the evidence that would tell the two apart on the next recurrence. The issue stays open.

### CREATE

- [x] `Invoke-Ps` captures stderr on a separate `Err` property, under `Continue` as `Invoke-Hook` already does; `Out` stays stdout only
- [x] `Write-ChildStderr` prints the child's exit and stderr when 11ua's or 11ub's finding pattern is absent

### TEST

- [x] `roster-sync.tests.ps1` standalone: 414 pass, 0 fail

### DEPLOY: fix/2572-roster-sync-child-stderr

`roster-sync.tests.ps1` now keeps its child's stderr, and when 11ua's or 11ub's finding is missing it
prints that stderr with the exit code. A failure under a loaded gate then shows whether the check threw
or its line was lost. That is the evidence #2572 lacked. This is a diagnostic, not a fix, so the issue
stays open. (#2572)

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

roster-sync.tests: keep the child's stderr, and show it when 11ua/11ub's finding is missing

