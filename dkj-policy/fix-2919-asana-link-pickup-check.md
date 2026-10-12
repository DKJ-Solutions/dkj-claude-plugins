## fix/2919-asana-link-pickup-check

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

Inbound #2919, the issue's option 1 (warn at pickup). Verified: nothing on the chain calls
`Resolve-AsanaTaskRef` before the close. dkj-policy's `claim-issue` and `new-branch` are repo-agnostic
and offer no companion seam, so the check is `bwj-development`'s own: a PostToolUse hook on the shell
tools. A warning rather than a refusal, because a mention of Asana is evidence, not proof. The close side
is #2918, built in another checkout.

### CREATE

- [x] `scripts/lib/asana-pickup-rules.ps1`: the pickup number, the verdict (via `Resolve-AsanaTaskRef`)
  and the warning text, which echoes nothing of the issue's own words
- [x] `hooks/asana-link-pickupcheck.ps1`, registered PostToolUse on `Bash|PowerShell` behind a shell
  pre-gate, so PowerShell starts only when `claim-issue.ps1` or `new-branch.ps1` is named
- [x] README and report-issue name the hook

### TEST

- [x] `asana-link-pickupcheck.tests.ps1`, 34 asserts green
- [x] Live: the hook warns on #2919 (Asana named, no link) and stays silent on #2912

### DEPLOY: fix/2919-asana-link-pickup-check

`bwj-development` now warns at pickup when an issue names Asana but links no Asana task
([#2919](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2919)). After `claim-issue` or
`new-branch` picks up an issue, a new PostToolUse hook, `asana-link-pickupcheck`, reads it. Where the
title or body mentions Asana and neither a marker, a header row nor a task URL links one, it tells the
session to write both halves of the link before any work. A colleague's bug copied with a plain
`gh issue create` (xoxowildhearts#404) had run the whole chain that way, and the requester would have
heard nothing when it shipped. The hook starts PowerShell only when one of those two scripts runs.

**Score:** 2

#### What makes this deploy extra special

A colleague who reports a bug in Asana hears back when it ships, because the session is now told at
pickup when the issue it works on has lost the link to their task.

**Score:** 3

#### Pull Request

bwj-development warns at pickup when an issue from Asana links no task

