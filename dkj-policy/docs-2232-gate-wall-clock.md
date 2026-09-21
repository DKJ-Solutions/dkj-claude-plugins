## docs/2232-gate-wall-clock

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

Answer #2232 with the measurement it named, and record it where this repo keeps wall-clock findings:
[the performance lens](../.claude/specialists/lenses/specialist-06-25-lens.md). The issue asked whether a
~90-minute gate run at 120 suites was the degraded band #1703 described or simply 41% more suites, and
named the deciding reading — lane line, wall clock, sum of the per-suite rows, from one unpiped run.
Resolves #2232.

#### What the measurement had to survive to be worth writing down

- **Two runs, not one.** The first was started from a session whose stdin is redirected and never closed,
  and three suites wedged on it (#2233) — 118 of 121 finished in 410.2s while the rest sat at zero CPU.
  The second was started with stdin at EOF, which is what CI has. They differ by ~4.8x in what they would
  have reported, so quoting either without saying how the run started would have been the defect this
  section warns about.
- **The issue's own decision rule was applied and then held against the bound**, rather than quoted. It
  gives 63.7% utilisation, which its threshold reads as "ordinary growth"; the same pool is at 101.4% of
  `max(longest file, work÷lanes)`, which says the opposite. Both are in the section, with why the pair is
  the only readable form.
- **The stale hints file was NOT re-opened.** 91 of 121 suites are listed, so 30 are charged the maximum
  — and the September 9 section already measured that at most 13s of 1,806 locally and 0s on CI. Writing
  it up again as a lever would have contradicted a measurement this lens already carries.

#### What was deliberately NOT done

- **No change to the gate, its default, or its lane formula.** #2232 says in its own words that it
  proposes none, and #1703 left scope to the owner. The finding is that the pool is critical-path-bound
  on one file; what to do about that file is a separate judgement with its own cost.
- **`suite-durations.json` was not refreshed.** It is a CI-seconds file by construction and this run is a
  workstation's; `record-suite-durations.ps1` is the way, from CI's own tables.

### CREATE

- [x] [`specialist-06-25-lens.md`](../.claude/specialists/lenses/specialist-06-25-lens.md) — one new
      section, placed after the September 9 reading it extends: the table, the bound, why the utilisation
      threshold mis-reads a critical-path-bound pool, where the ~90 minutes actually came from, and the
      warning that a gate figure carries its session's stdin.

### TEST

- [x] The measurement itself is the test, and it was taken twice. Clean run: 121 suites, 22 lanes,
      makespan 421.2s, work 5,903.7s, longest file 415.5s — `makespan ÷ bound = 101.4%`.
- [x] Arithmetic re-checked against the run's own table rather than restated: 121 rows parsed,
      `max(StartOffset + Duration) = 420.7s` against a reported 421.2s wall clock.
- [x] The competing explanation was verified rather than inferred. `connector-sessioncheck.ps1` spawned
      twice outside the gate: stdin closed → exit 0 in 2.3s; stdin redirected and never closed → still
      running at 45s. The mechanism (`[Console]::In` is a `SyncTextReader`, so the documented
      `Wait(250)` is never reached) is traced on #2233's thread.
- [x] No script, manifest or hook changed, so there is nothing new for a suite to pin — the gates run on
      the lens as prose.

#### Two findings filed rather than carried

- **[#2239](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2239)** —
  `teardown.tests.ps1` failed inside the clean run at 22 lanes with an empty child capture and passed
  standalone (223 asserts) minutes later. Same shape as #1915/#1939/#2068. Filed at n=1, honestly.
- **[#2233](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2233)** already existed and called
  the stdin reading a guess; the verification was posted there as a comment instead of as a second issue.

### DEPLOY: docs/2232-gate-wall-clock

The gate's wall clock was re-measured at 121 suites, because #2232 reported ~90 minutes and asked whether
that was #1703's degraded band returning or simply a pool 41% larger than the last table. It is neither.
On an idle 24-core workstation the whole pool runs in **421.2s at 22 lanes**, and the makespan sits at
**101.4% of `max(longest file, work÷lanes)`** — the scheduler is at its floor, exactly the regime the
September 9 reading found at 16 lanes, and the pool simply *is*
`check-plugin-integrity-docs.tests.ps1` (415.5s). The 41% more suites are absorbed by lanes that were
idle behind that file anyway: work ÷ lanes is 268.4s, 147s below it. The ~90 minutes was
[#2233](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2233) — three suites blocking forever
on a redirected-but-never-closed stdin and released only by the 1,800s per-suite bound. The section also
records why #2232's own utilisation threshold reads this pool backwards, and that a gate figure quoted
without naming how the run was started is unreadable.

**Score:** 3

#### What makes this deploy extra special

Nothing here changes what a consumer runs — it is one section in a repo lens. What it buys the next
reader is the two things this measurement cost to learn. First, that a **utilisation number has a ceiling
set by the longest file**: this pool could not have exceeded 64.6% however perfect the scheduler, it
scored 63.7%, and the threshold #2232 proposed in good faith would have sent the next session looking for
growth instead of at the one file that sets the whole wall clock. Second, that **a wall clock measured on
a workstation carries that session's stdin**, invisibly — the same tree, minutes apart, reports 421s or
half an hour depending on a handle nobody names, and the gate's output does not mention it. Both are the
kind of thing that is obvious once written down and expensive every time it is not.

**Score:** N/A — this reaches nobody outside this repo. It is a lens section, not plugin payload, and no
consumer reads it.

#### Pull Request

The gate at 121 suites, measured: 7 minutes and critical-path-bound on one file
