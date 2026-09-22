## feat/2317-gate-cost-ci-wait

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

Issue #2317 measured seven full local gate runs on one machine in one session, while landing two
ordinary branches: 12,801s -- 3 h 33 min -- of gate for two pull requests, two of those runs
producing nothing at all. It names five levers, cheapest first. This branch builds the two that are
real work, and the other three are answered rather than built:

#### The five levers, and which of them this branch is

1. **Do not re-run the pool while CI is running.** BUILT. The biggest single waste measured, and the
   one the issue's title names: 2,595s (43.3 min) on PR #2316 spent re-proving locally what CI was
   proving on the same commit at the same moment, which could not make the merge happen one second
   sooner because `main`'s ruleset blocks the merge on that check whatever a local pool decides.
2. **Make the local proof survive a commit that changes nothing it measured.** NOT BUILT. A per-suite
   proof keyed on the files each suite reads needs a way to know what a suite reads, and nothing in
   this tree has one; the issue proposes the property rather than a mechanism. Filed as
   [#2323](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2323), with the three candidate
   mechanisms and the measurement that would settle which -- a design question with a number rather
   than a bullet inside a closed issue.
3. **Re-read memory during the run, not only at t=0.** BUILT.
4. **Pack lanes longest-first locally.** ALREADY TRUE -- verified against the tree before anything was
   written. `Invoke-TestSuiteGate` calls `Get-TestSuiteShardOrder` unconditionally with the hints from
   `suite-durations.json`, and at `ShardCount 0` that function returns the cost-descending order, so a
   local run has dequeued longest-first since #1358. Nothing to build; recorded on the issue.
5. **Split the four `check-plugin-integrity-*` files.** LANDED ALREADY, as #2304 (PR #2310), which the
   issue cites rather than restates.

### CREATE

- [x] Lever 1, the judgement: `Get-CiTestCertificate` gains a third state, `InFlight`. A named check
      that has FAILED and one that is STILL RUNNING were one refusal -- 'not green' -- and they are
      opposite facts. True only on a commit match; a check that has not registered stays a plain
      refusal, because absent is indistinguishable from never.
- [x] Lever 1, the loop: `Wait-CiTestCertificate` in `gate-lib.ps1`, bounded on laps AND wall clock,
      with the reads injected so every exit is walkable from a suite. Three outcomes -- certified,
      settled, gave-up -- two of which are byte-for-byte the old behaviour.
- [x] Lever 1, the wiring: `open-pr.ps1` waits on the in-flight branch only, and takes `-NoCiWait`;
      `ship-pr.ps1` forwards it. Every other refusal falls straight through to the pool.
- [x] Lever 3, the judgement: `Get-GateLaneStartVerdict` in `native-capture-lib.ps1` -- pure, over four
      integers, with the reading charged for lanes opened since it was taken so a burst at t=0 stops
      itself.
- [x] Lever 3, the wiring: the pool re-reads free memory before a lane start (throttled to
      `$script:GateLaneMemoryPollSeconds`), holds rather than opening one it has no room for, announces
      the hold on the transition, and puts the held seconds on the verdict line beside #2095's.
- [x] Scoped to runs where the gate chose its own lane count, exactly where
      `$script:TestSuiteGateLaneMemoryMB` already applies -- so CI, which passes `-MaxParallel`
      explicitly, is untouched.
- [x] Mirrors rebuilt (`build-shared-scripts.ps1`): both libs and both release scripts are carried
      into the plugin payload.

### TEST

- [x] `gate-lib.tests.ps1` -- the third state (in flight vs. red vs. green, the commit-match
      requirement, unanimity across a check's own records) and every exit of the wait loop, including
      the two that only a bound can reach.
- [x] A regression guard for the defect this suite found while being written: PowerShell scriptblocks
      are dynamically scoped, so the caller's `-Reader` could read the loop's own locals. A helper and
      a local both named `$reading` made every lap throw, be swallowed as an unreadable read, and the
      wait run to its bound -- failing as "CI never answered", which is indistinguishable from the real
      thing. The loop's locals are prefixed now and the suite asserts a caller's own names survive.
- [x] `test-suite-gate.tests.ps1` -- the floor asserted directly (the boundary, the burst charge, both
      allow-anyway rules), plus the plumbing: a pool that holds still passes every suite, announces the
      hold once rather than per poll, releases, and an explicit `-MaxParallel` never holds at all.

### DEPLOY: feat/2317-gate-cost-ci-wait

The local test gate ran twice for one answer. `ship-pr` calls `open-pr` immediately after the push, so
the required check has just started and the CI certificate is refused for the one reason that is about
to stop being true -- and the whole pool then re-proved, locally, the commit CI was at that moment
proving on a clean checkout. Measured over seven gate runs in one session: 12,801s of local gate for
two pull requests, of which one single re-run was 2,595s. It could not make the merge happen one
second sooner, because `main`'s ruleset blocks the merge on that check whatever a local pool decides.

`Get-CiTestCertificate` now separates a check that has **failed** from one that is **still running** --
they were one refusal, 'not green', and they are opposite facts -- and where the check is running on
this exact commit the gate waits for it instead of re-taking the measurement. Two of the wait's three
exits are byte-for-byte the old behaviour, and the third is a skip the caller was already entitled to:
nothing here can fail a gate, skip a suite or move a merge.

The second half is the lane count. It resolves once, at t=0, from a single memory reading, and #2317
measured what happens when that is wrong downwards: the pool is a background shell, and a harness that
finds the system critically low on memory **reaps** it -- 731s with 18 of 124 suites done, then 2,166s
with 54 of 124, neither producing a verdict. A lane start now consults a fresh reading and is held when
there is no room for one more lane. It can only delay a start, and it can never wedge, because nothing
running always starts.

**Score:** 4

#### What makes this deploy extra special

Two of the issue's five levers turned out not to be work at all, and finding that out cost one read
each. Lever 4 -- pack lanes longest-first locally -- has been true since #1358: the gate calls
`Get-TestSuiteShardOrder` unconditionally with the hints file, and at `ShardCount 0` that returns the
cost-descending order. Lever 5 had landed hours earlier as #2304. **The standing lesson is the one
this repo already writes down for an inbound report and does not always apply to its own plan: a
proposed repair is verified against the tree before it is built, because a plan is a snapshot of the
moment somebody wrote it.** Here the snapshot was eight hours old and the trunk had moved 44 commits.

The other half is a trap worth keeping. PowerShell scriptblocks are **dynamically** scoped, so an
injected `-Reader` runs in a child of the function's own scope and can read -- and be shadowed by --
its locals. A test helper named `$reading` and a loop local named `$reading` met, the caller's read
resolved to the function's `$null`, every lap threw, each throw was swallowed as an unreadable read,
and the wait ran to its bound. It fails as *"CI never answered"*, which is indistinguishable from the
real thing, on a mechanism whose whole job is to decide when to stop waiting. The loop's locals carry
a prefix now and the suite asserts that a caller's own names survive.

**Score:** 2

#### Pull Request

Stop the local test gate re-proving what CI is proving, and hold lane starts under a memory floor

