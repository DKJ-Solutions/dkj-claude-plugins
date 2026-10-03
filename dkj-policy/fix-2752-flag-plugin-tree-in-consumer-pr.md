## fix/2752-flag-plugin-tree-in-consumer-pr

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

Issue #2752, decided by Dave on October 3, 2026: option 3. The leading-`*` allow globs stay, with no
pinned root and no prompt per step. Diffs that touch `**/.claude/plugins/**` are flagged in the consumer's
review gates. Every adopted consumer runs one review gate on every PR: the branch-entry runner that
`adopt-dkj-policy` Part 1 places as a caller of `reusable-branch-entry.yml@main`. So the flag goes there.

### CREATE

- [x] `.github/workflows/reusable-branch-entry.yml`: a new step, run even when the entry check fails,
  that fails the job when the PR's merge tree tracks any path under `.claude/plugins/` (case-insensitive)
- [x] `specialists-init` SKILL.md and the `bootstrap.ps1` comment: they now name the CI step instead of
  "review with care" / "closing that is a decision"
- [x] `adopt-dkj-policy` SKILL.md: one paragraph on what the caller now also checks

### TEST

- [x] `branch-entry-gate.tests.ps1`: the step reads the pattern out of the workflow and runs it against
  sample paths (3 flagged, 5 left alone), and checks `!cancelled()`, `exit 1` and that no github context
  sits in `run:`. 82/82 pass.
- [x] Real `grep -iE` on a scratch repo flags `.claude/plugins/cache/x/a.ps1` and passes
  `dkj-policy/b.ps1` and `.claude/settings.json`.

### DEPLOY: fix/2752-flag-plugin-tree-in-consumer-pr

**Inside this repo:** nothing changes here. The new step is in the consumer runner only. This repo's own
`branch-entry.yml` runs its own tree's scripts on its own PRs, and nothing in this tree is under
`.claude/plugins/`.

**Score:** N/A

#### What makes this deploy extra special

**For a consumer that calls the reusable branch-entry runner:** a pull request whose tree tracks a path
under `.claude/plugins/` now turns its branch-entry check red, with an annotation saying why. The allow
rules `specialists-init` proposes run a workflow script found under such a path without a prompt, and a
glob can pin the path's shape but not its location, so a plugin tree committed into the repo would have
run unprompted with `-ExecutionPolicy Bypass`. It needs no re-adopt and no extra token scope. A repo still
on a full copy of the runner does not get it. It prevents a failure that has not happened yet.

**Score:** 1

#### Pull Request

The consumer's branch-entry check flags a pull request that tracks a .claude/plugins/ path

