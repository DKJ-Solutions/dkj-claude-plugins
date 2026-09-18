## fix/2091-openpr-idx-region-scoped

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

#### What #2091 reported, and what was verified before anything was written

`scripts/tests/pr-issues.tests.ps1` pinned several of `open-pr.ps1`'s orderings with a whole-file
`$openPrText.IndexOf(...)` -- the same defect #2090 repaired one script over. Every claim in the
report was measured against the tree at `85dd041d` before the repair was designed, and all of them
stand exactly as filed:

- Of the 13 needles those reads used, **three match in more than one place**: `if ($existingPr) {`
  at 704, 799 and 1892; `if ($RefreshBody) {` at 443 and 1897; `Invoke-WorkflowGates -RepoRoot` at
  448 and 1798.
- **One was already pinning the wrong block.** `$idxExisting` resolved to **704** -- the `-Title`
  warning -- while the assert it anchors is about the existing-PR body path at **1892**, 1188 lines
  below. Both of its asserts passed on that anchor.
- `open-pr.ps1` has **no** top-level `function` and **no** `# --- Step ` banners; its ten `# --- `
  banners sit at column 0 at 566, 634, 713, 908, 1405, 1510, 1584, 1682, 1836 and 1860.

So `Get-ShipIdx` could not be reused as written, exactly as the report said: the two scripts divide
themselves up differently, and the opener pattern is the whole of what had to generalise.

#### One thing the repair found that the report did not

The old block chained its searches -- `IndexOf('if ($RefreshBody) {', $idxExisting)` -- and then
asserted `$idxRefresh -gt $idxExisting`. A search that STARTS at X can only return something greater
than X, so that compare proved nothing beyond "the needle still exists somewhere after the anchor".
The region now isolates all three needles on its own, so `-From` is gone from this block and each
index is located independently. The compare is the assertion, so it has to be made between two
indices that were found without reference to each other.

### CREATE

- [x] Generalise the #2090 machinery into a source-agnostic core -- `Register-SourceScript`,
      `Get-SourceRegions`, `Get-SourceProseMap`, `Get-SourceIdx` -- keyed on a registry, with the
      **opener pattern supplied per script**. Hoisted to the suite's helper area, because
      `$openPrText` is read ~370 lines above where the ship-pr helpers used to be defined.
- [x] Keep `Get-ShipIdx` as a thin wrapper and add `Get-OpenPrIdx` beside it, both splatting
      `$PSBoundParameters`. That preserves the 45 existing ship-pr call sites verbatim, and carries
      `-From`'s *explicitly passed* bit through -- a wrapper forwarding the default would collapse
      the "negative `-From` is refused" distinction into a silent whole-region search.
- [x] Register `open-pr.ps1` with `(?m)^(?:#\s+---\s|function\s).*$` and `ship-pr.ps1` with its own
      `# --- Step ` pattern, unchanged.
- [x] Convert **all 13** positional reads of `open-pr.ps1` to `Get-OpenPrIdx` with `-In` and `-Code`.
- [x] Drop the `LastIndexOf(..., $idxPush)` workaround for the gate call -- the region picks the
      right one now, which is what that hand-written compensation was standing in for.
- [x] Add the helper's own two properties for `open-pr.ps1`, mirroring the ship-pr pair and measured
      against the real script rather than a fixture.

### TEST

- [x] `pr-issues.tests.ps1`: **1015 asserts pass**, up from 1013 (the two new property asserts).
- [x] **The repair is not a no-op, and this is the measurement that proves it.** Each of the 13
      needles resolved whole-file vs. region-scoped: the three ambiguous ones move
      (`if ($existingPr) {` **704 -> 1892**, `if ($RefreshBody) {` **443 -> 1897**,
      `Invoke-WorkflowGates -RepoRoot` **448 -> 1798**) and the other ten are unchanged. The first
      is the mis-anchor the issue measured, now pointing at the block its assert names.
- [x] **Negative test 1 -- a renamed region.** Renaming the `# --- Already open?` banner produces the
      named `[FAIL] open-pr.ps1 has no region opening with 'Already open' -- the assert below cannot
      be placed`, not a silent re-anchor. Restored afterwards; `git status` clean.
- [x] **Negative test 2 -- the ordering itself.** Moving the `Add-ResolvesBlock` call above the
      `if ($RefreshBody) {` block, inside the same region, turns exactly one assert red: *"open-pr.ps1
      appends the closing block AFTER the refresh, not before it (#919)"*. So that assert is live on
      the real call site, which is the half that was not true before. Restored; `git status` clean.
- [x] A first perturbation attempt did NOT fire, and the reason is worth recording: PowerShell `-like`
      is case-insensitive, and the replacement text still contained the words "already open". The
      region matcher inherits that from #2090 and it is not a defect -- but a negative test has to be
      checked for having actually broken something, or it certifies nothing.
- [x] No stale references to the removed `Get-ShipRegions` / `Get-ShipProseMap` anywhere in the tree.
- [x] Lint gate: `0 error(s)`. Full test gate via `open-pr.ps1 -GatesOnly`.

### DEPLOY: fix/2091-openpr-idx-region-scoped

`pr-issues.tests.ps1` located things inside `open-pr.ps1` with a whole-file `IndexOf`, which finds
the first occurrence anywhere in the file. Three of its 13 needles already matched in more than one
place, and one assert was pinning a block **1188 lines** from the one it names -- green on the
`-Title` warning while claiming to be about the existing-PR body path (#2091).

#2090's region-scoped lookup is now generalised: one `Get-SourceIdx` core with the **opener pattern
supplied per script**, since `open-pr.ps1` divides itself by plain `# --- ` banners where
`ship-pr.ps1` divides itself by `# --- Step ` banners and top-level functions. `Get-ShipIdx` and
`Get-OpenPrIdx` are thin wrappers over it, so all 45 existing ship-pr call sites are untouched. All
13 open-pr reads are now region-scoped and code-only, a `LastIndexOf` workaround is gone, and the
`#919` block no longer chains its searches -- an assert anchored at the index it compares against
could only ever pass.

**Score:** 2

Nothing a consumer runs changes: this is a test suite pinning two scripts it cannot run, and both
scripts are byte-identical after the branch. What changes is whether those asserts can be believed
the next time one of them goes red -- and one of them was already answering about the wrong block.

#### What makes this deploy extra special

The repair carries its own proof in both directions, which is the thing a test-integrity change
usually cannot show. The forward measurement lists all 13 needles whole-file against region-scoped,
so "this changed nothing" is refuted with three moved anchors and ten deliberately unmoved ones. The
two negative tests then break the script on purpose -- once structurally, once in the ordering the
assert is actually about -- and both go red in exactly the right place. The first attempt at the
structural one silently passed because `-like` is case-insensitive and the perturbation left the
matched words in place; that is recorded above rather than quietly re-run, because a negative test
nobody verified had bitten is a green tick for nothing.

**Score:** N/A

The subscriber of this service takes nothing from this branch -- no shipped script, hook, manual or
agent def changes. It is a suite in the source repo, guarding two scripts in the source repo.

#### Pull Request

open-pr's ordering asserts are region-scoped and code-only, like ship-pr's

