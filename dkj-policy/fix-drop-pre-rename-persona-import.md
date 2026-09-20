## fix/drop-pre-rename-persona-import

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

The overlap line #2135 put in SPECIALISTS.md says to delete it once the line above resolves. It does now, and the dead line makes the always-on gate carry the persona a second time.

### CREATE

- [x] Removed the pre-rename orchestrator import line, and the comment that said to remove it, from `.claude/specialists/SPECIALISTS.md`; the line above it (`specialist-01-01-persona.md`) stays and resolves in this machine's marketplace clone
- [x] Raised the always-on baseline to 110,314 B with a recorded reason, in the same commit, because the gate judges the persona from the tree now (#2187) and reads 239 B over the figure recorded from the older clone copy

### TEST

- [x] Ran `check-always-on-budget.ps1` on `main` before the edit: 140,974 B, the dead import warned about, the pre-rename persona counted a second time as 30,267 B carried from the baseline
- [x] Ran it after the edit: 110,314 B, no dead-import warning; the 239 B left over the recorded baseline is the persona's source size (30,899 B against the 30,267 B clone copy the baseline held), so the baseline was raised rather than the path shrunk

### DEPLOY: fix/drop-pre-rename-persona-import

This repo's always-on document path no longer names the orchestrator persona under both its old and its
new filename. #2135 put both import lines in `SPECIALISTS.md` on purpose, so that a checkout whose
marketplace clone still held the old name kept its orchestrator while the clone refreshed, and left
a comment saying to delete the old line once the new one resolved. It resolves now, so the old
line pointed at nothing, and the always-on budget gate warned about the dead import and counted the
same persona a second time, as 30,267 B carried from the baseline. That put the measured path at
140,974 B against a recorded 110,075 B and made every branch in this repo, whatever it changed, read
as growing an over-budget path by 30,899 B, so `open-pr` refused it. The line and its comment are gone,
and the baseline is raised by 239 B, recorded with its reason: the persona was already 30,899 B in
the source, and the gate only started judging it from the tree in #2187.

A maintainer on a machine whose marketplace clone has refreshed meets this at the first `open-pr`:
`fix/2183-reserved-root-md-seam-row` changed nothing on the always-on path and was refused all the same.
It reaches no subscriber of the service and nothing else in the tree changes with it, which is why it
is not higher.

**Score:** 2

#### What makes this deploy extra special

N/A -- this repo's own session-start weight and its own gate; no subscriber of the service reads or does
anything differently because of it.

**Score:** N/A

#### Pull Request

Drop the pre-rename orchestrator import line now that the clone resolves the new one

