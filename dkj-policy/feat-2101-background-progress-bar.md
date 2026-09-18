## feat/2101-background-progress-bar

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

Publish progress from the long-running scripts and render it in the statusline, so a backgrounded run
is visible.

#### What the issue asks, and what a session can actually put on screen

#2101: *"Toon altijd een progress bar als er iets op de achtergrond draait dat ik niet in de VSC
terminal kan zien."* The premise is exact, and it was verified against Claude Code's own documentation
on 2.1.276 before anything was built: a `Bash` call made with `run_in_background` streams **no** stdout
to any visible surface -- the output is retrievable afterwards from `/tasks` or the task's output file,
which is a different thing from watching a run -- and the terminal CLI and the VS Code extension behave
the same way here. So the gate's progress line (#1717) and `ship-pr`'s watch are both written for a
reader who, in the one case they are needed for, is not there.

Three further facts decided the shape:

- **The `statusLine` is the only persistent surface.** It accepts multiple lines and ANSI, and it has a
  `refreshInterval` (minimum 1 s) that exists for exactly this -- the documentation says its
  event-driven triggers "can go quiet when the main session is idle", which is the state a backgrounded
  run leaves a session in.
- **There is no native progress UI**, and no marker a script can emit that becomes one.
- **`OSC 9;4`, terminal-title control and a `Notification` hook are undocumented or absent**, so the
  status line is not one option among several.

#### The shape: publish and render, never print

The script that knows its own progress writes a small record; the statusline reads every live record and
draws the bar. The two halves never meet in a pipe, which is the point -- the pipe is what the
background hides.

**The renderer derives elapsed itself**, which is load-bearing rather than an optimisation: `ship-pr`
hands twelve minutes to a single `gh pr checks --watch` call, so a design where the bar advanced only
when the producer wrote would freeze for the whole wait it exists to cover.

### CREATE

