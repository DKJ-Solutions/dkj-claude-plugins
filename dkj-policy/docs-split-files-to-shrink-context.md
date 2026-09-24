## docs/split-files-to-shrink-context

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

Dave, September 24, 2026, after the `this-repo.md` / `language-layers.md` split was explained to him:
record as a constitution rule that a file may be split as far as that keeps loaded context smaller.
The principle already existed in narrower forms: the persona/manual split "by **when** they are needed" in
the root `README.md`, and the `paths:` scoping of `language-layers.md`. This branch states it once, in the
constitution, for every repo.

### CREATE

- [x] Add the rule to `plugins/dkj-policy/CLAUDE.md` under General working practices, directly after
      "be proactive about structure"
- [x] Raise the always-on baseline on the record (`check-always-on-budget.ps1 -Raise`). The path was
      already over the ceiling, so the gate refuses any growth, and this rule governs every turn and so
      belongs on that path (+836 B)

### TEST

- [x] `check-always-on-budget.ps1` is green after the recorded raise
- [x] The lint and test gates run at `open-pr`

### DEPLOY: docs/split-files-to-shrink-context

The constitution gets a new working practice: split a file wherever the split keeps loaded context
smaller. Content is divided by **when** it is needed. What governs every turn stays always-on, and the
rest moves to where it loads on demand (a `paths:`-scoped rule, a manual, a skill page). The rule states
its two limits. Halves that always load together save nothing, and a rule that must hold whichever files a
turn touches stays always-on, because on-demand content is lost after a compaction. The always-on baseline
is raised by 836 B on the record to carry it.

**Score:** 2

#### What makes this deploy extra special

Every repo running `dkj-policy` reads the constitution through its absolute `@`-import, so its sessions
now carry an explicit licence, and a test, for moving situational detail off the always-on path: split by
timing, not by topic.

**Score:** 3

#### Pull Request

Constitution: split a file wherever that keeps loaded context smaller

