## fix/1931-exit-code-unknown-audit

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

- [x] Verify issue #1931's own premise before building anything: it claims "#1920 added
      `ExitCodeUnknown` to both arms of `Invoke-NativeCapture`, so the state is now reportable." A
      repo-wide grep (`grep -rn ExitCodeUnknown scripts/`, plus `grep -rn nknown scripts/`) found the
      field nowhere in the tree, and reading commit `b87a1c15` (#1920's actual fix) shows it narrowed
      `Test-GitCanCommit` to refuse only on git's own exit code 128 -- a caller-side fix, not a field on
      the shared lib. The premise was wrong; the ask (a consultable field, on the `ShortRead`
      precedent from #1679) was not. Built the field first, then did the audit the issue actually asks
      for.
- [x] Establish the failure mode is real and get its shape right before designing a fix, rather than
      trusting "reads as absent (`$null`)" from the issue text. Reproduced independently (300 fresh
      `powershell.exe` children, each running Start-Process -> read `.Handle` -> unbounded
      `WaitForExit()` -> read `.ExitCode` against a trivial `cmd.exe /c exit 0`): 1 of 300 came back
      with `.ExitCode` LITERALLY PowerShell `$null` -- not `0`, not a thrown exception, not `259`
      (`STILL_ACTIVE`). The same 300-iteration test against the `&` operator's `$LASTEXITCODE` (the
      other arm) came back real every time, and so did 300 iterations of `Start-Process -Wait -PassThru`
      (no explicit `.Handle` read) -- confirming #1931's own claim that the hazard is confined to the
      Start-Process arm's async `-PassThru` pattern, and ruling out `gate-lib.ps1`'s unrelated
      `Start-Process -Wait -PassThru` lint-gate launcher as a second site of the same bug.
- [x] Read #1679's `ShortRead` field and its docstring as the precedent to follow (same file, same
      shape of ambiguity: an empty/absent read that five callers had resolved toward an overconfident
      answer). Followed the same pattern: a boolean field on both arms' return object, a docstring
      contract paragraph, then a caller-by-caller audit rather than a blanket rewrite of every
      `.ExitCode` comparison.
- [x] Audit every `.ExitCode -eq 0` / `-ne 0` site outside `scripts/tests/` (256 matches across 36
      files -- see the family table under CREATE) and decide, per family, whether an absent code would
      produce a dangerous silent conclusion or a safe one. Declined a blanket sweep, per the issue's
      own instruction.

### CREATE

- [x] Added `ExitCodeUnknown` (boolean) to the return object of BOTH arms of `Invoke-NativeCapture`
      (`scripts/lib/native-capture-lib.ps1`): the `&` arm reports `$null -eq $LASTEXITCODE` (never
      measured to fire, kept for symmetry -- a caller reads one field whichever arm answered it, same
      promise `TimedOut`/`ShortRead` already make); the `-Utf8`/Start-Process arm reports
      `(-not $timedOut) -and ($null -eq $proc.ExitCode)`, checked BEFORE `$code` is used for anything
      else, the same discipline `TimedOut` needs. A timed-out call is never `ExitCodeUnknown` -- its
      code is a substituted verdict, not an unmeasured one, and the two must not collapse into the same
      field. Nothing is appended to `Output` for this (unlike the timeout lines): `ExitCodeUnknown` can
      fire on ANY `-Utf8` call, including `gh --json ...` ones a caller feeds straight into
      `ConvertFrom-Json`, so inserting a line would corrupt exactly the callers `ShortRead`'s own
      docstring warns against breaking. Full docstring contract added to `Invoke-NativeCapture`,
      matching `ShortRead`'s shape and citing the measurement.
