## feat/2509-prepare-release

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

Inbound #2509: a read-only `prepare-release` skill in dkj-policy-bwj that stages a store release days
ahead of release day. Verified on pickup: the subject did not exist; `Get-ReleaseAudienceTier` and
`live-preflight` exist as named. Two parts of the proposal did not hold as written and are built
differently, with the reasons on the skill page: the bump comes from the fold's pending tally rather than
from `Get-ReleaseAudienceTier`, and the "tier-2 score where tier 2 is off" check is not built, because an
entry carries no tier number this plugin can read without dkj-policy's parser.

The one design conflict: the issue asks to reuse live-preflight's push-list derivation, and dkj-policy-bwj
scripts may not reach another plugin's libs. Resolved with the registry: `live-push-rules` and
`git-porcelain-lib` are mirrored into dkj-policy-bwj as well, one source each.

### CREATE

- [x] Sync provenance moved out of live-preflight.ps1 into two pure functions in live-push-rules.ps1
  (`Get-SyncMergeCommits`, `Get-SyncOwnedPaths`), called by both scripts
- [x] `Get-LivePushRows` no longer throws under a StrictMode caller given no directories
- [x] `live-push-rules-bwj` and `git-porcelain-lib-bwj` registered as mirrors; mirrors rebuilt
- [x] `prepare-release-rules.ps1`: pending entries, the tier-1 fix/ score note, go-live obligations, the
  verification pull and the runbook
- [x] `prepare-release.ps1`: the eight read-only steps and the runbook, `-OutFile`
- [x] `skills/prepare-release/SKILL.md` and the README skill row
- [ ] Review findings from the code, security and copy passes applied
### TEST

### DEPLOY: feat/2509-prepare-release

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

