## fix/1920-new-branch-tests-flaky-at-16-lanes

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

#### What the report established, and what it only inferred

[#1920](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1920) reports
`new-branch.tests.ps1` red at 16 lanes and green at 4 or 1, with every failure the same shape:
`new-branch` exiting 1 where 0 was expected. The measurement stands and was not re-litigated.

**Its stated REASON does not follow from the evidence it cites**, and that is checked before it is
repaired (the rule in `CLAUDE.md`). The report concludes "it is not running to completion" because the
other asserts in each failing scenario passed "in the it-did-nothing direction", naming three:
`the uncommitted foreign document is byte-for-byte untouched`, `the branch ref is NOT on origin`,
`nothing was committed`. **All three are what those scenarios assert on a SUCCESSFUL run** -- (n2)
exists to prove nothing aims at a foreign legacy document, and (p) exists to prove `-NoPush` leaves
origin empty and commits nothing. They are the expected passes, so they say nothing about whether the
run finished.

#### What the evidence DOES pin, read off the failure counts

The report gives a count per scenario, and those counts are the usable half. Against the suite:

| scenario | reported | asserts that fail if the run refuses before the checkout's own output |
|---|---|---|
| `legacy/foreign` (n2) | x2 | exit code; `and this branch got its own document instead`. The other two are negative/success asserts and pass. |
| `-NoPush` (p) | x2 | exit code; `says the branch stayed local`. The origin and commit-count asserts pass. |
| `idempotent second run` (a) | x3 | exit code; `already existed`; `already written`. `HEAD stays on the same branch` still passes -- the first run left it there. |
| `-Park` (i) | x3 | exit code; `reports the branch was parked on origin`; `exactly one park commit`. |

**Four scenarios, four exact matches, on one hypothesis:** the run refused BEFORE the checkout's
success line and before the document was written, having created nothing. Nothing else in the suite
produces those four numbers.

#### Which refusals live in that window -- and the one that is wrong on its own terms

Three, and each is gated on the exit code of a git child process: the repo-root fallback
(`git rev-parse --show-toplevel`, #1913), the identity probe (`git var GIT_AUTHOR_IDENT`, #1867), and
the checkout itself. The first and third MUST refuse -- without a root or a branch nothing can
proceed, and since #1913 both name their cause in git's own words.

**The second must not, and did.** `Test-GitCanCommit`'s docstring has said since #1867 that an
unmeasurable answer is can-commit: *"a refusal built on a failure to measure would wedge a run for the
wrong reason."* Its body read `$res.ExitCode -eq 0`, so every non-zero exit refused -- a killed probe,
a timed-out one, any of them -- and `new-branch` then exits 1 with nothing created. Only the throw
path and a `$null` result were ever honoured. That is a defect against a written contract, independent
of whether it is what fired here.

#### The corroboration, and the limit of it

`Test-GitCanCommit` entered `new-branch.ps1` on **2026-09-11** (#1867). This suite then collected
three gate-only flake reports in the two days after: #1913 (09-12), #1915 and #1920 (09-13). And
#1915 independently **measured** the primitive -- a git child transiently failing inside a fixture
under this same 16-lane gate, on the same day -- which is exactly the input this probe was turning
into a refusal.

**Stated plainly: the causal link to #1920 is inference, not a captured reproduction.** It did not
fire here in ~5,600 invocations (three full 16-lane gate runs including one under doubled load, plus
two targeted stress harnesses of 960-1,680 invocations each; 6,000 spawns also cleared the suite's
exit-code read, so `Invoke-CapturedChild` is not misreporting). The report's own runs predate #1913,
whose `Assert-ExitCode` now prints the child's output -- so if this recurs it arrives naming its cause
instead of as two bare numbers.

#### Deliberately not done

- **No retry, at either layer.** `Invoke-TestSuiteGate` declines to re-run a suite that exits 1, and
  that decision is left standing: the two refusals that remain in this window genuinely have measured
  the tree.
- **The OS-level cause of a transient git failure is not chased.** It is environmental and outside
  this repo; what is in scope is not converting it into a verdict.

### CREATE

- [x] `Test-GitCanCommit` refuses only on git's own `128`; exit 0 is can-commit, and every other
      non-zero exit -- plus a timed-out capture -- is the "unknown" the docstring already promised.
- [x] The discriminator is a named constant, `$script:GitAuthorIdentityUnknownExitCode`, because two
      readers have to agree on it: this function, and the fixture sanity assert in
      `new-branch.tests.ps1` that pins git's side of the number.
- [x] `plugins/dkj-policy/scripts/lib/git-identity-lib.ps1` re-synced -- byte-identical, per the
      shared-scripts drift lint.

### TEST

- [x] Seven asserts added to `git-identity-gate.tests.ps1`, driving the lib directly with a shadowed
      `Invoke-NativeCapture` (the idiom `remote-ahead-lib.tests.ps1` already uses) so no git runs and
      the cases stay machine-independent like the rest of that suite: exit 0, exit 128, four
      non-answering exits, a timeout at 128, a `$null` result, and the stub's own removal.
- [x] **Proven against the old body**: restoring `$res.ExitCode -eq 0` turns exactly the five new
      regression asserts red (5 failed, 43 passed); the repaired body is 48/48.
- [x] `new-branch.tests.ps1` green standalone (279 asserts) and under the gate.
- [x] Full gate green at 16 lanes, 102/102.

### DEPLOY: fix/1920-new-branch-tests-flaky-at-16-lanes

`Test-GitCanCommit` refused on any non-zero exit from its `git var GIT_AUTHOR_IDENT` probe, while its
own docstring promised the opposite -- that an answer it could not measure is treated as can-commit,
because "a refusal built on a failure to measure would wedge a run for the wrong reason". Only a throw
and a `$null` result were honoured; a probe that was killed, timed out, or failed for any other reason
was read as a checkout that cannot commit.

That probe runs on every `new-branch.ps1` run, before the checkout, and its refusal exits 1 with
nothing created -- no branch, no document, nothing on origin. Under the parallel test gate
`new-branch.tests.ps1` invokes that script some forty times per run across sixteen lanes, so one
transient git child turned into a red gate that had measured nothing, and a red gate that measured
nothing is what teaches people to reach for `-SkipTests`.

A refusal is now gated on `128`, which is how git's `die()` reports an unknown author identity and the
number this suite already pins from git's own side. Everything else -- including a bounded call that
expired -- is the "unknown" the contract always described. `check-git-identity.ps1` reads the same
function and stops reporting a broken identity on a probe that never answered.

**Score:** 3

#### What makes this deploy extra special

N/A -- a probe's exit-code reading inside this workflow's own scripts. A consumer sees no change in
behaviour except the one they should never have seen: a branch refused because a git call under load
did not answer.

**Score:** N/A

#### Pull Request

new-branch.tests.ps1 no longer false-reds under the parallel test gate at high lane counts

