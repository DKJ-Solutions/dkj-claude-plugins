## fix/2338-merge-on-green-trunk-code

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

#2338 checked against the tree: both runners check out the armed head with `FOLD_PUSH_TOKEN` in the
workspace and then run code from it. The source runner runs the branch's own `ship-pr.ps1` and libs,
and in every repo `ship-pr` dot-sources the branch's `scripts/repo-config.ps1`. The requester chose the
picker-side repair over running trunk tooling: a PR that changes what the ship runs is left to a session.

### CREATE

- [x] `merge-on-green-lib.ps1`: `Get-MergeOnGreenExecutedPathHit`, and the verdict refuses a diff touching
      `scripts/`, `.github/`, `.workflow-scripts/` or `plugins/**/scripts/`. It fails closed on a missing
      file list or one shorter than `changedFiles`, and a pushed path is printed with its control
      characters replaced.
- [x] `pick-merge-on-green.ps1`: asks for `files,changedFiles,headRefOid`, refuses without a readable
      head SHA, and emits `sha`.
- [x] Both runners (`merge-on-green.yml` and `adopt-ci-floor.ps1`'s template) refuse to run `ship-pr`
      unless `HEAD` after the checkout is the picked SHA.
- [x] Plugin mirrors synced; tests in `merge-on-green-lib.tests.ps1` and `adopt-ci-floor.tests.ps1`.

### TEST

- [x] `merge-on-green-lib.tests.ps1` 74/0, `adopt-ci-floor.tests.ps1` 206/0, `shared-scripts.tests.ps1` 997/0.
- [x] Live `gh pr list --json files,changedFiles,headRefOid` returns all three fields.
- [x] Security review (Sebastian): closes the path for the ordinary runner shape. His residual finding, a
      failed step-2b trunk return letting step 3b fast-forward to an unjudged head, is filed as #2343.

### DEPLOY: fix/2338-merge-on-green-trunk-code

The merge-on-green runner checked out an armed pull request's head with `FOLD_PUSH_TOKEN` in the workspace
and then ran code from that checkout, so being able to push a branch meant being able to run code with a
token that bypasses the trunk ruleset. The picker now refuses a pull request whose diff touches code the
runner executes, and the runner refuses any checkout other than the commit the picker judged (#2338).

**Score:** 3 -- closes a privilege widening on the one runner that holds the standing write token; a
pull request touching scripts now ships from a session instead.

#### What makes this deploy extra special

A consumer's scaffolded `merge-on-green.yml` ran the plugin's `ship-pr.ps1`, and that dot-sourced the
branch's `scripts/repo-config.ps1` with the consumer's `FOLD_PUSH_TOKEN` in place. The picker fix reaches
them as soon as their runner checks out the source's `main`. The SHA pin reaches them when
`adopt-ci-floor` reports their runner as drifted and they re-apply it.

**Score:** 3 -- a security fix to a runner consumers adopted; those who use merge-on-green will see
script-touching pull requests left for a session.

#### Pull Request

merge-on-green: never run code from an armed branch that changes what the ship executes

