## feat/2902-not-planned-on-hold-message

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

Inbound #2902: a ticket parked while waiting on its requester is closed as not planned with
`awaiting-more-info` kept on (the sanctioned pair, #2732), and `asana-closed-message` told the task
nothing. Not planned alone also means a rejection, so the label is what selects the new message.

### CREATE

- [x] `Get-ClosedMessageDecision` returns a `Kind`; not planned + `awaiting-more-info` is `on-hold`
- [x] `New-OnHoldMessage` / `New-OnHoldMessageHtml`, posted with no go-live block
- [x] The workflow template passes `ISSUE_LABELS` as `toJSON` of the label names (a name may hold a comma -- code review)
- [x] Docs: the template header, WORKFLOW-portable.md, README, golive-block, report-issue, adopt-bwj-development, and the sessioncheck hook's wording (copy edit: the "two messages" count)

### TEST

- [x] `bwj-development.tests.ps1`: the decision, the label split, the on-hold HTML and the yml hand-off (368 asserts green); closed-message-sessioncheck green

### DEPLOY: feat/2902-not-planned-on-hold-message

`bwj-development`'s `asana-closed-message` template gains a third message. `Get-ClosedMessageDecision`
now returns which message a run posts, and a close as not planned that still carries `awaiting-more-info`
is the on-hold message. The workflow template passes the issue's labels to the script for that. The
docs that said a not-planned close always posts nothing now say when it does not.

**Score:** 2

#### What makes this deploy extra special

A BWJ store's `asana-closed-message` workflow now tells the Asana task that an issue is **on hold** when
it is closed as not planned with the `awaiting-more-info` label kept on. Until now that close posted
nothing, so a session that wanted the requester to hear about it had to close the issue as completed,
and the task then read *"is now closed"* while a question was still open. A close as not planned without
the label, or as a duplicate, still posts nothing. The workflow and its script are taken together at the
re-adopt; a new script under an old workflow gets no labels and stays silent as before.
Requested in [#2902](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2902).

**Score:** 2

#### Pull Request

asana-closed-message posts an on-hold message on a not-planned close while waiting for info
