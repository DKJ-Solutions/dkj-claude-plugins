## feat/3183-golive-block-by-hand

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

Inbound #3183 from smartwatchbanden: a closed message posted on the Asana task by hand had no sanctioned
opt-out, so the session posted a block to pass the close guard and unlinked the issue body around the
close. Verified against the tree: no marker, label or parameter existed. The repair is the proposal's own:
a fourth block kind, `-ByHand`, that the close guard already accepts because it is a block, and that
`asana-closed-message` reads as "post nothing".

### CREATE

- [x] `Get-AsanaHandBlockMarker` in `asana-task-lib.ps1`, copied into `templates/asana-closed-message.ps1`
- [x] `Format-GoLiveByHandBlock` in `golive-block-rules.ps1`: a one-line record between the rules
- [x] `build-golive-block.ps1 -ByHand [-Story <gid>]`: refuses the other forms' input, skips the PR check
- [x] `asana-closed-message.ps1` posts nothing for this round's trusted by-hand record
- [x] the close guard names `-ByHand` among its fixes; notify-live gives the skip its own reason
- [x] docs: the `golive-block` skill and `WORKFLOW-portable.md`
- [x] review round: Victor (shared-task exemption, the `asana :` line, test order), Sebastian and Edith
  (nothing blocking; Edith's `Plugins:` line is added by the ship tooling, so withdrawn)

### TEST

- [x] `bwj-development.tests.ps1`: formatter, driver refusals, closed-message end to end (fresh, stale,
  untrusted), live-message skip, marker copy equality -- 775 asserts green
- [x] `guard-stale-paste-block.tests.ps1`: a by-hand record lets the close through, the refusal names
  `-ByHand` -- 156 asserts green

### DEPLOY: feat/3183-golive-block-by-hand

`build-golive-block.ps1 -ByHand [-Story <gid>]` records on the issue that its closed message was posted on
the Asana task by hand. The close guard accepts that record as this round's block, and the
`asana-closed-message` workflow posts nothing beside the hand-written message. A record from before the
last reopen, or from an untrusted author, silences nothing. `-ByHand` skips the pull-request and
shared-task checks, and the guard's refusal names it among its fixes (#3183).

**Score:** 2

#### What makes this deploy extra special

A hand-approved closed message no longer needs the issue body edited around the close to keep the
workflow from posting a second message beside it.

**Score:** 2

#### Pull Request

build-golive-block -ByHand: a sanctioned opt-out for a closed message posted by hand

