## docs/remove-install-uninstall

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
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Dave's decision (September 24, 2026): the two root pages go. The one thing no skill can replace -- the
install commands, which run before any plugin skill exists -- moves into `plugins/ADOPTION.md`.

### CREATE

- [x] `git rm` INSTALL.md and UNINSTALL.md
- [x] `plugins/ADOPTION.md`: new *Installing it yourself* section, and the machine half of the undo inline
- [x] Ten relative links in archived release notes pinned to the last commit that had the pages (text unchanged)
- [x] Every live link repointed (README, connectors, handbook, lens, plugin READMEs, init/teardown skills, manual)
- [x] Printed script messages repointed (bootstrap, check-connectors, check-roster-sync x2, teardown)
- [x] Both names off `ReservedRootMd` and `$consumerDocs`; blueprint rebuilt

### TEST

- [x] Lint gate green locally (0 errors, incl. dead links); suites run as the required CI check

### DEPLOY: docs/remove-install-uninstall

The root `INSTALL.md` and `UNINSTALL.md` are gone. The install commands and the machine-side removal now
live in `plugins/ADOPTION.md`, and every link, printed script message and tooling list that named either
page points there instead. The archived release notes are left as written.

**Score:** 2

#### What makes this deploy extra special

A consumer's single entry is now `plugins/ADOPTION.md`, which carries the install commands in its own
*Installing it yourself* section. The old migration walkthroughs (old plugin names, `dkj-team-*` ids, the
`specialist-` filenames) went with `INSTALL.md` and survive only in the release notes that introduced them.

**Score:** 3

#### Pull Request

Remove INSTALL.md and UNINSTALL.md

