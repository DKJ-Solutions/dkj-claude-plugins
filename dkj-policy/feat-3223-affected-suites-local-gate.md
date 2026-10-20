## feat/3223-affected-suites-local-gate

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

#3223: open-pr's local test gate runs all 162 suites on every diff. The owner chose **partial by
default** (Maikel, October 20, 2026, recorded on the issue): run only the suites the diff can affect,
plus the ones that walk the live tree, leave the whole pool to the required CI check, and keep
`-AllSuites` as the switch back.

### CREATE

- [x] `Get-AffectedSuiteSelection` and its parts in `scripts/lib/gate-lib.ps1`: a reference graph read
  off each script's syntax tree, followed only through what a file RUNS, with a library's data
  reference counted only when it names a directory; live-tree walkers (and `# gate-selection: always`)
  run every time; a per-blob cache in the git directory, keyed by the extractor's own hash
- [x] `Get-GateChangedPaths`: the merge-base with `origin/<trunk>` against the working tree, untracked
  files included
- [x] `Invoke-WorkflowGates -SelectSuites`: falls back to every suite, saying why, when no required CI
  check is named, the changes cannot be read, a path is non-ASCII, or the selector itself changed; a
  selected run records no gate evidence
- [x] `Invoke-TestSuiteGate -SuiteNames` in `native-capture-lib.ps1` (not `-Suites`: case-blind names
  collide with the function's own `$suites`), refused with sharding or focus, and a name that matches no
  suite throws
- [x] `open-pr -AllSuites` (selection on the PR path only; `-GatesOnly` and the release cut gate the
  whole pool), forwarded by `ship-pr`; both skill pages document it
- [x] mirrors copied

#### Measured while building it

Counting every file name in a script's text selected all 162 suites for every change (the docstrings
name nearly every file). String tokens only: 121 of 162 for a CSS file, through `shared-scripts-lib.ps1`'s
registry. Followed through RUN references only: 26. With the enumerator functions and `$PSScriptRoot` walks counted, the
always-run set is 39 suites (1,722s of 5,927s suite work), and a narrow change selects 29-60% of the
pool's seconds (`house-style.css` 29%, `claim-issue.ps1` 31%, `open-pr.ps1` 38%, `release-lib.ps1`
60%), in line with #2323's measured ceiling. Parsing ~480 scripts costs ~24s cold, ~2.5s warm.

### TEST

- [x] `scripts/tests/affected-suites.tests.ps1` (new, 67 asserts): reference reduction, run vs read,
  comments ignored, walks (direct, derived, git, fixture, marker), unparsed files, path matching, the
  selection over a real repo (transitive libs, a registry that lists a tool, a library's data path, a
  bare seam name, a changed suite, the three fallbacks), the cache (blob-keyed, warm equals cold, a dirty
  file read fresh), the changed-path reader, `-SelectSuites` (selected names handed over, no evidence
  recorded, no CI check means the whole pool), the callers' shape, and `-SuiteNames` run for real
- [x] lint gate: 0 errors
- [x] the related suites green through `-SuiteNames`: 13 of 163 (the new suite, gate-lib, test-suite-gate, native-capture, shared-scripts, script-contract, fixture-lib-deps, ci-shard, cut-release-guardrail, remote-ahead-lib, trusted-tree-seam, backing-gate, release-lib) passed in 230s
- [x] review: Victor (three bugs, all fixed: `$PSScriptRoot` walks, dotfile and extensionless references, a throwing selection now falls back) and Sebastian (no blockers; workflow and repo-config changes now run the whole pool)
- [~] the whole pool locally: this machine cannot finish it (hostname DAVE, #2267), and this change touches `gate-lib.ps1`, so its own selection falls back to every suite. The required CI check runs them all

### DEPLOY: feat/3223-affected-suites-local-gate

`open-pr`'s local test gate now runs only the suites a branch's changes can affect, plus every suite that
walks the live tree, and leaves the whole pool to the required CI check (#3223, the owner's decision of
October 20, 2026). A suite is selected when a changed path is the suite, a script it runs (followed
transitively), or a file one of those names, read off the scripts' syntax trees. Every suite runs, and
the line says why, when the repo names no required CI check, the changes cannot be read, a path is
non-ASCII, the selection throws, or the change touches the selector, the gate or the CI behind them. A selected run records no gate evidence, so it
never lets a later run skip the rest. `-AllSuites` on `open-pr` and `ship-pr` runs every suite. The
release cut and `-GatesOnly` still gate the whole pool. Measured here, a narrow change runs 27-60% of the
pool's suite-seconds: a CSS token change went from 162 suites to 43.

**Score:** 4

#### What makes this deploy extra special

In a repo whose required CI check runs every suite, `open-pr` and `ship-pr` gate a branch with only the
suites its changes reach, so a small change pushes in a fraction of the time. A repo that names no
required check (`Get-CiTestCheckName`) still runs every suite, and `-AllSuites` runs them all on request.

**Score:** 3

#### Pull Request

open-pr's local test gate runs only the suites a branch's changes can affect

