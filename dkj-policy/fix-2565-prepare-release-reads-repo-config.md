## fix/2565-prepare-release-reads-repo-config

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

Inbound #2565 (xoxowildhearts, dkj-policy-bwj 5.9.0): `prepare-release.ps1` never dot-sources
`scripts/repo-config.ps1`, so every consumer seam reads its default.

#### The reason, verified

Measured in the tree, not taken from the report: `git log -p -S"all three warnings below"` shows
`94db2a0c` (#2509, "names an exception's type, never its message") **replaced** the line
`try { . $configPath } catch { ... }` with the first line of the comment meant to sit above it. The
StrictMode toggle around it survived, so the block read as intact. The other two warnings in that commit
were edited correctly.

### CREATE

- [x] Restore the dot-source inside the existing StrictMode-off block, in the shape `build-golive-block.ps1`
      uses (script scope, so the seam functions survive), with its warning naming the exception's **type**
      only -- the #2509 rule the lost line was being edited for. The orphaned comment is completed.

### TEST

- [x] A fixture run in `dkj-policy-bwj.tests.ps1`: a root whose `repo-config.ps1` answers
      `Get-ShopifyThemeEstateStore` and `Get-ChangelogPath` with values no default produces, and the run
      must print both. A second run with a `repo-config.ps1` that throws: the run completes, names the file,
      and never echoes the consumer's own message.
- [x] Proven both ways: the suite is 3 red against the pre-fix driver (stashed) and 493/493 green with it.

### DEPLOY: fix/2565-prepare-release-reads-repo-config

`prepare-release` reads the store's `scripts/repo-config.ps1` again (inbound
[#2565](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2565)). Since the #2509 hardening it had
dropped the dot-source, so every seam read its default: no store domain, no live theme id, the changelog
looked for at `CHANGELOG.md`, and each step then reported a plausible skip instead of a fault. A fixture run
now pins that the repo's own seams are read, and that a config which throws degrades to a warning naming
only the exception's type.

**Score:** 2

#### What makes this deploy extra special

A store running `prepare-release` on 5.9.0 got a runbook with no push command and every scoped step
skipped, in a repo that had answered every seam. After this release the skill works as documented there.

**Score:** 3

#### Pull Request

prepare-release dot-sources repo-config.ps1 again
