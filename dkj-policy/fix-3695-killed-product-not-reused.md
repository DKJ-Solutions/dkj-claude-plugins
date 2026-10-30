## fix/3695-killed-product-not-reused

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

The dev-preview hook stops its own outdated server (the product after HEAD moved, #3657; the hub of
another plugin version, #3275), waits 5 s for the port, and fell back to `reuse` when the port was still
held. Measured October 30, 2026: the product on 4870 was reported `already running`, nothing listened
minutes later, and its log had not been rewritten since 08:22, so no start had happened. A stopped
server is never reused again: the replacement starts on the same port when it is free, otherwise on the
next free port of the range, and otherwise the line says it was not started.

### CREATE

- [x] `Select-DevPreviewRestartPort` in `hub/lib/dev-preview-rules.ps1`: where the replacement starts, from a snapshot taken after the wait
- [x] `Select-DevPreviewAfterStop` in the hook: the 5 s wait plus the fresh snapshot, used by both the hub and the product restart
- [x] The hub and product restart paths no longer fall back to `reuse`; with no free port they report why

### TEST

- [x] Three new asserts in `dev-preview-sessionstart.tests.ps1`: port freed, port still held by the stopped server (the measured case), and a single port still held
- [x] `dev-preview-sessionstart.tests.ps1`: 425 passed, 0 failed, including the existing #3275 and #3657 restart scenarios
- [~] A hook-level case where the stopped server keeps its port: not built, because a force-stopped test listener frees its port at once, so the held state cannot be produced reliably and a case that never reaches it would only look like coverage. The decision lives in `Select-DevPreviewRestartPort`, which the three asserts cover
- [x] Review: Victor (no correctness findings) and Sebastian (no security findings)

### DEPLOY: fix/3695-killed-product-not-reused

When a session starts after the trunk has moved, the dev-preview hook restarts the repo's product
server, and it now really restarts it
([#3695](https://github.com/DKJ-Solutions/dkj-marketplace/issues/3695)). Before, a stopped server that
took more than 5 seconds to free its port was reported `already running`, and a moment later nothing
listened at all. The replacement now starts on the same port once it is free, or on the next free port
in the range. Where there is none, the line says so instead of naming a server that is gone. The hub's
restart after a plugin update follows the same rule.

**Score:** 2 -- the product link from the session start line pointed at nothing, which the owner
notices the first time they open it.

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

dev-preview: a killed outdated product server is never reported as reused

