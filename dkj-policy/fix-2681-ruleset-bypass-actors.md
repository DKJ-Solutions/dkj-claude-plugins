## fix/2681-ruleset-bypass-actors

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

Inbound [#2681](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2681): the ruleset
`adopt-ci-floor` composes has no `bypass_actors`, so every fold is refused. Reason verified against
the source's own declaration in `scripts/repo-config.ps1` (`ruleset.bypass_actor_types`: a required
status check can never be satisfied by a direct push). One actor, `RepositoryRole` 5 (repository
admin), because it is valid on a user-owned and an org-owned repo alike, where `OrganizationAdmin` is
refused on a user-owned one -- and an org owner already holds the admin role.

### CREATE

- [x] add `bypass_actors` to the composed payload, and a printed line saying why it is there
- [x] sync the plugin mirror of `adopt-ci-floor.ps1`

### TEST

- [x] `adopt-ci-floor.tests.ps1` pins the parsed actor (type, id, mode) and the explanation -- 276 passed, 0 failed

### DEPLOY: fix/2681-ruleset-bypass-actors

The paste-ready ruleset that `adopt-ci-floor` prints now carries a repository-admin bypass actor, and
says why: without one, the required check refuses the fold's direct push to the trunk, so every fold
after the next pull request was blocked
([#2681](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2681)).

**Score:** 3

#### What makes this deploy extra special

A consumer who follows Part 3 of `adopt-dkj-policy` to the letter no longer gets a trunk nothing can
fold onto. A ruleset already pasted from the old output still needs the bypass actor added by hand.

**Score:** 4

#### Pull Request

