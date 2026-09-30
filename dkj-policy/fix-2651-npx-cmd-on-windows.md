## fix/2651-npx-cmd-on-windows

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

#2651: every wrangler command `issue-dashboard.ps1 -EmitWorker` prints fails in Windows PowerShell under
the default execution policy, because `npx` resolves to node's `npx.ps1` shim there. `npx.cmd` sits beside
it and is not subject to the policy. The issue asks whether the release-notes-page and publish-page
instructions print the same form. They do, and their `Next:` line also joins `cd` and the deploy with
`&&`, which Windows PowerShell 5.1 cannot parse at all. It is the same line and the same failure (a
printed command that cannot run in the default Windows shell), so it is repaired here too.

The repair is one conditional per script (`npx.cmd` where `$env:OS` is `Windows_NT`), not a shared
lib, because the three scripts sit in two plugins and a new lib would cross both mirror contracts for one
line. `publish-page.ps1`'s own `Invoke-BwjNpx` already runs through `cmd.exe`, so it is unaffected. Only
what a person is told to type changes.

### CREATE

- [x] `issue-dashboard.ps1` prints `$npx wrangler ...` (whoami, both secret puts, deploy), mirrored to the plugin copy
- [x] `build-release-notes-page.ps1` and `publish-page.ps1`: the `Next:` line prints on two lines with `$npx`, and publish-page's no-login refusal names `$npx` too
- [x] The three skill pages (issue-dashboard, release-notes-page, publish-page) say that Windows prints `npx.cmd`, and why

### TEST

- [x] `issue-dashboard.tests.ps1`: asserts the platform form, and on Windows that no line names bare `npx wrangler` (397 pass)
- [x] `bwj-page-publish.tests.ps1` and `release-notes-page.tests.ps1`: assert the platform form and no `&&` (114 and 167 pass)

### DEPLOY: fix/2651-npx-cmd-on-windows

On Windows, the issue dashboard, the release-notes page and the BWJ page publisher now print
`npx.cmd wrangler ...` instead of `npx wrangler ...`, so the commands they hand over run in PowerShell
under the default execution policy. The deploy step prints on its own line and is no longer joined to
`cd` with `&&`, which Windows PowerShell 5.1 rejects.

**Score:** 2

#### What makes this deploy extra special

Whoever deploys one of these pages from Windows PowerShell can paste the printed commands as they are,
where before each one failed, either as a blocked script (*"running scripts is disabled on this
system"*) or, for the joined `Next:` line, as a parse error on `&&`.

**Score:** 2

#### Pull Request

Print npx.cmd on Windows, where the default execution policy blocks npx.ps1

