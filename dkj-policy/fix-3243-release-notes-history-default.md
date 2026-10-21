## fix/3243-release-notes-history-default

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

#3243: `build-release-notes-page.ps1` kept its own literal `releases/README.md` as the fallback for an
unanswered `Get-ReleaseHistoryPath`, while the cut writes to the computed default. The issue's side
remark about `NoteRoot` does not stand: `cut-release.ps1` keeps `releases/notes` as that seam's default
on purpose (line 578), so the two agree there.

### CREATE

- [x] The builder dot-sources `seam-lib.ps1` and falls back to `Get-DefaultReleaseHistoryPath`, in the
  source and its plugin mirror.
- [x] A fixture with no history seam and its history at `dkj-policy/releases/history.md` (case 10b).

### TEST

- [x] `release-notes-page.tests.ps1`: 177 passed, 0 failed.

### DEPLOY: fix/3243-release-notes-history-default

The release-notes page builder now finds the release history where the cut writes it (#3243). In a repo
that leaves `Get-ReleaseHistoryPath` unanswered, `build-release-notes-page.ps1` looked for
`releases/README.md`, the pre-#885 default, while `cut-release.ps1` wrote the history to
`dkj-policy/releases/history.md`, so the build refused and the general pages server's `/release-notes`
returned 404. It now resolves the same computed default the cut uses.

**Score:** 3

#### What makes this deploy extra special

A consumer that follows the default gets its release-notes page after this release; the workaround of
answering `Get-ReleaseHistoryPath` in `scripts/repo-config.ps1` can stay or go.

**Score:** 3

#### Pull Request

build-release-notes-page: fall back to the computed release-history default

