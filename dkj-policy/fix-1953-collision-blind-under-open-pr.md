## fix/1953-collision-blind-under-open-pr

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

#### What #1953 reports, and what is actually wrong

The issue reports that a session stepping onto an EXISTING branch by hand meets no remote-ahead check, and
proposes hooking one at that entry moment. The symptom is real; the reason is one layer deeper, and the
repair it proposes would not have caught the case it measured.

`park-cycle.ps1` is documented as this workflow's earliest collision detector: it runs on a Stop hook every
turn, so from the moment a second session pushes, every turn of this one can see it. That claim rested
entirely on the push being ATTEMPTED and REFUSED -- detection was a side effect of the refusal. Bound 3,
the DEPLOY lock, stops the run the moment a PR exists, so on every branch from `open-pr` until the merge
the run ended at that bound: no push, no refusal, no fetch, nothing to interpret -- and under `-Quiet`,
which is what the hook passes, in complete silence.

That is the worst branch to be blind on, and it is exactly the one #1953 measured: a branch with an open PR
and a red required check.

#### Why the entry check the issue proposes is not the repair

In the measured case the second session stepped onto the branch BEFORE the first had pushed, so a check at
`git checkout` would have found nothing on origin. Only a check that runs AGAIN, every turn, sees the other
side arrive mid-work. So this restores the per-turn detector rather than adding a fourth door.

### CREATE

- [x] `scripts/task/park-cycle.ps1`: extract the fetch-and-compare into `Get-BranchCollisionNote` and the
      interpretation into `Write-CycleCollisionReport`, so two callers cannot drift on the ref they read or
      on what the report means.
- [x] Bound 3's open-PR arm performs that read and prints that report. The bound still refuses the push:
      nothing is committed, nothing is pushed. The merged and closed arms stay silent -- a shipped branch is
      not two sessions building the same repair, so the round trip is bought rather than assumed.
- [x] The report bypasses `-Quiet`, as the push report already does: under the hook that switch is the only
      reader there is.
- [x] Header, the `-Quiet` parameter doc and the DELIBERATELY-NO-FETCH block corrected -- all three
      described a one-door detector.
- [x] `plugins/dkj-policy/skills/park/SKILL.md`: it stated *"this is the one place the script fetches"* and
      *"a push still reports itself"*, both now false. Rewritten with both doors, the measurement, and what
      this deliberately does not repair.
- [x] Mirror regenerated with `scripts/sync/build-shared-scripts.ps1`.

#### From the review chain

- [x] **Security:** the branch name went into the new lead sentence raw while the same value, one argument
      over, went through `Get-DisplayRef`'s control/format strip -- one report with one half hardened. Both
      the new lead and its pre-existing sibling line now print `$shownBranch`. `git check-ref-format`
      accepts `\p{Cf}`, so this is the class `remote-ahead-lib.ps1` centralised the strip for.
- [x] **Copy:** `.claude/specialists/lenses/05-05-extension.md` said park-cycle *"becomes a no-op the
      moment a PR exists"*, which this change makes false; and the `park` skill's pickup section said the
      collision reaches you because *"its push is refused"*, which is now only the no-PR half. Both
      corrected.
- [x] **Copy:** the `#1600` link on a line this branch rewrote still carried the retired repo name, and
      one *"fast-forward of your own autopark"* was left behind by the generalisation to *"push"*. Both
      corrected on the lines already being edited.
- [~] **Cost:** `scripts/tests/suite-durations.json` is now stale-low for this suite (+4.5s locally). NOT
      re-recorded here, deliberately: `record-suite-durations.ps1` may only be regenerated from a real CI
      run's tables -- a local reading does not convert into a CI one, and its own docstring names reading
      one as the other as how #1358 went wrong. It refreshes on the next CI-fed pass.
- [~] **Cost:** the Stop hook's 60s ceiling against the shared 120s network bound, so park-cycle's
      always-exits-0 contract cannot hold when the network is slow. Pre-existing and not this branch's
      subject -- the no-PR path already stacks three such calls where this arm stacks two. Filed as
      [#1958](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1958).

### TEST

- [x] `scripts/tests/park-cycle.tests.ps1` case (q): case (p)'s fixture with an open PR -- a peer clone
      under its own identity pushes to the shared branch. Asserts the report names the PR, the other session
      and their commit subject; that nothing is committed; that origin still carries the peer tip; and that
      all of it survives `-Quiet`, which is the only assert that matters for the hook.
- [x] Case (r): a MERGED PR over a diverged origin prints the bound's refusal and no collision report --
      the assert that keeps the round trip bought.
- [x] Case (s), from the code review: a PR payload with **no `state` field** over a diverged origin. The
      new arm treats an unknown state as open, and that direction is the one worth pinning -- the
      alternative is the collision going unreported on a branch the run could not classify, which is the
      silence #1953 was filed for. Case (d4) proves the degraded wording survives StrictMode and sets up no
      divergence, so it could not say whether this arm runs at all.
- [x] The peer-clone block the three cases share is one helper, `New-PeerDivergence`, rather than written
      three times. Case (p) is deliberately left on its own copy: it is the long-standing assert over the
      refused-push arm, and rewriting it would put risk on the one test already guarding that path.
- [x] Full suite green: 112 asserts, up from 91. Runtime 29s, from ~25s (three clone-based fixtures where
      there was one).

### DEPLOY: fix/1953-collision-blind-under-open-pr

`park-cycle.ps1` runs on a Stop hook every turn and is documented as this workflow's earliest detector of
two sessions on one branch. That claim rested entirely on the push being attempted and refused -- detection
was a side effect of the refusal -- and bound 3, the DEPLOY lock, stops the run the moment a PR exists. So
on every branch from `open-pr` until the merge it ran to that bound and stopped: no push, no refusal, no
fetch, nothing to interpret, and under `-Quiet` -- which is what the hook passes -- in silence.

**That is the worst branch to be blind on.** A branch with an open PR and a red required check is the
single most likely object for two sessions to reach for independently: the work is well-defined, visible on
the PR list, and obviously owed. Measured September 13, 2026
([#1953](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1953)): two sessions repaired the same
red check on PR #1950 about 90 seconds apart, produced the same three-file change, and learned of each
other from git's non-fast-forward refusal at the push -- after the diagnosis, the repair, the suite run and
the lint gate had each been paid for twice.

The bound had fused two questions. *May this script write?* is the DEPLOY lock's, and the answer is still
no -- nothing is committed and nothing is pushed. *Is somebody else on this branch?* is a read, and it owes
the lock nothing. So the open-PR arm now reads the same one ref and prints the same report, naming the
other side's author and subject. A merged or closed PR still buys no fetch, and neither arm touches the
ordinary turn: both sit past the gate that returns early when the document is unchanged and origin holds
everything this branch has.

**The repair #1953 proposed was not taken, and the reason is inside the issue.** It asks for a check at the
entry moment -- `git checkout <branch>` by hand. That would not have caught what it measured: the second
session stepped onto the branch *before* the first had pushed, so there was nothing on origin to find. Only
a check that runs again, every turn, sees the other side arrive mid-work.

**Score:** 3

#### What makes this deploy extra special

It ships in `dkj-policy` and reaches every consumer running this workflow through the Stop hook they
already have -- no adoption step and nothing to configure. What they get is a collision named minutes into
the duplicated work instead of at the push, on the branch state where a collision is likeliest. The cost is
one network round trip, only on a turn that already made one.

**Score:** 3

#### Pull Request

park-cycle is blind to a collision on exactly the branch two sessions collide on

