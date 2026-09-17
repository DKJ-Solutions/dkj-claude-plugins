## fix/2061-lane-forwards-resolves

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

A lane must run the same already-done check a direct new-branch run does.

#### What the issue measured

`worktree-lane.ps1` delegates the whole branch-creation act to `new-branch.ps1` and says so as the
reason it restates none of new-branch's rules -- but its own `param()` block had no `-Resolves`, so
there was nothing to forward and passing one was refused outright. `-Resolves` is what runs #1409's
already-done check BEFORE the checkout, so a lane paid exactly the cost #1409 was filed to remove, and
paid it silently.

#### The distinction this branch turns on

`-SkipStaleBase` is passed and stays passed: it is a decline this script EARNED, because step 2 chose
the base from `origin/<trunk>` seconds earlier, so new-branch's stale-base check has nothing left to
discover. The already-done check asks the TRACKER a question no step of this script has asked or
answered, so no reasoning here made it redundant -- it was an omission, not a decision. Documented as
that pair everywhere it is now stated, so the next reader does not repair the wrong half.

### CREATE

- [x] `scripts/task/worktree-lane.ps1`: `-Resolves` added to the `Open` parameter set and forwarded at
      the delegation call site, with its own `.PARAMETER` block and an `.EXAMPLE`.
- [x] The call-site comment, which argued only the `-SkipStaleBase` decline, now argues both -- why one
      is waived and the other cannot be.
- [x] The step 4 docstring sentence the issue quoted ("Every rule new-branch enforces ... therefore
      holds in a lane") names the already-done check among those rules, which is what makes it true.
- [x] `plugins/dkj-policy/skills/worktree-lane/SKILL.md`: `-Resolves` in the parameter list with the
      instruction to pass it whenever a lane is opened for an issue, and the same pairing under step 4.
- [x] Mirror regenerated with `scripts/sync/build-shared-scripts.ps1`.

### TEST

- [x] New case (j) in `scripts/tests/worktree-lane.tests.ps1`: a lane opened with `-Resolves 2061`
      exits 0 and its output carries new-branch's own already-done sentence naming `#2061`. The
      observable is new-branch's "supplies no Get-RepoName" warning, so the case needs no `gh` and no
      mock -- and before this branch the same run died on `A parameter cannot be found that matches
      parameter name 'Resolves'`.
- [x] A structural assert beside it: exactly one delegation call site, and it forwards `-Resolves`.
      That is the half the behavioural assert would stop covering the day the fixture grows a
      `Get-RepoName`.
- [x] `worktree-lane.tests.ps1`: 39 passed, 0 failed.
- [ ] Full gate green (lint + all suites) via `open-pr.ps1`.

### DEPLOY: fix/2061-lane-forwards-resolves

`worktree-lane.ps1` now forwards `-Resolves` to `new-branch.ps1`, so a branch opened in a lane runs the
same already-done check a direct `new-branch` run does -- one `gh` call, before the checkout, asking
whether the issue is already closed or already resolved by a merged PR. The parameter did not exist on
the lane script at all, so passing one was refused outright and a lane simply ran without the check,
silently: nothing in the run said it had not happened.

That is exactly the cost #1409 was filed to remove -- a branch cut, its commits, its development
document, its reviews and its test runs, all spent before the warning finally arrives at `open-pr` --
and a lane is where it bites hardest, because a lane is opened during a busy window, which is precisely
when another session is likeliest to have just closed the issue being picked up.

`-SkipStaleBase` stays declined and is now argued beside it, at the call site and on the skill page,
because the two read as a pair and are not one: that check reads the BASE, which this script chose from
`origin/<trunk>` seconds earlier, so it has nothing left to discover; the already-done check reads the
TRACKER, which no step here has asked about. One is waived because the script already answered its
question, the other could never have been.

**Score:** 3

#### What makes this deploy extra special

A consumer who installs `dkj-policy` gets the lane script and the skill page, and the page is what
tells them a lane inherits every rule `new-branch` enforces. That sentence was not true of the check
that costs the most to skip, and nothing in a lane's output reported the gap -- so the reader furthest
from the code was the one most likely to believe it. The page now names `-Resolves` in the parameter
list and says plainly to pass it whenever a lane is opened for an issue.

**Score:** 3

#### Pull Request

worktree-lane forwards -Resolves to new-branch
