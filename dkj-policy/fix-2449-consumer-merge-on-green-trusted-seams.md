## fix/2449-consumer-merge-on-green-trusted-seams

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

Build the design pass and Sebastian #23's review on #2449 (both are comments on the issue): the consumer
`merge-on-green.yml` that `adopt-ci-floor.ps1` scaffolds moves from one token-bearing workspace switched
in place to three sibling checkouts, together with the review's three conditions.

### CREATE

- [x] `$mergeOnGreenRunner`: `trusted-main` (the trunk, no token, `persist-credentials: false`), the pinned
  `.workflow-scripts` fetch left unchanged, and `pr-branch` (only when a PR is picked, no token). The exclude
  line and the in-place `git checkout` are gone.
- [x] Ship step: an ephemeral `GIT_CONFIG_*` credential built from `FOLD_PUSH_TOKEN`. It deepens and
  SHA-checks `pr-branch`, then runs `ship-pr.ps1 -TrustedRoot trusted-main` with `CLAUDE_PROJECT_DIR`
  set to `pr-branch`. The picker gets `CLAUDE_PROJECT_DIR` set to `trusted-main` explicitly.
- [x] Condition 1: the runner's own header argues the one-credential-for-both-trees trade.
- [x] Condition 3: `Write-MergeOnGreenShapeVerdict` reports an existing runner of the old shape on a
  re-run, and says it is unread when it is neither shape.
- [x] The comment in `merge-on-green-lib.ps1`: the `.workflow-scripts/` refusal is now documented as
  permanent (review question 5). The code is unchanged.
- [x] `.DESCRIPTION` of `adopt-ci-floor.ps1`. Both mirrors are byte-identical.
- [x] Two docs still described the old shape as current (Edith #17's copy edit):
  - `adopt-dkj-policy/SKILL.md`, Part 3's fourth runner. It is rewritten for the three checkouts and gets
    the re-scaffold instruction. The same paragraph's "half-hourly" is corrected to every 3 hours (#2487).
  - Sylvester's lens. The `.git/info/exclude` sentence is dropped, and the "not the same fix" bullet
    becomes what #2449 built.

### TEST

- [x] `adopt-ci-floor.tests.ps1`: section 2e was rewritten for the new shape. The new 2e-2 pins three
  credential-free checkouts, no `token:` input, no exclude line or in-place checkout, the literal
  `trusted-main` and `pr-branch` values (condition 2), and the `GIT_CONFIG_*` credential. Section 11 adds
  the shape advisory for the current, old and unreadable shapes. 270 passed, 0 failed.
- [x] An intermittent `OutOfMemoryException` during that suite also reproduces on `main`, so it is not
  this branch. Filed as #2601.

### DEPLOY: fix/2449-consumer-merge-on-green-trusted-seams

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

