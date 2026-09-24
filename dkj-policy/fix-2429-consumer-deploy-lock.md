## fix/2429-consumer-deploy-lock

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

#2429: the consumer's branch-entry runner passes no `-Pr`, so a consumer PR merged from the GitHub UI
after its DEPLOY section was edited meets no lock. Waited for #2432 (#2422) to merge, since it rewrote
every file this touches (the owner's call, 2026-09-24). The constraint that shapes the design: a called
workflow that declares a scope its caller did not grant fails to start, so the runner must not declare
`pull-requests: read` itself, or every caller placed before this change goes red.

### CREATE

- [x] `reusable-branch-entry.yml`: passes `-Pr`, `GH_TOKEN`, `GH_REPO`; declares no `permissions:`, so it
  inherits the caller's grant (an old caller gets the script's own `[INFO]`, not a red check)
- [x] the caller Part 1 places (both copies of `adopt-workflow-folder.ps1`): `pull-requests: read` and the
  `edited` trigger type
- [x] `adopt-dkj-policy` SKILL.md: what the lock needs from a caller, and how an older caller takes it
- [x] security review (advisory, taken): with no cap in the runner, a caller must keep its own
  `permissions:` block -- stated in the runner's header and on the skill page; code review: no findings

### TEST

- [x] `adopt-workflow-folder.tests.ps1`: four asserts over both hops -- 115 pass, 0 fail

### DEPLOY: fix/2429-consumer-deploy-lock

The branch-entry gate that `adopt-dkj-policy` places in a consumer now holds the DEPLOY lock, as this
repo's own gate does: it refuses a PR whose DEPLOY section changed after the PR opened, including one
merged from the GitHub UI. A caller placed before this change keeps working unchanged and says the lock
was not checked. To take the lock, add `pull-requests: read` and the `edited` trigger, or re-run Part 1.

**Score:** 3

#### What makes this deploy extra special

A consumer repo's own CI starts guarding the changelog text a PR was approved with, once its caller
carries the two lines. Callers placed before this change see nothing new until then.

**Score:** 2

#### Pull Request

The consumer's branch-entry gate holds the DEPLOY lock

