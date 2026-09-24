## fix/2420-thumbnail-generator-connector-owner

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

Inbound #2420: `connectors/thumbnail-generator.json` still named `DaveKJohn/thumbnail-generator`
after the repo moved into the `DKJ-Solutions` org (thumbnail-generator PR #26). Verified before
repairing: `gh repo view DKJ-Solutions/thumbnail-generator` resolves as the canonical name. The report's
guess that other connectors moved too was checked: `DaveKJohn/djcylow-react` still resolves under
its own owner, so this one entry is the whole repair.

### CREATE

- [x] Set `repo` to `DKJ-Solutions/thumbnail-generator` and record the move in the entry's `notes`.

### TEST

- [x] `check-connectors.ps1` names the entry `DKJ-Solutions/thumbnail-generator`. The consumer checkout
  is not on this machine, so the match with its origin is checked in that repo's own next session.

### DEPLOY: fix/2420-thumbnail-generator-connector-owner

The connector register now names `thumbnail-generator` under the `DKJ-Solutions` org it moved to, so
that consumer's session check stops reporting its own origin as unregistered.

**Score:** 1

#### What makes this deploy extra special

N/A -- the register is this repo's own bookkeeping and ships to no subscriber.

**Score:** N/A

#### Pull Request

Register thumbnail-generator under its new owner

