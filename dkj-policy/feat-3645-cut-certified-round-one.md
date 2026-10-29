## feat/3645-cut-certified-round-one

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

#3645: a first round of `cut-release` reads the main-push CI certificate for HEAD the way the
catch-up does (#3155), and skips the local lint and test gates on green. The in-flight wait is
bounded below the local gate's cost (300s against 382-422s uncontended; main-push runs measured at
220-590s over 15 runs, October 28-29, 2026).

### CREATE

- [x] `cut-release.ps1` (both copies): the catch-up's certificate read moved into
      `Read-MainPushCertificate`, shared by the catch-up and the first round
- [x] The first round asks it only when the origin check before the gates measured main = origin/main
      (`$script:CutHeadIsOrigin`), so `-SkipOriginCheck` keeps the local gates
- [x] `gate-lib.tests.ps1`: wiring asserts for the first round
- [x] `cut-release` SKILL.md: the first round's paragraph

### TEST

- [x] `gate-lib.tests.ps1` green (328 pass), parser clean on `cut-release.ps1`
- [~] A live first-round read on a real cut -- only a cut exercises it, and a cut is the owner's to ask for

### DEPLOY: feat/3645-cut-certified-round-one

A release cut whose `main` already equals `origin/main` now asks the CI run that the push to the
trunk started whether it has proved that exact commit green, before running the lint and test gates
locally. On green it skips both and says so; a run still in flight is waited on for up to five
minutes; anything else runs the gates as before. On the v5.36.0 cut the local gate was about half of
the 15 minutes. The certificate reader is now one function, shared with the catch-up (#3155).

**Score:** 3

#### What makes this deploy extra special

A maintainer cutting a release in a repo that names its CI check (`Get-CiTestCheckName`) and slug
sees the cut skip the local gate when CI already proved the commit, and finish several minutes
sooner.

**Score:** 2

#### Pull Request

cut-release: skip the round-one local gate when the main-push CI run certified HEAD

