---
id: 18
group: 04
---

# Tycho 🧪 · claude-code-specialists addendum

> Repo-lens (claude-code-specialists) accompanying the portable playbook in the `dkj-subagents-alpha` plugin (`plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-04-18-manual.md`). This file does not describe the craft, but what Tycho does in this repo.

A test engineer (SDET) does the same thing everywhere — write and maintain automated tests, guard
against regressions, secure reliability with a suite instead of manual checking. **What is
repo-specific in claude-code-specialists is not that Tycho tests, but what there is to test here.**

### What there is to test here

The testable surface of this repo is the **PowerShell scripts** in `scripts/**` — in particular the
lint gate `check-plugin-integrity.ps1` and the drift check `check-consumer-drift.ps1`, which make
decisions (valid/invalid, MISSING/IDENTICAL/DRIFTED) that can break silently, and the pure release
logic in `release-lib.ps1` (version bump, CHANGELOG transformation, release-notes assembly).

### Honest status & Tycho's role

- **The suite has grown well past its first member.** It started with
  [`scripts/tests/release-lib.tests.ps1`](../../../scripts/tests/release-lib.tests.ps1) —
  dependency-free (no Pester), dot-sources `release-lib.ps1` and asserts the version bump + CHANGELOG
  transformation, exit 1 on the first failure (usable in a CI gate) — and that dependency-free,
  exit-1-on-first-failure style now runs across the suite under `scripts/tests/`, which covers most
  of what Sylvester's lens lists: the lint gate (`check-plugin-integrity-*.tests.ps1`, four of them —
  see [the split below](#the-lint-gate-suite-is-four-files-august-16-2026)), the shared
  agent-def blocks (`subagent-shared.tests.ps1`), the branch/changelog/release chain
  (`branch-info.tests.ps1`, `new-branch.tests.ps1`, `fold-changelog.tests.ps1`,
  `cut-release-guardrail.tests.ps1`, `park-branch.tests.ps1`), the connectors + roster machinery
  (`connectors.tests.ps1`, `roster-sync.tests.ps1`, `sync-roster.tests.ps1`), the shared-scripts
  mirror + contract (`shared-scripts.tests.ps1`, `script-contract.tests.ps1`), the bootstrap drift
  check (`bootstrap-drift.tests.ps1`), the repo-config helper (`repo-config.tests.ps1`), and the test
  gate itself (`test-suite-gate.tests.ps1` — the runner all three callers share, which had only
  wiring-level coverage until it became a parallel scheduler on August 7, 2026). Tycho
  does not need to re-derive that list from memory: `Get-ChildItem scripts/tests/*.tests.ps1` gives
  the current count and membership directly, which is deliberately how this file avoids hardcoding a
  number that would drift with every new suite.
- **One committed member is deliberately not a test: `scripts/tests/fresh-consumer.measure.ps1`.** The
  `.measure.ps1` suffix keeps it out of CI's `scripts/tests/*.tests.ps1` glob on purpose — it reports
  numbers for a human to read and asserts nothing. It builds a synthetic consumer in the state a real
  one is in right after enabling the plugin (its own `CLAUDE.md`, no lenses, no repo-config, no
  orchestrator import) and runs the three `SessionStart` hooks against it the way the harness does,
  optionally after `specialists-init`'s bootstrap. It is committed rather than run ad hoc for one
  reason: **the point is that round two is comparable to round one**, and a measurement done by hand
  cannot be repeated identically, so its before/after could not be trusted. First run, July 29, 2026:
  **44 `[ERROR]` lines before the bootstrap and 21 after a successful one, with zero lines naming
  `specialists-init` in either state.** Turning the install/uninstall round-trip into a genuinely
  asserting suite is the follow-up this harness exists to make possible — a measurement first, so the
  assertions encode observed behaviour instead of assumed behaviour.
- Tycho's role here is now mostly **keeping the suite honest as the scripts evolve**: add a test the
  moment a script grows a new decision path or a fixture (a valid and a deliberately broken plugin
  directory) the lint gate must still catch, and close any genuine gap Victor flags during review —
  not starting the suite from scratch.
- He works together with [Sylvester #15](specialist-05-15-lens.md) (who owns the scripts) and
  [Victor #19](specialist-06-19-lens.md) (who flags a missing test during review).

### The lint-gate suite is four files (August 16, 2026)

`check-plugin-integrity.tests.ps1` is now four suites plus a shared, non-asserting
[`check-plugin-integrity-fixture.ps1`](../../../scripts/tests/check-plugin-integrity-fixture.ps1):
`-links` (checks 4 and 10), `-commands` (11 and 12), `-entries` (13, 13b, coverage, the staleness
checks) and `-docs` (18-27 and `-SkipCheck`).

**Why, measured** ([#714](https://github.com/DaveKJohn/claude-code-specialists/issues/714)): the gate's
whole wall clock **was** this one suite, to a tenth of a second, in four runs out of four. Every other
suite finished at 126.9s, after which one process ran on alone for another 70-86 seconds with 15 of 16
lanes idle. The gate parallelises **per file**, so the only way to hand that work the idle lanes was to
make it more than one file. The four together run in **~51s**.

**Three rules for working on them, each of which cost something to learn:**

- **The asserts must still sum to 234** — 48 + 42 + 69 + 75 at the split. That number is what makes
  "nothing was dropped" checkable rather than claimed, and the split was verified on it before the old
  file was deleted. If you move a scenario between the four, the total is the invariant, not the four.
- **Each suite builds its own fixture, in its own `$PID`-keyed directory.** They run concurrently under
  the gate, so a shared path would have them tearing down each other's tree mid-assert — the exact
  failure `test-suite-gate.tests.ps1` pins the convention against.
- **Scenario state that two suites share belongs in the fixture lib, not in a second copy.** Exactly one
  piece qualified (`$s24Contributing`, the quiet root document the coverage block needs), and it was
  found by parsing each generated file for variables it reads but never assigns — worth re-running as a
  one-off if you ever move scenarios again, because a split turns shared state into a silent `$null`
  rather than an error.

**What is NOT the lever here, so nobody re-derives it:** narrowing what the suites check. That was
explicitly refused in #714 and is not what bought the time; the same 110 gate invocations still run.

### A suite captures a child script through redirect files, never `2>&1` (September 6, 2026)

Every suite here drives a script as a **child process** and then asserts on its text. That text is
captured with `Invoke-NativeCapture -Utf8` (or `shared-scripts.tests.ps1`'s own
`Invoke-CapturedScript`) â€” both start the child with `Start-Process` and redirected streams.
**`& powershell ... 2>&1 | Out-String` is the wrong capture and it fails in a way that reads as a
defect in the script under test.**

**What goes wrong.** Under `2>&1` the parent re-renders the child's **first** stderr line as its own
`NativeCommandError` and stamps the record decoration â€” `At <path>:<line>`, the `+ ` source echo,
`CategoryInfo`, `FullyQualifiedErrorId` â€” *into* that line at the cut. The sentence is then not
reformatted but **interrupted**, and no comparison can rejoin it. This is the half that whitespace
stripping cannot repair, and the distinction is the whole rule: a **wrap** only ever *removes*
separation, so stripping separation always repairs it; **insertion** adds text, and nothing at the
comparison undoes that.

**Where the cut lands is not a property of the code.** The parent renders
`<powershell.exe> : <full script path> : <message>` and cuts the whole of it at the console width â€” so
the verdict is decided by the **checkout's path length** and the **terminal width** together.

**Measured twice, and the second time is why this is written here and not only in a code comment:**

- **August 14, 2026** â€” `shared-scripts.tests.ps1` scenario C1's assert on `#332` failed at width 152
  with the source at a 95-character path, and passed on the **same machine, same commit** in an
  80-column shell. That produced `Invoke-CapturedScript`.
- **September 6, 2026** ([#1530](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1530))
  â€” `verify-pushed-merges.tests.ps1` reported `FAILS: 1 failed, 47 passed` on a tree **byte-identical
  to `origin/main`** while CI on `main` was green. Reproduced here by checkout path alone: green at this
  repo's 108-character script path, red at a 45-character one, on the same commit and the same machine.
  At width 120 the failing window is a script path of **29 to 51 characters** â€” outside it every assert
  passes.

**So a green run is not evidence that the capture works**, on a developer's machine or on CI. Two
consequences:

- **Pin the capture, not the phrase.** `NativeCommandError` can appear in captured text *only* if a
  parent rendered the child's stderr as an error record; a redirect file receives what the child wrote
  and nothing else. Asserting its **absence** holds at every width and every path length, where an
  assert that merely looks for its own phrase fails only where the cut happens to land inside it. Both
  suites repaired for #1530 carry that assert on the scenario whose child writes to stderr.
- **Do not copy a capture from a neighbouring suite without reading this.** #1530 happened because
  `verify-pushed-merges.tests.ps1` was written *after* the August 14 repair and still copied the old
  capture from its sibling â€” the lesson existed only inside the one file that had been fixed. Both
  siblings now call the shared lib, and `verify-resolved-issues.tests.ps1` was changed **without a
  failing assert to point at**, deliberately: "it passes here today" is a fact about one checkout, and
  leaving the old capture in the file others copy from is what makes the next instance.

### Which suites need `Test-Says` -- read the capture, then the emitter (September 9, 2026)

The section above says how to CAPTURE. This one says when the captured text has to be READ
whitespace-insensitively, because the two questions were being answered as one and the answer was
coming out far too large.

**The mechanism** ([#1512](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1512)): a
`throw`, a `Write-Error` or a `Write-Warning` reaches a capture through PowerShell's error formatter,
which hard-wraps at the host's buffer column **inside a word** -- so the phrase the script composed is
not the phrase the capture carries. `Write-Host` does not go through that formatter and is unaffected.
`Test-Says` strips all whitespace from both sides and compares literally, which repairs a wrap inside a
word; normalizing `\s+` to one space does not.

**Two conditions, and BOTH must hold before a suite needs the helper:**

1. **the capture can carry the error stream** -- `2>&1`, a `StandardError.ReadToEnd()` concatenated
   onto stdout, or `Invoke-NativeCapture` without `-DiscardStderr` (it merges err into `Output`); and
2. **the script under test emits the asserted phrase through the formatter** -- a `throw`,
   `Write-Error` or `Write-Warning`, rather than `Write-Host`.

**Measured against the eight suites
[#1728](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1728) named, whose 358 assert
sites it called the exposure:**

| suites | sites | condition 1 | genuinely exposed |
|---|---:|---|---:|
| `roster-sync`, `connectors`, `script-contract`, `sync-roster`, `adopt-workflow-folder`, `config-blueprint` | 311 | **no** -- stdout only | **0** |
| `cut-release-drive` | 4 | yes | 0 today, structurally reachable |
| `publish-to-business` | 13 | yes (`2>&1`) | **3** |

The six are immune **by construction rather than by luck**: each captures stdout only (checked against
`2>&1`, `StandardError` and `Invoke-NativeCapture` alike) from a script with zero `throw`,
`Write-Error` and `Write-Warning`. Converting them would have been 311 edits with no defect behind any
of them -- and #1728 said so itself, in the sentence that is easiest to read past: *"That is the
exposure, not the defect count."*

**Condition 2 has a trap worth naming**, because it is what shrinks `publish-to-business` from 13 to 3:
a script may deliberately `Write-Host` the readable part and `throw` only a summary. That one does,
with the reason in its own code -- *"PowerShell renders a multi-line error message on one line, and the
whole point of this check is that you can read the list."* So the phrase an assert reads can be
formatter-free even where the failure that produced it was a `throw`.

**NO TREE-WIDE GATE, and this is the measurement that decided it.** 37 of this repo's suites satisfy
condition 1. A gate demanding `Test-Says` of all of them would be born with 33 findings, nearly all of
them about `Write-Host` phrases that cannot wrap -- which is the false-positive rate this repo already
turned down once, in the stale-path check declined at 124 findings. Condition 2 is what separates them
and it cannot be read off a suite: it lives in the script under test, one process away.

**The reason this class recurred at all is a documentation defect, not a test defect.** Before this
section the mechanism was recorded seven times -- once in each suite that had already been repaired --
and nowhere a person writing an eighth suite would look. `grep Test-Says` finds the fix only if you
already suspect the problem.

#### Condition 2 is a property of the ASSERT, not of the script (#1736, September 9, 2026)

The section above establishes the two conditions. Applying them to the rest of the tree -- the eight
suites #1736 nominated on a script-level emission count, plus the thirteen it could not resolve --
moved the answer again, and in the same direction: **a script carrying twenty `Write-Error` calls says
nothing about a suite whose asserts all read its `Write-Host` report.** The `publish-to-business` trap
named above is not a special case; it is the normal one.

Of the eight nominated, **four read no formatter-emitted phrase at all**: `gate-lib` (which starts no
child process -- its `2>&1` is on the fixture's own `git` calls), `fanout-lib`,
`find-specialist-mentions` and `measure-always-on`. A fifth, `verify-pushed-merges`, already carried
the helper and no `Assert-Match` at all. **All thirteen unresolved suites resolve to zero** -- their
scripts emit one or two formatter lines each, almost always on a `repo-config.ps1` load failure that no
suite asserts.

**Routing a `Write-Host` assert through the whitespace-blind reader is a LOSS, not a neutral tidy-up.**
It asserts strictly less than `-match` does, and it destroys any assert that cares about line structure
-- `round-tally`'s `(?m)^\| v10 \| A2 extra \|` reads a generated markdown row and must keep `-match`.

#### The three flatteners are not equally safe, and the ranking is measured

A suite that captures a child also has to flatten the records before it matches. Three ways of doing
that were in the tree and their docstrings disagreed about which is safe. Measured by padding a
`Write-Error` until its break swept every column of a 120-wide render -- 120 wrap positions x 4
phrases, 480 checks per variant:

| what the suite does with the captured records | failed |
|---|---:|
| collapse the break to a space (`-replace "\r?\n", ' '`) | 68 / 480 |
| join the records with a newline, or leave them alone | 51-68 / 480 |
| join with nothing between them (`''`) | **0 / 480** |

The formatter breaks **inside a word**, so collapsing to a space cannot repair the break it exists for
-- `dirty working tre e`. Joining with `''` reconstructs it exactly.

**But that immunity is incidental, and this is the part to carry forward.** Joining with `''` survives
a break that landed *on* a space only because PowerShell keeps that space at the end of the line it
wrapped -- a property of the renderer that nothing here controls or tests. `Test-Says` needs neither
property. So converting a suite that already joins with `''` is a **hardening**; converting one that
does not is a **repair**.

**Exactly one suite in that queue was genuinely exposed:** `round-tally.tests.ps1`, which joins its
records with a newline (`-match` is single-line by default) and measured 51 of 480. It had already met
this in [#1242](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1242) and answered it by
rejoining the lines at **one** call site by hand, leaving two `Write-Warning` asserts beside it
untouched -- and that hand-rolled form only worked because the phrase it guarded was a single token. A
local fix to a class defect is how the class survives, which is the same lesson as the documentation
defect named above.

**Say which of the two you did.** A green suite before and after is the expected result of a hardening,
so a commit that claims a fix and shows no failing assert is unreadable a month later. State the
measurement, and say plainly that nothing was letting a phrase through when that is what you found.

**The top row is no longer in the tree** ([#1742](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1742),
September 9, 2026). Two copies of it were found and both are gone: `find-specialist-mentions.tests.ps1`
was a **hardening** — it asserts no formatter-emitted phrase, so all 480 checks were moot there and its
safety was an accident of what it happens to read — and `shared-scripts.tests.ps1`, which collapsed the
break inline at one call site rather than in a named helper, was a **repair**. That second one is the
lesson worth carrying, and it has three parts:

- **The issue's own inventory named one copy and there were two**, because a search for the *helper*
  (`Get-FlatOutput`) cannot see a substitution typed at a call site. Search for the substitution.
- **It was the exposed one**, and by both conditions at once: its three positive asserts read an
  `open-pr` **`Write-Warning`**, which is exactly the formatter path the 68-in-480 was measured on.
- **Its comment argued the case that had already been disproved** — *"wrapping only ever inserts a
  newline where a space was, so collapsing whitespace restores the sentence verbatim"* — written after a
  red CI run, which is what made it read as settled. A break inside a word is the counter-example, and
  the phrases it guarded are long enough to meet one.

And the negative assert beside them is the sharpest reason this class is worth removing rather than
ranking: **a mangled phrase makes a `-notmatch` pass**. That assert existed to prove `open-pr` stays
quiet on the ordinary path, and under the collapse variant it would have reported exactly that for a
warning which was printed and merely wrapped.

### No COM in a suite -- one `New-Object -ComObject` stalled the whole gate (September 20, 2026)

A suite on `fix/2184-policy-drift-rank2-lenses` needed an 8.3 short name in order to prove a path
derivation does not canonicalize its root. It asked `Scripting.FileSystemObject`, which is the obvious
route and passed in **6 seconds standalone**. Inside the parallel test gate it **hung**: the suite sat
at that one line for the full 1,800s lane bound, and the run came back
**48 of 118 suites FAILED in 5,422s** -- every one of them a timeout rather than an assert, with most
of them logged as `started +3,620.3s`, i.e. never reaching their own first line for an hour.

**The failure reads as everything except its cause**, which is why it is written down here. The report
names 48 suites, 47 of which are innocent and pass standalone in seconds; the one that is guilty is in
the middle of an alphabetical list, and its own captured output ends on a `[PASS]`. Nothing in
5,422 seconds of output says *COM*. The route to it was the kept output directory the gate names on
failure -- read the guilty suite's own file and see which assert it stopped **after**.

**The rule: a suite reaches the operating system through a child process, never through COM.** Every
suite here already drives scripts that way, so the shape was available; the COM call was reached for
because it was the tidier one-liner. The replacement is `cmd /c "for %I in ("<path>") do @echo %~sI"`,
which answers in **42 ms** and produces exactly the same divergence -- so this costs nothing but a
longer line.

**And a red gate this size is a question about the RUNNER before it is one about the diff.** Forty-eight
suites failing at once, none of them on an assert, is not forty-eight regressions: the shared thing is
the harness. Re-run two or three of the named suites standalone first. Where they pass in seconds, the
failure is contention or a stall, and the next place to look is which suite held its lane.

In short: the **how** (automated tests, regression guarding) is portable; the **what** (the
PowerShell scripts as the test surface, and building out a suite once the lint gate warrants it)
belongs to this repo.
