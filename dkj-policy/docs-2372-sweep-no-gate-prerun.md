## docs/2372-sweep-no-gate-prerun

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

#2372: `sweep-issues` step 4 said a `-GatesOnly` pre-run "costs nothing". The symptom stands -- measured in
this session too: every pre-run was followed by a full gate inside `ship-pr`. The REASON the report gives
does not: `open-pr` does record gate evidence (`Save-GateEvidence`, `scripts/lib/gate-lib.ps1`), but keyed
on `Get-GateFingerprint` -- HEAD plus every dirty file -- and stored in the worktree's own git directory. A
pre-run before the commit, or in a lane followed by a ship from the primary, never matches. So the repair
is the skill's advice, not a missing stamp. One nuance the report does not have: on step 5's stop path
(visible result, no PR) the pre-run is the only gate that ever runs, so it stays there.

### CREATE

- [x] Step 4 splits by where step 5 sends the branch: shipping runs no pre-run (with the evidence rule
  stated); stopping keeps `-GatesOnly`

### TEST

- [x] Gates run by `ship-pr` itself -- this branch follows its own advice

### DEPLOY: docs/2372-sweep-no-gate-prerun

`sweep-issues` step 4 told a session that a `-GatesOnly` run before the ship costs nothing. It doubles
the wait: `open-pr` credits a recorded pass only on the identical tree (HEAD plus every uncommitted file)
in the same worktree, and a sweep's pre-run is almost always before the commit or in another lane, so
`ship-pr` ran the same gate again (1,400s twice on one commit, as measured). Step 4 now says to run nothing
before a branch that ships, and keeps `-GatesOnly` for the branch that stops at a visible result, where
it is the only gate that runs.

**Score:** 2

#### What makes this deploy extra special

A session sweeping a consumer's backlog stops paying for every gate twice on the issues it ships.

**Score:** 2

#### Pull Request

sweep-issues: no -GatesOnly pre-run, since ship-pr gates first and a pre-run is rarely credited

