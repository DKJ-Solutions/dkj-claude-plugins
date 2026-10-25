## fix/3271-fixture-git-wrapper-dispatch

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

#3271 recurred in a second suite with a second verb, both through `fixture-git-lib.ps1:165`. The issue's
first inference (the path got into `$Arguments`) does not hold: the `[FIXTURE GIT FAILED]` line is built
from that same vector and named no `git.exe` either time. The path comes from Git for Windows' `cmd\`
launcher, and the refusal is git's dispatcher, which runs before any subcommand -- so nothing ran.

### CREATE

- [x] `fixture-git-lib.ps1`: `Test-FixtureGitLauncherFailure` -- the launcher refusal, matched only where the quoted "subcommand" is a path ending in `git`/`git.exe`, read through a wide `Out-String` so an ErrorRecord wrap cannot hide it
- [x] `Test-FixtureGitTransientFailure` treats it as transient for every verb; `Invoke-FixtureGitNative` names it on the retry line and dumps the argument vector element by element (`Format-FixtureGitArgumentVector`), the capture the issue asked for

### TEST

- [x] `fixture-git-lib.tests.ps1` 7b and 8: both measured occurrences, a forward-slash path, a real mistyped verb (not retried), a long-path ErrorRecord, the argv dump, and a faked launcher refusal on a commit retried once -- 43/43 green

### DEPLOY: fix/3271-fixture-git-wrapper-dispatch

A test-suite fixture git call that Git for Windows' launcher refuses with its own path as the subcommand
(`git: '...\cmd\git.exe' is not a git command`) is now retried once, for any verb, instead of turning a
suite red under the parallel gate. That refusal comes from git's dispatcher before any subcommand runs,
so repeating it is safe where repeating a failed commit otherwise is not. The retry line names the cause
and prints the argument vector element by element, so the next occurrence carries the evidence
[#3271](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3271) asked for. A genuinely mistyped
subcommand is still a failure.

**Score:** 2

#### What makes this deploy extra special

N/A -- `scripts/tests/` ships to no consumer; this changes only this repo's own gate runs.

**Score:** N/A

#### Pull Request

Retry a fixture git call once when Git's own launcher hands it its own path as the subcommand

