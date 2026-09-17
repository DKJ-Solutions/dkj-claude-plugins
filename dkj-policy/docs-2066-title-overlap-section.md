## docs/2066-title-overlap-section

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

`claim-issue`'s fifth pickup signal -- the title-overlap scan from #2018 -- is in the lib, in the
script and on a session's console, and the shipped skill page goes straight from the fourth signal to
`Every gh call is bounded`. The page is plugin payload, so a consumer meets that block with no
document saying what it measured, how strong the evidence is, or that it is advisory. The fourth
signal's section is the model; #2018's own measurement is the material.

- [x] Read #2018, the lib's fifth-signal section and the caller, so the write-up is against the code
      rather than against the issue's summary of it
- [x] Note the parallel branch: `origin/feat/2064-prerequisite-branch-signal` (held by another
      account) inserts its own section at the same anchor and renumbers the same list -- this branch
      stays inside the fifth signal and touches nothing of theirs

### CREATE

- [x] `## The fifth signal: a branch named for the SUBJECT, not the number`, placed between the fourth
      signal and `Every gh call is bounded`: #2018's measurement, why all four signals above miss the
      case, how the word matching works, the measured floor of two shared words, the hedges, and where
      the scan does not run
- [x] The page's numbered summary of what the script does gains the scan as its own item 5

### TEST

- [x] The console sample in the section is real output, captured by running
      `Get-TitleOverlapBranches` + `Format-TitleOverlapReport` over #2016's own title and the branch
      #2018 was measured against -- not an invented block
- [x] Every claim in the section checked against `scripts/task/claim-issue.ps1` and
      `scripts/lib/claim-issue-lib.ps1`: the shared fetch, the exclusions, the three skip paths and
      the fact that this signal never sets `$foreignParked` and so never moves the closing `[OK]`
- [x] Copy-edit pass on the diff (Edith), against the two source scripts rather than against the
      prose: two findings, both applied -- the cross-hit examples named two of the three the corpus
      actually produces (`update`+`plugins` between #1890 and #1988 was dropped), and one transitive
      use of *grows* reworded
- [x] Lint gate + all suites green (`check-plugin-integrity.ps1` and `scripts/tests/*`, via open-pr)

#### Filed, not fixed here

- [x] #2069 -- the fifth signal prints branch names with no `Format-ForConsole` strip, unlike the
      fourth signal reading the same capture. A script change with a test; this branch is `docs/`
- [x] #2070 -- the scan's lead line keeps the plural verb and pronoun in the singular case
      (`1 branch ... share words ... no commit on them`). The section quotes today's real output, so
      whoever lands #2070 updates that sample with it

### DEPLOY: docs/2066-title-overlap-section

`claim-issue`'s fifth pickup signal -- the title-overlap scan, which matches an issue's own title
against every branch name off the trunk to catch a branch cut for the subject rather than the number
-- now has its section on the skill page, between the fourth signal and the bounded-call section. It
carries #2018's own measurement (two complete independent implementations of #2016 inside half an
hour, every other pickup signal reading clean), how the word matching filters and why, the corpus
measurement behind the floor of two shared words, and the hedges that make it weaker evidence than the
fourth signal -- including that it deliberately never moves this script's closing line. The page's
numbered summary of what the script does names the scan as its own step.

**Score:** 2

#### What makes this deploy extra special

A consumer who installs `dkj-policy` reads this page and nothing else, and the scan has been printing
its block to their console with no document behind it: nothing saying what it measured, how strong a
shared word is as evidence, or that it is advisory like every other signal in the family. That is
exactly the hedging every neighbouring section is careful to state, and the reader most in need of it
is the one furthest from the code.

**Score:** 3

#### Pull Request

The title-overlap scan gets its own section on claim-issue's page
