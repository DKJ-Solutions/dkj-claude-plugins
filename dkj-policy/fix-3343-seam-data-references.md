## fix/3343-seam-data-references

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

Issue #3343: a path with a directory in `scripts/repo-config.ps1`'s data made every suite that
dot-sources the seam depend on that file. Cause verified at `gate-lib.ps1`'s `$named` loop: a non-test
file's data reference counts when it has a directory, and repo-config.ps1 names 16 such paths (the
house-style allowlist's CSS files, `.claude/settings.json`, the changelog and others).

### CREATE

- [x] `Get-AffectedSuiteSelection`: repo-config.ps1 contributes no data reference; what it runs is still followed
- [x] the header states the third asymmetry; the plugin mirror is byte-identical again

### TEST

- [x] `affected-suites.tests.ps1`: a fixture seam naming `docs/style.css` selects only the suite that names it itself (163 pass)
- [x] the issue's reproduction on this tree: `showcase.css` matches 0 suites, down from 118

### DEPLOY: fix/3343-seam-data-references

The local test gate no longer selects most of the pool for a change to a file that
`scripts/repo-config.ps1` only names as data
([#3343](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3343)). A one-line comment in the
brand book's `showcase.css` selected 118 of 166 suites, because the house-style allowlist names that path
and nearly every suite dot-sources the seam. That cost 725s on the first ship and 447s on the re-ship.
`Get-AffectedSuiteSelection` in `scripts/lib/gate-lib.ps1` now treats every path the seam config names
as a seam value rather than a dependency. The same change now matches no suite. A change to
`repo-config.ps1` itself still runs the whole pool, and CI still runs every suite before a merge.

**Score:** 3

#### What makes this deploy extra special

A repo running `dkj-policy` takes the same selection through the mirrored `gate-lib.ps1`. A change to a
file its own `repo-config.ps1` only names, such as a stylesheet in an allowlist, no longer runs most of
its suites before `open-pr` pushes.

**Score:** 2

#### Pull Request

Gate selection: repo-config.ps1's data paths no longer select every suite that loads it

