## fix/2005-slow-fixture-shared-dir

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

Section 10 of `test-suite-gate.tests.ps1` pointed `$slowDir` at the fixture directory
`suites-slow`, which section 5 has **already** filled with six suites that each sleep 1.2s. So the
3s bound that case sets was a ceiling on those six as well, and the gate ran eight suites where the
case only ever reasoned about two.

#### What the CI log actually said

The issue stated the cause as unestablished -- the fixture's captured output lives in the run's
scratch tree rather than in the log. It is in the log: `Assert-Says` prints the whole haystack on a
failure, and attempt 1 of run 34875895039 is still retrievable through
`gh api repos/.../actions/runs/34875895039/attempts/1/jobs` after the green re-run replaced the
current attempt. Job `suites (4)`:

```
test gate: running all 8 test suites for the fixture (2 at a time)...
...
== s1.tests.ps1 == TIMED OUT after 4.4s (bound 3s) -- its process tree was killed; no verdict
...
test gate: 2 of 8 suites FAILED in 13s (2 lanes): s1.tests.ps1, s-wedged.tests.ps1
           did not finish within the 3s bound: s1.tests.ps1, s-wedged.tests.ps1
```

So there is **no ordering gap between the header path and the verdict path**, which is what the
issue proposed as one of its two candidate causes. The two agree exactly: `s1.tests.ps1` took 4.4s
under contention, the gate timed it out and named it, and the verdict listed both names in sort
order. The assert wanted `s-wedged.tests.ps1` alone, so it failed over a gate that was behaving
correctly. The issue's other candidate -- a margin less generous than it reads under CI contention
-- is right in substance and one suite over from where it was looking: the sleepers were the ones
against the ceiling, not the wedged suite.

The `s-quick` plain-header assert did rule out `s-quick` as the second name, as the issue argued.
It could not rule out `s1`, because nothing in the case knew `s1` was in the pool.

#### And section 5 had already written the argument against this

Its own comment states the rule this case broke: *a timing FLOOR is a testable property, because
Start-Sleep guarantees it; a timing CEILING is not, because nothing bounds how slow a shared machine
can be.* That is why section 5 shrank its sleeps from 2s to 1.2s. Section 10 then put a 3s ceiling
over those same 1.2s sleepers by pointing at their directory.

`suites-slow` was the only fixture directory in this suite named by two sections; all 28 others are
used once.

### CREATE

- [x] `$slowDir` points at its own directory, `suites-deadline`, so the pool is the two suites this
      case creates and nothing else
- [x] the measurement recorded at the fixture, with the run and the quoted verdict line, and with
      section 5's floor-versus-ceiling rule named as the reason the reuse was wrong
- [x] a regression guard -- `running all 2 test suites` -- so a third suite in this pool reds one
      assert that says why rather than the name-list asserts that do not

### TEST

- [x] `test-suite-gate.tests.ps1` standalone: 207 pass, 0 fail (was 205 pass, 1 fail in CI / 206
      pass locally -- the guard is the new assert)
- [x] the deadline case now takes 3.8s against the 60s sleeper, where the eight-suite pool took 13s
- [x] full local gate + lint via `open-pr.ps1`

### DEPLOY: fix/2005-slow-fixture-shared-dir

`test-suite-gate.tests.ps1`'s deadline case ran in a fixture directory it shared with the
parallelism case, so its 3s suite bound also applied to that case's six 1.2s sleepers. Under CI
contention one of them exceeded the bound, the gate correctly named two timed-out suites on its
verdict line, and the case's assert -- which expects the wedged suite alone -- went red over a gate
that was behaving exactly right: intermittent in CI, green on re-run, green locally. The case now
has its own directory, so the pool is the two suites it creates, and a pool-size assert keeps it
that way. Cause established from attempt 1 of the failing run rather than inferred; the issue's
proposed ordering gap between the header path and the verdict path does not exist.

**Score:** 2

A flaky required check is noticed by whoever it stops, and this one stopped a merge and was cleared
by a re-run that proved nothing. But it is one assert in one suite of this repo's own gate, it had
fired once, and nothing about the gate itself was wrong -- so it is small, and a reader who was not
blocked by it would need to be told.

#### What makes this deploy extra special

The repair is a directory name, and the finding is that the issue's own stated reason was wrong in
a way that would have produced a wrong fix. Both candidate causes it named -- an ordering gap
between the header and verdict paths, or a margin too tight for the wedged suite -- point at the
gate; the log shows the gate was right and the fixture was wrong. A repair built on either would
have loosened a correct assert or widened a bound that was never the problem, and it would have
carried a citation.

The retrieval is worth keeping too: `gh run rerun --failed` replaces the current attempt, so the
red job's log looks gone from `gh run view`. It is not -- `actions/runs/<id>/attempts/1/jobs` gives
the job ids, and `actions/jobs/<id>/logs` gives the log. The issue's "I did not establish which"
was one API call from being established.

**Score:** N/A

#### Pull Request

Give the deadline case its own fixture directory
