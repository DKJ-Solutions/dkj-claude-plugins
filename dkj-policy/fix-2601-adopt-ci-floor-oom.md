## fix/2601-adopt-ci-floor-oom

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

#2601 reported `adopt-ci-floor.tests.ps1` throwing `OutOfMemoryException` intermittently, on a 32 GB
machine. The report inferred that something allocates without bound. That inference did not hold up
when measured here (September 28, 2026, a 15.6 GB machine):

- **It did not reproduce.** Three standalone runs were all green (271 passed). Sampling showed every
  `adopt-ci-floor.ps1` child process peaked at about 120 MB (40 children sampled, highest 126 MB), so
  nothing grows without bound on this suite's inputs.
- **CI never showed it.** In the last 25 `ci.yml` run logs there is no `OutOfMemory` anywhere, and none
  of the last 60 runs failed.

What the tree does get wrong is the half that makes the verdict unreliable. `Invoke-Adopt` ran the child
as `$out = & powershell ...`, which never captured the child's **stderr**. So a child that died on an
exception left a shortened `$out` behind, and every negative assert (`-notlike`, `-notmatch`) passes on
shortened output. That is the reported `270 passed, 0 failed` with a `Get-WorkflowFacts : ...
OutOfMemoryException` printed above it. The other symptom, a run that ends with no summary line, is a
parent that died with a non-zero exit. The gate already treats that as a crash and re-runs the suite on
its own (#1723), so that half was never green.

#### How the repair works

Stderr is redirected to a file, and any byte in that file becomes a `[FAIL]` naming the child's first
error line. The exit code cannot tell a crash apart, because a terminating error exits 1, and exit 1 is
also this script's own live-defect verdict. Stderr can tell, because the script writes nothing there on
any path this suite drives: the full run below stays at 271 passed with the check in place. If the OOM
comes back on some machine, the suite now names it as a failure together with the error line, and that
error line is the evidence a cause would need.

### CREATE

- [x] `Invoke-Adopt` in `scripts/tests/adopt-ci-floor.tests.ps1` sends the child's stderr to a file,
  under a local `$ErrorActionPreference = 'Continue'`, and fails on any content in it.

### TEST

- [x] A full standalone run with the check in place: 271 passed, 0 failed. So no normal path writes to stderr.
- [x] Mutation proof, with the script restored afterwards: one child (`consumer-switch`) was made to throw
  after printing its report. The **old** suite read `271 passed, 0 failed`, exit 0, with the exception
  printed four times. The **new** one read `271 passed, 1 failed`, exit 1, with
  `[FAIL] the adopt-ci-floor child wrote to stderr, so it died mid-run (exit 1): ... injected #2601`.
- [x] The lint and test gate, run by `open-pr`.

### DEPLOY: fix/2601-adopt-ci-floor-oom

`adopt-ci-floor.tests.ps1` now fails when an `adopt-ci-floor.ps1` child dies on an exception. Before
this, such a run could still finish green, because the child's error went to stderr, which nothing read,
and the negative asserts passed on the output it left behind. The intermittent `OutOfMemoryException`
the report was about did not reproduce here or in CI (#2601).

**Score:** 1

#### What makes this deploy extra special

N/A. The test suite stays in this repo, and nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

adopt-ci-floor suite fails on a child that died on an exception, instead of passing on its truncated output

