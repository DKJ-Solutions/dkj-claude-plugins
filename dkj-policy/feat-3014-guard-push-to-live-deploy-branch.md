## feat/3014-guard-push-to-live-deploy-branch

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

#### The decision

#3014 asked whether `guard-live-theme` should also gate `git push` / `gh pr merge` aimed at a
Git-connected live theme's deploy branch. Maikel decided (October 15, 2026, following the specialist's
advice, recorded on the issue): gate the direct push only. The deploy ruleset already requires a PR, so
`gh pr merge` stays ungated; the push that goes around the PR needs the live-push marker.

### CREATE

- [x] `hooks/guard-live-theme.ps1`: read `Get-ShopifyLiveDeployBranch`; rule 5 refuses a `git push`
      whose refspec targets that branch, `--all`/`--mirror`, or no refspec while it is checked out (or
      when that cannot be told), unless the live-push marker is on the command. Degraded mode refuses
      any `git push` while the seam is answered.
- [x] `scripts/tests/guard-live-theme.tests.ps1`: rule 5 group -- blocked, allowed, HEAD-based,
      unanswered/placeholder seam, marker narrowing, refusal text, degraded mode.
- [x] Docs: the shopify README's rules table and seam row, `WORKFLOW-portable.md`'s Git-connected
      go-live passage.

### TEST

- [x] Review (Victor, Sebastian, Edith): wrapper-led git (`& git`, `env git`), glob and shell-expanded
      refspecs, inner quotes, `heads/<branch>`, abbreviated `--mirror`/`--all`, `@`, a `-c alias.`, and HEAD
      read from the payload's cwd -- all repaired and pinned; prose findings applied.
- [x] `guard-live-theme.tests.ps1`: 203 passed, 0 failed.
- [x] The full gate through `open-pr` (run by ship-pr; a red gate stops it before the push).

### DEPLOY: feat/3014-guard-push-to-live-deploy-branch

`guard-live-theme` now holds a Git-connected live theme too. Where `Get-ShopifyLiveDeployBranch` names the branch the live theme deploys from, a `git push` to that branch is refused unless it carries the live-push marker: a refspec whose destination is the branch, `--all`, `--branches` or `--mirror`, a glob or a refspec the shell still expands, or a push with no refspec while that branch is checked out or when that cannot be told. `gh pr merge` is deliberately not gated, because the deploy ruleset already requires the promotion PR; the push is what goes around it. Without the seam nothing changes ([#3014](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3014), part of [#2998](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2998)).

**Score:** 2

#### What makes this deploy extra special

A store whose live theme deploys from a branch no longer has its ruleset as the only rail: a session whose credentials carry a ruleset bypass can no longer push straight to live without the marker. A store on the CLI push sees no difference.

**Score:** 2

#### Pull Request

guard-live-theme: refuse a git push to a Git-connected live theme's deploy branch
