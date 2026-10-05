## fix/2805-foreign-checkout-guard

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

Inbound [#2805](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2805) (with #2806 folded in as
the same event). `-RepoRoot` is new-branch's only route into another repository, because
`CLAUDE_PROJECT_DIR` otherwise wins over the cwd, so the guard sits there. It refuses only a hosted clone's
primary checkout. A fixture (no remote, or a local path) and a linked worktree pass, so every suite that runs
new-branch against a fixture from inside a session keeps working. #2806's extra idea (refuse a checkout whose
HEAD moved recently) is noted on #2805 and not built.

### CREATE

- [x] new-branch refuses `-RepoRoot` on another repository's hosted primary checkout, naming the worktree route (both copies)
- [x] The `new-branch` skill documents the refusal under `-RepoRoot`
- [x] Fixture case (z2) in `new-branch.tests.ps1`: refused, nothing created, and a linked worktree passes

### TEST

- [x] `new-branch.tests.ps1`: 85 pass

### DEPLOY: fix/2805-foreign-checkout-guard

`new-branch` now refuses to cut a branch in another repository's primary checkout. When `-RepoRoot` names
the main working tree of a repository other than the session's project, and that tree was cloned from a
host, the run stops before creating anything and names the worktree route. A session in one repository can
no longer switch a branch under a session working in another.

**Score:** 3

#### What makes this deploy extra special

A session that carries a change into a sibling repository is stopped at `new-branch` and told to open a
worktree of it, rather than switching that repository's own checkout. Before, the checkout moved under
whoever was working there, and on October 5, 2026 that put one store's fold commit on another session's
branch.

**Score:** 2

#### Pull Request

new-branch refuses a foreign repo's primary checkout and points at a worktree

