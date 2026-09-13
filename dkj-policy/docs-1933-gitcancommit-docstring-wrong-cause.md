## docs/1933-gitcancommit-docstring-wrong-cause

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

#### What the issue asks, and what verifying it added

#1933 says the #1930 repair is correct and its stated *reason* is not: the docstring cites #1915 for
"a git child in a fixture really does transiently fail under that load", and #1915 measured no such
thing -- it is the capped-tip flake, whose mechanism turned out to be a fetch-attempt record
suppressing a retry, reproduced by writing a failed record by hand. Verified against both issues and
against `scripts/tests/new-branch.tests.ps1`, where that mechanism is written up.

Two things the issue does not name came out of reading the tree for it:

- The same wrong cause sits in **four** places, not two -- the constant comment and the docstring in
  `git-identity-lib.ps1`, the block comment in `git-identity-gate.tests.ps1`, and the pending
  `CHANGELOG.md` entry for #1930, which is unreleased and would publish it.
- `git-identity-gate.tests.ps1` pins every state *around* the absent exit code -- 0, 128, four
  non-zero codes, a timeout, a `$null` result -- and not the absent code itself, which is the one
  state the narrowing exists for.

### CREATE

- [x] Correct the constant comment and the docstring in `scripts/lib/git-identity-lib.ps1`
- [x] Correct the block comment in `scripts/tests/git-identity-gate.tests.ps1`
- [x] Correct the pending `CHANGELOG.md` entry for #1930, which carries the same cause unreleased
- [x] Rebuild the plugin mirror (`scripts/sync/build-shared-scripts.ps1`)

### TEST

- [x] Pin the absent exit code itself -- `$null` and `''`, both read as can-commit
- [x] `git-identity-gate.tests.ps1` green: 50 asserts, the two new ones among them

### DEPLOY: docs/1933-gitcancommit-docstring-wrong-cause

`Test-GitCanCommit` refuses only on git's own `128`, and the reasoning recorded beside that narrowing
named a cause nobody measured: a git child transiently failing under the parallel gate, cited to
#1915. #1915 is a different flake -- the capped-tip case, whose mechanism was a fetch-attempt record
suppressing a retry. What was measured on #1920's branch is the opposite of a failure: at 16 lanes
the git child **succeeded**, exited, and printed the correct author ident, while `$proc.ExitCode`
from `Start-Process -PassThru` came back absent in 27 of 960 captures.

That distinction is what the narrowing's safety rests on. A reader who believes it only screens out
*failed* children may reasonably conclude that a more precise probe, a retry or a `-Utf8` removal
makes it unnecessary -- and remove it. So the four passages carrying the old cause now state the
measured one, including the three repairs that were tried and do nothing (the position-1
confinement, `.Refresh()`, and re-reading the code twenty times over 200ms), and the comparison's
own shape is written down: `$null -ne 128` is what lets an unreadable capture through, so any
rewrite to "is it non-zero" silently restores the refusal #1930 removed.

`git-identity-gate.tests.ps1` now pins that state as well. It had asserts for every state around it
-- `0`, `128`, four non-zero codes, a timeout, a `$null` result -- and none for an absent exit code,
which is the one the narrowing was written for; both spellings it arrives as (`$null` and `''`) are
asserted to read as can-commit.

**Score:** 3

#### What makes this deploy extra special

The corrected reasoning ships with the plugin, so a consumer reading the lib their own `new-branch`
runs no longer receives an explanation that argues for removing a guard they depend on. Nothing they
do changes; the failure it prevents has not happened yet, which is the whole of its weight.

**Score:** 1

#### Pull Request

Correct the cause recorded beside Test-GitCanCommit's 128 narrowing

