## fix/3492-live-message-is-a-notice

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

#3492 (inbound): the live message `notify-live` posts says *"the review can start now"* and repeats the
go-live block's ask, while the closed message's look-sentence already calls the preview the last moment
something can change. Verified in the tree: `Get-LiveMessageLines` and `New-LiveMessageHtml` hardcode the
line and append `$t.Ask` / `AskYes` / `AskNo`, and their docstring states the assumption. Make it a notice.
"Visible to customers" is deliberately not said: an app-only change can be owed this message too.

### CREATE

- [x] `live-message-rules.ps1`: the live line ends at the version, one fixed notice line
  (`Get-LiveMessageNoticeLine`, shared by both forms) replaces the repeated ask, and the docstrings say why
- [x] `skills/notify-live/SKILL.md`: "The message" describes the notice
- [x] `bwj-development.tests.ps1`: the notice is there, "review can start" and the block's ask are not, in
  both forms

### TEST

- [x] The gates run in `ship-pr`

### DEPLOY: fix/3492-live-message-is-a-notice

The message `notify-live` posts on an Asana task after a release no longer says the review can start, and no
longer asks the go-live block's question a second time
([#3492](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3492)). It says the work is live as that
version, and that the review already took place on the preview.

**Score:** 2

#### What makes this deploy extra special

A requester told on release day that their work is live is no longer asked to review it again. The review
already happened on the preview, and the earlier message said that was the last moment to change something.

**Score:** 3

#### Pull Request

notify-live: the live message is a notice, not a second review request

