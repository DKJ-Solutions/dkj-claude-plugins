## docs/2409-tycho-owns-suite-population

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

Dave, September 24, 2026: the test gate is at 141 suites and nobody owns the population. Tycho gets
that ownership and Nolan supplies the cost. The first audit is tracked separately in #2408.

### CREATE

- [x] Tycho's portable manual: a "What Tycho covers" bullet on owning the suite population, plus a hard rule that a regression test goes into its subject's suite rather than a new one
- [x] Nolan's portable manual: extend the division of roles with the test engineer to cover the population, with Nolan supplying the per-suite cost table

### TEST

- [x] Edith copy edit on the diff (four findings, all applied)

### DEPLOY: docs/2409-tycho-owns-suite-population

The test engineer's manual now makes Tycho the owner of the test-suite **population**. Before this,
every rule in it pointed one way: add a test, add a regression test, flag a gap. Nothing covered
justifying, merging or retiring a suite, and this repo's gate grew from 43 to 141 suites in about six
weeks with nobody able to say why each one is needed. He now has to be able to name what every suite
protects. He proposes merges where suites overlap and retirements where a subject has gone, and each
retirement is stated as a trade of coverage for time. A new hard rule stops the one-suite-per-issue
shape: a regression case goes into the suite that already owns its subject. The performance
engineer's manual adds the matching line: the verdict is Tycho's, and Nolan supplies the per-suite
cost table it is made against. Closes #2409; the first audit of the 141 is #2408.

**Score:** 3

#### What makes this deploy extra special

Any consumer whose test gate is growing now has a named specialist who answers for its size. Asked why
the gate needs every suite it runs, the test engineer gives a per-suite answer and proposes merges or
retirements. Before, he added suites and never questioned them.

**Score:** 2

#### Pull Request

Tycho owns the test-suite population, and Nolan prices it

