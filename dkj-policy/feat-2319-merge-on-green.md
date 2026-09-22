## feat/2319-merge-on-green

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

#### The three preconditions, and which half of this branch removes which

`ship-pr` refusing on a red required check leaves the merge owed to three things at once: a session
that is **still alive**, a person who **notices** CI turned green, and a checkout that **stands on
the branch**. Measured on PR #2316, 2026-09-22 (#2319). This branch removes all three -- the first
two with a CI runner, the third inside `ship-pr` itself.

#### The runner does not re-derive a single gate, it runs `ship-pr`

The shape #2319 proposes is a runner that merges "only when the required check is green on the exact
head and the staleness count is zero". Every one of those predicates already exists, in
`ship-pr.ps1`, together with the gate #2319's list leaves out (the step-list gate) and the one it
names (the DEPLOY lock). Re-deriving them in a second script would be a second implementation of one
question -- the thing `ci-merge-skip-lib.ps1` deliberately refused to do one file over, and it
refused it by calling the SAME pure functions rather than by writing new ones.

So the runner checks the branch out and runs `ship-pr.ps1`. It is a session that cannot die, not a
second opinion about when a merge is owed. Everything `ship-pr` learns from here on, it learns too.

#### Why the merge has to be made by a PAT, which #2319 does not name

A push caused by the job-scoped `GITHUB_TOKEN` starts no workflow runs. This tree already records
that, in `verify-resolved.yml`'s own header. So a `GITHUB_TOKEN` merge would land the PR and silence
`ci.yml` on the trunk, `fold-on-merge.yml` and `verify-resolved.yml` all three -- the exact
unobserved-merge state that whole family exists to close. The checkout therefore carries
`FOLD_PUSH_TOKEN`, which needs `Pull requests: write` added to it; today it is `Contents: Read and
write` only. That is a credential act and it is Dave's, not this branch's. Until it is made, the
runner's merge step fails with a 403 and says so.

#### The arming label, because not every green PR is owed a merge

`CLAUDE.md` keeps two kinds of PR back for Dave's own word -- a visible result, and anything
irreversible or outward-facing. A runner that merges every green PR would merge those too. So the
runner acts only on a PR carrying `merge-when-green`, and the one thing that sets that label is
`ship-pr` itself, at the moment its own CI verdict refuses. The label is therefore a record that a
session deliberately began shipping, which is precisely what those two exceptions withhold.

#### A sweep, not an event-derived PR

`workflow_run` gives immediacy and is the wrong thing to depend on alone: the measured incident was
repaired with `gh run rerun --failed`, and whether a partial re-run re-emits `workflow_run` is not a
contract this branch wants to rest on. So the trigger set is `workflow_run` + a 30-minute schedule +
`workflow_dispatch`, all three waking ONE sweep that reads the tracker rather than the event. A
constant concurrency group with `cancel-in-progress: false` keeps two sweeps off one trunk.

### CREATE

