## docs/2368-asana-mirror-write-comment

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

Inbound #2368, verified against the tree before building: `asana-mirror.ps1` makes exactly two GitHub
writes, `gh issue edit` for the prio labels and `gh issue comment` for the paste-block backstop
(`Add-GithubIssueComment`, since 5.5.0 / #2049). Its graphql calls are read-only queries. The
permission is right; the two passages that justify it say labels only.

### CREATE

- [x] `templates/asana-mirror.yml`: the `issues: write` comment names both writes.
- [x] `WORKFLOW-portable.md` step 5: the same claim corrected, linking the step-4 backstop section.

### TEST

- [x] Lint and test gates through `ship-pr`.

### DEPLOY: docs/2368-asana-mirror-write-comment

`dkj-policy-bwj`'s `asana-mirror.yml` template and its `WORKFLOW-portable.md` step 5 said the
workflow's `issues: write` only ever edits labels. Since 5.5.0 it also posts one comment, the
paste-block backstop on a closed issue that has no paste-ready block yet. Both passages now name the two
writes ([#2368](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2368)). The permission
does not change. The failure this prevents has not happened yet: a reviewer who takes the old comment at
its word and narrows the scope to labels would break the backstop without noticing.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

asana-mirror: the issues: write rationale names both GitHub writes

