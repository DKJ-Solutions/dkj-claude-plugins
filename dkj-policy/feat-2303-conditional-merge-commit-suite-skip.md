## feat/2303-conditional-merge-commit-suite-skip

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

Closes #2303. #1300 gave the fold commit a static shortcut (its tree differs from the merge
commit's by two non-executable paths, provable from the subject alone). #2303 asks for the same
saving on the merge commit itself, and that one cannot be decided from the subject: a ship-pr
merge carries the guarantee that 'main' had not moved past the certified tree at merge time, but
a GitHub-UI merge does not, and nothing in a push event says which one happened. So CI has to
RE-DERIVE the fact from GitHub's own records rather than trust the commit that claims it, reusing
the identical pure functions ship-pr.ps1's own step 3b already uses before merging
(Get-RequiredCheckNames, Get-RequiredCheckRunIds, Get-CertifyingRunCreatedAt,
Test-IsFoldOnlyCommit, Get-StaleCertificateVerdict, Get-CheckOutcome), done after the merge
instead of before it.

### CREATE

- [x] scripts/lib/ci-merge-skip-lib.ps1 -- pure Get-MergeCommitPrNumber (parses the PR number out
      of ship-pr's 'merge: <branch> (#NN)' subject) and Get-MergeCommitSuiteSkipVerdict (combines
      an already-fetched check outcome + certifying-run-found + staleness verdict into Skip/Reason,
      fail-closed on every branch but the one where all three read clean).
- [x] scripts/ci/get-merge-suite-skip.ps1 -- the CI-facing orchestration: reads the merged PR's
      checks back from GitHub, dates the run behind the repo's named check, walks 'main's
      first-parent history since that run (net of #1592's fold exemption), and prints
      'skip=true|false' plus a reason -- writing 'skip' to $GITHUB_OUTPUT when running in Actions.
- [x] .github/workflows/ci.yml -- the suites job: a "Merge-commit certificate" step (id
      merge-suite-skip) ahead of "Test suites", whose own `if:` now also refuses on
      `steps.merge-suite-skip.outputs.skip != 'true'` -- step-level, not job-level, for the same
      reason #1300's fold shortcut is (a job-level `if:` sourced from another job's output would
      make `needs.suites.result` legitimately 'skipped' on the overwhelming majority of runs: any
      PR, any non-merge push). The checkout's `fetch-depth` is conditional (full history only on a
      'merge: ' push, shallow everywhere else), and the job gains its own read-only `permissions:`
      block (`checks`, `pull-requests`, `actions`, alongside `contents`) since the certificate step
      reads a merged PR's checks and the Actions runs behind them, which the workflow-level
      `contents: read` alone cannot reach.

### TEST

- [x] scripts/tests/ci-merge-skip-lib.tests.ps1 (new) -- every branch of
      Get-MergeCommitSuiteSkipVerdict exercised directly against already-fetched facts (no git, no
      gh), with the negative cases outnumbering the positive one on purpose: the cost of a wrong
      Skip=true is a red trunk behind a green required check, the exact hazard #1292 exists to
      prevent, so every ambiguous or unreadable input is asserted to refuse. Plus
      Get-MergeCommitPrNumber's parse, including the anchored-at-the-end case (a number embedded in
      the branch name must not be read in place of the trailing `(#NN)`).
- [x] scripts/tests/ci-shard.tests.ps1 -- extended with the same class of structural assert #1300's
      shortcut already carries there: the new step exists with its id, the Test suites step's `if:`
      reads its output, the checkout's conditional `fetch-depth`, and the job's read-only
      `permissions:` block (asserting no `write` scope anywhere in it).
- [x] Full lint gate (`check-plugin-integrity.ps1`): 0 errors.
- [x] Targeted suites run clean: ci-shard (86/86), ci-merge-skip-lib (23/23), ci-fold-lib
      (75/75, unaffected), shared-scripts (972/972, confirms the new lib is correctly NOT
      registered as a mirrored script), pr-issues (1123/1123, unaffected), merge-queue-prereq
      (38/38, unaffected). The full local suite gate was not run in this session (this machine's
      own known limit -- CI covers the rest).
- [~] A live CI run exercising the actual skip=true path -- can only be proved by a real
      'merge: ' push once this lands, since it needs GitHub's own Checks/Actions API and a real
      merge commit's parents. The design is fail-closed throughout: every unreadable or ambiguous
      read (an unresolvable run, a failed checks read, 'main' having moved) answers skip=false, so
      the worst a defect here can do is run suites that were not strictly necessary, never skip
      ones that were.

### DEPLOY: feat/2303-conditional-merge-commit-suite-skip

CI no longer re-runs the full ~11-minute, four-shard test suite on a `merge:` push to `main` when
the merged PR's own head SHA already carries a green required check and `main` had not advanced
(net of fold commits) since the run that certified it -- prices and answers #2303, which measured
that 46% of a day's CI runs land on the trunk and the `merge:` half of those re-tests a tree
`ship-pr` had just certified as non-stale. Unlike #1300's fold shortcut, this cannot be decided
from the commit subject alone (a UI merge carries no such guarantee), so CI re-derives the fact
from GitHub's own records instead of trusting the commit that claims it, reusing the identical
pure functions `ship-pr.ps1`'s own pre-merge staleness gate already relies on. Fail-closed
throughout: an unreadable check, an undateable run, or `main` having actually moved all fall back
to running the suites in full.

**Score:** 3

#### What makes this deploy extra special

N/A -- a CI-internal change to this repo's own `.github/workflows/ci.yml` and the scripts it
calls; nothing here is mirrored to a consumer (unlike `ci-fold-lib.ps1`, this repo's own internal
suite gate is never shipped), so no subscriber of the plugin marketplace is affected.

**Score:** N/A

#### Pull Request

CI on a merge commit skips the suites when the merged PR is already independently re-certified fresh

