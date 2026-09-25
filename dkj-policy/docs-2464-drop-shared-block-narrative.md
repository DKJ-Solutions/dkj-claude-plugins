## docs/2464-drop-shared-block-narrative

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

#2464 proposed moving ~1 KB of narrative per file out of the two generated shared blocks. The
earlier attempt, recorded on the issue, measured the full split at ~0.5 KB per file (a pointer
costs back most of what it moves), found that most candidates are operative guidance, and found
that an on-demand home would need four uncontrolled copies. What was left standing is the two
sentences that are pure narrative, and those are dropped outright. The issues they came from
still hold the evidence.

### CREATE

- [x] `subagent-shared/findings-become-issues.md`: drop "Measured twice in one session..." and
      "Measured -- a report proposed gating a check..."
- [x] Regenerate the 30 stamped copies through `build-agent-defs.ps1`

### TEST

- [x] `build-agent-defs.ps1 -Check` in sync; `git grep` finds neither sentence left under `plugins/`

### DEPLOY: docs/2464-drop-shared-block-narrative

The shared "findings become issues" block in every agent def and persona loses two sentences
that only told the story behind a rule. The rules stay word for word. That saves ~0.4 KB per
copy, across 30 files, and Chris's always-on persona is one of them.

**Score:** 1 -- trims the per-dispatch and always-on cost. No behaviour changes.

#### What makes this deploy extra special

N/A -- a subscriber sees the same rules; only the anecdotes are gone.

**Score:** N/A

#### Pull Request

Drop the two pure-narrative sentences from the findings-become-issues shared block

