## feat/2387-claim-takeover

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

#2387: a `held` tag claim could only be dropped by the tag that wrote it, so an issue parked by one of
your own machines could not be finished on another -- even with its branch on origin. Measured on machine
`DAVE`, 2026-09-23: 9 of 11 open issues read `held`, 7 of them by the same gh account on two other
machines. The only route was deleting the marker by hand through `gh api`, which the sweep page forbids.

Shape, per the issue's proposal: a deliberate `-Tag -TakeOver` whose two preconditions check what the
`held` refusal otherwise assumes -- the holder is this same account, and exactly one branch is on origin.
A colleague's claim is refused outright rather than put behind an extra word.

### CREATE

- [x] `claim-issue-lib.ps1`: `Get-IssueBranchNames`, `Get-TakeOverVerdict`, `Format-HandoverComment`
- [x] `claim-issue.ps1`: `-TakeOver` (with `-Tag`); removes the holder's marker, then claims through the
  ordinary path (marker, assignee, race read-back), comments the handover and prints the checkout. One
  marker-deletion helper now serves `-Release` and `-TakeOver`. The `held` refusal names the way through.
- [x] Plugin mirrors updated; `claim-issue` and `sweep-issues` skill pages carry the exception

### TEST

- [x] `claim-issue.tests.ps1`: branch matching, all seven take-over verdicts, the handover comment (and that
  it carries no marker), and the script's ordering -- 458 passed, 0 failed with them
- [x] Live, on #2387 itself: released this tag, planted a `TESTBOX-2387/davekokbwj` marker, `-TakeOver
  -DryRun` named the branch, `-TakeOver` removed the marker, claimed, commented, and `-Verify` read `[OK]`

### DEPLOY: feat/2387-claim-takeover

`claim-issue.ps1 <n> -Tag -TakeOver` hands a `held` issue over to this machine, deliberately and visibly,
when the holder is this same gh account on another machine and exactly one branch for the issue is on
origin. It removes the old marker, claims under this tag through the ordinary path, leaves a comment naming
the old tag, the new tag and the branch, and prints the checkout, so the old machine's `-Verify` reads
`[NO]`. A colleague's claim, an issue with no branch on origin, and one with several are each refused.

**Score:** 3

#### What makes this deploy extra special

A sweep run across several of your own machines no longer strands an issue on a machine you cannot reach:
the work parked on origin can be picked up from any of them in one command, without deleting a marker by
hand.

**Score:** 3

#### Pull Request

claim-issue -Tag -TakeOver: hand a held issue over to this machine when its branch is on origin
