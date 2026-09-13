## fix/1915-capped-tip-flaky-in-gate

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

#### What #1915 reported, and what it turned out to be

`new-branch.tests.ps1` case (y6) went red inside the parallel test gate -- two of its three cap asserts,
with the negative one passing -- and was green standalone on the identical tree. The report inferred the
fixture helpers in front of the assert and said so openly: *"Not verified; that is where I would start."*

Reproduced here instead, by reasoning from the failure signature back to its only possible cause and then
staging that cause by hand. PASS/FAIL/FAIL on those three asserts means one thing and nothing else: the
divergence warning never fired at all, because `Get-RemoteAheadNote` returned `''`. Its count comes off
the in-process capture arm, which cannot short-read, so a zero there means the branch's
remote-tracking ref was never refreshed. A hand-written failed-fetch record between the two
`Invoke-NewBranch` calls reproduces all three verdicts exactly.

The amplifier is `-RecentFailureSeconds` (#1860): `new-branch` opts into it, so ONE transient `git fetch`
failure suppresses the retry for the next 90 seconds -- and the fixture's two runs sit seconds apart, as
does a real claim, cut and resume.

#### The cap was never the subject, and neither were the fixture helpers

`Add-OriginBranchCommits` and the `checkout -q main` between the runs are both correct. The 400-character
subject is capped to 120, leaving 91 `x`s against an assert asking for 80 -- a fixed margin that does not
move under load.

### CREATE

- [x] `new-branch.ps1`: a count taken against a ref this run did not refresh is SAID, not printed as
      silence -- gated on `.Measured`, so it cannot land where the question was never asked
- [x] Mirror synced (`scripts/sync/build-shared-scripts.ps1`)
- [x] `new-branch` SKILL.md: the new sentence, the 90-second window behind it, and why the trunk-level
      note does not cover it

### TEST

- [x] `new-branch.tests.ps1`: `Clear-FixtureFetchStamp`, run from `Invoke-NewBranch` before every run --
      the flake's own repair, and `-KeepFetchStamp` for the one case whose subject is that state
- [x] (y6) gains the premise assert, so this class of failure names itself instead of blaming the cap
- [x] (y7): a run whose fetch did not refresh says so; a run that fetched says nothing
- [x] Suite green -- 274 asserts

### DEPLOY: fix/1915-capped-tip-flaky-in-gate

`new-branch`'s branch-divergence warning (#1439) could report the shape of a clean branch on a run where
it was blind. `Get-RemoteAheadNote` returns an empty note both for *"origin has nothing you do not have"*
and for *"the ref I counted against is whatever the last fetch left"*, and `new-branch` printed the second
as the first. Since #1860 the window is not one run but ninety seconds: the script opts into the freshness
seam's `-RecentFailureSeconds`, so a single transient fetch failure suppresses the next retry -- which is
the interval a claim, a cut and a resume all live in. A run whose own fetch did not refresh the ref now
says so and hands over `git fetch origin <branch>`; the ordinary run, where the fetch succeeded, is
unchanged and silent. The trunk-level `Base: ...` line does not cover this, because it speaks about the
trunk and is printed on a skip only.

That same blindness is what made `new-branch.tests.ps1`'s capped-tip case flaky in the 16-lane test gate
(#1915): the case is two `new-branch` runs seconds apart on one fixture, so a fetch that failed in the
first silently disarmed the probe the second was asserting on. `Invoke-NewBranch` now clears the
fetch-attempt record before every run -- which removes no coverage, since the seam has its own suite, and
can mask no regression, since clearing only ever makes the run fetch. Case (y6) also gains the premise
assert it was missing, so a warning that never fires reports itself instead of reading as a broken cap.

**Score:** 3

#### What makes this deploy extra special

Every consumer of `dkj-policy` runs this `new-branch`. The guard whose whole job is to catch another
session's push to the branch you are resuming could go quiet for ninety seconds after one bad fetch, and
say nothing about having gone quiet -- the duplicate-work hazard #1439 exists to prevent, arriving through
the one route that reports nothing.

**Score:** 3

#### Pull Request

A stale remote-tracking ref no longer makes the branch-divergence warning read as silence

