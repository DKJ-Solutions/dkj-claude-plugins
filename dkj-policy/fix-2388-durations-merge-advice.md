## fix/2388-durations-merge-advice

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

Resolves #2388. The issue's reason was verified in `.github/workflows/ci.yml` before the repair: the suites
step's `if:` skips on a `fold:` subject and on `steps.merge-suite-skip.outputs.skip == 'true'`, the #2303
merge-commit certificate, which answers `true` for the ordinary ship-pr merge.

### CREATE

- [x] `record-suite-durations.ps1`: the no-table throw names a PR run and states why both trunk pushes are
      normally tableless; the `.PARAMETER RunId` docstring says the same.

### TEST

- [x] Re-ran the script with `-DryRun` against `35903739236`, the `merge:` run the issue measured: it still
      refuses, now pointing to a PR run.
- [x] No test pins the throw text (grep over the tree), and no other page repeats the merge-run advice.

### DEPLOY: fix/2388-durations-merge-advice

`record-suite-durations.ps1`'s no-table refusal used to send the caller from a `fold:` run to the
`merge:` run beside it. Since the merge-commit certificate (#2303), that run normally has no suite table
either. The refusal and the `-RunId` docstring now name a PR run, the run that always has one. This prevents a
failure that already happened twice during #2304's duration re-reads: a maintainer following the throw's
advice to a second tableless run.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

record-suite-durations: the no-table refusal names a PR run, not a merge run

