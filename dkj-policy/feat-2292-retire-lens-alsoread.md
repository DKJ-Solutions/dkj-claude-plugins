## feat/2292-retire-lens-alsoread

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

Close #2292: every consumer is over the #2130 lens rename, so the Lens row's `AlsoRead` in
`Get-SpecialistFileShapes` empties. The condition was measured on 2026-09-28 against the remote trunks.
Five of the six consumers hold only `specialist-<g>-<id>-lens.md`. The sixth,
`DKJ-Solutions/djcylow-react`, removed its `.claude/specialists/` layer that day (`32397532`) and holds
no lens file at all. The local roll-up could only say `NOT ANSWERABLE`, because one checkout was absent
and one register record was stale (#2592). The other three kinds are out of scope and keep their rows.

### CREATE

- [x] Empty the Lens `AlsoRead` in `scripts/lib/check-report-lib.ps1` and update the banner, then copy
  the file byte-identical into its three plugin mirrors.
- [x] Record the retirement in `connectors/README.md` and in check 7's docstring in
  `scripts/sync/check-connectors.ps1`. What becomes of that check is filed as #2591.
- [x] Update the test fixtures that still wrote lenses as `<g>-<id>-extension.md`, and invert the
  assertions that pinned the old spelling as tolerated. Six suites changed. Most failures came from one
  shared fixture helper per suite that wrote every generic lens under the old name; those were
  respelled. The Lens dual-read asserts, including `connectors.tests.ps1` 14b/14e/14f, now pin the
  post-retirement behaviour and cite #2292.
- [x] Point `teardown.ps1`'s no-lib fallback lens filter at `*-lens.md`. Code review found it still
  held only the retired `*-extension.md` filter, so it would have diverged from the lib path.
  `check-consumer-drift.ps1` now reports a lens under the retired name as missing. That is intended,
  and it is what retiring the name means.

### TEST

- [x] The affected suites are green: check-report-lib, connectors, consumer-lens-paths,
  policy-drift-report, roster-sync and sync-roster, plus eight neighbouring suites that were already
  green. The full gate runs through `open-pr`.

### DEPLOY: feat/2292-retire-lens-alsoread

The lens file of a specialist has one name now: `specialist-<g>-<id>-lens.md`. The old
`<g>-<id>-extension.md` spelling that readers had tolerated since the #2130 rename is retired, which
closes [#2292](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2292). Every registered
consumer had already migrated when this was measured on September 28, 2026. The manual, persona and
subagent spellings are untouched.

**Score:** 2

#### What makes this deploy extra special

A consumer that still keeps a lens under `<g>-<id>-extension.md` will find that no check or scaffold
reads it any more, and has to `git mv` it to `specialist-<g>-<id>-lens.md`. All six registered consumers
were already over, so this reaches nobody we know of.

**Score:** 1

#### Pull Request

