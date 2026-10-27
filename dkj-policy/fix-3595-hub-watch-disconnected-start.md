## fix/3595-hub-watch-disconnected-start

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

#3595 (Maikel, October 27, 2026): the hub on 4891 exited about two minutes after the SessionStart hook started
it, leaving no error. The issue inferred a shell teardown. Measured instead: the session the hook runs in
(session 42, this account) reads `WTSDisconnected` while Claude Code works in it, because the console is another
account's session (43). The #3569 watcher, new in v5.34.0, read that as "disconnected" and stopped the server's
tree after its 60-second grace -- which fits the timeline, and the 4896 hub that stayed up all day was started at
11:03, before v5.34.0. The repair: a disconnect counts only after the session was seen connected, so a session
disconnected from the start is not watched, while #3569's case -- a session that disconnects later -- is.

### CREATE

- [x] `dev-preview-rules.ps1`: `Get-DevPreviewWatchStep` carries `-Armed`, set by a WTSActive or WTSConnected read; a disconnected read before that starts no clock
- [x] `dev-preview-watch.ps1`: carries the armed state between polls; `-ForceState` takes a sequence of states so the live test can drive the transition
- [x] `hub/README.md`: the watcher paragraph states the rule

### TEST

- [x] `dev-preview-sessionstart.tests.ps1`: 401 passed, 0 failed -- the unit rules for the unarmed watch, and live: `0 4` stops the tree, `4` from the start keeps the server and the watcher leaves with it

### DEPLOY: fix/3595-hub-watch-disconnected-start

The hub and the product the SessionStart hook starts no longer stop about two minutes later on a machine where
Claude Code runs in a disconnected Windows session, as it does under a second account while another account
holds the console. The session watcher from v5.34.0 now counts a disconnect only after it has seen the session
connected, so it still stops a server whose session is left behind later.

**Score:** 4

#### What makes this deploy extra special

Every repo's hub stays up on a machine that switches Windows accounts, instead of going dark minutes after each session start.

**Score:** 4

#### Pull Request

A server started in an already disconnected session is not watched, so the hub no longer exits minutes after it starts

