## fix/3473-drop-local-timing-hooks

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

#3473 was parked `awaiting-release` until a release shipping #3470's plugin-level Stopwatch and Logbook hooks was
installed here. v5.32.0 is installed (release-freshness session check: CURRENT) and its `hooks/hooks.json` wires
both hooks on `UserPromptSubmit` and `Stop`, so the label was stale and has been removed.

### CREATE

- [x] Remove the `hooks` block (two `UserPromptSubmit`, two `Stop` entries) from `.claude/settings.json`; keep the
      `DKJ_STOPWATCH_SHARE` env entry, which the plugin's hooks read too.
- [x] Drop the "until then in the source repo's .claude/settings.json alone" clause from both hook headers.

### TEST

- [x] `.claude/settings.json` still parses as JSON, and nothing else in it changed.
- [x] The installed v5.32.0 `hooks/hooks.json` carries both hooks on both events, so this repo's runs stay recorded.

### DEPLOY: fix/3473-drop-local-timing-hooks

This repo no longer wires the Stopwatch and Logbook hooks itself in `.claude/settings.json`
([#3473](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3473)). The installed release ships them in
`dkj-policy`'s own `hooks/hooks.json` since #3470, so each prompt and each turn's end ran both hooks twice; the
second copy was a no-op under the store's mutex and cost two extra PowerShell processes per event.

**Score:** 1

#### What makes this deploy extra special

A change to this repo's own harness config; it reaches no reader who takes the next version.

**Score:** N/A

#### Pull Request

Drop this repo's own Stopwatch and Logbook hook wiring

