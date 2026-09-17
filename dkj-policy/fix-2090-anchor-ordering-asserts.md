## fix/2090-anchor-ordering-asserts

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

#### What #2090 reports, and what the tree actually held

The issue reports that `scripts/tests/pr-issues.tests.ps1` pins several of `ship-pr.ps1`'s orderings
with a whole-file `IndexOf`, which finds the FIRST occurrence -- so a function defined above the step
being asserted about re-points the index at the definition. It was found from the red side (#2087
added two helpers above step 3 and four asserts went red without the wait changing), and it infers
that the remaining ~14 reads would break the same way.

Verified before repairing, and the inference is only half right. Of the 35 distinct ship-pr needles
this file uses, **7 already matched in more than one place** -- so they are fragile today, not
hypothetically -- and **two of those already resolved to PROSE**, which is the OTHER direction the
issue names and the worse one, because it is green:

- `Get-MergeBlockVerdict` resolved to a comment at ship-pr.ps1:1523, 121 lines above its first call
  (1644). `the wait still happens FIRST and the verdict second` was passing on a comment.
- `Get-MissingCheckSuiteNote` resolved to a `.PARAMETER` line inside `Get-MissingCheckSuiteRefusalNote`'s
  docstring (829) rather than to the call at 862. #1584 had lifted that read out of step 3's inline
  probe into the shared builder, and the assert followed it into the docstring.

The other 28 needles are unique today and were only fragile against a future duplicate.

### CREATE

- [x] `Get-ShipIdx` in `scripts/tests/pr-issues.tests.ps1`: one region-scoped lookup, the only way
      this suite locates anything in ship-pr.ps1. `-In` names the region -- a top-level `function`
      or a `# --- Step ` banner, up to the next one of either, which are the two boundaries that move
      with the script rather than with a line number. `-Code` skips a match on a comment line or
      inside a block comment. `-Last` and `-From` cover the two sequencing cases. A needle it cannot
      find is a named FAILURE rather than a silent `-1`, because `-1` compares as "earlier than
      everything" and a `-lt` assert would read a deleted call site as a pass.
- [x] All 44 `$shipText.IndexOf(...)` / `.LastIndexOf(...)` reads converted; none remains.
- [x] Two hedges that only existed because of the whole-file lookup removed with it: the
      `-or $shipText -like '*...*'` half of the pending-list assert, which made it true whenever the
      text existed anywhere, and the manual `IndexOf(x, $anchor)` offsets now expressed as regions.

#### What was NOT swept, and why

`$openPrText`'s 13 reads in the same file have the same shape and three of their needles are already
multi-occurrence -- `if ($existingPr) {` resolves to open-pr.ps1:704, the `-Title` warning, 1188 lines
above the body-edit block at 1892 that the assert names. That is out of #2090's scope, which is
written about `$shipText`, and it is filed as [#2091](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2091) rather than ridden along.

### TEST

- [x] `scripts/tests/pr-issues.tests.ps1`: 1007 asserts, all pass (1005 before, plus the two that pin
      the helper's own properties against ship-pr.ps1 itself -- same needle in two steps resolving to
      two places, and `-Code` walking past the comment onto the call).
- [x] `scripts/lint/check-plugin-integrity.ps1`: 0 errors.
- [x] The regression, run as the issue describes it: a decoy function carrying every re-pointable
      needle inserted above step 3 in `ship-pr.ps1`. The pre-change suite goes RED on two asserts
      (`the watch call sits inside the attempt loop rather than before it`, `step 3 runs the wait
      before the --watch call, as the inline loop did`); the converted suite stays green at 1007.
      `ship-pr.ps1` restored afterwards -- it is untouched by this branch.

### DEPLOY: fix/2090-anchor-ordering-asserts

`scripts/tests/pr-issues.tests.ps1` no longer locates anything in `ship-pr.ps1` with a whole-file
`IndexOf`. All 44 reads go through one region-scoped helper, `Get-ShipIdx`, which searches inside a
single `function` or `# --- Step ` region and, with `-Code`, skips comments and docstrings. A needle
it cannot find is a named failure instead of a silent `-1` that a `-lt` assert would read as a pass.

This closes both directions of the defect. The red one is what #2087 met: two helpers added above
step 3 turned four asserts red about behaviour that had not moved. The green one was measured on the
repair -- seven needles already matched in more than one place, and two of them resolved to prose
rather than to code, so `the wait still happens FIRST and the verdict second` was passing on a comment
121 lines above the call, and the check-suite read was pinned to a `.PARAMETER` line in a docstring.

**Score:** 2

Nobody outside this repo runs this suite, and nothing it guards changed behaviour. What it buys is
the next person who adds a helper to `ship-pr.ps1`: they no longer meet a red suite naming a
behaviour they did not touch, whose cheapest reading is to delete the assert.

#### What makes this deploy extra special

A test that is green about the wrong text is worse than one that is red, because nothing ever asks it
again. Two of these had drifted onto prose -- one onto a comment, one into a docstring -- while
reporting that ship-pr's wait order was pinned.

**Score:** N/A

The reader of a tier-2 change is the subscriber of a service; this is a test suite inside the repo
that authors the workflow, and reaches nobody who installs it.

#### Pull Request

pr-issues.tests.ps1's ship-pr ordering asserts are region-scoped instead of whole-file
