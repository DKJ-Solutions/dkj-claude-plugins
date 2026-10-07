## docs/research-lands-on-the-issue

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

The owner's correction after #2879: research findings do not get a folder in the repo. They go as
one comment on the issue the research answers, so everything sits in one central place. The #2879
finding had landed as `research/shopify-store-switch/finding.md` through PR #2882, following
Rebecca's lens, which still named `research/<topic>/` as the destination.

### CREATE

- [x] Rebecca's portable manual: research lands as one comment on the issue it answers. No research
  folder, dossier file, branch or PR for a finding alone; an issue is filed first when none exists,
  and the follow-up work is filed separately
- [x] Rebecca's agent def and repo lens follow the manual (Derek posts the comment with `gh`)
- [x] Marlowe's and Chris's lenses: "research dossier" becomes "research finding"
- [x] The #2879 finding is posted as a comment on #2879, and `research/` is removed
- [x] The pending #2882 changelog entry links the comment instead of the removed file

### TEST

- [x] No `research/<topic>` destination is left in the live docs (git grep: only the manual's own
  account of the correction and a released changelog remain); the lint gate runs at open-pr

### DEPLOY: docs/research-lands-on-the-issue

Rebecca's findings now land as one comment on the issue the research answers, not as a file under
`research/<topic>/`. Her portable manual, her agent def and this repo's lenses say so. A finding
alone takes no branch and no pull request; an issue is filed first when none exists, and whatever
the research leads to is filed as a separate follow-up issue. The #2879 finding moved onto its
issue, and the `research/` folder is gone.

**Score:** 2

#### What makes this deploy extra special

A repo running the core team gets research findings on the issue that asked the question, in one
place beside the follow-ups, instead of a research folder in its tree that nobody reads again.

**Score:** 2

#### Pull Request

Research findings land as a comment on the issue, not as a file in the repo

