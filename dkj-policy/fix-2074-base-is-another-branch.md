## fix/2074-base-is-another-branch

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

#### What this branch answers

`new-branch.ps1` measures `HEAD..origin/<trunk>` and prints `Base is current with origin/main` when that
gap is zero. The measurement is right and the choice is argued by name on the skill page -- it answers
*"what is my base missing"*, so a deliberate stack gets the gap it actually carries. What the sentence
cannot do is tell its two cases apart: a branch cut from the trunk and a branch cut from another branch
that has just merged the trunk both read zero, and both were told the same reassuring line.

Measured September 17, 2026 (#2074): two sessions in one working copy, the other standing on
`fix/2056-already-done-three-state` with `origin/main` merged into it minutes earlier. The new branch
carried five of that branch's commits -- 22 files, 1257 insertions -- under a two-line repair, and every
downstream guard read the branch and found it fine: lint, all suites and CI green. A reviewer reading the
diff is what found it.

- [x] Read the base block and `Get-TrunkGap` against the issue's account rather than taking it: the gap
      is measured before the checkout, so `HEAD` is still the base when the question is asked
- [x] Confirm the neighbours this must not be confused with -- the stale-base refusal (#1046/#1417) fires
      on a base *behind* the trunk, the remote-ahead warning (#1439) is about the branch being *resumed*
- [x] Built in a lane, because the primary checkout was shipping #2073 at the time. Which is the hazard
      this branch is about, one turn later

### CREATE

- [x] `scripts/task/new-branch.ps1`: where `HEAD` is a branch other than the trunk and
      `origin/<trunk>..HEAD` is above zero, the run names that branch and that count, and says what those
      commits would do -- travel into this branch, its diff and its pull request. Placed *above* the gap
      chain so a refusing run still says what it was standing on
- [x] The dim currency line carries the base too when there is one: `Base is current with origin/main --
      but that base is 'fix/y', not main.` It is the line a reader scans for the base question, and left
      bare it answers *"is the base stale"* while reading as *"the base is the trunk"*
- [x] Repeated as the second-to-last line of the run, the same schedule the stale-base, already-done and
      remote-ahead notes are on, and for a sharper version of their reason: this is the one case where
      nothing else in the run looks wrong
- [x] Both branch names go through `Get-DisplayRef` -- the base is whatever `HEAD` pointed at, which on
      the measured run was another session's branch name
- [x] Script header and the `-SkipStaleBase` neighbourhood updated; plugin mirror rebuilt via
      `scripts/sync/build-shared-scripts.ps1`
- [x] `plugins/dkj-policy/skills/new-branch/SKILL.md`: a row in the base table, step 4 of the numbered
      summary, and a new `### And zero is two different facts (issue #2074)` section carrying the
      measurement, the silence rule, why it warns rather than refuses, and the two neighbours it is not

### TEST

- [x] `scripts/tests/new-branch.tests.ps1` gains two cases beside the existing (t):
      **(t2)** a base that is another branch's tip carrying two commits -- exit 0, branch created, the
      base named, the count named, the currency line carrying it, `behind origin/main` *absent* (this is
      not the stale-base check), and the warning counted at exactly **2** occurrences;
      **(t3)** a branch base carrying nothing -- silent on both lines, which is what keeps the check off
      the ordinary run
- [x] (t) gains one assert: a `HEAD` on the trunk claims no stack
- [x] `new-branch.tests.ps1`: 297 asserts, all passing
- [x] Lint gate green (`check-plugin-integrity.ps1`, 0 errors), full suite via open-pr

#### Not built, and why

- [~] No refusal, and no `-Skip...` valve for one. The issue asks for a warning and the reason holds:
      stacking on purpose is on the intended happy path and `worktree-lane.ps1` delegates here having
      chosen its base seconds earlier. A valve with nothing to open is noise
- [~] Nothing about two sessions sharing one working copy -- #1973's subject. This repair is worth having
      either way, because a stale `HEAD` from your own earlier checkout produces the same silence with one
      session

### DEPLOY: fix/2074-base-is-another-branch

`new-branch` no longer reports `Base is current with origin/main` and nothing else when the base is
another branch's tip. Where `HEAD` is a branch other than the trunk and carries commits `origin/<trunk>`
does not, the run names that branch and that count -- twice, once before the checkout and once near the
last line -- and the dim currency line names the branch as well, so the sentence that reads as *"the base
is the trunk"* cannot be read alone. It warns and never refuses: stacking on purpose is on the happy path
and the lane chooses its base seconds before delegating here. A detached `HEAD` is not a subject, which
keeps the lane itself silent, and `origin/<trunk>..HEAD` is zero for a base that really is the trunk and
for a branch not yet committed on, which keeps the ordinary run silent.

**Score:** 3

#### What makes this deploy extra special

This is the gap every other guard in the family reads straight past. The stale-base refusal fires on a
base *behind* the trunk and this base is behind nothing; the remote-ahead warning is about the branch you
are resuming; the claim step reads the tracker; the lint gate, the suites and CI all read the branch, and
the branch is valid. The measured run went green on all of them while carrying 22 files of somebody
else's unlanded work into a two-line repair's pull request, and was caught by a human reading a diff.
Since two sessions can now share one working copy without either typing a git command, the accidental
stack is reachable without anyone doing anything wrong.

**Score:** 3

#### Pull Request

new-branch names the base when it is another branch's tip, so a stack is not silent
