## fix/3078-ship-pr-diverged-trunk

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

Inbound #3078 was verified against the tree before the repair. Step 0 never compared the local `main` with
`origin/main`, and step 5's failed fast-forward printed "the FOLD IS STILL OWED" without reading
`origin/main`. The report suggested two halves, (a) and (b), and this branch does both.

### CREATE

- [x] step 0c in `ship-pr.ps1`: refuse a local `main` ahead of `origin/main` before anything is pushed,
  printing the log and the backup-and-realign pair (not under a queue, a fold left to CI, or `-TrustedRoot`)
- [x] step 5: on a failed fast-forward, read `origin/main` for the entry and the branch document's
  absence before saying the fold is owed; a found fold skips the fold and step 5c prints the realign lines
- [x] the mirror under `plugins/dkj-policy/scripts/release/`, and the `ship-pr` skill page

### TEST

- [x] `fold-changelog.tests.ps1`: step 0c sits before step 1 and is gated to the local-trunk folds, and the
  upstream read sits between the ff merge and the owed refusal, needs both halves, and skips the fold
  (300 pass)

### DEPLOY: fix/3078-ship-pr-diverged-trunk

`ship-pr` no longer merges a PR it cannot fold locally (inbound #3078). When this checkout's `main` carries
commits that `origin/main` lacks, usually the redundant fold commit of an earlier ship that lost the fold
race, the run now stops before anything is pushed and prints the log to read and the two commands that
realign the trunk. When the fast-forward still fails after the merge, it first checks whether `origin/main`
already carries the fold. If it does, it says so instead of reporting a fold that is still owed.

**Score:** 3 -- a false "fold is still owed" after a merge, met in dkj-brandbook on PR #167

#### What makes this deploy extra special

A maintainer who ships several branches in a row with `fold-on-merge` active is no longer left with a
merged PR and a refusal that names a state that does not exist. The stop now comes before the merge, where
it costs nothing.

**Score:** 3

#### Pull Request

ship-pr refuses a trunk ahead of origin before the merge, and checks upstream before saying the fold is owed

