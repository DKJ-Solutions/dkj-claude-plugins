## fix/2829-sync-branch-name-pr-heads

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

Inbound #2829: a second same-day `sync-main` run reused the name of a sync branch whose PR had already
merged, because the namer only checked whether a ref existed. Verified in the source: steps [3/6] chose
the name by `refs/heads/<name>` and `refs/remotes/origin/<name>` alone.

### CREATE

- [x] `Select-SyncBranchName` in `scripts/lib/sync-rules.ps1`: the suffix loop, with an "is it taken?" probe.
- [x] `sync-main.ps1` passes a probe that also asks `gh pr list --head <name> --state all`. Where gh cannot
  answer, it falls back to refs alone and says so.
- [x] Mirrors rebuilt with `build-shared-scripts.ps1`.

### TEST

- [x] `sync-rules.tests.ps1`: the namer's behaviour, including the measured merged-PR-head case and the limit (178 asserts green).
- [x] `sync-main.tests.ps1`: the network-call pin is 12 now, plus source pins for the `--state all` probe (160 asserts green).

### DEPLOY: fix/2829-sync-branch-name-pr-heads

`sync-main.ps1` now treats a name as taken when it is already the head of a pull request in any state, as
well as when a ref for it exists. A second sync on the same day therefore gets `-2` even after the first
one's PR has merged and its branch is deleted. Where `gh` cannot answer, the name is chosen from refs
alone, as before, and the run says so.

**Score:** 2

#### What makes this deploy extra special

A Shopify repo that syncs twice in one day no longer gets a branch that `ship-pr` refuses with "PR #...
is already merged", so the hand rename to `-2` is no longer needed.

**Score:** 2

#### Pull Request

sync-main: skip a same-day name that is already a PR's head

