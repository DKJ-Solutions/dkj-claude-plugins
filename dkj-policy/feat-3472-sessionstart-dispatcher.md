## feat/3472-sessionstart-dispatcher

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Inbound #3472, verified on pickup. The 13 SessionStart interpreters on a `clear` hold: 10 + dev-preview in
`dkj-policy`, 1 in the core team, 1 in `dkj-solutions`. `Invoke-CheckScript` (#1625) already runs a
hook script in-process and survives its `exit`. So the repair is one dispatcher entry that runs every
`*-sessioncheck.ps1` beside it. The issue's "one in total" across plugins is declined: a plugin's hook only
knows its own `CLAUDE_PLUGIN_ROOT`, and reaching into a sibling plugin's cache is a coupling this tree has
nowhere else.

Measured before choosing, n=2, this repo: the ten checks in a loop 7529 / 7659 ms; in a runspace pool
3124 / 2967 ms. The harness runs entries in parallel, so a loop would have traded the cold starts for
~4.5 s on every start. A pool keeps the wall-clock at the slowest check.

Re-measured later under load (CPU ~38 %, other sessions on the box), interleaved, n=3: ten parallel`nprocesses 6151 / 6584 / 9445 ms, the dispatcher 7090 / 10944 / 7951 ms. Same range within the noise, so`nthe claim is robustness, not speed.

### CREATE

- [x] `plugins/dkj-policy/hooks/sessioncheck-dispatch.ps1`: discover, run in a runspace pool, merge plain
  and JSON output into one SessionStart object, 100 s deadline that names a hung check, the
  non-interactive git environment set once before the pool (the push/pop race in `native-capture-lib`)
- [x] `hooks.json`: the ten entries become one; `dev-preview-sessionstart` keeps its own
- [x] the three suites that pinned a per-hook entry now pin the dispatcher entry and the discovery pattern
- [x] prose that named `hooks.json`'s timeout as the backstop, and `SPECIALISTS.md`'s pointer to the set

### TEST

- [x] `scripts/tests/sessioncheck-dispatch.tests.ps1`, 32 asserts: wiring, merge order, JSON pass-through, a
  throw, a non-zero exit, silence, the environment, the pattern, the deadline
- [x] the dispatcher end to end on this checkout: the same eight lines this session's own start reported, the
  release-freshness systemMessage intact, 4.0 s
- [x] review, Victor: stdin is one handle per process, and two checks read the hook payload for their
  session cache, so on the pool only the first got it. The dispatcher now reads it once and hands it over in
  `DKJ_HOOK_PAYLOAD`, which `Get-HookPayloadRaw` prefers. A suite case with three concurrent readers passes,
  and goes red (3 of 3) with the handover line removed. The outer catch now leaves without waiting on the pool.
- [x] review, Sebastian: only a SessionStart JSON object is read as JSON, so a plain check cannot promote text
  to the `systemMessage`; a static guard holds every check to no process-wide state but the two
  non-interactive git variables. 47 asserts.
### DEPLOY: feat/3472-sessionstart-dispatcher

`dkj-policy`'s ten session checks now run from one SessionStart entry, `sessioncheck-dispatch.ps1`, in one
interpreter instead of ten ([#3472](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3472)). A
`/clear` in a consumer started thirteen cold `powershell.exe` processes at once, and under load some failed
before their script ran ("Unable to start thread"), each as a harness error. The checks still run in parallel,
on a runspace pool, so a session start takes about as long as before. A check that fails or
hangs now shows up as a named line in the report. A new `*-sessioncheck.ps1` in the plugin's `hooks/` runs
without a `hooks.json` edit.

**Score:** 3

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

SessionStart checks run from one dispatcher instead of ten cold interpreters

