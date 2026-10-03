## feat/2759-sweep-decisions-skill

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

#2759: the issues `sweep-issues` skips as `awaiting-decision` pile up where no sweep looks. The step to
automate is already prescribed in `CONTRIBUTING-portable.md` (the owner answers, the answer goes on the
issue as a comment, the label comes off), so the skill adds no rule, only the loop: list, check that
each decision is still open, ask as menus four at a time, record comment-then-label.

A procedure skill with no script of its own, as `sweep-issues` drives `claim-issue`: every step is one
`gh` call already, and the lazy rule automates on the second manual repeat, not the first.
`disable-model-invocation: true` like `sweep-issues`, because it is run with the owner, on request.

### CREATE

- [x] Tessa: `plugins/dkj-policy/skills/sweep-decisions/SKILL.md`, plus pointers in `CONTRIBUTING-portable.md` and `sweep-issues`, and the skill list in `plugins/ADOPTION.md`
- [x] Lint: `check-plugin-integrity` 0 errors

### TEST

- [x] Security review (Sebastian): no blockers; the two silent label removals became menu options for the owner, authorship is checked by `author.login`, the body goes through `--body-file`, and a public-tracker note was added
- [x] Copy edit (Edith): an invented quote removed, the Drop-it comment wording and the placeholders spelled out

### DEPLOY: feat/2759-sweep-decisions-skill

New skill `/sweep-decisions`: it goes through every open issue parked on `awaiting-decision` (or its
former name `needs-decision`) with you in one sitting. Each one is checked first (already answered,
overtaken by a merged PR, or not yet a choice), then put to you as a short menu, four at a time, with
"Not now" and "Drop it" beside the issue's own options. Your answer goes on the issue as a comment and
the label comes off, so the next `/sweep-issues` finds it free with the decision in its thread.

**Score:** 3

#### What makes this deploy extra special

It is the other half of `sweep-issues`: between the two, nothing on the tracker waits without a route
that reaches it.

**Score:** 2

#### Pull Request

sweep-decisions: put every issue parked on awaiting-decision to the owner in one pass

