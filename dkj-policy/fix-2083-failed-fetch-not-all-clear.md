## fix/2083-failed-fetch-not-all-clear

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

Get-BranchCollisionNote returns '' -- its own word for 'no collision' -- when the bounded git fetch exits non-zero, so a network blip, an expired credential or a stale ref makes the workflow's earliest collision detector answer all-clear. Give the plain non-zero arm the same voice the spent-budget arm already has: still return '', but print from inside the function that the look did not happen.

#### The overlap with `fix/2081-exitcodeunknown-audit`, named because a reviewer will meet it

That branch is parked on origin under another account and edits the same eight lines: it inserts a
`Test-NativeExitMeasured` arm directly above `if ($fetch.ExitCode -ne 0)`, and its own comment there
says in so many words that the plain non-zero case is **not** repaired by it and is #2083's. So this
is not duplicate work -- the claim's parked-fix scan raised it as a locked door, and reading that
branch's tree is what settled it.

What it does mean is that whichever of the two lands second resolves a textual conflict in
`Get-BranchCollisionNote`, in both copies. The two arms are designed to sit next to each other: theirs
catches the unmeasurable code and returns `''` with its own line, this one catches the remainder. The
`$codeClause` here is the seam -- it omits the code rather than guessing at it, so it is correct on
`main` today, where an unmeasurable code still reaches this arm, and still correct once theirs takes
that case away.

### CREATE

- [x] `Get-BranchCollisionNote` prints from inside when the fetch it bought came back unsuccessful,
      and still returns `''` -- a collision report is a claim about another session's work, and a
      failed fetch is no evidence for one. `scripts/task/park-cycle.ps1`.
- [x] The timeout is named apart, and `Invoke-NativeCapture`'s own `[timeout]` lines are printed
      rather than restated here -- filtered on that prefix, so `-DiscardStderr`'s guarantee that git's
      plumbing stays off this stream is not quietly given back.
- [x] The function's header block updated, so the promise it already made -- "a skipped look is NOT
      the same answer as a look that found nothing, and both callers are told which they got" -- now
      describes what the function does rather than what it fails to do.
- [x] Mirrored byte-identically to `plugins/dkj-policy/scripts/task/park-cycle.ps1`; the drift lint
      holds the two copies equal.

### TEST

- [x] Case (v) in `scripts/tests/park-cycle.tests.ps1`: an open PR, a **real** peer commit on origin,
      and then the remote URL repointed at a path that is not a repository -- so the run buys the look
      and gets nothing back, with a genuine collision on the far side. It asserts the line is printed,
      that the exit code is named, that no collision is invented from it, that nothing was committed
      or pushed, and that the line survives `-Quiet`, which is what the Stop hook passes.
- [x] Proved to be a regression guard rather than a description: **4 of its asserts go red** against
      `origin/main`'s copy of the script and green against this one.
- [x] `scripts/tests/park-cycle.tests.ps1` -- 131 asserts, all passing.
- [~] The **timeout** arm is not covered by an assert. Reaching it needs a `git` that hangs, and the
      fixture's only shim is `gh`; the suite's existing budget cases buy their timing from a delayed
      `gh` shim, which cannot reach a call made after it. Flagged rather than faked: what is untested
      is the `ran out of time` wording and the `[timeout]` passthrough, not the `return ''` beneath
      them, which case (v) does cover.

### DEPLOY: fix/2083-failed-fetch-not-all-clear

`park-cycle.ps1`'s collision detector no longer reports a **failed** fetch as "nothing to report". The
reader `Get-BranchCollisionNote` is the earliest collision detector in this workflow -- it runs from
the `cycle-autopark` Stop hook, in the one place where no operator is watching -- and `''` is its own
word for *no collision*. A fetch that exited non-zero returned exactly that, so a network blip, a
credential that had just expired or a stale ref made it answer all-clear and the turn went on building
on top of somebody else's tip.

It still returns `''`, deliberately: a collision report is a claim about another session's work, and a
failed fetch is no evidence for one. What changes is that the function now says so, from inside, on
both call sites at once -- `the fetch of 'origin/<branch>' failed (git exit code 128), so this run did
NOT read who is on the far side. That is NOT an all-clear` -- which is the sentence the neighbouring
spent-budget path has printed since #1958. A **timeout** is named apart and carries
`Invoke-NativeCapture`'s own `[timeout]` diagnosis, which this site had been discarding.

**Not a sighting.** #2083 says outright that nobody has measured this firing, and `git fetch` of one
branch against a configured origin is reliable; it is priced as the latent hazard it is. The failure it
prevents is the one #1439 measured -- two sessions building the same branch end to end, discovered at
the push -- arriving through a fetch that could not answer rather than through a look nobody bought.

**Score:** 2

#### What makes this deploy extra special

A consumer running `dkj-policy`'s `cycle-autopark` Stop hook gets a line where it previously got
silence, and only in the state where the silence was wrong: a turn with something to push, on a branch
with an open PR or a refused push, whose fetch of that branch did not succeed. Nothing else changes --
no new refusal, no new network call, and a healthy fetch is byte-identical to before. They notice it
the first time their network, credential or remote ref is having a bad day, which is precisely the
turn on which the old answer was a confident wrong one.

**Score:** 2

#### Pull Request

park-cycle's collision detector says a FAILED fetch out loud instead of reporting it as 'nothing to report'

Plugins: dkj-policy

