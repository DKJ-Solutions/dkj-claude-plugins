## feat/2104-backgrounded-call-progress

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

#### What #2101 left open

The bar covers the two long runs this workflow OWNS -- the test gate's lane events and `ship-pr`'s CI
wait -- because each publishes from inside its own process. #2101 was asked for a bar for **anything**
running out of sight. A backgrounded `npm test`, a `gh run watch`, a long clone: nobody publishes, so
the statusline sits on its context line while the session is in fact busy.

#### The three things #2104 asked to have measured first

Measured on Claude Code 2.1.276 with a probe hook and a foreground control call, so a silence could be
told apart from a config that never loaded. Posted in full on the issue.

- **`PostToolUse` fires at call-return** -- 363 ms after `PreToolUse`, with 24.6 s of a `sleep 25` still
  to run, `duration_ms: 13`. The issue's first premise holds, and is now a measurement rather than an
  inference.
- **The task id IS recoverable** -- `tool_response.backgroundTaskId` is a structured field, not result
  text. The issue listed this as unmeasured; it lands in the favourable direction.
- **Polling it is not.** `TaskCreated`/`TaskCompleted` are real hook events -- the binary carries
  `executeTaskCreatedHooks`/`executeTaskCompletedHooks` -- and **neither fired once** across two
  backgrounded runs; they belong to the agent/teammate surface. Nor is there state on disk: the
  session's `tasks/` directory holds `<id>.output` and nothing else.
- **The cost objection is weaker than filed.** The matcher already carries TWO hooks, not one, and
  hooks on one event run in **parallel** -- so a third costs roughly zero wall-clock rather than
  doubling anything. That also removes most of the argument for folding this into
  `guard-working-copy.ps1`, which would have made one hook do two jobs.

#### The constraint the issue did not have, and the measurement that answered it

`Write-RunProgress` stamped `writerPid = $PID` and the reaper deletes any record whose writer is gone --
liveness is deliberately the writer's PROCESS. A hook lives about 400 ms, so **anything it published
would be reaped two seconds later**. "Call `Write-RunProgress` from a hook" could not work.

What rescues it: the backgrounded command's own shell IS visible at `PostToolUse` time -- a `bash.exe`
parented by the Claude Code process, 829 ms old, one `Win32_Process` query at 589 ms. Name THAT pid as
the writer and the existing liveness test does the entire job, with **no completion event** -- which is
exactly the thing that turned out not to exist.

#### Where it lives, and what it deliberately does not do

The hook is plugin payload, so unlike `statusLine` (a settings key, which is why #2103 needs an adopt
seam) it travels on its own. But `run-progress-lib.ps1` is source-repo only until #2103 mirrors it, so
this hook is **guarded**: it resolves the lib from the repo root and publishes nothing where it is
absent. That leaves #2103's three mirroring steps and its open `statusLine`-collision judgement
untouched rather than doing half of them here.

### CREATE

- [x] `Write-RunProgress -WriterPid` -- publish on behalf of another process. The pid and its start
      ticks are read from one local, so the pair that guards against pid reuse cannot drift apart.
      Omitted, it is `$PID` exactly as before, so every existing producer is unaffected.
- [x] `scripts/lib/background-run-lib.ps1` -- `Get-BackgroundRunPublishPlan` (a pure function of the
      payload text) and `Get-BackgroundShellProcessId` (the one part that asks the live machine).
      Registered as a mirrored pair and mirrored into `plugins/dkj-policy/scripts/lib/`.
- [x] `plugins/dkj-policy/hooks/publish-background-run.ps1` -- `PostToolUse` on `Bash|PowerShell`,
      behind the raw-string pre-gate `guard-working-copy.ps1` uses, so a foreground call pays the bare
      launch and nothing else. Always exits 0, never 2.
- [x] Registered in `hooks.json`, and a row added to the mirror README the shared-script lint requires.
- [~] `Complete-RunProgress` anywhere in the hook -- dropped, and the reason is the design rather than
      an omission: there is no event at which to call it, and none is needed, because the reaper already
      removes a record whose writer is gone.
- [~] Mirroring `run-progress-lib.ps1` so the bar works in a consumer -- dropped as out of scope. That
      is #2103's first step and it carries an unsettled judgement about a consumer that already has a
      `statusLine`. This hook is guarded so it is inert there, and starts working with no change here
      once #2103 lands.

### TEST

- [x] `scripts/tests/background-run-lib.tests.ps1` -- **38 pass, 0 fail**. Every publish/refuse decision
      driven from a payload string: foreground, no task id, no `tool_response`, whitespace id, non-JSON,
      empty, null; the repo-root precedence; the label fallbacks; and that a refused plan still carries
      every field so a caller reads one shape.
- [x] `-WriterPid` asserted in `run-progress.tests.ps1` -- **53 pass, 0 fail**. Including the one that
      matters: a record naming a dead process is reaped on the next read, while a live one beside it is
      untouched.
- [x] Lint gate green -- `0 error(s)`, after it correctly refused the missing mirror-README row.
- [x] **End-to-end against a real backgrounded call**, which is the only thing that could have caught
      what it did catch. The bar appears while the run is alive and disappears on its own when it ends,
      with no completion event and no record left on disk.

#### What the end-to-end run caught that no unit test could

The first live run published **nothing at all**. The shell's command line carries the command re-quoted
-- `eval 'echo \"E2E-2104 start\"; ...'` -- while `tool_input.command` has plain quotes, so a raw
`Contains()` matched nothing for any command holding a double quote, which is most of them. Both sides
now go through one reduction (`Get-CommandMatchKey`), and the measured pair is pinned in the suite so
the next reader does not have to rediscover it.

The same run also showed the label rendering as `... Second end-to-end backgrounded run (bac...` --
the note `backgrounded` being spent from the label's own ceiling. The note is now empty, asserted, and
the label renders in full.

### DEPLOY: feat/2104-backgrounded-call-progress

The progress bar now covers a backgrounded call this workflow does not own. A `PostToolUse` hook reads
the structured `backgroundTaskId`, finds the shell actually running the command, and publishes a record
attributed to **that** process -- so the existing liveness test shows the bar while the run lives and
removes it within two seconds of the run ending. There is no completion event for a backgrounded shell
and no state to poll; measured, both. `Write-RunProgress` gained `-WriterPid` for it, and existing
producers are untouched.

**Score:** 3

#### What makes this deploy extra special

Three of the issue's own premises changed under measurement, and the one it did not have turned out to
be the decisive one: liveness is the writer's process, so a 400 ms hook could not be the writer at all.
The whole design is the answer to that -- attribute the record to the shell, and the mechanism that
already exists does the rest.

It is also a reminder about what a unit test cannot buy. Every decision here is driven from a payload
string, 38 asserts, all green -- and the first real backgrounded call published nothing, because both
sides of the comparison were fixtures and the shell re-quotes what it is handed.

**Score:** N/A

#### Pull Request

The progress bar covers a backgrounded call this workflow does not own
