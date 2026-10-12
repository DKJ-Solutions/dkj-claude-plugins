## feat/2929-ruleset-allowed-merge-methods

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

Inbound #2929. Verified: `Get-LiveValue` had no arm for the field, so a declaration of it read as
UNKNOWN. The payload shape was measured live: smartwatchbanden's branch rules carry
`pull_request.parameters.allowed_merge_methods = ["merge"]`.

### CREATE

- [x] `check-repo-settings.ps1` reads `ruleset.allowed_merge_methods` from the `pull_request` rule as a
  sorted set, and reports it unreadable when no such rule applies (the strict arm's reasoning); mirror
  resynced

### TEST

- [x] `repo-settings-gate.tests.ps1`: as declared, squash let back in, and no `pull_request` rule; 71 green

### DEPLOY: feat/2929-ruleset-allowed-merge-methods

`check-repo-settings` can now watch a ruleset's `allowed_merge_methods`
([#2929](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2929)). Declare
`ruleset.allowed_merge_methods` in the repo-settings seam and the check reads it from the trunk's
`pull_request` rule as a sorted set. A ruleset that lets squash back in then turns the check red, where
before only the repo's own merge switches could be watched. Where no `pull_request` rule applies, the
field reads as unreadable, not as an empty set. Measured at smartwatchbanden#900: a ruleset allowed
`merge,squash,rebase` while the tooling merges with `merge`.

**Score:** 2

#### What makes this deploy extra special

A repo that depends on merge commits, a store's reconciliation-base sync among them, can now have the
scheduled settings check guard the ruleset as well as the repo switches.

**Score:** 2

#### Pull Request

check-repo-settings reads a ruleset's allowed_merge_methods

