## feat/2352-needs-info-message-form

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

#### Scope, as decided at pickup

Inbound #2352: a consumer page carrying the `needs-info` requester message ("form B") and five
corrections to the delivered-work message was deleted, and the shared layer carried neither. Verified
against the tree: `WORKFLOW-portable.md` step 6 says what the label does to the card and prescribes no
message; the paste-ready block `build-golive-block.ps1` writes asks the requester nothing. The source
page is in a private consumer, so only the rule is carried, never its wording.

- Corrections 2, 3 and 5 (requester judges, rejection asks two things, release is not a reward) are
  what the pasted block says, so they go into `Format-GoLiveBlock` -- a doc rule the script does not
  follow would be a new inconsistency.
- Corrections 1 and 4 (provenance first, issue and task close apart) are documented; the block's first
  line already names the issue, and step 4 already closes the issue before the task.
- Form B is a judgement nothing can derive, so it is prose in step 6.
- The relayer is named as the Asana task's assignee wherever the page said "the person".

### CREATE

- [x] `Get-GoLiveBlockAsk` in `golive-block-rules.ps1`, called by `Format-GoLiveBlock`, only with a link
- [x] asserts in `dkj-policy-bwj.tests.ps1`: present with a link, after the live URLs, both rejection
      halves, "either way", absent without a link
- [x] `WORKFLOW-portable.md`: block example, the assignee as relayer, *What the block asks of the
      requester* (five rules), form B under step 6, step 7's two bullets
- [x] `report-issue` and `golive-block` skill pages point at the new sections

### TEST

- [x] `dkj-policy-bwj.tests.ps1` alone: exit 0
- [x] `open-pr.ps1 -GatesOnly`

### DEPLOY: feat/2352-needs-info-message-form

`dkj-policy-bwj` now carries the requester message for an issue sent back with `needs-info`, and the
paste-ready block asks the requester for something. Both lived only in a consumer page that was deleted
on September 23 ([#2352](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2352)).
`WORKFLOW-portable.md` step 6 makes setting the label and writing the question one act, and gives the
comment's shape. The issue stays open and the label is left for whoever brings the answer. Step 4
gains the five rules for what the block asks and names the Asana task's assignee as the one who
carries it across and closes the issue. `build-golive-block.ps1` now ends the block with that ask
whenever it is given a result link.

**Score:** 3

#### What makes this deploy extra special

Every paste-ready block a BWJ store posts after the update ends by asking the colleague who filed the
ticket to look at the result themselves. An approval ticks off the task. A rejection names what is
wrong and what should change, and the issue reopens. The release happens either way. A ticket sent
back for more information now has a prescribed question on it rather than an empty card in the
blocked column.

**Score:** 3

#### Pull Request

The needs-info requester message and the paste-ready block's ask, carried in dkj-policy-bwj

