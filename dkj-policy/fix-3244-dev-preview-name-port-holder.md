## fix/3244-dev-preview-name-port-holder

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

Inbound #3244: with every port taken, the dev-preview line said only "taken by other processes",
although the hook had already read the process table. Cause verified at
`dev-preview-sessionstart.ps1`'s `none` branch. The issue's second half (whether the General pages
should still start there) is the owner's decision and rides on #3245, where it is commented.

### CREATE

- [x] `Get-DevPreviewHolderName` / `Format-DevPreviewPortHolders` in `hub/lib/dev-preview-rules.ps1`
- [x] the hook's `none` line names each holder by checkout (or executable) and pid

### TEST

- [x] `dev-preview-sessionstart.tests.ps1`: naming per holder kind, and the hook's real line: 201 asserts pass

### DEPLOY: fix/3244-dev-preview-name-port-holder

When every port the repo's dev server may use is taken, the session-start line now names who holds
each one (#3244): `Repo hub: not started -- port 3000 taken by other processes: 3000 by dkj-lifehub
(pid 19544).` The holder is the checkout its command line names, or else its executable, read from the
process table the hook already holds, so finding the server to stop no longer takes a netstat and a
process lookup by hand.

**Score:** 2

#### What makes this deploy extra special

An owner whose pinned port is held by another repo's server sees which one to stop in the line itself.

**Score:** 2

#### Pull Request

dev-preview: name who holds the port when the repo's server cannot start

