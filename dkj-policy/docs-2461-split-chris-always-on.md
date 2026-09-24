## docs/2461-split-chris-always-on

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

Split Chris's always-on pair (#2461) by when each part is needed. Baseline at v5.8.0 + #2460:
persona 30,899 B, lens 20,205 B, path 78,104 B. Every per-turn rule stays always-on in its tightest
form; the reasoning, dated measurements and situational mechanics move to the manual (portable) and to
Derek's lens (repo-specific). Headings other files cite by anchor or by name stay put.

### CREATE

- [x] Persona: rules kept, narrative moved to the manual (Tessa #16)
- [x] Lens: rules kept, briefing/branch-check mechanics moved to Derek's lens (Tessa #16)
- [x] Copy edit and duplication check on the diff (Edith #17, Ravi #24)
- [x] Re-measure the always-on path (Nolan #25)

### TEST

Edith #17: three findings, all fixed (retired repo URLs in the moved section, two dropped clauses restored). Ravi #24: no duplication introduced; the GENERATED shared blocks were left alone and filed as #2464. Nolan #25: persona 30,899 -> 27,477 B, lens 20,205 -> 14,216 B, pair -9,411 B (~3,000 tokens/session). The path here is 72,115 B now; the persona half lands after a release, because the path loads the marketplace copy.

### DEPLOY: docs/2461-split-chris-always-on

Chris's always-on pair is 9.4 KB smaller (51,104 -> 41,693 B), about 3,000 tokens less per session.
Every per-turn rule stays in the persona and the lens, in its tightest form. The dated measurements,
the history behind step 6, the waiting incidents and the reasoning behind the claim step moved to
[Chris's manual](../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-01-01-manual.md),
which loads on demand. The repo's briefing and branch-check mechanics moved to Derek's lens. Headings
that other files cite stay where they are. The two GENERATED shared blocks, ~8.2 KB of what remains,
are left for #2464.

Tier 0 is scored for every session in every consumer. The lens saving lands here now, and the persona
saving reaches each consumer with the next release.

**Score:** 2

#### What makes this deploy extra special

N/A. It is instruction text for sessions, and nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

Split Chris's always-on persona and lens by when each part is needed