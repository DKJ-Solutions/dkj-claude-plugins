## fix/3401-holder-other-logon-session

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

Inbound #3401: a port holder in another Windows logon session reads back with an empty command line,
so the dev-preview line named it by bare pid with no reason. Verified in the code: the hook's process
table read no `SessionId`, and `Format-DevPreviewPortHolders` fell back to the pid whenever no name came.

### CREATE

- [x] The hook's process table carries each process's `SessionId`.
- [x] `Format-DevPreviewPortHolders` says when a holder's command line cannot be read, and names the
  other logon session where its `SessionId` differs from the hook's own.
- [x] The hub README's table of lines shows the new shape.

### TEST

- [x] `dev-preview-sessionstart.tests.ps1`: the measured case, an unreadable holder in our own session,
  the default session, and the #3378 assert updated to the new wording.

### DEPLOY: fix/3401-holder-other-logon-session

The dev-preview line now says why it can only name a port's holder by pid
([#3401](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3401)). Where the holder's command line
reads back empty, the entry reads `3000 by pid 22588 (its command line cannot be read)`, and
`(another logon session -- its command line cannot be read)` where the holder runs in another Windows logon
session of the account. Measured: the bare pid was this checkout's own product, started from another session,
and nothing in the line said where to look.

**Score:** 2

#### What makes this deploy extra special

A consumer whose dev server was started from another Windows logon session now learns that from the session
line, instead of hunting for a foreign app holding the port.

**Score:** 2

#### Pull Request

dev-preview names a holder whose command line cannot be read, and another logon session

