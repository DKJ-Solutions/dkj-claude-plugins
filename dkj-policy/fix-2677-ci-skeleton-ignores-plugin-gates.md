## fix/2677-ci-skeleton-ignores-plugin-gates

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

Inbound #2677, verified against the tree: `adopt-ci-floor.ps1` offered its CI skeleton only when no
workflow triggered on `pull_request`, and Part 1 (`adopt-workflow-folder.ps1`) places two that do --
`branch-entry.yml` and `always-on-budget.yml`, each a bare `uses:` call into this plugin's source.
Repair as proposed: recognise those callers and leave them out of the skeleton test and the
candidate checks.

### CREATE

- [x] `Get-WorkflowFacts` records `PluginGate`: a job-level `uses:` into the source repo (current or
      retired name) with no `steps:`/`runs-on:` of its own, so a mixed file stays the consumer's
- [x] The skeleton test, the ruleset auto-fill and the candidate list read `$repoPrWorkflows`
      (pull_request workflows minus plugin gates); the generated `ci.yml` header and the console line say so
- [x] Plugin mirror `plugins/dkj-policy/scripts/task/adopt-ci-floor.ps1` synced

### TEST

- [x] `adopt-ci-floor.tests.ps1` 9d2: a tree holding only Part 1's two gates still gets the skeleton
      offered, the ruleset pre-filled with `ci`, neither gate listed as a candidate, and `-Apply` places
      `ci.yml`; 9d3: a workflow mixing a plugin call with its own job still counts -- 277 passed, 0 failed

### DEPLOY: fix/2677-ci-skeleton-ignores-plugin-gates

`adopt-ci-floor` no longer counts the plugin's own pull-request gates (`branch-entry`,
`always-on-budget`) as the repo's CI. Measured in a consumer (#2677): running Part 1 before Part 3,
the documented order, suppressed the `ci.yml` skeleton and left only those two pull-request-only gates
as candidate checks, so no check could be made required. Part 3 now offers the skeleton and pre-fills
the ruleset with `ci` whichever order the parts ran in.

**Score:** 2

#### What makes this deploy extra special

A maintainer adopting dkj-policy in a new repo now gets a CI workflow to require from Part 3 even after
running Part 1 first, instead of a ruleset naming a check that never runs.

**Score:** 3

#### Pull Request

adopt-ci-floor: the plugin's own PR gates no longer suppress the CI skeleton

