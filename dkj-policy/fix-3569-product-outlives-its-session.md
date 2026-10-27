## fix/3569-product-outlives-its-session

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

Inbound #3569: a product the dev-preview hook started in one Windows logon session kept its port after that
session was disconnected, so every later session on the machine started without it. Measured cross-account,
where the later session cannot stop it without elevation.

Of the three directions the report weighs, this branch takes the first: the server's lifetime is tied to its
session. Holding the port in the first place is the defect, and a fallback port (the third) needs an OAuth
redirect registered per repo. The second direction is taken only partly: the holder's entry now names the
session and the elevated commands that free the port, for holders started before this fix. A machine-wide
claim record was left out, because the watcher removes the case it would report on.

### CREATE

- [x] `Test-DevPreviewSessionWatchable`, `Get-DevPreviewWatchStep` and `Get-DevPreviewWatchArgs` in
  `hub/lib/dev-preview-rules.ps1`: no watcher in session 0, a stop only after a full minute disconnected, and
  an unreadable state never stops anything.
- [x] `hub/pages/dev-preview-watch.ps1`: reads its own session's connect state (WTSQuerySessionInformation),
  stops the server's tree with `taskkill /T /F`, exits with the server, and refuses a pid whose start time is
  not the server's.
- [x] The hook starts a watcher beside the hub and the product it starts.
- [x] `Format-DevPreviewPortHolders`: a holder in another logon session names that session and the remedy.
- [x] `hub/README.md`: the watcher, and the new line shape.

### TEST

- [x] `scripts/tests/dev-preview-sessionstart.tests.ps1`: the rules (session 0, the grace, a reconnect, an
  unreadable state), the watcher live (stops the tree when disconnected, keeps it when active, leaves with the
  server, never stops a reused pid), and a watcher beside the hub the hook starts. 393 passed, 0 failed.
- [x] The real WTS read compiles and reads this session as active (state 0, session 42).

### DEPLOY: fix/3569-product-outlives-its-session

A server the dev-preview hook starts no longer holds its port after its Windows session is left behind. A
watcher runs beside it in the same session and stops the server's whole tree once that session has been
disconnected for a minute. It exits with the server either way, and session 0 gets none. A holder that is
still in another logon session is named with that session's number and the one elevated command that frees
the port.

**Score:** 3

#### What makes this deploy extra special

On a machine where people switch Windows accounts, or leave a session disconnected instead of signing out,
the next session no longer starts without its product. The port is free about a minute after the switch. A
session that is started sooner, or a holder from before this release, gets the exact `Stop-Process`
command instead of a bare pid.

**Score:** 3

#### Pull Request

dev-preview: a server the hook starts no longer outlives its session

