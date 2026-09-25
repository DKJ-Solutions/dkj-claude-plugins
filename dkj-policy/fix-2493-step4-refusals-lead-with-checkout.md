## fix/2493-step4-refusals-lead-with-checkout

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

Issue #2493 (inbound, measured on a consumer's PR): `ship-pr.ps1`'s DEPLOY lock refused and prescribed
`open-pr.ps1 -RefreshBody` -- but step 2b (#1073) had already handed the primary checkout back to `main`,
so the remedy met open-pr's "You are on main". The reason is verified in the code: step 2b runs at
`$trunkReturn` before the CI wait, both step-4 refusals run after it. The step-list gate beside the lock
has the same defect ("Commit, and re-run" needs the branch too), so both are repaired here, the way #1588
repaired the stale-CI remedy: lead with `git checkout <paste-safe token>`, printed unconditionally.

### CREATE

- [x] `$step4CheckoutBlock` in `ship-pr.ps1`: the checkout (paste-safe token plus its note), with a lead
      sentence that follows `$treeOnTrunk` so it never claims a move step 2b declined
- [x] the DEPLOY lock and the step-list gate refusals both carry it
- [x] plugin mirror rebuilt (`build-shared-scripts.ps1`)

### TEST

- [x] `ref-print-lib.tests.ps1`: the block names the token and appends the note, and each of the two
      refusals carries it -- 471 passed; `ship-pr.ps1` parses clean
- [ ] reviewed: Victor, Sebastian, Edith

### DEPLOY: fix/2493-step4-refusals-lead-with-checkout

When `ship-pr` refuses a merge at the DEPLOY lock or the step-list gate, the refusal now starts with the
`git checkout <branch>` the fix needs. Both refusals fire after `ship-pr` has already moved the checkout
back to `main`, so the remedy they printed (commit, or `open-pr.ps1 -RefreshBody`) failed with "You are
on main" until the branch was checked out by hand.

**Score:** 2 -- a refusal's own remedy failed on first use; noticed only by somebody who hits the lock.

#### What makes this deploy extra special

N/A -- nothing changes for a subscriber.

**Score:** N/A

#### Pull Request

ship-pr's step-4 refusals lead with the checkout the fix needs

