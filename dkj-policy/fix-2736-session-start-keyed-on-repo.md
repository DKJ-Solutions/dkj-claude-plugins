## fix/2736-session-start-keyed-on-repo

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

Inbound #2736 from `smartwatchbanden`: the lookup key of `/measure-session-start` was the fixed title
`Sessiestart-context`. An account that runs the skill in a second repo finds the first repo's page,
and following steps 2 to 7 literally computes deltas across two trees and republishes over the first
repo's history. I checked the reason against the tree before repairing: `pageTitle` is pinned to that
value in the skill page and the schema table, and neither the script nor the data carried a repo.

Repair along the reporter's suggested direction:

- collect writes `repo`, read from the origin URL with the folder leaf as fallback (a worktree lane's
  folder is not the repo's name), and `pageTitle` = `Sessiestart-context · <repo>`
- `-ExtractPrevious` and `-Render` read a previous page only when its data names that same repo. A page
  naming another repo, or none (every page rendered before this change), yields no history and an
  `[ERROR]` saying whose it is
- the skill page looks up by the new title and leaves a bare `Sessiestart-context` page alone

**Deliberate consequence:** the source repo's existing four-measurement page names no repo, so its next
run starts a fresh page under the new title. That page cannot be told apart from another repo's
without reading its prose, and reading prose is exactly what step 3 forbids.

### CREATE

- [x] `session-start-lib.ps1`: `ConvertTo-SessionStartRepoName`, `Get-SessionStartRepoName`,
  `Get-SessionStartPageTitle`, `Test-SessionStartPreviousRepo`
- [x] `measure-session-start.ps1`: collect writes `repo` and `pageTitle`; extract and render apply the
  repo check; the repo-root resolution is shared between the three modes
- [x] Plugin mirrors synced byte for byte
- [x] `SKILL.md`: step 2's lookup, step 7, the schema table and the `-Previous` row

### TEST

- [x] `measure-session-start.tests.ps1`: 219 passed, 0 failed. New asserts cover the repo-name parsing
  (https, scp-style, trailing slash, folder fallback, nothing usable), the title, the check itself
  (same repo, another repo, case, no repo, no current name), render against another repo's page and
  against a legacy page, and extract on the #2736 case itself
- [x] Code review (Victor) on the diff

### DEPLOY: fix/2736-session-start-keyed-on-repo

`/measure-session-start` now keeps one page per repo: `Sessiestart-context · <repo>`. Running it in a
second repo no longer finds the first repo's page, and no longer computes deltas between two different
trees or republishes over another repo's history. A previous page whose data names another repo, or no
repo at all, is refused as history with an `[ERROR]` that says whose page it is. Pages published before
this change name no repo, so the next run in each repo starts a fresh page and leaves the old one alone.

**Score:** 3

#### What makes this deploy extra special

The repo key travels inside the page's own data, not only in its title. A title can be matched by
mistake, but the data block decides, so the guard holds even when a session picks the wrong artifact.

**Score:** 2

#### Pull Request

measure-session-start: key the published page on the repo, so a second repo never reads or overwrites the first one's history
