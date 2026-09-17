## fix/2043-closeout-fillable-template

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

Verified: the report's repair 1 is already shipped (the print IS ship-pr's last statement). The ~35 trailing lines are child-process output landing after the parent's. So repair 2 is the one that stands -- and it is also what survives the interleaving.

### CREATE

- [x] Verify the report against the tree before repairing it. Its repair 1 ("print the close-out shape LAST") is ALREADY SHIPPED: the call is the final statement of `scripts/release/ship-pr.ps1`, with a comment saying so deliberately, and the released 5.3.0 mirror the report measured is byte-identical on that block.
- [x] Establish what the ~35 trailing lines actually were: the child processes' output. `ship-pr` spawns `open-pr`, the fold and `verify-resolved-issues`, and on the reporting run every parent line appeared above every child line -- `Done: PR #683 shipped` above `PR created for`, the reverse of the file order. Filed in the report as a secondary observation; it is the primary cause.
- [x] Probe the interleaving in this harness (a parent script printing around a `& powershell` child): it interleaves CORRECTLY here, so the inversion is environment-dependent and not reproducible from this checkout.
- [x] `scripts/lib/closeout-lib.ps1`: the print hands over a fillable template instead of describing a shape -- `<what happened> -- see PR #1885. [Filed #<n>.] Session can be cleared.` The `-Cite` slot arrives already answered, the other two arrive blank.
- [x] Record the verification in the lib's own docstring -- that repair 1 was a no-op, what the trailing lines were, and the general lesson: last in the file is not last on the screen.
- [x] `plugins/dkj-subagents/dkj-subagents-alpha/manuals/01-01-manual.md`: the fifth recurrence and its lesson, under the section the persona already points at. Nothing added to the always-on persona passage.
- [x] Regenerate the plugin mirror (`scripts/sync/build-shared-scripts.ps1`).

### TEST

- [x] `scripts/tests/closeout-lib.tests.ps1` updated: the three parts asserted in their new form, plus four new asserts on the property that is the repair -- exactly one template line, indented, carrying a bracketed filing slot, and nothing else. 87 pass, 0 fail.
- [x] The output inspected by eye in all three shapes (citation, citation + bypass, no citation): the ceiling still holds at three lines, four with a bypass.
- [x] Full lint + test gate green before the PR.

### DEPLOY: fix/2043-closeout-fillable-template

The close-out reminder the chain-ending scripts print now hands over a line to fill in rather than
describing the shape to compose: `<what happened> -- see PR #1885. [Filed #<n>.] Session can be
cleared.`, with the citation slot already answered from the run's own knowledge. The three parts, the
ceiling and the rehousing rule are unchanged; only the delivery is.

It is the fifth repair of a rule that keeps losing, and the first taken after verifying that the
previous one was in force and still lost. Inbound #2043 asked for the print to be moved last -- it was
already last, the final statement of `ship-pr.ps1`. What put ~35 lines under it was the child
processes' output arriving after the parent's, which no placement can fix and whose cause does not
reproduce in this repo -- filed on its own as #2044. That **retires** the placement repair without
arguing for this one: a template printed in a buried position is exactly as buried as prose was, so
this change does not repair the ordering and is not offered as doing so. What it stands on is the
report's other argument, independent of where the line lands -- **a shape that is described has to be
composed, and a shape that is handed over has to be filled.** The general lesson banked alongside it is
that **last in the file is not last on the screen**.

**Score:** 3

#### What makes this deploy extra special

Every repo running this workflow gets the new line at every `open-pr`, `ship-pr`, `park-branch`,
`fold-changelog-entry` and `cut-release`, on its next plugin update. Nothing to do and nothing breaks
-- the parameters, the suppression and the bypass clause are untouched -- but what a session reads at
the end of every chain changes wording.

**Score:** 3

#### Pull Request

The close-out receipt hands over a fillable template instead of describing one

