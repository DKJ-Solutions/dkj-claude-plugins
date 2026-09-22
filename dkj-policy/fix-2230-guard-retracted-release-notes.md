## fix/2230-guard-retracted-release-notes

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

Inbound #2230: `Build-ReleaseNoteDraft` selects a release's audience entries by tier alone, so a build
that reached the trunk and was then reverted before the cut is drafted as delivered work -- measured in
`BWJ-Development/smartwatchbanden` v2.44.0, where two retracted features survived into the published
management release-notes page. The issue's own suggested shape is an optional `Retracts:` line on the
retracting entry, resolved at cut time; its own honest objection rules out inferring a retraction from
prose or git history, so this branch reads only what an entry says about itself.

### CREATE

- [x] `Get-EntryRetracts` (release-lib.ps1) and `Get-EntryDeclaredBranch` (entry-scaffold-lib.ps1): read
      the optional `Retracts:` line, and a single entry's own declared branch.
- [x] `Resolve-ReleaseRetractions` (release-lib.ps1): resolves every `Retracts:` line across the WHOLE
      pending set (not one tier), returning retracted/retracting branches, what was withheld, and an
      unresolved-target error list -- a typo is an error, never a silent no-op (the issue's point 5).
- [x] `Format-RetractionWithheldNote` + `Build-ReleaseNoteDraft -WithheldNote`: the audience document
      keeps rendering its section (and the caller's note) even where retraction empties it completely,
      instead of silently falling through the "no section where nothing reached this tier" rule.
- [x] `cut-release.ps1`: a guardrail refuses the cut (nothing written) on an unresolved `Retracts:`
      target; `$audienceEntries` is filtered to the intersection actually present in this one document
      before `Build-ReleaseNoteDraft` runs. `CHANGELOG.md`, its changelog note (the record) and the
      generated GitHub Release body are all left untouched, exactly as the issue asks.
- [x] `scripts/sync/build-shared-scripts.ps1` run so the `plugins/dkj-policy/scripts/` mirrors match.

### TEST

- Unit coverage added: `Get-EntryDeclaredBranch` (entry-scaffold.tests.ps1), `Get-EntryRetracts` /
  `Resolve-ReleaseRetractions` / `Format-RetractionWithheldNote` / `Build-ReleaseNoteDraft -WithheldNote`
  (release-lib.tests.ps1) -- including the unresolved-target error case and the byte-identical-when-omitted
  case for the new parameter.
- End-to-end coverage added in `cut-release-drive.tests.ps1`: a real cut against a throwaway git repo with
  a tier-2 entry and a tier-0 entry that retracts it -- the audience document withholds the retracted
  entry and names both branches in its comment, while the changelog note (the record) keeps both; and a
  second scenario proving a typo'd `Retracts:` target refuses the cut before anything is written.
- All four affected suites run locally: `release-lib.tests.ps1` (549 asserts), `entry-scaffold.tests.ps1`
  (853), `cut-release-guardrail.tests.ps1` (111), `cut-release-drive.tests.ps1` (58) -- all green, no
  regressions against the pre-branch baseline. `scripts/lint/check-plugin-integrity.ps1` run locally too
  (green after the mirror sync above); the full local suite gate is skipped per this machine's own memory
  note and left to CI.

### DEPLOY: fix/2230-guard-retracted-release-notes

`Build-ReleaseNoteDraft` selected a release's audience-facing entries by tier alone, with no way to see
that a later pending entry retracts an earlier one -- so a build that reached the trunk and was reverted
before the cut was drafted as delivered work, in the author's own confident words, in the one document
an employer or commissioner reads to learn what their money bought (measured in `BWJ-Development/smartwatchbanden`
v2.44.0: two of three retracted features survived into a published management release-notes page).

The repair is the issue's own suggested shape, in full rather than the weaker report-only fallback: an
optional `Retracts: <branch>, <branch>` line on the entry that undoes earlier work, read and resolved
across the whole pending changelog (`Resolve-ReleaseRetractions`), an unresolvable target refused at cut
time rather than read as "nothing to withhold," and the withheld branches named in an HTML comment in the
audience document so the person finishing the draft sees the decision instead of a silent gap. `CHANGELOG.md`,
its changelog note and the generated GitHub Release body are untouched -- all three are records of what
reached the trunk, and the retracted work did too. The field is optional and absent from every existing
entry, so an ordinary release is byte-for-byte unchanged; asserted directly in `release-lib.tests.ps1`.

**Score:** 2

#### What makes this deploy extra special

The reader here is the party that runs the upgrade -- a consuming repo (life-hub, smartwatchbanden, and
every other repo that installs `dkj-policy`) cutting its own release with `cut-release.ps1`. Most releases
carry no retraction and this change is invisible to them. When one does, it is exactly the failure the
issue measured: a deliberately-pulled build announced as shipped, in a document that has already been read
by the time anyone notices -- "the one error in this whole cycle that a consumer cannot correct after the
fact," in the issue's own words. Rare, but when it fires it protects a real published document from a
confidently wrong sentence rather than merely tidying prose.

**Score:** 3

#### Pull Request

Guard cut-release against drafting a retracted change as delivered work

