## feat/1843-portable-ci-skeleton

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

#### What #1843 still needed

Step 1 (repo-settings.yml) landed in #1909. Remaining, per the issue's own "in order" list: a CI
skeleton for a consumer with no required status check at all, which is what switches ship-pr's
detect-and-rebase staleness guard on. adopt-ci-floor.ps1's section 1 already composed a paste-ready
ruleset call once a required check existed somewhere in the tree, but a repo with NOTHING triggering
on pull_request had nothing for that call to name -- only a placeholder.

#### Design

- A fifth artefact adopt-ci-floor.ps1 can place, alongside fold/resolves/repo-settings: a minimal
  `.github/workflows/ci.yml`, offered ONLY when nothing in the tree already triggers on pull_request
  -- never merely because that one file is absent, since a consumer running CI under a different name
  already has what this exists to give.
- The body is deliberately empty ("a skeleton is portable; the body is not" -- the assessment's own
  phrase): one job, one clearly marked placeholder step. What a merge should prove is the consumer's
  own choice.
- Triggers on both `pull_request` and `merge_group` from day one (#1325's prerequisite) -- inert
  without a queue, cheaper to place now than to remember later.
- The job's check name follows `Get-CiTestCheckName` when a consumer has declared it (the same seam
  open-pr's own local-gate-skip logic reads, #1715), so the two never need reconciling by hand.
  Falls back to the bare job key `ci`. An unsafe declared value is refused rather than interpolated
  into the YAML as-is -- the same "refuse, do not escape" posture #1972 settled for the ruleset JSON.
- Section 1's own ruleset advice auto-fills from the skeleton's check name when no real candidate
  exists in the tree, instead of the usual placeholder.

### CREATE

- [x] `scripts/task/adopt-ci-floor.ps1` (+ plugin mirror): the CI-skeleton target, its offer
      condition, its job-name resolution, and section 1's auto-fill from it.
- [x] `Test-YamlScalarSafe` and section 1's `Test-JsonContextSafe` merged into one script-scoped
      `Test-QuotedScalarSafe` (Victor's review on #1843): a YAML double-quoted scalar and a JSON
      string literal forbid exactly the same two characters and are vulnerable to the same
      console-repainting class, so one predicate serves both sites instead of two copies a reader
      has to trust are kept in sync by hand.
- [x] `scripts/lib/script-contract-lib.ps1` (+ plugin mirror): `Get-CiTestCheckName`'s record now
      names `adopt-ci-floor` alongside `open-pr`.
- [x] `plugins/dkj-policy/blueprint/config-blueprint.json` regenerated to match the contract change.
- [x] Status update posted on #1843 itself: step 1 was already merged (#1909) since the issue's own
      last comment, before this branch started on step 2.

### TEST

- [x] 21 new asserts in `scripts/tests/adopt-ci-floor.tests.ps1` (section 9): dry-run report and
      auto-fill, `-Apply` placement (both triggers, least-privilege, no credential, placeholder
      step), never overwriting a consumer's edit, never offered/created when any pull_request
      workflow already exists under any name, the `Get-CiTestCheckName` seam driving the job name,
      and an unsafe declared name falling back rather than being interpolated -- the double quote
      (9f), the backslash (9g) and an embedded control character (9h) each checked separately
      (Sebastian's security review on #1843: 9f alone only proved one half of the two-character
      check).
- [x] Full existing `adopt-ci-floor.tests.ps1` suite (144 prior asserts) still green -- every
      existing fixture already carries a pull_request workflow, so the new arm is correctly inert
      there.
- [x] `scripts/lint/check-plugin-integrity.ps1`: 0 errors.
- [x] Every suite under `scripts/tests/*.tests.ps1`: 0 failing.

### DEPLOY: feat/1843-portable-ci-skeleton

This closes #1843: both halves the issue asked for -- the repo-settings runner (#1909) and this CI
skeleton -- are now delivered. A consumer with no required status check at all now gets a scaffolded,
adoptable workflow to require, instead of only being told what such a workflow would need to look
like.

**Score:** 3

#### What makes this deploy extra special

Before this, "make one CI check required" was correct advice with nothing behind it for the one repo
that actually needed it -- a consumer with zero CI. The skeleton closes that gap without asserting
anything about what the consumer's checks should be: the body stays empty on purpose, and the one
seam this template reads (`Get-CiTestCheckName`) is the same one a consumer may already have answered
for an unrelated reason (open-pr's local test-gate skip), so answering it once now serves two
mechanisms instead of one.

**Score:** 2

#### Pull Request

Portable CI skeleton for a consumer with no required check

