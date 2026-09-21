## fix/2233-gate-lane-stdin

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

#### What was reported, and what of it survived the read

[#2233](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2233) reported three suites wedging
at zero CPU under `Invoke-TestSuiteGate` on DAVE-KOK-BWJ while passing standalone in seconds, so a
local gate run could not go green. The report's **measurements** stood: four gate runs, four lane
counts, the same three suites, every one of them holding exactly one hook-shaped child and no
grandchild below it.

Its **cause was offered as a guess and said so** -- that the pool's `Start-Process` redirects stdout
and stderr while leaving stdin inherited, so a child reading to end-of-stream blocks forever. Read
against the code, that half is exactly right: `scripts/lib/native-capture-lib.ps1` spawns each lane
with `-RedirectStandardOutput` and `-RedirectStandardError` and says nothing about stdin, at **both**
of its spawn sites.

- [x] Verify the symptom against the tree rather than accepting the report -- all three children do read stdin by design (a statusline renderer and two session checks)
- [x] Verify the proposed cause names a mechanism that exists -- it does, and at two spawn sites rather than the one the report implies

### CREATE

- [x] The pool hands every lane an **empty file** as stdin, so no child inherits a handle the gate never closes -- `$laneStdin` in `Invoke-TestSuiteGate`
- [x] Both spawn sites take it, the pool's and #1723's crash re-run -- the re-run is the one that waits **unbounded**, so a wedge there has no deadline to convert it into anything at all
- [x] Mirror the lib into the two plugin copies via `scripts/sync/build-shared-scripts.ps1`, so the drift lint stays quiet
- [~] Repair the children themselves -- dropped deliberately: a hook whose own stdin bound does not bind is that hook's defect, it is not what this issue is about, and its repair is not a one-line change. Filed as [#2249](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2249) with the three mechanisms already measured and rejected

### TEST

Both halves of the repair were verified against the condition the report was measured under -- a gate
started from a parent holding stdin **open** and never closing it. Without that, a fixture reaches EOF
for the wrong reason and proves nothing.

**A/B on the real suites, through the real gate:**

| suite | before | after |
|---|---|---|
| `adopt-statusline` | TIMED OUT at the bound | passed, 4.4s |
| `connector-sessioncheck` | (wedged as reported) | passed, 29s |
| `connectors` | (wedged as reported) | passed, 70s |

- [x] Regression test added to `scripts/tests/native-capture.tests.ps1`, in two parts that fail for different reasons: a **source** assert that every `Start-Process` in the gate body redirects stdin (so a third spawn site added later fails here), and a **behavioural** one that runs the real pool, from a parent holding stdin open, over a fixture suite whose **grandchild** reads to end-of-stream
- [x] The grandchild shape rather than a suite reading directly -- it is what was measured, and it also proves the empty handle is inherited down the tree
- [x] Confirmed the test fails without the repair (`277 pass, 2 fail`) and passes with it (`279 pass, 0 fail`) -- a regression test that cannot fail proves nothing

### DEPLOY: fix/2233-gate-lane-stdin

A test-gate lane is no longer handed the gate's own stdin. `Invoke-TestSuiteGate` redirected stdout and
stderr and said nothing about stdin, so every suite inherited the gate's handle and passed it on to
whatever it spawned. Where the gate itself runs under a pipe nobody closes, a child that reads stdin to
end-of-stream blocked forever -- zero CPU, no output, no error -- and #1941's per-suite deadline then
converted that into a 30-minute red naming a timeout rather than a defect. Each lane now gets an empty
file instead, at both spawn sites, so the read returns at once. Measured on the three suites that
wedged: all three now pass through the gate under exactly the condition that wedged them, the slowest
in 70s against a 30-minute refusal.

**Score:** 4

#### What makes this deploy extra special

Anyone running this workflow's own gate gets it: `open-pr` could not open a pull request at all on a
machine in this state, and the half-hour it took to refuse is the shape that gets a gate bypassed by
habit rather than by decision. The repair is at the pool, so it covers every suite at once rather than
the three that happened to be caught.

**Score:** 3

#### Pull Request

A test-gate lane no longer hands its suite the gate's own stdin