- [x] **Family audit, all `.ExitCode` sites outside `scripts/tests/` (256 matches, 36 files):**

      | family | shape | direction on ExitCodeUnknown | example sites | verdict |
      |---|---|---|---|---|
      | fatal exit-on-failure guard | `if (...ExitCode -ne 0) { Write-Error; exit 1 }` | halts the script -- fail-closed | `cut-release.ps1` (git add/commit/tag/push), `push-preview.ps1`, `worktree-lane.ps1`, `park-branch.ps1`, `record-suite-durations.ps1` | safe by construction; not fixed |
      | advisory degrade-to-warning | `if (...ExitCode -ne 0) { Write-Warning '...will not block' }` | already documented as non-blocking | `open-pr.ps1`'s resolves gate (line 661) and remote-ahead fetch (1501-1502), `check-connectors.ps1`, `verify-pushed-merges.ps1` | already the safe direction; not fixed |
      | tri-state `Known`/`Measured`/`Fresh` reads | a dedicated field says "could not tell", never conflated with a definite 0 | `Get-TrunkGap` (`entry-scaffold-lib.ps1`), `Get-GitParkBacking`/`Get-BranchMachineLocalFindings` (`park-lib.ps1`), `Get-GitPorcelainStatus` (`git-porcelain-lib.ps1`), `Get-WorkingCopySnapshot` (`fanout-lib.ps1`), `Invoke-RecordedRemoteFetch` (`fetch-attempt-lib.ps1`) | ALREADY correct: an absent code routes to the same "unmeasured" branch a genuine read failure already uses | reviewed; not fixed -- this is the shape the fix below generalises |
      | "unmeasurable reads as NOT folded/NOT an ancestor" | the safe direction is already chosen by design | `entry-scaffold-lib.ps1`'s folded-entry check (line 7854, docstring: "the safe direction to fail in"), `prune-merged.ps1`/`tidy-machine.ps1`'s `-is-ancestor` checks (never over-deletes on ambiguity) | reinforces an existing, deliberate choice | reviewed; not fixed |
      | `Test-GitCanCommit` (git-identity-lib.ps1) | refuses ONLY on the literal git exit code 128 | any unknown/absent code already falls into "can commit" -- verified by the existing suite (`git-identity-gate.tests.ps1`, case "exit -1073741819") | fixed already, by #1920, for an overlapping reason | reviewed; not fixed |
      | **`Get-GitFileTextAtRef`'s one caller: ship-pr.ps1's step-list gate + DEPLOY lock** | `$null` (path absent OR unmeasurable) -> `if ($null -ne $shipCycleText) { <run both gates> }` | **DANGEROUS**: an unmeasurable read is silently read as "no document -- nothing to check", SKIPPING both the unresolved-step refusal and the DEPLOY-drift lock on a merge that otherwise proceeds | `native-capture-lib.ps1`'s `Get-GitFileTextAtRef`, called from `ship-pr.ps1:2150` | **fixed** -- see below |
      | **`Invoke-TestSuiteGate`'s own suite-judging loop** | `$code = $d.Process.ExitCode` read directly off a raw `Start-Process -PassThru` child (the exact race, not through `Invoke-NativeCapture`) | **DANGEROUS**: `$null -ne 0` is `$true` in PowerShell, so an unmeasured code on a PASSING suite was recorded `Failed = $true` and printed as `FAILED (exit )`, failing the whole gate on a suite that actually passed; the retry loop one level down had the same exposure plus a `Format-GateExitCode -ExitCode $null` crash waiting in the "re-ran ALONE and PASSED" message | pool loop (~line 1779) and crash-retry loop (~line 1902) in `native-capture-lib.ps1` | **fixed** -- see below |
      | `Get-TestCommands` entries (native-capture-lib.ps1, ~line 2028) | `$r = Invoke-NativeCapture ...` (no `-Utf8`, no `-TimeoutSeconds` -> the `&` arm) | same negligible-probability family as the `&` arm generally (0/300 in the reproduction) | this file's own `Get-TestCommands` judging block | reviewed; not fixed -- the `&` arm this site uses is not exposed to the Start-Process race |

