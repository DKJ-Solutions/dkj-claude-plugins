## docs/2730-findings-block-rules-only

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

#### Issue and the decision it left open

[#2730](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2730) asked whether the 29
on-demand subagent copies still need the full reasoning, or whether Chris gets a short variant. The
answer here is **one short source for everyone**. A second variant is a second shared block and its own
duplication cost. Every copy keeps all eight rules. Only the arguments for them move, behind an
absolute link, because the copies sit in four plugin roots and a relative link would escape each of
them (`plugin-link`).

### CREATE

- [x] `subagent-shared/findings-become-issues.md` cut to the eight rules, one bold sentence plus at
      most a line each, ending in a link to the reasoning. 5,294 B to 1,927 B.
- [x] `plugins/dkj-subagents/README.md` gains *Why the filing rules read the way they do*, holding the
      block's previous text verbatim.
- [x] `build-agent-defs.ps1` regenerated all 30 copies. Chris's persona goes from 19,165 B to 16,317 B.
- [x] The README's list of shared blocks named fourteen of the seventeen. Corrected, since the new
      section sits right under it.

### TEST

- [x] The generator reports 30 files updated and the rest in sync. The full gate runs in `ship-pr`.

### DEPLOY: docs/2730-findings-block-rules-only

The shared block that tells every specialist to file findings as issues now states its eight rules
briefly and links to the reasoning, instead of arguing each rule in place. Chris's persona is loaded
into every session, and it shrinks by about 2,850 bytes. The rules themselves are unchanged and stay in
every specialist's definition. The reasoning they carried until now, word for word, is in
[the teams README](../plugins/dkj-subagents/README.md#why-the-filing-rules-read-the-way-they-do).

**Score:** 2

#### What makes this deploy extra special

A consumer session's always-on context is about 900 tokens smaller once this release is installed,
because Chris's persona ships in the core team. The filing behaviour is meant to stay exactly as it
was.

**Score:** 2

#### Pull Request

Shared findings-become-issues block keeps its rules; the reasoning moves to the teams README

The block is cut to its eight rules and links to a README section holding its previous text verbatim,
regenerated into all 30 copies. Chris's always-on persona shrinks from 19,165 B to 16,317 B.

