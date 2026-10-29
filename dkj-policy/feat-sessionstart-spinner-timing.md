## feat/sessionstart-spinner-timing

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

The owner asked for a loading screen while a session starts after `/clear` or `claude`. A hook does not
own the terminal (the harness renders it, and a hook's stdout is captured), so a real progress screen is
not possible. What the harness offers is `statusMessage` on a hook entry ("Custom status message to
display in spinner while hook runs", read from the Claude Code binary's hook schema). The owner chose
spinner text plus a measured duration line, with any decoupling of the slow steps decided afterwards
from the numbers.

### CREATE

- [x] `statusMessage` on the four SessionStart entries of the enabled plugins (dkj-policy's dispatcher and dev-preview, the core team's roster check, dkj-solutions' house-style check)
- [x] `sessioncheck-dispatch.ps1`: time each prep step and each check, and end the systemMessage with one `sessionstart:` line; never in additionalContext
- [x] An otherwise silent start no longer writes an empty hookSpecificOutput

### TEST

- [x] `sessioncheck-dispatch.tests.ps1`: the asserts that pinned the old systemMessage reworked; timing line, prep naming, the statusMessage on the entry and the context staying clean asserted (56 green)
- [x] Measured on this repo: `sessionstart: 5.9 s in the dispatcher -- prep 0.5 s (trunk-sync), checks 5.4 s (slowest: connector 5.0 s, release-freshness 1.1 s, consumer-prose 0.2 s)`
- [~] Seeing the spinner during SessionStart -- not testable from this tree: a session runs the installed copy, so the owner sees it after the release

### DEPLOY: feat/sessionstart-spinner-timing

A session start now says what it is waiting on and how long it took. Every SessionStart hook of the
enabled plugins carries a `statusMessage`, so the spinner names the step, and the session-check
dispatcher ends its message with one line such as `sessionstart: 5.9 s in the dispatcher -- prep 0.5 s
(trunk-sync), checks 5.4 s (slowest: connector 5.0 s, ...)`. The line goes to the person only, never into
the model's context. The first measurement already names the slow step: the connector check.

**Score:** 3

#### What makes this deploy extra special

Whoever runs these plugins now sees a named spinner while a session starts and a measured duration once
it has, instead of a silent pause.

**Score:** 3

#### Pull Request

SessionStart shows a spinner message and reports how long it took

