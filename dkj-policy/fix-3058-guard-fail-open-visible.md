## fix/3058-guard-fail-open-visible

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

Inbound #3058, measured in BWJ-Development/smartwatchbanden#946: every fail-open path of
`guard-stale-paste-block.ps1` wrote its warning to stderr and exited 0, and Claude Code shows the model
no stderr from a hook that exits 0 (confirmed in the hooks reference). The issue proposed `ask` or at
least `additionalContext`. This branch does both, split by backstop: a **close** has none that can still
stop it, so an unchecked close asks a person; a **ship** has the workflow's own check at the close, so it
only informs.

### CREATE

- [x] `Add-NotChecked` collects every fail-open warning (still on stderr too); `Exit-Allow` prints
  PreToolUse JSON with `additionalContext`, plus `permissionDecision: "ask"` where a close went unchecked
- [x] a close only *mentioned* in the command does not ask once the payload has parsed; before the parse,
  the pre-gate's match decides
- [x] header docstring and the bwj-development README row say the new behaviour

### TEST

- [x] `guard-stale-paste-block.tests.ps1` (127 pass): a checked pass prints nothing on stdout; a ship's
  fail-open informs without asking; a mentioned close beside a ship does not ask; an unchecked close asks
  with the issue named in the reason; an unparseable payload and an unresolved repo are said to the model

### DEPLOY: fix/3058-guard-fail-open-visible

`guard-stale-paste-block` now tells the session when it let a command through unchecked
([#3058](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3058)). Each fail-open path used to
write its warning to stderr and exit 0, which Claude Code never shows the model, so a close with no go-live
block went through in smartwatchbanden#946 and nothing in the session said the check had been skipped.
The hook now prints PreToolUse JSON whenever something was not checked: `additionalContext` for the model,
and `permissionDecision: "ask"` when the unchecked command is a `gh issue close`, because a close has no
later check that can still stop it.

**Score:** 3

#### What makes this deploy extra special

In a store repo running `bwj-development`, a hand close of an Asana-linked issue that the guard could not
check now stops at a permission prompt that names the issue, instead of quietly posting the bare closed
line to the Asana task. A ship the guard could not check still runs, and the session is now told so.

**Score:** 3

#### Pull Request

guard-stale-paste-block makes a fail-open visible to the session

