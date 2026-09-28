## docs/2557-audience-tier-by-purpose

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

### CREATE

- [x] One test for both audience tiers, what the repo is FOR, stated in the tier model (`RELEASES-portable.md`) with the maintainer-as-user case, and restated briefly in `CONTRIBUTING-portable.md` and `DEVELOPMENT-portable.md`
- [x] The scaffold's reader sentence (`Get-EntryAudienceDescription`) and the `Get-ReleaseAudienceTier` contract record, which `adopt-dkj-policy` puts to a repo as the question, carry the same test; mirrors synced, blueprint regenerated

### TEST

- [x] `entry-scaffold.tests.ps1` 882 asserts, `config-blueprint.tests.ps1` 219, `script-contract.tests.ps1` 401 -- all green

### DEPLOY: docs/2557-audience-tier-by-purpose

The two audience tiers now come with a test a repo can apply to itself: what the repo is **for**. A repo that is a means of selling or delivering something else answers 1. A repo that is the product its user relies on answers 2, and that user counts even when they are its own maintainer: as user they are tier 2, as developer tier 0. The same wording is in the tier model, the scaffold's reader sentence and the `Get-ReleaseAudienceTier` contract record ([#2557](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2557), answering [#2556](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2556)).

**Score:** 2

#### What makes this deploy extra special

A repo whose only user is its maintainer, such as a local single-user tool, can now see from the text that it has a tier-2 audience. Before this, every entry there honestly answered N/A for both tiers and earned a patch. Each new entry's guidance now names that reader, and the adoption question names it too.

**Score:** 3

#### Pull Request

Audience tiers: the test is what the repo is for, so a tool's own maintainer-as-user is tier 2

