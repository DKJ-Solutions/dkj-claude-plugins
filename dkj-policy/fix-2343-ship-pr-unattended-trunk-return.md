## fix/2343-ship-pr-unattended-trunk-return

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

#2343 checked against `ship-pr.ps1`: step 2b's return to the trunk is non-fatal, whether it declines or
fails, and with HEAD still on the branch, step 3b's forward lap takes `git fetch origin <branch>` +
`git merge --ff-only origin/<branch>`. That writes the live remote head, including anything pushed during
the CI wait, into the working tree. The merge-on-green runner is the only caller of `ship-pr` inside
GitHub Actions; no suite runs `ship-pr` past step 2b as a process, so CI's own `GITHUB_ACTIONS=true` is
unaffected.

### CREATE

- [x] `forward-lane-lib.ps1`: `Get-UnattendedTrunkReturnRefusal`, and `Get-LocalRefForwardPlan -Unattended`
      returns `refuse` where it would otherwise merge into the branch checkout.
- [x] `ship-pr.ps1`: under `GITHUB_ACTIONS`, a run that is not back on the trunk after step 2b stops
      before the CI wait, and a refused forward plan ends the run. The pull request stays armed either way.
- [x] Plugin mirrors synced; tests in `forward-lane-lib.tests.ps1`.

### TEST

- [x] `forward-lane-lib.tests.ps1` 72/0, `shared-scripts.tests.ps1` 997/0, lint 0 errors.

### DEPLOY: fix/2343-ship-pr-unattended-trunk-return

When `ship-pr` runs inside GitHub Actions, as the merge-on-green runner, it now stops before the CI wait
unless step 2b got the checkout back onto the trunk. A second layer stops the forward lap from merging the
branch's live remote head into the working tree. Together they close the residual window #2338's security
review found: code pushed during the wait could land where a `FOLD_PUSH_TOKEN` checkout runs scripts
(#2343).

**Score:** 2 -- a narrow window, two failures deep; the attended path is unchanged.

#### What makes this deploy extra special

A consumer's merge-on-green runner runs the plugin's `ship-pr.ps1`, so it picks this up with the release
without any change to its workflow. A pull request whose runner cannot reach the trunk now stays armed for
the next sweep instead of merging.

**Score:** 2 -- invisible unless a runner's trunk return fails, and then the merge waits half an hour.

#### Pull Request

ship-pr: an unattended run stops unless it is back on the trunk, so a forward lap cannot bring in an unjudged head

