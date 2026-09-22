## fix/2255-suite-bound-basis

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

#### What #2255 reports, and which half of its proposed repair survived verification

`$script:GateSuiteTimeoutSeconds`'s own comment sized 1800s off one reading -- `new-branch.tests.ps1`
at 290.2s, the maximum row in `scripts/tests/suite-durations.json` -- and concluded **"no suite can
reach it by being slow"**. Verified against the tree: the JSON's maximum really is 290.2, so the
comment was internally consistent, and #2232's closing measurement really does record
`check-plugin-integrity-docs.tests.ps1` at **415.5s** on 24 idle cores. The conclusion is falsified by
a run rather than by an argument: a 9-lane gate over this repo's 121 suites timed that file out at
1,800s, and it passed all 188 asserts standalone on the same checkout minutes later.

The issue proposes three things and only the first is buildable here:

1. **Correct the comment** -- done, plus the half the issue's own "why this matters" section asks for
   and its numbered list does not: the correction is also PRINTED, because the console verdict is
   where a session decides what to suspect and the lib comment is not.
2. **Refresh `suite-durations.json`** -- NOT done, and not deferred silently: **#2252 already owns it**
   and records that the refresh needs a post-merge CI run that does not exist yet. Doing it here would
   duplicate an open issue with a local reading the file's own note forbids.
3. **Derive the bound per suite** -- declined with the mechanism written into the comment, so the next
   reader does not re-litigate it. A CI-derived row would be tightest exactly where the machine is
   slowest, and 30 of 121 suites have no row at all and are charged the maximum, which inverts the
   generosity.

Whether 1800 is the right constant is #2255's own third question, deliberately left alone here.

### CREATE

- [x] Rewrite the `1800 SECONDS` comment block in `scripts/lib/native-capture-lib.ps1`: both readings
      that bracket the bound, the retraction of the false sentence with the run that falsified it, and
      the argument against deriving it per suite.
- [x] Add the discriminator to the red verdict in `Invoke-TestSuiteGate`: a slow suite CAN reach the
      bound, and the standalone re-run is what settles it.
- [x] Mirror the lib to its two plugin copies (`scripts/sync/build-shared-scripts.ps1`).

### TEST

- [x] `scripts/tests/test-suite-gate.tests.ps1` -- two asserts added on the new verdict lines, both
      halves separately, since a hedge that says "maybe not a wedge" and stops has moved the
      re-litigation rather than ended it. 243 pass, 0 fail.
- [x] `shared-scripts.tests.ps1` (972 asserts) and `native-capture.tests.ps1` (337 pass) -- the two
      plugin mirrors are back in sync with the source, and the lib's own behaviour is untouched by the
      two added lines.

### DEPLOY: fix/2255-suite-bound-basis

The per-suite timeout in `Invoke-TestSuiteGate` carried a comment claiming **"no suite can reach it by
being slow"**, sized off the slowest row in `suite-durations.json` (`new-branch.tests.ps1`, 290.2s on a
four-lane hosted runner). That sentence is what tells a reader a 1,800s timeout means a wedge -- the
reading that made #2233 diagnosable -- and it has been false since #2232 recorded
`check-plugin-integrity-docs.tests.ps1` at 415.5s. A 9-lane run of this repo's 121 suites then reached
the bound on that file, which passed all 188 of its asserts standalone on the same checkout minutes
later.

The comment now carries both readings that bracket the bound instead of the CI one alone, retracts the
false sentence against the run that falsified it, and records why the bound stays a fixed constant
rather than being derived from `suite-durations.json`: that file is measured on CI, a local reading does
not convert into a CI one and the sign is not even fixed, so a derived bound would be tightest exactly
where the machine is slowest.

The correction is also printed. A red verdict naming a timed-out suite now adds that a slow suite can
reach the bound, so the timeout is not by itself a wedge, and names the one measurement that separates
the two -- a standalone re-run of that suite. The comment is read by whoever maintains the lib; the
verdict line is read by whoever just lost half an hour, and that is where the false reading cost its
second full gate run.

**Score:** 3

#### What makes this deploy extra special

`native-capture-lib.ps1` is mirrored into `dkj-policy`, so every consumer running this workflow's test
gate gets the corrected verdict. It lands hardest where it is worth most: a slow machine is the one that
reaches an 1,800s bound on a green suite, and also the one least able to afford a second full gate run
spent hunting a wedge that was never there.

Nothing changes for a run that does not time out, and the constant itself is untouched.

**Score:** 2

#### Pull Request

The 1800s suite bound no longer claims a basis that a measured run has already exceeded
