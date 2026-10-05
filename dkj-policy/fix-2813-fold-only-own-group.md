## fix/2813-fold-only-own-group

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

Issue #2813: a fold-only push queued behind a merge's pending fold-on-merge run cancelled it, and was
then skipped by the job's own `if:` -- so neither fold path ran. Verified before repairing: the
cancelled run 37289301517 had zero jobs allocated (pending, not running), and verify-resolved's run on
the same push (37289301501) was cancelled the same way, so that merge's resolves check was lost too.

Repair: give a fold-only push a per-commit concurrency group of its own, keyed on the job's `if:`
condition verbatim. It is skipped either way (the #2487 billing saving stands), and it can no longer
displace a run that has work. Two real pushes still share the `github.ref` group, where the newer
survivor is harmless for fold-all mode.

### CREATE

- [x] `fold-on-merge.yml` + `verify-resolved.yml`: the split group, and headers that say what
      `cancel-in-progress: false` does and does not guard
- [x] `adopt-ci-floor.ps1` templates (and the plugin mirror) carry the same group lines
- [x] Sylvester's lens: the #1544 bullet no longer promises "no fold dropped"

### TEST

- [x] `workflow-concurrency.tests.ps1`: asserts the split shape and that the group's condition equals
      the job's `if:`; mutated back to the old group line it goes red (2 FAIL)
- [x] `adopt-ci-floor.tests.ps1`: the placed runners carry the source repo's own group line (281 passed)

### DEPLOY: fix/2813-fold-only-own-group

`fold-on-merge.yml` and `verify-resolved.yml` put a fold-only push in a concurrency group of its own,
keyed per commit, so it can no longer cancel a merge's pending run and leave the fold and the resolves
check undone (#2813). `cancel-in-progress: false` only ever protected the *running* job; a third arrival
drops the pending one regardless, and a skipped fold-only run was the worst possible survivor. Measured
October 5, 2026: the merge of #2811 lost both its fold and its resolves check this way.

**Score:** 3

#### What makes this deploy extra special

A repo whose CI floor was placed by `adopt-ci-floor` keeps the old group lines: re-running it leaves an
existing runner as it is. There, two sessions shipping seconds apart can still leave an entry unfolded
on the trunk and a merge's closing keywords unverified. To take the fix, copy the new `group:` line
into `.github/workflows/fold-on-merge.yml` and `verify-resolved.yml`, or delete both files and re-run
`adopt-ci-floor -Apply`, which places them fresh.

**Score:** 2

#### Pull Request

A fold-only push no longer displaces a pending merge run in fold-on-merge and verify-resolved

