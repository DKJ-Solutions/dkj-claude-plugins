## fix/2048-closeout-repair-strategy

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

Investigate WHY five close-out repairs each failed, per inbound #2048 -- the report asks for an
investigation rather than a fix, and names four questions it would have to answer.

#### What the verification found before any work started

Two of the report's premises had already moved, and both are verified against the tree rather than
assumed:

- **"#2043's second proposal was never tried."** It was, hours before the report arrived: the fillable
  template is `ea8f8720`/`1c834bbc`, merged as #2047.
- **The child-output ordering** it blamed the miss on was repaired the same day, #2046.

Both landed **after** the `v5.4.0` tag, so no consumer has either -- and the reporting consumer was on
5.3.0. Neither premise being current changes what the report asks for, because its real subject is the
repair strategy rather than any one repair.

### CREATE

- [x] Verify the six inbound checks against the tree -- symptom, reason, repair, size, subject, repo
- [x] Reconstruct the six recorded repairs (#849, Aug 27, #1402, #1408, #1884, #2043) from the tracker
- [x] Build `scripts/maintenance/measure-closeouts.ps1` -- the instrument the report asks for
- [x] Record a baseline in `scripts/maintenance/baselines/closeout-ceiling.json`
- [x] Write the finding into `scripts/lib/closeout-lib.ps1`'s header, where this history already lives
- [x] Mirror the lib to `plugins/dkj-policy/scripts/lib/` byte-identically
- [~] Change what the close-out print says -- deliberately not done: the measurement's own conclusion
      is that a seventh sharpening is the move that has never once worked, and Chris's body already
      forbids repairing step 6 by sharpening that passage again

### TEST

- [x] `scripts/tests/closeout-measure.tests.ps1` -- 16 asserts, synthetic fixture, no machine state
- [x] `closeout-lib.tests.ps1` 87 pass, `shared-scripts.tests.ps1` 858 asserts (the mirror)
- [x] Full lint gate + every suite via `open-pr.ps1`

### DEPLOY: fix/2048-closeout-repair-strategy

The close-out ceiling is now measured instead of argued about. `measure-closeouts.ps1` reads this
machine's recorded sessions and reports how the close-out actually behaved, separating the two
populations that matter -- every session's final message, and the close-outs that follow a
chain-ending script, which is the set the ceiling governs and the only set a verdict may be read off.

It answers the question inbound #2048 called open and real. Over 328 sessions, 263 of them real
close-outs: **84% exceed the three-line ceiling, 56% exceed even six, and the median is seven.** So the
rule has never been in force anywhere -- five complaints are five of two hundred and twenty-two -- and
every previous repair was advice against a baseline nobody had counted, evaluated by waiting for the
next complaint. That is a sample of one, which cannot tell a repair that worked from one that did not,
and it is the mechanism behind the pattern the report identified.

It also settles the report's leading hypothesis, that the trigger is volume of work: measured,
`r = 0.207` over n=263 -- real, about 4% of the variance, and not the cause, because the smallest
quarter of sessions already averages 5.8 lines against a ceiling of 3.

Nothing about what the close-out print says was changed, deliberately. The finding is about how
repairs are evaluated, and the instrument plus its recorded baseline is what lets the next change here
be shown to have done something.

**Score:** 4

#### What makes this deploy extra special

N/A -- this repo's audience tier is the developers maintaining it. The instrument reads session
transcripts on the machine it runs on and ships to no consumer in this change.

**Score:** N/A

#### Pull Request

The close-out repair strategy, investigated across five recurrences
