## fix/2825-resume-line-plugin-path

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

Inbound [#2825](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2825), verified: `Get-PrScanResumeLines`
in `pr-scan-lib.ps1` hard-coded `scripts/release/ship-pr.ps1`, which exists only in the source repo. Its two
callers (`check-unshipped-pr`, `check-stranded-sweep`, both behind session hooks) already know the repo root,
so the line now names the repo's own copy where there is one and the plugin's copy beside the lib otherwise.
The same resolution `cut-release` uses for the scripts it prints (#461).

### CREATE

- [x] `Get-PrScanShipPrPath` + `-RepoRoot` on `Get-PrScanResumeLines`; both callers pass their root (all copies mirrored)
- [x] Asserts in `unshipped-pr-gate.tests.ps1`

### TEST

- [x] `unshipped-pr-gate.tests.ps1`: 47 pass; `stranded-sweep-gate.tests.ps1`: 46 pass

### DEPLOY: fix/2825-resume-line-plugin-path

The resume command the unshipped-PR and stranded-sweep session checks print now names a `ship-pr.ps1` that
exists. In the source repo that is still `scripts/release/ship-pr.ps1`; in a consumer, which has no copy
there, it is the plugin's own copy, as a quoted full path.

**Score:** 2

#### What makes this deploy extra special

When a session check says a green pull request is waiting to ship, the command it prints works as pasted.
Before, it named `scripts/release/ship-pr.ps1`, which no consumer has, and failed with "the argument to the
-File parameter does not exist".

**Score:** 2

#### Pull Request

The unshipped-PR resume line names a ship-pr that exists in the consumer

