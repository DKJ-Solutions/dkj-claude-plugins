## fix/2180-entry-shape-per-branch-exclusion

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

#### What #2180 reports, and what was verified before anything was written

The report's own six checks, run against the tree on September 20, 2026, after the trunk was brought
current:

- [x] Symptom: `Get-BranchFilePaths` with no `-Branch` answers `dkj-policy/development.md` -- measured,
      so check 20's exclusion set names a file that has not existed since #1255.
- [x] Reason: `Test-IsPerBranchDocumentPath -RelativePath 'dkj-policy\fix-2180-x.md'` answers `True`,
      and `$linkFiles` sweeps the folder recursively -- so the branch document is swept and not exempt.
- [x] Proposed repair: the predicate exists and checks 4 and 11 already pair it with their own fixed
      list. This is the third site #1255/#1335 missed, and it takes the same answer.
- [x] Size, subject, repo: one check in one file, in this repo.

### CREATE

- [x] `check-plugin-integrity.ps1` check 20: add `Test-IsPerBranchDocumentPath` beside the fixed legacy
      list, and say in the comment why the list is kept rather than replaced.

### TEST

- [x] `check-plugin-integrity-docs.tests.ps1`: a new 20c block -- the branch document and the folder's
      own README carry the identical stale sentence in ONE run, so the negative cannot be vacuous, plus
      a pin that the pre-#1255 shared name is still exempt.
- [x] The new block fails against the unrepaired check and passes against the repaired one -- run both
      ways rather than only the second, since a test that never saw the bug is a test of nothing.
- [x] Lint gate + all suites green.

### DEPLOY: fix/2180-entry-shape-per-branch-exclusion

Check 20 of the plugin-integrity gate now exempts a branch's own development document by the pattern
that names it, instead of by the shared filename it carried before September 3, 2026. The exclusion had
been built from a branch-less `Get-BranchFilePaths`, which answers the retired `dkj-policy/development.md`
-- so the per-branch rename silently undid it, the third site of that rename to be found this way. The
legacy names stay in the list beside the predicate, so a branch opened before the rename is still exempt.
The failure this removes is noise rather than silence, which is the opposite of the two sibling checks:
a branch document quoting a section count while explaining the entry format would have been reported as
stale prose and failed the gate.

**Score:** 2

#### What makes this deploy extra special

N/A -- a lint-gate exclusion inside this repo's own tooling. A consumer meets check 20 only through the
gate this repo runs on itself; nothing in their tree or their workflow changes.

**Score:** N/A

#### Pull Request

check 20 exempts the per-branch development document by pattern, not by its retired shared name

