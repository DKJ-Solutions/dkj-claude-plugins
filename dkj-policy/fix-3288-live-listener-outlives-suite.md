## fix/3288-live-listener-outlives-suite

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

#### Status

A test suite only: the gates prove it, so it ships without an intermediate stop.

### CREATE

- [x] The fixture listener in `dev-preview-sessionstart.tests.ps1` sleeps 600 s, not 60. The `finally` stops every one of them
- [x] The two asserts that failed on CI print what they got: the hook's line, and `/issues`'s status line with the elapsed seconds

### TEST

- [x] Cause reproduced: with a 30 s listener the suite fails locally on exactly `another checkout does not mistake that server for its own`, with `other` starting its own server on the freed port (307/1)
- [x] The repaired suite passes locally (308/0)
- [~] The `/issues` co-failure is not explained by this cause. Filed as #3324, with the new output in place for its next recurrence

### DEPLOY: fix/3288-live-listener-outlives-suite

`dev-preview-sessionstart.tests.ps1` failed on CI with `another checkout does not mistake that server for its own`
([#3288](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3288), five times). The fixture server that
assert depends on was a listener that ran for 60 s, and on a slow shard the assert came about 67 s after that
listener started. By then the port was free, so the second checkout started its own server. The listener now
runs for 600 s and is stopped in the suite's `finally`. The assert also prints the line it got. With a 30 s
listener the failure reproduces locally.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

A CI-flaky dev-preview assert: its fixture server no longer stops before the last scenario
