## docs/2182-2185-lens-heading-and-ci-job

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

Two accuracy defects found by the parallel review pass on `docs/2179-folder-docs-into-lenses`, both
shipped on `main` by the #2179 migration, both invisible to every gate.

- **#2182** -- `specialist-05-15-lens.md` carries two consecutive `###` headings. Commit `17461190`
  inserted the reworded one where the blank line was instead of replacing the old one, so the first
  section is empty and the paragraph above abuts a heading with no blank line between them.
- **#2185** -- `specialist-05-05-lens.md` says both gates run *"under the job id `lint-en-tests`"*.
  Since the three-way split they run under `lint` and `suites`; `lint-en-tests` is the summary job.

#### The one place this branch departs from what the issues proposed

**#2182 proposed deleting the new heading and keeping `the two that fire beside them`. This branch
keeps the other one.** The diff of `17461190` marks `the ones that fire beside them` as the INSERTED
line and `the two ...` as the line it meant to replace, and that commit's own subject is the retiring
of stale counts (*"the eight `Gate N` headings lost their ordinals, and the hard-stated count went with
them"*). `CLAUDE.md` states the principle outright: *"neither count is stated here any more,
deliberately: both went stale as gates were added, and a wrong number reads as authority."*

`two` is accurate today -- the label gate and the always-on budget gate are the two of the ten
subsections that read nothing on the branch document -- and it is also the half that goes stale the
next time a gate is added beside them. So the de-counted wording survives and the counted one goes.
The report's symptom stands exactly as filed; only its choice of survivor changed.

### CREATE

- [x] `specialist-05-15-lens.md` -- delete the duplicated `### The gates on the branch document, and
      the two that fire beside them`, restore the blank line above the surviving heading (#2182)
- [x] `specialist-05-05-lens.md` -- rewrite the CI passage: the gates run under `lint` and `suites`,
      `lint-en-tests` is the summary job over those five legs, and a red `lint-en-tests` is never where
      the failure is (#2185)
- [x] Check the tree for the same claim elsewhere -- `grep 'under the job id'` finds only this one; the
      other two hits are `claude-review`, a different workflow, and both are correct
- [x] Check the tree for links into either anchor -- `grep 'fire-beside-them'` finds none, so no deep
      link resolved to the empty section and none breaks with its removal

### TEST

- [x] Lint gate + all suites, via `open-pr.ps1` (its own step 1)
- [x] Both repaired passages re-read against their subject: `ci.yml`'s job ids (`lint:` 119,
      `suites:` 130 with a four-shard matrix, `lint-en-tests:` 254 with `needs: [lint, suites]`), and
      the ten `####` subsections under the surviving `###` heading

### DEPLOY: docs/2182-2185-lens-heading-and-ci-job

Two accuracy repairs in the lenses the #2179 migration touched, neither of which any gate can see.
Sylvester's lens shipped a duplicated `###` heading with an empty section behind it; Derek's lens sent
a session debugging a red check to a job that runs no PowerShell and never touches the repo. The second
is the one that cost something: it is the passage a session reads to understand why a merge is blocked,
and it named the summary job where it should have named the leg. Check 4 of the lint gate validates
anchor existence, not heading structure, and nothing at all reads prose against `ci.yml`, so both were
green on `main`.

**Score:** 2

#### What makes this deploy extra special

A repo lens is this repo's own file and travels in no plugin payload, so nothing here reaches a
consumer.

**Score:** N/A

#### Pull Request

Two accuracy repairs in the lenses the #2179 migration touched
