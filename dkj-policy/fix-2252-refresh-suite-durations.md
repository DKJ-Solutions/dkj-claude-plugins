## fix/2252-refresh-suite-durations

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

Run record-suite-durations.ps1 against post-merge CI runs on main and commit the regenerated scripts/tests/suite-durations.json.

### CREATE

- [x] Confirmed #2252's reason still holds: `#2236` merged at `1fa18227`, so post-merge CI runs now exist.
- [x] Ran `scripts/maintenance/record-suite-durations.ps1` against three post-merge merge-commit CI runs
      on `main` -- `35664490957` (#2256), `35671058308` (#2257), `35682991043` (#2258) -- each of which
      printed a full 121-row per-suite table, and committed the regenerated
      `scripts/tests/suite-durations.json`.
- [x] Measured what the refresh actually moved, rather than assuming it moved only #2252's suite.

### TEST

- [x] `-DryRun` first: three runs read, 121 suite rows each, no suite left without a row and no
      `no rows for N suite(s)` warning -- so nothing in the tree is charged the maximum any more.
- [x] The lint gate and all suites, via `open-pr.ps1`.

### DEPLOY: fix/2252-refresh-suite-durations

`scripts/tests/suite-durations.json` is re-recorded from three post-merge CI runs, and it repairs more
than the row #2252 reported. `script-contract.tests.ps1` moves from 98.8s to **208.9s**, which is the
+12 child spawns #2236 added plus the contention of a pool that has grown since. But the file was also
**eleven days and 30 suites stale**: it listed 91 of the 121 suites in the tree, and
`Invoke-TestSuiteGate` charges an unlisted suite the largest recorded value -- so it was packing 30
suites at 290.2s each when they total **266.5s between them**. The packer believed the lightest
thirty suites in the pool were its heaviest. Every row is now a measured mean rather than a ceiling.

**Score:** 2

#### What makes this deploy extra special

N/A. The file is this repo's own CI packing hint; nothing in it ships in a plugin payload, so no
consumer reads it and none of their gates change.

**Score:** N/A

#### Pull Request

Refresh the recorded CI suite durations from post-2236 runs