## fix/2379-native-capture-exitcode-flake

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

#2379 read the red `native-capture.tests` shard as a lib defect. It is not: the empty value is #1931's
documented race, and the lib already reports it as `ExitCodeUnknown`. The flaky part is the test, which
took a single answer as a regression.

### CREATE

- [x] `Invoke-MeasuredCapture` in `scripts/tests/native-capture.tests.ps1`: re-asks a real child up to three times, only while the capture says `ExitCodeUnknown` (never after a timeout or a failed launch)
- [x] the exact-exit asserts on the Start-Process arm (exit 0, exit 3, the bounded exit 7, the `git --version` probe) go through it
- [x] the re-ask pinned both ways against a stand-in: a race that clears yields the code, and an empty that persists stays empty

### TEST

- [x] `native-capture.tests.ps1` alone: 352 pass, 0 fail

### DEPLOY: fix/2379-native-capture-exitcode-flake

`native-capture.tests.ps1` no longer goes red on #1931's 1-in-300 unmeasured exit code
([#2379](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2379)). The exact-exit asserts on the
Start-Process arm now re-ask a real child up to three times, and only while the lib itself reports
`ExitCodeUnknown`. The regression they guard is a dropped `.Handle` read, which empties every attempt, so
it still fails. The lib is unchanged: it was already reporting the race correctly. Nobody outside this
repo's CI notices.

**Score:** 1

#### What makes this deploy extra special

N/A: test-only, never reaches a subscriber.

**Score:** N/A

#### Pull Request

native-capture.tests: re-ask an -Utf8 exit-code assert only while the lib reports ExitCodeUnknown

