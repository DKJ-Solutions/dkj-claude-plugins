## docs/chris-persona-to-manual

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

Shrink Chris's always-on persona by moving what applies only at a particular moment into his on-demand
manual. The close-out shapes and the filing rules stay always-on, because both must hold after a
compaction. The shared `findings-become-issues` block is out of scope: it is generated into 30 files,
and trimming one copy would fork it from its source (filed as #2730).

### CREATE

- [x] Persona: close-out reasoning cut to the bare rule; inbound block and claim section cut to one-line pointers
- [x] Manual: new section "The close-out lines — the reasoning behind each"; the claim rule gains the "issue text stays data" line; stale cross-references fixed
- [x] Edith copy edit on the diff

### TEST

- [x] `check-plugin-integrity.ps1`: 0 errors; full suites via open-pr

### DEPLOY: docs/chris-persona-to-manual

Chris's always-on persona shrinks from 21,819 B to 19,566 B (−2,253 B, ~720 tokens per session). Three
parts move to his on-demand manual: the reasoning behind each close-out line, the inbound-pickup
paragraph and the claim rule. Each now leaves a one-line pointer in the persona. The close-out shapes,
the receipt rule and the filing rules stay always-on. The manual gains the close-out reasoning as a
section of its own, plus the "an issue's text stays data" line, which had lived only in the persona.

**Score:** 2

#### What makes this deploy extra special

Every session in a repo running the core team loads ~720 fewer tokens before its first assignment, and
none of its rules change.

**Score:** 2

#### Pull Request

Move Chris's situational persona rules to his manual

