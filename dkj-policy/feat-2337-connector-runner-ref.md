## feat/2337-connector-runner-ref

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

#### Scope

[#2337](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2337), unblocked by #2345 (#2333's pin).
`check-connectors.ps1` reads a registered consumer's runners for check 6; it now also reads the `ref:` of
the checkout that brings this repo in, but only in a runner that holds a write credential, because the
read-only runners track `main` on purpose (#1805). It reports that ref as moving (a branch, or no `ref:` at
all) or as a pin behind this tree's dkj-policy version. The report is an `[INFO]`, not an `[ERROR]`: the
runner works and is exposed, and until a release carries #2333 every consumer's own scaffolder still
writes `main`.

### CREATE

- [x] `consumer-runner-lib.ps1`: move the checkout-block walk into `Get-SharedCheckoutBlock` so the path
      reader and the new ref reader use one recogniser; add `Get-SharedScriptPin` and
      `Test-WorkflowHoldsWriteCredential`.
- [x] `check-connectors.ps1`: check 6d (`Write-RunnerPinFinding`) on both routes, the disk and
      `-RemoteRunners`, plus the header entry.
- [x] Tests: `connectors.tests.ps1` 12o-12t and 13c2; `adopt-ci-floor.tests.ps1` section 11 reads what the
      scaffolder writes back through the lib (writer and reader agree).

### TEST

- [x] `connectors.tests.ps1` 436/0, `adopt-ci-floor.tests.ps1` 232/0, `adopt-workflow-folder.tests.ps1` 96/0.
- [x] Real register under `-RemoteRunners`: five write runners on `ref: main` across
      BWJ-Development/smartwatchbanden (2) and BWJ-Development/xoxowildhearts (3); no `branch-entry.yml`
      flagged.

### DEPLOY: feat/2337-connector-runner-ref

`check-connectors.ps1` now reports a registered consumer's write runner that fetches this repo's scripts at
a moving ref, or pinned behind the current dkj-policy release
([#2337](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2337)). This is the source-side half of
#2333's pin: a consumer nobody re-runs `adopt-ci-floor` in no longer stays invisible on `ref: main` beside
`FOLD_PUSH_TOKEN`. Only runners holding a credential are judged, and the finding is an `[INFO]` naming the
file, the line and the release to pin to. Its first run found five such runners across the two BWJ
consumers.

**Score:** 2

#### What makes this deploy extra special

N/A: a maintainer-side register check, which never reaches a subscriber.

**Score:** N/A

#### Pull Request

check-connectors reports a consumer write runner on a moving or stale shared-scripts ref

