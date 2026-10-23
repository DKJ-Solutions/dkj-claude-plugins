## fix/3353-release-build-held-files

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

Issue #3353: the brandbook release build's `npm ci` failed with EPERM on the `esbuild.exe` the product dev
server runs from `brandbook/node_modules` -- after the full gate. Refuse up front instead (the issue's first
direction): probe the build folder's executables and native modules with a write-open before the gates.

### CREATE

- [x] `cut-release.ps1` (and its plugin mirror): a held `*.exe`/`*.dll`/`*.node` in a release build's folder refuses the cut before the lint gate, naming the file and the folder.
- [x] `cut-release-drive.tests.ps1`: a copied `ping.exe` running from the fixture build's ignored output is refused before the gates, with nothing written.
- [x] `brandbook/README.md`: stop the dev server before a cut.

### TEST

- [x] `cut-release-drive.tests.ps1` alone: 119 of 119 asserts pass.

### DEPLOY: fix/3353-release-build-held-files

`cut-release.ps1` now refuses a cut **before its gates** when a running process has loaded an executable or
native module inside a release build's folder, which is what a dev server running from `brandbook/` does.
The build's `npm ci` cannot replace such a file, and until now the cut only found that out after the whole
~11-minute gate ([#3353](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3353)). The refusal names
the file and the folder. The probe is a write-open on `*.exe`, `*.dll` and `*.node` rather than a process
scan, because a process's image path can come back in 8.3 form and a `.node` module is loaded into
`node.exe`, which lives elsewhere.

**Score:** 3

#### What makes this deploy extra special

N/A: a consumer names no release build by default, so its cut is unchanged.

**Score:** N/A

#### Pull Request

cut-release: refuse before the gates when a running process holds a release build's files

