## fix/2199-one-lens-assembler

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

Promote the duplicated lens assembly out of `Get-ConsumerLensPaths` and `Get-ConsumerProseDocuments`'
kind-3 walk into one shared function; the exclusion stays at the call site because the two mean
different things by it.

#### The home was the one open question, and #2199's own proposal was half right

The issue proposed `check-report-lib.ps1`, "where the three primitives already live". Three of the four
are there -- `Get-SeamPaths`, `Get-LensDirCandidates`, `Get-SpecialistFiles` -- and the fourth,
`Get-PathRelativeToDirectory`, is in `entry-scaffold-lib.ps1`. Neither lib dot-sources the other, so
every reach between them runs through the guarded `Test-FunctionDefined` pattern, and that pattern
today runs in one direction only: from `entry-scaffold-lib.ps1` into `check-report-lib.ps1`. Landing
the assembly in `check-report-lib.ps1` would have been the first probe pointing back, turning a
one-way soft dependency into a cycle between two files that both call themselves libs. So it landed
in `entry-scaffold-lib.ps1` instead, and the reasoning is written into the function's own docstring.

### CREATE

- [x] One `Get-ConsumerLensPaths` in `scripts/lib/entry-scaffold-lib.ps1`, carrying the whole assembly:
      the seam dir, the per-plugin candidates, the slug guard, the `Get-PathRelativeToDirectory`
      conversion and the `../` escape rejection.
- [x] The duplicate local copy deleted from `scripts/task/check-policy-drift.ps1`; its call site now
      filters the shared function's return against `$consumerRels` itself.
- [x] The kind-3 block inside `Get-ConsumerProseDocuments` replaced by a call to the shared function,
      keeping its own `$seen` filter and its own wrapped `Get-EnabledPlugins` derivation.
- [x] `-Exclude` dropped from the shared function: the two callers mean different things by "already
      accounted for", so the exclusion stays at each call site.
- [x] Mirrors regenerated with `scripts/sync/build-shared-scripts.ps1`; nothing under `plugins/` was
      hand-edited, and no row in `scripts/lib/shared-scripts-lib.ps1` needed adding or changing.

### TEST

- [x] `policy-drift-report.tests.ps1` -- 32 passed, 0 failed.
- [x] `consumer-prose-gate.tests.ps1` -- all 91 asserts passed.
- [x] `check-report-lib.tests.ps1` -- 377 pass, 0 fail.
- [x] `entry-scaffold.tests.ps1` -- all 838 asserts passed.
- [x] `check-plugin-integrity.ps1`, the full lint gate including the shared-scripts drift check -- no
      findings, 0 errors.
- [x] RANK 2 proved unchanged rather than assumed unchanged: the pre-edit code run from a temporary
      worktree against this same repo, diffed against the post-edit run. Identical -- 29 lenses, 9,042
      lines, same order -- and RANK 3 identical too. A silently empty rank is this area's own known
      failure mode, which is why it was measured instead of eyeballed (#2184).
- [ ] Review pass on the diff: correctness, prose, security surface, and the per-session cost of the
      consumer-prose path.

### DEPLOY: fix/2199-one-lens-assembler

Two functions answered "where are this repo's lenses" independently, and now one does. The discovery
was already shared -- `Get-SeamPaths`, `Get-LensDirCandidates`, `Get-SpecialistFiles` -- but the
assembly around it was not: the seam directory plus the per-plugin candidates, the plugin-name slug
guard, the path-relative conversion and the `../` escape rejection sat in both the drift report's
`Get-ConsumerLensPaths` and the prose corpus's kind-3 walk. A fifth lens layout, or a third filename
spelling, would have had to be taught to each of them.

It is one shared `Get-ConsumerLensPaths` now, in `entry-scaffold-lib.ps1`. What deliberately did not
collapse is the pair's two real differences: where each caller gets its plugin names, and what each
means by "already accounted for" -- one excludes an explicit list another rank has printed, the other
excludes the set it has built so far. Both stay at the call site, so the shared function takes no
`-Exclude` at all and hands back the full de-duplicated list.

**Score:** 3

#### What makes this deploy extra special

`dkj-policy` ships both files, so this reaches every repo running the workflow -- and what it reaches
them with is nothing they can see today. The behaviour is identical on both paths, proved rather than
assumed: the drift report's RANK 2 and RANK 3 output is byte-identical before and after.

What it prevents is a failure that has not happened yet, which is the only part a later reader can
use. The two copies were close enough to look interchangeable and were not, and the next change to how
lenses are found -- a new layout, a new filename spelling -- would have been taught to one of them. A
consumer would then have a session-start prose check and an on-demand drift report disagreeing about
which files in their own repo are lenses, with neither one wrong on its own terms.

**Score:** 1

#### Pull Request

One lens-discovery assembler, shared by the drift report and the prose corpus