- [x] **Fixed: `Get-GitFileTextAtRef`** (`scripts/lib/native-capture-lib.ps1`) now throws when
      `ExitCodeUnknown` is set, instead of returning `$null`. This function's contract already
      conflates "path absent" and "could not measure" into one `$null`, and its ONE caller
      (`ship-pr.ps1`'s step-list gate and DEPLOY lock, issue #884) reads that `$null` as "nothing to
      check" and skips both merge-time gates -- a worse failure than `ShortRead`'s five callers being
      too confident, because nothing tells the reviewer the check never ran. Throwing is the
      fail-closed direction, and it is affordable here specifically BECAUSE there is exactly one call
      site to widen (`ship-pr.ps1` runs under `$ErrorActionPreference = 'Stop'` with no
      surrounding try/catch, so an uncaught throw is a hard stop with a non-zero exit) -- unlike
      `Invoke-NativeCapture` itself, where #1920 already declined widening 239 callers' contract on
      size.
- [x] **Fixed: `Invoke-TestSuiteGate`'s pool-judging loop and its crash-retry loop**
      (`scripts/lib/native-capture-lib.ps1`) now detect `$null -eq $d.Process.ExitCode` /
      `$null -eq $rp.ExitCode` and route an unmeasured read through the SAME "no verdict yet, re-run
      alone" path issue #1723 already built for a genuine crash, rather than reading it as `FAILED`.
      `$suiteTimings`'s `Failed` field is guarded the same way (`(-not $codeUnknown) -and ($code -ne 0)`),
      since `$null -ne 0` is `$true` in PowerShell and would otherwise mark a passing suite failed in
      the per-suite table even before the crash branch could correct it. The retry loop's own second
      read gets the identical treatment PLUS a guard against calling `Format-GateExitCode` (a
      non-nullable `[int]` parameter) with a `$null` -- which would have thrown inside the gate rather
      than reporting anything. A second unmeasurable read (the retry itself races) is treated as a
      second crash and fails the gate, on the same "ONCE" doctrine #1723 already states for a genuine
      re-crash -- fail-closed for a merge gate, consistent with the `Get-GitFileTextAtRef` fix above.
      This is plausibly the unexplained mechanism behind this repo's own recent flaky-test-gate reports
      (#1913, #1915, #1920 all fired on `new-branch.tests.ps1` under 16-lane load in the same two-day
      window and none identified a root cause) -- NOT confirmed, since the race is probabilistic and
      none of those reports captured the raw exit code, but named here as a plausible unifying
      explanation rather than asserted as proven.
- [x] Deliberately NOT built: a retry/re-read loop inside `Invoke-NativeCapture` itself to reduce the
      odds of hitting the race. #1931 already measured that a 200ms re-read budget (20 reads with
      `.Refresh()`) still leaves 7 of 240 unresolved -- so a retry here would spend wall-clock on every
      capture for a recovery that is not reliable, and the honest-field approach (this branch) costs
      nothing on the far more common measured case.
- [x] Synced both shared-script mirrors via `scripts/sync/build-shared-scripts.ps1` (no manual copy):
      `plugins/dkj-policy/scripts/lib/native-capture-lib.ps1` and
      `plugins/dkj-subagents/dkj-subagents-shopify/scripts/lib/native-capture-lib.ps1`.

### TEST

- [x] `scripts/tests/native-capture.tests.ps1`: added three new assert blocks --
      (1) `ExitCodeUnknown` is present and `$false` on both arms for an ordinary clean child, and
      `$false` (not double-reported) on a genuinely timed-out call; (2) `Get-GitFileTextAtRef` throws,
      names issue #1931 and says what could not be measured, when `Invoke-NativeCapture` is shadowed
      (the idiom `remote-ahead-lib.tests.ps1` already uses) to return `ExitCodeUnknown = $true` for the
      `git show` call, and that the ordinary (unstubbed) read is unaffected once the shadow is removed.
      129/129 asserts pass (was 111 before this branch).
