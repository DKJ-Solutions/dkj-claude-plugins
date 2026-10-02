## docs/retire-dkj-policy-readme

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

Dave asked whether `plugins/dkj-policy/README.md` adds anything an agent needs, and said to remove it
if it does not. Checked against the tree: nothing loads it, no script reads it, and lint check 29's
`skills:plugin` span is opt-in, so zero spans passes.

### CREATE

- [x] Delete `plugins/dkj-policy/README.md`
- [x] Rewire its inbound links: `plugins/ADOPTION.md` (two), `plugins/dkj-subagents/README.md`, the
      `dkj-policy-bwj` README, Sylvester's and Nolan's lenses, and the check 29 comment

### TEST

- [x] No live link to the retired page left outside released history (grep)
- [x] Lint + suites green via `open-pr`

### DEPLOY: docs/retire-dkj-policy-readme

`plugins/dkj-policy/README.md` is gone. No agent needed it: nothing loads it, and every fact it held
already had another home. The skill descriptions are always in context, the cycle is in
`CONTRIBUTING-portable.md`, versioning and the cut are in `RELEASES-portable.md`, updating is in
`plugins/ADOPTION.md` and the `update-plugins` skill, and the history is in Sylvester's lens. Its own
copies had already drifted. It said `tidy-machine` had eleven lanes (the skill says twelve) and that
`dkj-policy-bwj` had four skills (it has six). It described `orchestrator`, `push-preview` and
`archive-theme` as if they were this plugin's skills, and it still cited the retired repo name. The
inbound links now point at the page that owns each fact.

**Score:** 2

#### What makes this deploy extra special

N/A: nothing a consumer installs, loads or runs changes. The pages the README pointed to are all still
shipped.

**Score:** N/A

#### Pull Request

Retire plugins/dkj-policy/README.md: every fact it held has a home elsewhere, and its own copies had drifted

