## docs/2471-cut-order-in-repo-rule

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

Inbound #2471: `cut-release/SKILL.md`'s "No seam, deliberately" block tells a push-then-cut consumer to
state its order in its own `CLAUDE.md`, which the constitution has restricted to `@`-imports since
#2374. Checked against the tree: the symptom holds (lines 677 and 684). `CONTRIBUTING-portable.md`'s
fourth-move paragraph was already moved to "always-on repo rule", so `cut-release` is the only page left
out of step. Other `own CLAUDE.md` hits in `plugins/` either address repos without `dkj-policy`
(shopify `start-task`) or mean the imported constitution, so they stay as they are.

### CREATE

- [x] Point both `cut-release` sentences at an unscoped `.claude/rules/<name>.md` or the release
      manager's lens, matching `CONTRIBUTING-portable.md`'s wording.

### TEST

- [x] Lint + suites via `open-pr`'s gate.

### DEPLOY: docs/2471-cut-order-in-repo-rule

`cut-release`'s cut-order block now tells a repo that pushes live before it cuts to write that order in
an always-on repo rule (`.claude/rules/<name>.md`) or the release manager's lens, not in `CLAUDE.md`,
which since #2374 carries only `@`-imports. It now agrees with the constitution and with
`CONTRIBUTING-portable.md`.

**Score:** 2 -- removes a contradiction a push-then-cut consumer hit while bringing its `CLAUDE.md` down to imports only (#2471).

#### What makes this deploy extra special

N/A -- a wording fix in a skill page; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

cut-release points the cut order at a repo rule, not CLAUDE.md

