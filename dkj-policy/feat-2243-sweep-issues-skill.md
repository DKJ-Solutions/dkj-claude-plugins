## feat/2243-sweep-issues-skill

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

#### What the prompt already had right, and the two places it did not

`PARALLEL-SWEEP-PROMPT.md` in `dkj-policy-bwj` is a working procedure -- it ran a fourteen-issue round
over six machines -- and the parts worth keeping are its ORDER (choose, claim, build, gates, stop at
the hand-over) and its insistence that the assignee is not the claim. What could not stay:

- **the claim was prose.** A session had to type two `gh` commands correctly and read the result of a
  third, on the step where getting it wrong means two machines building the same thing.
- **the race did not close.** "If you see a claim that is not yours, let go" releases the issue from
  BOTH sides of a tie. That is the one defect a pure function can be written to have never.

#### Where it goes, and why not in the BWJ plugin

Decided with Dave, September 21, 2026: the sweep belongs in `dkj-policy`, not in `dkj-policy-bwj` --
this repo sweeps its own backlog too, and nothing in the loop is a storefront's. What stays BWJ's is
the ticket-mirror close-out and the storefront hand-over, and the skill points at those rather than
restating them. The claim itself goes INTO `claim-issue.ps1` rather than beside it: a second claim
script would be a second answer to "who is working on this", and the two would drift.

### CREATE

- [x] `Get-ClaimTag`, `Get-ClaimMarkerPattern`, `Format-ClaimComment`, `Get-ClaimRecords`,
      `Get-TagClaimVerdict`, `Resolve-ClaimRace` and `Get-SweepCandidates` in `claim-issue-lib.ps1` --
      every decision pure, so the suite holds the whole judgement and the impure half stays `gh` calls.
- [x] `-Tag`, `-Verify`, `-Release` and `-Candidates` in `claim-issue.ps1`, with the default mode
      untouched: without `-Tag` the script behaves exactly as it did, refusals and all.
- [x] The tag verdict is MAPPED onto the assignee verdict's vocabulary rather than branching around
      the rest of the script, so the parked-fix, prerequisite and title-overlap scans (#1853, #2064,
      #2018) all run in tag mode unchanged.
- [x] `sweep-issues` skill in `dkj-policy`, `disable-model-invocation: true` -- a sweep starts because
      somebody asked for one.
- [x] The new parameters documented on the `claim-issue` page too, which the `skill-param` gate
      requires and which is right: a consumer holding the mirror and that page must be able to learn
      that the modes exist.
- [~] Rewriting `PARALLEL-SWEEP-PROMPT.md` -- dropped HERE, because the page is not this repo's: it
      lives in the consumer (`smartwatchbanden/dkj-policy-bwj/`) and this plugin has never carried it.
      Writing a copy here to edit was the first move of this branch and it was wrong for exactly the
      reason the workflow forbids a second copy of anything; it was removed. The consumer's own page
      points at the skill in its own repo, after this lands.

### TEST

- [x] 80 new assertions in `claim-issue.tests.ps1`, including the race asserted from BOTH sides of one
      record set -- the property the prompt did not have, and one no single-session test can see.
- [x] Three existing structural asserts re-pointed rather than dropped: the field list moved into a
      variable, and the assignee-timeout branch gained a `-not $Tag` guard.
- [x] End-to-end against the live tracker on #2243: `-Candidates`, `-Tag`, `-Tag -Verify`, the `held`
      refusal under a second machine name, and `-Tag -Release` (which deletes through GraphQL, since
      the id in hand is a node id).
- [x] The lint gate and the full suite pool.

### DEPLOY: feat/2243-sweep-issues-skill

A backlog worked by several machines at once had one procedure in this marketplace and it was a
**prompt block** in `dkj-policy-bwj` -- pasted by hand into a fresh session per machine, with its claim
written as prose for a session to type and its race resolution releasing the issue from both sides of a
tie. `sweep-issues` is that procedure as a skill in `dkj-policy`, and `claim-issue.ps1` gains the claim
it needs: **`-Tag`**, which claims with a marker comment carrying `machine/account` instead of with an
assignee. Both halves of that tag are load-bearing and both were measured -- two accounts sharing a
machine name and two machines sharing an account each produced an ambiguous claim
([#701](https://github.com/BWJ-Development/smartwatchbanden/issues/701)) -- and the assignee is still
written beside it as the tracker's visible signal rather than as the claim. `Resolve-ClaimRace` reads
the markers back and names the **winner** (earliest comment, ties broken on the node id, which is
arbitrary and identical for every reader) so exactly one session keeps the issue and the losers release
their own marker. `-Verify` answers in an exit code whether THIS tag still holds an issue, which is what
the resume step needs and the sharpest place a vague claim costs; `-Release` drops this tag's own
markers and nothing else; `-Candidates` reads the whole board in one call and judges it without writing
anything, because between choosing and claiming sits the question of whether the issue is this repo's
work at all ([#722](https://github.com/BWJ-Development/smartwatchbanden/issues/722)). The default
assignee mode is untouched throughout, and the tag verdict is mapped onto its vocabulary so the
parked-fix, prerequisite and title-overlap scans all still run.

**Score:** 4

#### What makes this deploy extra special

A consumer repo gets a way to put several machines on one backlog without the two failures that shape
costs: building the same issue twice, and a session resuming somebody else's branch because the claim
could not name a machine. Before this, the only shared claim was an assignee -- which two checkouts
under one GitHub account write identically, and which refuses an issue carrying the name of the
colleague who owns the ticket, measured at three of fourteen open issues on one board. The skill also
carries the stop that a parallel round most wants to skip: where the result has to be judged by eye it
parks the branch and takes the next issue rather than opening a pull request on work nobody has seen.

**Score:** 3

#### Pull Request

Sweep an issue backlog with several machines, claiming by tag