- [x] `scripts/tests/test-suite-gate.tests.ps1` (150/150) and `scripts/tests/git-identity-gate.tests.ps1`
      (48/48) re-run in full as regression: the pool-loop and crash-retry-loop edits reorder an
      `if`/`elseif` chain inside `Invoke-TestSuiteGate`, and both suites' existing crash/pass/fail
      classification cases (issue #1723's own fixtures) still pass unchanged.
- [x] `scripts/lint/check-plugin-integrity.ps1`: 0 errors (86 shared scripts checked, including the
      two mirrors this branch touches).
- [~] No deterministic unit test for the `Invoke-TestSuiteGate` pool-loop fix's actual OS-level
      trigger (a genuinely `$null` `.ExitCode` on a real child inside the gate's own reap loop): unlike
      issue #1723's crash class, where a fixture suite CAN choose its own exit code (`exit -1073741819`),
      a fixture cannot choose to make .NET's `Process.ExitCode` getter race and return `$null` -- that
      is an OS/.NET-internal timing hazard, reproduced only by brute-force repetition outside the gate
      (see PLAN). Verified instead by (a) the independent 300-iteration reproduction confirming the
      phenomenon and its confinement, and (b) full regression of both existing gate suites confirming
      every already-tested classification path (pass/fail/crash/crash-again) is unchanged.

### DEPLOY: fix/1931-exit-code-unknown-audit

`Invoke-NativeCapture` (`scripts/lib/native-capture-lib.ps1`) could return an `ExitCode` of `$null` --
not from a crash, not a `0`, and no exception -- when its own documented "proven pattern"
(`Start-Process -PassThru`, read `.Handle`, `WaitForExit()`, read `.ExitCode`) still lost a race in the
first `Start-Process` call of a fresh process (issue #1931: 27 in 960 captures, 2.8%, under 16 lanes;
reproduced independently here at 1 in 300). Both comparisons a caller could write, `-eq 0` and `-ne 0`,
read a `$null` as failure, so an unmeasured code was indistinguishable from a measured one everywhere it
was read.

This adds `ExitCodeUnknown` to both arms of `Invoke-NativeCapture`, on the `ShortRead` precedent (#1679):
a boolean a caller can consult, rather than a change to what `ExitCode` itself returns. #1931's own
premise -- that #1920 had already added this field -- did not match the tree (verified by grep and by
reading #1920's actual commit, which narrowed one caller's refusal to a specific git exit code instead);
this branch builds the field #1931 actually needed.

An audit of the ~256 `.ExitCode` comparison sites outside `scripts/tests/` found most of this codebase
already defends against exactly this ambiguity, via a `Known`/`Measured`/`Fresh` tri-state pattern this
lib's own `Get-TrunkGap`, `park-lib.ps1` and `git-porcelain-lib.ps1` already use, or via a fail-closed
`Write-Error; exit 1` that halts rather than draws a wrong conclusion. Two sites did not, and both are in
this same file:

- **`Get-GitFileTextAtRef`**, whose one caller (`ship-pr.ps1`'s step-list gate and DEPLOY lock, #884)
  read an unmeasurable exit code as "the document is absent -- nothing to check" and silently skipped
  both merge-time content gates. It now throws instead, which is a hard stop under that script's
  `$ErrorActionPreference = 'Stop'` rather than a silent pass.
- **`Invoke-TestSuiteGate`'s own suite-judging loop**, which reads a raw `Start-Process` child's
  `.ExitCode` directly (not through `Invoke-NativeCapture`) and is exposed to the identical race: a
  passing suite whose exit code raced to `$null` was recorded and printed as `FAILED`, which would fail
  the whole gate -- and by extension block every push and merge in this repo -- on a suite that actually
  passed. It now routes an unmeasured read through the same "no verdict yet, re-run alone" path issue
  #1723 already built for a genuine process crash, and treats a second unmeasurable read (on the retry)
  as a second crash, fail-closed.

Every other family was reviewed and left as is, with the reasoning recorded in the CREATE section's
table above -- this was an audit with a documented decision per family, not a blanket sweep.

**Score:** 3

#### What makes this deploy extra special

A repo running this workflow's shared scripts (native-capture-lib.ps1 is mirrored to every consumer)
gets a more reliable test gate and a merge-time content gate that no longer has a silent skip path on
an unmeasurable git read. No action is required to receive it -- it lands with the next plugin update
-- and nothing about how a subscriber writes their own branch document or runs their own gate changes.

**Score:** 2

#### Pull Request

Audit ExitCode comparison sites for absent-code false verdicts

