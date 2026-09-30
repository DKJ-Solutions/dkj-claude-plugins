## fix/2644-shared-stray-token-finder

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

One shared stray path-token finder for the release-notes page and the issue dashboard, which each carried a copy differing only in the file name.

### CREATE

- [x] Verified the reason in the tree: `Find-StrayPathToken` (build-release-notes-page.ps1) and
  `Find-StrayDashboardToken` (issue-dashboard.ps1) were the same walk with a different `-Filter`.
- [x] New `scripts/lib/stray-token-lib.ps1` with `Find-StrayToken -Root -ExpectedPath -FileName`,
  carrying the #1444 reasoning once; registered as a `LibOnly` pair and mirrored into dkj-policy.
- [x] Both scripts dot-source it and pass their own token file name; both local copies removed.
- [x] Plugin mirrors synced; a row for the lib in the dkj-policy scripts README.

### TEST

- [x] The existing stray-token asserts in both suites cover the refactor unchanged:
  `release-notes-page.tests.ps1` 165/165, `issue-dashboard.tests.ps1` 328/328,
  `shared-scripts.tests.ps1` 1131/1131; `check-plugin-integrity.ps1` 0 errors.

### DEPLOY: fix/2644-shared-stray-token-finder

The release-notes page and the issue dashboard now share one stray path-token finder
([#2644](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2644)), and neither script behaves
differently. The failure it prevents has not happened yet: a repair to the orphaned-token guard (#1444)
landing in one script and not the other.

**Score:** 1

#### What makes this deploy extra special

N/A -- nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

One shared stray path-token finder for the release-notes page and the issue dashboard
