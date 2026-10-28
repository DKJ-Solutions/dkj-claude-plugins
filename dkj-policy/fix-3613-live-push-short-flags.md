## fix/3613-live-push-short-flags

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

Inbound #3613: `guard-live-theme` read a live push only through `--allow-live` or the live id, so
`-l -a` and `-t <live name> -a` passed. Read the short flags after `theme push` as well.

### CREATE

- [x] `guard-live-theme.ps1`: `--live`, `-a`, `-l` and combined push clusters (`-la`) count as aimed at
  live, scanned only after `theme push` so a wrapper's `-Command` does not trip it
- [x] `guard-live-theme.tests.ps1`: the report's five rows, the short-flag variants, and the preview
  pushes that must stay allowed

### TEST

- [x] `guard-live-theme.tests.ps1` standalone: 218 passed, 0 failed

### DEPLOY: fix/3613-live-push-short-flags

The Shopify live-theme guard now also blocks a live push written with the short flags: `-a` for
`--allow-live`, `-l` or `--live` for live, and combined clusters such as `-la`. A push naming the
live theme by name is caught through the `-a` it needs. A preview push, including one wrapped in
`powershell -Command`, and every pull stay allowed (#3613).

**Score:** 3

#### What makes this deploy extra special

A Shopify consumer's live theme is guarded against `shopify theme push -l -a` and
`-t <live name> -a`, which used to pass. A session that pushes to live has to carry the authorisation
marker however it spells the flags.

**Score:** 3

#### Pull Request

guard-live-theme catches a live push written with short flags

