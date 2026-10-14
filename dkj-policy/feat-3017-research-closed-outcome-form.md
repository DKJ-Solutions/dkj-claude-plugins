## feat/3017-research-closed-outcome-form

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

The research closed message (#3004) takes Maikel's general form from the smartwatchbanden#944
reference story (#3017): the lead "is now closed: the Asana task is ready for review. Read the outcome
below.", the heading OUTCOME with bullets, and the closing ask naming the board's own done section,
derived from `Get-AsanaStageMap`'s `Completed` code rather than a fixed `'4. Done'`.

Verified before building: the #3004 wording is what ships (`Get-ClosedMessageTail`,
`Get-GoLiveBlockText`), and both stores' maps answer `Completed = '4'`, which is `4. Done` on their
boards -- the reference story's own section.

### CREATE

- [x] `golive-block-rules.ps1`: the research closed line, the fixed English OUTCOME heading, bullets
  (`ConvertTo-GoLiveOutcomeBullets`), and `[outcome]` with `[found]` still read
- [x] `build-golive-block.ps1` and the close-guard hook name `[outcome]`
- [x] `asana-closed-message.ps1`: the new lead, the outcome as a `<ul>` (`ConvertTo-AsanaStoryHtml -Lists`),
  and the closing ask (`Get-ClosedMessageAsk`), its done section from the repo's stage map read as text
  (`Get-RepoStageCode`) and the task's board sections (`Resolve-DoneSectionName`), naming none when
  either does not answer
- [x] `golive-block` skill page and `WORKFLOW-portable.md` describe the new form

### TEST

- [x] `bwj-development.tests.ps1`: 649 asserts pass, the research block, the HTML message, the stage-code
  parse, the section match and the end-to-end run with two board reads among them
- [x] `guard-stale-paste-block.tests.ps1`: 116 asserts pass
- [x] `Get-RepoStageCode` against the real smartwatchbanden and xoxowildhearts configs: both `4`

### DEPLOY: feat/3017-research-closed-outcome-form

The research closed message now takes the general form Maikel set on a reference story. It opens with
*"is now **closed**: the Asana task is ready for review. Read the outcome below."*, lists the outcome
as bullets under *OUTCOME*, and ends with *"Is anything still unclear? Leave a comment on this task. No
more questions? Move the task to '4. Done' and mark it as complete."* The done section is the board's
own name: the code `Get-AsanaStageMap` gives the `Completed` stage, matched against the sections of the
task's board. Where that does not resolve, the ask names no section. Every fixed line is English on
every board. The prose section is now `[outcome]`; `[found]` is still read
([#3017](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3017)).

**Score:** 2

#### What makes this deploy extra special

A requester of a research, test or decision ticket reads a message that fits any ticket and tells
them how to finish it. The store's copy of `asana-closed-message.ps1` has to be taken again;
`closed-message-sessioncheck` reports the difference at session start.

**Score:** 2

#### Pull Request

asana-closed-message: the research close takes Maikel's general form (OUTCOME, the closing ask)

Plugins: bwj-development

