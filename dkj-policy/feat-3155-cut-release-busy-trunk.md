## feat/3155-cut-release-busy-trunk

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

The owner chose the design on #3155: a retry whose proof is the main-push CI run for the new tip, not a
quiet-trunk signal.

### CREATE

- [x] `gate-lib.ps1`: `ConvertTo-CommitCheckBucketsJson` (commit check-runs into the PR certificate's shape) and `Get-TrunkCatchUpDecision` (when a catch-up is allowed)
- [x] `cut-release.ps1`: the after-gates origin check catches up over a behind-only trunk (certificate, wait, ff-only, child re-run with `-CatchUpCertifiedSha`/`-CatchUpRound`), and the gates skip only on the certified HEAD
- [x] Plugin mirrors synced, and the `cut-release` skill page documents the catch-up (the `[skill-param]` lint found the two parameters undocumented)
- [x] Review findings taken: only GitHub Actions' own check-runs count (security), a short registration grace for a push run not yet registered, the child cut streams through `Out-Host`, and the gate line says the certificate was handed in (code review)

### TEST

- [x] `gate-lib.tests.ps1`: bucket mapping, every catch-up refusal, and the wiring in cut-release (288 pass)
- [x] `cut-release-drive.tests.ps1`: a certified re-run cuts without its gates, spent rounds refuse with nothing written, and a first run before the gates does not catch up (101 pass)
- [x] `native-capture.tests.ps1`: bounded-site count 97 -> 98, audited
- [x] The real check-runs read against the current `origin/main` tip certifies `lint-en-tests`
- [x] End to end in a throwaway clone with a `gh` shim: a commit landed on origin during the lint gate, the cut caught up, re-ran, skipped only the certified gates and cut on top of the landed commit (`-NoPush`)

### DEPLOY: feat/3155-cut-release-busy-trunk

A release cut no longer has to start over when a merge lands while its gates run. After the gates, a
`main` that is only behind `origin/main` is caught up rather than refused when the CI run that the push
to the trunk started has proved the new tip green: the cut waits for that run while it is still going,
fast-forwards, and runs itself again on the new tip. That second run re-reads every pending entry and
re-runs every content gate, and it skips only the lint and test gates CI just ran on that exact commit. A
`main` that is ahead, an unnamed or red check, an unreadable run, or a trunk still moving after three
rounds refuse as before (#2899), with the reason no catch-up was made. Measured at the v5.25.0 cut, two
refusals in a row cost about 30 minutes and postponed the release.

**Score:** 3

#### What makes this deploy extra special

A maintainer cutting a release in a repo whose trunk merges often can now finish the cut in one run,
provided the repo names its test check and its slug, instead of retrying the whole gate until the trunk
goes quiet.

**Score:** 3

#### Pull Request

cut-release finishes on a busy trunk by fast-forwarding over merges certified by main-push CI
