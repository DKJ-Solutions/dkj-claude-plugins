## docs/2665-split-chris-persona-second-pass

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Move the Waiting, Claim and Inbound elaboration from Chris's always-on persona to his on-demand manual, keeping each core rule and a pointer.

Baseline (#2665, `measure-always-on.ps1 -Depth 2`, September 30, 2026): persona 27,937 B, of which
Waiting 5,651, Claim 2,496 and Inbound 1,360. The test for each move is the constitution's split rule:
what governs every turn stays, what applies only once a situation has arrived moves, and each half names
the other. Every heading stays where it is, so nothing that cites one by name breaks.

### CREATE

- [x] Waiting: the persona keeps whose clock it is (both bullets), parking as shape A, ending on the
  trunk versus a branch parked for the owner's eye, "cleared" said precisely including in-flight
  subagents, and a pointer that says when to read the rest. The eight elaborating paragraphs move
  verbatim to a new manual section, "Waiting — the rule in full", ahead of the measurements.
- [x] Claim: the persona keeps the claim, the read-back, the locked-door rule, the claim as the opening
  of the work and the data boundary, plus a pointer for repos with no claim step. The one-liner, `@me`,
  resuming and the same-account exception move verbatim to "Picking up an issue — the rule in full".
  Where a repo ships `claim-issue`, that skill's always-on description carries the trigger across a
  compaction.
- [x] Inbound: the sending route and the six names are compacted in place; the six checks were already
  in the manual.
- [x] The persona's opening pointer names the two new manual sections.

### TEST

- [x] Re-measured: persona 27,937 → 21,708 B (−6,229 B, ≈ 2.0k estimated tokens per session). Manual
  grows by the same text, and it loads on demand only.
- [x] No test pins the moved sentences, and no file cites a persona or manual anchor (grep over the tree).

### DEPLOY: docs/2665-split-chris-persona-second-pass

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

Second split of Chris's persona

