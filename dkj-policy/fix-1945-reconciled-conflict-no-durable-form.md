## fix/1945-reconciled-conflict-no-durable-form

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

#### The report, verified before it was repaired

Inbound #1945, from `BWJ-Development/smartwatchbanden`. Symptom, reason and the working shape all
reproduced here against the real functions before anything was written -- a fixture repo driving
`Test-LiveContentIsOurs`, `Get-SyncPathReferencePoint`, `Test-MainTouchedSince` and
`Get-SyncFileVerdict` in sync-main's own order. All four cells came back exactly as reported.

The two quoted facts check out too: the refusal really does say *"Compare them by hand and merge
deliberately"*, and `Get-ShopifySyncReferencePattern` is a real seam under that name.

#### Which of the three proposed repairs, and why not the third

1 (say it in the refusal) and 2 (`-ReconcileBase`) are built. 3 (stop the silent revert) is
**declined with its measurement**, recorded in `Get-SyncPathReferencePoint`: a hand-written
`sync...` commit is content-indistinguishable from a genuine sync commit, so a proof would have to be
declared -- and reading an undeclared sync commit as no agreement point turns every legacy path's
drift into a conflict on the first run after the upgrade, which refuses the whole run in every
consumer at once.

### CREATE

- [x] `-ReconcileBase` on `sync-main.ps1` -- `Write-SyncReconciliationBase` writes the pair
- [x] the refusal block names the durable shape and both failure modes
- [x] `Get-SyncPathReferencePoint` and `Get-SyncFileVerdict` carry the declined repair and its reason
- [x] `Test-LiveContentIsOurs` takes `--full-history` (found while testing; see DEPLOY)
- [x] the `sync-main` skill page: the parameter, the refusal row, and a section of its own
- [x] shared-script mirrors rebuilt

### TEST

- [x] `sync-rules.tests.ps1` -- the four reconciliation shapes + the simplification case (164 asserts)
- [x] `sync-main.tests.ps1` -- `-ReconcileBase` end to end, through the merge and back (155 asserts)
- [x] `check-plugin-integrity.ps1` -- 0 errors

### DEPLOY: fix/1945-reconciled-conflict-no-durable-form

A sync conflict you reconcile by hand now has a durable form, and the refusal says what it is. It
used to end at *"compare them by hand and merge deliberately"* -- complete advice about the content
and silent about the shape, which is where the single commit a person naturally reaches for fails. It
fails in one of two ways, chosen by nothing but the commit's subject: an ordinary subject leaves the
path conflicted on every future run, and a subject matching the sync pattern makes that commit the
path's own agreement point, so the next run reads the trunk as stationary and deletes the
reconciliation. Neither announces itself. Reported from a consumer on seven conflicted paths, where
the second would have re-deleted a locale key from five files, reverted seven string fixes and
dropped an unpushed section.

The cause is that merged bytes are neither side's, so they carry no provenance -- and provenance is
the whole of what the rule reads. So the refusal now names the durable two-commit shape, and
`-ReconcileBase` writes it: live's bytes verbatim, then the trunk's own bytes straight back on top.
The branch changes no file, which is what makes merging it safe at every point, and after it the path
reads `keep-trunk` permanently -- the same state every ordinary held-back file is in. The
reconciliation itself is then ordinary work in an ordinary commit, in any spelling.

**Score:** 3

#### What makes this deploy extra special

**Building the repair found a second defect underneath it, in a function that had been answering a
narrower question than its own name since it was written.** `Test-LiveContentIsOurs` asks whether a
path has *ever* held live's exact bytes, and `git log -- <path>` does not answer that: it applies
history simplification, so at a merge whose result for that path equals the first parent's, the
entire merged side is pruned, every blob on it included. It survived because the ordinary sync branch
changes the path and nothing puts it back, so its merge is never TREESAME and the walk follows it --
every take-live this rule has ever made is unaffected. The shape that hits it is a branch whose net
effect on a path is zero, which is exactly what `-ReconcileBase` writes on purpose. Measured: after
that merge the reconciliation base was invisible and the path reported the same conflict it started
with. `--full-history` is the repair, and it moves only in the protective direction -- more content
recognised as ours means keep-trunk where the answer would otherwise have been take-live.

**And the third proposed repair is declined rather than deferred**, with the measurement in the code:
a hand-written `sync...` commit cannot be told from a genuine one by anything in the content, because
every case that reaches that cell is one where live has moved since the base either way. A proof
would have to be declared, and no declaration can describe history that is already written -- so the
strict version would stop the sync dead in every consumer at once, to close a hole that needs the
operator to ignore a printed warning first. The repair lands where the hazard is created instead.

**Score:** 3

#### Pull Request

A hand-reconciled sync conflict gets a durable form

Plugins: dkj-subagents-shopify
