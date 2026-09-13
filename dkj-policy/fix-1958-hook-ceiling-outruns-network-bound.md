## fix/1958-hook-ceiling-outruns-network-bound

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

Bound park-cycle's network calls to a run-wide budget the Stop hook's 60s ceiling can contain; gh pr list was unbounded entirely.

#### What the tree said that the report did not

The symptom stands exactly as filed. The reason is one detail off, in the direction that makes it
worse: `gh pr list` carries no `-TimeoutSeconds` at all. `Invoke-NativeCapture`'s bound is opt-in per
call site and that site never opted in, so the issue's "has carried the same 120s bound since long
before" is wrong about the one call it names as the older half. The worst case was not 240s against
60 -- it was unbounded.

#### The second bullet, answered

No other hook can outrun its ceiling. `guard-working-copy.ps1` (30s) is local-only; the six
SessionStart hooks (120s) make no network call at all -- `check-connectors.ps1`'s two bounded `gh`
calls sit behind `-RemoteRunners`, which `connector-sessioncheck.ps1` never passes, and its only child
(`plugin-versions.ps1`, itself bounded at 30s) runs local git against the marketplace clone. Nothing
to file.

#### The third bullet, NOT answered

Whether the harness's kill is visible to the session was not measured: doing so means wedging a real
turn for 60 seconds on a modified working tree. The repair does not rest on the answer -- whatever the
harness prints, none of park-cycle's arms run and nothing it wrote is delivered.

### CREATE

- [x] `native-capture-lib.ps1`: `$NativeCaptureHookNetworkBudgetSeconds` (45) and its floor (5), plus
      the budget functions -- `New-`, `Test-...Set`, `Test-...HasRoom`, `Get-...SecondsLeft`, `Get-...Bound`.
- [x] `park-lib.ps1`: `Invoke-GitPark -PushTimeoutSeconds`; 0 keeps the shared bound, so park-branch
      and new-branch are byte-for-byte unaffected.
- [x] `park-cycle.ps1`: `-UnderHook` / `-BudgetSeconds`, one deadline, all three network calls bounded
      by what is left -- `gh pr list` included, which had no bound at all -- and a named skip for each.
- [x] `cycle-autopark.ps1`: passes `-UnderHook`. The number stays in the lib: dot-sourcing 190 KB per
      turn to carry one integer measured ~28 ms, in the hook #1641 removed a 102 ms interpreter from.
- [x] `05-15-manual.md`: the portable rule -- a hook's timeout is a ceiling and per-call bounds do not
      compose. Portable half only, per the source-is-the-default rule; no lens edit.

### TEST

- [x] `native-capture.tests.ps1`: no-budget, wide, narrow, spent, sliver and malformed budgets, and
      that a spent one never yields 0 -- which is the lib's own UNBOUNDED value.
- [x] `park-cycle.tests.ps1`: (t) a spent budget skips the PR check and pushes nothing; (u) a budget
      healthy at the PR check and spent by the look reports which it was, via a delayed `gh` shim.
- [x] `cycle-autopark.tests.ps1`: (k) the budget is pinned against `hooks.json`'s registered `timeout`
      with a 10s margin, and the stub proves `-UnderHook` still arrives.
- [x] All three suites green locally; the full gate runs from open-pr.

### DEPLOY: fix/1958-hook-ceiling-outruns-network-bound

A script a hook invokes now runs its network calls under a deadline the hook's own ceiling can
contain. The `cycle-autopark` Stop hook is registered at 60 seconds, and `park-cycle.ps1` made up to
three sequential network calls under it -- two bounded at the shared per-call 120 seconds and
`gh pr list` bounded at nothing at all, because that bound is opt-in per call site and this one had
never opted in. Past the ceiling the harness kills the process from outside, which is the one way this
script can end that its own `ALWAYS EXITS 0` contract cannot cover: no fail-safe arm runs, no refusal
is worded, and the collision report -- the thing it is uniquely positioned to say -- is lost on exactly
the turn it mattered.

The hook now declares `-UnderHook` and the run gets one budget: 45 seconds of the 60, the rest left for
killing the timed-out child and printing what it found. Each call is bounded by what is *left* of that
budget rather than by a fresh two minutes, so three calls cannot outrun what one could have spent; and
where nothing is left, the call is skipped and named, because "I did not look" and "I looked and found
nothing" are different answers -- reporting them alike would reinstate #1953's silence through a new
door. A run typed by hand passes no budget and behaves exactly as it did before.

Checked once, as the issue asked: no other hook has the problem. The six SessionStart hooks make no
network call at all, and the `PreToolUse` guard is local. What was NOT measured is whether the
harness's kill is visible to the session -- that needs a deliberately wedged turn, and the repair does
not depend on the answer.

**Score:** 3

#### What makes this deploy extra special

Every consumer of `dkj-policy` runs this Stop hook on every turn, and the failure it removes is silent
by construction: a killed hook reports nothing, so a consumer on a slow or stalled network was losing
the workflow's earliest two-sessions-on-one-branch signal with no sign that anything had happened.
They need do nothing -- it arrives with the plugin.

**Score:** 3

#### Pull Request

A hook's network calls run under a budget it can finish inside

