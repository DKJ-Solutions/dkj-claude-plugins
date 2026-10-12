## fix/2918-golive-block-checks-asana-link

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

Inbound #2918, verified against the tree first: `build-golive-block.ps1` never calls
`Resolve-AsanaTaskRef`, and both `Get-GoLiveBlockLead` and the closing hint promise the closed message
unconditionally.

### CREATE

- [x] `Get-GoLiveBlockLead -AsanaLink linked|none|ambiguous` and `Format-GoLiveBlock -AsanaLink`: the lead promises "no paste needed" only on a linked issue
- [x] `build-golive-block.ps1`: the issue read (for `-OutFile`/`-Post`) moves before the block is built and resolves the body's link; `-OutFile` warns, `-Post` refuses (`-Force` for GitHub-only), and the closing hint follows the link state
- [x] Skill page, WORKFLOW-portable and the script header describe the check

### TEST

- [x] `bwj-development.tests.ps1`: unit asserts on the three leads, plus end to end through the stand-in `gh` (unlinked `-Post` refused, `-Force` past it, unlinked and linked `-OutFile` leads), 404/404 green

### DEPLOY: fix/2918-golive-block-checks-asana-link

`build-golive-block` now checks the issue's Asana link before it promises anything. It uses
`Resolve-AsanaTaskRef`, the matcher `asana-closed-message` uses. The issue body may link no task, or
more than one. Then the lead no longer says *"no paste needed"* and `-OutFile` warns. `-Post` refuses
until the `<!-- asana-task: <gid> -->` marker is added, and `-Force` covers an issue that is
GitHub-only. A print-only run still reads nothing
([#2918](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2918)).

**Score:** 2

#### What makes this deploy extra special

A store team no longer tells a requester "no paste needed" on an issue whose close reaches nobody.
Measured on xoxowildhearts#404: an Asana-filed bug, unlinked, got that promise, and its reporter would
have heard nothing when it shipped.

**Score:** 3

#### Pull Request

build-golive-block checks the issue links an Asana task before promising the closed message carries the block

