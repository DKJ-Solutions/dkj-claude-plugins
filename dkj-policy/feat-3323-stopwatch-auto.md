## feat/3323-stopwatch-auto

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

The follow-up to #3315 (#3323, owner's choice of trigger: arm on the page, October 23, 2026): the clock times
Claude's work without anybody pressing Start or Stop.

#### Design

- **Arm, then a hook starts it.** `/stopwatch` gets an Arm form beside Start: a label is stored as `armed`
  (top level of the store, beside the runs) and no clock runs. Arming while a run is going is refused, arming
  again replaces the label, Disarm clears it. A `UserPromptSubmit` hook starts the armed run at the moment the
  next prompt is submitted (`Auto`, label = the armed label, `StartHead` = the checkout's HEAD) and clears the arming.
- **The stop is "HEAD moved and the checkout is back on the trunk", not "a branch was seen".** A Stop hook fires
  only at the end of a turn, and a whole ship (branch, PR, merge, fold) usually happens inside one turn, so a
  branch is never observed at a turn's end. The `Stop` hook ends a running Auto run only when the checkout is on
  the trunk, `git --no-optional-locks status --porcelain` is empty AND HEAD differs from `StartHead`. A turn that only answers a
  question leaves HEAD alone and the run keeps going; a branch parked for the owner's eye is not on the trunk, so
  it keeps going too. A run started by hand is never touched.
- **The rules are pure, the hook only gathers.** `Invoke-StopwatchHookEvent` takes runs, armed, branch, clean,
  HEAD, trunk and the clock, so every rule is tested without git. `scripts/dashboard/stopwatch-hook.ps1` reads the
  store and (only when a decision needs it) git, writes the store when the decision changed it, prints nothing and
  always exits 0. It never writes over a store that does not read. The trunk name comes from
  `Get-TrunkBranchName` in `scripts/repo-config.ps1` where this repo defines one, else `main`.
- **`Invoke-StopwatchAction` stays pure** and now takes `-Armed` and returns `Armed` beside `Runs` and `Error`
  (`arm` and `disarm` are two more actions); `Save-StopwatchStore` takes `-Armed`, `Read-StopwatchStore` returns
  it. Runs gain `Auto` and `StartHead`. The server's POST route accepts `arm` and `disarm` under the same
  same-origin rule.
- The page shows "Armed: <label> -- starts on your next prompt to Claude" with Disarm, and tags auto-started
  runs `auto`, in the table and on the running run. The house style is untouched: existing classes only.
- **Left out on purpose:** the hooks are wired in this repo's `.claude/settings.json` only, so they run for a
  session of this checkout and nowhere else; the store is shared with the hub server and the two writes are a
  read and a rename apart, which a button press against a turn boundary does not realistically hit.

### CREATE

- [x] `stopwatch-lib.ps1`: `armed` in the store, `Auto` and `StartHead` on a run, the `arm` and `disarm`
  actions, `New-StopwatchRun`, `Invoke-StopwatchHookEvent`, and the page's Armed line, Arm form and auto tag
- [x] `scripts/dashboard/stopwatch-hook.ps1`: the hook script for `UserPromptSubmit` and `Stop`
- [x] `serve-connector-dashboard.ps1`: the POST route takes `arm` and `disarm` and passes the armed state
  through; `dev-pages-lib.ps1`: the card subtitle no longer says "by hand"
- [x] `.claude/settings.json`: the two hook entries (a session cannot write a settings file, so the owner or
  the orchestrator pastes the block; tick this once it is in). The command is
  `powershell -NoProfile -ExecutionPolicy Bypass -File "$CLAUDE_PROJECT_DIR/scripts/dashboard/stopwatch-hook.ps1" -Hook Prompt|Stop`

### TEST

- [x] `stopwatch.tests.ps1`: arm and disarm rules, the hook's decisions (start, no start with a run going or
  nothing armed, stop only on the trunk, clean and moved; not for a manual run, a missing StartHead or an unknown
  HEAD), the store round trip of `armed`, `Auto` and `StartHead`, the hook script run for real against a store of
  its own (silent, exit 0, never writes over an unreadable store), and the page (100 green)
- [x] `dev-pages.tests.ps1` and `connector-dashboard.tests.ps1` green (310 and 198)
- [x] `check-plugin-integrity.ps1`: 0 errors

### DEPLOY: feat/3323-stopwatch-auto

The hub's Stopwatch can now time Claude's work without anybody pressing Start or Stop. Arm a label on the page,
and the clock starts at the next prompt you give Claude in a session of this checkout; it stops when Claude is back
on the trunk with a clean checkout and HEAD moved since the start (a sign the work landed, not a proof of it). A turn that only answers a question, or a branch parked
for your look, keeps the clock going. A run started by hand behaves as before, and auto-started runs carry an
`auto` tag.

A running hub must be restarted to pick up the new store fields: an old server would drop `armed`, `auto` and
`startHead` on its next write. A manual Start while a label is armed clears the arming.

**Score:** 2

#### What makes this deploy extra special

The hub is this repo's own dev server, so nothing a consumer takes changes.

**Score:** N/A

#### Pull Request

Stopwatch: armed runs start on the next prompt and stop when Claude is back on the trunk
