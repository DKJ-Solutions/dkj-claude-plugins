## fix/2470-stranded-sweep-fake-gh-timeout

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

#2470's filed cause was the 90 s `-MaxElapsedSeconds` budget. Reproduced against the real check,
the reachable clock is the 15 s per-call `-TimeoutSeconds`, which the suite never passed: a fake
`gh` slower than it reads `[SKIP]` or `[INCOMPLETE]`, never `[OK]`. The correction is on the issue.

### CREATE

- [x] `stranded-sweep-gate.tests.ps1`: `Invoke-Check` passes `-TimeoutSeconds 120` to every run

### TEST

- [x] Suite alone 46/46; a 3 s fake with `-TimeoutSeconds 2` gives `[SKIP]`, and with 120 gives `[OK]`

### DEPLOY: fix/2470-stranded-sweep-fake-gh-timeout

`stranded-sweep-gate.tests.ps1` no longer refuses a push when the parallel test gate is under
load. Its fake `gh` launches a fresh `powershell.exe`, and under 22 lanes that could outrun the
check's 15 s per-call timeout. The suite now gives every run a 120 s bound, because none of its
cases tests that timeout.

**Score:** 2 -- removes a spurious red from `open-pr`'s gate (#2470), in the same class as #2077 and #2458.

#### What makes this deploy extra special

N/A -- a test-suite change; nothing a subscriber runs is touched.

**Score:** N/A

#### Pull Request

stranded-sweep-gate suite gives its fake gh a per-call timeout no load can reach