- [x] `scripts/lib/merge-on-green-lib.ps1` -- the pure half: which armed PR a sweep may hand to
      `ship-pr`, decided from already-fetched facts (label, draft, mergeable, and
      `Get-MergeBlockVerdict`'s own object, borrowed whole rather than rebuilt). Fail-closed at every
      branch, like `ci-merge-skip-lib.ps1`.
- [x] `scripts/ci/pick-merge-on-green.ps1` -- the impure half: the reads, and the `GITHUB_OUTPUT`
      contract the workflow's `if:` keys on.
- [x] `.github/workflows/merge-on-green.yml` -- the runner: pick, check the branch out with
      `FOLD_PUSH_TOKEN`, run `ship-pr.ps1`.
- [x] `ship-pr.ps1` arms the label on its own CI-verdict refusals, and never under `-NoMerge`. It
      creates the label on first use, so no adoption step is needed for it.
- [x] `ship-pr.ps1`'s on-the-trunk refusal resumes itself: one candidate, clean tree, `git checkout`
      and carry on -- the third precondition, and the half #2319 offers to split off.
- [x] `merge-on-green-lib.ps1` registered as a shared lib and mirrored, because `ship-pr.ps1`
      dot-sources it unguarded and travels to every consumer.
- [~] Register the runner with `adopt-ci-floor`, and the label with `adopt-triage-labels`. **Dropped,
      both, and for different reasons.** The runner: a consumer template is a third ~200-line generated
      workflow plus its own asserts, and `fold-on-merge.yml` landed the same way -- built and proved
      here under #1493, derived into `adopt-ci-floor.ps1` afterwards. Filed as
      [#2329](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2329). The label: that command's
      subject is the four canonical `prio-1`..`prio-4` TRIAGE labels, and this is not one -- it is half
      of a handshake between two scripts, so it creates itself on first use instead.

### TEST

- [x] `scripts/tests/merge-on-green-lib.tests.ps1` -- 56 asserts. Every refusal branch of the verdict,
      the arming label read case-sensitively, the fork refusal, the lowest-number pick, and the verdict
      fed the REAL `Get-MergeBlockVerdict` rather than only hand-built stand-ins. It also holds the
      runner to four things it must not lose: the PAT on the merge, `-SkipLint -SkipTests`, the
      deepening before step 3b's trunk walk, and the branch never reaching a shell body through an
      expression interpolation.
- [x] The lint gate: 0 errors (it wanted the mirror row in `plugins/dkj-policy/scripts/README.md`,
      which is now there).
- [x] `shared-scripts` (986), `script-contract` (386), `pr-issues` (1123) and `ci-merge-skip-lib` (23)
      all green -- the four suites the mirror registration and the `ship-pr` edits could reach.
- [~] Behavioural coverage of the on-the-trunk resume. **A named test gap.** The block reads HEAD, the
      tracker and the working tree and drives `git checkout`, so there is no pure function to hand a
      payload to; what the suite holds is the three conditions structurally and that the #1620 refusal
      survived for every case the resume declines. That is not the same as covering the behaviour, and
      saying so is better than a fixture that asserts on its own stand-in.
- [~] Proving the runner itself before the merge. **Structurally impossible, not skipped.**
      `workflow_run` always runs the DEFAULT branch's copy of a workflow file, so this one cannot fire
      on its own pull request; its first live proof is its own first sweep after the merge.

### DEPLOY: feat/2319-merge-on-green

A pull request whose CI goes green *after* `ship-pr` refused is now merged by a CI runner instead of by
whoever happens to notice. `ship-pr` arms the pull request with `merge-when-green` at the moment its own
CI verdict refuses, and `.github/workflows/merge-on-green.yml` -- woken by a CI `workflow_run`, a
30-minute schedule or `workflow_dispatch` -- sweeps for an armed pull request that is green on its own
head, checks its branch out and runs `ship-pr.ps1`. It re-derives no gate: the staleness check, the
step-list gate and the DEPLOY lock are all that script's, so the runner is a session that cannot die
rather than a second opinion about when a merge is owed, and it folds and verifies the resolves exactly
as a live session would. `ship-pr`'s own on-the-trunk refusal now performs the `git checkout` it used to
print, on exactly one candidate and a clean tree. Measured on PR #2316, where a flake, a
`gh run rerun --failed` and a green check still cost a full human round trip.

**Score:** 4

#### What makes this deploy extra special

The runner does not travel yet ([#2329](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2329)),
so what a consumer receives at the next release is the two halves that live in `ship-pr.ps1`: the
on-the-trunk resume, which they get in full, and the arming label, which is inert there until a sweep
exists to read it. The merge itself is made by `FOLD_PUSH_TOKEN` rather than by the job token, because a
push caused by `GITHUB_TOKEN` starts no workflow runs -- a consumer adopting the runner later will need
`Pull requests: write` on their own PAT for the same reason.

**Score:** 2

#### Pull Request

A merge owed to a green PR no longer needs a live session that is also on the right branch
