## fix/2816-runner-group-verdict

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

Issue #2816, narrowed on the issue itself: an existing write runner is already read on a re-run for its
pin (#2333) and merge-on-green.yml for its checkout shape (#2449). What was missing is the same advisory
for #2813's concurrency-group fix in fold-on-merge.yml and verify-resolved.yml. A whole-file diff
against the template is not the repair: trunk names and pins differ per consumer, so it would fire
everywhere.

### CREATE

- [x] `Write-RunnerGroupVerdict` in `adopt-ci-floor.ps1` (+ plugin mirror): silent on the template's
      own group line (read from the template, not restated), `[group]` on the pre-#2813 line, "could not
      be read" on anything else; the file stays untouched

### TEST

- [x] `adopt-ci-floor.tests.ps1`: current line silent, both pre-#2813 runners reported once each, file
      unchanged, neither shape reported as unread (286 passed)

### DEPLOY: fix/2816-runner-group-verdict

`adopt-ci-floor` now reports a `[group]` advisory when an existing `fold-on-merge.yml` or
`verify-resolved.yml` still carries the single `github.ref`-keyed concurrency group #2813 replaced,
beside the `[pin]` line it already printed. The scaffolder still never rewrites a placed runner, so
this re-run is the one moment that shape gets noticed (#2816).

**Score:** 2

#### What makes this deploy extra special

A consumer re-running `adopt-ci-floor` is told, file by file, whether its fold and resolves runners
still carry the concurrency group that can cancel a merge's pending run, and how to fix it: replace
the `group:` line, or delete the file and re-run with `-Apply`.

**Score:** 2

#### Pull Request

adopt-ci-floor says when an existing fold or resolves runner still carries the concurrency group #2813 replaced