- [x] `scripts/lib/run-progress-lib.ps1` -- the record: `Write-RunProgress` / `Complete-RunProgress` /
      `Get-LiveRunProgress`, plus `Format-ProgressBar`, `Format-ElapsedShort` and
      `Format-RunProgressLine`. Per-user root (`LOCALAPPDATA`, for session-cache-lib's reasons), and a
      write-aside-then-move so a reader on its own clock cannot land mid-write. Every failure path
      returns `$false` rather than throwing: a diagnostic must not be able to cost the run it describes.
- [x] **Liveness is the writer's process, never the record's age.** A healthy watch publishes once and
      then blocks for minutes, and #1941's gate sat for 141 minutes printing nothing, so an age test
      would hide precisely the run a reader most wants to see. The pid is paired with that process's
      **start time**, so a reused pid cannot resurrect a finished run's bar. A 12-hour cap sits behind
      both, for the one state liveness cannot reach: a machine powered off mid-run.
- [x] `scripts/task/show-progress.ps1` -- the `statusLine` command. Bar lines first, context line
      (`repo  branch  model`) second. The branch is read out of `.git/HEAD` as a **file**, worktree
      pointer followed, so the hot path spawns nothing. Always exits 0.
- [x] Producer 1: the test gate -- both lane events in `Invoke-TestSuiteGate` publish beside their
      existing `Write-Host`, and the `finally` clears. One event, two surfaces, neither derived from the
      other's text.
- [x] Producer 2: `ship-pr`'s CI wait -- published at the exact moment the invitation tells the reader
      to background the run, and cleared when the watch returns rather than at process exit, because
      that script goes on merging and folding for minutes afterwards.
- [x] `.claude/settings.json` -- the `statusLine` block, at `refreshInterval: 2000`.
- [x] Mirrors: `native-capture-lib.ps1` to both its plugin copies, `ship-pr.ps1` to its one.
- [x] `scripts/README.md` -- its "five scripts invoked by something other than a person" claim was about
      to go stale; it is six now, and the sixth is named.
- [x] Sylvester's lens -- the ownership bullet, the four decisions behind it, and the measured cost.

#### Two things deliberately NOT built, both filed rather than left in a close-out

- **#2103** -- a consumer gets none of this. The dot-source into `native-capture-lib.ps1` is **guarded**,
  which is what let that file stay byte-identical to its two mirrors; shipping the bar outward is one
  more mirrored file plus an `adopt-dkj-policy` seam for a settings key no plugin component can place.
- **#2104** -- the issue says *anything*, and this covers the two long waits this workflow owns. A
  backgrounded `npm test` or a dispatched subagent still publishes nothing. The `PreToolUse` shape that
  would close it has a measured objection (`PostToolUse` fires when the tool CALL returns, not when the
  process ends, so it would clear a background record immediately) and a measured cost (~400 ms on every
  `Bash` call), so it is a measurement job rather than a patch.

#### ASCII glyphs, and that is this repo's own prohibition rather than taste

A bar of U+2588 blocks would have to survive Windows PowerShell 5.1's stdout encoder, which uses the
console code page -- and the one repair for that, `[Console]::OutputEncoding`, is `SetConsoleOutputCP`,
console-**wide**, which `.claude/rules/language-layers.md` forbids outright and which the test gate's
shared console is the standing reason for. Mojibake in the one line that is always on screen is not a
cosmetic defect. `#` and `-` cost nothing in meaning.

### TEST

- [x] `scripts/tests/run-progress.tests.ps1` -- **46 asserts, all green.** The liveness cases are where
      the value is, and both are walked with a **real** process rather than a fabricated pid: a writer
      that has exited (dropped **and** reaped), and a live pid whose start time does not match (dropped).
      Beside them the two that must **not** drop: a two-hour-old record with a live writer, and a file
      the reader cannot parse -- skipped, and deliberately left on disk, because a reader that deletes
      what it cannot read destroys evidence.
- [x] The suite found a real defect before the code was ever run in anger: `[math]::Max(0, $Seconds)`
      binds the **int** overload, so PowerShell converts the double by **rounding** it -- 59.9 came back
      as 60 and `59s` rendered as `1m00s`. Repaired at both call sites with a plain comparison, which
      cannot pick an overload and cannot round. Exactly the class the system-administration manual's
      trap section is about: well-formed, plausible, wrong.
- [x] Live end-to-end, against the **real** `Invoke-TestSuiteGate` over a six-suite fixture at two lanes,
      sampling the statusline command while it ran -- the bar advances during the run and is gone the
      moment it ends:

      sample 1 : [####--------] 2/6  test gate (2 running)  +5s
      sample 2 : [######------] 3/6  test gate (2 running)  +10s
      sample 3 : [########----] 4/6  test gate (2 running)  +14s
      sample 4 : dkj-claude-plugins  feat/2101-background-progress-bar

- [x] Cost measured rather than assumed: **206 ms** per refresh on this machine, nearly all of it the
      bare `powershell` launch a command statusline cannot avoid -- the same floor the `PreToolUse`
      guard already pays. At 2,000 ms that is about a tenth of one core while a session is open.
- [x] `check-plugin-integrity.ps1`: **0 errors**, including `[script-ascii]`, `[mirror-depth]`,
      `[plugin-lib]` and the shared-script drift check over all three mirrored files.
- [x] The statusline does not hang when somebody runs it by hand: stdin is read only when
      `[Console]::IsInputRedirected`, because `ReadToEnd` on a live console waits for a Ctrl+Z that is
      never coming.

#### Test gap, named rather than papered over

Nothing asserts that **Claude Code** renders what this script prints. The suite proves the command's
stdout, its exit code and that it never throws; the harness's own rendering is not reachable from a
test. It was verified by hand instead, which is why the settings block and the interval are stated in
the lens with their measurement beside them.

### DEPLOY: feat/2101-background-progress-bar

A progress bar for the runs a session cannot see. A backgrounded `Bash` call streams no stdout to any
visible surface, so the two longest waits in this workflow -- the test gate and `ship-pr`'s CI watch --
now **publish** their progress to a small per-user record, and a new `statusLine` command
(`scripts/task/show-progress.ps1`, at a 2-second refresh) draws it: `[#####-------] 37/84  test gate
(7 running)  +6m12s` while the gate runs, `... ship-pr: CI on PR #2103  +11m48s` while the watch does.
Liveness is the writer's **process** and never the record's age, so a run blocked for twelve minutes
keeps its bar while a run that was killed loses it within seconds. A fraction nobody measured is never
invented: a wait with no counts gets an elapsed readout and deliberately no bar, and there is no ETA
anywhere. Consumers are unaffected -- the dot-source into `native-capture-lib.ps1` is guarded, so that
file stays byte-identical to its two plugin mirrors and the gate behaves there exactly as it did.

**Score:** 4

#### What makes this deploy extra special

N/A -- nothing here reaches a subscriber of this service. The bar is wired into this repo's own
`.claude/settings.json`, and `statusLine` is a settings key rather than a plugin component, so no
consumer receives it from a release; the shared files that changed carry a guarded dot-source and behave
in a consumer exactly as they did before. Shipping it outward is #2103, and that is the change a
subscriber would notice.

**Score:** N/A

#### Pull Request

A progress bar for work the terminal cannot show

