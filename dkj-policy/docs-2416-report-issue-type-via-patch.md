## docs/2416-report-issue-type-via-patch

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

### CREATE

- [x] `report-issue` step 1: file without `--type`, then set the type with `gh api --method PATCH ... -f type=`
- [x] `WORKFLOW-portable.md` classification table: name the same `PATCH` route instead of `--type`

### TEST

- [x] `gh issue create --help` on gh 2.74.0 lists no `--type`; the `PATCH` route was measured on #2414 and #2415 (the issue's own evidence)

### DEPLOY: docs/2416-report-issue-type-via-patch

`report-issue`'s step 1 prescribed `gh issue create --type`, which `gh 2.74.0` rejects as an unknown
flag, so the create failed and no issue was filed. The step now files with the labels only and sets
the type straight after with `gh api --method PATCH repos/<owner>/<repo>/issues/<n> -f type=<Type>` --
the route the page already used for an issue filed earlier, and one that works on old and new `gh`
alike. `WORKFLOW-portable.md`'s classification table names the same route. Closes #2416.

**Score:** 2

#### What makes this deploy extra special

A consumer filing through `report-issue` on an older `gh` no longer has the create fail outright; the
issue lands and is typed in the same step.

**Score:** 3

#### Pull Request

report-issue sets the issue type after creation, since gh 2.74.0 has no --type flag

