## feat/stopwatch-prepare-card

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

Owner's ask (Maikel, 2026-10-28): prepare a Stopwatch card for a label ahead of time (e.g. 'release cut'), so the owner then starts the run themselves with a 'stopwatch:' prompt. Visible result: park for the owner's look, do not merge.

### CREATE

- [x] Store: a `prepared` list (label, preparedAt) read and written by the Stopwatch store, labels normalised like a prompt's.
- [x] Overview and label page: a "Ready, not started" card and page for a prepared label with no run; a label with runs keeps its normal card.
- [x] Hooks: the marked prompt removes the matching prepared entry; every writer of the store keeps the rest.
- [x] New `stopwatch-prepare` skill and script (prepare, `-Remove`), registered in the hub README.

### TEST

- [x] `stopwatch.tests.ps1` and `stopwatch-sync.tests.ps1` green, with new tests for the prepared label.
- [x] `check-plugin-integrity.ps1`: 0 errors.
- [~] Owner's look at the card on `/stopwatch`: the branch is parked for it, not merged (visible result).

### DEPLOY: feat/stopwatch-prepare-card

The hub's Stopwatch page can now show a card for a label before any run of it exists, with no clock running. A new `stopwatch-prepare` skill (`-Label "release cut"`, `-Remove` to withdraw) puts the label in this machine's Stopwatch store; the `/stopwatch` overview then shows a "Ready, not started" card that tells the reader to send a prompt whose first line is `stopwatch: <label>`, and the label's page opens with the same message. Nothing else changes about how a run starts: it still begins only with that prompt, lands on the prepared card, and the prepared entry is removed. A prepared label is kept on this machine and is not shared with other machines. Older stores read unchanged.

**Score:** 2

#### What makes this deploy extra special

Nobody has to change anything to take it, and no store needs migrating, but every dkj-policy user gets a new skill and a new kind of card on their hub, so it is a feature the user can notice and choose to use, not a pure internal change.

**Score:** 2

#### Pull Request

a Stopwatch card can be prepared before its first run starts

