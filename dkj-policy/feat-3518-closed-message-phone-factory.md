## feat/3518-closed-message-phone-factory

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

phone-factory's owner adopted `asana-closed-message` (BWJ-Development/phone-factory#15, shipped there in
#19, `ASANA_PAT` set), and `asana-prio-label` was not decided. Give each workflow its own reach in the
session check, and make the adopt skill and the pages that state the reach agree.

### CREATE

- [x] `closed-message-sessioncheck.ps1`: each workflow carries its reach; phone-factory is checked for the
  closed-message pair, `ASANA_PAT` (the line names only the workflows that repo copies) and the seam
- [x] `adopt-bwj-development` steps 1 and 3, the bwj-development README hook row and two `WORKFLOW-portable.md`
  sentences name phone-factory's reach

### TEST

- [x] `closed-message-sessioncheck.tests.ps1`: phone-factory cases (pair missing, secret line, silent when
  complete, seam, prio pair never asked); 31 passed

### DEPLOY: feat/3518-closed-message-phone-factory

`bwj-development`'s `closed-message-sessioncheck` now checks `phone-factory` too, for the
`asana-closed-message` workflow alone. That repo adopted it on October 26, 2026
(BWJ-Development/phone-factory#15), so a missing or drifted copy, a missing `ASANA_PAT` or an unstated
`Get-ResolvesExemptMatchers` is reported there at session start. `adopt-bwj-development` step 1 copies that
pair there and leaves `asana-prio-label` out, because that workflow was not decided there
([#3518](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3518)).

**Score:** 2

#### What makes this deploy extra special

phone-factory's maintainer gets the same session-start warning the two stores get when the closed message
cannot reach the Asana task. The measured case is phone-factory's own: #3's closed message failed on a missing
`ASANA_PAT`, and nothing in the session reported it.

**Score:** 2

#### Pull Request

bwj-development: extend asana-closed-message reach to phone-factory

