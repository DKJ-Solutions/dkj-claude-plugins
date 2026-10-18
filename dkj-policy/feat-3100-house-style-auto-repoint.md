## feat/3100-house-style-auto-repoint

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

Inbound #3100: a dkj-brandbook release should become a repoint pull request here without a session in
between. Verified first: the repoint was hand work four times in five days, `FOLD_PUSH_TOKEN` already
holds `Contents` and `Pull requests: write` (merge-on-green), and this repo does not let the job-scoped
token create pull requests, which would start no CI anyway. The brand book publishes no list of retired
names, so the runner derives it by the rule `house-style-rules.ps1`'s header already states.

### CREATE

- [x] `scripts/lib/house-style-repoint-lib.ps1`: the pure rewrites, the safety reads and the retired-name derivation
- [x] `scripts/ci/repoint-house-style.ps1`: due-or-not, the fetch at the tag, and the rewrite, fail-closed
- [x] `.github/workflows/house-style-repoint.yml`: daily plus dispatch; one open repoint pull request, an older one closed as superseded
- [x] `check-house-style.tests.ps1` reads the pinned tag instead of hard-coding it, so a repoint's own pull request stays green
- [x] The `house-style` skill's "Changing the house style" names the runner instead of an inbound issue

### TEST

- [x] `house-style-repoint.tests.ps1` (new): 49 passed, 0 failed
- [x] `check-house-style.tests.ps1`: 61 passed, 0 failed
- [x] Replayed the v0.1.0 to v0.2.0 repoint in a worktree at 62e284c3: links, commit, checksums, retired list and both vendored copies match what #3089 did by hand

### DEPLOY: feat/3100-house-style-auto-repoint

A dkj-brandbook release now reaches this repo as a pull request within a day, opened by a scheduled
runner ([#3100](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3100)). It repoints the
`house-style` skill's links, commit and checksums, updates the retired-name list and replaces both
vendored copies; a file that fails the skill's safety reads stops it before any pull request. It never
merges: whoever ships it scores the entry. Nothing changes for a repo that uses the house style until
such a repoint is released.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

house-style: open the repoint PR automatically on a dkj-brandbook release

