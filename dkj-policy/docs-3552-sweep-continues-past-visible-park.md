## docs/3552-sweep-continues-past-visible-park

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

#3552 (Maikel, October 27, 2026): a sweep ends at the first visible park, so a backlog of visible
results takes one sweep per issue. Settled here, as the sensible defaults the issue left open:

- the constitution carves out the **sweep** only; a single assignment that parks a visible result still
  keeps the checkout on its branch (Chris's manual already names "a sweep's next issue" as the exception,
  #2558, so it needs no edit);
- the sweep's close-out prints one `git checkout <branch>` line per parked branch.

### CREATE

- [x] Constitution (`plugins/dkj-policy/CLAUDE.md`): the sweep carve-out from the checkout half of the visible-result rule.
- [x] `sweep-issues` SKILL.md: the description, the one-sweep-per-checkout paragraph, step 5 (park, then step 7), "When the sweep ends" and the close-out shape.
- [x] Chris's persona: the parked-branch clause names the sweep exception.

### TEST

- [x] No test pins the replaced wording (grep over `scripts/tests` for the old phrases: none); the gates run in `ship-pr`.

### DEPLOY: docs/3552-sweep-continues-past-visible-park

A sweep no longer ends at the first result that has to be judged by eye. It parks that branch on
`origin` with `awaiting-review-dev` and a comment on what to look at, returns to the trunk and carries on
with the next issue; the close-out lists every parked branch with the `git checkout` line that shows it
([#3552](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3552)). The constitution now names
the sweep as the one carve-out from "the checkout stays on that branch until the owner has looked"; a
single assignment still stays on its branch, and no visible result is merged unseen.

**Score:** 3

#### What makes this deploy extra special

A sweep over a backlog of visible results now handles all of them in one run, where it used to stop
after the first one. You look at each parked branch afterwards by checking it out.

**Score:** 3

#### Pull Request

sweep-issues: a visible result parks the issue and the sweep continues

