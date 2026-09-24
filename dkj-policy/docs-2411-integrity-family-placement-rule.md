## docs/2411-integrity-family-placement-rule

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

#2411: state where a new numbered check's tests go in the `check-plugin-integrity-*` family, and check
whether the fifteen files each re-pay a fixture setup a coarser grouping would pay once.

### CREATE

- [x] Measured locally: fixture lib dot-source ~245 ms, `New-IntegrityFixture` ~30 ms (n=5), one
  `Invoke-Integrity` ~2.4 s (n=3), ~280 call sites across the family. Per-file start is ~0.3 s x 15
  = ~4 s of 2,494.6 s (0.2%): the re-paid-setup hypothesis does not hold.
- [x] Tycho's lens: the placement rule (subject file first; a new file only above the gate's work
  bound), the measurement behind "fewer files is not the lever", and the stale "seven" membership
  list replaced by a pointer to the fixture header.
- [x] Fixture header: a short pointer to that rule beside the membership table.

### TEST

- [x] Lint and test gates run by open-pr.

### DEPLOY: docs/2411-integrity-family-placement-rule

The `check-plugin-integrity-*` test family now has a stated rule for where a new numbered check's
scenarios go. They join the existing file that owns their subject. A new file is justified only when
that file's CI median would exceed the gate's work bound (sum of suite medians over lanes, ~352 s
today), which is the condition every past split was actually bought on. The second half of #2411 was
measured and does not hold: a file's own start costs ~0.3 s, about 4 s across fifteen files against
the family's 2,494.6 s, so merging files would buy nothing. The family's 35.5% share is set by how
many times it runs the gate, not by how many files it has. The rule lives in the test engineer's repo
lens, with a pointer beside the membership table in the shared fixture. Closes #2411.

**Score:** 2

#### What makes this deploy extra special

N/A -- repo-internal test organisation; nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

Where a new check-plugin-integrity check's tests go, and why fewer files would not help
