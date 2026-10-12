## feat/2945-asana-prio-label-sync

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

Inbound #2945, parked on `awaiting-decision-dev`. Dave decided October 12, 2026: the sync comes back,
triggered by an issue being opened or edited plus a daily sweep. It ships as its own copied workflow, so
`asana-closed-message` stays `issues: read` and keeps its claim that it writes no label.

### CREATE

- [x] `templates/asana-prio-label.yml` + `.ps1`: event mode (opened/edited) and sweep mode (schedule, dispatch), `issues: write`, `ASANA_PAT` only, self-contained, logic from the retired `asana-mirror.ps1`
- [x] Victor's review: a 401/403/429/5xx Asana read fails the run (404 stays a skip), sweep limit 1000 with a `::warning::` at the cap, an empty list counts 0 on PS 5.1
- [x] `closed-message-sessioncheck.ps1` checks both copied pairs; `adopt-bwj-development` copies four files
- [x] WORKFLOW-portable steps 4, 5 and 7, README and `asana-closed-message.ps1`'s header say the sync is back

### TEST

- [x] `bwj-development.tests.ps1`: bands, score lookup, label change, the copy pins, the yml shape, the no-PAT exit, the read-outcome classifier and the list parser
- [x] `closed-message-sessioncheck.tests.ps1`: a store missing only the prio pair, and a stale prio script
- [x] `template-selfcontained.tests.ps1` picks up the new template

### DEPLOY: feat/2945-asana-prio-label-sync

In `bwj-development`, the Asana `Prio-Score` -> `prio-N` label sync is back, as a second copied workflow, `asana-prio-label`. It was retired with the `asana-mirror` workflow on October 5. It runs when an issue is opened or edited and once a day over every open issue. It puts exactly one of `prio-1` to `prio-4` on the issue and leaves the labels alone when there is no readable score. A failed Asana read fails the run instead of passing green. `adopt-bwj-development` copies it into the two stores, and `closed-message-sessioncheck` reports a missing or stale copy ([#2945](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2945)).

**Score:** 3

#### What makes this deploy extra special

In a BWJ store repo, an issue linked to a scored Asana ticket gets its priority label without anybody typing it, so the backlog page ranks it again. A store takes it by re-running `adopt-bwj-development`. The session check names the two missing files until it has.

**Score:** 3

#### Pull Request

The Asana Prio-Score -> prio-N label sync is back, as its own workflow

