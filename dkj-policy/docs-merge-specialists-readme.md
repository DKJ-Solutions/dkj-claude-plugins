## docs/merge-specialists-readme

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

Dave: `.claude/specialists/README.md` and `SPECIALISTS.md` felt heavily duplicated -- merge them and
delete the README. Chosen route (Dave): de-duplicate into `SPECIALISTS.md` and distribute the unique,
on-demand content to the owning lenses, because `SPECIALISTS.md` is on the always-on path and a
wholesale merge would have added ~33 KB to every session and breached the 100 KB budget.

### CREATE

- [x] `SPECIALISTS.md`: one roster, the doubled blank lines removed; the seam detail and the Bianca "no caller" note moved to Tessa's lens
- [x] Tessa's lens: "How a specialist is structured here" (the seam, persona vs subagent, where a new rule goes, stable id)
- [x] Sylvester's lens: the plugin-update procedure and "Why `Get-RosterIgnoredIds` is empty"
- [x] Derek's lens: the three ways a briefing fails, and the branch check on the follow-up assignment
- [x] Every inbound link repointed (root README, `this-repo.md`, Chris's and Tessa's lenses, four archived release notes' link targets only)
- [x] `.claude/specialists/README.md` deleted

### TEST

- [x] `check-plugin-integrity.ps1`: 0 errors (the dead-link scan found the four release-note links, now retargeted)
- [x] `check-roster-sync.ps1`: 0 errors, no orphan tokens
- [x] Always-on path measured: `SPECIALISTS.md` 10,446 B -> 9,998 B, so the over-budget path shrinks rather than grows

### DEPLOY: docs/merge-specialists-readme

The specialists handbook (`.claude/specialists/README.md`) is gone, and
[`SPECIALISTS.md`](../.claude/specialists/SPECIALISTS.md) is the one page for the roster.
The two pages repeated the roster, the lens index and the scaffold explanation. The handbook's unique
content moved to the lens of the specialist who owns it, so it stays on demand:
[Tessa's](../.claude/specialists/lenses/specialist-06-16-lens.md#how-a-specialist-is-structured-here)
for how a specialist and this directory are structured,
[Sylvester's](../.claude/specialists/lenses/specialist-05-15-lens.md#updating-the-plugins--in-every-other-checkout-of-this-repo)
for the plugin-update procedure and the `Get-RosterIgnoredIds` history, and
[Derek's](../.claude/specialists/lenses/specialist-05-05-lens.md#the-three-ways-a-briefing-fails-measured-here)
for the measured instances behind Chris's briefing and branch-check rules. The always-on path shrinks by
448 B, where a wholesale merge would have added ~33 KB.

**Score:** 2

#### What makes this deploy extra special

N/A -- `.claude/` is this repo's own layer and ships in no plugin, so no subscriber receives it.

**Score:** N/A

#### Pull Request

Merge the specialists handbook into SPECIALISTS.md and retire the README
