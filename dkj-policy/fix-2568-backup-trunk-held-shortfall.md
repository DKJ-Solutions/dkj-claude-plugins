## fix/2568-backup-trunk-held-shortfall

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

Inbound #2568: in one consumer every duplicate of live settles at 535 of 539 files, lacking the same four
templates each time, so `backup-live-theme` can never verify and `live-preflight` can never go green.
The six inbound checks all hold. The count-only code cannot name what is missing.

The pickup comment's design point was that "byte-identical in the trunk" needs live's own bytes for
paths the copy lacks. They are already in this run: the source count is a full pull of live, which
was thrown away after counting. Keeping that pull until the verdict is in answers the point without
a second pull. The comment's weaker point was that the two unexplained `blog.context.*` files are
admitted on the trunk comparison alone. That is by design. The rule is about where the rollback bytes
are, and that holds whatever Shopify's reason for dropping a file was.

A ceiling (10 missing paths) keeps trunk-identical from admitting a copy that simply stalled early.

### CREATE

- [x] `Get-ThemeFileSnapshot` (shopify-cli-lib): the pull `Get-ThemeFileCount` counts, returned as sorted theme paths; `-KeepAt` keeps it standing. `Get-ThemeFileCount` delegates to it
- [x] `Get-ThemeShortfallPaths` + `Get-ThemeShortfallVerdict` (theme-lifecycle-rules, pure): the missing paths, and accepted only when every one is `identical` to the trunk and there are at most 10
- [x] `backup-live-theme.ps1`: keeps live's pull, and on `short` after the whole wait compares each missing path's live bytes with git's stored blob at HEAD (raw or CR-stripped id, sync-rules' functions). It prints each path's state and passes as `verified WITH EXCEPTIONS` or refuses as before
- [x] `live-preflight.ps1`: the backup step's pass detail says WITH EXCEPTIONS when the backup did
- [x] theme-lifecycle skill page and `THEME-LIFECYCLE-portable.md` describe the exception; mirrors rebuilt

### TEST

- [x] `theme-lifecycle-rules.tests.ps1` standalone: 129 pass, 0 fail, including the shortfall paths, every refusing state, the ceiling, a case-only path pair, the WITH EXCEPTIONS sentinel both scripts share, and the caller's wiring
- [x] blob-id comparison checked by hand against a tracked file: stored, raw and CRLF-then-stripped ids agree; an absent path returns ''
- [~] `backup-live-theme.ps1` itself is not driven: every path reaches a real store, as its NOTES state. The consumer's next preflight is the live test

### DEPLOY: fix/2568-backup-trunk-held-shortfall

`backup-live-theme` no longer refuses a copy that is short only on files the trunk holds exactly as
live holds them. After the wait it names each path live has and the copy lacks, and compares it with
the trunk at HEAD. It passes as verified WITH EXCEPTIONS only when all of them match and there are at
most 10. Any other state still refuses, as before. (#2568)

**Score:** 3

#### What makes this deploy extra special

In a store whose duplicates Shopify always leaves a few templates short, the backup step, and with it
`live-preflight`, could never pass. They now can, path by path, and a missing file the repo cannot
restore still stops the push.

**Score:** 4

#### Pull Request

backup-live-theme: accept a short copy whose missing paths the trunk holds exactly as live does
