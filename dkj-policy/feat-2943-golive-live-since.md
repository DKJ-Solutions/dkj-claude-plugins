## feat/2943-golive-live-since

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

Inbound #2943, verified on pickup: `Get-NextReleaseDate` is strictly after `-From`, and `Format-GoLiveBlock`
had no form for a change that is already live, so a block written after the release named the next one.
The five fixed headings stay, because `asana-closed-message` and the tests name them.

### CREATE

- [x] `Get-GoLiveBlockText`: `LiveSince`, `LiveSinceVer`, `LiveNow`, `AskLookLive` in Dutch and English
- [x] `Format-GoLiveBlock -Live` / `Get-GoLiveBlockAsk -Live`: the live-since sentence, a plain live-URL label, no last-moment sentence
- [x] `build-golive-block.ps1 -LiveSince <date>`, refusing a future day and `-From`/`-ReleaseDay` beside it
- [x] The `golive-block` skill page names the parameter

### TEST

- [x] `bwj-development.tests.ps1`: the lib's live block in both languages, and the driver through `-File` -- the date binds, a future day and `-From` beside it are refused (suite green)

### DEPLOY: feat/2943-golive-live-since

`build-golive-block` takes `-LiveSince <date>` for an issue that closes after its change went live, which is the normal case for one parked `awaiting-release`, or work pushed live on its own. The block then reads *Het staat live sinds ...* / *It has been live since ...* instead of naming the next release day. It also drops the private-window caveat on the live URLs and the "last moment before a customer sees it" line in the ask. A date after today is refused, and so is `-LiveSince` beside `-From` or `-ReleaseDay` ([#2943](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2943)).

**Score:** 2

#### What makes this deploy extra special

In a BWJ store repo, the closed message on a ticket that is already live now tells the requester it is live, and since when. Before, it told them it would go live next Monday, and #190 had to be closed with a hand-written comment instead.

**Score:** 2

#### Pull Request

golive-block -LiveSince: a block for a change that is already live

