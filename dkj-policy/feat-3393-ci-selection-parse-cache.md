## feat/3393-ci-selection-parse-cache

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

#3393: shard 1 spends 59s of an asset-only PR's run on the suite selection. The issue inferred a cold
parse every run and asked for a timing first. Measured locally, October 24, 2026: 27.3s cold and 3.3s
warm, with the same answer (10 suites for a house-style.css change), so the inference stands.

A cache saved in a PR run is visible only to that PR, so the trunk has to write it.

### CREATE

- [x] `get-pr-suite-selection.ps1` warms the parse cache on a push to main, in shard 1, best-effort; the verdict stays `full`
- [x] `ci.yml`: shard 1 restores `.git/workflow-suite-refs.json` (key: hash of every `.ps1`, prefix fallback), and the trunk saves it when the key moved

### TEST

- [x] simulated trunk warm from an empty cache (24.2s), then a real asset-only selection: 3.3s
- [x] `ci-suite-selection-lib.tests.ps1`: path, order, shard and trunk-only conditions pinned (47 passed)
- [~] the CI saving itself is only measurable once main has saved its first entry, after the merge: the next asset-only PR's selection step shows it

### DEPLOY: feat/3393-ci-selection-parse-cache

CI now keeps the suite selection's parse cache between runs, so an asset-only pull request no longer
pays a cold parse of every script before its suites start
([#3393](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3393)). Every push to `main` warms
the cache and saves it, and shard 1 of a pull request restores it. Measured locally: 27.3s cold
against 3.3s warm, with the same selection. On CI the step took 59s.

**Score:** 2

#### What makes this deploy extra special

N/A: this repo's own CI, which ships in no plugin.

**Score:** N/A

#### Pull Request

CI: keep the suite selection's parse cache between runs
