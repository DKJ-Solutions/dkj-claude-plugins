## fix/2217-pretooluse-guards-fail-open

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

#### The report's reason, verified before anything was built

#2217 says both guards fail open because PowerShell fails before it loads the script and the harness
classifies that as non-blocking, and it leaves three questions open on purpose. Each was answered
against evidence rather than assumed:

- **Is a start failure distinguishable from a hook's own non-blocking exit?** No. The transcripts on
  this machine hold four `hook_non_blocking_error` records for a sibling guard
  (`guard-direct-main-hook.ps1`, smartwatchbanden), with exit codes **127, 45, 66 and 1** -- the last one
  `uv_spawn` failing before any shell ran. None is 2, and the code is arbitrary, so it cannot be matched
  on. The issue's own two events (`guard-live-theme`, `guard-working-copy`) are in another checkout and
  are not on this machine; the mechanism is verified on the sibling, not on those two.
- **Can `hooks.json` declare a start failure as blocking?** No. The hooks documentation states that exit 2
  blocks, that any other code does not, and that a crashed or timed-out hook does not block either; it
  offers no fail-closed setting. It does offer a `shell` field and states that the default is bash
  (PowerShell only where Git Bash is not installed) -- which is what makes the third answer possible.
- **Failing both, can it be reported?** Not at session start: the failure is per call and transient, so
  no session-start check sees it. Not built here; a follow-up if it is wanted.

**The repair is therefore not in either `.ps1`** -- no line of them runs on a start failure -- and lives in
the one layer above the interpreter: the `hooks.json` command is a bash wrapper. It passes 0 and 2
through, and on any other exit code refuses (exit 2) **only when the payload looks like the guard's
subject**: a Shopify theme command for the live-theme guard, a subagent running git for the working-copy
guard. Any other call passes the failure through as it always did.

#### Decisions, and who made them

Narrow rather than blanket, because a blanket refusal would block every Bash call on a machine whose
PowerShell is unwell to protect two rules that concern a small fraction of them. **Dave chose the narrow
wrapper over "document only" and over "live-theme guard only"** when the choice was put to him, with the
cost below stated.

**The cost, stated rather than hidden:** a machine with no Git Bash runs the hook string in PowerShell,
where bash syntax does not parse, so the guard does not run there at all. That is a regression for such a
machine and it cannot be tested from here. `command -v powershell` failing (a platform without PowerShell)
exits 127 exactly as the hook always did there.

### CREATE

- [x] Measured the three open questions (exit codes from the transcripts, the hooks documentation, a
  failed `-File` under Git Bash returning 127) before writing anything.
- [x] Replaced the `PreToolUse` command in `plugins/dkj-subagents/dkj-subagents-shopify/hooks/hooks.json`
  and `plugins/dkj-policy/hooks/hooks.json` with the narrow bash wrapper.
- [x] Added a header paragraph to `guard-live-theme.ps1` and `guard-working-copy.ps1` saying why
  `hooks.json` wraps them, since that is where somebody reading the wiring will look.
- [x] Wrote `scripts/tests/hook-fail-closed.tests.ps1`.

### TEST

- [x] `hook-fail-closed.tests.ps1`: 43 passed, 0 failed with the wrapper. Run against the original
  `hooks.json` files (stashed) every fail-closed case goes red and the pass-through cases stay green, so
  the suite discriminates. It runs the real command string from each `hooks.json` under Git Bash against
  a stub `powershell` that returns 1, 45, 66 and 127, and end to end against the real guards.
- [x] `check-plugin-integrity.ps1`: 0 errors (including `[script-ascii]` on the new suite).
- [x] The suites nearest the change, run alone: `guard-live-theme` 110, `guard-working-copy` 32,
  `working-copy-guard-lib` 92, `closeout-gate` 47, `cycle-autopark` 25 -- all green.
- [x] Overhead measured: median about 1.1 s per call both with and without the wrapper (that is
  `powershell.exe` startup); the added forks are inside the noise.
- [x] The full suite gate is `open-pr.ps1`'s own first step and pushes nothing if it fails.

### DEPLOY: fix/2217-pretooluse-guards-fail-open

Two guards this workflow ships -- the live-theme guard and the working-copy guard -- used to fail open:
when PowerShell could not start (out of memory, a failed type initializer), no line of the guard ran and
Claude Code let the command through. Their `hooks.json` entries are now a small bash wrapper that turns
that failure into a refusal, but only for a call the guard exists for: a command naming a Shopify theme,
or a dispatched subagent running git. Every other call behaves exactly as before, so a machine with an
unhealthy PowerShell is not locked out. The wrapper assumes the hook shell is bash, the documented
default wherever Git Bash is installed; a machine without it runs the hook in PowerShell, where the
wrapper does not parse, so the guard does not run there.

**Score:** 3

#### What makes this deploy extra special

A store or a repo running the Shopify or policy plugin is now protected in the condition where its
machine is least healthy: a `shopify theme publish` or a live push no longer goes through just because
PowerShell ran out of memory at that moment, and a subagent's `git checkout` no longer reaches a
checkout holding uncommitted work. Nobody notices this until the failure it prevents would have
happened -- measured on smartwatchbanden, four start failures on one guard in the transcripts. The one
subscriber who does notice something is a machine without Git Bash, whose guard stops running; that is a
cost of the fix, and it lands only when the plugins are next updated.

**Score:** 1

#### Pull Request

Both PreToolUse guards now fail closed when PowerShell cannot start, for the calls they exist for

