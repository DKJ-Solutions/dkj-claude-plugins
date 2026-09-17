## fix/2087-ship-pr-converges-under-parallel-lanes

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

Two repairs to `ship-pr.ps1`, both of which block a lane from landing and neither of which is a
weakening of a gate. Issue #2087 offered four candidate directions and recommended none; Dave ruled out
the merge queue outright, on the ground that this repo sets the example for every consumer and a
prescription half of them cannot follow turns their correct state into an open gap. That leaves the two
below, both of them script, both of them reaching every consumer through the ordinary release.

#### Repair 1 -- step 0a's refusal rests on a ground that has partly expired

`ship-pr` refuses to ship at all while another worktree holds the trunk, because step 5 checks the trunk
out in order to fold. Since #1493 that ground holds only where nothing else folds: `fold-on-merge.yml`
triggers on every push to the trunk, not only a merge queue's, and this script has relied on that on the
ordinary path since #1792. The refusal was gated on the queue when the thing it actually depends on is
the runner.

The cost is not an edge case. The close-out rule and step 5b both end sessions on the trunk, so a second
live checkout standing there is the ordinary state of this workflow -- two lanes shipping in the same
period block each other even when CI is fresh (measured on PR #2076).

#### Repair 2 -- detect-and-rebase does not converge, and the remedy is what changes

Step 3b's predicate is right and stays exactly as it is. What was wrong was that its remedy was printed
for a person to type, and takes about as long as CI -- so on a trunk merging every twenty to forty
minutes the branch is stale again by the time it is green. PR #2062 recorded seven refusals in a row.

Issue #2087's direction 3 (narrow the predicate to a path overlap) is declined: `ship-pr`'s own
commentary already weighed and rejected a general path filter, and the fold exemption is the bounded
version that is safe only because git enforces a fold commit's two-path diff.

#### What is deliberately not in this branch

- [~] Re-enabling the merge queue on this repo -- dropped: Dave ruled it out, and the reasoning is in
      the PLAN above. `main-ci-gate` is untouched by this branch.
- [~] Narrowing step 3b to a path overlap -- dropped: argued against in `ship-pr.ps1`'s own commentary,
      and the reasoning is recorded in `forward-lane-lib.ps1`'s header so the next reader meets it.

#### Handover -- picking this up on another machine

**Written as prose on purpose, not as a step list.** An unresolved `- [ ]` above the DEPLOY heading is
refused by both `open-pr` and `ship-pr`, and there is no `-Force` for it -- so a handover written as
checkboxes would block the very merge it is handing over.

**Where this branch stands.** Both commits are on `origin` and nothing is half-done: there is no pull
request, no merge and no fold. Issue #2087 is claimed on `davekokbwj`. The gates were green on the
machine that wrote this -- `check-plugin-integrity.ps1` clean, all 113 suites green -- and `open-pr` was
started twice there and stopped twice by the harness for system memory, before it pushed or opened
anything. Nothing about the branch is in doubt; what is missing is the chain from the PR onwards.

**Resume it with two commands.** `new-branch` is idempotent and reads both ref namespaces, so it finds a
branch that exists only on `origin`, checks it out **at the remote tip** with the work in it, and says in
so many words that this is a resume rather than a new branch:

```powershell
git fetch origin
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\task\new-branch.ps1" -Name "fix/2087-ship-pr-converges-under-parallel-lanes"
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\release\ship-pr.ps1" -Resolves 2087
```

`ship-pr` runs the whole chain: the gates, the PR, the CI wait, the merge, the fold, and the
resolved-issues verification.

**Two things that are per-machine and fail silently, so check them before starting.** The plugin's
install record is keyed on the folder path where `claude plugin install --scope project` was run, so a
machine that never ran it does not load the plugin and says nothing -- the session-start check reports
it. And `gh` and git must name the same account: `gh auth status` beside `git config user.name`, because
a claim written under one name while the commits land under the other answers the wrong question.

**If the test gate runs the machine out of memory**, pass `-MaxParallel 2` (it is forwarded to
`open-pr`'s gate). That runs every suite, two at a time, instead of on `ProcessorCount - 2` lanes -- it
costs wall-clock and removes the peak. **Do not reach for `-SkipTests` or `-SkipStaleCheck`**: the first
skips the gate this branch is about, and the second is the valve for the certificate check this branch
repairs.

**Expect step 3b to fire on this PR, and let the lap do its work.** This branch repairs the
stale-certificate gate, so its own PR goes through it. That is the intended proof: the forward lap it
adds is what brings the branch up to date and re-certifies. It is now the default, so nothing needs
typing -- but if several other lanes are shipping at the same time, ship this one on its own, because a
lap absorbs one trunk merge and the default budget is 2.

**One finding is already filed and is not part of this branch:**
[#2090](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2090) -- the ordering asserts in
`pr-issues.tests.ps1` read `ship-pr.ps1` by whole-file `IndexOf`, so adding a function above a step
re-points them. The four this branch broke are repaired and anchored; the remaining fourteen are that
issue's.

### CREATE

- [x] `scripts/lib/ci-fold-lib.ps1` -- does a CI runner fold off a push to the trunk? Reads
      `.github/workflows/` from disk; every ambiguity answers "no recovery", which is today's behaviour.
- [x] `scripts/lib/forward-lane-lib.ps1` -- the four decisions behind the forward lap, as pure functions.
- [x] `ship-pr.ps1` step 0a: read the verdict, and refuse only where nothing else folds. The deferred
      arm merges and hands the fold over, in the queue arm's own shape.
- [x] `ship-pr.ps1` step 5: guard the fold body, and step 5b, so a deferred run touches no trunk and
      does not announce releasing one it never took.
- [x] `ship-pr.ps1` step 3b: wrap the whole measurement in a bounded lap loop; on a stale reading,
      forward through GitHub's `update-branch`, wait for a genuinely new certifying run, fast-forward the
      local ref so step 4's invariant holds, and measure again.
- [x] `-MaxForwardLaps` (default 2, `ValidateRange(0,10)`); `0` restores the pre-#2087 behaviour.
- [x] Fold the queue path's own hard-coded `fold-on-merge.yml` file test (#1516) into the same verdict --
      it answered "nothing folds here" on a repo that had merely renamed its runner.
- [x] Register both libs in the shared-scripts registry, regenerate the plugin mirrors, and add their
      rows to `plugins/dkj-policy/scripts/README.md`.
- [x] Document both repairs and the new parameter in the `ship-pr` skill page.

### TEST

- [x] `scripts/tests/ci-fold-lib.tests.ps1` -- 59 asserts. The negative cases outnumber the positive
      ones on purpose: a false negative costs a refusal already being paid, a false positive costs a
      merged-and-unfolded trunk. Pinned against this repo's own `.github/workflows/` as well as against
      fixtures, with a negative control on the same real files.
- [x] `scripts/tests/forward-lane-lib.tests.ps1` -- 60 asserts, including the structural half: that
      `ship-pr.ps1` actually laps on these decisions rather than computing them and refusing anyway.
- [x] Both suites found a real defect on their first run, which is recorded where it was fixed: the
      recogniser skipped every colon-less line and so never saw a block-sequence `- main` entry, and
      `Test-CertificateRenewed` refused a blank element with a binding error -- inside the poll that runs
      between the merge gate and the merge.
- [x] Lint gate green (`check-plugin-integrity.ps1`), including the two findings it raised about this
      change: the undocumented parameter and the missing mirror rows.
- [x] All test suites green.

### DEPLOY: fix/2087-ship-pr-converges-under-parallel-lanes

`ship-pr` now lands a branch on a busy trunk instead of refusing it. Two blockers are gone, and neither
gate was weakened to do it.

A **stale certificate is repaired rather than reported**: on a stale reading the script brings the branch
up to date through GitHub's own `update-branch`, waits for a genuinely new certifying run, and takes the
same measurement again -- up to `-MaxForwardLaps` times, default 2. The predicate is untouched, so
`-SkipStaleCheck` is still the only way to merge on an old certificate; what changes is that the remedy
costs a CI cycle instead of however long it takes somebody to read a refusal and retype four commands.
Each lap is CI-bound, so the TRUNK takes one merge per CI cycle instead of none. That is a claim about
throughput and not about any one lane: a lap absorbs exactly one trunk merge, so a lane contending with
several others can still exhaust its budget and refuse -- the bound is a stop-loss, and the refusal says
so. A conflict, a branch already current, or a red check on the forwarded head all end the run rather
than lapping. Worth knowing before upgrading: the trigger is "the trunk moved", not "several lanes are
shipping", so a single-lane repo meets this too -- and a lap pushes a merge commit to the branch, made by
GitHub, which is what the printed remedy always told an operator to do by hand. `-MaxForwardLaps 0` keeps
the old behaviour.

And **a trunk held by another checkout no longer blocks the merge** where a CI runner folds. That
refusal's ground -- "step 5 could not fold" -- stopped being true when `fold-on-merge.yml` began folding
off every push to the trunk, not only a merge queue's; it was gated on the queue when the thing it
depends on is the runner. A repo with no such runner is refused exactly as before, and the refusal now
says which read came back empty.

Measured, September 17, 2026: five pull requests sat `CLEAN` and `MERGEABLE` with every check green and
none of them merged, against a trunk taking 33 first-parent commits in a day. PR #2062 recorded seven
refusals in a row, one of them 48 commits behind; PR #2076 was refused on the worktree instead.

**Score:** 5

#### What makes this deploy extra special

A consumer running this workflow with more than one lane could not land work on a busy trunk, and the
two mechanisms that stopped them are both repaired in the shared scripts -- so the fix arrives with a
plugin update and needs no repo setting, which is the half a merge queue could not deliver: GitHub
offers one on a private repo only under Enterprise Cloud, and otherwise only on a public repo owned by
an organisation.

**Score:** 4

#### Pull Request

ship-pr converges under parallel lanes: it forwards the branch itself, and a busy trunk no longer blocks the merge
