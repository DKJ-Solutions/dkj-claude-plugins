## fix/3431-release-notes-page-ignored

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

#3431 (inbound): the hub builds the release-notes page into `<note root>/../page/` in every consumer
(#3189), while the ignore line for that directory reached only consumers that read the
`release-notes-page` skill. Of the issue's options this takes none of the three: the build script writes a
`*` `.gitignore` into the page directory itself, which needs no adopt step, no warning and no session
check, and reaches every builder (the hub and a manual run alike).

### CREATE

- [x] `build-release-notes-page.ps1` (plugin and repo mirror): write `page/.gitignore` with `*` when absent
- [x] `release-notes-page` skill: the directory ignores itself, instead of "add it to your `.gitignore`"
- [x] `release-notes-page.tests.ps1`: the file is written, holds `*`, and an existing one is left alone

### TEST

- [x] `release-notes-page.tests.ps1`: 180 passed

### DEPLOY: fix/3431-release-notes-page-ignored

The release-notes page directory (`dkj-policy/releases/page/`) now ignores itself: the build writes a
`.gitignore` holding `*` into it when there is none. A repo whose hub built the page no longer finds it as
an untracked folder after every session, and a `git add -A` can no longer commit it, whether or not that
repo ever added the line to its own `.gitignore`.

**Score:** 3

#### What makes this deploy extra special

Nothing to do: a repo that already ignores the directory keeps working, and the new file is ignored by
itself. An existing `page/.gitignore` is never overwritten.

**Score:** N/A

#### Pull Request

The release-notes page directory ignores itself

