## fix/2634-complete-run-progress-retries-locked-delete

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

#2634: under the parallel gate, `run-progress.tests.ps1`'s gate-wiring probe found its own record still
present after `Clear-GateProgress`. Verified in the code: `Get-LiveRunProgress` reads each record with
`ReadAllText` (shares for read, not delete), and `Complete-RunProgress` turned a failed `Remove-Item`
into a silent `$false`. The repair is a bounded retry on the delete.

### CREATE

- [x] `Complete-RunProgress` retries a failed delete, up to 20 times 50 ms apart, and still returns `$false` without throwing once that is used up
- [x] mirrored byte-identically into `plugins/dkj-policy` and `plugins/dkj-subagents/dkj-subagents-shopify`

### TEST

- [x] `run-progress.tests.ps1`: a child process holds the record the way the reader does. A single delete fails (the mechanism), and `Complete-RunProgress` succeeds past it (79/79 standalone)

### DEPLOY: fix/2634-complete-run-progress-retries-locked-delete

A gate or ship that closes while a statusline is reading its progress record now removes that record,
where it used to leave it behind. The delete failed on a sharing violation and the failure was swallowed.
This also took down `run-progress.tests.ps1`'s gate-wiring assert under the parallel gate, so a red there
said nothing about the tree (#2634).

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

run-progress: Complete-RunProgress retries a delete a statusline read is holding

Plugins: dkj-policy, dkj-subagents-shopify

