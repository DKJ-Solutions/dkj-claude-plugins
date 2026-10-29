## docs/3661-dkj-marketplace-migration

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

Step 1 of #3660, the rename to `dkj-marketplace`: write the flag-day procedure in the docs before
anything functional changes, as #1778 did for #1769. The owner gave the go, and decided that local
checkout folders keep their name (davekokbwj, October 29, 2026, recorded on #3661). Nothing functional
changes on this branch, and no name is renamed here.

The issue names `plugins/INSTALL.md` as well, but that page was removed (5a9c004c1). The consumer
install steps now live in `plugins/ADOPTION.md`, so the procedure goes there. It is written to stay true
on both sides of the flag-day merge: it states that it applies only from the release that carries the
rename, so no step has to rewrite it on that day.

### CREATE

- [x] `plugins/ADOPTION.md`, new `### Moving to dkj-marketplace` under Consumption, in three ordered
      parts. Per consuming repo: the settings keys and `source.repo`, the absolute `@`-imports and the CI
      runners' `repository:` line. Per machine: `marketplace remove`, from a throwaway directory, after
      every consumer on that machine has merged. Per checkout: pull, restart, update, install again,
      verify the install and the imports.
- [x] Record the decision on the folder name (keep it, so the install record stays linked) and the
      `git remote set-url` line for checkouts of this repo
- [x] One line for the business mirror, which follows the name by default, so the release notes have
      to carry that migration

### TEST

- [x] Gates left to `ship-pr` (the sweep's step 4)

### DEPLOY: docs/3661-dkj-marketplace-migration

The adoption page now has the procedure for the coming rename to `dkj-marketplace`
([#3660](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3660)), in the order it has to run:
first each consuming repo's settings, imports and CI runners, then one `marketplace remove` per machine,
then a reinstall and verification in every checkout. Local checkout folders keep their name. Nothing is
renamed yet, and the procedure says it applies only from the release that carries the rename
([#3661](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3661)).

**Score:** 2

#### What makes this deploy extra special

A consumer can read ahead what the rename will ask of them, but nothing changes for them until that
release. This entry is the preview, and that release is the act.

**Score:** 2

#### Pull Request

Write the dkj-marketplace migration procedure

