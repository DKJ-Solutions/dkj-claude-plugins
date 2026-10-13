## feat/house-style-upstream-rule

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

The dkj-solutions extension states, always-on, that a house-style change is made in dkj-brandbook and never in the consuming repo.

### CREATE

- [x] the extension's `CLAUDE.md` carries the upstream rule as its second chapter rule, with the brand book itself exempt
- [x] the `house-style` skill's "Changing the house style" section names the same route

### TEST

### DEPLOY: feat/house-style-upstream-rule

A DKJ-Solutions repo that needs the house style itself to change no longer edits its own copy: it files an
issue on `DKJ-Solutions/dkj-brandbook`, keeps working on its own layer, and takes the new copy once it has
landed there. The rule is in the `dkj-solutions` extension's always-on `CLAUDE.md`, so every session in a
repo with the plugin enabled reads it; the brand book itself is exempt, because that is where the change is
made.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions app keeps one look: a styling fix lands once, in the brand book, and every app takes it
from there instead of drifting into its own variant.

**Score:** 3

#### Pull Request

DKJ-Solutions repos change the house style upstream, in dkj-brandbook

