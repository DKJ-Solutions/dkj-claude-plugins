## feat/2452-trusted-tree-exec-guard

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

Dave chose option 3 on #2452 (2026-09-24): no job split. Instead a guard refuses any
string-to-code execution primitive in the code the token-bearing "Ship it" step runs. The
analysis of why the split fails is on #2452 (comment 5818456726).

#### Where I left off (parked 2026-09-24)

- **Home:** a new section in `scripts/tests/trusted-tree-seam.tests.ps1`, reusing its
  `Get-DotSourceClosure` walk rather than a second walk.
- **Scope is WIDER than that suite's closure.** The token process also runs child scripts:
  `fold-changelog-entry.ps1` (ship-pr step 5, reads the branch document), `verify-resolved-issues.ps1`
  (step 6, reads the PR body), and `scripts/lint/check-always-on-budget.ps1` (open-pr:2124, runs even in
  trusted mode, reads the PR branch's CLAUDE.md). Discover them by following `-File (Join-Path
  $PSScriptRoot ...)` spawns, inline and via variable, to a fixpoint. Do not hand-list them. Keep the
  existing `$repoRoot` dot-source rule scoped to the dot-source closure only: children resolve their
  own root.
- **Detection is AST-based** (`Parser::ParseFile`), so comments and string literals never count. The
  probe is in the session scratchpad, not the tree; rebuild it from this list. It flags:
  `Invoke-Expression`/`iex`/`Invoke-Command`/`icm`; `Add-Type` ONLY with
  `-TypeDefinition`/`-MemberDefinition`/a positional source (`-AssemblyName` is fine);
  `[scriptblock]::Create`; `.NewScriptBlock`/`.InvokeScript`; `powershell`/`pwsh` with
  `-Command`/`-EncodedCommand`; a `'-Command'`/`'-EncodedCommand'` string constant.
- **`& $var` is deliberately NOT in scope.** Measured: dozens of legitimate scriptblock-seam calls
  (`gate-lib`, `entry-scaffold-lib`, `check-report-lib`). Say so in the suite header.
- **Measured hits over scripts/lib, release, lint today:** `plugin-tree-lib.ps1:128` and
  `check-plugin-integrity.ps1:601` (`Add-Type -AssemblyName`, which the refined rule drops), and
  `native-capture-lib.ps1:4667`, a real `powershell -Command` over `Get-TestCommands` strings (repo
  seam data). It sits in the test gate, which `-TrustedRoot` force-skips. The next step is to decide
  whether it is in the discovered closure. If it is, it needs a narrow, reasoned allowance (the seam
  comes from trusted-main, the gate is structurally skipped), plus a regression fixture proving
  that a planted `iex` is caught.

### CREATE

- [ ] Add the discovered token-process closure + AST primitive scan to trusted-tree-seam.tests.ps1
- [ ] Regression fixture: planted primitive in a child-spawned lib is flagged
- [ ] Header + merge-on-green.yml comment updated to name the guard (#2452)

### TEST

### DEPLOY: feat/2452-trusted-tree-exec-guard

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

A lint check refuses any execution primitive in the merge-on-green trusted-tree closure

