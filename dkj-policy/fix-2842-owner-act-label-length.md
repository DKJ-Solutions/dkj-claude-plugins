## fix/2842-owner-act-label-length

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

Measured: of the ten canonical triage labels only `awaiting-owner-act` is over GitHub's limit (123
characters; `awaiting-pull` sits at exactly 100). Shorten it to the text already created on
smartwatchbanden, which keeps the suffix every sibling carries, and add the limit test #2842 asks for.

### CREATE

- [x] Shorten the description in `scripts/task/adopt-triage-labels.ps1`, its plugin mirror,
  `scripts/repo-config.ps1` and `scripts/tests/repo-config.tests.ps1`; regenerate the config blueprint
- [x] Test: every canonical label's name is at most 50 characters and its description at most 100

### TEST

- [x] `adopt-triage-labels.tests.ps1` and `repo-config.tests.ps1` green

### DEPLOY: fix/2842-owner-act-label-length

The `awaiting-owner-act` label's canonical description is now 86 characters:
`Waiting on an act only the owner performs -- parks the issue so no session picks it up`. The old
text was 123 characters, so the `gh label create` line that `adopt-triage-labels` prints failed on
every tracker with HTTP 422. A test now holds every canonical label to GitHub's limits of 50 characters
for a name and 100 for a description.

**Score:** 2

#### What makes this deploy extra special

If you adopt the triage labels, the printed command for `awaiting-owner-act` now creates the label
instead of failing. A tracker where you already created it with a text of your own is left alone.

**Score:** 2

#### Pull Request

Shorten awaiting-owner-act description to GitHub's 100-character limit

