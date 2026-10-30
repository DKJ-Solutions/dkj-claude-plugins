## fix/3666-connector-check-finds-renamed-source

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

Step 6 of the rename (#3666): run the aftercare checks and repair what still resolves the old name
`dkj-claude-plugins`. `check-connectors.ps1` and `check-roster-sync.ps1` were clean (0 errors). The
`git grep` over this repo and the consumers found citations, the retired-names list and regexes that
already accept both names, plus one site that resolves the name: `connector-sessioncheck.ps1` looks for
the source checkout under the old folder names only. Measured from `dkj-lifehub` beside a checkout in a
folder named `dkj-marketplace`: "no source checkout on this machine, so the register checks ... did not
run".

### CREATE

- [x] `connector-sessioncheck.ps1`: add `..\dkj-marketplace` and `..\..\DKJ-Solutions\dkj-marketplace` to
  the source-checkout candidates, ahead of the old names, which stay.

### TEST

- [x] Ran the patched hook from `dkj-lifehub`: "connector-sessioncheck: no errors." instead of the skip
  line. The suites run in `ship-pr`.

### DEPLOY: fix/3666-connector-check-finds-renamed-source

The connector session check looked for the source checkout only under the repo's old folder names, so
in a consumer beside a fresh clone named `dkj-marketplace` it reported no source checkout and skipped
the register checks without saying anything was wrong. It now finds the checkout under the new name
as well.

**Score:** 1

#### What makes this deploy extra special

A consumer session on a machine whose source checkout is named `dkj-marketplace` runs the register
checks again (consumer registration, lens inventory, agent-def drift) instead of skipping them.

**Score:** 1

#### Pull Request

The connector session check finds a source checkout named dkj-marketplace
